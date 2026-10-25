import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/settings/settings_preferences_page.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:provider/provider.dart';

void main() {
  for (final english in [true, false]) {
    for (final light in [true, false]) {
      testWidgets(
        'iPhone subtitle font picker fits ${english ? 'English' : 'Arabic'} '
        '${light ? 'light' : 'dark'} at normal text size',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final api = NoorApi();
          final app = AppState(api, CatalogRepository(api))..english = english;
          await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
            value: app,
            child: MaterialApp(
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
              home: const SettingsPreferencesPage(subtitles: true),
            ),
          ));
          final fontTitle = find.text(english ? 'Subtitle font' : 'خط الترجمة');
          await tester.scrollUntilVisible(fontTitle, 250,
              scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          await tester.tap(fontTitle);
          await tester.pumpAndSettle();
          expect(
              find.text(
                  english ? 'Add font from device' : 'إضافة خط من الجهاز'),
              findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
}
