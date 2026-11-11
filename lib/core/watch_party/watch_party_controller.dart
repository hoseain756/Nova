import 'dart:async';
import 'package:flutter/foundation.dart';
import 'watch_party_invite.dart';
import 'watch_party_models.dart';
import 'watch_party_service.dart';

/// Route dependency for controller identity only; transport updates are
/// observed by the binding, without rebuilding the fullscreen player.
class WatchPartyHandle {
  const WatchPartyHandle(this.controller);
  final WatchPartyController? controller;
}

/// Room lifetime is independent of a player route. Only server-authenticated
/// RPC results and server-only broadcasts may update the trusted snapshot.
class WatchPartyController extends ChangeNotifier {
  WatchPartyController(this.gateway,
      {required this.deviceId, WatchPartyClock? clock})
      : clock = clock ?? WatchPartyClock();
  final WatchPartyGateway gateway;
  final String deviceId;
  final WatchPartyClock clock;
  WatchPartySnapshot? snapshot;
  List<WatchPartyMessage> messages = const [];
  String? errorKey;
  bool realtimeConnected = false;
  bool online = false;
  bool busy = false;
  String? _accountId, _profileId, _subscribedId;
  String _status = 'browsing';
  String? _mediaKey;
  Object? _statusOwner;
  bool _disposed = false, _refreshing = false, _publishing = false;
  int _generation = 0, _commandCount = 0;
  Timer? _heartbeat;
  Future<void> _commands = Future<void>.value();
  bool get eligible => _accountId != null && _profileId != null;
  bool get isHost => snapshot?.isHost ?? false;
  bool get canControl => snapshot?.canControl ?? false;

