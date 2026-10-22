import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/anime/anime_page.dart';
import 'package:nova_mobile/features/shell/nova_browse_widgets.dart';

class _DeferredAnimeCatalog extends CatalogRepository {
  _DeferredAnimeCatalog(super.api);

  final Completer<List<MediaItem>> result = Completer<List<MediaItem>>();

  @override
  Future<List<MediaItem>> anime() => result.future;
}

void main() {
  for (final theme in [NovaTheme.dark, NovaTheme.light]) {
    testWidgets(
      'anime canvas stays on the ${theme.brightness.name} theme surface while catalog loads',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(400, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final api = NoorApi();
        final catalog = _DeferredAnimeCatalog(api);
        final app = AppState(api, catalog);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: app,
            child: MaterialApp(
              theme: theme,
              home: const Scaffold(body: AnimePage()),
            ),
          ),
        );

        ColoredBox canvas() => tester.widget<ColoredBox>(
              find.byKey(const ValueKey('anime-catalog-canvas')),
            );

        expect(canvas().color, theme.scaffoldBackgroundColor);
        catalog.result.complete(const [
          MediaItem(id: 'anime:1', type: 'series', name: 'NOVA Test Anime'),
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(canvas().color, theme.scaffoldBackgroundColor);
        expect(find.text('NOVA Test Anime'), findsOneWidget);
        expect(find.byType(NovaBrowseFeature), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
