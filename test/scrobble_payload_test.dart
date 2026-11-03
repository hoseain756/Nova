import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/track/scrobble_payload.dart';

void main() {
  test('movie scrobble identifies the film and clamps progress', () {
    expect(
      buildScrobblePayload(
        type: 'movie',
        title: ' Film ',
        year: '2025',
        imdb: 'tt1234567',
        progress: 120,
      ),
      {
        'movie': {
          'title': 'Film',
          'year': 2025,
          'ids': {'imdb': 'tt1234567'},
        },
        'progress': 100.0,
      },
    );
  });

  test('episode scrobble requires and includes exact season and number', () {
    expect(
      buildScrobblePayload(
        type: 'series',
        title: 'Show',
        imdb: 'tt7654321',
        season: 2,
        episode: 3,
        progress: 51.5,
      ),
      {
        'show': {
          'title': 'Show',
          'ids': {'imdb': 'tt7654321'},
        },
        'episode': {'season': 2, 'number': 3},
        'progress': 51.5,
      },
    );
    expect(
      buildScrobblePayload(type: 'series', title: 'Show', progress: 50),
      isNull,
    );
  });
}
