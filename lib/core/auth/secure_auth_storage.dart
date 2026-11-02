import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the active Supabase session out of shared preferences.
class NovaSecureAuthStorage extends LocalStorage {
  const NovaSecureAuthStorage();

  static const _storage = FlutterSecureStorage();
  static const _activeKey = 'nova.auth.active-session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      (await _storage.read(key: _activeKey)) != null;

  @override
  Future<String?> accessToken() => _storage.read(key: _activeKey);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _activeKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _activeKey, value: persistSessionString);
}

class NovaSecurePkceStorage extends GotrueAsyncStorage {
  const NovaSecurePkceStorage();

  static const _storage = FlutterSecureStorage();
  String _key(String key) => 'nova.auth.pkce.$key';

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: _key(key));

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: _key(key), value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: _key(key));
}
