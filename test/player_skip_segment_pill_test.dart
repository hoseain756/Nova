import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/segments/skip_segment.dart';
import 'package:nova_mobile/features/player/widgets/player_skip_segment_pill.dart';

void main() {
  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('skip pill fits enlarged text in $direction $brightness',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 240));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var taps = 0;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: Center(
                  child: PlayerSkipSegmentPill(
                    segment: const SkipSegment(
                      type: SkipSegmentType.recap,
                      startMs: 0,
                      endMs: 30000,
                      source: 'test',
                    ),
                    english: direction == TextDirection.ltr,
                    onTap: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(PlayerSkipSegmentPill)).height,
            greaterThanOrEqualTo(48));
        expect(
            find.text(direction == TextDirection.ltr
                ? 'Skip recap'
                : 'تخطي ملخص الحلقة السابقة'),
            findsOneWidget);
        await tester.tap(find.byType(PlayerSkipSegmentPill));
        expect(taps, 1);
      });
    }
  }
}
