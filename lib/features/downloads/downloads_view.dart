import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/downloads/download_manager.dart';
import '../../core/theme/nova_theme.dart';
import '../../l10n/nova_strings.dart';
import '../../shared/widgets/app_state_message.dart';
import '../../shared/widgets/image_decode.dart';
import '../../shared/widgets/nova_network_image.dart';

/// The download library's presentation. Transfer ownership stays in
/// [DownloadManager]; actions are supplied by the route.
class DownloadsView extends StatelessWidget {
  const DownloadsView({
    super.key,
    required this.jobs,
    required this.onPlay,
    required this.onCancel,
    required this.onRetry,
    required this.onRemove,
    this.storageError,
  });

  final List<NovaDownload> jobs;
  final String? storageError;
  final ValueChanged<NovaDownload> onPlay;
  final ValueChanged<NovaDownload> onCancel;
  final ValueChanged<NovaDownload> onRetry;
  final ValueChanged<NovaDownload> onRemove;

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final active = jobs
        .where((job) => job.status == 'downloading' || job.status == 'queued')
        .toList(growable: false);
    final ready =
        jobs.where((job) => job.status == 'complete').toList(growable: false);
    final attention = jobs
        .where((job) =>
            job.status != 'downloading' &&
            job.status != 'queued' &&
            job.status != 'complete')
        .toList(growable: false);
    final savedBytes = ready.fold<int>(
      0,
      (sum, job) => sum + (job.total > 0 ? job.total : job.received),
    );
    final sections = <(String, List<NovaDownload>)>[
      (s.text('downloadActiveSection'), active),
      (s.text('downloadReadySection'), ready),
      (s.text('downloadAttentionSection'), attention),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final gutter = NovaSpace.gutter(constraints.maxWidth);
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(
                gutter, NovaSpace.lg, gutter, NovaSpace.lg),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.text('downloadIntro'),
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: NovaSpace.sm),
                  Text(
                    s.text('downloadLibrarySummary', {
                      'ready': ready.length,
                      'active': active.length,
                    }),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (savedBytes > 0) ...[
                    const SizedBox(height: NovaSpace.xs),
                    Text(
                      s.text('downloadSavedSize', {'size': _size(savedBytes)}),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (storageError != null) ...[
                    const SizedBox(height: NovaSpace.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.circleAlert,
                            size: 20, color: scheme.error),
                        const SizedBox(width: NovaSpace.sm),
                        Expanded(
                          child: Text(s.text('downloadStorageError'),
                              style: TextStyle(color: scheme.error)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (jobs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppStateMessage(
                icon: LucideIcons.download,
                message:
                    '${s.text('downloadsEmpty')}\n${s.text('downloadsEmptyBody')}',
              ),
            )
          else
            for (final section in sections)
              if (section.$2.isNotEmpty) ...[
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                      gutter, NovaSpace.sm, gutter, NovaSpace.md),
                  sliver: SliverToBoxAdapter(
                    child: Semantics(
                      header: true,
                      child: Text(section.$1,
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: gutter),
                  sliver: SliverList.builder(
                    itemCount: section.$2.length,
                    itemBuilder: (context, index) {
                      final job = section.$2[index];
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(
                            bottom: NovaSpace.md),
                        child: DownloadRow(
                          job: job,
                          onPlay: () => onPlay(job),
                          onCancel: () => onCancel(job),
                          onRetry: () => onRetry(job),
                          onRemove: () => onRemove(job),
                        ),
                      );
                    },
                  ),
                ),
              ],
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(
                gutter, NovaSpace.sm, gutter, NovaSpace.xxl),
            sliver: SliverToBoxAdapter(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding:
                    const EdgeInsetsDirectional.only(bottom: NovaSpace.md),
                leading: const Icon(LucideIcons.info),
                title: Text(s.text('downloadBackgroundInfo')),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(s.text('downloadForeground'),
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

class DownloadRow extends StatelessWidget {
  const DownloadRow({
    super.key,
    required this.job,
    required this.onPlay,
    required this.onCancel,
    required this.onRetry,
    required this.onRemove,
  });

  final NovaDownload job;
  final VoidCallback onPlay, onCancel, onRetry, onRemove;

  String _statusKey() => switch (job.status) {
        'complete' => 'downloadComplete',
        'downloading' => 'downloading',
        'queued' => 'downloadQueued',
        'cancelled' => 'downloadCancelled',
        _ => 'downloadFailed',
      };

  String _failureKey() => switch (job.error) {
        'storage' => 'downloadStorageError',
        'interrupted' => 'downloadInterrupted',
        'missingFile' => 'downloadMissingFile',
        'invalidSource' => 'downloadInvalidSource',
        'backgroundLimit' => 'downloadBackgroundLimit',
        _ => 'downloadNetworkError',
      };

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isActive = job.status == 'downloading' || job.status == 'queued';
    final isReady = job.status == 'complete';
    final failed = job.status == 'failed';
    final progress = job.total > 0
        ? (job.received / job.total).clamp(0.0, 1.0).toDouble()
        : null;
    final statusColor = failed
        ? scheme.error
        : isReady || isActive
            ? scheme.secondary
            : scheme.onSurfaceVariant;
    final actionSuffix = ': ${job.title}';

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DownloadPoster(job: job),
                const SizedBox(width: NovaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: NovaSpace.sm),
                      Row(
                        children: [
                          Icon(
                            failed
                                ? LucideIcons.circleAlert
                                : isReady
                                    ? LucideIcons.circleCheck
                                    : LucideIcons.download,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: NovaSpace.xs),
                          Expanded(
                            child: Text(s.text(_statusKey()),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: statusColor)),
                          ),
                        ],
                      ),
                      if (job.received > 0 || job.total > 0) ...[
                        const SizedBox(height: NovaSpace.xs),
                        Text(
                          s.text('downloadBytes', {
                            'received': _size(job.received),
                            'total': _size(job.total),
                          }),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (failed) ...[
                        const SizedBox(height: NovaSpace.xs),
                        Text(s.text(_failureKey()),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.error)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (job.status == 'downloading') ...[
              const SizedBox(height: NovaSpace.md),
              LinearProgressIndicator(
                value: progress,
                semanticsLabel: s.text('downloading'),
                semanticsValue:
                    progress == null ? null : '${(progress * 100).round()}%',
              ),
              if (progress != null) ...[
                const SizedBox(height: NovaSpace.xs),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text('${(progress * 100).round()}%',
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.labelSmall),
                ),
              ],
            ],
            const SizedBox(height: NovaSpace.md),
            Wrap(
              spacing: NovaSpace.sm,
              runSpacing: NovaSpace.sm,
              children: [
                if (isReady)
                  _AccessibleDownloadAction(
                    label: '${s.text('playOffline')}$actionSuffix',
                    onPressed: onPlay,
                    child: FilledButton.icon(
                      onPressed: onPlay,
                      icon: const Icon(LucideIcons.play),
                      label: Text(s.text('playOffline')),
                    ),
                  )
                else if (isActive)
                  _AccessibleDownloadAction(
                    label: '${s.text('cancel')}$actionSuffix',
                    onPressed: onCancel,
                    child: TextButton(
                        onPressed: onCancel, child: Text(s.text('cancel'))),
                  )
                else
                  _AccessibleDownloadAction(
                    label: '${s.text('retry')}$actionSuffix',
                    onPressed: onRetry,
                    child: OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(LucideIcons.rotateCw),
                      label: Text(s.text('retry')),
                    ),
                  ),
                _AccessibleDownloadAction(
                  label: '${s.text('remove')}$actionSuffix',
                  onPressed: onRemove,
                  child: TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(LucideIcons.trash2),
                    label: Text(s.text('remove')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadPoster extends StatelessWidget {
  const _DownloadPoster({required this.job});
  final NovaDownload job;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = job.poster?.trim();
    final uri = url == null ? null : Uri.tryParse(url);
    final displayImage = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    Widget fallback() => ColoredBox(
          color: scheme.surfaceContainerHigh,
          child: Center(
            child: Icon(LucideIcons.film,
                size: 28, color: scheme.onSurfaceVariant),
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 96,
        child: displayImage
            ? NovaNetworkImage(
                url!,
                width: 64,
                height: 96,
                fit: BoxFit.cover,
                cacheWidth: imageCacheWidth(context, 64),
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => fallback(),
              )
            : fallback(),
      ),
    );
  }
}

class _AccessibleDownloadAction extends StatelessWidget {
  const _AccessibleDownloadAction({
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        button: true,
        onTap: onPressed,
        excludeSemantics: true,
        child: ExcludeSemantics(child: child),
      );
}

String _size(int bytes) => bytes < 1
    ? '—'
    : bytes >= 1073741824
        ? '${(bytes / 1073741824).toStringAsFixed(1)} GB'
        : '${(bytes / 1048576).toStringAsFixed(1)} MB';
