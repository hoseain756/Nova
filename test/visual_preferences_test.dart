import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/models/visual_preferences.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/shared/widgets/image_decode.dart';
import 'package:nova_mobile/shared/widgets/poster_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LocalNoorApi extends NoorApi {
  @override
  Future<void> initialize() async {}

  @override
  Future<List<dynamic>> loadIptvPlaylists() async => const [];

  @override
  bool isLinked(String service) => false;

  @override
  Future<bool> hasPendingTraktLink() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('card settings preserve legacy radius and fall back from invalid data',
      () {
    expect(CardPreferences.fromSettings(const {}).size, CardSize.medium);
    expect(CardPreferences.fromSettings(const {}).orientation,
        CardOrientation.vertical);
    expect(CardPreferences.fromSettings(const {'posterRadius': 22}).radius, 22);
    final invalid = CardPreferences.fromSettings(const {
      'cardSize': 'unknown',
      'cardOrientation': 'diagonal',
      'posterRadius': 100,
    });
    expect(invalid, const CardPreferences(radius: 28));
    final dimensions = invalid.dimensions(390);
    expect(dimensions.gridColumns(342), 2);
    expect(
        const CardPreferences(size: CardSize.large).dimensions(390).railWidth,
        greaterThan(dimensions.railWidth));
    expect(
        const CardPreferences(orientation: CardOrientation.horizontal)
            .dimensions(390)
            .gridColumns(342),
        1);
  });

  test('known provider URLs receive valid poster/backdrop sizes only', () {
    const poster = 'https://image.tmdb.org/t/p/w342/aBc.jpg?language=ar';
    const backdrop = 'https://image.tmdb.org/t/p/original/hero.jpg';
    expect(
      providerSizedImageUrl(poster,
          quality: ImageQuality.auto, targetPixels: 365),
      'https://image.tmdb.org/t/p/w500/aBc.jpg?language=ar',
    );
    expect(
      providerSizedImageUrl(poster,
          quality: ImageQuality.low, targetPixels: 999),
      'https://image.tmdb.org/t/p/w185/aBc.jpg?language=ar',
    );
    expect(
      providerSizedImageUrl(backdrop,
          quality: ImageQuality.high,
          targetPixels: 200,
          kind: ProviderImageKind.backdrop),
      'https://image.tmdb.org/t/p/w1280/hero.jpg',
    );
    expect(
      providerSizedImageUrl(poster,
          quality: ImageQuality.original, targetPixels: 200),
      'https://image.tmdb.org/t/p/original/aBc.jpg?language=ar',
    );
    for (final url in [
      'https://addon.example.com/t/p/w342/aBc.jpg?signature=123',
      'http://image.tmdb.org/t/p/w342/aBc.jpg',
      'https://image.tmdb.org/t/p/custom/aBc.jpg',
    ]) {
      expect(
          providerSizedImageUrl(url,
              quality: ImageQuality.low, targetPixels: 200),
          url);
    }
  });

  test('hero and card quality are independent and cellular saving is opt-in',
      () {
    final preferences = ImageQualityPreferences.fromSettings(const {
      'heroImageQuality': 'original',
      'cardImageQuality': 'medium',
      'saveCellularData': true,
    });
    expect(preferences.forRole(ImageRole.hero), ImageQuality.original);
    expect(preferences.forRole(ImageRole.card), ImageQuality.medium);
    expect(preferences.forRole(ImageRole.hero, isCellular: true),
        ImageQuality.high);
    expect(preferences.forRole(ImageRole.card, isCellular: true),
        ImageQuality.low);
    expect(
        ImageQualityPreferences.fromSettings(const {}).hero, ImageQuality.auto);
  });

  test('visual preferences persist in the existing settings bucket', () async {
    SharedPreferences.setMockInitialValues({
      AppState.settingsStorageKey: jsonEncode({
        'cloudSyncEnabled': false,
        'uiLanguage': 'en',
      }),
      'horse.mobile.english': true,
    });
    final api = _LocalNoorApi();
    final first = AppState(api, CatalogRepository(api));
    await first.initialize();
    await first.setSetting('cardSize', 'large');
    await first.setSetting('cardOrientation', 'horizontal');
    await first.setSetting('posterRadius', 2);
    await first.setSetting('heroImageQuality', 'high');
    await first.setSetting('cardImageQuality', 'low');
    await first.setSetting('heroTrailerAutoplay', 'never');

    final storage = await SharedPreferences.getInstance();
    for (var attempt = 0; attempt < 30; attempt++) {
      final decoded =
          jsonDecode(storage.getString(AppState.settingsStorageKey) ?? '{}')
              as Map;
      if (decoded['heroTrailerAutoplay'] == 'never' &&
          decoded['cardSize'] == 'large') {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    first.dispose();

    final secondApi = _LocalNoorApi();
    final second = AppState(secondApi, CatalogRepository(secondApi));
    addTearDown(second.dispose);
    await second.initialize();
    expect(
        CardPreferences.fromSettings(second.webSettings),
        const CardPreferences(
            size: CardSize.large,
            orientation: CardOrientation.horizontal,
            radius: 2));
    final quality = ImageQualityPreferences.fromSettings(second.webSettings);
    expect(quality.hero, ImageQuality.high);
    expect(quality.card, ImageQuality.low);
    expect(second.webSettings['heroTrailerAutoplay'], 'never');
  });

  for (final brightness in Brightness.values) {
    for (final direction in TextDirection.values) {
      testWidgets('poster card follows $direction in $brightness mode',
          (tester) async {
        final api = _LocalNoorApi();
        final app = AppState(api, CatalogRepository(api));
        addTearDown(app.dispose);
        app.webSettings = {
          ...app.webSettings,
          'tmdbEnabled': false,
          'cardOrientation': 'horizontal',
          'cardSize': 'medium',
        };
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: app,
          child: MaterialApp(
            theme: brightness == Brightness.light
                ? NovaTheme.light
                : NovaTheme.dark,
            home: Directionality(
              textDirection: direction,
              child: const Scaffold(
                body: Center(
                  child: PosterCard(
                    item: MediaItem(
                        id: 'preview', type: 'movie', name: 'Card Preview'),
                    width: 260,
                    onTap: _noop,
                  ),
                ),
              ),
            ),
          ),
        ));
        final image = tester.getRect(find.byIcon(LucideIcons.film));
        final title = tester.getRect(find.text('Card Preview'));
        if (direction == TextDirection.ltr) {
          expect(image.center.dx, lessThan(title.center.dx));
        } else {
          expect(image.center.dx, greaterThan(title.center.dx));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('large text fits horizontal and vertical card layouts',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _LocalNoorApi();
    final app = AppState(api, CatalogRepository(api));
    addTearDown(app.dispose);
    app.webSettings = {
      ...app.webSettings,
      'tmdbEnabled': false,
      'cardOrientation': 'horizontal',
    };
    Widget view() => ChangeNotifierProvider<AppState>.value(
          value: app,
          child: MaterialApp(
            theme: NovaTheme.dark,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const Scaffold(
                body: Center(
                  child: PosterCard(
                    item: MediaItem(
                      id: 'scaled',
                      type: 'movie',
                      name: 'A long title that needs more than one line',
                      releaseInfo: '2026 · Science fiction',
                    ),
                    width: 260,
                    onTap: _noop,
                  ),
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(view());
    expect(tester.takeException(), isNull);
    await app.setSetting('cardOrientation', 'vertical');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
