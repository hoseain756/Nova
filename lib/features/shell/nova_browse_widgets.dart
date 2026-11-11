import '../../shared/widgets/poster_layout.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    final style = watchPosterStyle(context);
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
            : LayoutBuilder(builder: (context, constraints) {
                final metrics = PosterGridMetrics(
                    context, constraints.maxWidth - 48,
                    spacing: 16, style: style);
                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: 12,
                  gridDelegate: metrics.delegate,
                  itemBuilder: (_, __) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: Container(
                                decoration: BoxDecoration(
                                    color: color,
                                    borderRadius:
                                        BorderRadius.circular(style.radius)))),
                        if (!style.hideTitles) ...[
                          const SizedBox(height: 12),
                          Container(height: 12, width: 112, color: color),
                          const SizedBox(height: 8),
                          Container(height: 8, width: 64, color: color),
                        ],
                      ]),
                );
              }));
  }
}

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
