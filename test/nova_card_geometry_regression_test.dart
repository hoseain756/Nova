import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/models/visual_preferences.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/kids/kids_page.dart';
import 'package:nova_mobile/features/library/library_page.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:nova_mobile/shared/widgets/poster_card.dart';
import 'package:provider/provider.dart';

Widget _host(AppState app, Widget child, {required bool english}) =>
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(
        theme: NovaTheme.build(Brightness.light, arabic: !english),
        locale: Locale(english ? 'en' : 'ar'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          NovaStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );

void main() {
  test('Kids seeded Medium and inherit follow app-wide card preferences', () {
    for (final legacyValue in [null, 'medium', 'inherit', 'unknown']) {
      final preferences = novaKidsCardPreferences({
        'cardSize': 'large',
        'cardOrientation': 'horizontal',
        'posterRadius': 22,
        'kidsCardSize': legacyValue,
      });
      expect(preferences.size, CardSize.large);
      expect(preferences.orientation, CardOrientation.horizontal);
      expect(preferences.radius, 22);
    }
  });

  test('Kids explicit size choices preserve shared orientation and radius', () {
    for (final choice in [
      ('small', CardSize.small),
      ('mediumOverride', CardSize.medium),
      ('large', CardSize.large),
    ]) {
      final preferences = novaKidsCardPreferences({
        'cardSize': 'large',
        'cardOrientation': 'horizontal',
        'posterRadius': 18,
        'kidsCardSize': choice.$1,
      });
      expect(preferences.size, choice.$2);
      expect(preferences.orientation, CardOrientation.horizontal);
      expect(preferences.radius, 18);
    }
  });

  testWidgets('PosterCard uses its override for width and horizontal extent',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = NoorApi();
    final app = AppState(api, CatalogRepository(api));
    addTearDown(app.dispose);
    app.webSettings = {
      ...app.webSettings,
      'cardSize': 'small',
      'cardOrientation': 'horizontal',
    };
    const preferences = CardPreferences(
        size: CardSize.large, orientation: CardOrientation.horizontal);
    final dimensions = preferences.dimensions(1024);
    await tester.pumpWidget(_host(
      app,
      const Align(
        alignment: AlignmentDirectional.topStart,
        child: PosterCard(
          item: MediaItem(id: 'fixture', type: 'movie', name: 'A long title'),
          preferencesOverride: preferences,
          onTap: _noop,
        ),
      ),
      english: true,
    ));
    await tester.pump();
    final size = tester.getSize(find.byType(PosterCard));
    expect(size.width, dimensions.railWidth);
    expect(size.height, dimensions.horizontalExtent(dimensions.railWidth, 2));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 1024.0]) {
    for (final english in [true, false]) {
      testWidgets('horizontal watchlist has finite geometry $width $english',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = NoorApi();
        final app = AppState(api, CatalogRepository(api));
        addTearDown(app.dispose);
        app.english = english;
        app.webSettings = {
          ...app.webSettings,
          'cardSize': 'small',
          'cardOrientation': 'horizontal',
        };
        app.watchlist = const [
          MediaItem(
            id: 'fixture',
            type: 'movie',
            name: 'A long mixed title / حكاية طويلة 2026',
          ),
        ];
        await tester
            .pumpWidget(_host(app, const LibraryPage(), english: english));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.byType(PosterCard), 300,
            scrollable: find.byType(Scrollable).first);
        await tester.pump();
        final card = tester.widget<PosterCard>(find.byType(PosterCard).first);
        expect(card.width, isNotNull);
        expect(card.width!.isFinite, isTrue);
        final size = tester.getSize(find.byType(PosterCard).first);
        expect(size.width.isFinite, isTrue);
        expect(size.height.isFinite, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

void _noop() {}
