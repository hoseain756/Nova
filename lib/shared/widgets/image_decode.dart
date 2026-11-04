import 'package:flutter/widgets.dart';

import '../../core/models/visual_preferences.dart';

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

enum ProviderImageKind { poster, backdrop }

/// Bound the decoded texture as well as the requested CDN image. Original
/// keeps the CDN source intact but still caps decode memory to 2048 pixels.
int imageCacheWidthForQuality(
  BuildContext context,
  double logicalWidth, {
  required ImageQuality quality,
  ProviderImageKind kind = ProviderImageKind.poster,
}) {
  final requested = imageCacheWidth(context, logicalWidth);
  final ceiling = switch ((kind, quality)) {
    (ProviderImageKind.poster, ImageQuality.low) => 185,
    (ProviderImageKind.poster, ImageQuality.medium) => 500,
    (ProviderImageKind.poster, ImageQuality.high) => 780,
    (ProviderImageKind.backdrop, ImageQuality.low) => 300,
    (ProviderImageKind.backdrop, ImageQuality.medium) => 780,
    (ProviderImageKind.backdrop, ImageQuality.high) => 1280,
    (_, ImageQuality.auto || ImageQuality.original) => 2048,
  };
  return requested.clamp(1, ceiling);
}

/// Resize only a recognized TMDB image URL. Other add-on and user-supplied
/// URLs stay byte-for-byte unchanged; changing their path can break signing.
String providerSizedImageUrl(
  String url, {
  required ImageQuality quality,
  required int targetPixels,
  ProviderImageKind kind = ProviderImageKind.poster,
}) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'image.tmdb.org' ||
      uri.pathSegments.length < 4 ||
      uri.pathSegments[0] != 't' ||
      uri.pathSegments[1] != 'p') {
    return url;
  }
  final current = uri.pathSegments[2];
  if (current != 'original' && !RegExp(r'^w\d+$').hasMatch(current)) {
    return url;
  }
  final size = switch ((kind, quality)) {
    (_, ImageQuality.original) => 'original',
    (ProviderImageKind.poster, ImageQuality.low) => 'w185',
    (ProviderImageKind.poster, ImageQuality.medium) => 'w500',
    (ProviderImageKind.poster, ImageQuality.high) => 'w780',
    (ProviderImageKind.backdrop, ImageQuality.low) => 'w300',
    (ProviderImageKind.backdrop, ImageQuality.medium) => 'w780',
    (ProviderImageKind.backdrop, ImageQuality.high) => 'w1280',
    (ProviderImageKind.poster, ImageQuality.auto) =>
      _autoSize(targetPixels, const [185, 342, 500, 780], cap: 780),
    (ProviderImageKind.backdrop, ImageQuality.auto) =>
      _autoSize(targetPixels, const [300, 780, 1280], cap: 1280),
  };
  if (size == current) return url;
  return uri.replace(pathSegments: [
    uri.pathSegments[0],
    uri.pathSegments[1],
    size,
    ...uri.pathSegments.skip(3),
  ]).toString();
}

String _autoSize(int targetPixels, List<int> options, {required int cap}) {
  final target = targetPixels.clamp(1, cap);
  for (final width in options) {
    if (width >= target) return 'w$width';
  }
  return 'w$cap';
}
