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
import 'package:nova_mobile/features/home/widgets/async_media_section.dart';
import 'package:nova_mobile/features/home/widgets/continue_watching_rail.dart';

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

class _CountingCatalogs extends CatalogRepository {
  _CountingCatalogs(super.api);

  int topTenRequests = 0;
  int catalogRequests = 0;
  int animeRequests = 0;
  final List<String> recommendationSeeds = [];

  @override
  Future<List<MediaItem>> catalog(
    String type,
    String id, {
    Map<String, dynamic> extras = const {},
    Addon? addon,
  }) async {
    catalogRequests++;
    return const [_quickFilm, _lateFilm];
  }

  @override
  Future<List<MediaItem>> homeTopTen() async {
    topTenRequests++;
    return const [_quickFilm, _lateFilm];
  }

  @override
  Future<List<MediaItem>> anime() async {
    animeRequests++;
    return const [];
  }

  @override
  Future<List<MediaItem>> tmdbRecommendations(
    MediaItem seed, {
    String language = 'en-US',
    String region = 'US',
  }) async {
    recommendationSeeds.add('${seed.type}:${seed.id}');
    return const [];
  }
}

Future<void> _pumpHome(WidgetTester tester, AppState app) async {
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
    value: app,
    child: const MaterialApp(home: Scaffold(body: HomePage(active: false))),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('playback saves update Continue Watching without reloading Home',
      (tester) async {
    final api = NoorApi();
    final catalog = _CountingCatalogs(api);
    final app = AppState(api, catalog)
      ..english = true
      ..webSettings['homeMode'] = 'classic'
      ..webSettings['cloudSyncEnabled'] = false
      ..history = const [
        WatchHistoryEntry(
          item: _quickFilm,
          watchedAt: 1,
          positionMs: 30000,
          durationMs: 600000,
        ),
      ];
    addTearDown(app.dispose);
    addTearDown(api.dispose);
    await _pumpHome(tester, app);
    final requests = (
      catalog.topTenRequests,
      catalog.catalogRequests,
      catalog.animeRequests,
      catalog.recommendationSeeds.length,
    );

    for (final position in [35000, 40000, 45000]) {
      await app.recordPlayback(_quickFilm,
          positionMs: position, durationMs: 600000);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(
        (
          catalog.topTenRequests,
          catalog.catalogRequests,
          catalog.animeRequests,
          catalog.recommendationSeeds.length,
        ),
        requests,
      );
      final rail = tester
          .widget<ContinueWatchingRail>(find.byType(ContinueWatchingRail));
      expect(rail.entries.single.positionMs, position);
    }
    expect(catalog.recommendationSeeds, ['movie:quick']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Home reloads for completion filtering and a new seed',
      (tester) async {
    final api = NoorApi();
    final catalog = _CountingCatalogs(api);
    final app = AppState(api, catalog)
      ..english = true
      ..webSettings['homeMode'] = 'classic'
      ..webSettings['cloudSyncEnabled'] = false
      ..webSettings['hideWatchedInCatalogs'] = true
      ..history = const [
        WatchHistoryEntry(
          item: _quickFilm,
          watchedAt: 1,
          positionMs: 475000,
          durationMs: 600000,
        ),
      ];
    addTearDown(app.dispose);
    addTearDown(api.dispose);
    await _pumpHome(tester, app);
    final initial = catalog.topTenRequests;

    await app.recordPlayback(_quickFilm,
        positionMs: 480000, durationMs: 600000);
    await tester.pump();
    await tester.pump();
    expect(catalog.topTenRequests, initial + 1);
    final topTen = tester
        .widgetList<AsyncMediaSection>(find.byType(AsyncMediaSection))
        .firstWhere((section) => section.numbered);
    expect((await topTen.future).map((item) => item.id), ['late']);

    await app.recordPlayback(_quickFilm,
        positionMs: 485000, durationMs: 600000);
    await tester.pump();
    expect(catalog.topTenRequests, initial + 1);

    await app.recordPlayback(_lateFilm, positionMs: 30000, durationMs: 600000);
    await tester.pump();
    await tester.pump();
    expect(catalog.topTenRequests, initial + 2);
    expect(catalog.recommendationSeeds.last, 'movie:late');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

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
