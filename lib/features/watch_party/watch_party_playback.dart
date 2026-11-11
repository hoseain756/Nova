import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/watch_party/watch_party_controller.dart';
import '../../core/watch_party/watch_party_models.dart';
import '../media/media_playback_launcher.dart';

typedef WatchPartySourceLauncher = Future<void> Function(
  BuildContext context, {
  required MediaItem item,
  required Map<String, dynamic>? video,
  int? resumePositionMs,
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

  bool current() =>
      context.mounted &&
      controller.snapshot?.id == room.id &&
      controller.snapshot?.selfId == room.selfId &&
      controller.snapshot?.media?.key == media.key;

  if (!current()) return;
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
    canLaunch: current,
  );
}
