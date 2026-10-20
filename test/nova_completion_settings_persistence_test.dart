import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LocalNoorApi extends NoorApi {
  @override
  Future<void> initialize() async {}

  @override
  Future<List<dynamic>> loadIptvPlaylists() async => const [];

  @override
  bool isLinked(String service) => false;

  @override
  Future<bool> hasPendingTraktLink() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('live settings survive construction of a fresh AppState', () async {
    SharedPreferences.setMockInitialValues({
      AppState.settingsStorageKey: jsonEncode({
        'cloudSyncEnabled': false,
        'pickerLayout': 'stremio',
        'uiLanguage': 'en',
      }),
      'horse.mobile.english': true,
    });

    final firstApi = _LocalNoorApi();
    final first = AppState(firstApi, CatalogRepository(firstApi));
    await first.initialize();
    var notifications = 0;
    first.addListener(() => notifications++);

    await first.setSetting('pickerLayout', 'condensed');
    await first.setSetting('navigationBarStyle', 'mini');
    await first.setLanguage(false);

    expect(first.webSettings['pickerLayout'], 'condensed');
    expect(first.webSettings['navigationBarStyle'], 'mini');
    expect(first.english, isFalse);
    expect(notifications, greaterThanOrEqualTo(2));

    // Both writes are intentionally paint-first and persist in the background.
    // Yield until the mock preference backend observes those unawaited writes.
    final preferences = await SharedPreferences.getInstance();
    for (var attempt = 0; attempt < 20; attempt++) {
      final saved = preferences.getString(AppState.settingsStorageKey);
      final decoded = saved == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(saved) as Map);
      if (decoded['pickerLayout'] == 'condensed' &&
          decoded['navigationBarStyle'] == 'mini' &&
          decoded['uiLanguage'] == 'ar' &&
          preferences.getBool('horse.mobile.english') == false) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    first.dispose();

    final secondApi = _LocalNoorApi();
    final second = AppState(secondApi, CatalogRepository(secondApi));
    addTearDown(second.dispose);
    await second.initialize();

    expect(second.webSettings['pickerLayout'], 'condensed');
    expect(second.webSettings['navigationBarStyle'], 'mini');
    expect(second.webSettings['uiLanguage'], 'ar');
    expect(second.english, isFalse);
  });
}
