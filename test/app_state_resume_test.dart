import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/integration_cw.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';

void main() {
  test('local pause becomes resume and completion removes it at two minutes',
      () async {
    final api = NoorApi(dio: Dio());
    final app = AppState(api, CatalogRepository(api))
      ..webSettings['cloudSyncEnabled'] = false;
    addTearDown(app.dispose);
    final movie = MediaItem(id: 'local:movie:13', type: 'movie', name: 'Movie');

    await app.recordPlayback(movie, positionMs: 0, durationMs: 600000);
    expect(app.continueWatching, isEmpty);
    await app.recordPlayback(movie, positionMs: 479999, durationMs: 600000);
    expect(app.continueWatching.single.positionMs, 479999);
    expect(app.history.single.toJson()['positionMs'], 479999);
    await app.recordPlayback(movie, positionMs: 480000, durationMs: 600000);
    expect(app.continueWatching, isEmpty);
    expect(app.history.single.positionMs, 480000);
    expect(app.history.single.durationMs, 600000);
  });

  test('local checkpoint does not mutate linked episode progress', () async {
    final api = NoorApi(dio: Dio());
    final app = AppState(api, CatalogRepository(api))
      ..webSettings['cloudSyncEnabled'] = false;
    addTearDown(app.dispose);
    final title = MediaItem(
      id: 'kitsu:9001',
      type: 'series',
      name: 'Series',
      anilistId: 21,
    );
    final linked = IntegrationCwEntry.fromAniListRow({
      'status': 'CURRENT',
      'progress': 7,
      'updatedAt': 1700000000,
      'media': {
        'id': 21,
        'title': {'english': 'Series'},
        'format': 'TV',
        'episodes': 12,
      },
    })!;
    app.linkedContinueWatching = [linked];

    await app.recordPlayback(title,
        positionMs: 60000,
        durationMs: 600000,
        videoId: 'episode-8',
        season: 1,
        episode: 8);

    expect(app.history.single.episode, 8);
    expect(app.linkedContinueWatching.single, same(linked));
    expect(app.historyForTitle(title).first.episode, 8);
    expect(app.historyForTitle(title).length, 8);
  });
}
