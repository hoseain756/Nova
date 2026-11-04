import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/auth/account_controller.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/downloads/download_manager.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/platform/app_icon_service.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/account/account_pages.dart';
import 'package:nova_mobile/features/downloads/downloads_view.dart';
import 'package:nova_mobile/features/settings/card_customization_page.dart';
import 'package:nova_mobile/features/settings/settings_page.dart';
import 'package:nova_mobile/features/settings/settings_display_page.dart';
import 'package:nova_mobile/features/settings/settings_personalization_page.dart';
import 'package:nova_mobile/features/settings/stats_page.dart';
import 'package:nova_mobile/features/settings/app_icon_settings_page.dart';
import 'package:nova_mobile/features/settings/catalog_settings_page.dart';
import 'package:nova_mobile/features/settings/navigation_bar_style_page.dart';
import 'package:nova_mobile/features/settings/settings_data_page.dart';
import 'package:nova_mobile/features/settings/settings_preferences_page.dart';
import 'package:nova_mobile/features/shell/search_sheet.dart';
import 'package:nova_mobile/features/shell/material_floating_dock.dart';
import 'package:nova_mobile/features/shell/noor_dock_tabs.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';

const _capture = ValueKey('redesign-capture');
const _write = bool.fromEnvironment('NOVA_WRITE_ACCEPTANCE');

class _FixtureIcons implements AppIconController {
  @override
  Future<AppIconSelection> current() async => const AppIconSelection(
      supported: true, selected: 'classic', ids: ['classic', 'clear', 'dark']);
  @override
  Future<AppIconSelection> select(String id) async => AppIconSelection(
      supported: true, selected: id, ids: const ['classic', 'clear', 'dark']);
}

Widget _downloads() => Scaffold(
        body: DownloadsView(jobs: [
      for (final status in [
        'downloading',
        'complete',
        'failed',
        'queued',
        'cancelled'
      ])
        NovaDownload(
            id: status,
            title: 'الحكاية 2026 A very long title across two languages',
            path: '$status.mp4',
            status: status,
            received: 500,
            total: 1000,
            error: status == 'failed' ? 'invalidSource' : null),
    ], onPlay: (_) {}, onCancel: (_) {}, onRetry: (_) {}, onRemove: (_) {}));

