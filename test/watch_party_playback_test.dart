import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/watch_party/watch_party_controller.dart';
import 'package:nova_mobile/features/watch_party/watch_party_playback.dart';
import 'package:provider/provider.dart';

import 'support/watch_party_fixture.dart';

void main() {
  for (final type in ['movie', 'series', 'anime']) {
    testWidgets('$type room launches its exact video without local history',
        (tester) async {
      final gateway = FakeWatchPartyGateway();
      final media = {
        'type': type,
        'id': 'provider:show:42',
        'video_id': 'provider:episode:season-3:ep-7',
        'title': 'The room selection',
        if (type != 'movie') 'season': 3,
        if (type != 'movie') 'episode': 7,
      };
      (gateway.data['room'] as Map)['media'] = media;
      final controller = WatchPartyController(gateway, deviceId: partyDeviceId);
      controller.bindIdentity('account', partyProfileId);
      await tester.runAsync(() => controller.join('ABCDEFGH'));
      MediaItem? item;
      Map<String, dynamic>? video;
      int? position;
      bool Function()? current;
      void capture(MediaItem selected, Map<String, dynamic>? selectedVideo,
          int? selectedPosition, bool Function()? isCurrent) {
        item = selected;
        video = selectedVideo;
        position = selectedPosition;
        current = isCurrent;
      }

      await tester
          .pumpWidget(ChangeNotifierProvider<WatchPartyController?>.value(
        value: controller,
        child: MaterialApp(home: Builder(builder: (context) {
          return TextButton(
            onPressed: () => unawaited(launchWatchPartyPlayback(context,
                room: controller.snapshot!, launch: (context,
                    {required item,
                    required video,
                    resumePositionMs,
                    canLaunch,
                    onLoadingChanged}) async {
              // Capture the real source launch request at the route boundary.
              capture(item, video, resumePositionMs, canLaunch);
            })),
            child: const Text('Watch'),
          );
        })),
      ));

      await tester.tap(find.text('Watch'));
      await tester.pump();
      expect(item?.id, media['id']);
      expect(item?.type, type);
      expect(video?['id'], media['video_id']);
      expect(video?['season'], type == 'movie' ? null : 3);
      expect(video?['episode'], type == 'movie' ? null : 7);
      expect(position, 10000);
      expect(current?.call(), isTrue);

      // A room change while the source picker is open invalidates its result.
      final changed = clonePartyData(gateway.data);
      (changed['room'] as Map)
        ..['revision'] = 2
        ..['media'] = partyMedia.toJson();
      gateway.event!('snapshot', changed);
      expect(current?.call(), isFalse);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
