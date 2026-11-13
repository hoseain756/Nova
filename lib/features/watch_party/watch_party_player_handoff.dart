import 'package:flutter/material.dart';

import '../../core/watch_party/watch_party_models.dart';
import '../../l10n/nova_strings.dart';
import 'watch_party_playback.dart';

typedef WatchPartyHandoffLauncher = Future<void> Function(
  BuildContext context, {
  required WatchPartySnapshot room,
});

/// Legacy's room handoff takes ownership of the exact engine and its torrent
/// from the page's synchronous dispose path. A native failure retains the
/// torrent lease and prevents the caller from opening another player.
Future<void> retireWatchPartyLegacyPlayback({
  required Future<void> Function() pause,
  required Future<void> Function() captureFrame,
  required Future<void> Function() saveProgress,
  required Future<void> Function() closeNative,
  required Future<void> Function() releaseTorrent,
  Duration saveTimeout = const Duration(seconds: 2),
  Duration retirementTimeout = const Duration(seconds: 15),
}) async {
  for (final save in [pause, captureFrame, saveProgress]) {
    try {
      await save().timeout(saveTimeout);
    } catch (_) {/* Preserve the normal exit's best-effort local saves. */}
  }
  // Timeout only the caller's wait. Keep cleanup attached to confirmed native
  // retirement so a late successful close still releases its exact lease.
  await (() async {
    await closeNative();
    await releaseTorrent();
  })()
      .timeout(retirementTimeout);
}

/// A room opened above a player may switch to a different title. Retire and
/// remove that player before opening sources, leaving the room available if
/// source selection is cancelled. Returning to the same title keeps playback.
Future<void> handoffWatchPartyPlayback(
  BuildContext roomContext, {
  required WatchPartySnapshot room,
  required WatchPartyMedia currentMedia,
  WatchPartySource? currentSource,
  required Route<dynamic> playerRoute,
  required Future<void> Function() retirePlayback,
  WatchPartyHandoffLauncher launch = launchWatchPartyPlayback,
}) async {
  if (!roomContext.mounted) return;
  final navigator = Navigator.of(roomContext);
  if (room.media?.key == currentMedia.key &&
      (!room.sourceLocked ||
          currentSource != null && currentSource.key == room.source?.key)) {
    navigator.pop();
    return;
  }
  try {
    await retirePlayback();
  } catch (_) {
    if (roomContext.mounted) {
      ScaffoldMessenger.of(roomContext).showSnackBar(SnackBar(
        content: Text(
            NovaStrings.of(roomContext).text('playerNativeRetirementFailed')),
      ));
    }
    return;
  }
  if (!roomContext.mounted) return;
  if (playerRoute.isActive) navigator.removeRoute(playerRoute);
  if (!roomContext.mounted) return;
  await launch(roomContext, room: room);
}
