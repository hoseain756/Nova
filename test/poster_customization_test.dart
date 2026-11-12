import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/models/poster_card_style.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/home/top10_rail.dart';
import 'package:nova_mobile/features/catalog/catalog_grid_page.dart';
import 'package:nova_mobile/features/home/widgets/async_media_section.dart';
import 'package:nova_mobile/features/settings/poster_card_settings_page.dart';
import 'package:nova_mobile/features/settings/widgets/settings_tiles.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:nova_mobile/shared/widgets/media_rail.dart';
import 'package:nova_mobile/shared/widgets/image_decode.dart';
import 'package:nova_mobile/shared/widgets/nova_network_image.dart';
import 'package:nova_mobile/shared/widgets/poster_card.dart';
import 'package:nova_mobile/shared/widgets/poster_layout.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends NoorApi {
  @override
  Future<void> initialize() async {}
  @override
  Future<List<dynamic>> loadIptvPlaylists() async => const [];
  @override
  bool isLinked(String service) => false;
  @override
  Future<bool> hasPendingTraktLink() async => false;
}

class _App extends AppState {
  _App(NoorApi api) : super(api, CatalogRepository(api));
  final writes = <String>[];
  @override
  Future<void> setSetting(String key, dynamic value) async {
    writes.add(key);
    webSettings = {...webSettings, key: value};
    notifyListeners();
  }
}

const _item = MediaItem(
    id: 'preview',
    type: 'movie',
    name: 'A long movie title عنوان فيلم طويل',
    releaseInfo: '2026',
    rating: '8.7');