void main() {
  setUpAll(() async {
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
    await lucide.load();
    for (final family in ['Poppins', 'IBMPlexSansArabic']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(rootBundle.load('assets/fonts/$family-$weight.ttf'));
      }
      await loader.load();
    }
  });

  final pages = <String, Widget Function()>{
    'welcome': () => AccountWelcomePage(
        onLogIn: () {}, onCreateAccount: () {}, onContinueAsGuest: () async {}),
    'profiles': () => ProfilePickerPage(profiles: const [
          ProfileSummary(
              id: 'family', name: 'العائلة Family 2026', hasPin: true),
          ProfileSummary(id: 'me', name: 'Layla'),
        ], onSelect: (_, __) async {}, onManage: () {}),
    'profile-editor': () => ProfileEditorPage(onSave: (_) async {}),
    'settings': () => const Scaffold(body: SettingsPage()),
    'appearance': () =>
        const SettingsPersonalizationPage(section: 'appearance'),
    'language': () => const SettingsPersonalizationPage(section: 'language'),
    'cards': () => const CardCustomizationPage(),
    'display': () => const SettingsDisplayPage(),
    'statistics': () => const StatsPage(),
    'downloads': _downloads,
    'search': () => const Scaffold(body: SearchSheet()),
    'playback': () => const SettingsPreferencesPage(subtitles: false),
    'subtitles': () => const SettingsPreferencesPage(subtitles: true),
    'privacy': () => const SettingsDataPage(section: 'privacy'),
    'catalog-settings': () => const CatalogSettingsPage(),
    'navigation': () => const NavigationBarStylePage(),
    'icons': () => AppIconSettingsPage(controller: _FixtureIcons()),
    'notifications': () =>
        const SettingsPersonalizationPage(section: 'notifications'),
  };

  for (final english in [true, false]) {
    for (final brightness in Brightness.values) {
      for (final wide in [false, true]) {
        final size = wide ? const Size(1024, 768) : const Size(390, 844);
        for (final entry in pages.entries) {
          testWidgets(
              '${entry.key} ${english ? 'en' : 'ar'} ${brightness.name} ${wide ? 'tablet' : 'phone'}',
              (tester) async {
            await _exercise(tester,
                name: entry.key,
                page: entry.value(),
                size: size,
                english: english,
                brightness: brightness);
          });
        }
      }
    }
  }

  for (final english in [true, false]) {
    testWidgets('search keyboard short viewport 200% ${english ? 'en' : 'ar'}',
        (tester) async {
      await _exercise(tester,
          name: 'search-keyboard-200',
          page: const Scaffold(body: SearchSheet()),
          size: const Size(320, 480),
          english: english,
          brightness: Brightness.dark,
          scale: 2,
          keyboard: 180);
    });
    testWidgets('welcome narrow 200% ${english ? 'en' : 'ar'}', (tester) async {
      await _exercise(tester,
          name: 'welcome-200',
          page: pages['welcome']!(),
          size: const Size(320, 640),
          english: english,
          brightness: Brightness.light,
          scale: 2);
    });
    testWidgets('card customization narrow 200% ${english ? 'en' : 'ar'}',
        (tester) async {
      await _exercise(tester,
          name: 'cards-200',
          page: const CardCustomizationPage(),
          size: const Size(320, 640),
          english: english,
          brightness: Brightness.light,
          scale: 2);
    });
    testWidgets('privacy descriptions 200% ${english ? 'en' : 'ar'}',
        (tester) async {
      await _exercise(tester,
          name: 'privacy-200',
          page: const SettingsDataPage(section: 'privacy'),
          size: const Size(320, 640),
          english: english,
          brightness: Brightness.light,
          scale: 2);
    });
    testWidgets(
        'M3 dock preserves direction and touch targets ${english ? 'en' : 'ar'}',
        (tester) async {
      String? chosen;
      final tabs = noorDockTabsFor(rtl: !english);
      await tester.pumpWidget(MaterialApp(
          theme: NovaTheme.light,
          home: Directionality(
              textDirection: english ? TextDirection.ltr : TextDirection.rtl,
              child: Scaffold(
                  body: Align(
                      alignment: Alignment.bottomCenter,
                      child: MaterialFloatingDock(
                          tabs: tabs,
                          activeId: 'home',
                          arabic: !english,
                          onTabSelected: (tab) => chosen = tab.id))))));
      final destinations = find.byType(NavigationDestination);
      expect(destinations, findsNWidgets(5));
      final home = tester.getCenter(destinations.first);
      final settings = tester.getCenter(destinations.last);
      expect(home.dx < settings.dx, english);
      await tester.tap(destinations.at(1));
      await tester.pumpAndSettle();
      expect(chosen, tabs[1].id);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _exercise(WidgetTester tester,
    {required String name,
    required Widget page,
    required Size size,
    required bool english,
    required Brightness brightness,
    double scale = 1,
    double keyboard = 0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = NoorApi();
  final app = AppState(api, CatalogRepository(api))..english = english;
  app.webSettings['tmdbEnabled'] = false;
  app.webSettings['heroTrailerAutoplay'] = 'never';
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: Provider<AccountController?>.value(
          value: null,
          child: MaterialApp(
              theme: NovaTheme.build(brightness, arabic: !english),
              locale: Locale(english ? 'en' : 'ar'),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                NovaStrings.delegate,
                ...GlobalMaterialLocalizations.delegates
              ],
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                      viewInsets: EdgeInsets.only(bottom: keyboard)),
                  child: RepaintBoundary(key: _capture, child: child)),
              home: page))));
  await tester.pump(const Duration(milliseconds: 100));
  expect(tester.takeException(), isNull);
  if (name == 'search-keyboard-200') {
    expect(tester.getRect(find.byType(TextField)).bottom,
        lessThanOrEqualTo(size.height - keyboard));
  }
  if (_write) {
    await tester.runAsync(() async {
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(_capture));
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File(
          'build/nova-review/redesign/$name-${size.width.toInt()}-${english ? 'en' : 'ar'}-${brightness.name}.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });
  }
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  app.dispose();
  api.dispose();
}
