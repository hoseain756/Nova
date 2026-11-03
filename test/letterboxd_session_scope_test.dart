import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/letterboxd/letterboxd_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Letterboxd session is secure and scoped to the active NOVA account',
      () async {
    SharedPreferences.setMockInitialValues({});
    final secure = <String, String>{};
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

    final api = NoorApi();
    await api.activateAccount('first');
    final session = LetterboxdSession(
      userToken: 'private-token',
      userId: 'user-id',
      username: 'viewer',
      loginAt: DateTime.utc(2026, 11, 4),
    );
    await api.saveLetterboxdSession(session);
    expect(api.letterboxdSession?.userToken, 'private-token');
    expect(secure.keys.single, contains('nova.account.first.'));
    expect(secure.values.single, contains('private-token'));

    await api.activateAccount('second');
    expect(api.letterboxdSession, isNull);
    await api.activateAccount('first');
    expect(api.letterboxdSession?.username, 'viewer');
    await api.clearLetterboxdSession();
    expect(api.letterboxdSession, isNull);
    expect(secure, isEmpty);
  });
}
