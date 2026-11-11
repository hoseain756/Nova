import 'dart:convert';
import 'package:nova_mobile/core/watch_party/watch_party_models.dart';
import 'package:nova_mobile/core/watch_party/watch_party_service.dart';

const partyRoomId = '00000000-0000-4000-8000-000000000001';
const partyHostId = '00000000-0000-4000-8000-000000000002';
const partyGuestId = '00000000-0000-4000-8000-000000000003';
const partyProfileId = '00000000-0000-4000-8000-000000000004';
const partyDeviceId = '00000000-0000-4000-8000-000000000005';
const partyMedia = WatchPartyMedia(
    id: 'tt1234', type: 'movie', title: 'A story', videoId: 'tt1234');
Map<String, dynamic> partyData(
        {String selfId = partyGuestId,
        bool playing = false,
        bool hostOnly = true,
        int revision = 1,
        int position = 10000}) =>
    {
      'server_time_ms': 100000,
      'self_member_id': selfId,
      'room': {
        'id': partyRoomId,
        'code': 'ABCDEFGH',
        'host_member_id': partyHostId,
        'host_only': hostOnly,
        'media': partyMedia.toJson(),
        'position_ms': position,
        'duration_ms': 3600000,
        'playing': playing,
        'rate': 1.0,
        'at': 100000,
        'revision': revision,
        'waiting': false,
        'ended': false
      },
      'members': [
        {
          'id': partyHostId,
          'name': 'Host',
          'avatar': null,
          'status': 'ready',
          'media_key': partyMedia.key
        },
        {
          'id': partyGuestId,
          'name': 'Guest',
          'avatar': null,
          'status': 'ready',
          'media_key': partyMedia.key
        }
      ],
      'messages': <Map<String, dynamic>>[]
    };
Map<String, dynamic> clonePartyData(Map<String, dynamic> data) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);

class FakeWatchPartyGateway implements WatchPartyGateway {
  Map<String, dynamic> data = partyData();
  final List<Map<String, dynamic>> requests = [];
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)? handle;
  void Function(String, Map<String, dynamic>)? event;
  void Function(bool)? status;
  int subscriptions = 0;
  @override
  Future<Map<String, dynamic>> request(Map<String, dynamic> params) async {
    requests.add(params);
    if (handle != null) return handle!(params);
    if (params['p_action'] == 'resume') return {'snapshot': null};
    if (params['p_action'] == 'leave' || params['p_action'] == 'end') {
      return {'left': true};
    }
    if (params['p_action'] == 'command') {
      final room = data['room'] as Map;
      final payload = params['p_payload'] as Map;
      room['revision'] = (room['revision'] as int) + 1;
      switch (payload['command']) {
        case 'play':
          room['playing'] = true;
        case 'pause':
          room['playing'] = false;
        case 'seek':
          room['position_ms'] = payload['position_ms'];
        case 'rate':
          room['rate'] = payload['rate'];
      }
    }
    return clonePartyData(data);
  }

  @override
  void subscribe(
      String memberId,
      void Function(String, Map<String, dynamic>) onEvent,
      void Function(bool) onStatus) {
    subscriptions++;
    event = onEvent;
    status = onStatus;
  }

  @override
  Future<void> unsubscribe() async {
    event = null;
    status = null;
  }
}
