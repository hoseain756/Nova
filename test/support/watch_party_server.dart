import 'dart:async';
import 'package:nova_mobile/core/watch_party/watch_party_service.dart';
import 'watch_party_fixture.dart';

/// Two independent transports sharing one authoritative room. Like the RPC,
/// responses identify their recipient; private broadcasts deliberately do not.
class WatchPartyTestServer {
  WatchPartyTestServer({bool hostOnly = false, bool playing = false})
      : data = clonePartyData(partyData(hostOnly: hostOnly, playing: playing));

  final Map<String, dynamic> data;
  final clients = <WatchPartyTestGateway>[];
  int now = 0;
  int get revision => (data['room'] as Map)['revision'] as int;
  Map get room => data['room'] as Map;
  final commands = <Map<String, dynamic>>[];

  WatchPartyTestGateway client(String memberId) {
    final client = WatchPartyTestGateway(this, memberId);
    clients.add(client);
    return client;
  }

  Map<String, dynamic> snapshot(String? memberId) {
    final result = clonePartyData(data);
    result['self_member_id'] = memberId;
    result['server_time_ms'] = 100000 + now;
    return result;
  }

  void broadcast() {
    for (final client in clients) {
      client.deliver('snapshot', snapshot(null));
    }
  }

  void _advance() {
    if (room['playing'] == true) {
      room['position_ms'] = (room['position_ms'] as int) +
          (((100000 + now) - (room['at'] as int)) * (room['rate'] as num))
              .round();
    }
    room['at'] = 100000 + now;
  }

  Future<Map<String, dynamic>> request(
      WatchPartyTestGateway client, Map<String, dynamic> params) async {
    final action = params['p_action'];
    final payload = params['p_payload'] as Map? ?? const {};
    if (action == 'resume') return {'snapshot': null};
    if (action == 'media') {
      if (client.memberId != room['host_member_id']) {
        return {'error': 'host_required'};
      }
      if (payload['revision'] != revision) {
        return {'error': 'conflict', 'snapshot': snapshot(client.memberId)};
      }
      room['media'] = payload['media'];
      room['source'] = payload['source'];
      room['audio_track'] = payload['audio_track'];
      room['position_ms'] = payload['position_ms'];
      room['duration_ms'] = 0;
      room['playing'] = payload['playing'];
      room['rate'] = payload['rate'];
      room['at'] = 100000 + now;
      room['revision'] = revision + 1;
      broadcast();
      return snapshot(client.memberId);
    }
    if (action == 'leave') {
      (data['members'] as List)
          .removeWhere((row) => (row as Map)['id'] == client.memberId);
      room['revision'] = revision + 1;
      broadcast();
      return {'left': true};
    }
    if (action == 'command' || action == 'publish' || action == 'configure') {
      if (payload['revision'] != revision) {
        return {'error': 'conflict', 'snapshot': snapshot(client.memberId)};
      }
      final host = client.memberId == room['host_member_id'];
      if ((room['host_only'] == true || action != 'command') && !host) {
        return {'error': 'host_required'};
      }
      if (action == 'configure') {
        for (final field in ['host_only', 'source', 'source_locked']) {
          if (payload.containsKey(field)) room[field] = payload[field];
        }
      } else {
        final media = room['media'] as Map;
        if (payload['media_key'] !=
            '${media['type']}|${media['id']}|${media['video_id']}') {
          return {'error': 'media_mismatch'};
        }
        if (!host &&
            room['source_locked'] == true &&
            payload['source_key'] != (room['source'] as Map?)?['key']) {
          return {'error': 'source_mismatch'};
        }
        _advance();
        if (action == 'publish') {
          room['position_ms'] = payload['position_ms'];
          room['duration_ms'] = payload['duration_ms'];
          room['source'] ??= payload['source'];
          room['audio_track'] ??= payload['audio_track'];
        } else {
          commands.add({...payload, 'member_id': client.memberId});
          switch (payload['command']) {
            case 'play':
              room['playing'] = true;
            case 'pause':
              room['playing'] = false;
              if (host && payload['position_ms'] is num) {
                room['position_ms'] = payload['position_ms'];
              }
            case 'seek':
              room['position_ms'] = payload['position_ms'];
            case 'rate':
              room['rate'] = payload['rate'];
            case 'audio':
              room['audio_track'] = payload['audio_track'];
          }
        }
      }
      room['revision'] = revision + 1;
      broadcast();
    } else if (action == 'heartbeat') {
      final member = (data['members'] as List)
          .cast<Map>()
          .firstWhere((row) => row['id'] == client.memberId);
      if (member['status'] != payload['status'] ||
          member['media_key'] != payload['media_key']) {
        member['status'] = payload['status'];
        member['media_key'] = payload['media_key'];
        room['revision'] = revision + 1;
        broadcast();
      }
    }
    return snapshot(client.memberId);
  }
}

class WatchPartyTestGateway implements WatchPartyGateway {
  WatchPartyTestGateway(this.server, this.memberId);
  final WatchPartyTestServer server;
  final String memberId;
  final requests = <Map<String, dynamic>>[];
  void Function(String, Map<String, dynamic>)? _onEvent;
  void Function(bool)? _onStatus;
  bool connected = true;

  @override
  Future<Map<String, dynamic>> request(Map<String, dynamic> params) {
    requests.add(params);
    return server.request(this, params);
  }

  void deliver(String event, Map<String, dynamic> data) {
    if (!connected) return;
    final payload = watchPartyBroadcastData({'event': event, 'payload': data});
    _onEvent?.call(event, payload!);
  }

  void setConnected(bool value) {
    connected = value;
    _onStatus?.call(value);
  }

  @override
  void subscribe(
      String memberId,
      void Function(String, Map<String, dynamic>) onEvent,
      void Function(bool) onStatus) {
    _onEvent = onEvent;
    _onStatus = onStatus;
    scheduleMicrotask(() => _onStatus?.call(connected));
  }

  @override
  Future<void> unsubscribe() async {
    _onEvent = null;
    _onStatus = null;
  }
}
