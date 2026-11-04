import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/media/detail_glass.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('menu fits safe viewport and flips above anchor: $direction',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 560);
      tester.view.viewInsets = FakeViewPadding(bottom: 180);
      tester.view.viewPadding = FakeViewPadding(top: 24, left: 8, right: 8);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () => showGlassMenu<void>(
                        context: context,
                        anchor: const Rect.fromLTWH(270, 300, 40, 40),
                        width: 400,
                        maxHeight: 500,
                        builder: (close) => Column(
                          key: const ValueKey('menu-content'),
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                              12,
                              (i) => GlassMenuItem(
                                  leading: const Icon(Icons.movie),
                                  label: 'A long option $i',
                                  onTap: () => close(null))),
                        ),
                      ),
                      child: const Text('Open'),
                    ))),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final scroll = find
          .ancestor(
              of: find.byKey(const ValueKey('menu-content')),
              matching: find.byType(SingleChildScrollView))
          .first;
      final rect = tester.getRect(scroll);
      expect(rect.left, greaterThanOrEqualTo(20));
      expect(rect.right, lessThanOrEqualTo(300));
      expect(rect.top, greaterThanOrEqualTo(36));
      expect(rect.bottom, lessThanOrEqualTo(292));
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 400));
      await tester.pump();
      expect(find.byKey(const ValueKey('menu-content')), findsNothing);
    });
  }
}
