import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:nova_mobile/core/update/app_update_service.dart';
import 'package:nova_mobile/core/version.dart';

class _PlainTextJsonAdapter implements HttpClientAdapter {
  _PlainTextJsonAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        body,
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('root release manifest matches the app and updates the previous build',
      () {
    final manifest = AppUpdateManifest.fromJson(
        jsonDecode(File('version.json').readAsStringSync())
            as Map<String, dynamic>);
    expect(manifest.latestVersion, noorVersion);
    expect(manifest.latestBuild, noorBuild);
    expect(manifest.androidUrl,
        'https://github.com/novastremio/nova-mobile/releases/download/v$noorVersion/app-release.apk');
    expect(novaUpdateManifestUrl,
        'https://raw.githubusercontent.com/novastremio/nova-mobile/main/version.json');
    final previous = AppUpdateStatus(
        manifest: manifest, currentVersion: '1.0.10', currentBuild: 73);
    expect(previous.hasUpdate, isTrue);
    expect(previous.forceRequired, isTrue);
    final installed = AppUpdateStatus(
        manifest: manifest,
        currentVersion: noorVersion,
        currentBuild: noorBuild);
    expect(installed.hasUpdate, isFalse);
    expect(installed.forceRequired, isFalse);
  });

  const manifestJson = <String, dynamic>{
    'latest_version': '1.0.7',
    'latest_build': 70,
    'min_build': 60,
    'message_ar': 'يتوفر تحديث جديد.',
    'android_url':
        'https://github.com/novastremio/nova-mobile/releases/download/v1.0.7/app-release.apk',
    'ios_url': '',
  };

  test('decodes GitHub raw JSON served with a text/plain content type',
      () async {
    final dio = Dio()
      ..httpClientAdapter = _PlainTextJsonAdapter(jsonEncode(manifestJson));
    final service = AppUpdateService(
      dio: dio,
      packageInfoProvider: () async => PackageInfo(
        appName: 'NOVA',
        packageName: 'app.nova.mobile',
        version: '1.0.6',
        buildNumber: '69',
      ),
    );

    final status = await service.checkForUpdates();

    expect(status.manifest.latestBuild, 70);
    expect(status.hasUpdate, isTrue);
    expect(status.forceRequired, isFalse);
  });

  test('parses release metadata and the direct APK URL', () {
    final manifest = AppUpdateManifest.fromJson(manifestJson);

    expect(manifest.latestVersion, '1.0.7');
    expect(manifest.latestBuild, 70);
    expect(manifest.minBuild, 60);
    expect(
      manifest.androidUrl,
      'https://github.com/novastremio/nova-mobile/releases/download/v1.0.7/app-release.apk',
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
      currentVersion: '1.0.2',
      currentBuild: 65,
    );

    expect(optional.hasUpdate, isTrue);
    expect(optional.forceRequired, isFalse);
    expect(forced.hasUpdate, isTrue);
    expect(forced.forceRequired, isTrue);
    expect(current.hasUpdate, isTrue);
    expect(current.forceRequired, isFalse);
    final latest = AppUpdateStatus(
      manifest: manifest,
      currentVersion: '1.0.7',
      currentBuild: 70,
    );
    expect(latest.hasUpdate, isFalse);
    expect(latest.forceRequired, isFalse);
  });

  test('Android release metadata cannot force an iOS update', () {
    final manifest = AppUpdateManifest.fromJson(manifestJson);
    final ios = AppUpdateStatus(
      manifest: manifest,
      currentVersion: '1.0.1',
      currentBuild: 1,
      platform: AppUpdatePlatform.ios,
    );

    expect(ios.hasUpdate, isFalse);
    expect(ios.forceRequired, isFalse);
  });

  test('iOS compares its own build and requires an update destination', () {
    final manifest = AppUpdateManifest.fromJson({
      ...manifestJson,
      'ios_latest_version': '1.0.5',
      'ios_latest_build': 68,
      'ios_url': 'https://testflight.apple.com/join/example',
    });
    expect(
      AppUpdateStatus(
        manifest: manifest,
        currentVersion: '1.0.4',
        currentBuild: 67,
        platform: AppUpdatePlatform.ios,
      ).hasUpdate,
      isTrue,
    );
    expect(
      AppUpdateStatus(
        manifest: manifest,
        currentVersion: '1.0.5',
        currentBuild: 68,
        platform: AppUpdatePlatform.ios,
      ).hasUpdate,
      isFalse,
    );
    expect(
      AppUpdateStatus(
        manifest: AppUpdateManifest.fromJson({
          ...manifestJson,
          'ios_latest_version': '1.0.5',
          'ios_latest_build': 68,
        }),
        currentVersion: '1.0.4',
        currentBuild: 67,
        platform: AppUpdatePlatform.ios,
      ).hasUpdate,
      isFalse,
    );
    expect(
      AppUpdateStatus(
        manifest: manifest,
        currentVersion: '1.0.4',
        currentBuild: 67,
        platform: AppUpdatePlatform.ios,
      ).forceRequired,
      isFalse,
    );
  });

  test('iOS opens only a valid HTTPS update destination', () async {
    Uri? opened;
    final service = AppUpdateService(
      iosUpdateOpener: (uri) async {
        opened = uri;
        return true;
      },
    );
    await service.openIosUpdate('https://testflight.apple.com/join/example');
    expect(opened?.host, 'testflight.apple.com');
    await expectLater(
      service.openIosUpdate('https://example.com/Nova-release-unsigned.ipa'),
      throwsA(isA<AppUpdateException>().having(
        (error) => error.failure,
        'failure',
        AppUpdateFailure.iosUnavailable,
      )),
    );
    await expectLater(
      service.openIosUpdate('http://example.com/install'),
      throwsA(isA<AppUpdateException>().having(
        (error) => error.failure,
        'failure',
        AppUpdateFailure.iosUnavailable,
      )),
    );
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
        'min_build': (manifestJson['latest_build'] as int) + 1,
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
    expect(
      () => AppUpdateManifest.fromJson({
        ...manifestJson,
        'ios_latest_version': '1.0.5',
      }),
      throwsFormatException,
    );
    expect(
      () => AppUpdateManifest.fromJson({
        ...manifestJson,
        'ios_url': 'http://example.com/install',
      }),
      throwsFormatException,
    );
    expect(
      () => AppUpdateManifest.fromJson({
        ...manifestJson,
        'ios_url': 'https://example.com/Nova-release-unsigned.ipa',
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
