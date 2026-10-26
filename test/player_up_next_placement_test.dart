import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/widgets/player_chrome.dart';

void main() {
  testWidgets('Up-Next action and X dismissal stay independent',
      (tester) async {
    var nextCount = 0;
    var dismissCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: PlayerUpNextActions(
            primaryLabel: 'الحلقة التالية',
            secondaryLabel: 'إلغاء',
            onPrimary: () => nextCount++,
            onSecondary: () => dismissCount++,
          ),
        ),
      ),
    ));
    await tester.tap(find.text('الحلقة التالية'));
    expect(nextCount, 1);
    expect(dismissCount, 0);
    await tester.tap(find.byTooltip('إلغاء'));
    expect(nextCount, 1);
    expect(dismissCount, 1);
  });

  for (final scenario in <(Size, TextDirection, double, ThemeMode)>[
    (const Size(800, 360), TextDirection.rtl, 1, ThemeMode.dark),
    (const Size(320, 240), TextDirection.rtl, 2, ThemeMode.light),
    (const Size(320, 240), TextDirection.ltr, 2, ThemeMode.dark),
  ]) {
    testWidgets(
        'Up-Next stays inside ${scenario.$1} ${scenario.$2} '
        'text ${scenario.$3}', (tester) async {
      tester.view.physicalSize = scenario.$1 * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
        themeMode: scenario.$4,
        home: MediaQuery(
          data: MediaQueryData(
            size: scenario.$1,
            textScaler: TextScaler.linear(scenario.$3),
          ),
          child: Directionality(
            textDirection: scenario.$2,
            child: Scaffold(
              body: Stack(fit: StackFit.expand, children: [
                PlayerUpNextPlacement(
                  scale: 1,
                  child: PlayerCardShell(
                    width: 288,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PlayerCardHeader(
                          icon: Icons.skip_next,
                          label: 'الحلقة التالية',
                          trailing: Text('00:30'),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'عنوان حلقة طويل جدًا مع Mixed English Words 123',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text('S23:E02'),
                        const SizedBox(height: 11),
                        PlayerUpNextActions(
                          primaryLabel: 'عرض مصادر الحلقة التالية',
                          secondaryLabel: 'إلغاء',
                          onPrimary: () {},
                          onSecondary: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      expect(viewport.top, greaterThanOrEqualTo(0));
      expect(viewport.bottom, lessThanOrEqualTo(scenario.$1.height));
      expect(viewport.left, greaterThanOrEqualTo(0));
      expect(viewport.right, lessThanOrEqualTo(scenario.$1.width));
      expect(find.text('الحلقة التالية'), findsOneWidget);
    });
  }
}
