import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/downloads/download_manager.dart';
import '../../core/models/media_item.dart';
import '../../l10n/nova_strings.dart';
import '../../shared/widgets/app_state_message.dart';
import '../../shared/widgets/noor_toast.dart';
import '../player/playback_entry_page.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, this.manager});

  @visibleForTesting
  final DownloadManager? manager;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
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

class _DownloadsPageState extends State<DownloadsPage> {
  late final DownloadManager _manager =
      widget.manager ?? DownloadManager.instance;
  Timer? _refreshTimer;
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 2), (_) => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    try {
      await _manager.refreshSystemDownloads();
    } catch (_) {
      // The view remains usable and the next poll can recover.
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _size(int bytes) => bytes < 1
      ? '—'
      : bytes >= 1073741824
          ? '${(bytes / 1073741824).toStringAsFixed(1)} GB'
          : '${(bytes / 1048576).toStringAsFixed(1)} MB';
  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        NoorToast.show(
            context, NovaStrings.of(context).text('operationFailed'));
      }
    }
  }

  String _failure(String? code) => NovaStrings.of(context).text(switch (code) {
        'storage' => 'downloadStorageError',
        'interrupted' => 'downloadInterrupted',
        'missingFile' => 'downloadMissingFile',
        'invalidSource' => 'downloadInvalidSource',
        'backgroundLimit' => 'downloadBackgroundLimit',
        _ => 'downloadNetworkError',
      });

  Future<void> _remove(NovaDownload job) async {
    final s = NovaStrings.of(context);
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(s.text('downloadDelete')),
                content: Text(s.text('downloadDeleteBody')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(s.text('cancel'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(s.text('remove')))
                ]));
    if (yes == true) await _action(() => _manager.remove(job));
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
        appBar: AppBar(title: Text(s.text('downloads'))),
        body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: AnimatedBuilder(
                  animation: _manager,
                  builder: (context, _) {
                    if (!_manager.initialized) {
                      final error = _manager.initializationError != null;
                      return AppStateMessage(
                        loading: !error,
                        icon: LucideIcons.hardDrive,
                        message: error
                            ? s.text('downloadStorageError')
                            : s.text('downloads'),
                        actionLabel: error ? s.text('retry') : null,
                        onAction:
                            error ? () => _action(_manager.initialize) : null,
                      );
                    }
                    final jobs = _manager.jobs;
                    return CustomScrollView(slivers: [
                      SliverPadding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              24, 24, 24, 32),
                          sliver: SliverToBoxAdapter(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Icon(LucideIcons.download,
                                    size: 32, color: scheme.secondary),
                                const SizedBox(height: 16),
                                Semantics(
                                    header: true,
                                    child: Text(s.text('downloadIntro'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium)),
                                const SizedBox(height: 12),
                                Text(s.text('downloadForeground'),
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                if (_manager.storageError != null) ...[
                                  const SizedBox(height: 12),
                                  Text(s.text('downloadStorageError'),
                                      style: TextStyle(color: scheme.error)),
                                ],
                              ]))),
                      if (jobs.isEmpty)
                        SliverFillRemaining(
                            hasScrollBody: false,
                            child: AppStateMessage(
                                icon: LucideIcons.download,
                                message:
                                    '${s.text('downloadsEmpty')}\n${s.text('downloadsEmptyBody')}'))
                      else
                        SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            sliver: SliverList.builder(
                                itemCount: jobs.length,
                                itemBuilder: (context, index) {
                                  final job = jobs[index];
                                  final key = switch (job.status) {
                                    'complete' => 'downloadComplete',
                                    'downloading' => 'downloading',
                                    'queued' => 'downloadQueued',
                                    'cancelled' => 'downloadCancelled',
                                    _ => 'downloadFailed'
                                  };
                                  void playOffline() => Navigator.of(context)
                                          .push(MaterialPageRoute<void>(
                                        builder: (_) => PlaybackEntryPage(
                                            item: MediaItem(
                                                id: 'local:${job.id}',
                                                name: job.title,
                                                type: 'movie'),
                                            url: job.path,
                                            streamName: job.title,
                                            videoId: job.id,
                                            recordProgress: false),
                                      ));

                                  void cancelDownload() =>
                                      _action(() => _manager.cancel(job));
                                  void retryDownload() =>
                                      _action(() => _manager.retry(job));
                                  void removeDownload() => _remove(job);
                                  String actionLabel(String label) =>
                                      '$label: ${job.title}';

                                  return Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                          bottom: 24),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Container(
                                                  width: 64,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                      color: scheme
                                                          .surfaceContainerHigh,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12)),
                                                  child: Icon(
                                                      job.status == 'complete'
                                                          ? LucideIcons
                                                              .circleCheck
                                                          : LucideIcons.film,
                                                      color: scheme.secondary)),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    Text(job.title,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium),
                                                    const SizedBox(height: 4),
                                                    Text(s.text(key),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall),
                                                    if (job.status == 'failed')
                                                      Text(_failure(job.error),
                                                          style: TextStyle(
                                                              color: scheme
                                                                  .error)),
                                                    Text(
                                                        s.text(
                                                            'downloadBytes', {
                                                          'received': _size(
                                                              job.received),
                                                          'total':
                                                              _size(job.total)
                                                        }),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall),
                                                  ]))
                                            ]),
                                            const SizedBox(height: 12),
                                            if (job.status == 'downloading')
                                              LinearProgressIndicator(
                                                  value: job.total > 0
                                                      ? job.received / job.total
                                                      : null,
                                                  semanticsLabel:
                                                      s.text('downloading')),
                                            const SizedBox(height: 8),
                                            Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  if (job.status == 'complete')
                                                    _AccessibleDownloadAction(
                                                        label: actionLabel(
                                                            s.text(
                                                                'playOffline')),
                                                        onPressed: playOffline,
                                                        child: FilledButton.icon(
                                                            icon: const Icon(
                                                                LucideIcons
                                                                    .play),
                                                            label: Text(s.text(
                                                                'playOffline')),
                                                            onPressed:
                                                                playOffline))
                                                  else if (job.status ==
                                                          'downloading' ||
                                                      job.status == 'queued')
                                                    _AccessibleDownloadAction(
                                                        label: actionLabel(
                                                            s.text('cancel')),
                                                        onPressed:
                                                            cancelDownload,
                                                        child: TextButton(
                                                            onPressed: cancelDownload,
                                                            child: Text(s.text('cancel'))))
                                                  else
                                                    _AccessibleDownloadAction(label: actionLabel(s.text('retry')), onPressed: retryDownload, child: OutlinedButton.icon(onPressed: retryDownload, icon: const Icon(LucideIcons.rotateCw), label: Text(s.text('retry')))),
                                                  _AccessibleDownloadAction(
                                                      label: actionLabel(
                                                          s.text('remove')),
                                                      onPressed: removeDownload,
                                                      child: TextButton.icon(
                                                          onPressed:
                                                              removeDownload,
                                                          icon: const Icon(
                                                              LucideIcons
                                                                  .trash2),
                                                          label: Text(s.text(
                                                              'remove')))),
                                                ]),
                                            const SizedBox(height: 16),
                                            Divider(
                                                color: scheme.outlineVariant),
                                          ]));
                                })),
                      const SliverToBoxAdapter(child: SizedBox(height: 48)),
                    ]);
                  })),
        ));
  }
}
