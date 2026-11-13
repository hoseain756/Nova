import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/watch_party/watch_party_models.dart';
import 'package:nova_mobile/features/player/watch_party_player_policy.dart';
import 'package:nova_mobile/features/player/watch_party_follow_prompt.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'support/watch_party_fixture.dart';

void main() {
  test('shared controls never grant guests permission to change episodes', () {
    for (final locked in [false, true]) {
      final data = partyData(hostOnly: false);
      (data['room'] as Map)['source_locked'] = locked;
      expect(
          watchPartyPlayerChangeError(
              room: WatchPartySnapshot.fromJson(data),
              currentMedia: partyMedia,
              videoId: 'next-episode'),
          'partyGuestEpisodeLocked');
      data['self_member_id'] = partyHostId;
      expect(
          watchPartyPlayerChangeError(
              room: WatchPartySnapshot.fromJson(data),
              currentMedia: partyMedia,
              videoId: 'next-episode'),
          isNull);
    }
  });

  test(
      'guest follows latest room media and only changes source in independent mode',
      () {
    final hostSource =
        WatchPartySource.fromStream({'url': 'https://example.test/host'})!;
    final other =
        WatchPartySource.fromStream({'url': 'https://example.test/other'})!;
    final data = partyData(hostOnly: false);
    (data['room'] as Map)['source'] = hostSource.toJson();
    for (final locked in [false, true]) {
      (data['room'] as Map)['source_locked'] = locked;
      expect(
          watchPartyPlayerChangeError(
              room: WatchPartySnapshot.fromJson(data),
              currentMedia: partyMedia,
              videoId: partyMedia.videoId,
              source: other,
              checkSource: true),
          locked ? 'partySourceLockedMismatch' : isNull);
    }
    (data['room'] as Map)['media'] = const WatchPartyMedia(
            id: 'new', type: 'movie', title: 'New room title', videoId: 'new')
        .toJson();
    expect(
        watchPartyPlayerChangeError(
            room: WatchPartySnapshot.fromJson(data),
            currentMedia: partyMedia,
            videoId: partyMedia.videoId),
        'partyTitleChanged');
  });

  testWidgets(
      'follow notice waits for the player to be visible and needs an explicit tap',
      (tester) async {
    late BuildContext player;
    var follows = 0;
    await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [NovaStrings.delegate],
        home: Builder(builder: (context) {
          player = context;
          return const Scaffold(body: Text('Player'));
        })));
    bool visible() => ModalRoute.of(player)?.isCurrent == true;
    final dialog = showDialog<void>(
        context: player,
        builder: (_) => const AlertDialog(content: Text('Tools')));
    await tester.pumpAndSettle();
    expect(
        showWatchPartyFollowPrompt(player,
            messageKey: 'partyTitleChanged',
            canShow: visible,
            onFollow: () => follows++),
        isFalse);
    expect(find.byType(SnackBarAction), findsNothing);
    Navigator.of(player).pop();
    await dialog;
    await tester.pumpAndSettle();
    expect(
        showWatchPartyFollowPrompt(player,
            messageKey: 'partyTitleChanged',
            canShow: visible,
            onFollow: () => follows++),
        isTrue);
    await tester.pumpAndSettle();
    expect(follows, 0);
    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();
    expect(follows, 1);
  });

  testWidgets('follow action rechecks visibility when another modal opens',
      (tester) async {
    late BuildContext player;
    var follows = 0;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      player = context;
      return const Scaffold(body: Text('Player'));
    })));
    bool visible() => ModalRoute.of(player)?.isCurrent == true;
    showWatchPartyFollowPrompt(player,
        messageKey: 'partySourceLockedMismatch',
        canShow: visible,
        onFollow: () => follows++);
    await tester.pumpAndSettle();
    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    final dialog = showDialog<void>(
        context: player,
        builder: (_) => const AlertDialog(content: Text('Tools')));
    await tester.pumpAndSettle();
    action.onPressed();
    expect(follows, 0);
    Navigator.of(player).pop();
    await dialog;
    await tester.pumpAndSettle();
  });
}
