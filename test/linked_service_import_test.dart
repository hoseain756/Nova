import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/state/app_state.dart';

class _ImportApi extends NoorApi {
  @override
  Future<List<dynamic>> syncLinkedService(String service, String kind) async {
    if (kind == 'watchlist') {
      return [
        {'imdb': 'tt1234567', 'type': 'movie', 'title': 'A film'}
      ];
    }
    return [
      {
        'imdb': 'tt7654321',
        'type': 'series',
        'title': 'A show',
        'season': 1,
        'episode': 1,
        'watchedAt': 1000,
      },
      {
        'imdb': 'tt7654321',
        'type': 'series',
        'title': 'A show',
        'season': 1,
        'episode': 2,
        'watchedAt': 2000,
      },
    ];
  }
}

void main() {
  test('linked import keeps distinct episodes and is idempotent', () async {
    final api = _ImportApi();
    final app = AppState(api, CatalogRepository(api));
    app.linkedServices = {
      'trakt': {'linked': true},
    };

    expect(await app.syncLinkedService('trakt'), (1, 2));
    expect(app.watchlist.map((item) => item.id), ['tt1234567']);
    expect(app.history.map((entry) => entry.episode).toSet(), {1, 2});
    expect(await app.syncLinkedService('trakt'), (0, 0));
    expect(app.history.length, 2);
  });
}
