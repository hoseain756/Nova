import 'package:flutter/foundation.dart';

enum PlaybackBackendPreference { auto, media3, mpv }

PlaybackBackendPreference playbackBackendPreference(
    Map<String, dynamic> settings) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return PlaybackBackendPreference.mpv;
  }
  return switch (settings['playbackBackend']) {
    'media3' => PlaybackBackendPreference.media3,
    'mpv' => PlaybackBackendPreference.mpv,
    _ => PlaybackBackendPreference.auto,
  };
}
