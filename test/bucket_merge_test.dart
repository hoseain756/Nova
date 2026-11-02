import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/sync/bucket_merge.dart';

void main() {
  test('settings merge preserves independent local and remote edits', () {
    final merged = mergeBucketPayload(
      bucket: 'settings',
      base: {
        'settings': {'themeMode': 'dark', 'uiLanguage': 'en'}
      },
      local: {
        'settings': {'themeMode': 'light', 'uiLanguage': 'en'}
      },
      remote: {
        'settings': {'themeMode': 'dark', 'uiLanguage': 'ar'}
      },
    );
    expect(merged['settings'], {'themeMode': 'light', 'uiLanguage': 'ar'});
  });

  test('watchlist merge keeps independent additions and explicit deletion', () {
    final merged = mergeBucketPayload(
      bucket: 'watchlist',
      base: {
        'watchlist': [
          {'id': 'old'}
        ]
      },
      local: {
        'watchlist': [
          {'id': 'local'}
        ]
      },
      remote: {
        'watchlist': [
          {'id': 'old'},
          {'id': 'remote'}
        ]
      },
    );
    expect((merged['watchlist'] as List).map((row) => row['id']).toList(),
        ['local', 'remote']);
  });

  test('same-field conflict favors the current device', () {
    final merged = mergeBucketPayload(
      bucket: 'history',
      base: {
        'history': [
          {'id': 'film', 'positionMs': 10}
        ]
      },
      local: {
        'history': [
          {'id': 'film', 'positionMs': 20}
        ]
      },
      remote: {
        'history': [
          {'id': 'film', 'positionMs': 30}
        ]
      },
    );
    expect((merged['history'] as List).single['positionMs'], 20);
  });
}
