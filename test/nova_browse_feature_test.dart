import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/shared/widgets/media_hero.dart';

void main() {
  for (final size in [const Size(390, 800), const Size(1024, 768)]) {
    testWidgets('browse hero adapts at ${size.width}dp', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      var opened = false;
      await tester.pumpWidget(MaterialApp(
        theme: NovaTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MediaHero(
              item: const MediaItem(
                id: 'anime:test',
                type: 'series',
                name: 'A featured series',
              ),
              actions: FilledButton(
                  onPressed: () => opened = true,
                  child: const Text('Explore title')),
            ),
          ),
        ),
      ));

      final art =
          tester.getRect(find.byKey(const ValueKey('media-hero-frame')));
      final title = tester.getRect(find.text('A featured series'));
      if (size.width < 700) {
        expect(art.width, size.width);
        expect(title.top, greaterThanOrEqualTo(art.bottom));
      } else {
        expect(title.right, lessThanOrEqualTo(art.left));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Explore title'));
      expect(opened, isTrue);
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('browse hero fits enlarged Arabic text at ${width}dp',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        theme: NovaTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: MediaHero(
                item: MediaItem(
                  id: 'kids:test',
                  type: 'movie',
                  name: 'حكاية طويلة للأطفال',
                  runtime: '52 min',
                ),
                actions:
                    FilledButton(onPressed: _noop, child: Text('اكتشف العمل')),
              ),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text('52 min')).textDirection,
          TextDirection.ltr);
      expect(
          tester.widget<Text>(find.text('حكاية طويلة للأطفال')).textDirection,
          TextDirection.rtl);
      final button = find.byType(FilledButton);
      await tester.ensureVisible(button);
      expect(button.hitTestable(), findsOneWidget);
    });
  }
}

void _noop() {}
