import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/settings/settings_data_page.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';

class _StorageApp extends AppState {
  _StorageApp(NoorApi api) : super(api, CatalogRepository(api));

  @override
  Future<void> setSetting(String key, dynamic value) async {
    webSettings = {...webSettings, key: value};
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (_) async {
      throw PlatformException(code: 'unavailable');
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
  });
  for (final english in [true, false]) {
    for (final brightness in Brightness.values) {
      testWidgets('cache options remain reachable at 200% $english $brightness',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = _StorageApp(NoorApi())..english = english;
        addTearDown(app.dispose);
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: app,
          child: MaterialApp(
            theme: NovaTheme.build(brightness, arabic: !english),
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
            home: const SettingsDataPage(section: 'storage'),
          ),
        ));
        await tester.pumpAndSettle();
        final title = find.text(NovaStrings.lookup(english, 'message400'));
        await tester.scrollUntilVisible(title, 250);
        await tester.pumpAndSettle();
        final interval = NovaStrings.lookup(english, 'cacheEvery12Hours');
        expect(
          find.text(NovaStrings.lookup(
              english, 'message399', {'p0': interval.toLowerCase()})),
          findsOneWidget,
        );
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final choice =
            find.text(NovaStrings.lookup(english, 'cacheEvery48Hours'));
        final scrollable = find.descendant(
            of: find.byType(BottomSheet), matching: find.byType(Scrollable));
        await tester.scrollUntilVisible(choice, 220,
            scrollable: scrollable.first);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(app.webSettings['cacheResetHours'], 48);
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
