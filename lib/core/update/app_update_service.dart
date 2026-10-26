import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const String novaUpdateManifestUrl =
    'https://raw.githubusercontent.com/hoseain756/Nova/main/version.json';

enum AppUpdateOperation { check, download, install }

enum AppUpdateFailure {
  checkFailed,
  connectionUnavailable,
  manifestUnavailable,
  invalidManifest,
  invalidUrl,
  storageUnavailable,
  apkUnavailable,
  downloadFailed,
  invalidApk,
  missingApk,
  installerPermission,
  installerUnavailable,
  installerFailed,
  iosUnavailable,
  iosOpenFailed,
  unsupportedPlatform,
}

String appUpdateMessageKey(AppUpdateFailure failure) => switch (failure) {
      AppUpdateFailure.checkFailed => 'updateCheckFailed',
      AppUpdateFailure.connectionUnavailable => 'updateConnectionFailed',
      AppUpdateFailure.manifestUnavailable => 'updateServiceUnavailable',
      AppUpdateFailure.invalidManifest => 'updateManifestInvalid',
      AppUpdateFailure.invalidUrl => 'updateLinkInvalid',
      AppUpdateFailure.storageUnavailable => 'updateStorageFailed',
      AppUpdateFailure.apkUnavailable => 'updateApkUnavailable',
      AppUpdateFailure.downloadFailed => 'updateDownloadFailed',
      AppUpdateFailure.invalidApk => 'updateApkInvalid',
      AppUpdateFailure.missingApk => 'updateApkMissing',
      AppUpdateFailure.installerPermission => 'updateInstallerPermission',
      AppUpdateFailure.installerUnavailable => 'updateInstallerUnavailable',
      AppUpdateFailure.installerFailed => 'updateInstallerFailed',
      AppUpdateFailure.iosUnavailable => 'updateIosUnavailable',
      AppUpdateFailure.iosOpenFailed => 'updateIosOpenFailed',
      AppUpdateFailure.unsupportedPlatform => 'updateUnsupportedPlatform',
    };

AppUpdateFailure classifyAppUpdateFailure(
  Object error, {
  required AppUpdateOperation operation,
}) {
  if (error is AppUpdateException) return error.failure;
  if (error is FormatException) return AppUpdateFailure.invalidManifest;
  if (error is FileSystemException) return AppUpdateFailure.storageUnavailable;
  if (error is SocketException ||
      error is HandshakeException ||
      error is TimeoutException) {
    return AppUpdateFailure.connectionUnavailable;
  }
  if (error is DioException) {
    final cause = error.error;
    if (cause is SocketException ||
        cause is HandshakeException ||
        cause is TimeoutException) {
      return AppUpdateFailure.connectionUnavailable;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return AppUpdateFailure.connectionUnavailable;
      case DioExceptionType.badResponse:
        if (operation == AppUpdateOperation.check) {
          return AppUpdateFailure.manifestUnavailable;
        }
        if (error.response?.statusCode == HttpStatus.notFound) {
          return AppUpdateFailure.apkUnavailable;
        }
        return AppUpdateFailure.downloadFailed;
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        break;
    }
  }
  return switch (operation) {
    AppUpdateOperation.check => AppUpdateFailure.checkFailed,
    AppUpdateOperation.download => AppUpdateFailure.downloadFailed,
    AppUpdateOperation.install => AppUpdateFailure.installerFailed,
  };
}

class AppUpdateManifest {
  const AppUpdateManifest({
    required this.latestVersion,
    required this.latestBuild,
    required this.minBuild,
    required this.messageAr,
    required this.androidUrl,
    required this.iosUrl,
  });

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    String stringValue(String key) {
      final value = json[key];
      if (value is! String) {
        throw FormatException('Missing update field: $key');
      }
      return value.trim();
    }

    int intValue(String key) {
      final value = json[key];
      final parsed = value is int ? value : int.tryParse('$value');
      if (parsed == null || parsed < 0) {
        throw FormatException('Invalid update field: $key');
      }
      return parsed;
    }

    final manifest = AppUpdateManifest(
      latestVersion: stringValue('latest_version'),
      latestBuild: intValue('latest_build'),
      minBuild: intValue('min_build'),
      messageAr: stringValue('message_ar'),
      androidUrl: stringValue('android_url'),
      iosUrl: stringValue('ios_url'),
    );
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(manifest.latestVersion) ||
        manifest.latestBuild == 0 ||
        manifest.minBuild > manifest.latestBuild) {
      throw const FormatException('Invalid update version metadata');
    }
    final androidUri = Uri.tryParse(manifest.androidUrl);
    if (androidUri == null ||
        androidUri.scheme != 'https' ||
        androidUri.host.isEmpty) {
      throw const FormatException('Invalid Android update URL');
    }
    return manifest;
  }

  final String latestVersion;
  final int latestBuild;
  final int minBuild;
  final String messageAr;
  final String androidUrl;
  final String iosUrl;
}

