import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/shell/nova_browse_widgets.dart';

void main() {
  for (final size in [const Size(390, 800), const Size(1024, 768)]) {
    testWidgets('browse hero stays 16:9 at ${size.width}dp', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      var opened = false;
      await tester.pumpWidget(MaterialApp(
        theme: NovaTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: NovaBrowseFeature(
              item: const MediaItem(
                id: 'anime:test',
                type: 'series',
                name: 'A featured series',
              ),
              label: 'Anime',
              actionLabel: 'Explore title',
              onOpen: () => opened = true,
            ),
          ),
        ),
      ));

      final hero = find.byKey(const ValueKey('nova-browse-hero'));
      final cardSize = tester.getSize(hero);
      expect(cardSize.width / cardSize.height, closeTo(16 / 9, .001));
      expect(tester.takeException(), isNull);

      await tester.tap(hero);
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
              child: NovaBrowseFeature(
                item: MediaItem(
                  id: 'kids:test',
                  type: 'movie',
                  name: 'حكاية طويلة للأطفال',
                ),
                label: 'NOVA للأطفال',
                actionLabel: 'اكتشف العمل',
                onOpen: _noop,
              ),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      final cardSize =
          tester.getSize(find.byKey(const ValueKey('nova-browse-hero')));
      expect(cardSize.width / cardSize.height, closeTo(16 / 9, .001));
    });
  }
}

void _noop() {}
