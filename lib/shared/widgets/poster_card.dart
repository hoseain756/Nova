import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/models/visual_preferences.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/horse_theme.dart';
import 'image_decode.dart';
import 'media_quick_look.dart';
import 'nova_network_image.dart';

/// Artwork first card used by rails, grids, and search results.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width,
    this.showText,
    this.preferencesOverride,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final double? width;
  final bool? showText;
  final CardPreferences? preferencesOverride;

  @override
  Widget build(BuildContext context) {
    final (language, tmdbEnabled, basicInfo, artwork) =
        context.select<AppState, (String, bool, bool, bool)>((app) => (
              app.contentTmdbLocale,
              app.webSettings['tmdbEnabled'] != false,
              app.webSettings['tmdbUseBasicInfo'] != false,
              app.webSettings['tmdbUseArtwork'] != false,
            ));
    if (!tmdbEnabled || !basicInfo || !RegExp(r'^tt\d+$').hasMatch(item.id)) {
      return _PosterCardContent(
          item: item,
          onTap: onTap,
          width: width,
          showText: showText,
          preferencesOverride: preferencesOverride);
    }
    return FutureBuilder<MediaItem>(
      future: context
          .read<AppState>()
          .catalogs
          .localizedItem(item, language, artworkEnabled: artwork),
      builder: (context, snapshot) => _PosterCardContent(
        item: snapshot.data ?? item,
        onTap: onTap,
        width: width,
        showText: showText,
        preferencesOverride: preferencesOverride,
      ),
    );
  }
}

class _PosterCardContent extends StatelessWidget {
  const _PosterCardContent({
    required this.item,
    required this.onTap,
    required this.width,
    required this.showText,
    this.preferencesOverride,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final double? width;
  final bool? showText;
  final CardPreferences? preferencesOverride;

  @override
  Widget build(BuildContext context) {
    final (savedPreferences, quality, settingShowTitle, showRating) = context
        .select<AppState, (CardPreferences, ImageQuality, bool, bool)>((app) {
      final settings = app.webSettings;
      return (
        CardPreferences.fromSettings(settings),
        ImageQualityPreferences.fromSettings(settings).card,
        settings['hidePosterTitles'] != true,
        settings['showImdbBadge'] != false &&
            settings['showCardBadges'] != false,
      );
    });
    final preferences = preferencesOverride ?? savedPreferences;
    final cardWidth = width ??
        preferences.dimensions(MediaQuery.sizeOf(context).width).railWidth;
    final showTitle = showText ?? settingShowTitle;
    return SizedBox(
      width: cardWidth,
      child: Semantics(
        button: true,
        label: item.name,
        child: InkWell(
          borderRadius: BorderRadius.circular(preferences.radius),
          onTap: onTap,
          onLongPress: () => showMediaQuickLook(
            context,
            item: item,
            onOpen: onTap,
          ),
          child: preferences.isHorizontal
              ? _horizontalCard(context, preferences, quality, showTitle,
                  showRating, cardWidth)
              : _verticalCard(context, preferences, quality, showTitle,
                  showRating, cardWidth),
        ),
      ),
    );
  }

  Widget _verticalCard(
    BuildContext context,
    CardPreferences preferences,
    ImageQuality quality,
    bool showTitle,
    bool showRating,
    double cardWidth,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: CardDimensions.verticalArtworkRatio,
            child:
                _artwork(context, preferences, quality, showRating, cardWidth),
          ),
          if (showTitle) ...[
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
            ),
            if (item.releaseInfo != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 3),
                child: Text(
                  item.releaseInfo!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ],
      );

  Widget _horizontalCard(
    BuildContext context,
    CardPreferences preferences,
    ImageQuality quality,
    bool showTitle,
    bool showRating,
    double cardWidth,
  ) {
    final dimensions = preferences.dimensions(MediaQuery.sizeOf(context).width);
    final artworkWidth = cardWidth * dimensions.horizontalArtworkWidthFraction;
    final height = dimensions.horizontalExtent(
        cardWidth, MediaQuery.textScalerOf(context).scale(1));
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: artworkWidth,
            child: _artwork(
                context, preferences, quality, showRating, artworkWidth),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showTitle)
                    Text(
                      item.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                    ),
                  if (showTitle && item.releaseInfo != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.releaseInfo!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _artwork(
    BuildContext context,
    CardPreferences preferences,
    ImageQuality quality,
    bool showRating,
    double artworkWidth,
  ) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(preferences.radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.poster != null)
              NovaNetworkImage(
                item.poster!,
                width: artworkWidth,
                fit: BoxFit.cover,
                cacheWidth: imageCacheWidthForQuality(
                  context,
                  artworkWidth,
                  quality: quality,
                ),
                quality: quality,
                errorBuilder: (_, __, ___) => const _PosterFallback(),
              )
            else
              const _PosterFallback(),
            if (showRating && item.rating != null)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: NovaColors.ink.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.star,
                            color: NovaColors.rating, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          item.rating!,
                          style: const TextStyle(
                            color: NovaColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();
  @override
  Widget build(BuildContext context) => Container(
        color: NovaTheme.of(context).raised,
        child: Center(
          child: Icon(LucideIcons.film,
              size: 34, color: NovaTheme.of(context).gold),
        ),
      );
}
