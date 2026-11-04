import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/nova_theme.dart';
import '../../../shared/widgets/shimmer_box.dart';

/// Presentation shared by tracker discussions and Letterboxd review previews.
class DetailDiscussionEntry {
  const DetailDiscussionEntry({
    required this.id,
    required this.source,
    this.author,
    this.title,
    required this.body,
    required this.hidden,
    required this.onReveal,
    this.onOpen,
    required this.openLabel,
  });

  final String id, source, body, openLabel;
  final String? author, title;
  final bool hidden;
  final VoidCallback onReveal;
  final VoidCallback? onOpen;
}

class DetailDiscussionRail extends StatelessWidget {
  const DetailDiscussionRail({
    super.key,
    required this.title,
    required this.entries,
    required this.hiddenLabel,
    required this.revealLabel,
    required this.readLabel,
    this.loading = false,
  });

  final String title, hiddenLabel, revealLabel, readLabel;
  final List<DetailDiscussionEntry> entries;
  final bool loading;

  double _lineHeight(BuildContext context, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) {
    if (!loading && entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final headerHeight = math.max(
      32.0,
      _lineHeight(context, theme.textTheme.titleSmall) +
          _lineHeight(context, theme.textTheme.labelMedium) +
          NovaSpace.xs,
    );
    // Reserve real scaled line boxes, including wrapped action labels. This
    // keeps the horizontal viewport bounded without clipping enlarged text.
    final bodyHeight = math.max(
      _lineHeight(context, theme.textTheme.bodyMedium) * 6,
      _lineHeight(context, theme.textTheme.titleSmall) * 2 +
          _lineHeight(context, theme.textTheme.bodyMedium) * 4 +
          NovaSpace.sm,
    );
    final footerHeight = math.max(
      48.0,
      _lineHeight(context, theme.textTheme.labelLarge) * 2 + NovaSpace.md,
    );
    final height = headerHeight + bodyHeight + footerHeight + NovaSpace.md * 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: NovaSpace.md),
        LayoutBuilder(builder: (context, constraints) {
          final count = loading ? 3 : entries.length;
          final available = constraints.maxWidth;
          final width = math
              .min(
                360.0,
                count > 1 && available < 480
                    ? available - NovaSpace.xl
                    : available,
              )
              .clamp(1.0, double.infinity);
          return SizedBox(
            height: height,
            child: ListView.separated(
              key: const ValueKey('detail-discussion-scroll'),
              primary: false,
              scrollDirection: Axis.horizontal,
              itemCount: count,
              separatorBuilder: (_, __) => const SizedBox(width: NovaSpace.md),
              itemBuilder: (context, index) => SizedBox(
                width: width,
                child: loading
                    ? const _LoadingCard()
                    : _DiscussionCard(
                        key: ValueKey(entries[index].id),
                        entry: entries[index],
                        hiddenLabel: hiddenLabel,
                        revealLabel: revealLabel,
                        readLabel: readLabel,
                        headerHeight: headerHeight,
                        footerHeight: footerHeight,
                      ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _DiscussionCard extends StatelessWidget {
  const _DiscussionCard({
    super.key,
    required this.entry,
    required this.hiddenLabel,
    required this.revealLabel,
    required this.readLabel,
    required this.headerHeight,
    required this.footerHeight,
  });

  final DetailDiscussionEntry entry;
  final String hiddenLabel, revealLabel, readLabel;
  final double headerHeight, footerHeight;

  void _read(BuildContext context) {
    final direction = Directionality.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (context) => Directionality(
        textDirection: direction,
        child: _DiscussionReader(entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasTitle = entry.title?.isNotEmpty == true;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(NovaSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: headerHeight, child: _EntryHeader(entry: entry)),
            const SizedBox(height: NovaSpace.md),
            Expanded(
              child: entry.hidden
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.eyeOff,
                            color: scheme.onSurfaceVariant, size: 24),
                        const SizedBox(height: NovaSpace.sm),
                        Text(hiddenLabel,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasTitle) ...[
                          Text(entry.title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall),
                          const SizedBox(height: NovaSpace.sm),
                        ],
                        Flexible(
                          child: Text(entry.body,
                              maxLines: hasTitle ? 4 : 6,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: NovaSpace.md),
            SizedBox(
              height: footerHeight,
              child: TextButton(
                onPressed: entry.hidden ? entry.onReveal : () => _read(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: NovaSpace.sm),
                  alignment: AlignmentDirectional.centerStart,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(entry.hidden ? revealLabel : readLabel,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: NovaSpace.sm),
                    Icon(entry.hidden ? LucideIcons.eye : LucideIcons.bookOpen,
                        size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryHeader extends StatelessWidget {
  const _EntryHeader({required this.entry});
  final DetailDiscussionEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = entry.author?.trim() ?? '';
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(LucideIcons.messageCircle,
              size: 24, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: NovaSpace.sm),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(author.isEmpty ? entry.source : author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall),
              if (author.isNotEmpty) ...[
                const SizedBox(height: NovaSpace.xs),
                Text(entry.source,
                    maxLines: 1,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscussionReader extends StatelessWidget {
  const _DiscussionReader({required this.entry});
  final DetailDiscussionEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Padding(
          padding: const EdgeInsets.all(NovaSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _EntryHeader(entry: entry)),
                  const SizedBox(width: NovaSpace.sm),
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
              const SizedBox(height: NovaSpace.md),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (entry.title?.isNotEmpty == true) ...[
                          Text(entry.title!,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: NovaSpace.md),
                        ],
                        Text(entry.body, style: theme.textTheme.bodyLarge),
                        if (entry.onOpen != null) ...[
                          const SizedBox(height: NovaSpace.lg),
                          TextButton.icon(
                            onPressed: entry.onOpen,
                            icon:
                                const Icon(LucideIcons.externalLink, size: 18),
                            label: Text(entry.openLabel),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(NovaSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: ShimmerBox(width: 128, height: 32),
              ),
              const SizedBox(height: NovaSpace.lg),
              for (var index = 0; index < 3; index++) ...[
                const ShimmerBox(height: 16),
                const SizedBox(height: NovaSpace.sm),
              ],
              const Spacer(),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: ShimmerBox(width: 112, height: 24),
              ),
              const SizedBox(height: NovaSpace.sm),
            ],
          ),
        ),
      );
}
