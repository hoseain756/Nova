import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/shared_collections/shared_collection_detail_page.dart';
import 'package:nova_mobile/features/shared_collections/shared_collections_panel.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';

void main() {
  test('invite parser accepts only a collection invite token or app link', () {
    final token = List.filled(64, 'a').join();
    expect(sharedCollectionInviteToken(token), token);
    expect(
      sharedCollectionInviteToken(
          'app.nova.mobile://collection-invite?token=$token'),
      token,
    );
    expect(sharedCollectionInviteToken('https://example.com/?token=$token'),
        isNull);
    expect(
        sharedCollectionInviteToken('app.nova.mobile://callback?token=$token'),
        isNull);
    expect(
        sharedCollectionInviteToken(
            'app.nova.mobile://collection-invite/extra?token=$token'),
        isNull);
    expect(
        sharedCollectionInviteToken(
            'app.nova.mobile://collection-invite?token=$token&token=$token'),
        isNull);
  });

  for (final language in ['en', 'ar']) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('$language $brightness collection forms fit a narrow phone',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final locale = Locale(language);
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          localizationsDelegates: const [
            NovaStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: Builder(builder: (context) {
              return Column(children: [
                TextButton(
                  onPressed: () => showSharedCollectionForm(context),
                  child: const Text('collection form'),
                ),
                TextButton(
                  onPressed: () => showSharedCollectionItemForm(context),
                  child: const Text('item form'),
                ),
              ]);
            }),
          ),
        ));

        await tester.tap(find.text('collection form'));
        await tester.pumpAndSettle();
        expect(
            find.text(NovaStrings(locale).text('sharedName')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(NovaStrings(locale).text('cancel')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('item form'));
        await tester.pumpAndSettle();
        expect(find.text(NovaStrings(locale).text('sharedItemType')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
