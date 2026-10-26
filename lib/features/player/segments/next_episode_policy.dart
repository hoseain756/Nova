import '../../../core/models/playback_resume_policy.dart';
import 'playback_segments.dart';

/// Shared decisions for the next-episode prompt and optional
/// data-provided auto-advance. Each player route owns its dismissal and
/// transition state; this policy never selects a source or changes history.
class NextEpisodePolicy {
  NextEpisodePolicy._();

  static bool cardVisible({
    required PlaybackSegments segments,
    required int positionMs,
    required int durationMs,
    required bool ready,
    required bool failed,
    required bool locked,
    required bool temporarySpeedActive,
    required bool panelOpen,
    required bool hasNextEpisode,
    required bool endingSegmentVisible,
    required bool dismissed,
    required bool completed,
  }) {
    final appear = SegmentWindows.cardAppearAtMs(
      segments: segments,
      durationMs: durationMs,
    );
    return ready &&
        !failed &&
        !locked &&
        !temporarySpeedActive &&
        !panelOpen &&
        hasNextEpisode &&
        !endingSegmentVisible &&
        !dismissed &&
        !completed &&
        appear >= 0 &&
        positionMs >= appear;
  }

  /// Auto-advance is allowed only on a short forward playback crossing of
  /// the data-provided deadline. A seek into/past it does not launch an
  /// episode, and a paused player or open panel cannot launch one either.
  static bool shouldAutoAdvance({
    required PlaybackSegments segments,
    required int? previousPositionMs,
    required int positionMs,
    required int durationMs,
    required bool ready,
    required bool playing,
    required bool failed,
    required bool closing,
    required bool seekInProgress,
    required bool resumeResolved,
    required bool locked,
    required bool panelOpen,
    required bool hasNextEpisode,
    required bool autoPlayEnabled,
    required bool dismissed,
    required bool completed,
    required bool transitionBusy,
    required bool alreadyFired,
  }) {
    if (!ready ||
        !playing ||
        failed ||
        closing ||
        seekInProgress ||
        !resumeResolved ||
        locked ||
        panelOpen ||
        !hasNextEpisode ||
        !autoPlayEnabled ||
        dismissed ||
        completed ||
        transitionBusy ||
        alreadyFired) {
      return false;
    }
    final at = SegmentWindows.autoAdvanceAtMs(
      segments: segments,
      durationMs: durationMs,
    );
    if (at == null || previousPositionMs == null) return false;
    final advanceMs = positionMs - previousPositionMs;
    return previousPositionMs < at &&
        positionMs >= at &&
        PlaybackResumePolicy.isComplete(positionMs, durationMs) &&
        advanceMs > 0 &&
        advanceMs <= 5000;
  }

  static int countdownSeconds({
    required PlaybackSegments segments,
    required int positionMs,
    required int durationMs,
  }) {
    final at = SegmentWindows.autoAdvanceAtMs(
          segments: segments,
          durationMs: durationMs,
        ) ??
        durationMs;
    return ((at - positionMs) / 1000).ceil().clamp(0, 9999);
  }
}
