import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/models/visual_preferences.dart';
import '../../core/state/app_state.dart';
import '../../shared/widgets/media_quick_look.dart';
import '../../shared/widgets/poster_card.dart';

/// Ranked rail with the same artwork geometry and quality as other media rows.
class Top10Rail extends StatelessWidget {
  const Top10Rail({
    super.key,
    required this.title,
    required this.items,
    required this.onTap,
  });

  final String title;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final preferences = context.select<AppState, CardPreferences>(
        (app) => CardPreferences.fromSettings(app.webSettings));
    final dimensions = preferences.dimensions(viewportWidth);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final artworkHeight = preferences.isHorizontal
        ? dimensions.horizontalExtent(dimensions.railWidth, scale)
        : dimensions.railWidth / CardDimensions.verticalArtworkRatio;
    final railHeight = artworkHeight + 12 + 54 * scale;
    final wide = viewportWidth >= 700;
    final gutter = wide ? 34.0 : 20.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: gutter),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: railHeight,
          child: ListView.separated(
            padding: EdgeInsetsDirectional.symmetric(horizontal: gutter),
            scrollDirection: Axis.horizontal,
            itemCount: items.length.clamp(0, 10),
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) => Top10Item(
              rank: index + 1,
              item: items[index],
              onTap: () => onTap(items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class Top10Item extends StatelessWidget {
  const Top10Item({
    super.key,
    required this.rank,
    required this.item,
    required this.onTap,
  });

  final int rank;
  final MediaItem item;
  final VoidCallback onTap;

  /// Kept for older callers; the actual extent follows the card preference.
  static const double itemHeight = 288;

  @override
  Widget build(BuildContext context) {
    final preferences = context.select<AppState, CardPreferences>(
        (app) => CardPreferences.fromSettings(app.webSettings));
    final width =
        preferences.dimensions(MediaQuery.sizeOf(context).width).railWidth;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PosterCard(
            item: item,
            onTap: onTap,
            width: width,
            showText: preferences.isHorizontal,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onTap,
            onLongPress: () =>
                showMediaQuickLook(context, item: item, onOpen: onTap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rank.toString().padLeft(2, '0'),
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.secondary, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                if (!preferences.isHorizontal)
                  Expanded(
                    child: Text(item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compatibility for downstream consumers of the earlier ranking presenter.
class OutlinedRankNumber extends StatelessWidget {
  const OutlinedRankNumber(
      {super.key, required this.rank, required this.fontSize});
  final int rank;
  final double fontSize;
  static const String rankFontFamily = 'Tajawal';
  @override
  Widget build(BuildContext context) => Text('$rank',
      textDirection: TextDirection.ltr,
      style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.secondary));
}
