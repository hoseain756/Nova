import 'package:nova_mobile/shared/widgets/nova_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/media_item.dart';
import '../../core/models/visual_preferences.dart';
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
      padding: EdgeInsetsDirectional.fromSTEB(
          NovaSpace.gutter(MediaQuery.sizeOf(context).width),
          compact ? 20 : 40,
          NovaSpace.gutter(MediaQuery.sizeOf(context).width),
          28),
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
          Semantics(
            header: true,
            child: Text(title,
                style: (compact
                        ? theme.textTheme.headlineLarge
                        : theme.textTheme.displaySmall)
                    ?.copyWith(height: 1.18)),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.55))),
          const SizedBox(height: 24),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ]);
        if (constraints.maxWidth < 840 ||
            MediaQuery.textScalerOf(context).scale(16) > 24 ||
            actions.isEmpty) {
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

/// An artwork-led spread. Copy flows beneath the image on phones and beside it
/// on tablets, so large type never competes with a fixed-height image overlay.
class NovaBrowseFeature extends StatelessWidget {
  const NovaBrowseFeature(
      {super.key,
      required this.item,
      required this.label,
      required this.actionLabel,
      required this.onOpen,
      this.quality = ImageQuality.auto});
  final MediaItem item;
  final String label;
  final String actionLabel;
  final VoidCallback onOpen;
  final ImageQuality quality;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gutter = NovaSpace.gutter(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, 40),
      child: LayoutBuilder(builder: (context, constraints) {
        final hasLandscapeArtwork = item.background?.trim().isNotEmpty == true;
        final artworkUrl = hasLandscapeArtwork ? item.background : item.poster;
        final wide = constraints.maxWidth >= 760;
        final artworkWidth =
            wide ? constraints.maxWidth * .62 : constraints.maxWidth;
        final artwork = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: artworkUrl != null && artworkUrl.trim().isNotEmpty
                  ? NovaNetworkImage(
                      artworkUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: hasLandscapeArtwork ? BoxFit.cover : BoxFit.contain,
                      cacheWidth: imageCacheWidth(context, artworkWidth),
                      quality: quality,
                      providerKind: hasLandscapeArtwork
                          ? ProviderImageKind.backdrop
                          : ProviderImageKind.poster,
                      excludeFromSemantics: true,
                    )
                  : Icon(LucideIcons.film,
                      size: 64, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        );
        final copy = Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              wide ? 28 : 0, wide ? 8 : 20, 0, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 12),
            Text(item.name, style: theme.textTheme.headlineMedium),
            if (item.releaseInfo?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(item.releaseInfo!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: Text(actionLabel, style: theme.textTheme.labelLarge)),
              const SizedBox(width: 12),
              Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? LucideIcons.arrowUpLeft
                      : LucideIcons.arrowUpRight,
                  color: theme.colorScheme.primary),
            ]),
          ]),
        );
        return Semantics(
          key: const ValueKey('nova-browse-hero'),
          button: true,
          onTap: onOpen,
          label: '$actionLabel: ${item.name}',
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(12),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                          Expanded(flex: 62, child: artwork),
                          Expanded(flex: 38, child: copy),
                        ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [artwork, copy]),
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
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 20, 0, 20),
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

/// All sheet content shares one scroll owner, including title and actions.
/// Padding consumes the actual keyboard inset; a short window never leaves a
/// fixed header above an unusably small list.
class NovaBrowseSheet extends StatelessWidget {
  const NovaBrowseSheet({super.key, required this.slivers});
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: slivers,
          ),
        ),
      );
}

class NovaBrowseSheetHeading extends StatelessWidget {
  const NovaBrowseSheetHeading({
    super.key,
    required this.title,
    required this.closeLabel,
    required this.onClose,
    this.subtitle,
  });
  final String title, closeLabel;
  final String? subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 12, 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                  header: true,
                  child: Text(title,
                      style: MediaQuery.sizeOf(context).height -
                                  MediaQuery.viewInsetsOf(context).bottom <
                              500
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.headlineMedium)),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ]),
          ),
          IconButton(
              tooltip: closeLabel,
              onPressed: onClose,
              icon: const Icon(LucideIcons.x)),
        ]),
      );
}
