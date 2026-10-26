import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum SkipTimingCredential { introDb, theIntroDb }

/// User keys for timing providers. Never put these in webSettings
/// or linkedServices, which are persisted and may be synchronized as JSON.
class SkipTimingCredentials extends ChangeNotifier {
  SkipTimingCredentials({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static final shared = SkipTimingCredentials();

  static const _introDbStorageKey = 'noor.skip-timing.introdb.user-key';
  static const _theIntroDbStorageKey = 'noor.skip-timing.theintrodb.user-key';

  final FlutterSecureStorage _storage;
  int _revision = 0;
  int get revision => _revision;

  String _storageKey(SkipTimingCredential provider) => switch (provider) {
        SkipTimingCredential.introDb => _introDbStorageKey,
        SkipTimingCredential.theIntroDb => _theIntroDbStorageKey,
      };

  Future<bool> hasKey(SkipTimingCredential provider) async =>
      (await _storage.read(key: _storageKey(provider)))?.isNotEmpty ?? false;

  /// Only TheIntroDB supports a user key on public reads. IntroDB's key is
  /// reserved for user-authored submissions, which NOVA does not send.
  Future<String?> readTheIntroDbKey() =>
      _storage.read(key: _theIntroDbStorageKey);

  Future<void> saveKey(SkipTimingCredential provider, String value) async {
    final key = value.trim();
    if (key.isEmpty || key.contains(RegExp(r'[\r\n\x00]'))) {
      throw const FormatException('Invalid API key');
    }
    await _storage.write(key: _storageKey(provider), value: key);
    _revision++;
    notifyListeners();
  }

  Future<void> removeKey(SkipTimingCredential provider) async {
    await _storage.delete(key: _storageKey(provider));
    _revision++;
    notifyListeners();
  }
}
