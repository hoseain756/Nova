import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/playback_resume_policy.dart';
import '../../../core/torrent/torrent_models.dart';

import '../engine/playback_engine.dart';
import 'playback_checkpoint.dart';
import 'playback_progress.dart';
import 'playback_state.dart';

abstract interface class PlaybackBackend {
  PlaybackEngine get engine;
  Future<void> openPaused(String url, Map<String, String>? headers);
  Future<bool?> seekable();
  Future<Uint8List?> captureFrame();
  Future<void> close();
}

class MediaKitSessionBackend implements PlaybackBackend {
  MediaKitSessionBackend() : engine = MediaKitEngine();
  @override
  final MediaKitEngine engine;
  @override
  Future<void> openPaused(String url, Map<String, String>? headers) =>
      engine.open(url, httpHeaders: headers, playWhenReady: false);
  @override
  Future<bool?> seekable() => engine.querySeekable();
  @override
  Future<Uint8List?> captureFrame() => engine.captureFrame();
  @override
  Future<void> close() => engine.close();
}

/// A positive backend assertion that repeating this operation is safe.
/// The native adapter currently makes no such assertion; ambiguous errors
/// never trigger automatic retries or decoder replacement.
class PlaybackRetryableException implements Exception {
  const PlaybackRetryableException();
}

/// Exclusive native ownership across route transitions, including unexpected
/// pop/push races. A failed retirement remains a barrier until app restart.
class PlaybackRetirementException implements Exception {
  const PlaybackRetirementException();
}

class PlaybackOwnership {
  PlaybackOwnership({this.retirementTimeout = const Duration(seconds: 15)});

  static final shared = PlaybackOwnership();
  final Duration retirementTimeout;
  PlaybackSession? _owner;
  bool _retirementFailed = false;

  /// Detail-page torrent preparation must not deactivate the active torrent
  /// until its previous Core player has retired native output.
  Future<void> retireCurrent() async {
    if (_retirementFailed) throw const PlaybackRetirementException();
    final previous = _owner;
    if (previous == null) return;
    try {
      await previous.close().timeout(retirementTimeout);
      await previous.drainResolution().timeout(retirementTimeout);
    } catch (_) {
      debugPrint('[NOVA] Core retirement barrier failed at '
          '${previous.closeStage}');
      _retirementFailed = true;
      throw const PlaybackRetirementException();
    }
    if (identical(_owner, previous)) _owner = null;
  }

  Future<bool> acquire(PlaybackSession session) async {
    if (_retirementFailed) throw const PlaybackRetirementException();
    final previous = _owner;
    _owner = session;
    if (previous != null && !identical(previous, session)) {
      try {
        await previous.close().timeout(retirementTimeout);
        await previous.drainResolution().timeout(retirementTimeout);
      } catch (_) {
        debugPrint('[NOVA] Core ownership acquisition failed at '
            '${previous.closeStage}');
        _retirementFailed = true;
        throw const PlaybackRetirementException();
      }
    }
    return identical(_owner, session) && !session.isClosing;
  }
}

class PlaybackContinuity {
  PlaybackContinuity(PlaybackSession session, {Duration? position})
      : position = position ?? session.position,
        playing = session.playIntent,
        rate = session.rate,
        volume = session.volume,
        audio = session.selectedAudio,
        subtitle = session.selectedSubtitle,
        subtitleDelayMs = session._subtitleDelayMs,
        audioDelayMs = session._audioDelayMs,
        resumeResolved = session.resumeResolved;
  PlaybackContinuity._restrict(PlaybackContinuity previous, bool allowed)
      : position = previous.position,
        playing = previous.playing && allowed,
        rate = previous.rate,
        volume = previous.volume,
        audio = previous.audio,
        subtitle = previous.subtitle,
        subtitleDelayMs = previous.subtitleDelayMs,
        audioDelayMs = previous.audioDelayMs,
        resumeResolved = previous.resumeResolved;
  PlaybackContinuity restrictPlay(bool allowed) =>
      PlaybackContinuity._restrict(this, allowed);
  final Duration position;
  final bool playing;
  final double rate;
  final double volume;
  final AudioTrack audio;
  final SubtitleTrack subtitle;
  final int subtitleDelayMs;
  final int audioDelayMs;
  final bool resumeResolved;
}

