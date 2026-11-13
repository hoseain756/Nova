import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/state/app_state.dart';
import '../../core/torrent/torrent_models.dart';
import '../../core/torrent/torrent_service.dart';
import '../../core/watch_party/watch_party_models.dart';
import '../../l10n/nova_strings.dart';
import '../player/playback_entry_page.dart';
import '../player/session/playback_session.dart';
import '../player/stream_headers.dart';
import 'sources_page.dart';
import 'stream_loading.dart';

/// Opens this exact video in the local source picker, resolves the selection,
/// and transfers its prepared torrent (if any) to the player.
///
/// Callers retain authorization policy and can invalidate an entry while its
/// picker or resolver is open. No metadata/history lookup changes its identity.
Future<void> launchMediaPlayback(
  BuildContext context, {
  required MediaItem item,
  required Map<String, dynamic>? video,
  int? resumePositionMs,
  WatchPartySource? lockedSource,
  bool Function()? canLaunch,
  ValueChanged<bool>? onLoadingChanged,
  // Navigation seams keep source identity/cancellation testable without a
  // platform player. Production callers use the normal navigator routes.
  Future<Map<String, dynamic>?> Function(SourcesPage page)? sourcePicker,
  Future<void> Function(PlaybackEntryPage page)? playerLauncher,
}) async {
  bool current() => context.mounted && (canLaunch?.call() ?? true);
  if (!current()) return;
  final app = context.read<AppState>();
  final english = app.english;
  final episode =
      video == null ? null : Map<String, dynamic>.unmodifiable(video);
  final id = episode?['id']?.toString() ?? item.id;
  final sources = SourcesPage(
    item: item,
    video: episode,
    english: english,
    loader: () => loadRankedSources(app: app, item: item, videoId: id),
  );
  Map<String, dynamic>? picked;
  var exactPeerFile = false;
  if (lockedSource != null) {
    final candidates = await sources.loader!();
    if (!context.mounted || !current()) return;
    for (final candidate in candidates) {
      if (candidate[unavailableTorrentSourceKey] != true &&
          isPlayableStreamMap(candidate) &&
          WatchPartySource.fromStream(candidate)?.key == lockedSource.key) {
        picked = candidate;
        break;
      }
    }
    // A locked peer file with a known index can be resolved from metadata
    // even if the guest's add-ons did not list the host's release.
    final index = lockedSource.fileIndex;
    final hash = lockedSource.infoHash;
    if (picked == null &&
        index != null &&
        index >= 0 &&
        hash != null &&
        lockedSource.key == 'torrent:$hash:$index' &&
        app.webSettings['p2pEnabled'] != false) {
      picked = {'infoHash': hash, 'fileIdx': index, 'title': lockedSource.name};
      exactPeerFile = true;
    }
    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(NovaStrings.lookup(english, 'partyLockedSourceUnavailable')),
      ));
      return;
    }
  } else {
    picked = sourcePicker != null
        ? await sourcePicker(sources)
        : await Navigator.of(context).push<Map<String, dynamic>>(
            MaterialPageRoute(builder: (_) => sources),
          );
  }
  if (picked == null || !context.mounted || !current()) return;

  PreparedTorrent? prepared;
  var transferred = false;
  var loading = true;
  onLoadingChanged?.call(true);
  void finishLoading() {
    if (!loading) return;
    loading = false;
    if (context.mounted) onLoadingChanged?.call(false);
  }

  try {
    final hints = (picked['behaviorHints'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final filename = (hints['filename'] ?? picked['title'])?.toString();
    final direct = parsePlaybackSource(picked);
    final magnet = (direct?.url ?? '').toLowerCase().startsWith('magnet:')
        ? direct!.url
        : null;
    final String url;
    Map<String, String>? headers;
    if (direct != null && magnet == null && direct.url.startsWith('http')) {
      url = direct.url;
      headers = direct.headers.isEmpty ? null : direct.headers;
    } else {
      final torrentHints = TorrentStreamHints.fromStream(
        picked,
        magnetUri: magnet,
        fallbackName: item.name,
      );
      final resolved = await _resolveTorrentStream(
        context,
        app: app,
        displayName: item.name,
        hints: torrentHints,
        magnet: magnet,
        isCurrent: current,
        forcePeerFile: exactPeerFile,
      );
      if (resolved == null) return;
      prepared = resolved.torrent;
      if (lockedSource?.fileIndex != null &&
          prepared != null &&
          prepared.fileIndex != lockedSource!.fileIndex) {
        if (context.mounted && current()) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(NovaStrings.lookup(
                  english, 'partyLockedSourceUnavailable'))));
        }
        return;
      }
      url = resolved.url;
    }
    if (!context.mounted || !current()) return;
    finishLoading();
    // The loading callback may update the room/account selection.
    if (!context.mounted || !current()) return;
    final page = PlaybackEntryPage(
      item: item,
      url: url,
      headers: headers,
      filename: filename,
      torrent: prepared,
      streamName: (picked['title'] ?? picked['addonName'] ?? 'NOVA').toString(),
      videoId: id,
      season: (episode?['season'] as num?)?.toInt(),
      episode: (episode?['episode'] as num?)?.toInt(),
      initialPositionMs: resumePositionMs,
      streams: [picked],
      streamIndex: 0,
    );
    final closed = playerLauncher != null
        ? playerLauncher(page)
        : Navigator.of(context).push<void>(MaterialPageRoute<void>(
            builder: (_) => page,
            fullscreenDialog: true,
          ));
    transferred = true;
    await closed;
  } catch (error) {
    if (context.mounted && current()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is PlaybackRetirementException
            ? NovaStrings.lookup(app.english, 'playerNativeRetirementFailed')
            : torrentFriendlyMessage(error, english: app.english)),
      ));
    }
  } finally {
    finishLoading();
    if (!transferred && prepared != null) {
      // No native player received this lease. Await its local server/native
      // removal rather than issuing a second hash-based removal later.
      await prepared.stop();
    }
  }
}

