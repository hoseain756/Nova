import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/widgets/player_side_panel.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('panel actions remain reachable at 200%: $direction',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var actions = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: Scaffold(
            body: PlayerSidePanel(
          title: 'A long playback settings title',
          english: true,
          onClose: () => actions++,
          onRefresh: () => actions++,
          onOpenAudio: () => actions++,
          onOpenStreams: () => actions++,
          onOpenSubtitles: () => actions++,
          child: const Center(child: Text('Content')),
        )),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final close = find.bySemanticsLabel('Close');
      expect(close, findsOneWidget);
      await tester.tap(close);
      expect(actions, 1);
    });
  }
}
