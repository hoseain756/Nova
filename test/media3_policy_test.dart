import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/engine/media3_engine.dart';
import 'package:nova_mobile/features/player/engine/playback_backend_preference.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('only format/decoder failures permit automatic fallback', () {
    for (final code in [3001, 3004, 4001, 4005, 5001, 7100]) {
      expect(Media3Engine.compatibilityFailure(code), isTrue);
    }
    for (final code in [null, -1, 1001, 1002, 2001, 2004, 2006, 6001, 6007]) {
      expect(Media3Engine.compatibilityFailure(code), isFalse);
    }
  });
  test('Android selection is explicit; other platforms always use mpv', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(playbackBackendPreference({}), PlaybackBackendPreference.auto);
    expect(playbackBackendPreference({'playbackBackend': 'media3'}),
        PlaybackBackendPreference.media3);
    expect(playbackBackendPreference({'playbackBackend': 'mpv'}),
        PlaybackBackendPreference.mpv);
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.windows,
      TargetPlatform.macOS
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(playbackBackendPreference({'playbackBackend': 'media3'}),
          PlaybackBackendPreference.mpv);
    }
  });
}
