import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/addon.dart';

Addon _addon(
  String id, {
  bool enabled = true,
  List<Map<String, dynamic>> catalogs = const [],
}) =>
    Addon(
      id: id,
      name: 'Addon $id',
      transportUrl: 'https://$id.example/manifest.json',
      manifest: <String, dynamic>{'catalogs': catalogs},
      enabled: enabled,
    );

Map<String, dynamic> _catalog(
  String id,
  String type,
  String name, {
  bool requiresSearch = false,
}) =>
    <String, dynamic>{
      'id': id,
      'type': type,
      'name': name,
      if (requiresSearch)
        'extra': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'search', 'isRequired': true},
        ],
    };

void main() {
  group('CatalogRepository.selectAddonCatalogRows', () {
    test('same-named catalogs from separate add-ons remain independent', () {
      final rows = CatalogRepository.selectAddonCatalogRows([
        _addon('a', catalogs: [
          _catalog('top', 'movie', 'Popular'),
        ]),
        _addon('b', catalogs: [
          _catalog('top2', 'movie', 'POPULAR '), // same name, different case
          _catalog('other', 'series', 'Other'),
        ]),
      ]);
      expect(rows.map((row) => row.key).toList(),
          ['a:movie:top', 'b:movie:top2', 'b:series:other']);
      expect(rows.first.title, 'Popular');
      expect(rows.first.subtitle, 'Addon a');
    });

    test('anchor keys, disabled add-ons and non-movie/series types are skipped',
        () {
      final rows = CatalogRepository.selectAddonCatalogRows([
        _addon('a', catalogs: [
          _catalog('trailer', 'movie', 'Trending'), // anchor pair movie:trailer
          _catalog('channels', 'tv', 'Live'), // unsupported type
          _catalog('other', 'movie', 'Other'),
        ]),
        _addon('b', enabled: false, catalogs: [
          _catalog('x', 'movie', 'Hidden'),
        ]),
      ], anchorKeys: const {
        'movie:trailer'
      });
      expect(rows.map((row) => row.key).toList(), ['a:movie:other']);
    });

    test('catalogs that REQUIRE a search term never get a row', () {
      final rows = CatalogRepository.selectAddonCatalogRows([
        _addon('a', catalogs: [
          _catalog('search-only', 'movie', 'Searchable', requiresSearch: true),
          _catalog('plain', 'movie', 'Plain'),
        ]),
      ]);
      expect(rows.map((row) => row.catalog.id).toList(), ['plain']);
    });

    test('limit caps the result across add-ons', () {
      final rows = CatalogRepository.selectAddonCatalogRows(
        [
          _addon('a', catalogs: [
            _catalog('1', 'movie', 'One'),
            _catalog('2', 'movie', 'Two'),
          ]),
          _addon('b', catalogs: [
            _catalog('3', 'series', 'Three'),
            _catalog('4', 'series', 'Four'),
          ]),
        ],
        limit: 3,
      );
      expect(rows.length, 3);
    });

    test('order and hidden preferences apply to every installed row', () {
      final rows = CatalogRepository.selectAddonCatalogRows([
        _addon('a', catalogs: [
          _catalog('first', 'movie', 'First'),
          _catalog('second', 'series', 'Second'),
          _catalog('third', 'movie', 'Third'),
        ]),
      ], order: const [
        'a:movie:third'
      ], hidden: const {
        'a:series:second'
      });
      expect(rows.map((row) => row.key).toList(),
          ['a:movie:third', 'a:movie:first']);
    });

    test('Kids catalog detection can hide Home rows without removing the tab',
        () {
      final rows = CatalogRepository.selectAddonCatalogRows([
        _addon('family', catalogs: [
          _catalog('kids', 'movie', 'Family films'),
          _catalog('anime', 'series', 'Anime'),
        ]),
      ]);
      expect(CatalogRepository.isKidsCatalog(rows.first), true);
      expect(CatalogRepository.isKidsCatalog(rows.last), false);
    });

    test('empty input yields no rows', () {
      expect(CatalogRepository.selectAddonCatalogRows(const []), isEmpty);
    });
  });
}
