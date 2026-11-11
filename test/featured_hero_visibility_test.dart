import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/featured_artwork.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/features/home/widgets/featured_hero.dart';
import 'package:nova_mobile/shared/widgets/media_hero.dart';
import 'package:nova_mobile/shared/widgets/nova_network_image.dart';

const _slides = [
  MediaItem(id: 'first', type: 'movie', name: 'First slide'),
  MediaItem(id: 'second', type: 'movie', name: 'Second slide'),
  MediaItem(id: 'third', type: 'movie', name: 'Third slide'),
];

class _Catalog extends CatalogRepository {
  _Catalog(super.api, {this.artwork});
  final FeaturedArtwork? artwork;
  final requests = <String>[];
  @override
  Future<FeaturedArtwork> featuredArtwork(
    MediaItem item, {
    String language = 'en-US',
    String region = 'US',
    String uiLanguage = 'en',
  }) async {
    requests.add(item.id);
    return artwork ?? FeaturedArtwork(title: item.name);
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
    final dots = [
      for (var i = 0; i < 3; i++)
        tester.getCenter(find.byKey(ValueKey('hero-slide-indicator-$i'))).dx
    ];
    expect(dots[1] - dots[0], 32);
    expect(dots[2] - dots[1], 32);
    expect(dots[1], closeTo(tester.getCenter(hero).dx, 1));
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

  testWidgets(
      'phone uses full-height portrait art and wide layout uses backdrop',
      (tester) async {
    const item = MediaItem(
      id: 'poster-test',
      type: 'movie',
      name: 'Poster test',
      poster: 'https://example.com/poster.jpg',
      background: 'https://example.com/backdrop.jpg',
    );
    final api = NoorApi();
    final catalog = _Catalog(api,
        artwork: const FeaturedArtwork(
          portrait: 'https://example.com/portrait.jpg',
          landscape: 'https://example.com/landscape.jpg',
        ));
    final app = AppState(api, catalog)..english = true;
    addTearDown(api.dispose);
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child:
                        FeaturedHero(items: const [item], onTap: (_) {}))))));
    expect(tester.widget<MediaHero>(find.byType(MediaHero)).artworkUrl,
        item.poster);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<MediaHero>(find.byType(MediaHero)).artworkUrl,
        'https://example.com/portrait.jpg');
    final phoneImage = tester.widget<NovaNetworkImage>(find.descendant(
        of: find.byType(MediaHero), matching: find.byType(NovaNetworkImage)));
    expect(phoneImage.fit, BoxFit.cover);
    expect(phoneImage.alignment, Alignment.topCenter);
    expect(phoneImage.cacheHeight, 624);
    expect(tester.getSize(find.byKey(const ValueKey('media-hero-frame'))),
        const Size(360, 624));

    tester.view.physicalSize = const Size(1024, 768);
    await tester.pump();
    expect(tester.widget<MediaHero>(find.byType(MediaHero)).artworkUrl,
        'https://example.com/landscape.jpg');
    final wideImage = tester.widget<NovaNetworkImage>(find.descendant(
        of: find.byType(MediaHero), matching: find.byType(NovaNetworkImage)));
    expect(wideImage.cacheWidth, 1024);
  });
}
