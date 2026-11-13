import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
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

/// Public identity of the original add-on row, before debrid/local resolution.
/// It never contains URLs, request headers or provider credentials.
class WatchPartySource {
  const WatchPartySource(
      {required this.key, required this.name, this.infoHash, this.fileIndex});
  final String key, name;
  final String? infoHash;
  final int? fileIndex;

  static WatchPartySource? tryParse(Object? value) {
    if (value is! Map || value['key'] is! String) return null;
    final key = value['key'] as String;
    if (!RegExp(
            r'^(torrent:([a-f0-9]{40}|[a-f0-9]{64}):(-1|[0-9]{1,8})|stream:[a-f0-9]{64})$')
        .hasMatch(key)) {
      return null;
    }
    return WatchPartySource(
        key: key,
        name: _publicLabel(value['name']),
        infoHash:
            value['info_hash'] is String ? value['info_hash'] as String : null,
        fileIndex: (value['file_index'] as num?)?.toInt());
  }

  static WatchPartySource? fromStream(Map<String, dynamic>? stream) {
    if (stream == null) return null;
    final hints = stream['behaviorHints'] is Map
        ? stream['behaviorHints'] as Map
        : const {};
    final uri = Uri.tryParse(stream['url']?.toString() ?? '');
    final magnetHash = uri?.scheme == 'magnet'
        ? uri?.queryParameters['xt']?.split(':').last
        : null;
    final hash = (stream['infoHash'] ?? magnetHash)?.toString().toLowerCase();
    final rawIndex = stream['fileIdx'] ?? stream['fileIndex'];
    final parsedIndex = rawIndex is num
        ? rawIndex.toInt()
        : int.tryParse(rawIndex?.toString() ?? '');
    final index =
        parsedIndex != null && parsedIndex >= 0 && parsedIndex <= 99999999
            ? parsedIndex
            : null;
    final name =
        _publicLabel(stream['title'] ?? hints['filename'] ?? stream['name']);
    if (hash != null &&
        RegExp(r'^([a-f0-9]{40}|[a-f0-9]{64})$').hasMatch(hash)) {
      if (index == null) {
        final filename =
            (hints['filename'] ?? stream['filename'])?.toString().trim();
        if (filename == null || filename.isEmpty) return null;
        final identity = 'torrent-file:$hash:${filename.replaceAll('\\', '/')}';
        return WatchPartySource(
            key: 'stream:${sha256.convert(utf8.encode(identity))}', name: name);
      }
      return WatchPartySource(
          key: 'torrent:$hash:$index',
          name: name,
          infoHash: hash,
          fileIndex: index);
    }
    String? identity;
    final videoHash = hints['videoHash'];
    if (videoHash is String && videoHash.isNotEmpty) {
      identity = 'video:${videoHash.toLowerCase()}:${hints['videoSize'] ?? ''}';
    } else if (uri != null &&
        const ['https', 'http'].contains(uri.scheme) &&
        uri.userInfo.isEmpty &&
        uri.host.isNotEmpty &&
        !const ['localhost', '127.0.0.1', '::1'].contains(uri.host)) {
      // Query parameters may identify the video itself (/stream?id=...).
      // Hash the complete opaque resource rather than guess which parameters
      // are authentication. Device-specific signed URLs safely fail to match.
      identity = '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}'
          '${uri.hasPort ? ':${uri.port}' : ''}${uri.path}'
          '${uri.hasQuery ? '?${uri.query}' : ''}';
    }
    if (identity == null) return null;
    return WatchPartySource(
        key: 'stream:${sha256.convert(utf8.encode(identity))}', name: name);
  }

  static String _publicLabel(Object? raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty ||
        RegExp(r'(://|magnet:|(?:token|password|secret|api.?key|authorization|signature)\s*[:=])',
                caseSensitive: false)
            .hasMatch(text)) {
      return 'Source';
    }
    return String.fromCharCodes(text.runes.take(160));
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        if (infoHash != null) 'info_hash': infoHash,
        if (fileIndex != null) 'file_index': fileIndex,
      };
}

/// Portable selection, independent of backend-specific track IDs.
class WatchPartyAudioSelection {
  const WatchPartyAudioSelection(
      {required this.mode,
      this.language,
      this.title,
      this.index,
      this.sourceKey});
  final String mode;
  final String? language, title;
  final int? index;
  final String? sourceKey;
  static WatchPartyAudioSelection? tryParse(Object? value) {
    if (value is! Map ||
        !const ['auto', 'off', 'track'].contains(value['mode'])) {
      return null;
    }
    return WatchPartyAudioSelection(
        mode: value['mode'] as String,
        language: normalizeLanguage(value['language']?.toString()),
        title: normalizeTitle(value['title']?.toString()),
        index: (value['index'] as num?)?.toInt(),
        sourceKey: value['source_key'] as String?);
  }

  static String? normalizeLanguage(String? value) {
    final clean = value?.trim().toLowerCase().replaceAll('_', '-');
    if (clean == null || clean.isEmpty || clean == 'und') return null;
    final primary = clean.split('-').first;
    final mapped = const {
      'eng': 'en',
      'ara': 'ar',
      'jpn': 'ja',
      'spa': 'es',
      'fra': 'fr',
      'fre': 'fr',
      'deu': 'de',
      'ger': 'de',
      'zho': 'zh',
      'chi': 'zh',
      'kor': 'ko',
      'por': 'pt',
      'rus': 'ru',
      'ita': 'it'
    }[primary];
    final normalized =
        mapped == null ? clean : clean.replaceFirst(primary, mapped);
    return normalized.length <= 35 ? normalized : normalized.substring(0, 35);
  }

  static String? normalizeTitle(String? value) {
    final clean = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean != null &&
        RegExp(r'(://|(?:token|password|secret|api.?key|authorization|signature)\s*[:=])',
                caseSensitive: false)
            .hasMatch(clean)) {
      return null;
    }
    return clean == null || clean.isEmpty
        ? null
        : String.fromCharCodes(clean.runes.take(160));
  }

  String get key => jsonEncode(toJson());
  Map<String, dynamic> toJson() => {
        'mode': mode,
        if (language != null) 'language': language,
        if (title != null) 'title': title,
        if (index != null) 'index': index,
        if (sourceKey != null) 'source_key': sourceKey,
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
        sourceLocked = (json['room'] as Map)['source_locked'] == true,
        source = WatchPartySource.tryParse((json['room'] as Map)['source']),
        audioTrack = WatchPartyAudioSelection.tryParse(
            (json['room'] as Map)['audio_track']),
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
  final bool sourceLocked;
  final WatchPartySource? source;
  final WatchPartyAudioSelection? audioTrack;
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
        'source_mismatch' => 'partySourceLockedMismatch',
        'relay_check_failed' => 'partyRelayCheckFailed',
        'relay_invalid' => 'partyRelayInvalid',
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
