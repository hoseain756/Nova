import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/letterboxd/letterboxd_settings.dart';
import 'package:nova_mobile/core/letterboxd/stremboxd_client.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/settings/letterboxd_settings_page.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:provider/provider.dart';

class _LetterboxdTestApp extends AppState {
  _LetterboxdTestApp(NoorApi api) : super(api, CatalogRepository(api)) {
    english = true;
  }

  LetterboxdSession? session;
  int publicConnections = 0;
  int fullConnections = 0;
  String? lastPassword;
  bool requestTotp = false;

  @override
  LetterboxdSession? get letterboxdSession => session;

  @override
  Future<void> setSetting(String key, dynamic value) async {
    webSettings = {...webSettings, key: value};
    notifyListeners();
  }

  @override
  Future<void> updateLetterboxdSettings(LetterboxdSettings settings) =>
      setSetting('letterboxd', settings.toJson());

  @override
  Future<int> connectLetterboxdPublic(String username) async {
    publicConnections++;
    await updateLetterboxdSettings(letterboxdSettings.copyWith(
      enabled: true,
      mode: LetterboxdSettings.publicMode,
      username: username,
    ));
    return 4;
  }

  @override
  Future<LetterboxdSession> connectLetterboxdFull(
    String username,
    String password, {
    String? totp,
  }) async {
    fullConnections++;
    lastPassword = password;
    if (requestTotp && totp != '123456') {
      throw const StremboxdException('2FA required', code: '2FA_REQUIRED');
    }
    session = LetterboxdSession(
      userToken: 'test-token',
      userId: 'user-1',
      username: username,
      loginAt: DateTime.utc(2026, 11, 4),
    );
    await updateLetterboxdSettings(letterboxdSettings.copyWith(
      enabled: true,
      mode: LetterboxdSettings.fullMode,
      username: username,
    ));
    return session!;
  }

  @override
  Future<void> disconnectLetterboxd() async {
    session = null;
    await updateLetterboxdSettings(letterboxdSettings.copyWith(
      mode: LetterboxdSettings.publicMode,
    ));
  }

  @override
  Future<void> refreshLetterboxdCatalogs({bool force = false}) async {}

  @override
  Future<void> addLetterboxdList(String url) async {
    final settings = letterboxdSettings;
    await updateLetterboxdSettings(settings.copyWith(
      listRefs: [
        ...settings.listRefs,
        const LetterboxdListRef(
            id: 'list-1', name: 'My films', owner: 'tester'),
      ],
      selectedCatalogs: [
        ...settings.selectedCatalogs,
        'letterboxd-list-list-1'
      ],
    ));
  }

  @override
  Future<void> removeLetterboxdList(String id) async {
    final settings = letterboxdSettings;
    await updateLetterboxdSettings(settings.copyWith(
      listRefs: settings.listRefs.where((list) => list.id != id).toList(),
      selectedCatalogs: settings.selectedCatalogs
          .where((catalog) => catalog != 'letterboxd-list-$id')
          .toList(),
    ));
  }
}

Widget _harness(_LetterboxdTestApp app,
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
            ...GlobalMaterialLocalizations.delegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const LetterboxdSettingsPage(),
        );
      }),
    );

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 240,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('public connection stores username and shows catalog choices',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _LetterboxdTestApp(NoorApi());
    await tester.pumpWidget(_harness(app));

    await tester.tap(find.text('Enable Letterboxd'));
    await tester.pumpAndSettle();
    expect(find.text('Public'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'filmfan');
    await _scrollTo(tester, find.text('Connect'));
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(app.publicConnections, 1);
    expect(app.letterboxdSettings.username, 'filmfan');
    expect(app.letterboxdSettings.enabled, true);
    expect(find.text('Connected. 4 catalogs are available.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public catalogs can be verified without a username',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _LetterboxdTestApp(NoorApi());
    await tester.pumpWidget(_harness(app));

    await tester.tap(find.text('Enable Letterboxd'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Optional. Add your public profile handle for watchlist and liked films.'),
        findsOneWidget);
    await _scrollTo(tester, find.text('Connect'));
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(app.publicConnections, 1);
    expect(app.letterboxdSettings.username, isEmpty);
    expect(app.letterboxdSettings.enabled, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full connection clears the password after two-factor sign-in',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _LetterboxdTestApp(NoorApi())..requestTotp = true;
    await tester.pumpWidget(_harness(app));
    await tester.tap(find.text('Enable Letterboxd'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'filmfan');
    await tester.enterText(find.byType(TextField).at(1), 'private-password');
    await _scrollTo(tester, find.text('Connect'));
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Two-factor code'), findsOneWidget);

    await _scrollTo(tester, find.text('Two-factor code'));
    await tester.enterText(find.byType(TextField).at(2), '123456');
    await _scrollTo(tester, find.text('Verify and connect'));
    await tester.tap(find.text('Verify and connect'));
    await tester.pumpAndSettle();

    expect(app.fullConnections, 2);
    expect(app.letterboxdSession?.username, 'filmfan');
    expect(app.lastPassword, 'private-password');
    expect(jsonEncode(app.webSettings['letterboxd']),
        isNot(contains('private-password')));
    expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom list and Home row controls update the saved choices',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _LetterboxdTestApp(NoorApi());
    app.webSettings = {
      ...app.webSettings,
      'letterboxd':
          LetterboxdSettings.defaults.copyWith(enabled: true).toJson(),
    };
    await tester.pumpWidget(_harness(app));

    await _scrollTo(tester, find.text('Add a public list'));
    await tester.enterText(find.byType(TextField).last,
        'https://letterboxd.com/tester/list/my-films/');
    await tester.tap(find.byTooltip('Add list'));
    await tester.pumpAndSettle();
    expect(app.letterboxdSettings.listRefs.single.name, 'My films');
    expect(app.letterboxdSettings.selectedCatalogs,
        contains('letterboxd-list-list-1'));

    await _scrollTo(tester, find.text('Home rows'));
    await _scrollTo(tester, find.byTooltip('Hide row').first);
    await tester.tap(find.byTooltip('Hide row').first);
    await tester.pumpAndSettle();
    expect(app.letterboxdSettings.hiddenCatalogs,
        contains(LetterboxdSettings.watchlistCatalog));

    await _scrollTo(tester, find.byTooltip('Move row down').first);
    await tester.tap(find.byTooltip('Move row down').first);
    await tester.pumpAndSettle();
    expect(app.letterboxdSettings.catalogOrder.first,
        isNot(LetterboxdSettings.watchlistCatalog));
    expect(tester.takeException(), isNull);
  });

  for (final english in [true, false]) {
    for (final size in [const Size(360, 800), const Size(1200, 800)]) {
      testWidgets(
          'Letterboxd settings fit $size at 200% in ${english ? 'LTR' : 'RTL'}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = _LetterboxdTestApp(NoorApi())..english = english;
        app.webSettings = {
          ...app.webSettings,
          'letterboxd':
              LetterboxdSettings.defaults.copyWith(enabled: true).toJson(),
        };
        await tester.pumpWidget(_harness(app, scale: 2, light: english));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -3000));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(Directionality.of(tester.element(find.byType(Scaffold))),
            english ? TextDirection.ltr : TextDirection.rtl);
      });
    }
  }
}
