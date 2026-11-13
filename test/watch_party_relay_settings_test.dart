import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nova_mobile/core/watch_party/watch_party_relay_settings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('relay configuration accepts only credential-free public TLS origins',
      () {
    expect(
        normalizeWatchPartyRelayEndpoint(' wss://RELAY.example.com/ ')
            .toString(),
        'https://relay.example.com');
    expect(
        normalizeWatchPartyRelayEndpoint('https://relay.example.com:443')
            .toString(),
        'https://relay.example.com');
    for (final value in [
      'http://relay.example.com',
      'https://user:pass@relay.example.com',
      'https://relay.example.com/path',
      'https://relay.example.com?token=secret',
      'https://relay.example.com#secret',
      'https://127.0.0.1',
      'https://[::1]',
      'https://localhost',
      'https://relay.local',
      'https://relay.example.com:8443'
    ]) {
      expect(
          () => normalizeWatchPartyRelayEndpoint(value), throwsFormatException,
          reason: value);
    }
  });

  test('transport selection is local, persistent and blocked in an active room',
      () async {
    final prefs = await SharedPreferences.getInstance();
    var canChange = true;
    final settings =
        WatchPartyRelaySettings(preferences: prefs, canChange: () => canChange);
    await settings.load();
    expect(settings.enabled, isFalse);
    await settings.configure('wss://relay.example.com');
    final restored = WatchPartyRelaySettings(preferences: prefs);
    await restored.load();
    expect(restored.enabled, isTrue);
    expect(restored.endpoint, 'https://relay.example.com');
    canChange = false;
    await expectLater(settings.useSupabase(), throwsStateError);
    await expectLater(
        settings.configure('https://other.example.com'), throwsStateError);
    expect(settings.endpoint, 'https://relay.example.com');
    canChange = true;
    await settings.useSupabase();
    expect(settings.enabled, isFalse);
    expect(settings.configured, isTrue);
    await settings.reset();
    expect(settings.endpoint, isNull);
    settings.dispose();
    restored.dispose();
  });
}
