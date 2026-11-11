import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/addon.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/features/media/media_playback_launcher.dart';
import 'package:nova_mobile/features/player/playback_entry_page.dart';

const _item = MediaItem(id: 'anime:exact', type: 'anime', name: 'Exact title');
const _source = <String, dynamic>{
  'title': 'Exact source',
  'url': 'https://example.com/video.mkv|User-Agent=Nova',
  'behaviorHints': {
    'filename': 'episode.mkv',
    'proxyHeaders': {
      'request': {'Referer': 'https://example.com/'},
      'response': {'Cache-Control': 'private'},
    },
  },
};

class _Catalogs extends CatalogRepository {
  _Catalogs(super.api);
  final requests = <(String, String)>[];

  @override
  Future<List<Map<String, dynamic>>> streams(
      String type, String id, List<Addon> addons,
      {bool reportFailures = false}) async {
    requests.add((type, id));
    return [_source];
  }
}

void main() {
  late AppState app;
  late _Catalogs catalogs;

  setUp(() {
    final api = NoorApi();
    catalogs = _Catalogs(api);
    app = AppState(api, catalogs);
    app.webSettings['p2pEnabled'] = false;
  });
  tearDown(() => app.dispose());

  Widget harness(Future<void> Function(BuildContext) launch) =>
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(launch(context)),
                child: const Text('Launch'),
              ),
            ),
          ),
        ),
      );

  testWidgets('source picker and player retain exact room video and headers',
      (tester) async {
    PlaybackEntryPage? launched;
    final loading = <bool>[];
    await tester.pumpWidget(harness((context) => launchMediaPlayback(
          context,
          item: _item,
          video: const {'id': 'episode:custom:42', 'season': 3, 'episode': 7},
          resumePositionMs: 456789,
          onLoadingChanged: loading.add,
          playerLauncher: (page) async => launched = page,
        )));
    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();
    expect(catalogs.requests, [('anime', 'episode:custom:42')]);
    expect(find.text('Exact source'), findsOneWidget);
    await tester.tap(find.text('Exact source'));
    await tester.pumpAndSettle();

    expect(launched?.item, same(_item));
    expect(launched?.videoId, 'episode:custom:42');
    expect(launched?.season, 3);
    expect(launched?.episode, 7);
    expect(launched?.initialPositionMs, 456789);
    expect(launched?.url, 'https://example.com/video.mkv');
    expect(launched?.headers,
        {'User-Agent': 'Nova', 'Referer': 'https://example.com/'});
    expect(launched?.filename, 'episode.mkv');
    expect(launched?.streams, [_source]);
    expect(loading, [true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing the room while choosing a source cancels launch',
      (tester) async {
    final selection = Completer<Map<String, dynamic>?>();
    var current = true;
    var launches = 0;
    final loading = <bool>[];
    await tester.pumpWidget(harness((context) => launchMediaPlayback(
          context,
          item: _item,
          video: const {'id': 'episode:custom:42', 'season': 3, 'episode': 7},
          canLaunch: () => current,
          onLoadingChanged: loading.add,
          sourcePicker: (_) => selection.future,
          playerLauncher: (_) async => launches++,
        )));
    await tester.tap(find.text('Launch'));
    current = false;
    selection.complete(_source);
    await tester.pump();
    expect(launches, 0);
    expect(loading, isEmpty);
  });

  testWidgets('rechecks validity immediately before the player push',
      (tester) async {
    var current = true;
    var launches = 0;
    final loading = <bool>[];
    await tester.pumpWidget(harness((context) => launchMediaPlayback(
          context,
          item: _item,
          video: null,
          canLaunch: () => current,
          sourcePicker: (_) async => _source,
          onLoadingChanged: (value) {
            loading.add(value);
            if (!value) current = false;
          },
          playerLauncher: (_) async => launches++,
        )));
    await tester.tap(find.text('Launch'));
    await tester.pump();
    expect(launches, 0);
    expect(loading, [true, false]);
  });

  testWidgets('unmounted caller cannot launch a completed source choice',
      (tester) async {
    final selection = Completer<Map<String, dynamic>?>();
    var launches = 0;
    await tester.pumpWidget(harness((context) => launchMediaPlayback(
          context,
          item: _item,
          video: null,
          sourcePicker: (_) => selection.future,
          playerLauncher: (_) async => launches++,
        )));
    await tester.tap(find.text('Launch'));
    await tester.pumpWidget(const SizedBox());
    selection.complete(_source);
    await tester.pump();
    expect(launches, 0);
    expect(tester.takeException(), isNull);
  });
}
