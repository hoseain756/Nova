import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/letterboxd/letterboxd_settings.dart';
import 'package:nova_mobile/core/state/app_state.dart';

void main() {
  test('Public global rows work without a username', () {
    final api = NoorApi();
    final app = AppState(api, CatalogRepository(api));
    app.webSettings = {
      ...app.webSettings,
      'letterboxd': LetterboxdSettings.defaults
          .copyWith(enabled: true, username: '')
          .toJson(),
    };
    expect(app.letterboxdVisibleCatalogOrder, [
      LetterboxdSettings.popularCatalog,
      LetterboxdSettings.top250Catalog,
    ]);
  });

  test(
      'Letterboxd catalogs follow selection, order and hide preferences while preserving offline rows',
      () async {
    var watchlistOffline = false;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final watchlist = options.uri.path.contains('/letterboxd-watchlist');
      if (watchlist && watchlistOffline) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ));
        return;
      }
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {
          'metas': [
            {
              'id': watchlist ? 'tt1234567' : 'tt7654321',
              'type': 'movie',
              'name': watchlist ? 'Watchlist film' : 'Liked film',
            }
          ],
        },
      ));
    }));
    final api = NoorApi(dio: dio);
    final app = AppState(api, CatalogRepository(api));
    final settings = LetterboxdSettings.defaults.copyWith(
      enabled: true,
      username: 'alice',
      selectedCatalogs: [
        LetterboxdSettings.watchlistCatalog,
        LetterboxdSettings.likedCatalog,
      ],
      catalogOrder: [
        LetterboxdSettings.likedCatalog,
        LetterboxdSettings.watchlistCatalog,
      ],
    );
    app.webSettings = {...app.webSettings, 'letterboxd': settings.toJson()};

    await app.refreshLetterboxdCatalogs(force: true);
    expect(app.letterboxdVisibleCatalogOrder, [
      LetterboxdSettings.likedCatalog,
      LetterboxdSettings.watchlistCatalog,
    ]);
    expect(
        app.letterboxdCatalogItems[LetterboxdSettings.watchlistCatalog]?.single
            .id,
        'tt1234567');

    watchlistOffline = true;
    await app.refreshLetterboxdCatalogs(force: true);
    expect(
        app.letterboxdCatalogItems[LetterboxdSettings.watchlistCatalog]?.single
            .id,
        'tt1234567');

    app.webSettings = {
      ...app.webSettings,
      'letterboxd': settings.copyWith(
        hiddenCatalogs: [LetterboxdSettings.likedCatalog],
      ).toJson(),
    };
    await app.refreshLetterboxdCatalogs(force: true);
    expect(
        app.letterboxdCatalogItems.keys, [LetterboxdSettings.watchlistCatalog]);
  });
}
