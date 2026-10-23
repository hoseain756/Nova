import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/addon.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/core/update/app_update_service.dart';
import 'package:nova_mobile/core/version.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:nova_mobile/features/settings/addons_page.dart';
import 'package:nova_mobile/features/settings/integrations_page.dart';
import 'package:nova_mobile/features/settings/settings_page.dart';
import 'package:nova_mobile/features/settings/settings_display_page.dart';
import 'package:nova_mobile/features/settings/settings_data_page.dart';
import 'package:nova_mobile/shared/widgets/nova_brand.dart';
import 'package:nova_mobile/features/settings/catalog_settings_page.dart';
import 'package:nova_mobile/features/settings/settings_personalization_page.dart';
import 'package:nova_mobile/features/settings/settings_preferences_page.dart';
import 'package:nova_mobile/features/settings/stats_page.dart';
import 'package:nova_mobile/features/settings/widgets/settings_tiles.dart';

class _SettingsApp extends AppState {
  _SettingsApp(NoorApi api) : super(api, CatalogRepository(api)) {
    english = true;
  }
  @override
  Future<void> setLanguage(bool value) async {
    english = value;
    webSettings = {...webSettings, 'uiLanguage': value ? 'en' : 'ar'};
    notifyListeners();
  }

  @override
  Future<void> setSetting(String key, dynamic value) async {
    webSettings = {...webSettings, key: value};
    notifyListeners();
  }

  @override
  Future<void> setAddonEnabled(String id, bool enabled) async {
    addons = addons
        .map((a) => a.id == id ? a.copyWith(enabled: enabled) : a)
        .toList();
    notifyListeners();
  }

  @override
  Future<void> reorderAddons(int oldIndex, int newIndex) async {
    final sorted = List.of(addons)..sort((a, b) => a.order.compareTo(b.order));
    if (oldIndex < newIndex) newIndex--;
    final moved = sorted.removeAt(oldIndex);
    sorted.insert(newIndex, moved);
    addons = [
      for (var i = 0; i < sorted.length; i++) sorted[i].copyWith(order: i)
    ];
    notifyListeners();
  }
}

class _StaticUpdateService extends AppUpdateService {
  @override
  Future<AppUpdateStatus> checkForUpdates() async => const AppUpdateStatus(
        manifest: AppUpdateManifest(
          latestVersion: '1.0.3',
          latestBuild: 66,
          minBuild: 1,
          messageAr: '',
          androidUrl: 'https://example.com/nova.apk',
          iosUrl: '',
        ),
        currentVersion: '1.0.3',
        currentBuild: 66,
      );
}

Widget _harness(_SettingsApp app, Widget page,
        {double scale = 1, bool light = false}) =>
    ChangeNotifierProvider<AppState>.value(
        value: app,
        child: Builder(builder: (context) {
          final english = context.watch<AppState>().english;
          return MaterialApp(
              theme: english
                  ? (light ? NovaTheme.light : NovaTheme.dark)
                  : NovaTheme.build(light ? Brightness.light : Brightness.dark,
                      arabic: true),
              locale: Locale(english ? 'en' : 'ar'),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                NovaStrings.delegate,
                ...GlobalMaterialLocalizations.delegates
              ],
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: page);
        }));

