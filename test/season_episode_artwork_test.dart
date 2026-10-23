import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';

class _ArtworkApi extends NoorApi {
  final requests = <String>[];

  @override
  Future<dynamic> tmdbGet(String path,
      {Map<String, String>? query, String? language}) async {
    requests.add(path);
    if (path.startsWith('/find/')) {
      return {
        'tv_results': [
          {'id': 321}
        ]
      };
    }
    if (path == '/tv/321/season/23') {
      return {
        'poster_path': '/poster23.jpg',
        'episodes': [
          {'episode_number': 1, 'still_path': '/still23.jpg'},
          {'episode_number': 2, 'still_path': null},
        ],
      };
    }
    throw StateError('Unexpected path: $path');
  }
}

void main() {
  test('selected season fetches its own stills and caches the request',
      () async {
    final api = _ArtworkApi();
    final repository = CatalogRepository(api);
    final artwork = await repository.seasonEpisodeArtwork('tt12345', 23);
    expect(artwork.stills[1], contains('/still23.jpg'));
    expect(artwork.poster, contains('/poster23.jpg'));
    expect(artwork.stills.containsKey(2), isFalse);

    await repository.seasonEpisodeArtwork('tt12345', 23);
    expect(api.requests, ['/find/tt12345', '/tv/321/season/23']);
  });

  test('each later season receives its own still without changing playback ids',
      () {
    final videos = <Map<String, dynamic>>[
      {'id': 'tt1:1:1', 'season': 1, 'episode': 1, 'thumbnail': 'addon-1'},
      {'id': 'tt1:2:1', 'season': 2, 'episode': 1, 'thumbnail': 'old-season-1'},
      {'id': 'tt1:3:1', 'season': 3, 'episode': 1},
      {'id': 'tt1:23:1', 'season': 23, 'episode': 1},
    ];
    final result = CatalogRepository.applySeasonEpisodeArtwork(videos, {
      1: {1: 'tmdb-1'},
      2: {1: 'tmdb-2'},
      3: {1: 'tmdb-3'},
    }, {
      23: 'season-23-poster',
    });

    expect(result.map((video) => video['thumbnail']),
        ['addon-1', 'tmdb-2', 'tmdb-3', 'season-23-poster']);
    expect(result.map((video) => video['id']),
        ['tt1:1:1', 'tt1:2:1', 'tt1:3:1', 'tt1:23:1']);
    expect(videos[1]['thumbnail'], 'old-season-1');
  });
}
