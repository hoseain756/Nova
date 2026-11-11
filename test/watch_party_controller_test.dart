import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/watch_party/watch_party_controller.dart';
import 'package:nova_mobile/core/watch_party/watch_party_models.dart';
import 'support/watch_party_fixture.dart';

Future<WatchPartyController> joined(FakeWatchPartyGateway gateway) async {
  final c = WatchPartyController(gateway, deviceId: partyDeviceId);
  c.bindIdentity('account', partyProfileId);
  await Future<void>.delayed(Duration.zero);
  await c.join('ABCDEFGH');
  return c;
}

void main() {
  test('readiness changed during a heartbeat is sent immediately after it',
      () async {
    final g = FakeWatchPartyGateway();
    final c = await joined(g);
    addTearDown(c.dispose);
    final pending = Completer<Map<String, dynamic>>();
    var heartbeats = 0;
    g.handle = (p) async {
      if (p['p_action'] == 'heartbeat' && ++heartbeats == 1) {
        return pending.future;
      }
      return partyData();
    };
    c.setPlaybackStatus('loading', partyMedia.key);
    await Future<void>.delayed(Duration.zero);
    c.setPlaybackStatus('ready', partyMedia.key);
    pending.complete(partyData());
    await Future<void>.delayed(Duration.zero);
    final statuses = g.requests
        .where((p) => p['p_action'] == 'heartbeat')
        .map((p) => (p['p_payload'] as Map)['status']);
    expect(statuses, ['loading', 'ready']);
  });

  test('reconnect history recovery survives an in-flight heartbeat', () async {
    final g = FakeWatchPartyGateway();
    final c = await joined(g);
    addTearDown(c.dispose);
    g.status!(true);
    await Future<void>.delayed(Duration.zero);
    g.requests.clear();
    final pending = Completer<Map<String, dynamic>>();
    var heartbeats = 0;
    g.handle = (p) async {
      if (p['p_action'] == 'heartbeat' && ++heartbeats == 1) {
        return pending.future;
      }
      return partyData();
    };
    final first = c.refresh(history: false);
    g.status!(false);
    g.status!(true);
    pending.complete(partyData());
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(g.requests.where((p) => p['p_action'] == 'snapshot').length, 1);
    expect(heartbeats, 2);
  });

  test('new rooms request shared controls with an explicit host-only option',
      () async {
    for (final hostOnly in [false, true]) {
      final g = FakeWatchPartyGateway();
      final c = WatchPartyController(g, deviceId: partyDeviceId);
      c.bindIdentity('account', partyProfileId);
      await Future<void>.delayed(Duration.zero);
      if (hostOnly) {
        await c.create(hostOnly: true);
      } else {
        await c.create();
      }
      final create = g.requests.singleWhere((p) => p['p_action'] == 'create');
      expect((create['p_payload'] as Map)['host_only'], hostOnly);
      c.dispose();
    }
  });
  test('a retiring route cannot clear a newer player status', () async {
    final g = FakeWatchPartyGateway();
    final c = await joined(g);
    addTearDown(c.dispose);
    final old = Object(), current = Object();
    c.setPlaybackStatus('ready', partyMedia.key, owner: old);
    await Future<void>.delayed(Duration.zero);
    c.setPlaybackStatus('ready', partyMedia.key, owner: current);
    g.requests.clear();
    c.releasePlaybackStatus(old);
    expect(g.requests, isEmpty);
    c.releasePlaybackStatus(current);
    await Future<void>.delayed(Duration.zero);
    expect((g.requests.first['p_payload'] as Map)['status'], 'browsing');
  });
  test('profile switch discards a late join and its error', () async {
    final gateway = FakeWatchPartyGateway();
    final c = WatchPartyController(gateway, deviceId: partyDeviceId);
    addTearDown(c.dispose);
    c.bindIdentity('a', partyProfileId);
    await Future<void>.delayed(Duration.zero);
    final pending = Completer<Map<String, dynamic>>();
    gateway.handle = (p) async =>
        p['p_action'] == 'join' ? pending.future : {'snapshot': null};
    final join = c.join('ABCDEFGH');
    final expected = expectLater(join, throwsA(isA<WatchPartyException>()));
    c.bindIdentity('a', 'other-profile');
    pending.complete(partyData());
    await expected;
    expect(c.snapshot, isNull);
    expect(c.errorKey, isNull);
    expect(c.busy, isFalse);
    expect(gateway.subscriptions, 0);
  });
  test('room and revision filters reject stale snapshots', () async {
    final g = FakeWatchPartyGateway()..data = partyData(revision: 5);
    final c = await joined(g);
    addTearDown(c.dispose);
    g.event!('snapshot', partyData(revision: 2, position: 90000));
    expect(c.snapshot!.positionMs, 10000);
    final wrong = partyData(revision: 99);
    (wrong['room'] as Map)['id'] = 'other';
    g.event!('snapshot', wrong);
    expect(c.snapshot!.id, partyRoomId);
  });
  test(
      'reconnect retrieves missed history even after channel becomes subscribed',
      () async {
    final g = FakeWatchPartyGateway();
    final c = await joined(g);
    addTearDown(c.dispose);
    g.data['messages'] = [
      {
        'id': 1,
        'member_id': partyHostId,
        'display_name': 'Host',
        'client_id': partyProfileId,
        'body': 'Missed'
      }
    ];
    g.status!(true);
    await Future<void>.delayed(Duration.zero);
    expect(c.messages.single.body, 'Missed');
    expect(g.requests.where((p) => p['p_action'] == 'snapshot'), isNotEmpty);
  });
  test('CAS retry uses refreshed revision without losing requested seek',
      () async {
    final g = FakeWatchPartyGateway();
    final c = await joined(g);
    addTearDown(c.dispose);
    var commands = 0;
    g.handle = (p) async {
      if (p['p_action'] == 'command') {
        commands++;
        if (commands == 1) {
          return {'error': 'conflict', 'snapshot': partyData(revision: 8)};
        }
        expect((p['p_payload'] as Map)['revision'], 8);
        expect((p['p_payload'] as Map)['position_ms'], 42000);
        return partyData(revision: 9, position: 42000);
      }
      return partyData();
    };
    await c.command('seek', positionMs: 42000, mediaKey: partyMedia.key);
    expect(commands, 2);
    expect(c.snapshot!.positionMs, 42000);
  });
  test('chat retries preserve client id and merge an earlier broadcast once',
      () async {
    final g = FakeWatchPartyGateway();
    final c = await joined(g);
    addTearDown(c.dispose);
    var attempts = 0;
    g.handle = (p) async {
      if (p['p_action'] == 'chat') {
        attempts++;
        final payload = p['p_payload'] as Map;
        if (attempts == 1) throw StateError('offline');
        final message = {
          'id': 5,
          'member_id': partyGuestId,
          'display_name': 'Guest',
          'client_id': payload['client_id'],
          'body': payload['body']
        };
        g.event!('chat', message);
        return {'message': message};
      }
      return partyData();
    };
    await c.sendMessage('Hi');
    expect(c.messages.single.failed, isTrue);
    final id = c.messages.single.clientId;
    await c.sendMessage('Hi', clientId: id);
    expect(c.messages.length, 1);
    expect(c.messages.single.id, 5);
    expect(c.messages.single.failed, isFalse);
  });
  test('removed member clears snapshot, chat, and subscriptions', () async {
    final g = FakeWatchPartyGateway();
    final c = await joined(g);
    addTearDown(c.dispose);
    g.event!('closed', {'reason': 'removed'});
    expect(c.snapshot, isNull);
    expect(c.messages, isEmpty);
    expect(c.errorKey, 'partyRemoved');
    expect(g.event, isNull);
  });
  test('queued commands cannot run after leaving the room', () async {
    final g = FakeWatchPartyGateway();
    final c = await joined(g);
    addTearDown(c.dispose);
    final pending = c.command('play', mediaKey: partyMedia.key);
    final expected = expectLater(pending, throwsA(isA<WatchPartyException>()));
    await c.leave();
    await expected;
    expect(g.requests.where((p) => p['p_action'] == 'command'), isEmpty);
  });
}
