import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/watch_party/watch_party_controller.dart';
import 'package:nova_mobile/core/watch_party/watch_party_models.dart';
import 'package:nova_mobile/features/player/engine/playback_engine.dart';
import 'package:nova_mobile/features/player/session/playback_checkpoint.dart';
import 'package:nova_mobile/features/player/session/playback_session.dart';
import 'package:nova_mobile/features/player/session/playback_state.dart';
import 'package:nova_mobile/features/player/watch_party_player_binding.dart';
import 'support/watch_party_fixture.dart';
import 'support/watch_party_server.dart';

class _Engine extends PlaybackEngine {
  final calls = <String>[];
  Completer<void>? seekGate;
  bool failSeek = false;
  Duration? seekLanding;
  @override
  bool ready = true;
  @override
  bool playing = false;
  @override
  bool buffering = false;
  @override
  bool failed = false;
  @override
  bool completed = false;
  @override
  Duration position = Duration.zero;
  @override
  Duration duration = const Duration(hours: 1);
  @override
  double rate = 1;
  @override
  double volume = 1;
  @override
  Duration bufferedEnd = Duration.zero;
  @override
  String? errorMessage;
  @override
  List<AudioTrack> audioTracks = [];
  @override
  List<SubtitleTrack> get subtitleTracks => const [];
  @override
  AudioTrack selectedAudio = AudioTrack.auto();
  @override
  SubtitleTrack get selectedSubtitle => SubtitleTrack.auto();
  @override
  Future<void> setSubtitleDelayMs(int delayMs) async {}
  @override
  Future<void> setAudioDelayMs(int delayMs) async {}
  @override
  Future<void> selectAudio(AudioTrack track) async {
    if (interceptsWatchPartyAudio && await routeWatchPartyAudio(track)) return;
    calls.add('audio');
    selectedAudio = track;
  }

  @override
  Future<void> setVolume(double value) async => volume = value;
  @override
  Future<void> play() async {
    if (interceptsWatchParty && await routeWatchPartyCommand('play')) return;
    calls.add('play');
    playing = true;
  }

  @override
  Future<void> pause() async {
    if (interceptsWatchParty && await routeWatchPartyCommand('pause')) return;
    calls.add('pause');
    playing = false;
  }

  @override
  Future<void> seekTo(Duration target) async {
    if (interceptsWatchParty &&
        await routeWatchPartyCommand(
            'seek', target.inMilliseconds.toDouble())) {
      return;
    }
    calls.add('seek');
    await seekGate?.future;
    if (failSeek) throw StateError('native seek failed');
    position = seekLanding ?? target;
  }

