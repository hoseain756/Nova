import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/watch_party/watch_party_controller.dart';
import '../../core/watch_party/watch_party_models.dart';
import '../../l10n/nova_strings.dart';
import '../media/media_playback_launcher.dart';

typedef WatchPartySourceLauncher = Future<void> Function(
  BuildContext context, {
  required MediaItem item,
  required Map<String, dynamic>? video,
  int? resumePositionMs,
  WatchPartySource? lockedSource,
  bool Function()? canLaunch,
  ValueChanged<bool>? onLoadingChanged,
});

/// Opens local sources for the exact room episode, without a metadata/history
/// round trip that could substitute another episode or playback identity.
Future<void> launchWatchPartyPlayback(
  BuildContext context, {
  required WatchPartySnapshot room,
  bool returnToPlayer = false,
  WatchPartySourceLauncher launch = launchMediaPlayback,
}) async {
  final controller = context.read<WatchPartyController?>();
  final media = room.media;
  if (controller == null || media == null || !media.supported) return;

  final locked = room.sourceLocked && !room.isHost;
  bool current() {
    final live = controller.snapshot;
    return context.mounted &&
        live != null &&
        live.id == room.id &&
        live.selfId == room.selfId &&
        live.media?.key == media.key &&
        (live.sourceLocked && !live.isHost) == locked &&
        (!locked || live.source?.key == room.source?.key);
  }

  if (!current()) return;
  if (locked && room.source == null) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(NovaStrings.lookup(english, 'partyLockedSourceUnavailable')),
    ));
    return;
  }
  if (returnToPlayer) {
    Navigator.of(context).pop();
    return;
  }

  await launch(
    context,
    item: media.item,
    video: Map<String, dynamic>.unmodifiable({
      'id': media.videoId,
      if (media.season != null) 'season': media.season,
      if (media.episode != null) 'episode': media.episode,
    }),
    resumePositionMs: room.targetMs(controller.clock.nowMs),
    lockedSource: locked ? room.source : null,
    canLaunch: current,
  );
}
