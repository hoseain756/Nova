import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/torrent/torrent_models.dart';
import 'package:nova_mobile/features/player/engine/playback_engine.dart';
import 'package:nova_mobile/features/player/session/playback_checkpoint.dart';
import 'package:nova_mobile/features/player/session/playback_session.dart';
import 'package:nova_mobile/features/player/session/playback_state.dart';

PlaybackRequest _request([String url = 'https://example.test/video']) =>
    PlaybackRequest(
      item: const MediaItem(id: 'title', type: 'series', name: 'Title'),
      url: url,
      streamName: 'Source',
      videoId: 'title:1:2',
      season: 1,
      episode: 2,
    );

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  late List<PlaybackSession> sessions;
  setUp(() => sessions = []);
  tearDown(() async {
    for (final session in sessions.reversed) {
      try {
        await session.close();
      } catch (_) {/* expected failed-close tests */}
      session.dispose();
    }
  });

  PlaybackSession create(
    _Backend backend, {
    PlaybackOwnership? ownership,
    PlaybackBackend Function()? factory,
    PlaybackCheckpointSink? persist,
    PlaybackCheckpointWriter? writer,
    PlaybackRequest? request,
    PlaybackStartupSettings startupSettings = const PlaybackStartupSettings(),
    bool startInBackground = false,
    Duration timeout = const Duration(milliseconds: 30),
    Duration seekabilityProbeInterval = const Duration(milliseconds: 500),
  }) {
    final session = PlaybackSession(
        request: request ?? _request(),
        startupSettings: startupSettings,
        startInBackground: startInBackground,
        createBackend: factory ?? () => backend,
        ownership: ownership ?? PlaybackOwnership(),
        checkpointWriter: writer ?? PlaybackCheckpointWriter(),
        persist: persist,
        cleanupSaveTimeout: timeout,
        seekabilityProbeInterval: seekabilityProbeInterval,
        periodicInterval: const Duration(days: 1));
    sessions.add(session);
    return session;
  }

  test('startup settings apply inside open before first play', () async {
    final backend = _Backend();
    final session = create(backend,
        startupSettings: const PlaybackStartupSettings(
            subtitleDelayMs: 420, audioDelayMs: -150, subtitlesOff: true));
    backend.raw.onPlay = () {
      expect(backend.raw.subtitleDelayMs, 420);
      expect(backend.raw.audioDelayMs, -150);
      expect(backend.raw.selectedSubtitle.id, 'no');
    };
    expect((await session.open(_request().url)).applied, isTrue);
  });

  test('late unsupported cannot undo terminal close', () async {
    final backend = _Backend()
      ..openGate = Completer<void>()
      ..closeGate = Completer<void>();
    final session = create(backend);
    final opening = session.open(_request().url);
    await _tick();
    final closing = session.close();
    backend.openGate!.completeError(UnsupportedError('late'));
    expect((await opening).status, PlaybackCommandStatus.cancelled);
    await _tick();
    expect(session.phase, PlaybackPhase.closing);
    expect((await session.retry()).status, PlaybackCommandStatus.cancelled);
    backend.closeGate!.complete();
    await closing;
    expect(session.phase, PlaybackPhase.closed);
  });

  test('failed replacement retirement retains old and candidate leases',
      () async {
    var released = 0;
    PreparedTorrent lease(String id) => PreparedTorrent(
        infoHash: id,
        url: 'http://127.0.0.1/$id',
        statusStream: const Stream.empty(),
        onStop: () async {
          released++;
        });
    final oldLease = lease('old');
    final candidate = lease('new');
    PlaybackRequest request(PreparedTorrent torrent) => PlaybackRequest(
        item: _request().item,
        url: torrent.url,
        streamName: 'Source',
        videoId: 'same',
        torrent: torrent);
    final backend = _Backend()..failClose = true;
    var creations = 0;
    final session = create(backend, request: request(oldLease), factory: () {
      creations++;
      return backend;
    });
    await session.open(oldLease.url);
    expect((await session.replaceSource(request(candidate))).status,
        PlaybackCommandStatus.failed);
    expect(creations, 1);
    expect(released, 0);
    await expectLater(session.close(), throwsStateError);
    expect(released, 0);
  });

  test('background during delayed resolution revokes handoff autoplay',
      () async {
    final old = create(_Backend());
    await old.open(_request().url);
    final saved = PlaybackContinuity(old);
    final identity = old.beginResolution();
    final pausing = old.pause();
    final intent = old.handoffIntent(identity, saved.playing);
    await pausing;
    final gate = Completer<void>();
    final resolving = old.resolve(identity, () => gate.future);
    await _tick();
    await old.background();
    old.foreground();
    gate.complete();
    await resolving;
    expect(old.canRestoreHandoff(intent), isFalse);
    final backend = _Backend();
    final next = create(backend);
    await next.open(_request().url,
        continuity: saved.restrictPlay(old.canRestoreHandoff(intent)));
    expect(backend.log, isNot(contains('play')));
    expect(next.playing, isFalse);
  });

  test('a route born in background cannot autoplay saved intent', () async {
    final old = create(_Backend());
    await old.open(_request().url);
    final backend = _Backend();
    final next = create(backend, startInBackground: true);
    await next.open(_request().url, continuity: PlaybackContinuity(old));
    expect(next.playing, isFalse);
    expect((await next.play()).status, PlaybackCommandStatus.cancelled);
    next.foreground();
    expect((await next.play()).applied, isTrue);
  });

  test('pause during open prevents autoplay and lane drains in order',
      () async {
    final backend = _Backend()..openGate = Completer<void>();
    final session = create(backend);
    final opening = session.open(_request().url);
    await _tick();
    final pausing = session.pause();
    final seeking = session.seekTo(const Duration(seconds: 20));
    backend.openGate!.complete();
    expect((await opening).applied, isTrue);
    expect((await pausing).applied, isTrue);
    expect((await seeking).applied, isTrue);
    expect(backend.log, ['open', 'pause', 'seek:20000']);
    expect(session.playing, isFalse);
  });

  test('close cancels queued commands and suppresses late open autoplay',
      () async {
    final backend = _Backend()..openGate = Completer<void>();
    final session = create(backend);
    final opening = session.open(_request().url);
    await _tick();
    final seeking = session.seekTo(const Duration(seconds: 2));
    final closing = session.close();
    expect(identical(closing, session.close()), isTrue);
    backend.openGate!.complete();
    expect((await opening).status, PlaybackCommandStatus.cancelled);
    expect((await seeking).status, PlaybackCommandStatus.cancelled);
    await closing;
    expect(backend.log, isNot(contains('play')));
    expect(backend.closed, isTrue);
  });

  test(
      'backend duration during open cannot enable checkpoints before preparation',
      () async {
    final backend = _Backend()..openGate = Completer<void>();
    final saved = <PlaybackCheckpoint>[];
    final session =
        create(backend, persist: (snapshot) async => saved.add(snapshot));
    final opening = session.open(_request().url);
    await _tick();
    backend.raw.ready = true;
    backend.raw.notifyListeners();
    expect(session.ready, isFalse);
    expect(await session.checkpoint(CheckpointCause.pause),
        CheckpointResult.rejected);
    expect(saved, isEmpty);
    backend.openGate!.complete();
    await opening;
    expect(session.ready, isTrue);
  });

  test('failed command does not poison later lane items or expose URL',
      () async {
    final backend = _Backend();
    final session = create(backend);
    await session.open(_request().url);
    backend.raw.failRate = StateError('https://private.test/token?secret=123');
    final failed = await session.setRate(2);
    final volume = await session.setVolume(.4);
    expect(failed.status, PlaybackCommandStatus.failed);
    expect(volume.applied, isTrue);
    expect(session.errorMessage, isNot(contains('private')));
    expect(backend.raw.volume, .4);
  });

  test('only explicit safe retry evidence retries once per operation/attempt',
      () async {
    final backend = _Backend();
    final session = create(backend);
    await session.open(_request().url);
    backend.raw.failRate = const PlaybackRetryableException();
    expect((await session.setRate(2)).applied, isTrue);
    expect(backend.log.where((op) => op == 'rate').length, 2);
    backend.raw.failRate = const PlaybackRetryableException();
    expect((await session.setRate(3)).status, PlaybackCommandStatus.failed);
    expect(backend.log.where((op) => op == 'rate').length, 3);
  });

  test(
      'position flood updates exact state without page transport notifications',
      () async {
    final backend = _Backend();
    final session = create(backend);
    await session.open(_request().url);
    var transportNotifications = 0;
    session.addListener(() => transportNotifications++);
    for (var i = 1; i <= 200; i++) {
      backend.raw.position = Duration(microseconds: i * 1234);
      backend.raw.notifyListeners();
    }
    expect(session.position.inMicroseconds, 246800);
    expect(transportNotifications, 0);
    expect(session.progress.value!.position, isNot(session.position));
  });

  test('panel token cannot autoplay after a later user/system pause', () async {
    final backend = _Backend();
    final session = create(backend);
    await session.open(_request().url);
    final token = session.pauseForPanel();
    await session.pause();
    expect((await session.restorePanel(token)).status,
        PlaybackCommandStatus.cancelled);
    expect(session.playing, isFalse);
    final second = session.pauseForPanel();
    await session.background();
    session.foreground();
    expect((await session.restorePanel(second)).status,
        PlaybackCommandStatus.cancelled);
    expect(session.playing, isFalse);
  });

  test('inactive/paused notifications share one pause/save transaction',
      () async {
    final backend = _Backend();
    final saves = <PlaybackCheckpoint>[];
    final session =
        create(backend, persist: (snapshot) async => saves.add(snapshot));
    await session.open(_request().url);
    final one = session.background();
    final two = session.background();
    expect(identical(one, two), isTrue);
    await one;
    expect(backend.log.where((op) => op == 'pause').length, 1);
    expect(saves, hasLength(1));
  });

  test('new native ownership waits for old native retirement', () async {
    final ownership = PlaybackOwnership();
    final old = _Backend()..closeGate = Completer<void>();
    final one = create(old, ownership: ownership);
    await one.open(_request().url);
    var creations = 0;
    final next = _Backend();
    final two = create(next, ownership: ownership, factory: () {
      creations++;
      return next;
    });
    final opening = two.open(_request().url);
    await _tick();
    expect(creations, 0);
    old.closeGate!.complete();
    await opening;
    expect(old.closed, isTrue);
    expect(creations, 1);
  });

  test('closing a stuck open retires native before the next route opens',
      () async {
    final ownership = PlaybackOwnership();
    final old = _Backend()
      ..openGate = Completer<void>()
      ..closeGate = Completer<void>()
      ..releaseOpenOnClose = true;
    final one = create(old, ownership: ownership);
    final firstOpening = one.open(_request().url);
    await _tick();
    expect(one.openStage, 'backend_open');

    var creations = 0;
    final next = _Backend();
    final two = create(next, ownership: ownership, factory: () {
      creations++;
      return next;
    });
    final secondOpening = two.open(_request().url);
    expect((await firstOpening).status, PlaybackCommandStatus.cancelled);
    await _tick();
    expect(old.log, contains('close'));
    expect(creations, 0);

    old.closeGate!.complete();
    expect((await secondOpening).applied, isTrue);
    expect(old.closed, isTrue);
    expect(one.phase, PlaybackPhase.closed);
    expect(creations, 1);
  });

  test('failed retirement during stuck open blocks the next native engine',
      () async {
    final ownership = PlaybackOwnership();
    final old = _Backend()
      ..openGate = Completer<void>()
      ..releaseOpenOnClose = true
      ..failClose = true;
    final one = create(old, ownership: ownership);
    final firstOpening = one.open(_request().url);
    await _tick();
    var creations = 0;
    final two = create(_Backend(), ownership: ownership, factory: () {
      creations++;
      return _Backend();
    });
    expect(
        (await two.open(_request().url)).status, PlaybackCommandStatus.failed);
    expect((await firstOpening).status, PlaybackCommandStatus.cancelled);
    expect(creations, 0);
  });

  test(
      'retirement timeout reports ownership failure instead of loading forever',
      () async {
    final ownership =
        PlaybackOwnership(retirementTimeout: const Duration(milliseconds: 20));
    final old = _Backend()..closeGate = Completer<void>();
    final one = create(old, ownership: ownership);
    await one.open(_request().url);
    var creations = 0;
    final two = create(_Backend(), ownership: ownership, factory: () {
      creations++;
      return _Backend();
    });
    final result = await two.open(_request().url);
    expect(result.status, PlaybackCommandStatus.failed);
    expect(result.failure?.operation, 'ownership');
    expect(two.phase, PlaybackPhase.failed);
    expect(creations, 0);
    old.closeGate!.complete();
    await one.close();
  });

  test('torrent preparation barrier waits for prior native retirement',
      () async {
    final ownership = PlaybackOwnership();
    final old = _Backend()..closeGate = Completer<void>();
    final session = create(old, ownership: ownership);
    await session.open(_request().url);
    var allowedToPrepare = false;
    final barrier = ownership.retireCurrent().then((_) {
      allowedToPrepare = true;
    });
    await _tick();
    expect(old.log, contains('close'));
    expect(allowedToPrepare, isFalse);
    old.closeGate!.complete();
    await barrier;
    expect(old.closed, isTrue);
    expect(allowedToPrepare, isTrue);
  });

  test('failed native close blocks competing engine creation', () async {
    final ownership = PlaybackOwnership();
    final old = _Backend()..failClose = true;
    final one = create(old, ownership: ownership);
    await one.open(_request().url);
    final next = _Backend();
    var creations = 0;
    final two = create(next, ownership: ownership, factory: () {
      creations++;
      return next;
    });
    expect(
        (await two.open(_request().url)).status, PlaybackCommandStatus.failed);
    expect(creations, 0);
    expect(next.log, isEmpty);
  });

  test('save failure still closes native and later writer calls recover',
      () async {
    final backend = _Backend();
    final session =
        create(backend, persist: (_) async => throw StateError('storage'));
    await session.open(_request().url);
    await session.close();
    expect(backend.closed, isTrue);
    expect(session.persistenceFailed, isTrue);
  });

  test('stalled save cannot hold native cleanup indefinitely', () async {
    final backend = _Backend();
    final blocked = Completer<void>();
    final session = create(backend, persist: (_) => blocked.future);
    await session.open(_request().url);
    await session.close();
    expect(session.persistenceFailed, isTrue);
    expect(backend.closed, isTrue);
    blocked.complete();
  });

  test(
      'source switch captures exact progress and restores pause/rate/subtitle off',
      () async {
    final old = _Backend();
    final next = _Backend();
    var created = 0;
    final saves = <PlaybackCheckpoint>[];
    final session = create(old,
        factory: () {
          if (created++ == 0) return old;
          expect(old.closed, isTrue);
          return next;
        },
        persist: (snapshot) async => saves.add(snapshot));
    await session.open(_request().url);
    old.raw.position = const Duration(milliseconds: 42321);
    await session.setRate(1.5);
    await session.selectSubtitle(SubtitleTrack.no());
    await session.pause();
    final result =
        await session.replaceSource(_request('https://example.test/second'));
    expect(result.applied, isTrue);
    expect(next.raw.position.inMilliseconds, 42321);
    expect(next.raw.playing, isFalse);
    expect(next.raw.rate, 1.5);
    expect(next.raw.selectedSubtitle.id, 'no');
    expect(saves.single.positionMs, 42321);
    expect(next.log.where((op) => op == 'open').length, 1);
  });

  test('nonseekable source returns unsupported without pretending continuity',
      () async {
    final backend = _Backend()..canSeek = false;
    final session = create(backend);
    await session.open(_request().url);
    expect(session.ready, isTrue);
    expect((await session.seekTo(const Duration(seconds: 1))).status,
        PlaybackCommandStatus.unsupported);
    expect(backend.log.where((op) => op.startsWith('seek')), isEmpty);
  });

  test('data-backed external subtitle survives a core source replacement',
      () async {
    final old = _Backend();
    final next = _Backend();
    var created = 0;
    final session = create(old, factory: () => created++ == 0 ? old : next);
    expect((await session.open(_request().url)).applied, isTrue);
    final subtitle = SubtitleTrack.data(
        '1\n00:00:01,000 --> 00:00:02,000\nHello\n',
        title: 'External');
    expect((await session.selectSubtitle(subtitle)).applied, isTrue);
    expect(
        (await session.replaceSource(_request('https://example.test/second')))
            .applied,
        isTrue);
    expect(next.raw.selectedSubtitle, subtitle);
    expect(next.raw.selectedSubtitle.data, isTrue);
  });

  test('seek unlocks when paused-open capability becomes available', () async {
    final backend = _Backend()..canSeek = false;
    final session = create(backend,
        seekabilityProbeInterval: const Duration(milliseconds: 5));
    await session.open(_request().url);
    expect(session.canSeek, isFalse);
    backend.canSeek = true;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(session.canSeek, isTrue);
    expect((await session.seekTo(const Duration(minutes: 2))).applied, isTrue);
    expect(backend.raw.position, const Duration(minutes: 2));
  });

  test('startup resume waits for late seek capability before playing',
      () async {
    final backend = _Backend()..seekableAfterQuery = 2;
    final session = create(backend,
        seekabilityProbeInterval: const Duration(milliseconds: 5));
    final result =
        await session.open(_request().url, startAt: const Duration(minutes: 3));
    expect(result.applied, isTrue);
    expect(backend.raw.position, const Duration(minutes: 3));
    expect(backend.log.indexOf('seek:180000'),
        lessThan(backend.log.indexOf('play')));
  });

  test('new source does not inherit the previous seek capability', () async {
    final first = _Backend();
    final second = _Backend()..canSeek = false;
    var created = 0;
    final session =
        create(first, factory: () => created++ == 0 ? first : second);
    await session.open(_request().url);
    expect(session.canSeek, isTrue);
    await session.open('https://example.test/other');
    expect(session.canSeek, isFalse);
    expect((await session.seekTo(const Duration(seconds: 5))).status,
        PlaybackCommandStatus.unsupported);
  });

  test('resolution token survives deliberate retirement but exit cancels it',
      () async {
    final session = create(_Backend());
    await session.open(_request().url);
    final old = session.beginResolution();
    final latest = session.beginResolution();
    expect(session.acceptsResolution(old), isFalse);
    await session.closeForResolution(latest);
    expect(session.acceptsResolution(latest), isTrue);
    session.cancelResolution();
    expect(session.acceptsResolution(latest), isFalse);
  });

  test('ownership drains a non-cancellable old resolver before new creation',
      () async {
    final ownership = PlaybackOwnership();
    final old = create(_Backend(), ownership: ownership);
    await old.open(_request().url);
    final identity = old.beginResolution();
    final gate = Completer<void>();
    final resolving = old.resolve(identity, () => gate.future);
    await _tick();
    var creations = 0;
    final nextBackend = _Backend();
    final next = create(nextBackend, ownership: ownership, factory: () {
      creations++;
      return nextBackend;
    });
    final opening = next.open(_request().url);
    await _tick();
    expect(creations, 0);
    gate.complete();
    await resolving;
    await opening;
    expect(creations, 1);
  });

  test('manual retry retains torrent until the terminal native close',
      () async {
    final old = _Backend();
    final next = _Backend();
    var created = 0;
    var releases = 0;
    final torrent = PreparedTorrent(
        infoHash: 'hash',
        url: 'http://127.0.0.1/stream',
        statusStream: const Stream.empty(),
        onStop: () async {
          releases++;
          expect(next.closed, isTrue);
        });
    final request = PlaybackRequest(
        item: _request().item,
        url: torrent.url,
        streamName: 'Source',
        videoId: 'video',
        torrent: torrent);
    final session = create(old, request: request, factory: () {
      if (created++ == 0) return old;
      expect(old.closed, isTrue);
      return next;
    });
    await session.open(torrent.url);
    expect((await session.retry()).applied, isTrue);
    expect(releases, 0);
    await session.close();
    expect(releases, 1);
  });

  test('retry restores last exact position after failed backend resets to zero',
      () async {
    final first = _Backend();
    final second = _Backend();
    var created = 0;
    final session =
        create(first, factory: () => created++ == 0 ? first : second);
    expect((await session.open(_request().url)).applied, isTrue);
    first.raw.position = const Duration(minutes: 9);
    first.raw.notifyListeners();
    first.raw.position = Duration.zero;
    first.raw.failed = true;
    first.raw.errorMessage = 'HTTP 503';
    first.raw.notifyListeners();
    expect(session.failed, isTrue);
    expect(session.position, Duration.zero);

    expect((await session.retry()).applied, isTrue);
    expect(second.raw.position, const Duration(minutes: 9));
    expect(second.log.indexOf('seek:540000'),
        lessThan(second.log.indexOf('play')));
  });

  test('retry retains startup resume target when first open fails', () async {
    final first = _Backend()..openError = StateError('source unavailable');
    final second = _Backend();
    var created = 0;
    final session =
        create(first, factory: () => created++ == 0 ? first : second);
    expect(
        (await session.open(_request().url,
                startAt: const Duration(minutes: 9)))
            .status,
        PlaybackCommandStatus.failed);
    expect(session.position, Duration.zero);

    expect((await session.retry()).applied, isTrue);
    expect(second.raw.position, const Duration(minutes: 9));
    expect(second.log.indexOf('seek:540000'),
        lessThan(second.log.indexOf('play')));
  });

  test('explicit seek to start clears retry position', () async {
    final first = _Backend();
    final second = _Backend();
    var created = 0;
    final session =
        create(first, factory: () => created++ == 0 ? first : second);
    await session.open(_request().url);
    expect((await session.seekTo(const Duration(minutes: 9))).applied, isTrue);
    // The native seek command may finish before its position stream publishes
    // the new zero value. Retry must honor the explicit intent in that gap.
    first.raw.deferSeekPosition = true;
    expect((await session.seekTo(Duration.zero)).applied, isTrue);
    expect(session.position, const Duration(minutes: 9));
    first.raw.failed = true;
    first.raw.errorMessage = 'source failed';
    first.raw.notifyListeners();

    expect((await session.retry()).applied, isTrue);
    expect(second.raw.position, Duration.zero);
    expect(second.log.where((op) => op.startsWith('seek:')), isEmpty);
  });

  test('failure categories are sanitized hints and do not trigger retries',
      () async {
    final backend = _Backend();
    final session = create(backend);
    await session.open(_request().url);
    backend.raw.errorMessage = 'HTTP 401 https://private.test/?token=secret';
    backend.raw.failed = true;
    backend.raw.notifyListeners();
    expect(session.failure!.category, PlaybackFailureCategory.source);
    expect(session.errorMessage, 'playback_source_backend');
    expect(backend.log.where((op) => op == 'open'), hasLength(1));
  });

  test('unresolved resume suppresses exact checkpoints until choice resolves',
      () async {
    final backend = _Backend();
    final saves = <PlaybackCheckpoint>[];
    final session =
        create(backend, persist: (snapshot) async => saves.add(snapshot));
    session.resumeResolved = false;
    await session.open(_request().url, playWhenReady: false);
    expect(await session.checkpoint(CheckpointCause.periodic),
        CheckpointResult.rejected);
    session.resumeResolved = true;
    backend.raw.position = const Duration(microseconds: 32123456);
    await session.checkpoint(CheckpointCause.pause);
    expect(saves.single.positionMs, 32123);
  });
}

