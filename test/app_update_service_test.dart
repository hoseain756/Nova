import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/update/app_update_service.dart';

void main() {
  const manifestJson = <String, dynamic>{
    'latest_version': '1.0.1',
    'latest_build': 64,
    'min_build': 60,
    'message_ar': 'يتوفر تحديث جديد.',
    'android_url':
        'https://github.com/hoseain756/Nova/releases/latest/download/app-release.apk',
    'ios_url': '',
  };

  test('parses release metadata and the direct APK URL', () {
    final manifest = AppUpdateManifest.fromJson(manifestJson);

    expect(manifest.latestVersion, '1.0.1');
    expect(manifest.latestBuild, 64);
    expect(manifest.minBuild, 60);
    expect(
      manifest.androidUrl,
      'https://github.com/hoseain756/Nova/releases/latest/download/app-release.apk',
    );
  });

  test('uses the build number as the source of update truth', () {
    final manifest = AppUpdateManifest.fromJson(manifestJson);
    final optional = AppUpdateStatus(
      manifest: manifest,
      currentVersion: '1.2.58',
      currentBuild: 62,
    );
    final forced = AppUpdateStatus(
      manifest: manifest,
      currentVersion: '1.2.55',
      currentBuild: 59,
    );
    final current = AppUpdateStatus(
      manifest: manifest,
      currentVersion: '1.0.0',
      currentBuild: 63,
    );

    expect(optional.hasUpdate, isTrue);
    expect(optional.forceRequired, isFalse);
    expect(forced.hasUpdate, isTrue);
    expect(forced.forceRequired, isTrue);
    expect(current.hasUpdate, isTrue);
    expect(current.forceRequired, isFalse);
    final latest = AppUpdateStatus(
      manifest: manifest,
      currentVersion: '1.0.1',
      currentBuild: 64,
    );
    expect(latest.hasUpdate, isFalse);
    expect(latest.forceRequired, isFalse);
  });

  test('rejects invalid version metadata and non-HTTPS APK URLs', () {
    expect(
      () => AppUpdateManifest.fromJson({
        ...manifestJson,
        'latest_version': '1.0',
      }),
      throwsFormatException,
    );
    expect(
      () => AppUpdateManifest.fromJson({
        ...manifestJson,
        'latest_build': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => AppUpdateManifest.fromJson({
        ...manifestJson,
        'min_build': 65,
      }),
      throwsFormatException,
    );
    expect(
      () => AppUpdateManifest.fromJson({
        ...manifestJson,
        'android_url': 'http://example.com/app.apk',
      }),
      throwsFormatException,
    );
  });

  test('maps connection, unavailable release, and malformed manifest errors',
      () {
    final timeout = DioException(
      requestOptions: RequestOptions(path: '/version.json'),
      type: DioExceptionType.connectionTimeout,
    );
    final notFound = DioException(
      requestOptions: RequestOptions(path: '/app-release.apk'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/app-release.apk'),
        statusCode: HttpStatus.notFound,
      ),
      type: DioExceptionType.badResponse,
    );

    expect(
      classifyAppUpdateFailure(timeout, operation: AppUpdateOperation.check),
      AppUpdateFailure.connectionUnavailable,
    );
    expect(
      classifyAppUpdateFailure(
        notFound,
        operation: AppUpdateOperation.download,
      ),
      AppUpdateFailure.apkUnavailable,
    );
    expect(
      classifyAppUpdateFailure(
        const FormatException('bad manifest'),
        operation: AppUpdateOperation.check,
      ),
      AppUpdateFailure.invalidManifest,
    );
    expect(
      appUpdateMessageKey(AppUpdateFailure.installerPermission),
      'updateInstallerPermission',
    );
  });
}