  @override
  Future<void> setRate(double value) async {
    if (interceptsWatchParty && await routeWatchPartyCommand('rate', value)) {
      return;
    }
    calls.add('rate');
    rate = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionBackend implements PlaybackBackend {
  bool canSeek = true;
  @override
  final _Engine engine = _Engine()..ready = false;
  @override
  Future<void> openPaused(String url, Map<String, String>? headers) async {
    engine.ready = true;
    engine.notifyListeners();
  }

  @override
  Future<bool?> seekable() async => canSeek;
  @override
  Future<Uint8List?> captureFrame() async => null;
  @override
  Future<void> close() async => engine.dispose();
}

void main() {
  testWidgets('immediate media failures retry at a bounded cadence and recover',
      (tester) async {
    var mono = 0;
    final g = FakeWatchPartyGateway()..data = partyData(selfId: partyHostId);
    final c = WatchPartyController(g,
        deviceId: partyDeviceId,
        clock: WatchPartyClock(monotonicMs: () => mono));
    c.bindIdentity('account', partyProfileId);
    await c.join('ABCDEFGH');
    var fail = true;
    const next = WatchPartyMedia(
        id: 'next', type: 'movie', title: 'Next', videoId: 'next');
    g.handle = (params) async {
      if (params['p_action'] == 'media') {
        if (fail) throw StateError('immediate transport failure');
        final revision = (g.data['room'] as Map)['revision'] as int;
        g.data = clonePartyData(
            partyData(selfId: partyHostId, revision: revision + 1));
        (g.data['room'] as Map)['media'] = next.toJson();
      }
      return clonePartyData(g.data);
    };
    final engine = _Engine();
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: engine, media: next, isActive: () => true);
    await tester.pump();
    int attempts() =>
        g.requests.where((params) => params['p_action'] == 'media').length;
    expect(attempts(), 1);
    for (var i = 0; i < 20; i++) {
      final membershipOnly = clonePartyData(g.data);
      (membershipOnly['room'] as Map)['revision'] = i + 2;
      g.event!('snapshot', membershipOnly);
    }
    await tester.pump();
    expect(attempts(), 1);
    mono = 999;
    await tester.pump(const Duration(milliseconds: 250));
    expect(attempts(), 1);
    mono = 1000;
    await tester.pump(const Duration(milliseconds: 250));
    expect(attempts(), 2);
    fail = false;
    mono = 2000;
    (g.data['room'] as Map)['revision'] = 30;
    await tester.pump(const Duration(milliseconds: 250));
    expect(attempts(), 3);
    expect(c.snapshot!.media!.key, next.key);
    binding.dispose();
    c.dispose();
    engine.dispose();
  });
  testWidgets(
      'new host player publishes media and old guest waits for visible follow action',
      (tester) async {
    final server = WatchPartyTestServer(playing: true);
    final host = WatchPartyController(server.client(partyHostId),
        deviceId: partyHostId,
        clock: WatchPartyClock(monotonicMs: () => server.now));
    final guest = WatchPartyController(server.client(partyGuestId),
        deviceId: partyGuestId,
        clock: WatchPartyClock(monotonicMs: () => server.now));
    for (final controller in [host, guest]) {
      controller.bindIdentity(controller.deviceId, partyProfileId);
      await controller.join('ABCDEFGH');
    }
    final guestEngine = _Engine();
    var visible = false;
    final notices = <String>[];
    final guestBinding = WatchPartyPlayerBinding(
        controller: guest,
        engine: guestEngine,
        media: partyMedia,
        isActive: () => true,
        onFollowRequired: (key) {
          if (!visible) return false;
          notices.add(key);
          return true;
        });
    await tester.pump();
    expect(guestEngine.playing, isTrue);
    final hostEngine = _Engine()..playing = true;
    const next = WatchPartyMedia(
        id: 'next', type: 'movie', title: 'Next', videoId: 'next');
    final hostBinding = WatchPartyPlayerBinding(
        controller: host,
        engine: hostEngine,
        media: next,
        isActive: () => true);
    await tester.pump();
    expect(host.snapshot!.media!.key, next.key);
    expect(guest.snapshot!.media!.key, next.key);
    expect(guestEngine.playing, isFalse);
    expect(notices, isEmpty);
    guestEngine.calls.clear();
    await guestEngine.play();
    await guestEngine.seekTo(const Duration(seconds: 30));
    await tester.pump();
    expect(guestEngine.calls, isEmpty);
    expect(server.commands, isEmpty);
    visible = true;
    await tester.pump(const Duration(milliseconds: 250));
    expect(notices, ['partyTitleChanged']);
    await tester.pump(const Duration(milliseconds: 250));
    expect(notices, ['partyTitleChanged']);
    hostBinding.dispose();
    guestBinding.dispose();
    host.dispose();
    guest.dispose();
    hostEngine.dispose();
    guestEngine.dispose();
  });

  testWidgets(
      'locked host source changes pause guests and offer follow playback',
      (tester) async {
    final first =
        WatchPartySource.fromStream({'url': 'https://example.test/a'})!;
    final second =
        WatchPartySource.fromStream({'url': 'https://example.test/b'})!;
    final g = FakeWatchPartyGateway()
      ..data = partyData(playing: true, hostOnly: false);
    (g.data['room'] as Map)['source'] = first.toJson();
    (g.data['room'] as Map)['source_locked'] = true;
    final c = WatchPartyController(g,
        deviceId: partyDeviceId, clock: WatchPartyClock(monotonicMs: () => 0));
    c.bindIdentity('account', partyProfileId);
    await c.join('ABCDEFGH');
    final engine = _Engine();
    final notices = <String>[];
    final binding = WatchPartyPlayerBinding(
        controller: c,
        engine: engine,
        media: partyMedia,
        source: first,
        isActive: () => true,
        onFollowRequired: (key) {
          notices.add(key);
          return true;
        });
    await tester.pump();
    expect(engine.playing, isTrue);
    (g.data['room'] as Map)['source'] = second.toJson();
    (g.data['room'] as Map)['revision'] = 2;
    g.event!('snapshot', clonePartyData(g.data));
    await tester.pump();
    expect(engine.playing, isFalse);
    expect(notices, ['partySourceLockedMismatch']);
    binding.dispose();
    c.dispose();
    engine.dispose();
  });
  testWidgets('paused scene correction resolves a 250 millisecond offset',
      (tester) async {
    final g = FakeWatchPartyGateway();
    final c = WatchPartyController(g,
        deviceId: partyDeviceId, clock: WatchPartyClock(monotonicMs: () => 0));
    c.bindIdentity('account', partyProfileId);
    await c.join('ABCDEFGH');
    final engine = _Engine()..position = const Duration(milliseconds: 9750);
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: engine, media: partyMedia, isActive: () => true);
    await tester.pump();
    expect(engine.position, const Duration(seconds: 10));
    expect(engine.calls, ['seek']);
    binding.dispose();
    c.dispose();
    engine.dispose();
  });

