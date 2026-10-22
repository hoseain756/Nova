/// Waits for a paused source to expose duration and positive seek capability
/// before applying an automatic resume. A seek issued earlier can complete
/// without moving a newly opened native source.
Future<bool> applyStartupResumeSeek({
  required Duration target,
  required Duration Function() duration,
  required Future<bool?> Function() seekable,
  required Future<void> Function(Duration) seekTo,
  required bool Function() isActive,
  Future<void> Function(Duration)? wait,
  Duration interval = const Duration(milliseconds: 500),
  int attempts = 7,
}) async {
  final pause = wait ?? (delay) => Future<void>.delayed(delay);
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (!isActive()) return false;
    bool? canSeek;
    if (duration() > Duration.zero) {
      try {
        canSeek = await seekable();
      } catch (_) {
        // A failed capability query cannot authorize a resume seek.
      }
    }
    if (!isActive()) return false;
    if (canSeek == true) {
      await seekTo(target);
      return isActive();
    }
    if (attempt + 1 < attempts) await pause(interval);
  }
  return false;
}

/// Some sources never report positive seek capability while their native
/// player is paused, although a seek works after playback has started. This
/// fallback confirms the resulting position instead of trusting seek's return.
Future<bool> applyPlayingStartupResumeSeek({
  required Duration target,
  required Duration Function() duration,
  required Duration Function() position,
  required Future<void> Function() play,
  required Future<void> Function() pause,
  required Future<void> Function(Duration) seekTo,
  required bool Function() isActive,
  Future<void> Function(Duration)? wait,
  Duration interval = const Duration(milliseconds: 500),
  int readyAttempts = 10,
  int positionAttempts = 10,
  Duration tolerance = const Duration(seconds: 8),
}) async {
  final delay = wait ?? (value) => Future<void>.delayed(value);
  var confirmed = false;
  if (!isActive()) return false;
  await play();
  try {
    for (var attempt = 0; attempt < readyAttempts; attempt++) {
      if (!isActive()) return false;
      if (duration() > Duration.zero) break;
      if (attempt + 1 < readyAttempts) await delay(interval);
    }
    if (!isActive() || duration() <= Duration.zero) return false;
    final expected = Duration(
      milliseconds: target.inMilliseconds.clamp(0, duration().inMilliseconds),
    );
    if (expected <= Duration.zero) return false;

    for (var seekAttempt = 0; seekAttempt < 2; seekAttempt++) {
      if (!isActive()) return false;
      await seekTo(expected);
      for (var attempt = 0; attempt < positionAttempts; attempt++) {
        if (!isActive()) return false;
        if ((position() - expected).abs() <= tolerance) {
          confirmed = true;
          return true;
        }
        if (attempt + 1 < positionAttempts) await delay(interval);
      }
    }
    return false;
  } finally {
    if (!confirmed && isActive()) await pause();
  }
}
