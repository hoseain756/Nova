import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/addon.dart';

class _StreamApi extends NoorApi {
  bool fail = false;

  @override
  Future<dynamic> proxyGet(String url, {Map<String, String>? headers}) async {
    if (fail) throw StateError('Provider unavailable');
    return {
      'streams': [
        {'url': 'https://example.org/video.mp4', 'title': 'Video'}
      ],
    };
  }
}

const _addon = Addon(
  id: 'stream-provider',
  name: 'Stream provider',
  transportUrl: 'https://example.org/manifest.json',
  manifest: {
    'resources': [
      {
        'name': 'stream',
        'types': ['movie'],
        'idPrefixes': ['tt']
      }
    ],
  },
);

void main() {
  test('player stream search reports complete provider failure', () async {
    final api = _StreamApi()..fail = true;
    final repository = CatalogRepository(api);

    await expectLater(
      repository.streams('movie', 'tt123', [_addon], reportFailures: true),
      throwsStateError,
    );
    expect(await repository.streams('movie', 'tt123', [_addon]), isEmpty);
  });

  test('player stream search retains successful results', () async {
    final result = await CatalogRepository(_StreamApi())
        .streams('movie', 'tt123', [_addon], reportFailures: true);
    expect(result.single['url'], 'https://example.org/video.mp4');
  });
}
