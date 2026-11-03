import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Trakt fetches every history page and skips unchanged activity',
      () async {
    SharedPreferences.setMockInitialValues({});
    final secure = <String, String>{
      'nova.account.account.noor.trakt.token': 'access-token',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      if (call.method == 'read') return secure[key];
      if (call.method == 'write') secure[key] = args['value'] as String;
      if (call.method == 'delete') secure.remove(key);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, null));

    final paths = <String>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      paths.add(options.uri.path);
      if (options.uri.path == '/sync/last_activities') {
        handler.resolve(Response<dynamic>(
          requestOptions: options,
          data: {'all': '2026-01-01T00:00:00Z'},
        ));
        return;
      }
      if (options.uri.path == '/users/me/history') {
        final page = options.uri.queryParameters['page'];
        handler.resolve(Response<dynamic>(
          requestOptions: options,
          headers: Headers.fromMap({
            'x-pagination-page-count': ['2'],
          }),
          data: [
            {
              'type': 'episode',
              'watched_at': '2026-01-01T00:00:00Z',
              'show': {
                'title': 'Series',
                'ids': {'imdb': 'tt1234567'},
              },
              'episode': {'season': 1, 'number': int.parse(page!)},
            }
          ],
        ));
        return;
      }
      handler.resolve(Response<dynamic>(requestOptions: options, data: []));
    }));

    final first = NoorApi(dio: dio);
    await first.activateAccount('account');
    final history = await first.syncLinkedService('trakt', 'history');
    expect(history.map((row) => row['episode']).toList(), [1, 2]);
    expect(paths.where((path) => path == '/users/me/history').length, 2);

    paths.clear();
    final second = NoorApi(dio: dio);
    await second.activateAccount('account');
    expect(await second.syncLinkedService('trakt', 'history'), hasLength(2));
    expect(paths, ['/sync/last_activities']);
  });
}
