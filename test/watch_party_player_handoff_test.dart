import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nova_mobile/core/watch_party/watch_party_models.dart';
import 'package:nova_mobile/features/watch_party/watch_party_player_handoff.dart';

import 'support/watch_party_fixture.dart';

void main() {
  test('Legacy saves exact state and retires native before releasing torrent',
      () async {
    final native = Completer<void>();
    final steps = <String>[];
    final retiring = retireWatchPartyLegacyPlayback(
      pause: () async => steps.add('pause'),
      captureFrame: () async => steps.add('frame'),
      saveProgress: () async => steps.add('progress'),
      closeNative: () {
        steps.add('close');
        return native.future;
      },
      releaseTorrent: () async => steps.add('torrent'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(steps, ['pause', 'frame', 'progress', 'close']);
    native.complete();
    await retiring;
    expect(steps, ['pause', 'frame', 'progress', 'close', 'torrent']);
  });

  test('Legacy native retirement failure retains its torrent lease', () async {
    var released = false;
    await expectLater(
      retireWatchPartyLegacyPlayback(
        pause: () async {},
        captureFrame: () async {},
        saveProgress: () async {},
        closeNative: () async => throw StateError('native still owns output'),
        releaseTorrent: () async => released = true,
      ),
      throwsStateError,
    );
    expect(released, isFalse);
  });

  test('late successful native retirement releases its lease after timeout',
      () async {
    final native = Completer<void>();
    var releases = 0;
    await expectLater(
      retireWatchPartyLegacyPlayback(
        pause: () async {},
        captureFrame: () async {},
        saveProgress: () async {},
        closeNative: () => native.future,
        releaseTorrent: () async => releases++,
        retirementTimeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(releases, 0);
    native.complete();
    await Future<void>.delayed(Duration.zero);
    expect(releases, 1);
  });

  const otherMedia = WatchPartyMedia(
      id: 'tt9999', type: 'movie', title: 'Previous title', videoId: 'tt9999');
  final room = WatchPartySnapshot.fromJson(partyData());

  Future<void> openRoom(WidgetTester tester,
      {required WatchPartyMedia currentMedia,
      WatchPartySource? currentSource,
      WatchPartySnapshot? snapshot,
      required Future<void> Function() retire,
      required WatchPartyHandoffLauncher launch}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (homeContext) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(homeContext).push<void>(
              MaterialPageRoute(builder: (playerContext) {
                final playerRoute = ModalRoute.of(playerContext)!;
                return Scaffold(
                  body: TextButton(
                    child: const Text('Open room'),
                    onPressed: () => Navigator.of(playerContext).push<void>(
                      MaterialPageRoute(
                        builder: (roomContext) => Scaffold(
                          body: TextButton(
                            child: const Text('Join playback'),
                            onPressed: () =>
                                unawaited(handoffWatchPartyPlayback(
                              roomContext,
                              room: snapshot ?? room,
                              currentMedia: currentMedia,
                              currentSource: currentSource,
                              playerRoute: playerRoute,
                              retirePlayback: retire,
                              launch: (context, {required room}) {
                                expect(playerRoute.isActive, isFalse);
                                return launch(context, room: room);
                              },
                            )),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            child: const Text('Open player'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open player'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open room'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'same episode with a different locked source retires before relaunch',
      (tester) async {
    final first =
        WatchPartySource.fromStream({'url': 'https://example.test/a'})!;
    final other =
        WatchPartySource.fromStream({'url': 'https://example.test/b'})!;
    final data = partyData();
    (data['room'] as Map)['source_locked'] = true;
    (data['room'] as Map)['source'] = first.toJson();
    final steps = <String>[];
    await openRoom(tester,
        currentMedia: partyMedia,
        currentSource: other,
        snapshot: WatchPartySnapshot.fromJson(data),
        retire: () async => steps.add('retire'),
        launch: (_, {required room}) async => steps.add('sources'));
    await tester.tap(find.text('Join playback'));
    await tester.pumpAndSettle();
    expect(steps, ['retire', 'sources']);
  });

  testWidgets(
      'a different room title waits for native retirement before sources',
      (tester) async {
    final native = Completer<void>();
    final steps = <String>[];
    await openRoom(tester,
        currentMedia: otherMedia,
        retire: () {
          steps.add('retire');
          return native.future;
        },
        launch: (_, {required room}) async => steps.add('sources'));
    await tester.tap(find.text('Join playback'));
    await tester.pump();
    expect(steps, ['retire']);
    expect(find.text('Join playback'), findsOneWidget);
    native.complete();
    await tester.pumpAndSettle();
    expect(steps, ['retire', 'sources']);
    // Source cancellation returns to the room; the retired player is removed.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('Open player'), findsOneWidget);
  });

  testWidgets('retirement failure blocks repeated source launch attempts',
      (tester) async {
    var launches = 0;
    final failed = Completer<void>();
    await openRoom(tester,
        currentMedia: otherMedia,
        retire: () => failed.future,
        launch: (_, {required room}) async => launches++);
    await tester.tap(find.text('Join playback'));
    failed.completeError(StateError('native retirement failed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join playback'));
    await tester.pumpAndSettle();
    expect(launches, 0);
    expect(find.text('Join playback'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('Open room'), findsOneWidget);
  });

  testWidgets('same room media returns to its existing native player',
      (tester) async {
    var retirements = 0;
    var launches = 0;
    await openRoom(tester,
        currentMedia: partyMedia,
        retire: () async => retirements++,
        launch: (_, {required room}) async => launches++);
    await tester.tap(find.text('Join playback'));
    await tester.pumpAndSettle();
    expect(retirements, 0);
    expect(launches, 0);
    expect(find.text('Open room'), findsOneWidget);
  });
}