class _Backend implements PlaybackBackend {
  final log = <String>[];
  late final raw = _Engine(log);
  Completer<void>? openGate;
  Completer<void>? closeGate;
  bool failClose = false;
  bool releaseOpenOnClose = false;
  Object? openError;
  bool canSeek = true;
  int? seekableAfterQuery;
  int seekableQueries = 0;
  bool closed = false;
  @override
  PlaybackEngine get engine => raw;
  @override
  Future<void> openPaused(String url, Map<String, String>? headers) async {
    log.add('open');
    await openGate?.future;
    if (openError != null) throw openError!;
    raw.ready = true;
    raw.notifyListeners();
  }

  @override
  Future<bool?> seekable() async {
    seekableQueries++;
    return canSeek &&
        (seekableAfterQuery == null || seekableQueries >= seekableAfterQuery!);
  }

  @override
  Future<Uint8List?> captureFrame() async => null;
  @override
  Future<void> close() async {
    log.add('close');
    if (releaseOpenOnClose && !(openGate?.isCompleted ?? true)) {
      openGate!.complete();
    }
    await closeGate?.future;
    if (failClose) throw StateError('Native close failed');
    closed = true;
    raw.dispose();
  }
}

class _Engine extends PlaybackEngine {
  _Engine(this.log);
  final List<String> log;
  Object? failRate;
  bool deferSeekPosition = false;
  void Function()? onPlay;
  int subtitleDelayMs = 0;
  int audioDelayMs = 0;
  @override
  bool ready = false;
  @override
  bool playing = false;
  @override
  bool buffering = false;
  @override
  bool completed = false;
  @override
  bool failed = false;
  @override
  String? errorMessage;
  @override
  Duration position = Duration.zero;
  @override
  Duration duration = const Duration(minutes: 20);
  @override
  Duration bufferedEnd = Duration.zero;
  @override
  double rate = 1;
  @override
  double volume = 1;
  @override
  bool get muted => volume == 0;
  @override
  List<AudioTrack> audioTracks = [];
  @override
  List<SubtitleTrack> subtitleTracks = [];
  @override
  AudioTrack selectedAudio = AudioTrack.auto();
  @override
  SubtitleTrack selectedSubtitle = SubtitleTrack.auto();
  @override
  Stream<List<String>> get subtitleTexts => const Stream.empty();
  @override
  List<String> get subtitleTextSnapshot => const [];
  @override
  Future<void> open(String url,
      {Duration? startAt, Map<String, String>? httpHeaders}) async {}
  @override
  Future<void> play() async {
    onPlay?.call();
    log.add('play');
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    log.add('pause');
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> togglePlayPause() => playing ? pause() : play();
  @override
  Future<void> seekTo(Duration target) async {
    final clamped = Duration(
        milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds));
    log.add('seek:${clamped.inMilliseconds}');
    if (!deferSeekPosition) {
      position = clamped;
      notifyListeners();
    }
  }

  @override
  Future<void> seekBy(int seconds) =>
      seekTo(position + Duration(seconds: seconds));
  @override
  Future<void> setRate(double value) async {
    log.add('rate');
    final fail = failRate;
    failRate = null;
    if (fail != null) throw fail;
    rate = value;
    notifyListeners();
  }

  @override
  Future<void> setVolume(double value) async {
    volume = value;
    notifyListeners();
  }

  @override
  Future<void> toggleMute() => setVolume(muted ? 1 : 0);
  @override
  Future<void> selectAudio(AudioTrack track) async {
    selectedAudio = track;
    notifyListeners();
  }

  @override
  Future<void> selectSubtitle(SubtitleTrack track) async {
    selectedSubtitle = track;
    notifyListeners();
  }

  @override
  Future<void> setSubtitleUri(String url, {String? title}) =>
      selectSubtitle(SubtitleTrack.uri(url, title: title));
  @override
  Future<void> setSubtitleDelayMs(int delayMs) async {
    subtitleDelayMs = delayMs;
  }

  @override
  Future<void> setAudioDelayMs(int delayMs) async {
    audioDelayMs = delayMs;
  }
}
