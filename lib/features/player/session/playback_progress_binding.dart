import 'package:flutter/foundation.dart';

import '../engine/playback_engine.dart';
import 'playback_progress.dart';

/// A route-local display projection; exact engine values remain authoritative.
/// This owns a listener and coalescer, never the engine or its disposal.
class PlaybackProgressBinding extends ValueNotifier<PlaybackProgress?> {
  PlaybackProgressBinding({
    Duration Function()? now,
    PlaybackProgressScheduler? schedule,
  }) : super(null) {
    _coalescer = PlaybackProgressCoalescer(
      contentGeneration: 1,
      sourceGeneration: 0,
      now: now,
      schedule: schedule,
      onProgress: (sample) {
        if (!_closed && sample.sourceGeneration == _sourceGeneration) {
          value = sample;
        }
      },
    );
  }

  late final PlaybackProgressCoalescer _coalescer;
  PlaybackEngine? _engine;
  VoidCallback? _listener;
  int _sourceGeneration = 0;
  Object? _interactionIdentity;
  bool _closed = false;

  Object? get interactionIdentity => _interactionIdentity;

  bool owns(PlaybackEngine engine, Object? identity) =>
      !_closed &&
      identical(_engine, engine) &&
      identity != null &&
      identical(identity, _interactionIdentity);

  void bind(PlaybackEngine engine) {
    if (_closed) return;
    unbind();
    if (_closed) return;
    _engine = engine;
    final identity = _interactionIdentity = Object();
    final generation = _sourceGeneration;
    void read() {
      if (!owns(engine, identity)) return;
      _coalescer.add(PlaybackProgress(
        contentGeneration: 1,
        sourceGeneration: generation,
        position: engine.position,
        duration: engine.duration,
        bufferedEnd: engine.bufferedEnd,
      ));
    }

    _listener = read;
    engine.addListener(read);
    read();
  }

  /// Invalidates old commands and pending delivery before native retirement.
  void unbind() {
    if (_closed) return;
    _detach();
    _coalescer.reset(contentGeneration: 1, sourceGeneration: _sourceGeneration);
    value = null;
  }

  void _detach() {
    final engine = _engine;
    final listener = _listener;
    _engine = null;
    _listener = null;
    _interactionIdentity = null;
    _sourceGeneration++;
    if (engine != null && listener != null) engine.removeListener(listener);
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _detach();
    _coalescer.close();
    super.dispose();
  }
}
