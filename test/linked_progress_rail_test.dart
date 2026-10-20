import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/integration_cw.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/home/widgets/continue_watching_rail.dart';

void main() {
  testWidgets('Home combines linked providers in one horizontal row',
      (tester) async {
    final api = NoorApi(dio: Dio());
    final app = AppState(api, CatalogRepository(api));
    addTearDown(app.dispose);
    final entries = [
      for (final source in const ['trakt', 'simkl', 'anilist', 'mal'])
        IntegrationCwEntry(
          item: MediaItem(
            id: '$source:sample',
            type: 'series',
            name: '$source sample',
          ),
          source: source,
          progress: .4,
          episodesWatched: 4,
          episodesTotal: 10,
          watchedAt: 100,
        ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          theme: NovaTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: Scaffold(
              body: ContinueWatchingRail(
                entries: const [],
                linkedEntries: entries,
                english: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final lists = tester.widgetList<ListView>(find.byType(ListView)).toList();
    expect(lists, hasLength(1));
    expect(lists.single.scrollDirection, Axis.horizontal);
    final delegate =
        lists.single.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 7); // Four cards and three separators.
    expect(tester.takeException(), isNull);
  });
}
