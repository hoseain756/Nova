import 'package:nova_mobile/shared/widgets/nova_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/media_item.dart';
import '../../core/theme/nova_theme.dart';
import '../../shared/widgets/image_decode.dart';

/// Shared editorial hierarchy for NOVA's browse destinations. The generous
/// title area wraps instead of assuming a fixed title/toolbar height.
class NovaBrowseHeader extends StatelessWidget {
  const NovaBrowseHeader(
      {super.key,
      required this.title,
      required this.subtitle,
      this.eyebrow,
      this.actions = const [],
      this.compact = false});
  final String title;
  final String subtitle;
  final String? eyebrow;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(24, compact ? 16 : 32, 24, 24),
      child: LayoutBuilder(builder: (context, constraints) {
        final copy =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (eyebrow != null) ...[
            Text(eyebrow!,
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
          ],
          Text(title,
              style: theme.textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 8),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.65))),
        ]);
        if (constraints.maxWidth < 680 || actions.isEmpty) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: copy),
          const SizedBox(width: 24),
          Flexible(child: Wrap(spacing: 8, runSpacing: 8, children: actions)),
        ]);
      }),
    );
  }
}

/// Static skeletons intentionally avoid a page-wide perpetual shimmer.
class NovaBrowseSkeleton extends StatelessWidget {
  const NovaBrowseSkeleton({super.key, this.rows = false});
  final bool rows;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ExcludeSemantics(
        child: rows
            ? ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, __) => Container(
                    height: 104,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(20))),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: 12,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: .61,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 24),
                itemBuilder: (_, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: Container(
                              decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(16)))),
                      const SizedBox(height: 12),
                      Container(height: 12, width: 112, color: color),
                      const SizedBox(height: 8),
                      Container(height: 8, width: 64, color: color),
                    ]),
              ));
  }
}

/// A landscape feature card that keeps the same 16:9 artwork frame on phones
/// and tablets. Text stays outside the image semantics; the whole card opens.
class NovaBrowseFeature extends StatelessWidget {
  const NovaBrowseFeature(
      {super.key,
      required this.item,
      required this.label,
      required this.actionLabel,
      required this.onOpen});
  final MediaItem item;
  final String label;
  final String actionLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
      child: LayoutBuilder(builder: (context, constraints) {
        final hasLandscapeArtwork = item.background?.trim().isNotEmpty == true;
        final artworkUrl = hasLandscapeArtwork ? item.background : item.poster;
        final width = constraints.maxWidth;
        final compact = width < 600;
        final showLabel = width * 9 / 16 >= 180 ||
            MediaQuery.textScalerOf(context).scale(16) <= 22;
        return AspectRatio(
          key: const ValueKey('nova-browse-hero'),
          aspectRatio: 16 / 9,
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (artworkUrl != null && artworkUrl.trim().isNotEmpty)
                    NovaNetworkImage(
                      artworkUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: hasLandscapeArtwork ? BoxFit.cover : BoxFit.contain,
                      cacheWidth: imageCacheWidth(context, width),
                      excludeFromSemantics: true,
                    )
                  else
                    Center(
                      child: Icon(LucideIcons.film,
                          size: 64, color: theme.colorScheme.secondary),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          NovaColors.ink.withValues(alpha: .72),
                          NovaColors.ink.withValues(alpha: .08),
                          NovaColors.ink.withValues(alpha: .92),
                        ],
                        stops: const [0, .35, 1],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(compact ? 16 : 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showLabel)
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: NovaColors.white,
                                fontWeight: FontWeight.w700,
                              )),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: (compact
                                          ? theme.textTheme.titleLarge
                                          : theme.textTheme.headlineLarge)
                                      ?.copyWith(
                                          color: NovaColors.white,
                                          fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 12),
                            Tooltip(
                              message: actionLabel,
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: theme.colorScheme.primary,
                                child: Icon(LucideIcons.arrowUpRight,
                                    color: theme.colorScheme.onPrimary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Same logical spacing for both directions, with generous touch/focus bounds.
class NovaBrowseDestination extends StatelessWidget {
  const NovaBrowseDestination(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Icon(icon,
                    color: Theme.of(context).colorScheme.secondary, size: 24),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ])),
                const SizedBox(width: 8),
                Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? LucideIcons.chevronLeft
                        : LucideIcons.chevronRight,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ])),
        ),
      );
}
