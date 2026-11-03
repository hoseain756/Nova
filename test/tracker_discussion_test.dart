import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';

void main() {
  test('linked detail discussions use the exact Trakt and AniList title IDs',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final data = options.uri.host == 'graphql.anilist.co'
          ? {
              'data': {
                'Page': {
                  'threads': [
                    {
                      'id': 21,
                      'title': 'Episode discussion',
                      'body': '<p>Story</p>',
                      'siteUrl': 'https://anilist.co/forum/thread/21',
                      'user': {'name': 'reader'}
                    }
                  ]
                }
              }
            }
          : [
              {
                'id': 11,
                'comment': 'A comment',
                'spoiler': true,
                'user': {'username': 'viewer'}
              }
            ];
      handler.resolve(Response<dynamic>(requestOptions: options, data: data));
    }));
    final api = NoorApi(dio: dio);
    final trakt = await api.traktComments(
        mediaId: 'tt1234567', type: 'series');
    final anilist = await api.aniListThreads(42);
    expect(trakt.single['spoiler'], true);
    expect(trakt.single['username'], 'viewer');
    expect(anilist.single['title'], 'Episode discussion');
    expect(anilist.single['username'], 'reader');
    expect(requests.first.uri.path, '/shows/tt1234567/comments/likes');
    expect((requests.last.data as Map)['variables'], {'mediaId': 42});
    expect(await api.traktComments(mediaId: 'bad-id', type: 'movie'), isEmpty);
    expect(requests, hasLength(2));
  });
}
