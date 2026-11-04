/// Settings shared by poster cards, rails, grids, and their live preview.
///
/// Values are read from the existing synced `webSettings` bucket. Unknown
/// values fall back to the current medium, vertical card presentation.
enum CardSize {
  small,
  medium,
  large;

  static CardSize fromValue(Object? value) => switch (value) {
        'small' => CardSize.small,
        'large' => CardSize.large,
        _ => CardSize.medium,
      };
}

enum CardOrientation {
  vertical,
  horizontal;

  static CardOrientation fromValue(Object? value) => value == 'horizontal'
      ? CardOrientation.horizontal
      : CardOrientation.vertical;
}

class CardPreferences {
  const CardPreferences({
    this.size = CardSize.medium,
    this.orientation = CardOrientation.vertical,
    this.radius = 12,
  });

  factory CardPreferences.fromSettings(Map<String, dynamic> settings) {
    final savedRadius = settings['posterRadius'];
    final radius = savedRadius is num ? savedRadius.toDouble() : 12.0;
    return CardPreferences(
      size: CardSize.fromValue(settings['cardSize']),
      orientation: CardOrientation.fromValue(settings['cardOrientation']),
      radius: radius.isFinite ? radius.clamp(0, 28).toDouble() : 12,
    );
  }

  final CardSize size;
  final CardOrientation orientation;
  final double radius;

  bool get isHorizontal => orientation == CardOrientation.horizontal;

  /// Rail width can differ from a grid cell; both use the same size ranking.
  CardDimensions dimensions(double viewportWidth) {
    final wide = viewportWidth >= 700;
    final posterWidth = switch ((wide, size)) {
      (false, CardSize.small) => 106.0,
      (false, CardSize.medium) => 122.0,
      (false, CardSize.large) => 146.0,
      (true, CardSize.small) => 120.0,
      (true, CardSize.medium) => 138.0,
      (true, CardSize.large) => 168.0,
    };
    return CardDimensions(
      railWidth: isHorizontal ? posterWidth * 2.13 : posterWidth,
      minimumGridWidth: isHorizontal
          ? switch (size) {
              CardSize.small => 224,
              CardSize.medium => 264,
              CardSize.large => 304,
            }
          : switch ((wide, size)) {
              (false, CardSize.small) => 112,
              (false, CardSize.medium) => 146,
              (false, CardSize.large) => 188,
              (true, CardSize.small) => 150,
              (true, CardSize.medium) => 180,
              (true, CardSize.large) => 220,
            },
      horizontalArtworkWidthFraction: .44,
      horizontalHeight: posterWidth * .98,
    );
  }

  CardPreferences copyWith({
    CardSize? size,
    CardOrientation? orientation,
    double? radius,
  }) =>
      CardPreferences(
        size: size ?? this.size,
        orientation: orientation ?? this.orientation,
        radius: radius ?? this.radius,
      );

  @override
  bool operator ==(Object other) =>
      other is CardPreferences &&
      other.size == size &&
      other.orientation == orientation &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(size, orientation, radius);
}

class CardDimensions {
  const CardDimensions({
    required this.railWidth,
    required this.minimumGridWidth,
    required this.horizontalArtworkWidthFraction,
    required this.horizontalHeight,
  });

  final double railWidth;
  final double minimumGridWidth;
  final double horizontalArtworkWidthFraction;
  final double horizontalHeight;

  static const verticalArtworkRatio = .72;

  double artworkHeight(double width, CardOrientation orientation) =>
      orientation == CardOrientation.vertical
          ? width / verticalArtworkRatio
          : horizontalHeight;

  double horizontalExtent(double width, double textScale) {
    final artworkExtent = width / railWidth * horizontalHeight;
    final textExtent = 116 * textScale.clamp(1, 3).toDouble();
    return artworkExtent > textExtent ? artworkExtent : textExtent;
  }

  /// Fits at least one column and never makes a horizontal card too narrow.
  int gridColumns(double availableWidth, {double gap = 20, int max = 7}) =>
      ((availableWidth + gap) / (minimumGridWidth + gap)).floor().clamp(1, max);

  double gridCellWidth(double availableWidth, int columns, {double gap = 20}) =>
      (availableWidth - gap * (columns - 1)) / columns;
}

enum ImageQuality {
  auto,
  low,
  medium,
  high,
  original;

  static ImageQuality fromValue(Object? value) => switch (value) {
        'low' => ImageQuality.low,
        'medium' => ImageQuality.medium,
        'high' => ImageQuality.high,
        'original' => ImageQuality.original,
        _ => ImageQuality.auto,
      };
}

enum ImageRole { hero, card }

class ImageQualityPreferences {
  const ImageQualityPreferences({
    this.hero = ImageQuality.auto,
    this.card = ImageQuality.auto,
    this.saveCellularData = false,
  });

  factory ImageQualityPreferences.fromSettings(Map<String, dynamic> settings) =>
      ImageQualityPreferences(
        hero: ImageQuality.fromValue(settings['heroImageQuality']),
        card: ImageQuality.fromValue(settings['cardImageQuality']),
        saveCellularData: settings['saveCellularData'] == true,
      );

  final ImageQuality hero;
  final ImageQuality card;
  final bool saveCellularData;

  ImageQuality forRole(ImageRole role, {bool isCellular = false}) {
    final selected = role == ImageRole.hero ? hero : card;
    if (!saveCellularData || !isCellular) return selected;
    return switch (selected) {
      ImageQuality.original => ImageQuality.high,
      ImageQuality.high => ImageQuality.medium,
      ImageQuality.medium => ImageQuality.low,
      ImageQuality.auto => ImageQuality.low,
      ImageQuality.low => ImageQuality.low,
    };
  }
}