class AppUpdateStatus {
  const AppUpdateStatus({
    required this.manifest,
    required this.currentVersion,
    required this.currentBuild,
    this.platform = AppUpdatePlatform.android,
  });

  final AppUpdateManifest manifest;
  final String currentVersion;
  final int currentBuild;
  final AppUpdatePlatform platform;

  // The current manifest's build numbers and minimum build describe the
  // Android APK. iOS needs its own release metadata before it can offer or
  // require an update; the Android minimum must never lock an iPhone out.
  bool get hasUpdate =>
      platform == AppUpdatePlatform.android &&
      manifest.latestBuild > currentBuild;
  bool get forceRequired =>
      platform == AppUpdatePlatform.android && currentBuild < manifest.minBuild;
}

enum AppUpdatePlatform { android, ios }

class AppUpdateException implements Exception {
  const AppUpdateException(this.failure, [this.cause]);

  final AppUpdateFailure failure;
  final Object? cause;
}

class AppUpdateService {
  AppUpdateService({
    Dio? dio,
    Future<Directory> Function()? temporaryDirectoryProvider,
    Future<PackageInfo> Function()? packageInfoProvider,
    Future<OpenResult> Function(String path)? apkOpener,
  })  : _dio = dio ?? Dio(),
        _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory,
        _packageInfoProvider = packageInfoProvider ?? PackageInfo.fromPlatform,
        _apkOpener = apkOpener ??
            ((path) => OpenFilex.open(
                  path,
                  type: 'application/vnd.android.package-archive',
                ));

  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final Future<PackageInfo> Function() _packageInfoProvider;
  final Future<OpenResult> Function(String path) _apkOpener;

  Future<AppUpdateStatus> checkForUpdates() async {
    final packageInfo = await _packageInfoProvider();
    final response = await _dio.get<Object?>(
      novaUpdateManifestUrl,
      options: Options(
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      ),
    );
    final responseData = response.data;
    final Object? decodedData;
    if (responseData is String) {
      try {
        decodedData = jsonDecode(responseData);
      } on FormatException catch (error) {
        throw FormatException('Invalid update manifest JSON: ${error.message}');
      }
    } else {
      decodedData = responseData;
    }
    if (decodedData is! Map) {
      throw const FormatException('Invalid update manifest');
    }
    final manifest = AppUpdateManifest.fromJson(
      Map<String, dynamic>.from(decodedData),
    );
    return AppUpdateStatus(
      manifest: manifest,
      currentVersion: packageInfo.version,
      currentBuild: int.tryParse(packageInfo.buildNumber) ?? 0,
      platform:
          Platform.isIOS ? AppUpdatePlatform.ios : AppUpdatePlatform.android,
    );
  }

  Future<File> downloadAndroidApk(
    String url, {
    required void Function(int received, int total) onProgress,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const AppUpdateException(AppUpdateFailure.invalidUrl);
    }

    late final File file;
    try {
      final directory = await _temporaryDirectoryProvider();
      await directory.create(recursive: true);
      file = File(
        '${directory.path}${Platform.pathSeparator}app-release.apk',
      );
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      throw AppUpdateException(AppUpdateFailure.storageUnavailable, error);
    } catch (error) {
      throw AppUpdateException(AppUpdateFailure.storageUnavailable, error);
    }

    try {
      await _dio.download(
        uri.toString(),
        file.path,
        onReceiveProgress: onProgress,
        deleteOnError: true,
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      if (!await file.exists() || await file.length() == 0) {
        throw const AppUpdateException(AppUpdateFailure.invalidApk);
      }
      final handle = await file.open(mode: FileMode.read);
      final signature = await handle.read(4);
      await handle.close();
      if (signature.length < 4 ||
          signature[0] != 0x50 ||
          signature[1] != 0x4b) {
        await file.delete();
        throw const AppUpdateException(AppUpdateFailure.invalidApk);
      }
      return file;
    } on AppUpdateException {
      rethrow;
    } on FileSystemException catch (error) {
      throw AppUpdateException(AppUpdateFailure.storageUnavailable, error);
    }
  }

  Future<void> installAndroidApk(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const AppUpdateException(AppUpdateFailure.missingApk);
    }
    if (await file.length() == 0) {
      throw const AppUpdateException(AppUpdateFailure.invalidApk);
    }
    final result = await _apkOpener(filePath);
    switch (result.type) {
      case ResultType.done:
        return;
      case ResultType.fileNotFound:
        throw const AppUpdateException(AppUpdateFailure.missingApk);
      case ResultType.noAppToOpen:
        throw const AppUpdateException(AppUpdateFailure.installerUnavailable);
      case ResultType.permissionDenied:
        throw const AppUpdateException(AppUpdateFailure.installerPermission);
      case ResultType.error:
        throw const AppUpdateException(AppUpdateFailure.installerFailed);
    }
  }
}
