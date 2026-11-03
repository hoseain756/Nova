import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MDBList device link persists account tokens and reads tracked data',
      () async {
    SharedPreferences.setMockInitialValues({});
    final secure = <String, String>{};
    const storage =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      if (call.method == 'read') return secure[key];
      if (call.method == 'write') secure[key] = args['value'] as String;
      if (call.method == 'delete') secure.remove(key);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null));

    final paths = <String>[];
    final writes = <String, dynamic>{};
    var watchedActivity = '2026-11-03T00:00:00Z';
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      paths.add(options.uri.path);
      if (options.method == 'POST') writes[options.uri.path] = options.data;
      final data = switch (options.uri.path) {
        '/oauth/device-authorization/' => {
            'device_code': 'device',
            'user_code': 'ABCD',
            'verification_uri_complete':
                'https://mdblist.com/oauth/device/?user_code=ABCD',
            'expires_in': 300,
            'interval': 5,
          },
        '/oauth/token/' => {
            'access_token': 'access',
            'refresh_token': 'refresh',
            'token_type': 'Bearer',
            'scope': 'write',
            'expires_in': 2592000,
          },
        '/sync/last_activities' => {
            'server_time': '2026-11-03T00:00:00Z',
            'watched_at': watchedActivity,
          },
        '/watchlist/items' => {
            'items': [
              {
                'mediatype': 'movie',
                'title': 'Planned film',
                'ids': {'imdb': 'tt1234567'}
              }
            ]
          },
        '/sync/watched' when options.method == 'POST' => {
            'updated': {'episodes': 1}
          },
        '/sync/watched' => {
            'movies': [
              {
                'last_watched_at': '2026-11-02T00:00:00Z',
                'movie': {
                  'title': 'Watched film',
                  'ids': {'imdb': 'tt2345678'}
                }
              }
            ],
            'shows': [
              {
                'show': {
                  'title': 'Watched show',
                  'ids': {'imdb': 'tt3456789'}
                },
                'seasons': [
                  {
                    'number': 1,
                    'episodes': [
                      {'number': 2, 'last_watched_at': '2026-11-02T00:00:00Z'}
                    ]
                  }
                ]
              }
            ]
          },
        '/sync/playback' => [
            {
              'type': 'movie',
              'progress': 40,
              'paused_at': '2026-11-03T00:00:00Z',
              'movie': {
                'title': 'Paused film',
                'ids': {'imdb': 'tt4567890'}
              }
            }
          ],
        '/watchlist/items/add' => {'added': 1},
        '/scrobble/start' => {'action': 'start'},
        _ => <String, dynamic>{},
      };
      handler.resolve(Response<dynamic>(requestOptions: options, data: data));
    }));

    final api = NoorApi(dio: dio);
    await api.activateAccount('account');
    final start = await api.startLinkedService('mdblist');
    expect(start?['user_code'], 'ABCD');
    expect(
        await api.pollLinkedService('mdblist', start!), {'status': 'success'});
    expect(api.isLinked('mdblist'), true);
    expect(secure['nova.account.account.noor.mdblist.refresh'], 'refresh');
    expect((await api.syncLinkedService('mdblist', 'watchlist')).single['imdb'],
        'tt1234567');
    final history = await api.syncLinkedService('mdblist', 'history');
    expect(history, hasLength(2));
    expect(history.last['season'], 1);
    expect(history.last['episode'], 2);
    expect(await api.mdbListPlayback(), hasLength(1));
    expect(
        await api.pushMdbListWatchlist(
            type: 'movie', imdb: 'tt1234567', add: true),
        true);
    await api.scrobbleLinkedService('mdblist',
        action: 'start',
        type: 'movie',
        title: 'Film',
        imdb: 'tt1234567',
        progress: 34);
    expect((writes['/scrobble/start'] as Map)['movie']['ids']['imdb'],
        'tt1234567');
    await api.pushLinkedEpisodeHistory('mdblist', imdb: 'tt3456789', episodes: [
      {'season': 1, 'episode': 2}
    ]);
    expect(
        (writes['/sync/watched'] as Map)['shows'][0]['seasons'][0]['episodes']
            [0]['number'],
        2);

    final fresh = NoorApi(dio: dio);
    await fresh.activateAccount('account');
    expect(fresh.isLinked('mdblist'), true);
    paths.clear();
    expect(await fresh.syncLinkedService('mdblist', 'history'), hasLength(2));
    expect(paths, ['/sync/last_activities']);

    watchedActivity = '2026-11-03T01:00:00Z';
    final changed = NoorApi(dio: dio);
    await changed.activateAccount('account');
    paths.clear();
    expect(await changed.syncLinkedService('mdblist', 'history'), hasLength(2));
    expect(paths, ['/sync/last_activities', '/sync/watched']);
  });
}
