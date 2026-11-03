import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Simkl imports episode history once, then reads activity-gated deltas',
      () async {
    SharedPreferences.setMockInitialValues({});
    final secure = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      if (call.method == 'read') return secure[key];
      if (call.method == 'write') secure[key] = args['value'] as String;
      if (call.method == 'delete') secure.remove(key);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, null));

    var changed = false;
    final paths = <String>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      paths.add(options.uri.path);
      final data = switch (options.uri.path) {
        '/sync/activities' => {
            'all': changed ? '2026-01-02T00:00:00Z' : '2026-01-01T00:00:00Z',
            'tv_shows': {
              'watching':
                  changed ? '2026-01-02T00:00:00Z' : '2026-01-01T00:00:00Z',
            },
          },
        '/sync/all-items/shows' => {
            'shows': [
              {
                'status': 'watching',
                'last_watched_at': '2026-01-01T00:00:00Z',
                'show': {
                  'title': 'A series',
                  'ids': {'simkl': 1, 'imdb': 'tt1234567'}
                },
                'seasons': [
                  {
                    'number': 1,
                    'episodes': [
                      {'number': 1, 'watched_at': '2026-01-01T00:00:00Z'}
                    ]
                  }
                ],
              },
              {
                'status': 'plantowatch',
                'show': {
                  'title': 'Planned',
                  'ids': {'simkl': 2, 'imdb': 'tt7654321'}
                },
              }
            ]
          },
        '/sync/all-items/movies' => {
            'movies': [
              {
                'status': 'completed',
                'last_watched_at': '2026-01-01T00:00:00Z',
                'movie': {
                  'title': 'A film',
                  'ids': {'simkl': 3, 'imdb': 'tt1122334'}
                },
              }
            ]
          },
        '/sync/all-items/anime' => <String, dynamic>{},
        '/sync/all-items' => {
            'shows': [
              {
                'status': 'watching',
                'last_watched_at': '2026-01-02T00:00:00Z',
                'show': {
                  'title': 'A series',
                  'ids': {'simkl': 1, 'imdb': 'tt1234567'}
                },
                'seasons': [
                  {
                    'number': 1,
                    'episodes': [
                      {'number': 1, 'watched_at': '2026-01-01T00:00:00Z'},
                      {'number': 2, 'watched_at': '2026-01-02T00:00:00Z'},
                    ]
                  }
                ],
              }
            ]
          },
        _ => <String, dynamic>{},
      };
      handler.resolve(Response<dynamic>(requestOptions: options, data: data));
    }));

    final first = NoorApi(
        dio: dio,
        simklExchange: (_) async => <String, dynamic>{'access_token': 'token'});
    await first.activateAccount('account');
    expect(
      await first.pollLinkedService('simkl', {'device_code': 'linked'}),
      {'status': 'success'},
    );
    final watchlist = await first.syncLinkedService('simkl', 'watchlist');
    expect(watchlist.single['imdb'], 'tt7654321');
    final history = await first.syncLinkedService('simkl', 'history');
    expect(history.length, 2);
    expect(history.where((row) => row['episode'] == 1).length, 1);
    expect(paths.where((path) => path == '/sync/all-items/shows').length, 1);

    changed = true;
    paths.clear();
    final second = NoorApi(dio: dio);
    await second.activateAccount('account');
    final updated = await second.syncLinkedService('simkl', 'history');
    expect(updated.where((row) => row['episode'] != null).length, 2);
    expect(paths, contains('/sync/activities'));
    expect(paths, contains('/sync/all-items'));
    expect(paths, isNot(contains('/sync/all-items/shows')));

    paths.clear();
    final third = NoorApi(dio: dio);
    await third.activateAccount('account');
    expect(await third.syncLinkedService('simkl', 'watchlist'), hasLength(1));
    expect(paths, ['/sync/activities']);
  });

  test('Simkl trending reads CDN rows and retains anime without IMDb',
      () async {
    final dio = Dio();
    String? host;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      host = options.uri.host;
      handler.resolve(Response<dynamic>(requestOptions: options, data: {
        'movies': [
          {
            'title': 'Film',
            'ids': {'imdb': 'tt1234567', 'simkl_id': 1}
          }
        ],
        'tv': <dynamic>[],
        'anime': [
          {
            'title': 'Anime',
            'anime_type': 'movie',
            'ids': {'mal': 42, 'simkl_id': 2}
          }
        ],
      }));
    }));
    final rows = await NoorApi(dio: dio).simklTrending();
    expect(host, 'data.simkl.in');
    expect(rows, hasLength(2));
    expect(rows.last['id'], 'mal:42');
    expect(rows.last['type'], 'movie');
  });

  test('Simkl personal rating checks the item result and refreshes its value',
      () async {
    SharedPreferences.setMockInitialValues({});
    final secure = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      if (call.method == 'read') return secure[key];
      if (call.method == 'write') secure[key] = args['value'] as String;
      if (call.method == 'delete') secure.remove(key);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, null));

    var rating = 6;
    var acceptWrite = false;
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final path = options.uri.path;
      final dynamic data = switch (path) {
        '/sync/activities' => {
            'all': '2026-01-01T00:00:00Z',
            'movies': {'rated_at': '2026-01-01T00:00:00Z'},
          },
        '/sync/all-items/movies' => {
            'movies': [
              {
                'status': 'completed',
                'user_rating': rating,
                'movie': {
                  'title': 'Film',
                  'ids': {'simkl': 44, 'imdb': 'tt1234567'}
                }
              }
            ]
          },
        '/sync/all-items/shows' ||
        '/sync/all-items/anime' =>
          <String, dynamic>{},
        '/sync/ratings' => acceptWrite
            ? {
                'added': {
                  'statuses': [
                    {
                      'request': {
                        'ids': {'imdb': 'tt1234567'}
                      },
                      'response': {'status': 'completed'}
                    }
                  ]
                }
              }
            : {
                'added': {'statuses': <dynamic>[]},
                'not_found': {
                  'movies': [1]
                }
              },
        '/sync/ratings/remove' => {
            'deleted': {'movies': 0, 'shows': 1}
          },
        _ => <String, dynamic>{},
      };
      handler.resolve(Response<dynamic>(requestOptions: options, data: data));
    }));
    final api = NoorApi(
        dio: dio,
        simklExchange: (_) async => <String, dynamic>{'access_token': 'token'});
    await api.activateAccount('rating-account');
    expect(await api.pollLinkedService('simkl', {'device_code': 'linked'}),
        {'status': 'success'});
    expect(await api.simklUserRating(imdb: 'tt1234567'), 6);
    expect(
        await api.setSimklUserRating(
            type: 'movie', anime: false, imdb: 'tt1234567', rating: 8),
        false);
    expect(await api.simklUserRating(imdb: 'tt1234567'), 6);
    acceptWrite = true;
    rating = 8;
    expect(
        await api.setSimklUserRating(
            type: 'movie', anime: false, imdb: 'tt1234567', rating: 8),
        true);
    expect(await api.simklUserRating(imdb: 'tt1234567'), 8);
    final write =
        requests.lastWhere((request) => request.uri.path == '/sync/ratings');
    expect((write.data as Map)['movies'], isNotEmpty);
    expect(write.headers['Authorization'], 'Bearer token');
    expect(
        await api.setSimklUserRating(
            type: 'series', anime: true, malId: 42, rating: null),
        true);
    final removal = requests
        .lastWhere((request) => request.uri.path == '/sync/ratings/remove');
    expect((removal.data as Map)['shows'], isNotEmpty);
  });
}
