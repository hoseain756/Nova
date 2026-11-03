import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/letterboxd/letterboxd_settings.dart';
import 'package:nova_mobile/core/letterboxd/stremboxd_client.dart';

void main() {
  test('public configuration matches Harbor and never contains credentials',
      () {
    final settings = LetterboxdSettings.defaults.copyWith(
      enabled: true,
      username: '  cine-user  ',
      listRefs: const [LetterboxdListRef(id: 'abc123', name: 'My list')],
    );
    final encoded = settings.encodedPublicConfig;
    final decoded =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(encoded))))
            as Map<String, dynamic>;
    expect(decoded, {
      'u': 'cine-user',
      'c': {
        'popular': true,
        'top250': true,
        'watchlist': true,
        'likedFilms': true,
      },
      'l': ['abc123'],
      'r': true,
    });
    final saved = jsonEncode(settings.toJson());
    expect(saved, isNot(contains('userToken')));
    expect(saved, isNot(contains('password')));
    expect(LetterboxdSettings.fromJson(settings.toJson()).selectedCatalogs,
        LetterboxdSettings.defaultCatalogs);
  });

  test('public verification, catalog, metadata and list use bridge paths',
      () async {
    final settings = LetterboxdSettings.defaults.copyWith(username: 'viewer');
    final paths = <String>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      paths.add(options.uri.path);
      final data = switch (options.uri.path) {
        '/stremio/user123/meta/movie/tt1234567.json' => {
            'meta': {
              'id': 'tt1234567',
              'name': 'Test film',
              'links': [
                {
                  'category': 'Letterboxd Popular Reviews',
                  'name': 'A review',
                  'url': 'https://letterboxd.com/film/test-film/reviews/'
                }
              ],
            },
          },
        final path when path.endsWith('/manifest.json') => {
            'id': 'community.stremboxd',
            'catalogs': [
              {'id': LetterboxdSettings.watchlistCatalog}
            ],
          },
        final path
            when path.endsWith('/catalog/movie/letterboxd-watchlist.json') =>
          {
            'metas': [
              {'id': 'tt1234567', 'type': 'movie', 'name': 'Test film'}
            ],
          },
        final path when path.endsWith('/meta/movie/tt1234567.json') => {
            'meta': {'id': 'tt1234567', 'name': 'Test film'}
          },
        '/auth/resolve-list-public' => {
            'id': 'list123',
            'name': 'Films',
            'owner': 'viewer',
            'filmCount': 20,
          },
        _ => <String, dynamic>{},
      };
      handler.resolve(Response<dynamic>(
          requestOptions: options, statusCode: 200, data: data));
    }));
    final client = StremboxdClient(dio: dio);
    final verified = await client.verifyPublic(settings);
    expect(verified.catalogs, 1);
    expect(verified.hasWatchlist, isTrue);
    final page = await client.fetchCatalog(
        settings, LetterboxdSettings.watchlistCatalog);
    expect(page.metas.single['id'], 'tt1234567');
    expect(page.items.single.name, 'Test film');
    expect(
        (await client.fetchPublicMeta(settings, 'tt1234567'))?.id, 'tt1234567');
    final fullMeta = await client.fetchFullMeta('user123', 'tt1234567');
    expect((fullMeta?['links'] as List).single['name'], 'A review');
    final ref = await client
        .resolvePublicList('https://letterboxd.com/viewer/list/films');
    expect(ref.id, 'list123');
    expect(paths, contains('/auth/resolve-list-public'));
    expect(paths.first, '/${settings.encodedPublicConfig}/manifest.json');
    await expectLater(
        client.resolvePublicList('https://example.com/viewer/list/films/'),
        throwsA(isA<StremboxdException>()));
  });

  test('Full mode handles 2FA and uses bearer token without saving password',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      if (options.uri.path == '/auth/login' &&
          (options.data as Map)['totp'] == null) {
        handler.resolve(Response<dynamic>(
            requestOptions: options,
            statusCode: 401,
            data: {'error': 'Code required', 'code': '2FA_REQUIRED'}));
        return;
      }
      final data = switch (options.uri.path) {
        '/auth/login' => {
            'userToken': 'secret-token',
            'user': {
              'id': 'abc123',
              'username': 'viewer',
              'displayName': 'Viewer'
            },
          },
        '/auth/preferences' => {'success': true},
        '/v1/resolve-film' => {
            'id': 'film123',
            'name': 'Test film',
            'imdbId': 'tt1234567',
          },
        '/v1/film-rating' => {
            'filmId': 'film123',
            'userRating': 4.5,
            'watched': true,
          },
        _ => <String, dynamic>{},
      };
      handler.resolve(Response<dynamic>(
          requestOptions: options, statusCode: 200, data: data));
    }));
    final client = StremboxdClient(dio: dio);
    await expectLater(
        client.login('viewer', 'a-password'),
        throwsA(isA<StremboxdException>()
            .having((error) => error.requiresTotp, 'requiresTotp', true)));
    final session = await client.login('viewer', 'a-password', totp: '123456');
    expect(session.userToken, 'secret-token');
    expect(session.displayName, 'Viewer');
    final settings = LetterboxdSettings.defaults
        .copyWith(mode: 'full', showRatingsOnPosters: false);
    await client.updatePreferences(settings, session);
    final preferenceBody = requests
        .firstWhere((options) => options.uri.path == '/auth/preferences')
        .data as Map;
    expect((preferenceBody['preferences'] as Map)['showRatings'], isFalse);
    expect((await client.resolveFilm('tt1234567', session))?.id, 'film123');
    expect((await client.fetchFilmRating('film123', session)).userRating, 4.5);
    final loginBody = requests
        .firstWhere((options) =>
            options.uri.path == '/auth/login' &&
            (options.data as Map)['totp'] != null)
        .data as Map;
    expect(loginBody['password'], 'a-password');
    expect(loginBody['totp'], '123456');
    expect(jsonEncode(settings.toJson()), isNot(contains('a-password')));
    expect(jsonEncode(session.toJson()), isNot(contains('a-password')));
    expect(
        requests
            .firstWhere((options) => options.uri.path == '/v1/film-rating')
            .headers['Authorization'],
        'Bearer secret-token');
  });

  test('film streams reject untrusted signed-action URLs', () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(
          Response<dynamic>(requestOptions: options, statusCode: 200, data: {
        'streams': [
          {
            'name': 'Letterboxd',
            'description':
                '4.2 / 5 (1.2K ratings)\n✓ Watched\nYour rating: 4.5',
            'externalUrl': 'https://letterboxd.com/film/test-film/',
          },
          {
            'name': 'Rate',
            'externalUrl':
                'https://api.stremboxd.com/action/user123/rate/film123?tok=signed',
          },
          {
            'name': 'Watchlist',
            'externalUrl':
                'https://evil.example/action/user123/watchlist/film123?tok=stolen',
          }
        ]
      }));
    }));
    final info = await StremboxdClient(dio: dio)
        .fetchFilmStreamInfo('user123', 'tt1234567');
    expect(info?.communityRating, 4.2);
    expect(info?.communityRatings, 1200);
    expect(info?.userRating, 4.5);
    expect(info?.watched, isTrue);
    expect(info?.rateUrl?.host, 'api.stremboxd.com');
    expect(info?.watchlistUrl, isNull);
  });
}
