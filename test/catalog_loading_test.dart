import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/data/catalog_response_cache.dart';
import 'package:nova_mobile/core/models/addon.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/features/catalog/catalog_browser_page.dart';
import 'package:nova_mobile/features/home/home_page.dart';

const _quickFilm = MediaItem(id: 'quick', type: 'movie', name: 'Quick Film');
const _lateFilm = MediaItem(id: 'late', type: 'movie', name: 'Late Film');

class _DeferredCatalogs extends CatalogRepository {
  _DeferredCatalogs(super.api);

  final addonResult = Completer<List<MediaItem>>();
  int addonRequests = 0;

  @override
  Future<List<MediaItem>> catalog(
    String type,
    String id, {
    Map<String, dynamic> extras = const {},
    Addon? addon,
  }) {
    if (addon != null) {
      addonRequests++;
      return addonResult.future;
    }
    return Future.value(const [_quickFilm]);
  }

  @override
  Future<List<MediaItem>> homeTopTen() async => const [_quickFilm];

  @override
  Future<List<MediaItem>> anime() async => const [_quickFilm];

  @override
  Future<List<MediaItem>> addonCatalogs(List<Addon> addons,
          {bool showAll = false}) =>
      addonResult.future;
}

void main() {
  test('catalog queue caps concurrent work and releases a failed slot',
      () async {
    final queue = CatalogLoadQueue(maxConcurrent: 2);
    final gates = List.generate(4, (_) => Completer<int>());
    var started = 0;
    final results = [
      for (final gate in gates)
        queue.run(() {
          started++;
          return gate.future;
        }),
    ];

    expect(started, 2);
    final failedResult = expectLater(results[1], throwsStateError);
    gates[0].complete(10);
    expect(await results[0], 10);
    expect(started, 3);

    gates[1].completeError(StateError('provider unavailable'));
    await failedResult;
    expect(started, 4);

    gates[2].complete(30);
    gates[3].complete(40);
    expect(await Future.wait(results.skip(2)), [30, 40]);
  });

  testWidgets('Discover publishes fast catalog before a slow add-on',
      (tester) async {
    final api = NoorApi();
    final catalog = _DeferredCatalogs(api);
    final app = AppState(api, catalog)..english = true;
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: const MaterialApp(home: CatalogBrowserPage()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Quick Film'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    catalog.addonResult.complete(const [_lateFilm]);
    await tester.pumpAndSettle();
    expect(find.text('Late Film'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    api.dispose();
  });

  testWidgets('Home defers add-on requests until their rows are near view',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = NoorApi();
    final catalog = _DeferredCatalogs(api);
    final app = AppState(api, catalog)
      ..english = true
      ..webSettings['tmdbEnabled'] = false
      ..addons = [
        Addon(
          id: 'test-addon',
          name: 'Test Add-on',
          transportUrl: 'https://example.test/manifest.json',
          manifest: {
            'catalogs': [
              for (var index = 1; index <= 8; index++)
                {
                  'id': 'extra-$index',
                  'type': 'movie',
                  'name': 'Extra Films $index',
                },
            ],
          },
        ),
      ];
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: const MaterialApp(home: Scaffold(body: HomePage(active: false))),
    ));
    await tester.pump();
    await tester.pump();
    // Flutter may build the first child to estimate the sliver, but it should
    // not start the other offscreen catalog requests at page entry.
    final initialRequests = catalog.addonRequests;
    expect(initialRequests, lessThan(8));

    await tester.scrollUntilVisible(
      find.text('Extra Films 8'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(catalog.addonRequests, greaterThan(initialRequests));

    catalog.addonResult.complete(const [_lateFilm]);
    await tester.pump();
    api.dispose();
  });
}