Widget _host(AppState app, Widget child,
        {bool english = true,
        Brightness brightness = Brightness.dark,
        double textScale = 1}) =>
    ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          locale: Locale(english ? 'en' : 'ar'),
          localizationsDelegates: const [
            NovaStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          theme:
              brightness == Brightness.dark ? NovaTheme.dark : NovaTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: child,
        ));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('artwork quality requests TMDB sizes and preserves add-on URLs', () {
    const url = 'https://image.tmdb.org/t/p/w500/example.jpg';
    expect(ArtworkQuality.low.sourceUrl(url, hero: true, portrait: true),
        'https://image.tmdb.org/t/p/w500/example.jpg');
    expect(ArtworkQuality.balanced.sourceUrl(url, hero: true),
        'https://image.tmdb.org/t/p/w1280/example.jpg');
    expect(ArtworkQuality.high.sourceUrl(url),
        'https://image.tmdb.org/t/p/original/example.jpg');
    expect(ArtworkQuality.high.sourceUrl('https://addon.test/t/p/w500/a.jpg'),
        'https://addon.test/t/p/w500/a.jpg');
    expect(
        PosterCardStyle.fromSettings({'posterArtworkQuality': 'invalid'})
            .artworkQuality,
        'balanced');
  });

  test('old settings retain their values; malformed synced values are bounded',
      () {
    final legacy = PosterCardStyle.fromSettings(
        {'posterRadius': 18, 'posterScale': 1.3, 'hidePosterTitles': true});
    expect(legacy.radius, 18);
    expect(legacy.scale, 1.3);
    expect(legacy.hideTitles, isTrue);
    expect(legacy.landscape, isFalse);
    final invalid = PosterCardStyle.fromSettings({
      'posterRadius': double.nan,
      'posterScale': 'bad',
      'posterShape': 'bad',
      'posterLogoPosition': 5
    });
    expect(invalid, const PosterCardStyle());
    expect(
        PosterCardStyle.fromSettings({'posterRadius': -5, 'posterScale': 100})
            .radius,
        0);
    expect(PosterCardStyle.fromSettings({'posterScale': 100}).scale, 1.5);
  });

  for (final width in [320.0, 900.0]) {
    for (final english in [true, false]) {
      for (final brightness in Brightness.values) {
        for (final landscape in [false, true]) {
          testWidgets(
              'cards fit $width $english $brightness wide=$landscape at 2x text',
              (tester) async {
            tester.view.physicalSize = Size(width, 1100);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final app = _App(_Api())..english = english;
            addTearDown(app.dispose);
            app.webSettings = {
              ...app.webSettings,
              'posterShape': landscape ? 'landscape' : 'portrait',
              'posterScale': 1.5,
              'posterRadius': 40
            };
            await tester.pumpWidget(_host(
                app,
                Scaffold(
                    body: ListView(children: [
                  MediaRail(title: 'Rail', items: const [_item], onTap: (_) {}),
                  Top10Rail(
                      title: 'Top 10', items: const [_item], onTap: (_) {}),
                  const RailLoadingSkeleton(title: 'Loading'),
                  SizedBox(
                      height: 700,
                      child: LayoutBuilder(builder: (context, constraints) {
                        final metrics = PosterGridMetrics(
                            context, constraints.maxWidth - 48,
                            style: watchPosterStyle(context));
                        return GridView.builder(
                            padding: const EdgeInsets.all(24),
                            gridDelegate: metrics.delegate,
                            itemCount: 3,
                            itemBuilder: (_, __) => PosterCard(
                                item: _item,
                                onTap: () {},
                                width: metrics.width));
                      })),
                ])),
                english: english,
                brightness: brightness,
                textScale: 2));
            await tester.pump();
            expect(tester.takeException(), isNull);
            await tester.drag(
                find.byType(ListView).first, const Offset(0, -900));
            await tester.pump();
            expect(tester.takeException(), isNull);
          });
        }
        testWidgets(
            'settings fit $width $english $brightness with enlarged text',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final app = _App(_Api())..english = english;
          addTearDown(app.dispose);
          app.webSettings = {...app.webSettings, 'posterShape': 'landscape'};
          await tester.pumpWidget(_host(app, const PosterCardSettingsPage(),
              english: english, brightness: brightness, textScale: 2));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.drag(find.byType(ListView), const Offset(0, -2000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
      'preview updates during dragging and saves once on release; reset is scoped',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _App(_Api())..english = true;
    addTearDown(app.dispose);
    app.webSettings = {
      ...app.webSettings,
      'posterShape': 'landscape',
      'unrelated': 'keep'
    };
    await tester.pumpWidget(_host(app, const PosterCardSettingsPage()));
    final cardQuality = tester.widget<SettingsLanguageDropdown>(
        find.byKey(const ValueKey('posterArtworkQuality')));
    final heroQuality = tester.widget<SettingsLanguageDropdown>(
        find.byKey(const ValueKey('heroArtworkQuality')));
    expect(cardQuality.value, 'balanced');
    expect(heroQuality.value, 'high');
    cardQuality.onChanged('high');
    heroQuality.onChanged('low');
    await tester.pump();
    expect(app.webSettings['posterArtworkQuality'], 'high');
    expect(app.webSettings['heroArtworkQuality'], 'low');
    final slider =
        tester.widget<Slider>(find.byKey(const ValueKey('posterScale')));
    slider.onChanged!(1.5);
    await tester.pump();
    expect(app.writes, ['posterArtworkQuality', 'heroArtworkQuality']);
    final preview = tester
        .widget<PosterCard>(find.byKey(const ValueKey('poster-style-preview')));
    expect(preview.style?.scale, 1.5);
    slider.onChangeEnd!(1.5);
    await tester.pump();
    expect(app.writes,
        ['posterArtworkQuality', 'heroArtworkQuality', 'posterScale']);
    await tester.scrollUntilVisible(find.text('Reset card appearance'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Reset card appearance'));
    await tester.pumpAndSettle();
    expect(
        PosterCardStyle.fromSettings(app.webSettings), const PosterCardStyle());
    expect(app.webSettings['unrelated'], 'keep');
    expect(app.webSettings['heroArtworkQuality'], 'high');
    expect(app.webSettings['posterArtworkQuality'], 'balanced');
  });

  testWidgets(
      'wide cards use background and respect logo position; hidden titles retain semantics',
      (tester) async {
    final app = _App(_Api());
    addTearDown(app.dispose);
    app.webSettings = {
      ...app.webSettings,
      'posterShape': 'landscape',
      'posterLogoPosition': 'bottomEnd',
      'hidePosterTitles': true,
      'posterArtworkQuality': 'high'
    };
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(
        app,
        Scaffold(
            body: PosterCard(
                item: const MediaItem(
                    id: 'art',
                    type: 'movie',
                    name: 'Artwork title',
                    poster: 'https://image.tmdb.org/t/p/w500/poster.jpg',
                    background: 'https://image.tmdb.org/t/p/w780/wide.jpg',
                    logo: 'https://image.tmdb.org/t/p/w300/logo.png'),
                onTap: () {}))));
    final images = tester
        .widgetList<NovaNetworkImage>(find.byType(NovaNetworkImage))
        .toList();
    expect(images.first.url, 'https://image.tmdb.org/t/p/original/wide.jpg');
    expect(images.last.url, 'https://image.tmdb.org/t/p/original/logo.png');
    expect(find.text('Artwork title'), findsNothing);
    expect(find.bySemanticsLabel('Artwork title'), findsOneWidget);
    expect(
        tester
            .widgetList<Align>(find.byType(Align))
            .any((align) => align.alignment == AlignmentDirectional.bottomEnd),
        isTrue);
    await app.setSetting('showPosterLogo', false);
    await tester.pump();
    expect(find.byType(NovaNetworkImage), findsOneWidget);
    semantics.dispose();
  });

  test('card preferences persist across AppState reconstruction', () async {
    SharedPreferences.setMockInitialValues({
      AppState.settingsStorageKey: jsonEncode({'cloudSyncEnabled': false})
    });
    final api = _Api();
    final first = AppState(api, CatalogRepository(api));
    await first.initialize();
    for (final entry in <String, dynamic>{
      'posterScale': 1.3,
      'posterRadius': 28,
      'posterShape': 'landscape',
      'hidePosterTitles': true,
      'showPosterLogo': false,
      'posterLogoPosition': 'center',
      'posterArtworkQuality': 'high',
      'heroArtworkQuality': 'low',
    }.entries) {
      await first.setSetting(entry.key, entry.value);
    }
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < 20; i++) {
      if (jsonDecode(prefs.getString(AppState.settingsStorageKey)!)[
              'posterLogoPosition'] ==
          'center') {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final expected = PosterCardStyle.fromSettings(first.webSettings);
    first.dispose();
    final secondApi = _Api();
    final second = AppState(secondApi, CatalogRepository(secondApi));
    addTearDown(second.dispose);
    await second.initialize();
    expect(PosterCardStyle.fromSettings(second.webSettings), expected);
    expect(second.webSettings['heroArtworkQuality'], 'low');
  });

  testWidgets(
      'an open catalog relayouts its sliver when card preferences change',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _App(_Api())..english = true;
    addTearDown(app.dispose);
    await tester.pumpWidget(_host(app,
        const CatalogGridPage(title: 'Catalog', items: [_item, _item, _item]),
        textScale: 2));
    await tester.pumpAndSettle();
    final before = tester.getSize(find.byType(PosterCard).first).width;
    await app.setSetting('posterShape', 'landscape');
    await app.setSetting('posterScale', 1.5);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PosterCard).first).width,
        greaterThan(before));
    final aspect = tester.widget<AspectRatio>(find
        .descendant(
            of: find.byType(PosterCard).first,
            matching: find.byType(AspectRatio))
        .first);
    expect(aspect.aspectRatio, 16 / 9);
    await app.setSetting('hidePosterTitles', true);
    await tester.pumpAndSettle();
    expect(find.text(_item.name), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
