import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/integration_cw.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/features/media/episode_data.dart';

void main() {
  test('mark through episode stores the selected episode and predecessors',
      () async {
    final api = NoorApi(dio: Dio());
    final app = AppState(api, CatalogRepository(api))
      ..webSettings['cloudSyncEnabled'] = false;
    addTearDown(app.dispose);
    final title = MediaItem(
      id: 'tt1234567',
      type: 'series',
      name: 'Example',
      videos: const [
        {'id': 'ep1', 'season': 1, 'episode': 1, 'duration': '24 min'},
        {'id': 'ep2', 'season': 1, 'episode': 2, 'duration': '24 min'},
        {'id': 'ep3', 'season': 1, 'episode': 3, 'duration': '24 min'},
        {
          'id': 'future-ep',
          'season': 1,
          'episode': 4,
          'duration': '24 min',
          'released': '2999-01-01T00:00:00Z',
        },
      ],
    );

    await app.markEpisodesWatchedThrough(title, title.videos, title.videos[1]);

    final episodeState = episodeProgressMap(
      entries: app.historyForTitle(title),
      itemId: title.id,
    );
    expect(isEpisodeWatched(episodeState, title.videos[0], title.id), isTrue);
    expect(isEpisodeWatched(episodeState, title.videos[1], title.id), isTrue);
    expect(isEpisodeWatched(episodeState, title.videos[2], title.id), isFalse);
    expect(isEpisodeWatched(episodeState, title.videos[3], title.id), isFalse);
  });

  test('linked anime progress appears as watched episode state in details', () {
    final api = NoorApi(dio: Dio());
    final app = AppState(api, CatalogRepository(api));
    addTearDown(app.dispose);

    final title = MediaItem(
      id: 'kitsu:9001',
      type: 'series',
      name: 'Frieren',
      anilistId: 21,
      idMal: 31,
      videos: [
        for (var episode = 1; episode <= 12; episode++)
          {
            'id': 'kitsu:9001:1:$episode',
            'season': 1,
            'episode': episode,
          },
      ],
    );
    app.linkedContinueWatching = [
      IntegrationCwEntry.fromAniListRow({
        'status': 'CURRENT',
        'progress': 7,
        'updatedAt': 1700000000,
        'media': {
          'id': 21,
          'idMal': 31,
          'title': {'english': 'Frieren'},
          'format': 'TV',
          'episodes': 12,
        },
      })!,
    ];

    final episodes = app.historyForTitle(title);
    final progress = episodeProgressMap(entries: episodes, itemId: title.id);
    expect(episodes, hasLength(7));
    expect(
      isEpisodeWatched(progress, title.videos[6], title.id),
      isTrue,
    );
    expect(
      isEpisodeWatched(progress, title.videos[7], title.id),
      isFalse,
    );
  });

  test('linked episode counts cross seasons and local progress wins', () {
    final api = NoorApi(dio: Dio());
    final app = AppState(api, CatalogRepository(api));
    addTearDown(app.dispose);
    final title = MediaItem(
      id: 'tt1234567',
      type: 'series',
      name: 'Example',
      anilistId: 21,
      videos: const [
        {'id': 'special', 'season': 0, 'episode': 1},
        {'id': 's1e1', 'season': 1, 'episode': 1},
        {'id': 's1e2', 'season': 1, 'episode': 2},
        {'id': 's2e1', 'season': 2, 'episode': 1},
        {'id': 's2e2', 'season': 2, 'episode': 2},
      ],
    );
    app.history = [
      WatchHistoryEntry(
        item: title,
        watchedAt: 100,
        positionMs: 200,
        durationMs: 1000,
        season: 2,
        episode: 1,
      ),
    ];
    app.linkedContinueWatching = [
      IntegrationCwEntry(
        item: MediaItem(
          id: 'anilist:21',
          type: 'series',
          name: 'Example',
          anilistId: 21,
        ),
        source: 'anilist',
        episodesWatched: 3,
        watchedAt: 200,
      ),
    ];

    final entries = app.historyForTitle(title);
    final progress = episodeProgressMap(entries: entries, itemId: title.id);
    expect(isEpisodeWatched(progress, title.videos[1], title.id), isTrue);
    expect(isEpisodeWatched(progress, title.videos[2], title.id), isTrue);
    expect(isEpisodeWatched(progress, title.videos[3], title.id), isFalse);
    expect(isEpisodeWatched(progress, title.videos[4], title.id), isFalse);
    expect(entries.where((entry) => entry.season == 2 && entry.episode == 1),
        hasLength(1));
  });
}
