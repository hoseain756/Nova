import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/watch_party/watch_party_models.dart';
import 'package:nova_mobile/core/watch_party/watch_party_invite.dart';
import 'package:nova_mobile/core/watch_party/watch_party_service.dart';
import 'support/watch_party_fixture.dart';

void main() {
  test('Realtime SDK broadcast envelope is unwrapped before room parsing', () {
    final data = partyData();
    expect(
        watchPartyBroadcastData(
            {'event': 'snapshot', 'type': 'broadcast', 'payload': data}),
        data);
    expect(watchPartyBroadcastData({'event': 'snapshot', 'payload': 'bad'}),
        isNull);
  });
  test('room clock uses a monotonic midpoint and rejects slower RTT samples',
      () {
    var mono = 100;
    final clock = WatchPartyClock(monotonicMs: () => mono);
    clock.observe(10000, 0);
    expect(clock.nowMs, 10050);
    mono = 500;
    clock.observe(99999, 0);
    expect(clock.nowMs, 10450);
    mono = 600;
    clock.observe(11000, 590);
    expect(clock.nowMs, 11005);
  });
  test('room projection multiplies elapsed time by speed and bounds EOF', () {
    final data = partyData(playing: true);
    (data['room'] as Map)['rate'] = 2.0;
    final room = WatchPartySnapshot.fromJson(data);
    expect(room.targetMs(101000), 12000);
    expect(room.targetMs(99999), 10000);
    expect(room.targetMs(101000, localDurationMs: 11000), 10750);
  });
  test('paused projections and authority use exact member identity', () {
    final room = WatchPartySnapshot.fromJson(partyData());
    expect(room.targetMs(200000), 10000);
    expect(room.canControl, isFalse);
    expect(
        WatchPartySnapshot.fromJson(partyData(selfId: partyHostId)).canControl,
        isTrue);
    expect(WatchPartySnapshot.fromJson(partyData(hostOnly: false)).canControl,
        isTrue);
  });
  test(
      'invitations require the correct host, one valid code, and no authority extras',
      () {
    expect(parseWatchPartyInvite(watchPartyInvite('ABCDEFGH')), 'ABCDEFGH');
    expect(parseWatchPartyInvite(watchPartyInvite('ABCDEF')), 'ABCDEF');
    expect(
        parseWatchPartyInvite('app.nova.mobile://watch-party?code=abcd-efgh'),
        'ABCDEFGH');
    for (final link in [
      'https://evil.test/watch-party?code=ABCDEFGH',
      'app.nova.mobile://callback?code=ABCDEFGH',
      'app.nova.mobile://watch-party?code=ABCDE',
      'app.nova.mobile://watch-party?code=ABCDEFG',
      'app.nova.mobile://watch-party?code=ABCDEFGH&endpoint=https://evil.test',
      'app.nova.mobile://watch-party?code=ABCDEFGH&code=JKLMNPQR',
      'app.nova.mobile://user@watch-party?code=ABCDEFGH',
      'app.nova.mobile://watch-party:42?code=ABCDEFGH',
      'app.nova.mobile://watch-party/path?code=ABCDEFGH',
      'app.nova.mobile://watch-party?code=ABCD0FGH'
    ]) {
      expect(parseWatchPartyInvite(link), isNull, reason: link);
    }
  });
  test(
      'join input accepts six and legacy eight character codes and invitations',
      () {
    expect(watchPartyCodeFromInput('abc def'), 'ABCDEF');
    expect(watchPartyCodeFromInput('ABCD-EFGH'), 'ABCDEFGH');
    expect(
        watchPartyCodeFromInput(' ${watchPartyInvite('ABCDEF')} '), 'ABCDEF');
    expect(
        watchPartyCodeFromInput('app.nova.mobile://watch-party?code=ABCDEFGH'),
        'ABCDEFGH');
    expect(formatWatchPartyCode('ABCDEF'), 'ABC DEF');
    expect(formatWatchPartyCode('ABCDEFGH'), 'ABCD EFGH');
    for (final input in [
      'ABCDE',
      'ABCDEFG',
      'ABCDEFGHI',
      'ABC0EF',
      'ABCIEF',
      'https://evil.test/ABCDEF',
      'app.nova.mobile://watch-party?code=ABCDEF&code=ABCDEF'
    ]) {
      expect(watchPartyCodeFromInput(input), isNull, reason: input);
    }
  });
  test('relay invitations retain origin metadata without a silent legacy join',
      () {
    final text =
        watchPartyInvite('ABCDEF', relay: Uri.https('rooms.example.com'));
    final invitation = parseWatchPartyInvitation(text)!;
    expect(invitation.code, 'ABCDEF');
    expect(invitation.relay.toString(), 'https://rooms.example.com');
    expect(parseWatchPartyInvite(text), isNull);
    for (final relay in [
      'http://rooms.example.com',
      'https://localhost',
      'https://127.0.0.1',
      'https://user:secret@rooms.example.com',
      'https://rooms.example.com/private',
      'https://rooms.example.com?token=secret'
    ]) {
      expect(
          parseWatchPartyInvitation(
              'app.nova.mobile://watch-party?code=ABCDEF&relay=${Uri.encodeComponent(relay)}'),
          isNull,
          reason: relay);
    }
    expect(
        parseWatchPartyInvitation(
            '$text&relay=https%3A%2F%2Fother.example.com'),
        isNull);
  });
  test(
      'media identity includes exact episode video ID and never transport credentials',
      () {
    const a = WatchPartyMedia(
        id: 'series',
        type: 'series',
        title: 'Story',
        videoId: 'series:1:2',
        season: 1,
        episode: 2);
    const b = WatchPartyMedia(
        id: 'series',
        type: 'series',
        title: 'Story',
        videoId: 'series:1:3',
        season: 1,
        episode: 3);
    expect(a.key, isNot(b.key));
    expect(a.supported, isTrue);
    expect(
        a.toJson().keys,
        unorderedEquals([
          'id',
          'type',
          'title',
          'video_id',
          'poster',
          'season',
          'episode'
        ]));
    expect(
        const WatchPartyMedia(id: 's', type: 'series', title: 'S', videoId: 's')
            .supported,
        isFalse);
  });
}
