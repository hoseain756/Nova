import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/anime_subtitle_ids.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/addon.dart';
import 'package:nova_mobile/core/models/media_item.dart';

class _SubtitleApi extends NoorApi {
  final requests = <String>[];
  bool primaryHasResults = false;
  bool failPrimary = false;

  @override
  Future<dynamic> proxyGet(String url, {Map<String, String>? headers}) async {
    requests.add(url);
    if (url.startsWith('https://api.ani.zip/mappings?')) {
      // AniZip currently labels its JSON response as text/plain.
      return jsonEncode(_mapping);
    }
    if (url.contains('/subtitles/')) {
      if (failPrimary && url.contains('tt0388629%3A23%3A1')) {
        throw StateError('Provider unavailable');
      }
      if (url.contains('tt0388629%3A23%3A1') && primaryHasResults) {
        return {
          'subtitles': [
            {'url': 'https://example.org/primary.srt'}
          ]
        };
      }
      if (url.contains('tt0388629%3A1%3A1156')) {
        return {
          'subtitles': [
            {'url': 'https://example.org/absolute.srt'}
          ]
        };
      }
      return {'subtitles': []};
    }
    throw StateError('Unexpected request: $url');
  }
}

const _item = MediaItem(
  id: 'tt0388629',
  type: 'series',
  name: 'One Piece',
  genres: ['Animation'],
  videos: [
    {
      'id': 'tt0388629:23:1',
      'season': 23,
      'episode': 1,
      'released': '2026-04-05T00:00:00.000Z',
    },
  ],
);

const _mapping = <String, dynamic>{
  'mappings': {
    'imdb_id': 'tt0388629',
    'mal_id': 21,
    'kitsu_id': 12,
    'anilist_id': 21,
    'anidb_id': 69,
  },
  'episodes': {
    '1156': {
      'seasonNumber': 23,
      'episodeNumber': 1,
      'absoluteEpisodeNumber': 1156,
      'airDate': '2026-04-05',
    },
  },
};

const _addon = Addon(
  id: 'subdl',
  name: 'SubDL Subtitles',
  transportUrl: 'https://example.org/manifest.json',
  manifest: {
    'resources': [
      {
        'name': 'subtitles',
        'types': ['series'],
        'idPrefixes': ['tt']
      },
    ],
  },
);

void main() {
  test('S23E1 resolves only from exact AniZip record to absolute 1156', () {
    expect(AnimeSubtitleIds.mappingQuery(_item), 'imdb_id=tt0388629');
    expect(
      AnimeSubtitleIds.fromMapping(
        item: _item,
        videoId: 'tt0388629:23:1',
        mapping: _mapping,
      ),
      contains('tt0388629:1:1156'),
    );
  });

  test('AniSkip episode number uses only exact AniZip mapping', () async {
    final item = _item.withAnimeIds(idMal: 21);
    final repo = CatalogRepository(_SubtitleApi());
    expect(await repo.exactAnimeSkipIdentity(item, 'tt0388629:23:1'),
        (malId: 21, episode: 1156));
    expect(await repo.exactAnimeSkipIdentity(_item, 'tt0388629:23:1'),
        (malId: 21, episode: 1156));
    expect(
      AnimeSubtitleIds.exactEpisodeNumber(
        item: item,
        videoId: 'tt0388629:23:1',
        mapping: {
          ..._mapping,
          'episodes': {
            ..._mapping['episodes'] as Map,
            '9999': (_mapping['episodes'] as Map)['1156'],
          },
        },
      ),
      isNull,
    );
  });

  test('mismatched identity, date, or ambiguous record rejects fallback', () {
    for (final mapping in [
      {
        ..._mapping,
        'mappings': {..._mapping['mappings'] as Map, 'imdb_id': 'tt1'}
      },
      {
        ..._mapping,
        'episodes': {
          '1156': {
            ...(_mapping['episodes'] as Map)['1156'] as Map,
            'airDate': '2026-04-06',
          },
        },
      },
      {
        ..._mapping,
        'episodes': {
          ..._mapping['episodes'] as Map,
          '9999': (_mapping['episodes'] as Map)['1156'],
        },
      },
    ]) {
      expect(
        AnimeSubtitleIds.fromMapping(
          item: _item,
          videoId: 'tt0388629:23:1',
          mapping: Map<String, dynamic>.from(mapping),
        ),
        isEmpty,
      );
    }
  });

  test('repository queries absolute subtitle ID only after empty primary',
      () async {
    final api = _SubtitleApi();
    final repo = CatalogRepository(api);
    final result = await repo.subtitlesForEpisode(
      _item,
      'tt0388629:23:1',
      [_addon],
    );
    expect(result.single['url'], 'https://example.org/absolute.srt');
    expect(api.requests.where((url) => url.contains('ani.zip')), hasLength(1));
    expect(api.requests.any((url) => url.contains('tt0388629%3A1%3A1156')),
        isTrue);
  });

  test('repository preserves primary subtitle results without AniZip',
      () async {
    final api = _SubtitleApi()..primaryHasResults = true;
    final result = await CatalogRepository(api).subtitlesForEpisode(
      _item,
      'tt0388629:23:1',
      [_addon],
    );
    expect(result.single['url'], 'https://example.org/primary.srt');
    expect(api.requests.where((url) => url.contains('ani.zip')), isEmpty);
  });

  test('player discovery reports all add-on failures instead of empty results',
      () async {
    final api = _SubtitleApi()..failPrimary = true;
    final repo = CatalogRepository(api);

    await expectLater(
      repo.subtitlesForEpisode(_item, 'tt0388629:23:1', [_addon],
          reportFailures: true),
      throwsStateError,
    );
    expect(api.requests.where((url) => url.contains('ani.zip')), isEmpty);
  });

  test('player discovery still accepts successful add-on results', () async {
    final api = _SubtitleApi()..primaryHasResults = true;
    final result = await CatalogRepository(api).subtitlesForEpisode(
        _item, 'tt0388629:23:1', [_addon],
        reportFailures: true);
    expect(result.single['url'], 'https://example.org/primary.srt');
  });
}
