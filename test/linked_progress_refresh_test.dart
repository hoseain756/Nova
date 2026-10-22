import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/state/app_state.dart';

class _TrackerApi extends NoorApi {
  bool animeFails = false;

  @override
  Future<List<dynamic>> traktPlayback() async => throw StateError('offline');

  @override
  Future<List<dynamic>> syncLinkedService(String service, String kind) async =>
      [];

  @override
  Future<List<dynamic>> aniListEntries() async {
    if (animeFails) throw StateError('offline');
    return [
      {
        'status': 'CURRENT',
        'progress': 3,
        'updatedAt': 1000,
        'media': {
          'id': 123,
          'format': 'TV',
          'episodes': 12,
          'title': {'english': 'Example anime'},
          'coverImage': {'large': 'https://example.com/poster.jpg'},
        },
      },
    ];
  }
}

void main() {
  test('one unavailable tracker leaves other progress and last good rows',
      () async {
    final api = _TrackerApi();
    final app = AppState(api, CatalogRepository(api));
    app.linkedServices = {
      'trakt': {'linked': true},
      'anilist': {'linked': true},
    };
    await app.refreshLinkedContent(force: true);
    expect(
        app.linkedContinueWatching.map((entry) => entry.source), ['anilist']);
    expect(
        app.linkedCatalogItems['anilist-watching']?.single.id, 'anilist:123');

    api.animeFails = true;
    await app.refreshLinkedContent(force: true);
    expect(
        app.linkedContinueWatching.map((entry) => entry.source), ['anilist']);
    expect(
        app.linkedCatalogItems['anilist-watching']?.single.id, 'anilist:123');
  });
}
