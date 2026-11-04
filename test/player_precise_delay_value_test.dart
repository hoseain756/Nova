import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/widgets/precise_delay_value.dart';
import 'package:nova_mobile/features/player/widgets/player_side_panel.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets('panel navigation stays beside close at 320dp in $direction',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var audio = 0;
      var subtitles = 0;
      var streams = 0;
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: PlayerSidePanel(
              title: 'A long player panel title that must fit',
              english: direction == TextDirection.ltr,
              currentKind: PlayerPanelKind.subtitles,
              onClose: () {},
              onOpenAudio: () => audio++,
              onOpenSubtitles: () => subtitles++,
              onOpenStreams: () => streams++,
              onRefresh: () {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ));

      final close = tester.getTopLeft(find.byIcon(LucideIcons.x));
      for (final icon in [
        LucideIcons.captions,
        LucideIcons.audioLines,
        LucideIcons.arrowLeftRight,
      ]) {
        expect(tester.getTopLeft(find.byIcon(icon)).dy, close.dy);
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(LucideIcons.audioLines));
      await tester.tap(find.byIcon(LucideIcons.captions));
      await tester.tap(find.byIcon(LucideIcons.arrowLeftRight));
      expect([audio, subtitles, streams], [1, 1, 1]);
    });

    testWidgets('vertical delay drag uses 10 ms steps in $direction',
        (tester) async {
      var delayMs = 125;
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: StatefulBuilder(builder: (context, setState) {
            return Scaffold(
              body: Center(
                child: SizedBox(
                  width: 180,
                  child: PreciseDelayValue(
                    valueMs: delayMs,
                    english: direction == TextDirection.ltr,
                    onDeltaMs: (delta) => setState(() => delayMs += delta),
                  ),
                ),
              ),
            );
          }),
        ),
      ));

      expect(find.text('0.125 s'), findsOneWidget);
      await tester.drag(find.byType(PreciseDelayValue), const Offset(0, -72));
      await tester.pump();
      expect(delayMs, greaterThan(125));
      expect((delayMs - 125) % 10, 0);
      expect(find.textContaining('.'), findsWidgets);

      final afterUp = delayMs;
      await tester.drag(find.byType(PreciseDelayValue), const Offset(0, 72));
      await tester.pump();
      expect(delayMs, lessThan(afterUp));
      expect((delayMs - 125) % 10, 0);
    });
  }
}
