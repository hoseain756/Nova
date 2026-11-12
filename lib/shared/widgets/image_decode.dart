import 'package:flutter/widgets.dart';

/// Artwork quality controls source resolution and bounded decoded texture size.
/// Other image hosts keep their original URL; only TMDB's size path is changed.
enum ArtworkQuality {
  low,
  balanced,
  high;

  static ArtworkQuality fromSetting(Object? value,
          {ArtworkQuality fallback = ArtworkQuality.balanced}) =>
      ArtworkQuality.values
          .where((quality) => quality.name == value)
          .firstOrNull ??
      fallback;

  int decodedExtent(BuildContext context, double logicalExtent) {
    final scale = switch (this) {
      low => .75,
      balanced => 1.0,
      high => 1.25,
    };
    final ceiling = switch (this) {
      low => 1024,
      balanced => 2048,
      high => 3072,
    };
    final pixels = (logicalExtent.clamp(64.0, 1600.0) *
            MediaQuery.devicePixelRatioOf(context) *
            scale)
        .round();
    return pixels.clamp(96, ceiling);
  }

  String sourceUrl(String url,
      {bool hero = false, bool portrait = false, bool logo = false}) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'image.tmdb.org') return url;
    final segments = uri.pathSegments.toList();
    if (segments.length < 4 ||
        segments[0] != 't' ||
        segments[1] != 'p' ||
        !RegExp(r'^(w\d+|original)$').hasMatch(segments[2])) {
      return url;
    }
    segments[2] = switch ((this, hero, portrait, logo)) {
      (high, _, _, _) => 'original',
      (low, _, _, true) => 'w300',
      (balanced, _, _, true) => 'w500',
      (low, true, true, _) => 'w500',
      (balanced, true, true, _) => 'w780',
      (low, true, false, _) => 'w780',
      (balanced, true, false, _) => 'w1280',
      (low, false, true, _) => 'w342',
      (balanced, false, true, _) => 'w500',
      (low, false, false, _) => 'w300',
      (balanced, false, false, _) => 'w780',
    };
    return uri.replace(pathSegments: segments).toString();
  }
}

/// Logical-width → pixel `cacheWidth` for network images (Task 136 perf pass).
///
/// Every poster/still/logo in the app used to decode at its DOWNLOAD
/// resolution (TMDB serves w342–w1280, AniList up to 460px) and held the
/// full-res texture even when drawn at 122 logical px. On a low-end device
/// that is megabytes of dead texture memory per screen, constant GC churn
/// and slow decodes on the UI thread path. Passing `cacheWidth` makes the
/// codec downsample at decode time — identical visuals, a fraction of the
/// memory, much faster first paint.
///
/// [logicalWidth] is the on-screen width in logical pixels (the box width,
/// not the image's natural width). The result is that width scaled by the
/// device pixel ratio (clamped to a sane band) so one code path serves
/// 40px logos and 800px hero art.
int imageCacheWidth(BuildContext context, double logicalWidth) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final px = (logicalWidth.clamp(64.0, 1280.0) * dpr).round();
  return px.clamp(96, 2048);
}
