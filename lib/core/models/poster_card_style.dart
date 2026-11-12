import 'package:flutter/foundation.dart';

/// Validated presentation preferences in the existing settings bucket.
@immutable
class PosterCardStyle {
  const PosterCardStyle({
    this.scale = 1,
    this.radius = 12,
    this.landscape = false,
    this.hideTitles = false,
    this.showLogo = true,
    this.logoPosition = 'bottomStart',
    this.artworkQuality = 'balanced',
  });

  factory PosterCardStyle.fromSettings(Map<String, dynamic> settings) =>
      PosterCardStyle(
        scale: _number(settings['posterScale'], 1, .8, 1.5),
        radius: _number(settings['posterRadius'], 12, 0, 40),
        landscape: settings['posterShape'] == 'landscape',
        hideTitles: settings['hidePosterTitles'] == true,
        showLogo: settings['showPosterLogo'] != false,
        logoPosition: const {'bottomStart', 'center', 'bottomEnd'}
                .contains(settings['posterLogoPosition'])
            ? settings['posterLogoPosition'] as String
            : 'bottomStart',
        artworkQuality: const {'low', 'balanced', 'high'}
                .contains(settings['posterArtworkQuality'])
            ? settings['posterArtworkQuality'] as String
            : 'balanced',
      );

  final double scale;
  final double radius;
  final bool landscape;
  final bool hideTitles;
  final bool showLogo;
  final String logoPosition;
  final String artworkQuality;

  PosterCardStyle copyWith({bool? hideTitles}) => PosterCardStyle(
        scale: scale,
        radius: radius,
        landscape: landscape,
        hideTitles: hideTitles ?? this.hideTitles,
        showLogo: showLogo,
        logoPosition: logoPosition,
        artworkQuality: artworkQuality,
      );

  double get aspectRatio => landscape ? 16 / 9 : .72;
  double railWidth(double viewportWidth) =>
      (landscape ? 236 : (viewportWidth >= 700 ? 138 : 122)) * scale;
  double gridTargetWidth(double baseWidth) =>
      baseWidth * scale * (landscape ? 1.8 : 1);

  static const defaults = <String, dynamic>{
    'posterScale': 1.0,
    'posterRadius': 12,
    'posterShape': 'portrait',
    'hidePosterTitles': false,
    'showPosterLogo': true,
    'posterLogoPosition': 'bottomStart',
    'posterArtworkQuality': 'balanced',
  };

  static double _number(dynamic raw, double fallback, double min, double max) {
    if (raw is! num || !raw.isFinite) return fallback;
    return raw.toDouble().clamp(min, max);
  }

  @override
  bool operator ==(Object other) =>
      other is PosterCardStyle &&
      scale == other.scale &&
      radius == other.radius &&
      landscape == other.landscape &&
      hideTitles == other.hideTitles &&
      showLogo == other.showLogo &&
      logoPosition == other.logoPosition &&
      artworkQuality == other.artworkQuality;

  @override
  int get hashCode => Object.hash(scale, radius, landscape, hideTitles,
      showLogo, logoPosition, artworkQuality);
}
