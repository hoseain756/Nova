import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/media_item.dart';
import '../../../core/models/visual_preferences.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/horse_theme.dart';
import '../../../shared/widgets/media_rail.dart';
import '../top10_rail.dart';

/// One home catalog row driven by a future: the geometry-matched rail
/// skeleton while waiting, a title + message + retry row on error/empty
/// (Top 10 rows only — other rows fail/empty silently), else the standard
/// poster rail or the ranked Top 10 layout. Moved verbatim from
/// home_page.dart (Task 121-c).
class AsyncMediaSection extends StatelessWidget {
  const AsyncMediaSection({
    super.key,
    required this.title,
    required this.future,
    required this.onTap,
    required this.onRetry,
    required this.english,
    this.subtitle,
    this.numbered = false,
    this.showEmptyState = false,
    this.onOpenSection,
  });

  final String title;

  /// Optional source line under the rail title (the add-on name, mirroring
  /// the web Rail subtitle).
  final String? subtitle;
  final Future<List<MediaItem>> future;
  final ValueChanged<MediaItem> onTap;
  final VoidCallback onRetry;
  final bool english;
  final bool numbered;
  final bool showEmptyState;

  /// Opens the full catalog section this rail belongs to (the header
  /// "greater-than" mark).
  final VoidCallback? onOpenSection;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<MediaItem>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return RailLoadingSkeleton(title: title);
          }
          final items = snapshot.data ?? const <MediaItem>[];
          if (snapshot.hasError) {
            return _RailMessage(
              title: title,
              message: NovaStrings.lookup(english, 'message119'),
              actionLabel: NovaStrings.lookup(english, 'message120'),
              onRetry: onRetry,
            );
          }
          if (items.isEmpty) {
            if (!showEmptyState) return const SizedBox.shrink();
            return _RailMessage(
              title: title,
              message: NovaStrings.lookup(english, 'message121'),
              actionLabel: NovaStrings.lookup(english, 'message68'),
              onRetry: onRetry,
            );
          }
          return Padding(
            padding: EdgeInsetsDirectional.only(
              bottom: MediaRail.sectionSpacing(context),
            ),
            // The Top 10 row uses the ranked sticker layout; every other
            // section keeps the standard poster rail.
            child: numbered
                ? Top10Rail(title: title, items: items, onTap: onTap)
                : MediaRail(
                    title: title,
                    subtitle: subtitle,
                    items: items,
                    onTap: onTap,
                    onOpenSection: onOpenSection,
                  ),
          );
        },
      );
}

/// Loading placeholder matching the real rail's geometry: title, then a
/// horizontal row of surface "posters" (138px wide at the 700px breakpoint,
/// else 122) with the two-line label stub when poster titles are shown.
class RailLoadingSkeleton extends StatelessWidget {
  const RailLoadingSkeleton({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final (preferences, showTitle) =
        context.select<AppState, (CardPreferences, bool)>((app) => (
              CardPreferences.fromSettings(app.webSettings),
              app.webSettings['hidePosterTitles'] != true,
            ));
    final width = MediaQuery.sizeOf(context).width;
    final dimensions = preferences.dimensions(width);
    final posterWidth = dimensions.railWidth;
    final posterHeight = preferences.isHorizontal
        ? dimensions.horizontalExtent(
            posterWidth, MediaQuery.textScalerOf(context).scale(1))
        : posterWidth / CardDimensions.verticalArtworkRatio;
    final labelHeight = showTitle && !preferences.isHorizontal
        ? 11 +
            MediaQuery.textScalerOf(context).scale(14) * 1.3 * 2 +
            MediaQuery.textScalerOf(context).scale(12) * 1.3
        : 0.0;
    final railHeight = posterHeight + labelHeight;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaRail.sectionSpacing(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          SizedBox(height: MediaRail.headerSpacing(context)),
          SizedBox(
            height: railHeight,
            child: ListView.separated(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, __) => SizedBox(
                width: (width * .035).clamp(12.0, 18.0).toDouble(),
              ),
              itemBuilder: (_, __) => SizedBox(
                width: posterWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: posterHeight,
                      child: preferences.isHorizontal
                          ? Row(children: [
                              SizedBox(
                                width: posterWidth *
                                    dimensions.horizontalArtworkWidthFraction,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: NovaTheme.of(context).surface,
                                    borderRadius: BorderRadius.circular(
                                        preferences.radius),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _SkeletonLine(width: 84, height: 11),
                                      SizedBox(height: 8),
                                      _SkeletonLine(width: 58, height: 9),
                                    ],
                                  ),
                                ),
                              ),
                            ])
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                color: NovaTheme.of(context).surface,
                                borderRadius:
                                    BorderRadius.circular(preferences.radius),
                              ),
                            ),
                    ),
                    if (showTitle && !preferences.isHorizontal) ...[
                      const SizedBox(height: 8),
                      _SkeletonLine(width: 96, height: 11),
                      const SizedBox(height: 5),
                      _SkeletonLine(width: 64, height: 9),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: NovaTheme.of(context).surface,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
}

/// Rail-level error/empty message: title line, message, then the retry
/// [TextButton.icon]. Deliberately NOT the shared [AppStateMessage] — that
/// widget renders a centered icon-over-text column for page-level states,
/// while this rail-level row keeps its start-aligned title + inline button
/// shape (audit 121-a2: a different family).
class _RailMessage extends StatelessWidget {
  const _RailMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onRetry,
  });
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          20,
          4,
          20,
          MediaRail.sectionSpacing(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.refreshCw),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      );
}
