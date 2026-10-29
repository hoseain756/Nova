import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/torrent/ios_torrent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String repeat(String value, int count) => List.filled(count, value).join();

  test('normalizes hex and base32 BitTorrent v1 identifiers', () {
    expect(canonicalIosTorrentHash(repeat('A', 40)), repeat('a', 40));
    expect(canonicalIosTorrentHash(repeat('A', 32)), repeat('0', 40));
    expect(canonicalIosTorrentHash(repeat('7', 32)), repeat('f', 40));
    expect(
      canonicalIosTorrentHash(
          'magnet:?xt=urn:btih:${repeat('A', 40)}&dn=Movie'),
      repeat('a', 40),
    );
    expect(canonicalIosTorrentHash('invalid'), isNull);
  });

  test('selects the addon file and uses TorrServer one-based HTTP index',
      () async {
    final previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    const hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const channel = MethodChannel('noor/ios_torrent');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final actions = <String>[];
    final subscription = server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      actions.add(body['action'] as String);
      request.response.headers.contentType = ContentType.json;
      if (body['action'] == 'get' || body['action'] == 'add') {
        request.response.write(jsonEncode({
          'hash': hash,
          'name': 'Series',
          'file_stats': [
            {'id': 1, 'path': 'Series/Episode1.mkv', 'length': 100},
            {'id': 2, 'path': 'Series/Episode2.mkv', 'length': 200},
          ],
        }));
      }
      await request.response.close();
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') return 'http://127.0.0.1:${server.port}';
      if (call.method == 'isSupported') return true;
      return null;
    });

    try {
      final prepared = await IosTorrentService.instance.prepare(
        infoHash: hash,
        magnet: 'magnet:?xt=urn:btih:$hash',
        fileIndex: 1,
      );
      final url = Uri.parse(prepared.url);
      expect(url.host, '127.0.0.1');
      expect(url.path, '/stream/Episode2.mkv');
      expect(url.queryParameters['link'], hash);
      expect(url.queryParameters['index'], '2');
      expect(url.queryParameters.containsKey('play'), isTrue);
      await prepared.stop();
      expect(actions, ['add', 'get', 'drop']);
    } finally {
      await IosTorrentService.instance.shutdown();
      messenger.setMockMethodCallHandler(channel, null);
      await subscription.cancel();
      await server.close(force: true);
      HttpOverrides.global = previousHttpOverrides;
    }
  });
}
