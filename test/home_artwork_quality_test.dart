import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/home/widgets/continue_watching_rail.dart';
import 'package:nova_mobile/features/home/widgets/featured_hero.dart';
import 'package:nova_mobile/shared/widgets/image_decode.dart';
import 'package:nova_mobile/shared/widgets/nova_network_image.dart';

const _poster = 'https://image.tmdb.org/t/p/w500/poster.jpg';
const _backdrop = 'https://image.tmdb.org/t/p/w780/backdrop.jpg';

void main() {
  for (final wide in [false, true]) {
    for (final hasBackdrop in [false, true]) {
      testWidgets(
          'Hero selects a valid CDN role: wide=$wide backdrop=$hasBackdrop',
          (tester) async {
        final size = wide ? const Size(1024, 768) : const Size(390, 844);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = NoorApi();
        final app = AppState(api, CatalogRepository(api));
        app.webSettings.addAll({
          'tmdbEnabled': false,
          'heroImageQuality': 'high',
          'heroTrailerAutoplay': 'never',
        });
        final visibility = ValueNotifier<double>(1);
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: app,
          child: MaterialApp(
            theme: NovaTheme.light,
            home: Scaffold(
              body: FeaturedHero(
                items: [
                  MediaItem(
                      id: 'fixture',
                      type: 'movie',
                      name: 'Fixture',
                      poster: _poster,
                      background: hasBackdrop ? _backdrop : null)
                ],
                autoplayActive: false,
                contentVisibility: visibility,
                onTap: (_) {},
              ),
            ),
          ),
        ));
        final art =
            tester.widget<NovaNetworkImage>(find.byType(NovaNetworkImage));
        expect(
            art.url,
            wide && hasBackdrop
                ? 'https://image.tmdb.org/t/p/w1280/backdrop.jpg'
                : 'https://image.tmdb.org/t/p/w780/poster.jpg');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        visibility.dispose();
        app.dispose();
        api.dispose();
      });
    }
  }
  for (final hasBackdrop in [false, true]) {
    testWidgets(
        'Continue Watching preserves artwork role: backdrop=$hasBackdrop',
        (tester) async {
      final api = NoorApi();
      final app = AppState(api, CatalogRepository(api));
      app.webSettings['cardImageQuality'] = 'high';
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          theme: NovaTheme.light,
          home: Scaffold(
              body: ContinueCard(
            data: CwCardData(
                id: 'fixture',
                progress: .5,
                item: MediaItem(
                    id: 'fixture',
                    type: 'movie',
                    name: 'Fixture',
                    poster: _poster,
                    background: hasBackdrop ? _backdrop : null)),
            english: true,
            width: 260,
            height: 300,
            onOpen: () {},
          )),
        ),
      ));
      final art =
          tester.widget<NovaNetworkImage>(find.byType(NovaNetworkImage));
      expect(art.providerKind,
          hasBackdrop ? ProviderImageKind.backdrop : ProviderImageKind.poster);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
      api.dispose();
    });
  }
}
