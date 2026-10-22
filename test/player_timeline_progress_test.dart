import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/widgets/player_chrome.dart';

void _noop() {}
void _noopValue(double _) {}

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
  for (final english in <bool>[false, true]) {
    testWidgets(
        'player timeline uses requested ${english ? 'English' : 'Arabic'} direction',
        (tester) async {
      double? committed;
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: english ? TextDirection.ltr : TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 800,
                height: 300,
                child: Stack(children: [
                  PlayerBottomCluster(
                    durationMs: 100000,
                    positionMs: 25000,
                    bufferedMs: 50000,
                    showRemaining: false,
                    volume: 1,
                    muted: false,
                    fullscreen: true,
                    canPrev: false,
                    canNext: false,
                    scale: 1,
                    wide: false,
                    english: english,
                    onPrev: null,
                    onNext: null,
                    onVolumeChanged: _noopValue,
                    onVolumeDragEnd: _noop,
                    onMuteToggle: _noop,
                    onToggleFullscreen: _noop,
                    onOpenStreams: _noop,
                    onOpenSubtitles: _noop,
                    onOpenAudio: _noop,
                    onToggleRemaining: _noop,
                    onScrubStart: _noop,
                    onScrubUpdate: _noopValue,
                    onScrubEnd: (value) => committed = value,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ));
      final timeline = tester.getRect(find.byType(GradientTimeline));
      final played = tester.getRect(find
          .descendant(
            of: find.byType(GradientTimeline),
            matching: find.byType(FractionallySizedBox),
          )
          .at(1));
      final current = tester.getRect(find.text('0:25'));
      final total = tester.getRect(find.text('1:40'));
      if (english) {
        expect(played.right, closeTo(timeline.right, 1));
        expect(current.left, greaterThan(total.right));
      } else {
        expect(played.left, closeTo(timeline.left, 1));
        expect(current.right, lessThan(total.left));
      }
      await tester.tapAt(
          Offset(timeline.left + timeline.width * .25, timeline.center.dy));
      expect(committed, closeTo(english ? 75 : 25, .1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final direction in TextDirection.values) {
    testWidgets('played and buffered tracks begin at locale start $direction',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: GradientTimeline(
                  durationMs: 100000,
                  positionMs: 25000,
                  bufferedMs: 50000,
                  onScrubStart: _noop,
                  onScrubUpdate: _noopValue,
                  onScrubEnd: _noopValue,
                ),
              ),
            ),
          ),
        ),
      ));
      final timeline = tester.getRect(find.byType(GradientTimeline));
      final fractions = find.descendant(
        of: find.byType(GradientTimeline),
        matching: find.byType(FractionallySizedBox),
      );
      final buffered = tester.getRect(fractions.at(0));
      final played = tester.getRect(fractions.at(1));
      expect(buffered.width, closeTo(200, 1));
      expect(played.width, closeTo(100, 1));
      if (direction == TextDirection.rtl) {
        expect(buffered.right, closeTo(timeline.right, 1));
        expect(played.right, closeTo(timeline.right, 1));
      } else {
        expect(buffered.left, closeTo(timeline.left, 1));
        expect(played.left, closeTo(timeline.left, 1));
      }
    });
  }

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