/// Route-owned command lane and projections. No raw event drives page-wide
/// progress rebuilds; exact state is read directly from the current backend.
class PlaybackSession extends PlaybackEngine {
  PlaybackSession({
    required PlaybackRequest request,
    PlaybackBackend Function()? createBackend,
    this.createFallbackBackend,
    this.canFallback,
    this.requiresTimingFallback,
    PlaybackOwnership? ownership,
    PlaybackCheckpointWriter? checkpointWriter,
    PlaybackCheckpointSink? persist,
    bool Function()? canRecord,
    this.startupSettings = const PlaybackStartupSettings(),
    bool startInBackground = false,
    this.onExactProgress,
    this.periodicInterval = const Duration(seconds: 5),
    this.seekabilityProbeInterval = const Duration(milliseconds: 500),
    this.cleanupSaveTimeout = const Duration(seconds: 3),
  })  : _request = request,
        _createBackend = createBackend ?? MediaKitSessionBackend.new,
        _ownership = ownership ?? PlaybackOwnership.shared,
        _writer = checkpointWriter ?? PlaybackCheckpointWriter.shared,
        _persist = persist,
        _canRecord = canRecord ?? (() => true) {
    _backgrounded = startInBackground;
    if (request.torrent != null) _leases.add(request.torrent!);
    _coalescer = PlaybackProgressCoalescer(
      contentGeneration: 1,
      sourceGeneration: 0,
      onProgress: (sample) {
        if (!isClosing && sample.sourceGeneration == _generation) {
          progress.value = sample;
        }
      },
    );
  }

  PlaybackRequest _request;
  PlaybackRequest get request => _request;
  final PlaybackBackend Function() _createBackend;
  final PlaybackBackend Function()? createFallbackBackend;
  final bool Function(PlaybackBackend backend)? canFallback;
  final bool Function(PlaybackBackend backend)? requiresTimingFallback;
  bool _usingFallback = false;
  bool _fallbackQueued = false;
  Future<PlaybackCommandResult>? _timingSwitch;
  final PlaybackOwnership _ownership;
  final PlaybackCheckpointWriter _writer;
  final PlaybackCheckpointSink? _persist;
  final bool Function() _canRecord;
  final PlaybackStartupSettings startupSettings;
  final Set<PreparedTorrent> _leases = Set.identity();
  final void Function(PlaybackSession session)? onExactProgress;
  final Duration periodicInterval;
  final Duration seekabilityProbeInterval;
  final Duration cleanupSaveTimeout;
  final progress = ValueNotifier<PlaybackProgress?>(null);
  late final PlaybackProgressCoalescer _coalescer;
  PlaybackBackend? _backend;
  VoidCallback? _backendListener;
  Future<void> _lane = Future.value();
  final Set<Completer<PlaybackCommandResult>> _pendingCommands = {};
  bool _commandInFlight = false;
  Future<void> _resolutionLane = Future.value();
  Future<void>? _closeFuture;
  Timer? _periodic;
  Timer? _seekabilityProbe;
  int _seekabilityProbeAttempts = 0;
  bool _seekabilityProbeInFlight = false;
  PlaybackPhase phase = PlaybackPhase.idle;
  PlaybackFailure? failure;
  bool persistenceFailed = false;
  bool _prepared = false;
  bool _nativeRetired = false;
  bool _playIntent = false;
  Duration _retryPosition = Duration.zero;
  Duration? _pendingSeekPosition;
  bool resumeResolved = true;
  bool? _seekable;
  int _generation = 0;
  int _intentRevision = 0;
  int _sequence = 0;
  int _subtitleDelayMs = 0;
  int _audioDelayMs = 0;
  final _checkpointOwner = Object();
  Object _sourceIdentity = Object();
  Object? _resolutionIdentity;
  Object? _transportProjection;
  final Set<String> _retried = {};
  Future<void>? _backgroundWork;
  bool _backgrounded = false;
  bool _notifiersDisposed = false;
  String openStage = 'idle';
  String closeStage = 'idle';

  Object get interactionIdentity => _sourceIdentity;
  bool owns(Object? identity) =>
      !isClosing && identical(identity, _sourceIdentity);

  Object beginResolution() {
    final identity = _resolutionIdentity = Object();
    if (!isClosing) {
      phase = PlaybackPhase.resolving;
      _notify();
    }
    return identity;
  }

  bool acceptsResolution(Object? identity) =>
      identity != null && identical(identity, _resolutionIdentity);
  void cancelResolution() => _resolutionIdentity = null;

  PlaybackHandoffIntent handoffIntent(
          Object resolutionIdentity, bool playing) =>
      PlaybackHandoffIntent(resolutionIdentity, _intentRevision, playing);
  bool canRestoreHandoff(PlaybackHandoffIntent intent) =>
      acceptsResolution(intent.resolutionIdentity) &&
      intent.intentRevision == _intentRevision &&
      intent.playing &&
      !_backgrounded &&
      failure == null;

