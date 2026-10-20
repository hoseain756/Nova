import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const String novaUpdateManifestUrl =
    'https://raw.githubusercontent.com/hoseain756/Nova/main/version.json';

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
      return value;
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
  });

  final AppUpdateManifest manifest;
  final String currentVersion;
  final int currentBuild;

  bool get hasUpdate => manifest.latestBuild > currentBuild;
  bool get forceRequired => currentBuild < manifest.minBuild;
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AppUpdateService {
  AppUpdateService({
    Dio? dio,
    Future<Directory> Function()? temporaryDirectoryProvider,
    Future<PackageInfo> Function()? packageInfoProvider,
  })  : _dio = dio ?? Dio(),
        _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory,
        _packageInfoProvider = packageInfoProvider ?? PackageInfo.fromPlatform;

  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final Future<PackageInfo> Function() _packageInfoProvider;

  Future<AppUpdateStatus> checkForUpdates() async {
    final packageInfo = await _packageInfoProvider();
    final response = await _dio.get<Object?>(
      novaUpdateManifestUrl,
      options: Options(
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: const {'Accept': 'application/json'},
      ),
    );
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Invalid update manifest');
    }
    final manifest = AppUpdateManifest.fromJson(
      Map<String, dynamic>.from(data),
    );
    return AppUpdateStatus(
      manifest: manifest,
      currentVersion: packageInfo.version,
      currentBuild: int.tryParse(packageInfo.buildNumber) ?? 0,
    );
  }

  Future<File> downloadAndroidApk(
    String url, {
    required void Function(int received, int total) onProgress,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const AppUpdateException('Invalid Android update URL');
    }
    final directory = await _temporaryDirectoryProvider();
    final file = File(
      '${directory.path}${Platform.pathSeparator}app-release.apk',
    );
    if (await file.exists()) await file.delete();
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
      throw const AppUpdateException('The downloaded APK is empty');
    }
    return file;
  }

  Future<void> installAndroidApk(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw AppUpdateException(result.message);
    }
  }
}