  void bindIdentity(String? accountId, String? profileId) {
    if (_disposed || (_accountId == accountId && _profileId == profileId)) {
      return;
    }
    final old = snapshot;
    final oldProfile = _profileId;
    _reset();
    _accountId = accountId;
    _profileId = profileId;
    clock.reset();
    if (old != null) {
      unawaited(gateway.request({
        'p_action': 'leave',
        'p_device_id': deviceId,
        'p_profile_id': oldProfile,
        'p_room_id': old.id
      }).catchError((Object _) => <String, dynamic>{}));
    }
    notifyListeners();
    if (eligible) unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      await _call('resume');
    } catch (_) {/* Explicit entry offers retry. */}
  }

  Future<Map<String, dynamic>> _call(String action,
      {String? code,
      Map<String, dynamic> payload = const {},
      bool roomRequired = false}) async {
    if (!eligible || _disposed) {
      throw const WatchPartyException('account_required');
    }
    final generation = _generation;
    final room = snapshot;
    if (roomRequired && room == null) {
      throw const WatchPartyException('not_member');
    }
    final sentAt = clock.monotonicMs;
    Map<String, dynamic> result;
    try {
      result = await gateway.request({
        'p_action': action,
        'p_device_id': deviceId,
        'p_profile_id': _profileId,
        'p_room_id': room?.id,
        'p_code': code,
        'p_payload': payload
      });
    } catch (_) {
      if (generation == _generation && !_disposed) {
        online = false;
        errorKey = 'partyUnavailable';
        notifyListeners();
      }
      throw const WatchPartyException('network');
    }
    if (_disposed || generation != _generation) {
      throw const WatchPartyException('cancelled');
    }
    if (result['server_time_ms'] is num) {
      clock.observe((result['server_time_ms'] as num).toInt(), sentAt);
    }
    online = true;
    final nested = result['snapshot'];
    if (nested is Map) _accept(Map<String, dynamic>.from(nested));
    if (result['error'] is String) {
      final error = WatchPartyException(result['error'] as String);
      if (const ['ended', 'not_member', 'removed'].contains(error.code)) {
        _reset();
      }
      errorKey = error.messageKey;
      notifyListeners();
      throw error;
    }
    errorKey = null;
    if (result['room'] is Map) _accept(result);
    if (result['message'] is Map) {
      _mergeMessage(WatchPartyMessage.fromJson(
          Map<String, dynamic>.from(result['message'] as Map)));
    }
    notifyListeners();
    return result;
  }

  void _accept(Map<String, dynamic> data) {
    final incoming =
        WatchPartySnapshot.fromJson(data, selfMemberId: snapshot?.selfId);
    if (snapshot != null && incoming.id != snapshot!.id) return;
    if (snapshot != null && incoming.revision < snapshot!.revision) return;
    if (incoming.ended ||
        !incoming.members.any((m) => m.id == incoming.selfId)) {
      _reset();
      errorKey = 'partyEnded';
      return;
    }
    snapshot = incoming;
    final history = data['messages'];
    if (history is List) {
      for (final row in history) {
        _mergeMessage(
            WatchPartyMessage.fromJson(Map<String, dynamic>.from(row as Map)));
      }
    }
    if (_subscribedId != incoming.selfId) {
      _subscribedId = incoming.selfId;
      final generation = _generation;
      gateway.subscribe(incoming.selfId, (event, payload) {
        if (_disposed || generation != _generation) return;
        try {
          if (event == 'closed') {
            _reset();
            errorKey =
                payload['reason'] == 'removed' ? 'partyRemoved' : 'partyEnded';
          } else if (event == 'snapshot' && payload['room'] is Map) {
            _accept(payload);
          } else if (event == 'chat') {
            _mergeMessage(WatchPartyMessage.fromJson(payload));
          }
          online = true;
          notifyListeners();
        } catch (_) {
          /* Malformed transport data cannot replace trusted state. */
        }
      }, (connected) {
        if (_disposed || generation != _generation) return;
        final rejoined = connected && !realtimeConnected;
        realtimeConnected = connected;
        notifyListeners();
        if (rejoined) unawaited(refresh(history: true));
      });
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 5),
          (_) => unawaited(refresh(history: false)));
    }
  }

  Future<void> create(
          {WatchPartyMedia? media,
          int positionMs = 0,
          bool playing = false,
          double rate = 1}) =>
      _withBusy(() async {
        if (snapshot != null) {
          throw const WatchPartyException('already_in_room');
        }
        if (media != null && !media.supported) {
          throw const WatchPartyException('invalid_media');
        }
        await _call('create', payload: {
          if (media != null) 'media': media.toJson(),
          'position_ms': positionMs,
          'playing': playing,
          'rate': rate
        });
      });
  Future<void> join(String input) => _withBusy(() async {
        final code =
            parseWatchPartyInvite(input) ?? normalizeWatchPartyCode(input);
        if (!validWatchPartyCode(code)) {
          throw const WatchPartyException('not_found');
        }
        if (snapshot != null) {
          throw const WatchPartyException('already_in_room');
        }
        await _call('join', code: code);
      });
  Future<void> _withBusy(Future<void> Function() action) async {
    if (busy) return;
    final generation = _generation;
    busy = true;
    errorKey = null;
    notifyListeners();
    try {
      await action();
    } on WatchPartyException catch (error) {
      if (!_disposed && generation == _generation) errorKey = error.messageKey;
      rethrow;
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh({bool history = true}) async {
    if (_refreshing || snapshot == null || _disposed) return;
    _refreshing = true;
    final generation = _generation;
    try {
      await _call('heartbeat',
          roomRequired: true,
          payload: {'status': _status, 'media_key': _mediaKey});
      // Recover missed chat as well as state after reconnect or a failed channel.
      if (history || !realtimeConnected) {
        await _call('snapshot', roomRequired: true);
      }
    } catch (_) {/* Retain last state and show reconnect/retry. */} finally {
      if (generation == _generation) _refreshing = false;
    }
  }

  void setPlaybackStatus(String status, String? mediaKey, {Object? owner}) {
    if (owner != null) _statusOwner = owner;
    if (_status == status && _mediaKey == mediaKey) return;
    _status = status;
    _mediaKey = mediaKey;
    if (snapshot != null) unawaited(refresh(history: false));
  }

  void releasePlaybackStatus(Object owner) {
    if (!identical(_statusOwner, owner)) return;
    _statusOwner = null;
    setPlaybackStatus('browsing', null);
  }

  Future<void> _mutate(String action, Map<String, dynamic> payload) async {
    final roomId = snapshot?.id;
    final generation = _generation;
    for (var attempt = 0; attempt < 2; attempt++) {
      final room = snapshot;
      if (room == null || room.id != roomId || generation != _generation) {
        throw const WatchPartyException('cancelled');
      }
      try {
        await _call(action,
            roomRequired: true,
            payload: {...payload, 'revision': room.revision});
        return;
      } on WatchPartyException catch (error) {
        if (error.code != 'conflict' || attempt != 0) rethrow;
      }
    }
  }

  Future<void> setMedia(WatchPartyMedia media,
      {int positionMs = 0, bool playing = false, double rate = 1}) async {
    if (!media.supported) throw const WatchPartyException('invalid_media');
    await _mutate('media', {
      'media': media.toJson(),
      'position_ms': positionMs,
      'playing': playing,
      'rate': rate
    });
  }

  Future<void> command(String command,
      {int? positionMs, double? rate, required String mediaKey}) {
    final generation = _generation, roomId = snapshot?.id;
    _commandCount++;
    final result = _commands.then((_) async {
      if (_disposed ||
          generation != _generation ||
          roomId != snapshot?.id ||
          snapshot?.media?.key != mediaKey) {
        throw const WatchPartyException('cancelled');
      }
      await _mutate('command', {
        'command': command,
        'media_key': mediaKey,
        if (positionMs != null) 'position_ms': positionMs,
        if (rate != null) 'rate': rate
      });
    });
    _commands = result
        .then<void>((_) {}, onError: (Object _, StackTrace __) {})
        .whenComplete(() {
      if (generation == _generation) _commandCount--;
    });
    return result;
  }

  Future<void> publish(
      {required String mediaKey,
      required int positionMs,
      required int durationMs}) async {
    if (_publishing ||
        _commandCount > 0 ||
        !isHost ||
        snapshot?.media?.key != mediaKey) {
      return;
    }
    _publishing = true;
    final generation = _generation;
    try {
      await _call('publish', roomRequired: true, payload: {
        'revision': snapshot!.revision,
        'media_key': mediaKey,
        'position_ms': positionMs,
        'duration_ms': durationMs
      });
    } catch (_) {/* A newer command wins over a stale heartbeat. */} finally {
      if (generation == _generation) _publishing = false;
    }
  }

  Future<void> configure(bool hostOnly) =>
      _mutate('configure', {'host_only': hostOnly});
  Future<void> transfer(String memberId) =>
      _mutate('transfer', {'member_id': memberId});
  Future<void> remove(String memberId) =>
      _mutate('remove', {'member_id': memberId});
  Future<void> end() async {
    await _call('end', roomRequired: true);
    _reset();
    notifyListeners();
  }

  Future<void> leave() async {
    final room = snapshot, profile = _profileId;
    if (room == null) return;
    _reset();
    notifyListeners();
    try {
      await gateway.request({
        'p_action': 'leave',
        'p_device_id': deviceId,
        'p_profile_id': profile,
        'p_room_id': room.id
      });
    } catch (_) {
      /* Server expires a disconnected membership after 75 seconds. */
    }
  }

  Future<void> sendMessage(String body, {String? clientId}) async {
    final room = snapshot;
    if (room == null || body.trim().isEmpty || body.trim().runes.length > 500) {
      return;
    }
    final message = WatchPartyMessage(
        memberId: room.selfId,
        name: room.members.firstWhere((m) => m.id == room.selfId).name,
        clientId: clientId ?? newWatchPartyId(),
        body: body.trim());
    _mergeMessage(message);
    notifyListeners();
    final generation = _generation;
    try {
      await _call('chat',
          roomRequired: true,
          payload: {'body': message.body, 'client_id': message.clientId});
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _mergeMessage(message.asFailed());
        notifyListeners();
      }
    }
  }

  void _mergeMessage(WatchPartyMessage incoming) {
    final next = messages
        .where((m) =>
            !(m.memberId == incoming.memberId &&
                m.clientId == incoming.clientId) &&
            (incoming.id == null || m.id != incoming.id))
        .toList();
    final confirmed = messages.where((m) =>
        m.memberId == incoming.memberId &&
        m.clientId == incoming.clientId &&
        m.id != null);
    if (incoming.id == null && confirmed.isNotEmpty) return;
    next.add(incoming);
    next.sort((a, b) => a.id == null
        ? (b.id == null ? 0 : 1)
        : b.id == null
            ? -1
            : a.id!.compareTo(b.id!));
    messages = List.unmodifiable(
        next.length > 200 ? next.sublist(next.length - 200) : next);
  }

  void _reset() {
    ++_generation;
    busy = false;
    _refreshing = false;
    _publishing = false;
    _commandCount = 0;
    _commands = Future<void>.value();
    snapshot = null;
    messages = const [];
    _subscribedId = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    realtimeConnected = false;
    online = false;
    _status = 'browsing';
    _statusOwner = null;
    _mediaKey = null;
    errorKey = null;
    unawaited(gateway.unsubscribe());
  }

  @override
  void dispose() {
    _reset();
    _disposed = true;
    super.dispose();
  }
}
