import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/state/app_state.dart';

class _SimklRailsApi extends NoorApi {
  @override
  Future<List<dynamic>> syncLinkedService(String service, String kind) async {
    if (service != 'simkl' || kind != 'all') return const [];
    return [
      {
        'id': 'simkl:1',
        'type': 'movie',
        'section': 'movies',
        'status': 'plantowatch',
        'title': 'Planned film',
      },
      {
        'id': 'simkl:2',
        'type': 'series',
        'section': 'shows',
        'status': 'watching',
        'title': 'Watching show',
        'nextDate': '2099-01-01T00:00:00Z',
      },
      {
        'id': 'simkl:3',
        'type': 'series',
        'section': 'anime',
        'status': 'plantowatch',
        'title': 'Planned anime',
        'anilist': 33,
        'nextDate': '2099-01-01T00:00:00Z',
      },
    ];
  }

  @override
  Future<List<dynamic>> simklPlayback() async => const [];

  @override
  Future<List<dynamic>> simklTrending() async => const [
        {'id': 'simkl:4', 'type': 'movie', 'title': 'Trending film'},
        {
          'id': 'simkl:5',
          'type': 'series',
          'title': 'Trending anime',
          'section': 'anime'
        },
      ];

  @override
  Future<Map<String, Map<String, String>>> animeTitleVariants(
          Iterable<int> aniListIds, Iterable<int> malIds) async =>
      {
        'anilist:33': {
          'english': 'English anime',
          'romaji': 'Romaji anime',
          'native': '日本語アニメ',
        },
      };
}

void main() {
  test('Simkl Home filters and Up Next affect actual rails', () async {
    final api = _SimklRailsApi();
    final app = AppState(api, CatalogRepository(api));
    app.linkedServices = {
      'simkl': {'linked': true}
    };
    app.webSettings['simklUpNextRailEnabled'] = true;
    app.webSettings['simklTrendingRailEnabled'] = true;
    await app.refreshLinkedContent(force: true);
    expect(app.linkedCatalogItems['simkl-movies-plan']?.single.name,
        'Planned film');
    expect(app.linkedCatalogItems['simkl-shows-watching']?.single.name,
        'Watching show');
    expect(app.linkedCatalogItems['simkl-up-next']?.first.name,
        'Watching show');
    expect(app.linkedCatalogItems['simkl-up-next']?.length, 2);
    expect(
        app.linkedCatalogItems['simkl-trending']?.first.name, 'Trending film');
    expect(app.linkedCatalogItems['simkl-anime-plan']?.single.name,
        'English anime');

    app.webSettings['simklAnimeTitleLanguage'] = 'native';
    await app.refreshLinkedContent(force: true);
    expect(app.linkedCatalogItems['simkl-anime-plan']?.single.name, '日本語アニメ');

    app.webSettings['hideContent'] = {'anime': true};
    await app.refreshLinkedContent(force: true);
    expect(app.linkedCatalogItems.containsKey('simkl-anime-plan'), false);
    expect(app.linkedCatalogItems['simkl-trending']?.length, 1);
    expect(app.linkedCatalogItems['simkl-up-next']?.length, 1);

    app.webSettings['simklShowsWatchingRail'] = false;
    await app.refreshLinkedContent(force: true);
    expect(app.linkedCatalogItems.containsKey('simkl-shows-watching'), false);
    expect(app.linkedCatalogItems.containsKey('simkl-movies-plan'), true);
  });
}
