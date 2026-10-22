import '../../../core/models/media_item.dart';
import '../../../core/torrent/torrent_models.dart';

Object? freezePlaybackValue(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(value.map(
      (key, value) => MapEntry(key.toString(), freezePlaybackValue(value)),
    ));
  }
  if (value is List) {
    return List<dynamic>.unmodifiable(value.map(freezePlaybackValue));
  }
  return value;
}

/// A route request freezes mutable catalog/source input at the ownership edge.
class PlaybackRequest {
  PlaybackRequest({
    required MediaItem item,
    required this.url,
    required this.streamName,
    required this.videoId,
    this.initialPositionMs,
    this.season,
    this.episode,
    List<Map<String, dynamic>> streams = const [],
    this.streamIndex,
    Map<String, String>? headers,
    this.filename,
    this.torrent,
    this.recordProgress = true,
  })  : itemData = freezePlaybackValue(item.toJson()) as Map<String, dynamic>,
        streams = List.unmodifiable(streams.map(
          (stream) => freezePlaybackValue(stream) as Map<String, dynamic>,
        )),
        headers = headers == null ? null : Map.unmodifiable(headers);

  final Map<String, dynamic> itemData;
  MediaItem get item => MediaItem.fromJson(itemData);
  final String url;
  final String streamName;
  final String videoId;
  final int? initialPositionMs;
  final int? season;
  final int? episode;
  final List<Map<String, dynamic>> streams;
  final int? streamIndex;
  final Map<String, String>? headers;
  final String? filename;
  final PreparedTorrent? torrent;
  final bool recordProgress;

  String get contentKey =>
      '${itemData['type']}:${itemData['id']}:$videoId:$season:$episode';
}

enum PlaybackPhase {
  idle,
  resolving,
  opening,
  prepared,
  playing,
  paused,
  failed,
  closing,
  closed
}

enum PlaybackCommandStatus { applied, cancelled, unsupported, failed }

enum PlaybackFailureCategory {
  source,
  network,
  decode,
  output,
  operation,
  unknown
}

class PlaybackFailure {
  const PlaybackFailure(this.category, this.operation, this.sourceGeneration);
  final PlaybackFailureCategory category;
  final String operation;
  final int sourceGeneration;
  // Never expose backend exception text, media URLs or credentials.
  String get code => 'playback_${category.name}_$operation';
}

/// Classification hints from backend diagnostics, never a measured cause and
/// never authorization to retry or change decoder.
PlaybackFailureCategory classifyPlaybackFailure(String? message) {
  final hint = message?.toLowerCase() ?? '';
  if (hint.contains('401') ||
      hint.contains('403') ||
      hint.contains('404') ||
      hint.contains('unauthorized')) {
    return PlaybackFailureCategory.source;
  }
  if (hint.contains('timeout') ||
      hint.contains('socket') ||
      hint.contains('connection')) {
    return PlaybackFailureCategory.network;
  }
  if (hint.contains('decoder') ||
      hint.contains('codec') ||
      hint.contains('decoding')) {
    return PlaybackFailureCategory.decode;
  }
  if (hint.contains('surface') || hint.contains('texture')) {
    return PlaybackFailureCategory.output;
  }
  return PlaybackFailureCategory.unknown;
}

class PlaybackCommandResult {
  const PlaybackCommandResult(this.status, [this.failure]);
  final PlaybackCommandStatus status;
  final PlaybackFailure? failure;
  bool get applied => status == PlaybackCommandStatus.applied;
}

class PlaybackPanelToken {
  const PlaybackPanelToken(this.identity, this.intentRevision, this.wasPlaying);
  final Object identity;
  final int intentRevision;
  final bool wasPlaying;
}

class PlaybackHandoffIntent {
  const PlaybackHandoffIntent(
      this.resolutionIdentity, this.intentRevision, this.playing);
  final Object resolutionIdentity;
  final int intentRevision;
  final bool playing;
}

class PlaybackStartupSettings {
  const PlaybackStartupSettings(
      {this.subtitleDelayMs = 0,
      this.audioDelayMs = 0,
      this.subtitlesOff = false});
  final int subtitleDelayMs;
  final int audioDelayMs;
  final bool subtitlesOff;
}