  testWidgets('coarse paused seeks are bounded without blocking room commands',
      (tester) async {
    var mono = 0;
    final g = FakeWatchPartyGateway()..data = partyData(hostOnly: false);
    final c = WatchPartyController(g,
        deviceId: partyDeviceId,
        clock: WatchPartyClock(monotonicMs: () => mono));
    c.bindIdentity('account', partyProfileId);
    await c.join('ABCDEFGH');
    final engine = _Engine()
      ..position = const Duration(seconds: 9)
      ..seekLanding = const Duration(milliseconds: 9800);
    final errors = <String>[];
    final binding = WatchPartyPlayerBinding(
        controller: c,
        engine: engine,
        media: partyMedia,
        isActive: () => true,
        onError: errors.add);
    await tester.pump();
    for (var i = 1; i <= 8; i++) {
      mono = i * 500;
      // Coarse native events may briefly report the requested target before
      // publishing the actual keyframe. Neither may replenish this budget.
      engine.position = Duration(milliseconds: i.isEven ? 10000 : 9800);
      // Membership-only revisions must not replenish the seek budget.
      g.data = partyData(hostOnly: false, revision: i + 1);
      g.event!('snapshot', clonePartyData(g.data));
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(engine.calls.where((call) => call == 'seek').length,
        WatchPartyPlayerBinding.maxPausedCorrectionAttempts);
    expect(errors, ['partySyncFailed']);
    await engine.play();
    await tester.pump();
    expect(engine.playing, isTrue);
    await engine.pause();
    await tester.pump();
    expect(engine.playing, isFalse);
    expect(
        g.requests
            .where((request) => request['p_action'] == 'command')
            .map((request) => (request['p_payload'] as Map)['command']),
        ['play', 'pause']);
    binding.dispose();
    c.dispose();
    engine.dispose();
  });
  testWidgets('a completed shorter guest never pauses the room or replays EOF',
      (tester) async {
    final g = FakeWatchPartyGateway()
      ..data = partyData(hostOnly: false, playing: true, position: 2600000);
    final c = WatchPartyController(g,
        deviceId: partyDeviceId, clock: WatchPartyClock(monotonicMs: () => 0));
    c.bindIdentity('account', partyProfileId);
    await c.join('ABCDEFGH');
    final engine = _Engine()
      ..duration = const Duration(minutes: 40)
      ..completed = true;
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: engine, media: partyMedia, isActive: () => true);
    await tester.pump(const Duration(seconds: 1));
    expect(engine.calls, isEmpty);
    expect(engine.playing, isFalse);
    expect(c.snapshot!.playing, isTrue);
    expect(g.requests.where((request) => request['p_action'] == 'command'),
        isEmpty);
    binding.dispose();
    c.dispose();
    engine.dispose();
  });
  testWidgets('two sources sync semantic audio and enforce a later source lock',
      (tester) async {
    final firstSource =
        WatchPartySource.fromStream({'url': 'https://example.test/a.mp4'})!;
    final secondSource =
        WatchPartySource.fromStream({'url': 'https://example.test/b.mp4'})!;
    final server = WatchPartyTestServer();
    server.room['source'] = firstSource.toJson();
    final controllers = [partyHostId, partyGuestId]
        .map((id) => WatchPartyController(server.client(id),
            deviceId: id,
            clock: WatchPartyClock(monotonicMs: () => server.now)))
        .toList();
    for (final controller in controllers) {
      controller.bindIdentity(controller.deviceId, partyProfileId);
      await controller.join('ABCDEFGH');
    }
    final engines = [_Engine(), _Engine()];
    engines.last.duration = const Duration(minutes: 40);
    engines.first.audioTracks = const [
      AudioTrack('1', 'English', 'eng'),
      AudioTrack('2', 'Japanese', 'jpn')
    ];
    engines.last.audioTracks = const [
      AudioTrack('media3:9', 'Japanese', 'ja'),
      AudioTrack('media3:3', 'English', 'en')
    ];
    final errors = <String>[];
    final bindings = [
      for (var i = 0; i < 2; i++)
        WatchPartyPlayerBinding(
            controller: controllers[i],
            engine: engines[i],
            media: partyMedia,
            source: i == 0 ? firstSource : secondSource,
            isActive: () => true,
            onError: errors.add)
    ];
    await tester.pump();
    await engines.first.selectAudio(engines.first.audioTracks.last);
    await tester.pump();
    expect(engines.first.selectedAudio.id, '2');
    expect(engines.last.selectedAudio.id, 'media3:9');
    expect(server.commands.map((command) => command['command']), ['audio']);
    await engines.last.setVolume(.2);
    expect(engines.first.volume, 1);
    expect(engines.last.volume, .2);
    await engines.first.play();
    await tester.pump();
    expect(engines.every((engine) => engine.playing), isTrue);
    await engines.last.pause();
    await tester.pump();
    expect(engines.every((engine) => !engine.playing), isTrue);
    await engines.last.play();
    await tester.pump();
    expect(engines.every((engine) => engine.playing), isTrue);
    await engines.first.pause();
    await tester.pump();
    expect(engines.every((engine) => !engine.playing), isTrue);
    await controllers.first.configure(true);
    await engines.last.selectAudio(engines.last.audioTracks.last);
    expect(engines.last.selectedAudio.id, 'media3:9');
    expect(errors.last, 'partyHostRequired');
    await engines.first.play();
    await tester.pump();
    expect(engines.every((engine) => engine.playing), isTrue);
    await controllers.first.setSourceLocked(true);
    await tester.pump();
    expect(engines.first.playing, isTrue);
    expect(engines.last.playing, isFalse);
    await engines.last.play();
    expect(engines.last.playing, isFalse);
    expect(errors.last, 'partySourceLockedMismatch');
    await expectLater(
        controllers.last.command('play',
            mediaKey: partyMedia.key, sourceKey: secondSource.key),
        throwsA(isA<WatchPartyException>()));
    // Host-only authorization runs before source validation on the server.
    await controllers.first.configure(false);
    await expectLater(
        controllers.last.command('play',
            mediaKey: partyMedia.key, sourceKey: secondSource.key),
        throwsA(predicate((error) =>
            error is WatchPartyException && error.code == 'source_mismatch')));
    for (final binding in bindings) {
      binding.dispose();
    }
    for (final controller in controllers) {
      controller.dispose();
    }
    for (final engine in engines) {
      engine.dispose();
    }
  });
  testWidgets('two nonseekable Core devices can start aligned but reject drift',
      (tester) async {
    for (final initialPosition in [0, 10000]) {
      final server = WatchPartyTestServer(playing: true);
      server.room['position_ms'] = initialPosition;
      final controllers = [partyHostId, partyGuestId]
          .map((id) => WatchPartyController(server.client(id),
              deviceId: id,
              clock: WatchPartyClock(monotonicMs: () => server.now)))
          .toList();
      for (final controller in controllers) {
        controller.bindIdentity(controller.deviceId, partyProfileId);
        await controller.join('ABCDEFGH');
      }
      final backends = [
        _SessionBackend()..canSeek = false,
        _SessionBackend()..canSeek = false
      ];
      final sessions = [
        for (final backend in backends)
          PlaybackSession(
              request: PlaybackRequest(
                  item: partyMedia.item,
                  url: 'https://example.test/nonseekable',
                  streamName: 'Test source',
                  videoId: partyMedia.videoId),
              createBackend: () => backend,
              ownership: PlaybackOwnership(),
              checkpointWriter: PlaybackCheckpointWriter(),
              periodicInterval: const Duration(days: 1))
      ];
      for (final session in sessions) {
        expect(
            (await session.open(session.request.url, playWhenReady: false))
                .applied,
            isTrue);
        expect(session.canSeek, isFalse);
        // This is the real Core command outcome that initial alignment used
        // to require, even for an already exact zero-start position.
        expect((await session.seekTo(Duration.zero)).status,
            PlaybackCommandStatus.unsupported);
      }
      final errors = <String>[];
      final bindings = [
        for (var i = 0; i < sessions.length; i++)
          WatchPartyPlayerBinding(
              controller: controllers[i],
              engine: sessions[i],
              media: partyMedia,
              isActive: () => !sessions[i].isClosing,
              onError: errors.add)
      ];
      await tester.pump();
      expect(
          sessions.every((session) => session.playing), initialPosition == 0);
      expect(
          errors,
          initialPosition == 0
              ? isEmpty
              : ['partySyncFailed', 'partySyncFailed']);
      expect(
          backends.every((backend) => !backend.engine.calls.contains('seek')),
          isTrue);
      server.now = 500;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
          sessions.every((session) => session.playing), initialPosition == 0);
      for (final binding in bindings) {
        binding.dispose();
      }
      for (final session in sessions) {
        await session.close();
        session.dispose();
      }
      for (final controller in controllers) {
        controller.dispose();
      }
    }
  });

  testWidgets('two Core session lanes preserve authority and report rejection',
      (tester) async {
    final server = WatchPartyTestServer();
    final controllers = [partyHostId, partyGuestId]
        .map((id) => WatchPartyController(server.client(id),
            deviceId: id,
            clock: WatchPartyClock(monotonicMs: () => server.now)))
        .toList();
    for (final c in controllers) {
      c.bindIdentity(c.deviceId, partyProfileId);
      await c.join('ABCDEFGH');
    }
    final backends = [_SessionBackend(), _SessionBackend()];
    backends.first.engine.audioTracks = const [
      AudioTrack('1', 'English', 'eng'),
      AudioTrack('2', 'Japanese', 'jpn')
    ];
    backends.last.engine.audioTracks = const [
      AudioTrack('media3:9', 'Japanese', 'ja'),
      AudioTrack('media3:3', 'English', 'en')
    ];
    final sessions = [
      for (final backend in backends)
        PlaybackSession(
            request: PlaybackRequest(
                item: partyMedia.item,
                url: 'https://example.test/video',
                streamName: 'Test source',
                videoId: partyMedia.videoId),
            createBackend: () => backend,
            ownership: PlaybackOwnership(),
            checkpointWriter: PlaybackCheckpointWriter(),
            periodicInterval: const Duration(days: 1))
    ];
    final errors = <String>[];
    final bindings = [
      for (var i = 0; i < sessions.length; i++)
        WatchPartyPlayerBinding(
            controller: controllers[i],
            engine: sessions[i],
            media: partyMedia,
            isActive: () => !sessions[i].isClosing,
            onError: errors.add)
    ];
    for (final session in sessions) {
      expect(
          (await session.open(session.request.url, playWhenReady: false))
              .applied,
          isTrue);
    }
    await tester.pump(const Duration(milliseconds: 250));
    expect(sessions.every((s) => s.ready), isTrue);
    expect(sessions.every((s) => s.position == const Duration(seconds: 10)),
        isTrue);
    await sessions.first.play();
    await tester.pump();
    expect(sessions.every((s) => s.playing), isTrue);
    await sessions.last.pause();
    await tester.pump();
    expect(sessions.every((s) => !s.playing), isTrue);
    server.now = 1000;
    await sessions.first.seekTo(const Duration(seconds: 50));
    await tester.pump(const Duration(milliseconds: 500));
    expect(sessions.every((s) => s.position == const Duration(seconds: 50)),
        isTrue);
    await sessions.last.setRate(1.25);
    await tester.pump();
    expect(sessions.every((s) => s.rate == 1.25), isTrue);
    expect(errors, isEmpty);
    await sessions.first.selectAudio(backends.first.engine.audioTracks.last);
    await tester.pump();
    expect(sessions.first.selectedAudio.id, '2');
    expect(sessions.last.selectedAudio.id, 'media3:9');
    await sessions.first.play();
    await tester.pump();
    // The real session catches native exceptions and returns a failed result.
    // The binding must not mistake that result for successful reconciliation.
    for (final backend in backends) {
      backend.engine.failSeek = true;
    }
    server.now = 2000;
    await sessions.first.seekTo(const Duration(seconds: 60));
    await tester.pump(const Duration(milliseconds: 500));
    expect(errors, ['partySyncFailed', 'partySyncFailed']);
    expect(sessions.every((s) => s.failed && s.playing), isTrue);
    await sessions.last.pause();
    await tester.pump();
    expect(sessions.every((s) => !s.playing), isTrue);
    expect(server.commands.map((c) => c['command']),
        ['play', 'pause', 'seek', 'rate', 'audio', 'play', 'seek', 'pause']);
    for (final binding in bindings) {
      binding.dispose();
    }
    for (final session in sessions) {
      await session.close();
      session.dispose();
    }
    for (final controller in controllers) {
      controller.dispose();
    }
  });
  testWidgets('two devices use server authority for play pause seek and rate',
      (tester) async {
    final server = WatchPartyTestServer();
    final host = WatchPartyController(server.client(partyHostId),
        deviceId: partyDeviceId,
        clock: WatchPartyClock(monotonicMs: () => server.now));
    final guest = WatchPartyController(server.client(partyGuestId),
        deviceId: 'other-device',
        clock: WatchPartyClock(monotonicMs: () => server.now));
    host.bindIdentity('host-account', partyProfileId);
    guest.bindIdentity('guest-account', partyProfileId);
    await host.join('ABCDEFGH');
    await guest.join('ABCDEFGH');
    final first = _Engine(), second = _Engine();
    final firstBinding = WatchPartyPlayerBinding(
        controller: host,
        engine: first,
        media: partyMedia,
        isActive: () => true);
    final secondBinding = WatchPartyPlayerBinding(
        controller: guest,
        engine: second,
        media: partyMedia,
        isActive: () => true);
    await tester.pump();
    expect(host.snapshot!.selfId, partyHostId);
    expect(guest.snapshot!.selfId, partyGuestId);
    expect(first.position, const Duration(seconds: 10));
    expect(second.position, first.position);

    await first.play();
    await tester.pump();
    expect(first.playing, isTrue);
    expect(second.playing, isTrue);
    await second.pause();
    await tester.pump();
    expect(first.playing, isFalse);
    expect(second.playing, isFalse);

    server.now = 1000;
    await second.seekTo(const Duration(seconds: 45));
    await tester.pump(const Duration(milliseconds: 500));
    expect(first.position, const Duration(seconds: 45));
    expect(second.position, first.position);
    await first.setRate(1.5);
    await tester.pump();
    expect(first.rate, 1.5);
    expect(second.rate, 1.5);
    expect(server.commands.map((c) => c['command']),
        ['play', 'pause', 'seek', 'rate']);

    // A locked guest cannot change local or authoritative transport.
    await host.configure(true);
    await second.play();
    await tester.pump();
    expect(first.playing, isFalse);
    expect(second.playing, isFalse);
    expect(server.commands.length, 4);

    // A local background pause is reconciled on return, including a missed
    // private broadcast; the detached engine never drives the room.
    final guestGateway = guest.gateway as WatchPartyTestGateway;
    secondBinding.setForeground(false);
    guestGateway.setConnected(false);
    await first.play();
    await tester.pump();
    expect(first.playing, isTrue);
    expect(second.playing, isFalse);
    guestGateway.setConnected(true);
    secondBinding.setForeground(true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(second.playing, isTrue);
    expect(server.commands.length, 5);
    secondBinding.dispose();
    final otherTitle = WatchPartyPlayerBinding(
        controller: guest,
        engine: second,
        media: const WatchPartyMedia(
            id: 'tt9999', type: 'movie', title: 'Other', videoId: 'tt9999'),
        isActive: () => true);
    await second.pause();
    await tester.pump();
    expect(first.playing, isTrue);
    expect(server.commands.length, 5);
    otherTitle.dispose();
    firstBinding.dispose();
    host.dispose();
    guest.dispose();
    first.dispose();
    second.dispose();
  });

  testWidgets(
      'a pause received during a seek is applied without waiting a tick',
      (tester) async {
    final g = FakeWatchPartyGateway()..data = partyData(playing: true);
    final c = WatchPartyController(g,
        deviceId: partyDeviceId, clock: WatchPartyClock(monotonicMs: () => 0));
    c.bindIdentity('account', partyProfileId);
    await c.join('ABCDEFGH');
    final e = _Engine()
      ..playing = true
      ..seekGate = Completer<void>();
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    expect(e.calls, ['seek']);
    g.data = partyData(playing: false, revision: 2);
    g.event!('snapshot', clonePartyData(g.data));
    e.seekGate!.complete();
    await tester.pump();
    expect(e.playing, isFalse);
    binding.dispose();
    c.dispose();
    e.dispose();
  });

  testWidgets('authoritative pause stops a playing engine before readiness',
      (tester) async {
    final g = FakeWatchPartyGateway();
    final c = WatchPartyController(g,
        deviceId: partyDeviceId, clock: WatchPartyClock(monotonicMs: () => 0));
    c.bindIdentity('account', partyProfileId);
    await c.join('ABCDEFGH');
    final e = _Engine()
      ..ready = false
      ..playing = true;
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    expect(e.calls, ['pause']);
    expect(e.playing, isFalse);
    binding.dispose();
    c.dispose();
    e.dispose();
  });

  testWidgets(
      'a failed initial seek cannot play during the correction cooldown',
      (tester) async {
    var mono = 0;
    final g = FakeWatchPartyGateway()..data = partyData(playing: true);
    final c = WatchPartyController(g,
        deviceId: partyDeviceId,
        clock: WatchPartyClock(monotonicMs: () => mono));
    c.bindIdentity('account', partyProfileId);
    await c.join('ABCDEFGH');
    final e = _Engine()..failSeek = true;
    final errors = <String>[];
    final binding = WatchPartyPlayerBinding(
        controller: c,
        engine: e,
        media: partyMedia,
        isActive: () => true,
        onError: errors.add);
    await tester.pump();
    mono = 250;
    await tester.pump(const Duration(milliseconds: 250));
    mono = 500;
    await tester.pump(const Duration(milliseconds: 250));
    expect(e.playing, isFalse);
    expect(e.calls.where((call) => call == 'play'), isEmpty);
    expect(errors, ['partySyncFailed']);
    binding.dispose();
    c.dispose();
    e.dispose();
  });

  testWidgets('an authoritative pause still stops both engines when seek fails',
      (tester) async {
    final server = WatchPartyTestServer(playing: true);
    final controllers = [partyHostId, partyGuestId]
        .map((id) => WatchPartyController(server.client(id),
            deviceId: id,
            clock: WatchPartyClock(monotonicMs: () => server.now)))
        .toList();
    for (final c in controllers) {
      c.bindIdentity(c.deviceId, partyProfileId);
      await c.join('ABCDEFGH');
    }
    final engines = [_Engine(), _Engine()];
    final bindings = [
      for (var i = 0; i < controllers.length; i++)
        WatchPartyPlayerBinding(
            controller: controllers[i],
            engine: engines[i],
            media: partyMedia,
            isActive: () => true)
    ];
    await tester.pump();
    expect(engines.every((e) => e.playing), isTrue);
    server.now = 1000;
    // Models a backend that loses seek capability while still playing. The
    // play/pause command must not depend on that optional correction.
    for (final e in engines) {
      e.failSeek = true;
    }
    await engines.first.pause();
    await tester.pump(const Duration(milliseconds: 500));
    expect(server.room['playing'], isFalse);
    expect(engines.every((e) => !e.playing), isTrue);
    expect(server.commands.map((c) => c['command']), ['pause']);
    for (final b in bindings) {
      b.dispose();
    }
    for (final c in controllers) {
      c.dispose();
    }
    for (final e in engines) {
      e.dispose();
    }
  });

  testWidgets('paused-open buffering can accept room play intent',
      (tester) async {
    final g = FakeWatchPartyGateway()..data = partyData(playing: true);
    final c = WatchPartyController(g,
        deviceId: partyDeviceId, clock: WatchPartyClock(monotonicMs: () => 0));
    c.bindIdentity('a', partyProfileId);
    await c.join('ABCDEFGH');
    final e = _Engine()..buffering = true;
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    expect(e.playing, isTrue);
    e.buffering = false;
    await tester.pump(const Duration(milliseconds: 250));
    expect(e.position, const Duration(seconds: 10));
    binding.dispose();
    c.dispose();
    e.dispose();
  });
  testWidgets('host completion stops the shared clock instead of replaying EOF',
      (tester) async {
    final g = FakeWatchPartyGateway()
      ..data = partyData(selfId: partyHostId, playing: true);
    final c = WatchPartyController(g, deviceId: partyDeviceId);
    c.bindIdentity('a', partyProfileId);
    await c.join('ABCDEFGH');
    final e = _Engine()..completed = true;
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.snapshot!.playing, isFalse);
    final commands =
        g.requests.where((p) => p['p_action'] == 'command').toList();
    expect(commands.length, 1);
    expect((commands.single['p_payload'] as Map)['command'], 'pause');
    expect(e.calls.where((s) => s == 'play'), isEmpty);
    binding.dispose();
    c.dispose();
    e.dispose();
  });
  Future<WatchPartyController> controller(FakeWatchPartyGateway g,
      {WatchPartyClock? clock}) async {
    final c = WatchPartyController(g, deviceId: partyDeviceId, clock: clock);
    c.bindIdentity('a', partyProfileId);
    await Future<void>.value();
    await c.join('ABCDEFGH');
    return c;
  }

  testWidgets('locked guest cannot issue native play or room commands',
      (tester) async {
    final g = FakeWatchPartyGateway();
    final c = await controller(g);
    final e = _Engine();
    final errors = <String>[];
    final binding = WatchPartyPlayerBinding(
        controller: c,
        engine: e,
        media: partyMedia,
        isActive: () => true,
        onError: errors.add);
    await tester.pump();
    e.calls.clear();
    await e.play();
    await tester.pump();
    expect(e.calls, isEmpty);
    expect(errors, ['partyHostRequired']);
    expect(g.requests.where((p) => p['p_action'] == 'command'), isEmpty);
    binding.dispose();
    c.dispose();
    e.dispose();
  });
  testWidgets('group seek goes through authority and applies without an echo',
      (tester) async {
    var mono = 0;
    final g = FakeWatchPartyGateway()..data = partyData(hostOnly: false);
    final c =
        await controller(g, clock: WatchPartyClock(monotonicMs: () => mono));
    final e = _Engine();
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    await e.seekTo(const Duration(seconds: 40));
    mono = 1000;
    await tester.pump(const Duration(milliseconds: 500));
    expect(e.position, const Duration(seconds: 40));
    expect(g.requests.where((p) => p['p_action'] == 'command').length, 1);
    binding.dispose();
    c.dispose();
    e.dispose();
  });
  testWidgets('rate nudge is local and returns to base when the room is left',
      (tester) async {
    var mono = 0;
    final g = FakeWatchPartyGateway()..data = partyData(playing: true);
    final c =
        await controller(g, clock: WatchPartyClock(monotonicMs: () => mono));
    final e = _Engine();
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    mono = 1000;
    await tester.pump(const Duration(milliseconds: 250));
    expect(e.rate, closeTo(1.05, 0.001));
    expect(g.requests.where((p) => p['p_action'] == 'command'), isEmpty);
    await c.leave();
    await tester.pump();
    expect(e.rate, 1);
    binding.dispose();
    c.dispose();
    e.dispose();
  });
  testWidgets('disposal during a seek cannot apply late play or speed changes',
      (tester) async {
    final g = FakeWatchPartyGateway()..data = partyData(playing: true);
    final c = await controller(g);
    final e = _Engine()..seekGate = Completer<void>();
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    expect(e.calls, ['seek']);
    binding.dispose();
    e.seekGate!.complete();
    await tester.pump();
    expect(e.calls, ['seek']);
    expect(e.watchPartyCommand, isNull);
    c.dispose();
    e.dispose();
  });
  testWidgets(
      'background pauses stay local and resume reconciles with the room',
      (tester) async {
    final g = FakeWatchPartyGateway()..data = partyData(playing: true);
    final c = await controller(g);
    final e = _Engine();
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    binding.setForeground(false);
    await e.pause();
    await tester.pump(const Duration(seconds: 1));
    expect(e.playing, isFalse);
    expect(g.requests.where((p) => p['p_action'] == 'command'), isEmpty);
    binding.setForeground(true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(e.playing, isTrue);
    binding.dispose();
    c.dispose();
    e.dispose();
  });
  testWidgets('different source runtimes retain shared pause and play controls',
      (tester) async {
    final g = FakeWatchPartyGateway()
      ..data = partyData(hostOnly: false, playing: true);
    final c = await controller(g);
    final e = _Engine()..duration = const Duration(minutes: 40);
    final errors = <String>[];
    final binding = WatchPartyPlayerBinding(
        controller: c,
        engine: e,
        media: partyMedia,
        isActive: () => true,
        onError: errors.add);
    await tester.pump();
    expect(e.playing, isTrue);
    expect(errors, ['partyDifferentVersion']);
    await e.pause();
    await tester.pump();
    expect(e.playing, isFalse);
    expect(c.snapshot!.playing, isFalse);
    await e.play();
    await tester.pump();
    expect(e.playing, isTrue);
    expect(c.snapshot!.playing, isTrue);
    expect(
        g.requests
            .where((p) => p['p_action'] == 'command')
            .map((p) => (p['p_payload'] as Map)['command']),
        ['pause', 'play']);
    binding.dispose();
    c.dispose();
    e.dispose();
  });
}
