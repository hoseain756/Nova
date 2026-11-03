import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MyAnimeList sync and visible list follow paging.next', () async {
    SharedPreferences.setMockInitialValues({});
    const storage =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async {
      final key = (call.arguments as Map)['key'];
      if (call.method == 'read' &&
          key == 'nova.account.account.noor.mal.token') {
        return 'access';
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null));

    final dio = Dio();
    final pages = <String>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      pages.add(options.uri.queryParameters['offset'] ?? '0');
      final offset = options.uri.queryParameters['offset'];
      handler.resolve(Response<dynamic>(requestOptions: options, data: {
        'data': [
          {
            'node': {
              'id': offset == null ? 1 : 2,
              'title': offset == null ? 'First' : 'Second',
              'media_type': 'tv',
            },
            'list_status': {
              'status': 'watching',
              'num_episodes_watched': 2,
            }
          }
        ],
        'paging': offset == null
            ? {
                'next':
                    'https://api.myanimelist.net/v2/users/@me/animelist?offset=500'
              }
            : <String, dynamic>{},
      }));
    }));
    final api = NoorApi(dio: dio);
    await api.activateAccount('account');
    final history = await api.syncLinkedService('mal', 'history');
    expect(history, hasLength(2));
    expect(history.last['id'], 'mal:2');
    final visible = await api.malList(status: 'watching');
    expect(visible, hasLength(2));
    expect(visible.last['id'], 2);
    expect(visible.last['list_status']['num_episodes_watched'], 2);
    expect(pages, ['0', '500', '0', '500']);
  });
}
