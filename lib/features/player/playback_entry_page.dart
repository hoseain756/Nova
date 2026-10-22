import 'package:flutter/material.dart';

import '../../core/models/media_item.dart';
import '../../core/torrent/torrent_models.dart';
import 'core_video_player_page.dart';
import 'session/playback_state.dart';
import 'video_player_page.dart';

/// Chooses once before allocating either playback implementation.
class PlaybackEntryPage extends StatefulWidget {
  const PlaybackEntryPage({
    super.key,
    required this.item,
    required this.url,
    required this.streamName,
    required this.videoId,
    this.initialPositionMs,
    this.season,
    this.episode,
    this.streams = const [],
    this.streamIndex,
    this.headers,
    this.filename,
    this.torrent,
    this.recordProgress = true,
    this.useCore =
        const bool.fromEnvironment('NOVA_PLAYER_CORE', defaultValue: false),
  });

  final MediaItem item;
  final String url;
  final String streamName;
  final String videoId;
  final int? initialPositionMs;
  final int? season;
  final int? episode;

  /// The stream row(s) known at launch — at least the PICKED one. The
  /// skip-intro/outro + Up-Next resolver reads the current row's metadata
  /// (behaviorHints etc.), and the sources side-panel seeds its list from
  /// it (refresh re-fetches the full ranked list).
  final List<Map<String, dynamic>> streams;
  final int? streamIndex;

  /// Extra HTTP headers (addon behaviorHints.proxyHeaders) for direct streams.
  final Map<String, String>? headers;

  /// Human stream name hint (used for debrid resolution).
  final String? filename;

  /// Prepared on-device torrent stream (when source was an infoHash).
  final PreparedTorrent? torrent;
  final bool recordProgress;
  final bool useCore;

  @override
  State<PlaybackEntryPage> createState() => _PlaybackEntryPageState();
}

class _PlaybackEntryPageState extends State<PlaybackEntryPage> {
  late final Widget _page = playbackPageForRequest(
      PlaybackRequest(
        item: widget.item,
        url: widget.url,
        streamName: widget.streamName,
        videoId: widget.videoId,
        initialPositionMs: widget.initialPositionMs,
        season: widget.season,
        episode: widget.episode,
        streams: widget.streams,
        streamIndex: widget.streamIndex,
        headers: widget.headers,
        filename: widget.filename,
        torrent: widget.torrent,
        recordProgress: widget.recordProgress,
      ),
      useCore: widget.useCore);

  @override
  Widget build(BuildContext context) => _page;
}

Widget playbackPageForRequest(PlaybackRequest request, {bool useCore = false}) {
  if (useCore) {
    return CoreVideoPlayerPage(
      item: request.item,
      url: request.url,
      streamName: request.streamName,
      videoId: request.videoId,
      initialPositionMs: request.initialPositionMs,
      season: request.season,
      episode: request.episode,
      streams: request.streams,
      streamIndex: request.streamIndex,
      headers: request.headers,
      filename: request.filename,
      torrent: request.torrent,
      recordProgress: request.recordProgress,
    );
  }
  return VideoPlayerPage(
    item: request.item,
    url: request.url,
    streamName: request.streamName,
    videoId: request.videoId,
    initialPositionMs: request.initialPositionMs,
    season: request.season,
    episode: request.episode,
    streams: request.streams,
    streamIndex: request.streamIndex,
    headers: request.headers,
    filename: request.filename,
    torrent: request.torrent,
    recordProgress: request.recordProgress,
  );
}
