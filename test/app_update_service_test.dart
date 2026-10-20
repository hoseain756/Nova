import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/update/app_update_service.dart';

void main() {
  const manifestJson = <String, dynamic>{
    'latest_version': '1.2.57',
    'latest_build': 61,
    'min_build': 60,
    'message_ar': 'يتوفر تحديث جديد.',
    'android_url':
        'https://github.com/hoseain756/Nova/releases/latest/download/app-release.apk',
    'ios_url': '',
  };

  test('parses the release metadata and direct APK URL', () {
    final manifest = AppUpdateManifest.fromJson(manifestJson);

    expect(manifest.latestVersion, '1.2.57');
    expect(manifest.latestBuild, 61);
    expect(manifest.minBuild, 60);
    expect(
      manifest.androidUrl,
      'https://github.com/hoseain756/Nova/releases/latest/download/app-release.apk',
    );
  });

  test('distinguishes available and forced updates by build number', () {
    final manifest = AppUpdateManifest.fromJson(manifestJson);
    final optional = AppUpdateStatus(
      manifest: manifest,
      currentVersion: '1.2.56',
      currentBuild: 60,
    );
    final forced = AppUpdateStatus(
      manifest: manifest,
      currentVersion: '1.2.55',
      currentBuild: 59,
    );

    expect(optional.hasUpdate, isTrue);
    expect(optional.forceRequired, isFalse);
    expect(forced.hasUpdate, isTrue);
    expect(forced.forceRequired, isTrue);
  });

  test('rejects invalid or non-HTTPS APK URLs', () {
    expect(
      () => AppUpdateManifest.fromJson({
        ...manifestJson,
        'android_url': 'http://example.com/app.apk',
      }),
      throwsFormatException,
    );
    expect(
      () => AppUpdateManifest.fromJson({
        ...manifestJson,
        'latest_build': -1,
      }),
      throwsFormatException,
    );
  });
}
