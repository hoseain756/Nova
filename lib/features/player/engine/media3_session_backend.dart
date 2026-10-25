import 'dart:typed_data';

import '../session/playback_session.dart';
import 'media3_engine.dart';

class Media3SessionBackend implements PlaybackBackend {
  @override
  final Media3Engine engine = Media3Engine();
  @override
  Future<void> openPaused(String url, Map<String, String>? headers) =>
      engine.open(url, httpHeaders: headers);
  @override
  Future<bool?> seekable() => engine.querySeekable();
  @override
  Future<Uint8List?> captureFrame() => engine.captureFrame();
  @override
  Future<void> close() => engine.close();
}
