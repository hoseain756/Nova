/// Existing resume and completion rules shared by the player and history.
/// The final two minutes are treated as complete, including short media.
enum ResumePlaybackAction { startOver, prompt, resume }

abstract final class PlaybackResumePolicy {
  static const int completionWindowMs = 120000;
  static const int promptAfterMs = 30000;
  static const int seekEndMarginMs = 5000;

  static ResumePlaybackAction action(
    Map<String, dynamic> settings,
    int? savedPositionMs,
  ) {
    if ((savedPositionMs ?? 0) <= 0 || settings['resumePlayback'] == false) {
      return ResumePlaybackAction.startOver;
    }
    return settings['resumePrompt'] == true && savedPositionMs! > promptAfterMs
        ? ResumePlaybackAction.prompt
        : ResumePlaybackAction.resume;
  }

  static int safePositionMs(int? savedPositionMs, int durationMs) {
    if (durationMs <= 0) return 0;
    final upperBound =
        durationMs > seekEndMarginMs ? durationMs - seekEndMarginMs : 0;
    return (savedPositionMs ?? 0).clamp(0, upperBound).toInt();
  }

  static bool canRecord({required bool awaitingResumeChoice}) =>
      !awaitingResumeChoice;

  static bool isComplete(int positionMs, int durationMs) =>
      durationMs > 0 && positionMs >= durationMs - completionWindowMs;

  /// Preserve the existing CW map rule; display additionally requires > 0.
  static bool isBeforeCompletion(int positionMs, int durationMs) =>
      durationMs > 0 && positionMs < durationMs - completionWindowMs;

  static bool canCaptureFrame(int positionMs, int durationMs) =>
      positionMs > 0 && isBeforeCompletion(positionMs, durationMs);
}
