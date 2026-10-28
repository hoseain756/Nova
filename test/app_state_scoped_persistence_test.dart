import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LocalNoorApi extends NoorApi {
  @override
  Future<void> initialize() async {}

  @override
  Future<List<dynamic>> loadIptvPlaylists() async => const [];

  @override
  bool isLinked(String service) => false;

  @override
  Future<bool> hasPendingTraktLink() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  const prefix = 'flutter.';
  const collectionKeys = {
    'horse.mobile.addons',
    'horse.mobile.lists',
    'horse.mobile.watchlist',
    'horse.mobile.history',
    'horse.mobile.cw',
  };
  late Map<String, Object> stored;
  late List<String> writes;

  setUp(() {
    SharedPreferences.resetStatic();
    stored = {
      '$prefix${AppState.settingsStorageKey}':
          jsonEncode({'cloudSyncEnabled': false, 'uiLanguage': 'en'}),
      '${prefix}horse.mobile.english': true,
      '${prefix}horse.mobile.addons': jsonEncode([
        {
          'transportUrl': 'https://example.invalid/manifest.json',
          'manifest': {'id': 'saved-addon', 'name': 'Saved addon'},
        },
      ]),
      '${prefix}horse.mobile.lists': jsonEncode([
        {
          'id': 'saved-list',
          'name': 'Saved list',
          'items': <dynamic>[],
          'createdAt': 1,
          'updatedAt': 1,
        },
      ]),
      '${prefix}horse.mobile.watchlist': jsonEncode([
        {'id': 'saved-movie', 'name': 'Saved movie', 'type': 'movie'},
      ]),
    };
    writes = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll' || call.method == 'getAllWithParameters') {
        return Map<String, Object>.from(stored);
      }
      final arguments = Map<String, dynamic>.from(call.arguments as Map);
      final key = arguments['key'] as String;
      if (call.method.startsWith('set')) {
        stored[key] = arguments['value'] as Object;
        writes.add(key.substring(prefix.length));
        return true;
      }
      if (call.method == 'remove') {
        stored.remove(key);
        return true;
      }
      throw UnsupportedError('Unexpected preference method ${call.method}');
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
  });

  Future<AppState> loadState() async {
    final api = _LocalNoorApi();
    final app = AppState(api, CatalogRepository(api));
    addTearDown(app.dispose);
    await app.initialize();
    return app;
  }

  test('playback persists only history and CW and survives a fresh load',
      () async {
    final app = await loadState();
    // initialize() uses the full persistence path, including empty history/CW.
    expect(writes.where(collectionKeys.contains).toSet(), collectionKeys);
    final unrelated = {
      for (final key in collectionKeys.where(
        (key) => key != 'horse.mobile.history' && key != 'horse.mobile.cw',
      ))
        key: stored['$prefix$key'],
    };
    writes.clear();
    final movie = MediaItem(id: 'movie-1', type: 'movie', name: 'Movie');

    await app.recordPlayback(movie,
        positionMs: 120000, durationMs: 3600000, videoId: 'stream-1');
    await app.recordPlayback(movie,
        positionMs: 125000, durationMs: 3600000, videoId: 'stream-1');

    expect(writes, [
      'horse.mobile.history',
      'horse.mobile.cw',
      'horse.mobile.history',
      'horse.mobile.cw',
    ]);
    for (final entry in unrelated.entries) {
      expect(stored['$prefix${entry.key}'], entry.value);
    }
    final savedHistory =
        jsonDecode(stored['${prefix}horse.mobile.history']! as String) as List;
    final savedCw =
        jsonDecode(stored['${prefix}horse.mobile.cw']! as String) as Map;
    expect((savedHistory.single as Map)['positionMs'], 125000);
    expect((savedCw['movie-1'] as Map)['positionMs'], 125000);

    // Discard the plugin's memory cache, then reconstruct from backend bytes.
    SharedPreferences.resetStatic();
    final fresh = await loadState();
    expect(fresh.continueWatching.single.positionMs, 125000);
    expect(fresh.history.single.videoId, 'stream-1');
    expect(fresh.addons.single.id, 'saved-addon');
    expect(fresh.customLists.single.id, 'saved-list');
    expect(fresh.watchlist.single.id, 'saved-movie');
  });

  test('watchlist and list changes persist only their declared collection',
      () async {
    final app = await loadState();
    final historyBefore = stored['${prefix}horse.mobile.history'];
    final cwBefore = stored['${prefix}horse.mobile.cw'];
    writes.clear();

    final movie = MediaItem(id: 'movie-2', type: 'movie', name: 'Other movie');
    await app.toggleWatchlist(movie);
    expect(writes, ['horse.mobile.watchlist']);
    writes.clear();

    await app.createCustomList('New list');
    expect(writes, ['horse.mobile.lists']);
    expect(stored['${prefix}horse.mobile.history'], historyBefore);
    expect(stored['${prefix}horse.mobile.cw'], cwBefore);

    SharedPreferences.resetStatic();
    final fresh = await loadState();
    expect(fresh.watchlist.map((item) => item.id), contains('movie-2'));
    expect(fresh.customLists.map((list) => list.name), contains('New list'));
  });
}
