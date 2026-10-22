import 'dart:async';

/// An exact backend sample, independent of its eventual UI publication.
///
/// Timing values are deliberately not rounded or clamped here. Validation and
/// persistence remain the responsibility of the caller. Route-local UI wiring
/// lives in playback_progress_binding.dart.
class PlaybackProgress {
  const PlaybackProgress({
    required this.contentGeneration,
    required this.sourceGeneration,
    required this.position,
    required this.duration,
    required this.bufferedEnd,
  });

  final int contentGeneration;
  final int sourceGeneration;
  final Duration position;
  final Duration duration;
  final Duration bufferedEnd;

  @override
  bool operator ==(Object other) =>
      other is PlaybackProgress &&
      contentGeneration == other.contentGeneration &&
      sourceGeneration == other.sourceGeneration &&
      position == other.position &&
      duration == other.duration &&
      bufferedEnd == other.bufferedEnd;

  @override
  int get hashCode => Object.hash(
        contentGeneration,
        sourceGeneration,
        position,
        duration,
        bufferedEnd,
      );
}

typedef PlaybackProgressCancel = void Function();

/// Schedules an asynchronous one-shot callback and returns its cancellation.
typedef PlaybackProgressScheduler = PlaybackProgressCancel Function(
  Duration delay,
  void Function() callback,
);

/// Latest-value progress coalescing for the PROPOSED Station 10 contract.
///
/// The first sample of a generation is published immediately. Subsequent
/// changed samples are published at least [interval] apart, with at most one
/// trailing callback. A late callback publishes once at its actual execution
/// time; it never catches up with a burst. There is no idle periodic timer.
///
/// [now] must be monotonic; the default uses a Stopwatch. [schedule] must invoke
/// callbacks asynchronously; the default uses Timer. Callback cancellation is
/// guarded as well, so a late cancelled callback cannot publish stale samples.
/// This helper owns no player, UI binding, storage or native resources.
class PlaybackProgressCoalescer {
  PlaybackProgressCoalescer({
    required int contentGeneration,
    required int sourceGeneration,
    required void Function(PlaybackProgress progress) onProgress,
    Duration Function()? now,
    PlaybackProgressScheduler? schedule,
  })  : _contentGeneration = contentGeneration,
        _sourceGeneration = sourceGeneration,
        _onProgress = onProgress,
        _now = now ?? _stopwatchClock(),
        _schedule = schedule ?? _timerSchedule;

  static const interval = Duration(milliseconds: 100);

  final void Function(PlaybackProgress progress) _onProgress;
  final Duration Function() _now;
  final PlaybackProgressScheduler _schedule;
  int _contentGeneration;
  int _sourceGeneration;
  PlaybackProgress? _latest;
  PlaybackProgress? _published;
  Duration? _lastPublication;
  Duration? _lastClockReading;
  PlaybackProgressCancel? _cancelPending;
  int _revision = 0;
  bool _closed = false;

  /// Latest accepted, unsampled input; never read UI publication as progress.
  PlaybackProgress? get latest => _latest;

  /// Last emitted UI sample, or null after a generation reset.
  PlaybackProgress? get published => _published;

  bool get isClosed => _closed;

  /// Returns false for a closed coalescer or a stale generation.
  bool add(PlaybackProgress progress) {
    if (_closed ||
        progress.contentGeneration != _contentGeneration ||
        progress.sourceGeneration != _sourceGeneration) {
      return false;
    }
    final time = _readClock();
    _latest = progress;
    if (progress == _published) {
      _cancelScheduled();
    } else if (_cancelPending == null) {
      _publishOrSchedule(time);
    }
    return true;
  }

  /// Clears samples and pending work for an explicit content/source transition.
  ///
  /// Callers must use a fresh generation pair, clear their own visible binding,
  /// and tag subsequent samples accordingly. Repeating the current pair is a
  /// no-op, so ordinary seek/duration/buffer events cannot reset the rate limit.
  /// Returns false if closed or the generation is unchanged.
  bool reset({required int contentGeneration, required int sourceGeneration}) {
    if (_closed ||
        (contentGeneration == _contentGeneration &&
            sourceGeneration == _sourceGeneration)) {
      return false;
    }
    _cancelScheduled();
    _contentGeneration = contentGeneration;
    _sourceGeneration = sourceGeneration;
    _latest = null;
    _published = null;
    _lastPublication = null;
    return true;
  }

  /// Stops delivery permanently. Repeated calls are harmless; snapshots freeze.
  void close() {
    if (_closed) return;
    _closed = true;
    _cancelScheduled();
  }

  Duration _readClock() {
    final time = _now();
    final previous = _lastClockReading;
    if (previous != null && time < previous) {
      throw StateError('Playback progress requires a monotonic clock.');
    }
    _lastClockReading = time;
    return time;
  }

  void _publishOrSchedule(Duration time) {
    final sample = _latest;
    if (sample == null || sample == _published) return;
    final previous = _lastPublication;
    if (previous != null && time - previous < interval) {
      final revision = ++_revision;
      _cancelPending = _schedule(interval - (time - previous), () {
        if (_closed || revision != _revision) return;
        _cancelPending = null;
        _revision++;
        _publishOrSchedule(_readClock());
      });
      return;
    }
    // Commit state before invoking user code, including reentrant add/reset.
    _published = sample;
    _lastPublication = time;
    _onProgress(sample);
  }

  void _cancelScheduled() {
    _revision++;
    final cancel = _cancelPending;
    _cancelPending = null;
    cancel?.call();
  }

  static Duration Function() _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  static PlaybackProgressCancel _timerSchedule(
    Duration delay,
    void Function() callback,
  ) {
    final timer = Timer(delay, callback);
    return timer.cancel;
  }
}
