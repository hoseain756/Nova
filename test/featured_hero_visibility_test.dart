import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/featured_artwork.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/features/home/widgets/featured_hero.dart';

const _slides = [
  MediaItem(id: 'first', type: 'movie', name: 'First slide'),
  MediaItem(id: 'second', type: 'movie', name: 'Second slide'),
  MediaItem(id: 'third', type: 'movie', name: 'Third slide'),
];

class _Catalog extends CatalogRepository {
  _Catalog(super.api);
  final requests = <String>[];
  @override
  Future<FeaturedArtwork> featuredArtwork(
    MediaItem item, {
    String language = 'en-US',
    String region = 'US',
    String uiLanguage = 'en',
  }) async {
    requests.add(item.id);
    return FeaturedArtwork(title: item.name);
  }
}

void main() {
  testWidgets(
      'manual selection survives opening details and returning; only selected artwork loads',
      (tester) async {
    final api = NoorApi();
    final catalog = _Catalog(api);
    final app = AppState(api, catalog)..english = true;
    addTearDown(api.dispose);
    addTearDown(app.dispose);
    final navigator = GlobalKey<NavigatorState>();
    final active = ValueNotifier(false);
    addTearDown(active.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(
                body: SingleChildScrollView(
              child: ValueListenableBuilder<bool>(
                  valueListenable: active,
                  builder: (context, value, _) => FeaturedHero(
                      items: _slides,
                      active: value,
                      onTap: (item) {
                        Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) =>
                                Scaffold(body: Text('Details: ${item.id}'))));
                      })),
            )))));
    await tester.pump();
    final hero = find.byType(FeaturedHero);
    final screenHeight = MediaQuery.sizeOf(tester.element(hero)).height;
    expect(tester.getSize(hero).height, closeTo(screenHeight * .78, 1));
    expect(
        tester
            .getSize(find.byKey(const ValueKey('hero-slide-indicator-0')))
            .width,
        16);
    expect(
        tester
            .getSize(find.byKey(const ValueKey('hero-slide-indicator-1')))
            .width,
        8);
    expect(catalog.requests, isEmpty);
    active.value = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    expect(catalog.requests, ['first']);
    await tester.tap(find.byTooltip('Second slide'));
    await tester.pumpAndSettle();
    expect(
        tester
            .getSize(find.byKey(const ValueKey('hero-slide-indicator-1')))
            .width,
        16);
    expect(catalog.requests, ['first', 'second']);
    expect(find.text('Second slide'), findsOneWidget);
    await tester.tap(find.text('Explore title'));
    await tester.pumpAndSettle();
    expect(find.text('Details: second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 13));
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Second slide'), findsOneWidget);
    expect(catalog.requests, ['first', 'second']);
    await tester.drag(
        find.byKey(const ValueKey('media-hero-frame')), const Offset(-90, 0));
    await tester.pumpAndSettle();
    expect(find.text('Third slide'), findsOneWidget);
    expect(catalog.requests, ['first', 'second', 'third']);
    expect(tester.takeException(), isNull);
  });
}
