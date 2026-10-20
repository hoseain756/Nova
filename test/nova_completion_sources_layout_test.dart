import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/media/sources_page.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:provider/provider.dart';

const _item = MediaItem(
  id: 'tt-layout',
  type: 'movie',
  name: 'Layout movie',
);

const _stream = <String, dynamic>{
  'title': '2160p HDR source with a deliberately long descriptive title',
  'description': 'H264 · 4 GB',
  'url': 'https://example.com/layout.mkv',
  'addonName': 'Layout provider',
};

void main() {
  for (final english in [true, false]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'source layout preference changes geometry but not selection '
          '${english ? 'English' : 'Arabic'} $brightness', (tester) async {
        Future<(double, Map<String, dynamic>?)> render(String layout) async {
          final api = NoorApi();
          final app = AppState(api, CatalogRepository(api))
            ..english = english
            ..webSettings = {
              ...AppState.defaultSettings,
              'pickerLayout': layout,
            };
          Map<String, dynamic>? picked;

          await tester.pumpWidget(
            ChangeNotifierProvider<AppState>.value(
              value: app,
              child: MaterialApp(
                theme: brightness == Brightness.light
                    ? NovaTheme.light
                    : NovaTheme.dark,
                locale: Locale(english ? 'en' : 'ar'),
                supportedLocales: const [Locale('en'), Locale('ar')],
                localizationsDelegates: const [
                  NovaStrings.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                home: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      picked = await Navigator.of(context)
                          .push<Map<String, dynamic>>(
                        MaterialPageRoute(
                          builder: (_) => const SourcesPage(
                            item: _item,
                            video: null,
                            streams: [_stream],
                            english: true,
                          ),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          expect(
              Directionality.of(tester.element(find.text('Layout provider'))),
              english ? TextDirection.ltr : TextDirection.rtl);
          expect(find.text('4 GB'), findsOneWidget);

          final row = find
              .ancestor(
                of: find.text('Layout provider'),
                matching: find.byType(InkWell),
              )
              .first;
          final height = tester.getSize(row).height;

          await tester.tap(find.textContaining('2160p HDR source'));
          await tester.pumpAndSettle();
          expect(picked?['url'], _stream['url']);

          await tester.pumpWidget(const SizedBox.shrink());
          app.dispose();
          return (height, picked);
        }

        final standard = await render('stremio');
        final condensed = await render('condensed');

        expect(condensed.$1, lessThan(standard.$1));
        expect(condensed.$2, equals(standard.$2));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final english in [true, false]) {
    testWidgets(
        'condensed source remains scrollable and tappable at 320x640 200% '
        '${english ? 'English' : 'Arabic'}', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = NoorApi();
      final app = AppState(api, CatalogRepository(api))
        ..english = english
        ..webSettings = {
          ...AppState.defaultSettings,
          'pickerLayout': 'condensed',
        };
      addTearDown(app.dispose);
      Map<String, dynamic>? picked;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: app,
          child: MaterialApp(
            theme: NovaTheme.dark,
            locale: Locale(english ? 'en' : 'ar'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              NovaStrings.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  picked =
                      await Navigator.of(context).push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => const SourcesPage(
                        item: _item,
                        video: null,
                        streams: [_stream],
                        english: true,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final title = find.textContaining('2160p HDR source');
      final sourceList = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(title, 120, scrollable: sourceList);
      await tester.drag(sourceList, const Offset(0, -120));
      await tester.pumpAndSettle();
      final titleWidget = tester.widget<Text>(title);
      expect(titleWidget.maxLines, 2);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(picked?['url'], _stream['url']);
      expect(tester.takeException(), isNull);
    });
  }
}
