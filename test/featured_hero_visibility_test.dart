import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/features/home/widgets/featured_hero.dart';

const _slides = [
  MediaItem(id: 'first', type: 'movie', name: 'First slide'),
  MediaItem(id: 'second', type: 'movie', name: 'Second slide'),
  MediaItem(id: 'third', type: 'movie', name: 'Third slide'),
];

void main() {
  testWidgets('covered hero stops its timer and resumes when the route returns',
      (tester) async {
    final api = NoorApi();
    final app = AppState(api, CatalogRepository(api))
      ..english = true
      ..webSettings['tmdbEnabled'] = false;
    final visibility = ValueNotifier(1.0);
    final navigator = GlobalKey<NavigatorState>();
    addTearDown(app.dispose);
    addTearDown(api.dispose);
    addTearDown(visibility.dispose);

    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: FeaturedHero(
            items: _slides,
            autoplayActive: true,
            onTap: (_) {},
            contentVisibility: visibility,
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Second slide'), findsOneWidget);

    // A transparent covering route keeps the hero built and painted, making
    // this prove route visibility independently from offstage layout.
    navigator.currentState!.push(PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, __, ___) => const Center(child: Text('Player route')),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 13));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Second slide', skipOffstage: false), findsOneWidget);
    expect(find.text('First slide', skipOffstage: false), findsNothing);
    expect(find.text('Third slide', skipOffstage: false), findsNothing);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Third slide'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final gate in ['tab', 'ticker', 'reduced motion']) {
    testWidgets('hero respects $gate changes and resumes its timer',
        (tester) async {
      final api = NoorApi();
      final app = AppState(api, CatalogRepository(api))
        ..english = true
        ..webSettings['tmdbEnabled'] = false;
      final visibility = ValueNotifier(1.0);
      final suspended = ValueNotifier(false);
      addTearDown(app.dispose);
      addTearDown(api.dispose);
      addTearDown(visibility.dispose);
      addTearDown(suspended.dispose);

      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: suspended,
              builder: (context, value, _) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: gate == 'reduced motion' && value,
                ),
                child: TickerMode(
                  enabled: gate != 'ticker' || !value,
                  child: FeaturedHero(
                    items: _slides,
                    autoplayActive: gate != 'tab' || !value,
                    onTap: (_) {},
                    contentVisibility: visibility,
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Second slide'), findsOneWidget);

      suspended.value = true;
      await tester.pump();
      await tester.pump(const Duration(seconds: 13));
      expect(find.text('Second slide'), findsOneWidget);

      suspended.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Third slide'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