void main() {
  for (final (size, english, light) in [
    (const Size(360, 800), true, true),
    (const Size(360, 800), false, false),
    (const Size(1200, 800), true, false),
    (const Size(1200, 800), false, true),
  ]) {
    testWidgets(
        'About lockup and update fit $size ${english ? 'English' : 'Arabic'} ${light ? 'light' : 'dark'}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = _SettingsApp(NoorApi())..english = english;
      addTearDown(app.dispose);
      await tester.pumpWidget(_harness(
        app,
        SettingsAboutPage(updateService: _StaticUpdateService()),
        scale: 2,
        light: light,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(NovaBrand), findsOneWidget);
      final header = find.byKey(const Key('about_brand_header'));
      final version = find.text(noorVersionLabel);
      expect(tester.widget<Padding>(header).child, isA<Column>());
      expect(version, findsOneWidget);
      expect(tester.getCenter(find.byType(NovaBrand)).dx,
          closeTo(size.width / 2, 1));
      expect(tester.getCenter(version).dx, closeTo(size.width / 2, 1));
      expect(find.byType(ListTile), findsWidgets);
      expect(Directionality.of(tester.element(find.byType(SettingsAboutPage))),
          english ? TextDirection.ltr : TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('required update dialog keeps the lockup and action reachable',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _SettingsApp(NoorApi());
    const status = AppUpdateStatus(
      manifest: AppUpdateManifest(
        latestVersion: '1.0.4',
        latestBuild: 67,
        minBuild: 67,
        messageAr: 'تحديث مطلوب',
        androidUrl: 'https://example.com/nova.apk',
        iosUrl: '',
      ),
      currentVersion: '1.0.3',
      currentBuild: 66,
    );
    await tester.pumpWidget(_harness(
        app, const SettingsAboutPage(initialStatus: status),
        scale: 2));
    await tester.pumpAndSettle();
    expect(find.byType(NovaBrand), findsWidgets);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog settings keep Kids tab and persist Home visibility',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _SettingsApp(NoorApi());
    app.addons = [
      Addon(
        id: 'family',
        name: 'Family add-on',
        transportUrl: 'https://family.example/manifest.json',
        manifest: const {
          'catalogs': [
            {'id': 'kids', 'type': 'movie', 'name': 'Kids'},
            {'id': 'anime', 'type': 'series', 'name': 'Anime'},
          ],
        },
      ),
    ];
    await tester
        .pumpWidget(_harness(app, const CatalogSettingsPage(), scale: 2));
    await tester.tap(find.text('Hide Kids catalogs on Home'));
    await tester.pump();
    expect(app.webSettings['hideKidsCatalogsHome'], true);
    await tester.scrollUntilVisible(find.text('Kids'), 160,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Kids'), findsOneWidget);
    await app.setLanguage(false);
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(find.byType(CatalogSettingsPage))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog order lives under Catalog & navigation', (tester) async {
    final app = _SettingsApp(NoorApi());
    addTearDown(app.dispose);
    await tester.pumpWidget(_harness(app, const SettingsPage()));
    expect(find.widgetWithText(SettingsTile, 'Catalog order'), findsNothing);
    final displayTile =
        find.widgetWithText(SettingsTile, 'Catalog & navigation');
    await tester.scrollUntilVisible(displayTile, 160,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(displayTile);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDisplayPage), findsOneWidget);
    await tester.tap(find.widgetWithText(SettingsTile, 'Catalog order'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogSettingsPage), findsOneWidget);
  });

  testWidgets('catalog label saves and drag keeps the card shape',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _SettingsApp(NoorApi());
    addTearDown(app.dispose);
    app.addons = [
      Addon(
        id: 'family',
        name: 'Family add-on',
        transportUrl: 'https://family.example/manifest.json',
        manifest: const {
          'catalogs': [
            {'id': 'kids', 'type': 'movie', 'name': 'Kids'},
            {'id': 'anime', 'type': 'series', 'name': 'Anime'},
          ],
        },
      ),
    ];
    await tester.pumpWidget(_harness(app, const CatalogSettingsPage()));
    await tester.tap(find.byTooltip('Rename catalog').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Family picks');
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();
    expect(app.webSettings['catalogRowNames'],
        {'family:movie:kids': 'Family picks'});
    expect(find.text('Family picks'), findsOneWidget);

    final list =
        tester.widget<ReorderableListView>(find.byType(ReorderableListView));
    const card = SizedBox();
    expect(list.buildDefaultDragHandles, isFalse);
    expect(list.proxyDecorator!(card, 0, const AlwaysStoppedAnimation(0.5)),
        same(card));
    final handle = find.byIcon(LucideIcons.gripVertical).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 16));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 220));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(app.webSettings['catalogRowOrder'],
        ['family:series:anime', 'family:movie:kids']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog rename fits narrow RTL layout and can be reset',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _SettingsApp(NoorApi())..english = false;
    addTearDown(app.dispose);
    app.addons = [
      Addon(
        id: 'arabic',
        name: 'إضافة طويلة الاسم',
        transportUrl: 'https://arabic.example/manifest.json',
        manifest: const {
          'catalogs': [
            {'id': 'shows', 'type': 'series', 'name': 'مسلسلات العائلة'},
          ],
        },
      ),
    ];
    await tester.pumpWidget(
        _harness(app, const CatalogSettingsPage(), scale: 2, light: true));
    await tester.scrollUntilVisible(find.byTooltip('تعديل اسم الكتالوج'), 120,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(ReorderableListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تعديل اسم الكتالوج'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'العائلة 2');
    await tester.tap(find.text('حفظ الاسم'));
    await tester.pumpAndSettle();
    expect(find.text('العائلة 2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('تعديل اسم الكتالوج'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.text('حفظ الاسم'));
    await tester.pumpAndSettle();
    expect(app.webSettings['catalogRowNames'], isEmpty);
    expect(find.text('مسلسلات العائلة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'search finds a setting category and language changes direction live',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _SettingsApp(NoorApi());
    await tester.pumpWidget(_harness(app, const SettingsPage()));
    await tester.enterText(find.byType(TextField), 'language');
    await tester.pump();
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPersonalizationPage), findsOneWidget);
    await tester.tap(find.text('Arabic'));
    await tester.pumpAndSettle();
    expect(app.english, isFalse);
    expect(app.webSettings['uiLanguage'], 'ar');
    expect(
        Directionality.of(
            tester.element(find.byType(SettingsPersonalizationPage))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 800), const Size(1200, 800)]) {
    for (final english in [true, false]) {
      testWidgets(
          'settings fit $size with 200% text, ${english ? 'LTR' : 'RTL'}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = _SettingsApp(NoorApi())..english = english;
        await tester.pumpWidget(
            _harness(app, const SettingsPage(), scale: 2, light: english));
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final page in const <Widget>[
          SettingsPreferencesPage(subtitles: false),
          SettingsPreferencesPage(subtitles: true),
          SettingsDisplayPage(),
          SettingsDisplayPage(kidsOnly: true),
          SettingsPersonalizationPage(section: 'language'),
          SettingsPersonalizationPage(section: 'appearance'),
          IntegrationsPage(),
          AddonsPage(),
          StatsPage(),
        ]) {
          await tester
              .pumpWidget(_harness(app, page, scale: 2, light: english));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '${page.runtimeType} at $size');
          await tester.drag(
              find.byType(Scrollable).first, const Offset(0, -3000));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: 'Scrolled ${page.runtimeType} at $size');
        }
      });
    }
  }

  testWidgets(
      'addon priority controls update order and enable state independently',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _SettingsApp(NoorApi())
      ..addons = const [
        Addon(
            id: 'a',
            name: 'Catalog A',
            transportUrl: 'https://a.example/manifest.json',
            manifest: {},
            order: 0),
        Addon(
            id: 'b',
            name: 'Catalog B',
            transportUrl: 'https://b.example/manifest.json',
            manifest: {},
            order: 1),
      ];
    await tester.pumpWidget(_harness(app, const AddonsPage()));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Move down').first);
    await tester.tap(find.byTooltip('Move down').first);
    await tester.pump();
    expect(app.addons.first.id, 'b');
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(app.addons.first.enabled, isFalse);
    expect(app.addons.last.enabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resume snapshot retention persists the selected period',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _SettingsApp(NoorApi());

    await tester.pumpWidget(
      _harness(app, const SettingsPreferencesPage(subtitles: false)),
    );
    await tester.ensureVisible(find.text('Resume screenshot retention'));
    await tester.tap(find.text('Resume screenshot retention'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 days'));
    await tester.pumpAndSettle();

    expect(app.webSettings['resumeSnapshotRetentionDays'], 10);
    expect(
      find.text(
        'Pause-frame previews stay on this device and are deleted after the selected period.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
