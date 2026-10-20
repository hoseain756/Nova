import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/widgets/player_side_panel.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
        'subtitle settings shortcut is localized for ${locale.languageCode}',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            NovaStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: PanelSettingsButton(onTap: () => taps++),
          ),
        ),
      );

      final expected = NovaStrings(locale).text('subtitleStyleAndTiming');
      final shortcut = find.bySemanticsLabel(expected);
      expect(shortcut, findsOneWidget);
      expect(
        Directionality.of(tester.element(shortcut)),
        locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      await tester.tap(shortcut);
      expect(taps, 1);
      semantics.dispose();
    });
  }
}
