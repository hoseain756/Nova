import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';

void main() {
  test('MDBList source scores are normalized and can be disabled', () async {
    final dio = Dio();
    var mdbRequests = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final data = switch (options.uri.host) {
        'www.omdbapi.com' => {'Response': 'False'},
        'api.trakt.tv' => {'rating': 8.1, 'votes': 100},
        'api.themoviedb.org' => {
            'movie_results': [
              {'id': 42, 'vote_average': 7.5, 'vote_count': 50}
            ],
          },
        'api.mdblist.com' => {
            'score_average': 82,
            'ratings': [
              {'source': 'tomatoes', 'value': 91},
              {'source': 'audience', 'value': 74},
              {'source': 'letterboxd', 'value': 4.2, 'score': 84},
              {'source': 'mal', 'value': 8.7},
              {'source': 'imdb', 'value': 120},
            ],
          },
        _ => <String, dynamic>{},
      };
      if (options.uri.host == 'api.mdblist.com') mdbRequests++;
      handler.resolve(Response<dynamic>(requestOptions: options, data: data));
    }));
    final api = NoorApi(dio: dio);

    final enabled = Map<String, dynamic>.from(await api.ratingsGet(
      type: 'movie',
      title: 'A film',
      imdb: 'tt1234567',
      mdblistEnabled: true,
    ) as Map);
    expect(enabled['rottenTomatoes']['rating'], 91);
    expect(enabled['audience']['rating'], 74);
    expect(enabled['letterboxd']['rating'], 4.2);
    expect(enabled['mal']['rating'], 8.7);
    expect(enabled['mdblist']['rating'], 82);
    expect(enabled['imdb'], isNull); // invalid out-of-range value
    expect(mdbRequests, 1);

    final disabled = Map<String, dynamic>.from(await api.ratingsGet(
      type: 'movie',
      title: 'A film',
      imdb: 'tt1234567',
      mdblistEnabled: false,
    ) as Map);
    expect(disabled['mdblist'], isNull);
    expect(disabled['audience'], isNull);
    expect(mdbRequests, 1);
  });
}
