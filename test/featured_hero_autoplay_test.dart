import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/home/widgets/featured_hero.dart';

void main() {
  const slides = [
    MediaItem(id: 'first', type: 'movie', name: 'First slide'),
    MediaItem(id: 'second', type: 'movie', name: 'Second slide'),
  ];

  for (final reduceMotion in [false, true]) {
    testWidgets(
        'featured hero advances when reduceMotion=$reduceMotion and pauses offscreen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = NoorApi();
      final app = AppState(api, CatalogRepository(api))
        ..english = true
        ..webSettings = {
          ...AppState.defaultSettings,
          'tmdbEnabled': false,
          'reduceMotion': reduceMotion,
        };
      final visibility = ValueNotifier<double>(1);
      addTearDown(() {
        visibility.dispose();
        app.dispose();
      });

      Widget host({required bool active}) => ChangeNotifierProvider.value(
            value: app,
            child: MaterialApp(
              theme: NovaTheme.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduceMotion),
                child: child!,
              ),
              home: Scaffold(
                body: FeaturedHero(
                  items: slides,
                  autoplayActive: active,
                  contentVisibility: visibility,
                  onTap: (_) {},
                ),
              ),
            ),
          );

      await tester.pumpWidget(host(active: true));
      expect(find.text('1 / 2'), findsOneWidget);
      final artworkSwitcher = tester.widget<AnimatedSwitcher>(find.descendant(
        of: find.byType(FeaturedHero),
        matching: find.byType(AnimatedSwitcher),
      ));
      expect(
        artworkSwitcher.duration,
        reduceMotion ? Duration.zero : const Duration(milliseconds: 380),
      );
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('2 / 2'), findsOneWidget);

      await tester.pumpWidget(host(active: false));
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('2 / 2'), findsOneWidget);

      await tester.pumpWidget(host(active: true));
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('1 / 2'), findsOneWidget);
    });
  }
}
