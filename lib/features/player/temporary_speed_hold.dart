import 'dart:async';

/// Serializes a temporary 2x gesture with restoration of the prior rate.
/// The owner check prevents a released gesture from changing a new source.
class TemporarySpeedHold {
  bool _active = false;
  int _generation = 0;
  Future<void> _start = Future<void>.value();
  Future<void>? _ending;
  double _previousRate = 1;
  Future<void> Function(double)? _setRate;
  bool Function()? _ownsSource;

  bool get active => _active;
  bool get settling => _ending != null;

  bool begin({
    required double previousRate,
    required Future<void> Function(double) setRate,
    required bool Function() ownsSource,
  }) {
    if (_active || _ending != null || !ownsSource()) return false;
    _active = true;
    _previousRate = previousRate;
    _setRate = setRate;
    _ownsSource = ownsSource;
    final generation = ++_generation;
    _start = Future<void>(() async {
      if (generation == _generation && ownsSource()) await setRate(2);
    }).catchError((Object _) {
      // A failed speed command must still permit restoration on release.
    });
    return true;
  }

  Future<void> end() {
    if (!_active) return _ending ?? Future<void>.value();
    _active = false;
    final generation = _generation;
    final previousRate = _previousRate;
    final setRate = _setRate!;
    final ownsSource = _ownsSource!;
    final pending = _start;
    final ending = () async {
      try {
        await pending;
        if (generation == _generation && ownsSource()) {
          await setRate(previousRate);
        }
      } catch (_) {
        // A retiring backend may reject the restoration command.
      } finally {
        _setRate = null;
        _ownsSource = null;
      }
    }();
    _ending = ending;
    unawaited(ending.whenComplete(() {
      if (identical(_ending, ending)) _ending = null;
    }));
    return ending;
  }

  void invalidate() {
    _generation++;
    _active = false;
  }
}
