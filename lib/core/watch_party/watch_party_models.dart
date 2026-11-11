import 'dart:math';
import '../models/media_item.dart';

String newWatchPartyId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class WatchPartyMedia {
  const WatchPartyMedia(
      {required this.id,
      required this.type,
      required this.title,
      required this.videoId,
      this.poster,
      this.season,
      this.episode});
  factory WatchPartyMedia.fromJson(Map<String, dynamic> json) =>
      WatchPartyMedia(
          id: json['id'] as String,
          type: json['type'] as String,
          title: json['title'] as String,
          videoId: json['video_id'] as String,
          poster: json['poster'] as String?,
          season: (json['season'] as num?)?.toInt(),
          episode: (json['episode'] as num?)?.toInt());
  factory WatchPartyMedia.fromItem(MediaItem item,
          {required String videoId, int? season, int? episode}) =>
      WatchPartyMedia(
          id: item.id,
          type: item.type,
          title: item.name,
          videoId: videoId,
          poster: item.poster,
          season: season,
          episode: episode);
  final String id, type, title, videoId;
  final String? poster;
  final int? season, episode;
  String get key => '$type|$id|$videoId';
  bool get supported =>
      const ['movie', 'series', 'anime'].contains(type) &&
      id.isNotEmpty &&
      videoId.isNotEmpty &&
      title.isNotEmpty &&
      (type == 'movie' || (season != null && episode != null));
  MediaItem get item =>
      MediaItem(id: id, type: type, name: title, poster: poster);
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'video_id': videoId,
        'poster': poster,
        'season': season,
        'episode': episode
      };
}

class WatchPartyMember {
  WatchPartyMember.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        name = json['name'] as String,
        avatar = json['avatar'] as String?,
        status = json['status'] as String,
        mediaKey = json['media_key'] as String?;
  final String id, name, status;
  final String? avatar, mediaKey;
}

class WatchPartyMessage {
  const WatchPartyMessage(
      {this.id,
      required this.memberId,
      required this.name,
      required this.clientId,
      required this.body,
      this.failed = false});
  factory WatchPartyMessage.fromJson(Map<String, dynamic> json) =>
      WatchPartyMessage(
          id: (json['id'] as num).toInt(),
          memberId: json['member_id'] as String,
          name: json['display_name'] as String,
          clientId: json['client_id'] as String,
          body: json['body'] as String);
  final int? id;
  final String memberId, name, clientId, body;
  final bool failed;
  bool get pending => id == null && !failed;
  WatchPartyMessage asFailed() => WatchPartyMessage(
      memberId: memberId,
      name: name,
      clientId: clientId,
      body: body,
      failed: true);
}

class WatchPartySnapshot {
  WatchPartySnapshot.fromJson(Map<String, dynamic> json, {String? selfMemberId})
      : selfId = json['self_member_id'] as String? ?? selfMemberId ?? '',
        id = (json['room'] as Map)['id'] as String,
        code = (json['room'] as Map)['code'] as String,
        hostId = (json['room'] as Map)['host_member_id'] as String?,
        hostOnly = (json['room'] as Map)['host_only'] == true,
        media = (json['room'] as Map)['media'] == null
            ? null
            : WatchPartyMedia.fromJson(Map<String, dynamic>.from(
                (json['room'] as Map)['media'] as Map)),
        positionMs = ((json['room'] as Map)['position_ms'] as num).toInt(),
        durationMs = ((json['room'] as Map)['duration_ms'] as num).toInt(),
        playing = (json['room'] as Map)['playing'] == true,
        rate = ((json['room'] as Map)['rate'] as num).toDouble(),
        atMs = ((json['room'] as Map)['at'] as num).toInt(),
        revision = ((json['room'] as Map)['revision'] as num).toInt(),
        waiting = (json['room'] as Map)['waiting'] == true,
        ended = (json['room'] as Map)['ended'] == true,
        members = List.unmodifiable((json['members'] as List).map((m) =>
            WatchPartyMember.fromJson(Map<String, dynamic>.from(m as Map))));
  final String id, code, selfId;
  final String? hostId;
  final bool hostOnly, playing, waiting, ended;
  final WatchPartyMedia? media;
  final int positionMs, durationMs, atMs, revision;
  final double rate;
  final List<WatchPartyMember> members;
  bool get isHost => selfId.isNotEmpty && selfId == hostId;
  bool get canControl => isHost || !hostOnly;
  int targetMs(int serverNowMs, {int? localDurationMs}) {
    var target = positionMs +
        (playing ? (max(0, serverNowMs - atMs) * rate).round() : 0);
    final duration = localDurationMs ?? durationMs;
    if (duration > 0) target = min(target, max(0, duration - 250));
    return target.clamp(0, 43200000);
  }
}

/// Wall-clock changes cannot move the anchored server clock backwards.
class WatchPartyClock {
  WatchPartyClock({int Function()? monotonicMs}) : _read = monotonicMs {
    _watch.start();
  }
  final int Function()? _read;
  final Stopwatch _watch = Stopwatch();
  int? _offset, _bestRtt;
  int get monotonicMs => _read?.call() ?? _watch.elapsedMilliseconds;
  int get nowMs =>
      (_offset ?? (DateTime.now().millisecondsSinceEpoch - monotonicMs)) +
      monotonicMs;
  void observe(int serverMs, int sentAt) {
    final elapsed = monotonicMs;
    final rtt = elapsed - sentAt;
    if (rtt < 0 || rtt > 10000 || (_bestRtt != null && rtt > _bestRtt!)) return;
    _bestRtt = rtt;
    _offset = serverMs + rtt ~/ 2 - elapsed;
  }

  void reset() {
    _offset = null;
    _bestRtt = null;
  }
}

class WatchPartyException implements Exception {
  const WatchPartyException(this.code);
  final String code;
  String get messageKey => switch (code) {
        'account_required' || 'profile_required' => 'partyAccountRequired',
        'host_required' => 'partyHostRequired',
        'not_found' => 'partyNotFound',
        'full' => 'partyFull',
        'ended' || 'not_member' => 'partyEnded',
        'removed' => 'partyRemoved',
        'rate_limited' => 'partyRateLimited',
        'conflict' => 'partyConflict',
        'already_in_room' => 'partyAlreadyInRoom',
        _ => 'partyUnavailable'
      };
}