Future<({String url, PreparedTorrent? torrent})?> _resolveTorrentStream(
  BuildContext context, {
  required AppState app,
  required String displayName,
  required TorrentStreamHints hints,
  required String? magnet,
  required bool Function() isCurrent,
  required bool forcePeerFile,
}) async {
  final api = app.api;
  final english = app.english;
  final debridConfigured = !forcePeerFile && api.debridService != null;
  var engineSupported = false;
  if (!debridConfigured) {
    try {
      engineSupported = await TorrentService.instance.isSupported;
    } catch (_) {
      engineSupported = false;
    }
    if (!context.mounted || !isCurrent()) return null;
    if (!engineSupported) {
      _showNoTorrentPathMessage(context, english);
      return null;
    }
  }
  if (!context.mounted || !isCurrent()) return null;
  final navigator = Navigator.of(context, rootNavigator: true);
  var cancelled = false;
  bool current() => !cancelled && isCurrent();
  final status = ValueNotifier<TorrentStatus?>(null);
  late final Route<void> dialog;
  Widget buildDialog(BuildContext _) => Material(
        type: MaterialType.transparency,
        child: StreamPrepareDialog(
          english: english,
          status: status,
          onCancel: () {
            cancelled = true;
            if (dialog.isActive) navigator.removeRoute(dialog);
          },
        ),
      );
  dialog = !kIsWeb && Theme.of(context).platform == TargetPlatform.iOS
      ? CupertinoDialogRoute<void>(
          context: context, barrierDismissible: false, builder: buildDialog)
      : DialogRoute<void>(
          context: context, barrierDismissible: false, builder: buildDialog);
  unawaited(navigator.push(dialog));
  try {
    if (debridConfigured) {
      final url = await api.resolveDebridTorrent(
        infoHash: hints.infoHash,
        filename: hints.filename,
        filesize: hints.filesize,
      );
      if (!context.mounted || !current()) return null;
      if (url != null && url.isNotEmpty) return (url: url, torrent: null);
      if (app.webSettings['p2pEnabled'] == false) {
        _showNoTorrentPathMessage(context, english, debridFailed: true);
        return null;
      }
      try {
        engineSupported = await TorrentService.instance.isSupported;
      } catch (_) {
        engineSupported = false;
      }
      if (!context.mounted || !current()) return null;
      if (!engineSupported) {
        _showNoTorrentPathMessage(context, english, debridFailed: true);
        return null;
      }
    }
    if (!context.mounted || !current()) return null;
    if (const bool.fromEnvironment('NOVA_PLAYER_CORE', defaultValue: true)) {
      await PlaybackOwnership.shared.retireCurrent();
    }
    if (!context.mounted || !current()) return null;
    final prepared = await TorrentService.instance.prepare(
      infoHash: hints.infoHash,
      magnet: magnet,
      filename: hints.filename,
      filesize: hints.filesize,
      displayName: displayName,
      trackers: hints.trackers,
      fileIndex: hints.fileIndex,
    );
    if (!current()) {
      await prepared.stop();
      return null;
    }
    return (url: prepared.url, torrent: prepared);
  } finally {
    // Remove only this dialog, even if another route appeared during a slow
    // provider/native call. Popping the current route could close that route.
    if (dialog.isActive) navigator.removeRoute(dialog);
    status.dispose();
  }
}

void _showNoTorrentPathMessage(BuildContext context, bool english,
    {bool debridFailed = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(NovaStrings.lookup(
        english, debridFailed ? 'message182' : 'message183')),
  ));
}
