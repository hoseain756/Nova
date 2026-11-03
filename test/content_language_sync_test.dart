import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/addon.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';

class _LanguageApi extends NoorApi {
  final catalogUrls = <String>[];
  final tmdbLanguages = <String?>[];

  @override
  Future<dynamic> proxyGet(String url, {Map<String, String>? headers}) async {
    catalogUrls.add(url);
    return {
      'metas': [
        {'id': 'tt1234567', 'type': 'movie', 'name': 'Original'}
      ],
    };
  }

  @override
  Future<dynamic> tmdbGet(String path,
      {Map<String, String>? query, String? language}) async {
    tmdbLanguages.add(language);
    if (path.endsWith('/videos')) {
      return {
        'results': [
          {'site': 'YouTube', 'type': 'Trailer', 'key': 'AbCdEfGh123'}
        ]
      };
    }
    if (path.startsWith('/find/')) {
      return {
        'movie_results': [
          {'id': 42, 'title': 'عنوان مترجم', 'overview': 'وصف مترجم'}
        ],
      };
    }
    return {
      'id': 42,
      'title': 'عنوان مترجم',
      'overview': 'وصف مترجم',
      'belongs_to_collection': {'name': 'A collection'},
      'networks': [
        {'name': 'A network'}
      ],
      'images': <String, dynamic>{},
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog request uses the current content language immediately',
      () async {
    final api = _LanguageApi();
    final catalogs = CatalogRepository(api);
    final app = AppState(api, catalogs);
    final addon = Addon(
      id: 'localized',
      name: 'Localized',
      transportUrl: 'https://example.com/manifest.json',
      manifest: {
        'catalogs': [
          {
            'type': 'movie',
            'id': 'top',
            'name': 'Top',
            'extra': [
              {'name': 'language'}
            ],
          }
        ],
      },
    );

    await catalogs.catalog('movie', 'top', addon: addon);
    expect(api.catalogUrls.last, contains('language=ar'));
    await app.setSetting('contentLanguage', 'fr');
    await catalogs.catalog('movie', 'top', addon: addon);
    expect(api.catalogUrls.last, contains('language=fr'));
  });

  test('TMDB enrichment applies localized title and synopsis without new ID',
      () async {
    final api = _LanguageApi();
    final catalogs = CatalogRepository(api);
    const original = MediaItem(
      id: 'tt1234567',
      type: 'movie',
      name: 'Original',
      description: 'Original overview',
    );
    final result = await catalogs.detailEnrichment(original, language: 'ar-SA');
    expect(result.id, original.id);
    expect(result.name, 'عنوان مترجم');
    expect(result.description, 'وصف مترجم');
    expect(api.tmdbLanguages, everyElement('ar-SA'));
  });

  test('TMDB feature settings control visible enrichment', () async {
    final api = _LanguageApi();
    final catalogs = CatalogRepository(api);
    final app = AppState(api, catalogs);
    const original = MediaItem(
      id: 'tt1234567',
      type: 'movie',
      name: 'Original',
      description: 'Original overview',
    );
    final full = await catalogs.detailEnrichment(original, language: 'ar-SA');
    expect(full.collectionName, 'A collection');
    expect(full.trailerUrl, 'https://www.youtube.com/watch?v=AbCdEfGh123');

    await app.setSetting('tmdbUseBasicInfo', false);
    await app.setSetting('tmdbUseTrailers', false);
    await app.setSetting('tmdbUseCollections', false);
    final minimal =
        await catalogs.detailEnrichment(original, language: 'ar-SA');
    expect(minimal.name, 'Original');
    expect(minimal.description, 'Original overview');
    expect(minimal.collectionName, isNull);
    expect(minimal.trailerUrl, isNull);
    expect(await catalogs.localizedItem(original, 'ar-SA'), original);
  });
}
