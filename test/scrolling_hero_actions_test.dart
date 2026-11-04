import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/home/widgets/cinematic_cover_scroll.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('editorial hero actions scroll into reach in $direction',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var activated = false;
      await tester.pumpWidget(MaterialApp(
          home: Directionality(
              textDirection: direction,
              child: Scaffold(
                  body: CinematicCoverScroll(
                scrollHero: true,
                heroHeight: 900,
                heroBuilder: (_) => Column(children: [
                  const Spacer(),
                  FilledButton(
                      key: const ValueKey('hero-action'),
                      onPressed: () => activated = true,
                      child: const Text('Details')),
                  const SizedBox(height: 24)
                ]),
                slivers: const [
                  SliverToBoxAdapter(child: SizedBox(height: 600))
                ],
              )))));
      await tester.ensureVisible(find.byKey(const ValueKey('hero-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hero-action')));
      expect(activated, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