  Future<T> resolve<T>(Object identity, Future<T> Function() action) {
    final result = Completer<T>();
    _resolutionLane = _resolutionLane.then((_) async {
      if (!acceptsResolution(identity)) {
        result.completeError(StateError('Resolution cancelled'));
        return;
      }
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        if (!isClosing && acceptsResolution(identity)) {
          phase = playing ? PlaybackPhase.playing : PlaybackPhase.paused;
          _notify();
        }
      }
    });
    return result.future;
  }

  Future<void> drainResolution() => _resolutionLane;

  Future<void> closeForResolution(Object identity) {
    if (!acceptsResolution(identity)) return Future.value();
    final closing = close();
    _resolutionIdentity = identity;
    return closing;
  }

  bool get playIntent => _playIntent;
  bool get isClosing =>
      phase == PlaybackPhase.closing || phase == PlaybackPhase.closed;
  bool get canSeek => _seekable == true && duration > Duration.zero;
  PlaybackEngine? get nativeEngine => _backend?.engine;

  PlaybackEngine? get _raw => _backend?.engine;
  @override
  bool get ready => _prepared;
  @override
  bool get playing => _raw?.playing ?? false;
  @override
  bool get buffering => _raw?.buffering ?? false;
  @override
  bool get completed => _raw?.completed ?? false;
  @override
  bool get failed => failure != null;
  @override
  String? get errorMessage => failure?.code;
  @override
  Duration get position => _raw?.position ?? Duration.zero;
  @override
  Duration get duration => _raw?.duration ?? Duration.zero;
  @override
  Duration get bufferedEnd => _raw?.bufferedEnd ?? Duration.zero;
  @override
  double get rate => _raw?.rate ?? 1;
  @override
  double get volume => _raw?.volume ?? 1;
  @override
  bool get muted => _raw?.muted ?? false;
  @override
  List<AudioTrack> get audioTracks => _raw?.audioTracks ?? const [];
  @override
  List<SubtitleTrack> get subtitleTracks => _raw?.subtitleTracks ?? const [];
  @override
  AudioTrack get selectedAudio => _raw?.selectedAudio ?? AudioTrack.auto();
  @override
  SubtitleTrack get selectedSubtitle =>
      _raw?.selectedSubtitle ?? SubtitleTrack.auto();
  @override
  Stream<List<String>> get subtitleTexts =>
      _raw?.subtitleTexts ?? const Stream.empty();
  @override
  List<String> get subtitleTextSnapshot =>
      _raw?.subtitleTextSnapshot ?? const [];

  void _notify() {
    if (!_notifiersDisposed) notifyListeners();
  }

  PlaybackCommandResult _cancelled() =>
      const PlaybackCommandResult(PlaybackCommandStatus.cancelled);

  Future<PlaybackCommandResult> _command(
    String operation,
    Future<void> Function(int generation) action,
  ) {
    final generation = _generation;
    final result = Completer<PlaybackCommandResult>();
    _pendingCommands.add(result);
    void complete(PlaybackCommandResult value) {
      if (!result.isCompleted) result.complete(value);
      _pendingCommands.remove(result);
    }

    _lane = _lane.then((_) async {
      if (isClosing || generation != _generation) {
        complete(_cancelled());
        return;
      }
      if (operation != 'open' && _raw == null) {
        complete(
            const PlaybackCommandResult(PlaybackCommandStatus.unsupported));
        return;
      }
      _commandInFlight = true;
      try {
        try {
          await action(generation);
        } on PlaybackRetryableException {
          if (!_retried.add(operation) ||
              isClosing ||
              generation != _generation) {
            rethrow;
          }
          await action(generation);
        }
        complete(isClosing || generation != _generation
            ? _cancelled()
            : const PlaybackCommandResult(PlaybackCommandStatus.applied));
      } on PlaybackRetirementException {
        if (isClosing || generation != _generation) {
          complete(_cancelled());
          return;
        }
        failure = PlaybackFailure(
            PlaybackFailureCategory.operation, 'ownership', generation);
        phase = PlaybackPhase.failed;
        _notify();
        complete(PlaybackCommandResult(PlaybackCommandStatus.failed, failure));
      } on UnsupportedError {
        if (isClosing || generation != _generation) {
          complete(_cancelled());
          return;
        }
        if (operation == 'open') {
          failure = PlaybackFailure(
              PlaybackFailureCategory.source, operation, generation);
          phase = PlaybackPhase.failed;
          _notify();
        }
        complete(
            const PlaybackCommandResult(PlaybackCommandStatus.unsupported));
      } catch (_) {
        if (isClosing || generation != _generation) {
          complete(_cancelled());
          return;
        }
        failure ??= PlaybackFailure(
            operation == 'open'
                ? PlaybackFailureCategory.unknown
                : PlaybackFailureCategory.operation,
            operation,
            generation);
        phase = PlaybackPhase.failed;
        _notify();
        complete(PlaybackCommandResult(PlaybackCommandStatus.failed, failure));
      } finally {
        _commandInFlight = false;
      }
    });
    return result.future;
  }

  void _invalidateSource() {
    _pendingSeekPosition = null;
    _seekabilityProbe?.cancel();
    _seekabilityProbe = null;
    _seekabilityProbeAttempts = 0;
    _seekabilityProbeInFlight = false;
    _seekable = null;
    final raw = _raw;
    final listener = _backendListener;
    if (raw != null && listener != null) raw.removeListener(listener);
    _backendListener = null;
    _generation++;
    _sourceIdentity = Object();
    _coalescer.reset(contentGeneration: 1, sourceGeneration: _generation);
    progress.value = null;
  }

  @override
  Future<PlaybackCommandResult> open(
    String url, {
    Duration? startAt,
    Map<String, String>? httpHeaders,
    bool playWhenReady = true,
    PlaybackContinuity? continuity,
  }) {
    if (isClosing) return Future.value(_cancelled());
    final target = continuity?.position ?? startAt;
    _retryPosition = target ?? Duration.zero;
    _periodic?.cancel();
    _periodic = null;
    _invalidateSource();
    _retried.clear();
    failure = null;
    _prepared = false;
    _playIntent = (continuity?.playing ?? playWhenReady) && !_backgrounded;
    final intent = ++_intentRevision;
    phase = PlaybackPhase.opening;
    _notify();
    return _command('open', (generation) async {
      openStage = 'ownership';
      if (!await _ownership.acquire(this) || generation != _generation) return;
      openStage = 'retire_previous_backend';
      final old = _backend;
      if (old != null) {
        try {
          await old.close();
        } catch (_) {
          throw const PlaybackRetirementException();
        }
      }
      for (final lease in _leases.toList()) {
        if (!identical(lease, request.torrent)) {
          await lease.stop();
          _leases.remove(lease);
        }
      }
      if (isClosing || generation != _generation) return;
      _nativeRetired = false;
      var backend = _backend = _usingFallback && createFallbackBackend != null
          ? createFallbackBackend!()
          : _createBackend();
      _attachBackend(backend, generation);
      _notify(); // Mount the stable video child before waiting for controller readiness.
      openStage = 'backend_open';
      try {
        await backend.openPaused(url, httpHeaders);
        if (backend.engine.failed) throw StateError('Backend open failed');
      } catch (_) {
        if (isClosing || generation != _generation) return;
        if (_usingFallback ||
            createFallbackBackend == null ||
            canFallback?.call(backend) != true) {
          rethrow;
        }
        final listener = _backendListener;
        if (listener != null) backend.engine.removeListener(listener);
        openStage = 'retire_incompatible_backend';
        try {
          await backend.close();
        } catch (_) {
          throw const PlaybackRetirementException();
        }
        if (isClosing || generation != _generation) return;
        _usingFallback = true;
        failure = null;
        backend = _backend = createFallbackBackend!();
        _attachBackend(backend, generation);
        await backend.openPaused(url, httpHeaders);
      }
      if (isClosing || generation != _generation) return;
      if (backend.engine.failed) throw StateError('Backend open failed');
      _seekable = await backend.seekable();
      openStage = 'restore';
      if (isClosing || generation != _generation) return;
      phase = PlaybackPhase.prepared;
      if (continuity != null) {
        await _restoreContinuity(backend, continuity, generation);
      } else {
        await backend.engine
            .setSubtitleDelayMs(startupSettings.subtitleDelayMs);
        if (isClosing || generation != _generation) return;
        await backend.engine.setAudioDelayMs(startupSettings.audioDelayMs);
        if (isClosing || generation != _generation) return;
        _subtitleDelayMs = startupSettings.subtitleDelayMs;
        _audioDelayMs = startupSettings.audioDelayMs;
        if (startupSettings.subtitlesOff) {
          await backend.engine.selectSubtitle(SubtitleTrack.no());
        }
      }
      if (isClosing || generation != _generation) return;
      if (target != null && target > Duration.zero) {
        openStage = 'resume_capability';
        if (!canSeek) await _waitForStartupSeekability(backend, generation);
        if (isClosing || generation != _generation) return;
        if (!canSeek) throw UnsupportedError('Source cannot preserve position');
        openStage = 'resume_seek_command';
        await backend.engine.seekTo(target);
        if (isClosing || generation != _generation) return;
      }
      openStage = 'play';
      if (_playIntent && intent == _intentRevision) await backend.engine.play();
      if (isClosing || generation != _generation) return;
      _prepared = true;
      openStage = 'ready';
      phase =
          backend.engine.playing ? PlaybackPhase.playing : PlaybackPhase.paused;
      _publishBackend(backend, generation);
      _periodic ??= Timer.periodic(periodicInterval,
          (_) => unawaited(checkpoint(CheckpointCause.periodic)));
      _notify();
    });
  }

  void _attachBackend(PlaybackBackend backend, int generation) {
    void listener() => _publishBackend(backend, generation);
    _backendListener = listener;
    backend.engine.addListener(listener);
  }

  void _publishBackend(PlaybackBackend backend, int generation) {
    if (isClosing ||
        generation != _generation ||
        !identical(backend, _backend)) {
      return;
    }
    final raw = backend.engine;
    // A failed native source can reset its position to zero before retry.
    // A seek may also finish before its position stream catches up: do not
    // replace explicit seek intent with an old native position in that gap.
    final pendingSeek = _pendingSeekPosition;
    if (pendingSeek != null) {
      if ((raw.position - pendingSeek).abs() <= const Duration(seconds: 3)) {
        _pendingSeekPosition = null;
        _retryPosition = raw.position;
      }
    } else if (raw.position > Duration.zero) {
      _retryPosition = raw.position;
    }
    if (_prepared && raw.duration > Duration.zero && _seekable != true) {
      _scheduleSeekabilityProbe(backend, generation);
    }
    _coalescer.add(PlaybackProgress(
        contentGeneration: 1,
        sourceGeneration: generation,
        position: raw.position,
        duration: raw.duration,
        bufferedEnd: raw.bufferedEnd));
    if (raw.failed && failure == null) {
      failure = PlaybackFailure(
          classifyPlaybackFailure(raw.errorMessage), 'backend', generation);
      phase = PlaybackPhase.failed;
      if (_prepared &&
          !_usingFallback &&
          !_fallbackQueued &&
          createFallbackBackend != null &&
          canFallback?.call(backend) == true) {
        _fallbackQueued = true;
        final saved = PlaybackContinuity(this, position: _retryPosition);
        scheduleMicrotask(() {
          _fallbackQueued = false;
          if (isClosing ||
              generation != _generation ||
              !identical(backend, _backend)) {
            return;
          }
          _usingFallback = true;
          unawaited(open(request.url,
              httpHeaders: request.headers,
              continuity: saved.restrictPlay(_playIntent && !_backgrounded)));
        });
      }
    } else if (_prepared &&
        failure == null &&
        phase != PlaybackPhase.resolving) {
      phase = raw.playing ? PlaybackPhase.playing : PlaybackPhase.paused;
    }
    final projection = (
      ready,
      raw.playing,
      raw.buffering,
      raw.completed,
      failure,
      raw.rate,
      raw.volume,
      Object.hashAll(raw.audioTracks),
      Object.hashAll(raw.subtitleTracks),
      raw.selectedAudio,
      raw.selectedSubtitle
    );
    onExactProgress?.call(this);
    if (projection != _transportProjection) {
      _transportProjection = projection;
      _notify();
    }
  }

  void _scheduleSeekabilityProbe(PlaybackBackend backend, int generation) {
    if (_seekabilityProbe != null ||
        _seekabilityProbeInFlight ||
        _seekabilityProbeAttempts >= 6) {
      return;
    }
    // mpv can report "no" while a paused source is opening, then expose
    // seeking after its duration and demuxer state become available.
    _seekabilityProbe = Timer(seekabilityProbeInterval, () async {
      _seekabilityProbe = null;
      if (isClosing ||
          generation != _generation ||
          !identical(backend, _backend)) {
        return;
      }
      _seekabilityProbeInFlight = true;
      _seekabilityProbeAttempts++;
      bool? value;
      try {
        value = await backend.seekable();
      } catch (_) {
        // Capability queries are advisory; keep playback running.
      } finally {
        if (generation == _generation && identical(backend, _backend)) {
          _seekabilityProbeInFlight = false;
        }
      }
      if (isClosing ||
          generation != _generation ||
          !identical(backend, _backend)) {
        return;
      }
      if (value == true) {
        _seekable = true;
        _notify();
      } else if (backend.engine.duration > Duration.zero) {
        _scheduleSeekabilityProbe(backend, generation);
      }
    });
  }

  Future<void> _waitForStartupSeekability(
      PlaybackBackend backend, int generation) async {
    for (var attempt = 0; attempt < 6 && !canSeek; attempt++) {
      await Future<void>.delayed(seekabilityProbeInterval);
      if (isClosing ||
          generation != _generation ||
          !identical(backend, _backend)) {
        return;
      }
      try {
        if (await backend.seekable() == true) {
          _seekable = true;
        }
      } catch (_) {
        // A failed capability query never authorizes a resume seek.
      }
    }
  }

  Future<void> _restoreContinuity(
      PlaybackBackend backend, PlaybackContinuity saved, int generation) async {
    final raw = backend.engine;
    await raw.setRate(saved.rate);
    if (isClosing || generation != _generation) return;
    await raw.setVolume(saved.volume);
    if (isClosing || generation != _generation) return;
    await raw.setAudioDelayMs(saved.audioDelayMs);
    if (isClosing || generation != _generation) return;
    await raw.setSubtitleDelayMs(saved.subtitleDelayMs);
    if (isClosing || generation != _generation) return;
    _audioDelayMs = saved.audioDelayMs;
    _subtitleDelayMs = saved.subtitleDelayMs;
    final audio = raw.audioTracks.where((track) =>
        track.language == saved.audio.language &&
        track.title == saved.audio.title);
    if (saved.audio.id == 'auto') {
      await raw.selectAudio(AudioTrack.auto());
    } else if (audio.isNotEmpty) {
      await raw.selectAudio(audio.first);
    } else {
      throw UnsupportedError('Audio intent unavailable on this source');
    }
    if (isClosing || generation != _generation) return;
    if (saved.subtitle.id == 'auto') {
      await raw.selectSubtitle(SubtitleTrack.auto());
    } else if (saved.subtitle.id == 'no') {
      await raw.selectSubtitle(SubtitleTrack.no());
    } else if (saved.subtitle.uri) {
      await raw.setSubtitleUri(saved.subtitle.id, title: saved.subtitle.title);
    } else if (saved.subtitle.data) {
      await raw.selectSubtitle(saved.subtitle);
    } else {
      final subs = raw.subtitleTracks.where((track) =>
          track.language == saved.subtitle.language &&
          track.title == saved.subtitle.title);
      if (subs.isNotEmpty) {
        await raw.selectSubtitle(subs.first);
      } else {
        throw UnsupportedError('Subtitle intent unavailable on this source');
      }
    }
    if (isClosing || generation != _generation) return;
    resumeResolved = saved.resumeResolved;
  }

  Future<PlaybackCommandResult> replaceSource(PlaybackRequest next) async {
    if (next.contentKey != request.contentKey) {
      return const PlaybackCommandResult(PlaybackCommandStatus.unsupported);
    }
    final saved = PlaybackContinuity(this);
    final resolutionIdentity = beginResolution();
    final pausing = pause();
    final intent = handoffIntent(resolutionIdentity, saved.playing);
    await pausing;
    await checkpoint(CheckpointCause.source);
    if (isClosing) return _cancelled();
    if (next.torrent != null) _leases.add(next.torrent!);
    _request = next;
    final result = await open(next.url,
        httpHeaders: next.headers,
        continuity: saved.restrictPlay(canRestoreHandoff(intent)));
    return result;
  }

  Future<PlaybackCommandResult> retry() {
    if (isClosing) return Future.value(_cancelled());
    final saved = PlaybackContinuity(this, position: _retryPosition);
    return open(request.url, httpHeaders: request.headers, continuity: saved);
  }

  @override
  Future<PlaybackCommandResult> play() {
    if (_backgrounded) return Future.value(_cancelled());
    _playIntent = true;
    ++_intentRevision;
    return _command('play', (_) async {
      await _raw?.play();
    });
  }

  @override
  Future<PlaybackCommandResult> pause() {
    _playIntent = false;
    ++_intentRevision;
    return _command('pause', (_) async {
      await _raw?.pause();
    });
  }

  @override
  Future<PlaybackCommandResult> togglePlayPause() => playing ? pause() : play();
  @override
  Future<PlaybackCommandResult> seekTo(Duration target) =>
      _command('seek', (_) async {
        if (!canSeek) throw UnsupportedError('Not seekable');
        await _raw!.seekTo(target);
        _rememberSeekIntent(target);
      });
  @override
  Future<PlaybackCommandResult> seekBy(int seconds) =>
      _command('seek', (_) async {
        if (!canSeek) throw UnsupportedError('Not seekable');
        final target = position + Duration(seconds: seconds);
        await _raw!.seekTo(target);
        _rememberSeekIntent(target);
      });

  void _rememberSeekIntent(Duration target) {
    final clamped = Duration(
        milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds));
    _retryPosition = clamped;
    _pendingSeekPosition = clamped;
  }

  @override
  Future<PlaybackCommandResult> setRate(double rate) =>
      _command('rate', (_) async {
        await _raw?.setRate(rate);
      });
  @override
  Future<PlaybackCommandResult> setVolume(double volume) =>
      _command('volume', (_) async {
        await _raw?.setVolume(volume);
      });
  @override
  Future<PlaybackCommandResult> toggleMute() => _command('mute', (_) async {
        await _raw?.toggleMute();
      });
  @override
  Future<PlaybackCommandResult> selectAudio(AudioTrack track) =>
      _command('audio', (_) async {
        await _raw?.selectAudio(track);
      });
  @override
  Future<PlaybackCommandResult> selectSubtitle(SubtitleTrack track) async {
    // Local imports can use formats beyond Media3's SRT/VTT/SSA parser. The
    // existing continuity handoff retains position, play intent and track.
    if (track.uri && Uri.tryParse(track.id)?.scheme == 'file') {
      final switching = await _ensureMpvBackend(true);
      if (switching != null) return switching;
    }
    return _command('subtitle', (_) async {
      await _raw?.selectSubtitle(track);
    });
  }

  @override
  Future<PlaybackCommandResult> setSubtitleUri(String url, {String? title}) =>
      _command('subtitle', (_) async {
        await _raw?.setSubtitleUri(url, title: title);
      });
  @override
  Future<PlaybackCommandResult> setSubtitleDelayMs(int delayMs) async {
    final switching = await _ensureTimingBackend(delayMs);
    if (switching != null) return switching;
    return _command('subtitle_delay', (_) async {
      await _raw?.setSubtitleDelayMs(delayMs);
      _subtitleDelayMs = delayMs;
    });
  }

  @override
  Future<PlaybackCommandResult> setAudioDelayMs(int delayMs) async {
    final switching = await _ensureTimingBackend(delayMs);
    if (switching != null) return switching;
    return _command('audio_delay', (_) async {
      await _raw?.setAudioDelayMs(delayMs);
      _audioDelayMs = delayMs;
    });
  }

  Future<PlaybackCommandResult?> _ensureTimingBackend(int offset) =>
      _ensureMpvBackend(offset != 0);

  Future<PlaybackCommandResult?> _ensureMpvBackend(bool required) async {
    final pending = _timingSwitch;
    if (pending != null) {
      final result = await pending;
      return result.applied ? null : result;
    }
    final backend = _backend;
    if (!required ||
        _usingFallback ||
        backend == null ||
        requiresTimingFallback?.call(backend) != true ||
        createFallbackBackend == null) {
      return null;
    }
    final saved = PlaybackContinuity(this);
    _usingFallback = true;
    final switching =
        open(request.url, httpHeaders: request.headers, continuity: saved);
    _timingSwitch = switching;
    try {
      final result = await switching;
      return result.applied ? null : result;
    } finally {
      if (identical(_timingSwitch, switching)) _timingSwitch = null;
    }
  }

  PlaybackPanelToken pauseForPanel() {
    final wasPlaying = playIntent;
    ++_intentRevision;
    unawaited(_command('pause', (_) async {
      await _raw?.pause();
    }));
    return PlaybackPanelToken(_sourceIdentity, _intentRevision, wasPlaying);
  }

  Future<PlaybackCommandResult> restorePanel(PlaybackPanelToken token) {
    if (!owns(token.identity) ||
        token.intentRevision != _intentRevision ||
        !token.wasPlaying ||
        failed ||
        _backgrounded) {
      return Future.value(_cancelled());
    }
    return play();
  }

  Future<void> background() {
    if (_backgrounded) return _backgroundWork ?? Future.value();
    _backgrounded = true;
    return _backgroundWork = () async {
      await pause();
      await checkpoint(CheckpointCause.pause, capture: true);
    }();
  }

  void foreground() {
    _backgrounded = false;
  }

  PlaybackCheckpoint _snapshot(CheckpointCause cause) => PlaybackCheckpoint(
        owner: _checkpointOwner,
        sequence: ++_sequence,
        contentKey: request.contentKey,
        item: request.item,
        videoId: request.videoId,
        season: request.season,
        episode: request.episode,
        positionMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
        cause: cause,
        eligible:
            request.recordProgress && resumeResolved && _canRecord() && ready,
      );

  Future<CheckpointResult> checkpoint(CheckpointCause cause,
      {bool capture = false}) async {
    if (isClosing || _persist == null) {
      return Future.value(CheckpointResult.rejected);
    }
    final snapshot = _snapshot(cause);
    final identity = _sourceIdentity;
    Uint8List? frame;
    if (capture && _frameEligible(snapshot)) {
      try {
        frame = await captureFrame().timeout(cleanupSaveTimeout);
      } catch (_) {/* optional frame */}
    }
    if (!owns(identity)) return CheckpointResult.rejected;
    return _write(snapshot.withFrame(frame));
  }

  bool _frameEligible(PlaybackCheckpoint snapshot) =>
      snapshot.eligible &&
      PlaybackResumePolicy.canCaptureFrame(
          snapshot.positionMs, snapshot.durationMs);

  Future<CheckpointResult> _write(PlaybackCheckpoint snapshot) async {
    final sink = _persist;
    if (sink == null) return CheckpointResult.rejected;
    final result = await _writer.write(snapshot, sink);
    if (result == CheckpointResult.failed) {
      persistenceFailed = true;
      _notify();
    }
    return result;
  }

  Future<Uint8List?> captureFrame() async {
    final backend = _backend;
    final identity = _sourceIdentity;
    if (backend == null || _nativeRetired) return null;
    final bytes = await backend.captureFrame();
    return !_nativeRetired &&
            identical(backend, _backend) &&
            identical(identity, _sourceIdentity)
        ? bytes
        : null;
  }

  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    final finalSnapshot = _snapshot(CheckpointCause.exit);
    final done = Completer<void>();
    _closeFuture = done.future;
    cancelResolution();
    phase = PlaybackPhase.closing;
    _invalidateSource();
    _coalescer.close();
    _periodic?.cancel();
    for (final command in _pendingCommands.toList()) {
      if (!command.isCompleted) command.complete(_cancelled());
    }
    _pendingCommands.clear();
    _notify();
    // Assign a terminal Future before any user/native callback can reenter.
    unawaited(_finishClose(finalSnapshot)
        .then(done.complete, onError: done.completeError));
    return done.future;
  }

  Future<void> _finishClose(PlaybackCheckpoint snapshot) async {
    Future<void>? retirement;
    Future<void> retireNative() => retirement ??= () async {
          closeStage = 'native_retirement';
          await _backend?.close();
          _nativeRetired = true;
          _backend = null;
        }();
    try {
      // A native open/command may never settle until its player is disposed.
      // Retire that backend first, then skip the blocked lane: queued command
      // results were cancelled by close(), and no new backend may be created
      // until this retirement has completed.
      final interrupted = _commandInFlight && _backend != null;
      if (interrupted) {
        await retireNative();
      } else {
        closeStage = 'command_lane';
        await _lane;
        try {
          closeStage = 'pause';
          await _raw?.pause();
        } catch (_) {
          failure ??= PlaybackFailure(
              PlaybackFailureCategory.operation, 'close_pause', _generation);
        }
      }
      Uint8List? frame;
      if (!interrupted && _frameEligible(snapshot)) {
        try {
          closeStage = 'frame_capture';
          frame = await captureFrame().timeout(cleanupSaveTimeout);
        } catch (_) {/* optional frame */}
      }
      // Storage can stall independently of the player. Retire native output
      // before waiting on the checkpoint so the next route never inherits a
      // live player from a page that has already been popped.
      await retireNative();
      try {
        closeStage = 'checkpoint_write';
        await _write(snapshot.withFrame(frame)).timeout(cleanupSaveTimeout);
      } catch (_) {
        persistenceFailed = true;
      }
    } finally {
      _writer.retire(_checkpointOwner);
      // If native retirement fails/hangs, never release the dependent torrent.
      await retireNative();
      closeStage = 'torrent_release';
      for (final lease in _leases.toList()) {
        await lease.stop();
        _leases.remove(lease);
      }
      phase = PlaybackPhase.closed;
      closeStage = 'closed';
      _notify();
    }
  }

  @override
  void dispose() {
    if (_notifiersDisposed) return;
    // Page starts close before dispose; observe any failure without hiding
    // the original terminal Future from ownership/handoff callers.
    unawaited(close().catchError((Object _) {}));
    _notifiersDisposed = true;
    progress.dispose();
    super.dispose();
  }
}
