/// A data-provided, half-open interval on the exact playback timeline.
enum SkipSegmentType { recap, intro, opening, outro, credits }

class SkipSegment {
  const SkipSegment({
    required this.type,
    required this.startMs,
    required this.endMs,
    required this.source,
    this.confidence,
  });

  final SkipSegmentType type;
  final int startMs;
  final int endMs;
  final String source;
  final double? confidence;

  bool contains(int positionMs, int durationMs) =>
      startMs >= 0 &&
      endMs > startMs &&
      (durationMs <= 0 || endMs <= durationMs) &&
      positionMs >= startMs &&
      positionMs < endMs;

  bool get isEnding =>
      type == SkipSegmentType.outro || type == SkipSegmentType.credits;
}

/// Chooses one prompt for overlapping windows, then suppresses the connected
/// overlap after a tap or dismissal. Seeking away and back rearms the prompt; a new route
/// gets a new controller.
class SkipSegmentController {
  (int, int)? _suppressedWindow;
  bool _inFlight = false;

  void reset() {
    _suppressedWindow = null;
    _inFlight = false;
  }

  SkipSegment? active(
    List<SkipSegment> segments, {
    required int positionMs,
    required int durationMs,
  }) {
    if (_inFlight) return null;
    final suppressed = _suppressedWindow;
    if (suppressed != null) {
      if (positionMs >= suppressed.$1 && positionMs < suppressed.$2) {
        return null;
      }
      _suppressedWindow = null;
    }
    SkipSegment? selected;
    for (final segment in segments) {
      if (!segment.contains(positionMs, durationMs)) continue;
      // Station 09's proposed order: latest start, then earliest end, then
      // stable type. The tapped overlap group is suppressed as one window.
      if (selected == null ||
          segment.startMs > selected.startMs ||
          (segment.startMs == selected.startMs &&
              (segment.endMs < selected.endMs ||
                  (segment.endMs == selected.endMs &&
                      segment.type.index < selected.type.index)))) {
        selected = segment;
      }
    }
    return selected;
  }

  bool begin(SkipSegment segment, List<SkipSegment> segments) {
    if (_inFlight) return false;
    _inFlight = true;
    _suppressConnectedWindow(segment, segments);
    return true;
  }

  bool dismiss(SkipSegment segment, List<SkipSegment> segments) {
    if (_inFlight) return false;
    _suppressConnectedWindow(segment, segments);
    return true;
  }

  void _suppressConnectedWindow(
      SkipSegment segment, List<SkipSegment> segments) {
    var start = segment.startMs;
    var end = segment.endMs;
    var changed = true;
    while (changed) {
      changed = false;
      for (final other in segments) {
        if (other.startMs >= end || other.endMs <= start) continue;
        if (other.startMs < start) {
          start = other.startMs;
          changed = true;
        }
        if (other.endMs > end) {
          end = other.endMs;
          changed = true;
        }
      }
    }
    _suppressedWindow = (start, end);
  }

  void finish({required bool applied}) {
    if (!applied) _suppressedWindow = null;
    _inFlight = false;
  }
}
