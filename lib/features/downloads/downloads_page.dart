import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/downloads/download_manager.dart';
import '../../core/models/media_item.dart';
import '../../l10n/nova_strings.dart';
import '../../shared/widgets/app_state_message.dart';
import '../../shared/widgets/noor_toast.dart';
import '../player/playback_entry_page.dart';
import 'downloads_view.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, this.manager});

  @visibleForTesting
  final DownloadManager? manager;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
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
            child: Text(s.text('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.text('remove')),
          ),
        ],
      ),
    );
    if (yes == true) await _action(() => _manager.remove(job));
  }

  void _play(NovaDownload job) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlaybackEntryPage(
            item: MediaItem(
                id: 'local:${job.id}',
                name: job.title,
                type: 'movie',
                poster: job.poster),
            url: job.path,
            streamName: job.title,
            videoId: job.id,
            recordProgress: false,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
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
                  onAction: error
                      ? () => unawaited(_action(_manager.initialize))
                      : null,
                );
              }
              return DownloadsView(
                jobs: _manager.jobs,
                storageError: _manager.storageError,
                onPlay: _play,
                onCancel: (job) =>
                    unawaited(_action(() => _manager.cancel(job))),
                onRetry: (job) => unawaited(_action(() => _manager.retry(job))),
                onRemove: (job) => unawaited(_remove(job)),
              );
            },
          ),
        ),
      ),
    );
  }
}
