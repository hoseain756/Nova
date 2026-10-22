import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/widgets/player_chrome.dart';

Widget _host({
  required ValueChanged<double> commit,
  ValueChanged<double>? preview,
  VoidCallback? start,
  int Function()? position,
  int Function()? duration,
  Object? identity,
  TextDirection direction = TextDirection.ltr,
  Brightness brightness = Brightness.dark,
}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: GradientTimeline(
                durationMs: 100000,
                positionMs: 10000,
                bufferedMs: 20000,
                readExactPositionMs: position,
                readExactDurationMs: duration,
                interactionIdentity: identity,
                onScrubStart: start ?? () {},
                onScrubUpdate: preview ?? (_) {},
                onScrubEnd: commit,
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  for (final direction in TextDirection.values) {
    for (final brightness in Brightness.values) {
      testWidgets('tap uses exact duration $direction $brightness',
          (tester) async {
        double? committed;
        await tester.pumpWidget(_host(
          commit: (value) => committed = value,
          duration: () => 200000,
          direction: direction,
          brightness: brightness,
        ));
        final rect = tester.getRect(find.byType(GradientTimeline));
        await tester.tapAt(Offset(rect.left + 100, rect.center.dy));
        expect(committed, direction == TextDirection.rtl ? 150 : 50);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('accessibility actions read current exact values without rebuild',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var position = 45000;
    var duration = 200000;
    final commits = <double>[];
    await tester.pumpWidget(_host(
      commit: commits.add,
      position: () => position,
      duration: () => duration,
    ));
    final node =
        tester.getSemantics(find.bySemanticsLabel('Playback position'));
    final owner = node.owner!;
    owner.performAction(node.id, SemanticsAction.increase);
    position = 3000;
    owner.performAction(node.id, SemanticsAction.decrease);
    position = 198000;
    owner.performAction(node.id, SemanticsAction.increase);
    duration = 0;
    owner.performAction(node.id, SemanticsAction.increase);
    expect(commits, [55, 0, 200]);
    semantics.dispose();
  });

  testWidgets('drag commits fraction against duration changed since preview',
      (tester) async {
    var duration = 100000;
    double? preview;
    double? committed;
    await tester.pumpWidget(_host(
      commit: (value) => committed = value,
      preview: (value) => preview = value,
      duration: () => duration,
    ));
    final rect = tester.getRect(find.byType(GradientTimeline));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(preview, isNotNull);
    duration = 200000;
    await gesture.up();
    expect(committed, closeTo(preview! * 2, .001));
  });

  testWidgets('source identity change cancels drag and subsequent updates',
      (tester) async {
    final commits = <double>[];
    var identity = Object();
    Widget host() => _host(commit: commits.add, identity: identity);
    await tester.pumpWidget(host());
    final rect = tester.getRect(find.byType(GradientTimeline));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    identity = Object();
    await tester.pumpWidget(host());
    await gesture.moveBy(const Offset(30, 0));
    await gesture.up();
    expect(commits, isEmpty);
  });

  testWidgets('unknown duration at release cancels commit', (tester) async {
    var duration = 100000;
    final commits = <double>[];
    await tester.pumpWidget(_host(
      commit: commits.add,
      duration: () => duration,
    ));
    final rect = tester.getRect(find.byType(GradientTimeline));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    duration = 0;
    await gesture.up();
    expect(commits, isEmpty);
  });

  testWidgets('ownership invalidated by scrub start suppresses tap commit',
      (tester) async {
    var duration = 100000;
    final commits = <double>[];
    await tester.pumpWidget(_host(
      commit: commits.add,
      start: () => duration = 0,
      duration: () => duration,
    ));
    await tester.tap(find.byType(GradientTimeline));
    expect(commits, isEmpty);
  });
}
