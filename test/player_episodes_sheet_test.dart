import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/widgets/player_episodes_sheet.dart';

void main() {
  final episodes = <Map<String, dynamic>>[
    {'id': 's1e1', 'season': 1, 'episode': 1, 'name': 'First'},
    {'id': 's2e1', 'season': 2, 'episode': 1, 'name': 'Second'},
  ];

  Widget host({
    required TextDirection direction,
    required bool english,
    required ValueChanged<Map<String, dynamic>> onPick,
    bool loading = false,
    double textScale = 1,
  }) =>
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: SizedBox(
              width: double.infinity,
              height: 450,
              child: PlayerEpisodesSheet(
                english: english,
                episodes: episodes,
                currentVideoId: 's1e1',
                onPick: onPick,
                loading: loading,
              ),
            ),
          ),
        ),
      );

  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets('season selection, badges and play work in $direction',
        (tester) async {
      Map<String, dynamic>? picked;
      await tester.pumpWidget(host(
        direction: direction,
        english: direction == TextDirection.ltr,
        onPick: (episode) => picked = episode,
      ));
      expect(find.text('S01E01'), findsOneWidget);
      expect(find.text('Second'), findsNothing);

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(
          find.text(direction == TextDirection.ltr ? 'S2' : 'الموسم 2').last);
      await tester.pumpAndSettle();
      expect(find.text('S02E01'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      await tester
          .tap(find.text(direction == TextDirection.ltr ? 'Play' : 'تشغيل'));
      await tester.pump();
      expect(picked?['id'], 's2e1');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('loading indicator stays inside episode sheet', (tester) async {
    await tester.pumpWidget(host(
      direction: TextDirection.ltr,
      english: true,
      onPick: (_) {},
      loading: true,
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('narrow panel remains usable with enlarged Arabic text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 450);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(host(
      direction: TextDirection.rtl,
      english: false,
      onPick: (_) {},
      textScale: 2,
    ));
    expect(find.text('S01E01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
