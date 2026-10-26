import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../torrent/torrent_models.dart';
import '../torrent/torrent_service.dart';
import '../../l10n/nova_strings.dart';

class NovaDownload {
  NovaDownload(
      {required this.id,
      required this.title,
      required this.path,
      this.poster,
      this.status = 'queued',
      this.received = 0,
      this.total = 0,
      this.error,
      this.systemId,
      this.sourceType = 'http',
      this.iosBackground = false,
      this.english = false});
  final String id, title, path;
  final String? poster;
  String status;
  int received, total;

  /// Stable diagnostic code; never contains a provider URL or credential.
  String? error;

  /// Android DownloadManager id. Null for legacy and non-Android jobs.
  int? systemId;
  final String sourceType;
  final bool iosBackground;
  final bool english;
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'path': path,
        if (poster != null && poster!.isNotEmpty) 'poster': poster,
        'status': status,
        'received': received,
        'total': total,
        if (error != null) 'error': error,
        if (systemId != null) 'systemId': systemId,
        if (sourceType != 'http') 'sourceType': sourceType,
        if (iosBackground) 'iosBackground': true,
        if (english) 'english': true,
      };
  factory NovaDownload.fromJson(Map<String, dynamic> json) => NovaDownload(
      id: json['id'] as String,
      title: json['title'] as String,
      path: json['path'] as String,
      poster: json['poster'] is String ? json['poster'] as String : null,
      status: json['status'] as String? ?? 'failed',
      received: (json['received'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
      systemId: (json['systemId'] as num?)?.toInt(),
      sourceType: json['sourceType'] == 'torrent' ? 'torrent' : 'http',
      iosBackground: json['iosBackground'] == true,
      english: json['english'] == true);
}

/// Standalone video downloads. Sources stay in secure storage; metadata is local.
/// Mutations and persistence are serialized independently of the network worker.
/// Cancellation settles the active writer before Retry or Remove can proceed.
class DownloadManager extends ChangeNotifier {
  DownloadManager._()
      : this._withDependencies(
          downloadDirectory: () async {
            final root = Platform.isAndroid
                ? await getExternalStorageDirectory() ??
                    (throw const FileSystemException(
                        'External storage unavailable'))
                : await getApplicationDocumentsDirectory();
            return Directory(
                '${root.path}${Platform.pathSeparator}nova_downloads');
          },
          readMetadata: () async =>
              (await SharedPreferences.getInstance()).getString(_metadataKey),
          writeMetadata: (value) async {
            if (!await (await SharedPreferences.getInstance())
                .setString(_metadataKey, value)) {
              throw const FileSystemException(
                  'Download metadata could not be saved');
            }
          },
          readSecret: (key) => _secure.read(key: key),
          writeSecret: (key, value) => _secure.write(key: key, value: value),
          deleteSecret: (key) => _secure.delete(key: key),
        );

  @visibleForTesting
  DownloadManager.forTesting({
    required Future<Directory> Function() downloadDirectory,
    required Future<String?> Function() readMetadata,
    required Future<void> Function(String) writeMetadata,
    required Future<String?> Function(String) readSecret,
    required Future<void> Function(String, String) writeSecret,
    required Future<void> Function(String) deleteSecret,
    required Dio dio,
    bool nativeTorrentDownloads = false,
    bool nativeIosDownloads = false,
  }) : this._withDependencies(
            downloadDirectory: downloadDirectory,
            readMetadata: readMetadata,
            writeMetadata: writeMetadata,
            readSecret: readSecret,
            writeSecret: writeSecret,
            deleteSecret: deleteSecret,
            dio: dio,
            nativeTorrentDownloads: nativeTorrentDownloads,
            nativeIosDownloads: nativeIosDownloads);

  DownloadManager._withDependencies({
    required Future<Directory> Function() downloadDirectory,
    required Future<String?> Function() readMetadata,
    required Future<void> Function(String) writeMetadata,
    required Future<String?> Function(String) readSecret,
    required Future<void> Function(String, String) writeSecret,
    required Future<void> Function(String) deleteSecret,
    Dio? dio,
    bool? nativeTorrentDownloads,
    bool? nativeIosDownloads,
  })  : _downloadDirectory = downloadDirectory,
        _readMetadata = readMetadata,
        _writeMetadata = writeMetadata,
        _readSecret = readSecret,
        _writeSecret = writeSecret,
        _deleteSecret = deleteSecret,
        _nativeTorrentDownloads = nativeTorrentDownloads ?? Platform.isAndroid,
        _nativeIosDownloads = nativeIosDownloads ?? Platform.isIOS,
        _dio = dio ??
            Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 45)));

  static final instance = DownloadManager._();
  static const _secure = FlutterSecureStorage();
  static const _metadataKey = 'nova.downloads.v1';
  static const _systemChannel = MethodChannel('nova/downloads');
  static const _torrentChannel = MethodChannel('nova/torrent_downloads');
  static const _iosChannel = MethodChannel('nova/ios_downloads');
  static final _idPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false);
  static final _filePattern =
      RegExp(r'\.(mp4|mkv|webm|avi|mov|m4v)$', caseSensitive: false);
  final Future<Directory> Function() _downloadDirectory;
  final Future<String?> Function() _readMetadata;
  final Future<void> Function(String) _writeMetadata;
  final Future<String?> Function(String) _readSecret;
  final Future<void> Function(String, String) _writeSecret;
  final Future<void> Function(String) _deleteSecret;
  final Dio _dio;
  final bool _nativeTorrentDownloads;
  final bool _nativeIosDownloads;
  final _jobs = <NovaDownload>[];
  Future<void>? _initializing, _pumpFuture;
  Future<void> _operations = Future<void>.value();
  Future<void> _persistence = Future<void>.value();
  Directory? _root;
  Directory? _legacyRoot;
  CancelToken? _token;
  String? _activeId;
  Completer<void>? _activeDone;
  bool _disposed = false;
  bool initialized = false;

  /// Exposed so startup/storage errors are not mistaken for an empty library.
  String? initializationError;
  String? storageError;
  List<NovaDownload> get jobs => List.unmodifiable(_jobs);

  Future<void> initialize() {
    if (initialized) return Future<void>.value();
    return _initializing ??= _load().whenComplete(() {
      if (!initialized) _initializing = null;
    });
  }

  Future<void> _load() async {
    initializationError = null;
    try {
      final requested = await _downloadDirectory();
      final existingType =
          await FileSystemEntity.type(requested.path, followLinks: false);
      if (existingType != FileSystemEntityType.notFound &&
          existingType != FileSystemEntityType.directory) {
        throw const FileSystemException(
            'Download root is not a private directory');
      }
      await requested.create(recursive: true);
      final resolved = await requested.resolveSymbolicLinks();
      final parent = await requested.parent.resolveSymbolicLinks();
      final name =
          requested.uri.pathSegments.where((part) => part.isNotEmpty).last;
      if (_normalized(resolved) !=
              _normalized('$parent${Platform.pathSeparator}$name') ||
          await FileSystemEntity.type(requested.path, followLinks: false) !=
              FileSystemEntityType.directory) {
        throw const FileSystemException(
            'Download root cannot be a symbolic link');
      }
      _root = Directory(resolved);
      if (Platform.isAndroid && identical(this, instance)) {
        try {
          final documents = await getApplicationDocumentsDirectory();
          _legacyRoot = Directory(
              '${documents.path}${Platform.pathSeparator}nova_downloads');
        } catch (_) {
          // New system-managed downloads remain available.
        }
      }
      final raw = await _readMetadata();
      final loaded = <NovaDownload>[];
      var repaired = false;
      if (raw != null) {
        List<dynamic> rows;
        try {
          rows = jsonDecode(raw) as List<dynamic>;
        } catch (_) {
          rows = [];
          repaired = true;
        }
        final seen = <String>{};
        for (final row in rows) {
          try {
            if (row is! Map) {
              repaired = true;
              continue;
            }
            final job = NovaDownload.fromJson(Map<String, dynamic>.from(row));
            if (!seen.add(job.id) || !await _managedPath(job)) {
              repaired = true;
              continue;
            }
            if (job.received < 0 || job.total < 0) {
              repaired = true;
              continue;
            }
            if (!{'queued', 'downloading', 'failed', 'cancelled', 'complete'}
                .contains(job.status)) {
              job.status = 'failed';
              job.error = 'metadata';
              repaired = true;
            }
            if (_usesNativeTorrent(job)) {
              await _refreshNativeTorrent(job);
              repaired = true;
            } else if (job.systemId != null) {
              await _refreshSystemJob(job);
              repaired = true;
            } else if (_usesIosBackground(job)) {
              await _refreshIosJob(job);
              repaired = true;
            } else if (job.status == 'queued' || job.status == 'downloading') {
              job.status = 'failed';
              job.error = 'interrupted';
              repaired = true;
            }
            if (job.status == 'complete' &&
                !await _isVideoFile(File(job.path))) {
              job.status = 'failed';
              job.error = 'missingFile';
              repaired = true;
            }
            loaded.add(job);
          } catch (_) {
            repaired = true;
          }
        }
      }
      _jobs
        ..clear()
        ..addAll(loaded);
      initialized = true;
      if (repaired) await _persistSafely();
    } catch (_) {
      initializationError = 'storage';
      initialized = false;
    }
    _notify();
  }

  Future<void> _serial(Future<void> Function() action) {
    final result = _operations.then((_) async {
      if (_disposed) throw StateError('Download manager is closed');
      await initialize();
      if (!initialized) {
        throw const FileSystemException('Download storage is unavailable');
      }
      await action();
    });
    _operations =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> enqueue(
          {required String url,
          required String title,
          String? poster,
          bool english = false,
          Map<String, String> headers = const {}}) =>
      _serial(() async {
        final uri = _validateSource(url, headers);
        final id = const Uuid().v4();
        final extension =
            _filePattern.firstMatch(uri.path)?.group(1)?.toLowerCase() ?? 'mp4';
        final job = NovaDownload(
            id: id,
            title: title,
            poster: poster,
            path: '${_root!.path}${Platform.pathSeparator}$id.$extension',
            iosBackground: _nativeIosDownloads,
            english: english);
        if (!await _managedPath(job)) {
          throw const FileSystemException('Unsafe download destination');
        }
        final key = 'nova.download.$id';
        await _writeSecret(key, jsonEncode({'url': url, 'headers': headers}));
        _jobs.insert(0, job);
        try {
          await _persist();
        } catch (_) {
          _jobs.remove(job);
          try {
            await _deleteSecret(key);
          } catch (_) {/* Orphan secret has no public metadata. */}
          rethrow;
        }
        _notify();
        if (_usesAndroidSystem(job)) {
          try {
            job.systemId = await _systemChannel.invokeMethod<int>('enqueue', {
              'url': url,
              'title': title,
              'fileName': job.path.split(Platform.pathSeparator).last,
              'headers': headers,
            });
            if (job.systemId == null) {
              throw StateError('Download was not queued');
            }
            job.status = 'downloading';
            await _persist();
            _notify();
          } catch (_) {
            if (job.systemId != null) {
              try {
                await _systemChannel
                    .invokeMethod<int>('remove', {'id': job.systemId});
              } catch (_) {/* Keep the original failure. */}
              job.systemId = null;
            }
            job.status = 'failed';
            job.error = 'network';
            await _persistSafely();
            _notify();
            rethrow;
          }
        } else if (_usesIosBackground(job)) {
          await _startIosDownload(job);
        } else {
          _startPump();
        }
      });

  /// Android's service owns torrent transfers and their durable source hints.
  Future<void> enqueueTorrent({
    required TorrentStreamHints hints,
    required String title,
    String? poster,
    String? magnet,
    bool english = false,
  }) =>
      _serial(() async {
        if (!_nativeTorrentDownloads) {
          throw UnsupportedError('Native torrent downloads require Android');
        }
        if (!RegExp(r'^(?:[0-9a-f]{40}|[a-z2-7]{32})$')
            .hasMatch(hints.infoHash)) {
          throw const FormatException('Invalid torrent identifier');
        }
        final id = const Uuid().v4();
        final extension =
            _filePattern.firstMatch(hints.filename)?.group(1)?.toLowerCase() ??
                'mp4';
        final job = NovaDownload(
            id: id,
            title: title,
            poster: poster,
            path: '${_root!.path}${Platform.pathSeparator}$id.$extension',
            sourceType: 'torrent');
        if (!await _managedPath(job)) {
          throw const FileSystemException('Unsafe download destination');
        }
        final key = 'nova.download.$id';
        await _writeSecret(
            key,
            jsonEncode({
              'torrent': {
                'infoHash': hints.infoHash,
                'filename': hints.filename,
                'trackers': hints.trackers,
                'fileIndex': hints.fileIndex,
                'magnet': TorrentService.magnetFor(hints.infoHash,
                    dn: hints.filename,
                    extraTrackers: hints.trackers,
                    magnetUri: magnet),
                'english': english,
              }
            }));
        _jobs.insert(0, job);
        try {
          await _persist();
        } catch (_) {
          _jobs.remove(job);
          try {
            await _deleteSecret(key);
          } catch (_) {/* Original storage error wins. */}
          rethrow;
        }
        _notify();
        if (_usesNativeTorrent(job)) {
          await _startNativeTorrent(job);
        } else {
          _startPump();
        }
      });

  Future<void> retry(NovaDownload job) => _serial(() async {
        if (!_jobs.contains(job) ||
            job.status == 'complete' ||
            job.status == 'downloading' ||
            job.status == 'queued') {
          return;
        }
        await _settleActive(job);
        if (job.systemId != null) {
          await _systemChannel
              .invokeMethod<int>('remove', {'id': job.systemId});
          job.systemId = null;
          await _deleteManagedFile(job);
        }
        if (_usesIosBackground(job)) {
          await _deleteManagedFile(job);
        }
        if (!await _managedPath(job)) {
          throw const FileSystemException('Unsafe download destination');
        }
        job.status = 'queued';
        job.error = null;
        job.received = 0;
        job.total = 0;
        try {
          await _persist();
        } catch (_) {
          job.status = 'failed';
          job.error = 'storage';
          _notify();
          rethrow;
        }
        _notify();
        if (_usesAndroidSystem(job)) {
          try {
            final raw = await _readSecret('nova.download.${job.id}');
            if (raw == null) {
              throw const FormatException('Missing download source');
            }
            final source = jsonDecode(raw) as Map;
            job.systemId = await _systemChannel.invokeMethod<int>('enqueue', {
              'url': source['url'],
              'title': job.title,
              'fileName': job.path.split(Platform.pathSeparator).last,
              'headers': Map<String, String>.from(
                  source['headers'] as Map? ?? const {}),
            });
            if (job.systemId == null) {
              throw StateError('Download was not queued');
            }
            job.status = 'downloading';
            await _persist();
            _notify();
          } catch (_) {
            if (job.systemId != null) {
              try {
                await _systemChannel
                    .invokeMethod<int>('remove', {'id': job.systemId});
              } catch (_) {/* Keep the original failure. */}
              job.systemId = null;
            }
            job.status = 'failed';
            job.error = 'network';
            await _persistSafely();
            _notify();
            rethrow;
          }
        } else if (_usesNativeTorrent(job)) {
          await _startNativeTorrent(job);
        } else if (_usesIosBackground(job)) {
          await _startIosDownload(job);
        } else {
          _startPump();
        }
      });

  Future<void> cancel(NovaDownload job) => _serial(() async {
        if (!_jobs.contains(job) || job.status == 'complete') return;
        final previousStatus = job.status;
        job.status = 'cancelled';
        job.error = null;
        _notify();
        await _settleActive(job);
        if (_usesNativeTorrent(job)) {
          await _torrentChannel.invokeMethod<void>('cancel', {'id': job.id});
          await _refreshNativeTorrent(job);
        }
        if (_usesIosBackground(job)) {
          try {
            await _iosChannel.invokeMethod<void>('cancel', {'id': job.id});
          } catch (_) {
            job.status = previousStatus;
            _notify();
            rethrow;
          }
        }
        if (job.systemId != null) {
          await _systemChannel
              .invokeMethod<int>('remove', {'id': job.systemId});
          job.systemId = null;
        }
        await _persist();
        _notify();
      });

  Future<void> remove(NovaDownload job) => _serial(() async {
        if (!_jobs.contains(job)) return;
        final previous = job.status;
        if (previous != 'complete') job.status = 'cancelled';
        await _settleActive(job);
        if (_usesNativeTorrent(job)) {
          await _torrentChannel.invokeMethod<void>('remove', {'id': job.id});
        }
        if (_usesIosBackground(job)) {
          await _iosChannel.invokeMethod<void>('remove', {'id': job.id});
        }
        if (job.systemId != null) {
          await _systemChannel
              .invokeMethod<int>('remove', {'id': job.systemId});
          job.systemId = null;
        }
        // Validate the actual parent and reject links before every disk mutation.
        if (!await _managedPath(job)) {
          throw const FileSystemException('Unsafe download destination');
        }
        try {
          await _deleteManagedFile(job, partial: true);
          await _deleteManagedFile(job);
          await _deleteSecret('nova.download.${job.id}');
        } catch (_) {
          if (!await File(job.path).exists()) job.status = 'failed';
          job.error = 'storage';
          await _persistSafely();
          _notify();
          rethrow;
        }
        _jobs.remove(job);
        try {
          await _persist();
        } catch (_) {
          // Keep an honest visible failure if metadata removal could not be committed.
          job.status = 'failed';
          job.error = 'storage';
          _jobs.insert(0, job);
          _notify();
          rethrow;
        }
        _notify();
      });

  Future<void> _settleActive(NovaDownload job) async {
    if (_activeId != job.id) return;
    final done = _activeDone;
    _token?.cancel();
    if (done != null) await done.future;
  }

  bool _usesAndroidSystem(NovaDownload job) =>
      job.sourceType != 'torrent' &&
      Platform.isAndroid &&
      identical(this, instance) &&
      _root != null &&
      _normalized(job.path)
          .startsWith(_normalized('${_root!.path}${Platform.pathSeparator}'));

  bool _usesNativeTorrent(NovaDownload job) =>
      _nativeTorrentDownloads && job.sourceType == 'torrent';

  bool _usesIosBackground(NovaDownload job) =>
      _nativeIosDownloads && job.iosBackground && job.sourceType == 'http';

  Future<void> _startIosDownload(NovaDownload job) async {
    try {
      final raw = await _readSecret('nova.download.${job.id}');
      if (raw == null) throw const FormatException('Missing download source');
      final source = jsonDecode(raw) as Map;
      final url = source['url'] as String;
      final headers =
          Map<String, String>.from(source['headers'] as Map? ?? const {});
      _validateSource(url, headers);
      await _iosChannel.invokeMethod<void>('enqueue', {
        'id': job.id,
        'title': job.title,
        'fileName': job.path.split(Platform.pathSeparator).last,
        'url': url,
        'headers': headers,
        'labels': {
          'progress': NovaStrings.lookup(job.english, 'downloadInBackground'),
          'complete':
              NovaStrings.lookup(job.english, 'downloadCompleteNotification'),
          'stopped':
              NovaStrings.lookup(job.english, 'downloadStoppedNotification'),
        },
      });
      job.status = 'downloading';
      job.error = null;
      await _persistSafely();
    } catch (error) {
      job.status = 'failed';
      job.error = error is FormatException ||
              (error is PlatformException && error.code == 'invalid_source')
          ? 'invalidSource'
          : error is FileSystemException ||
                  (error is PlatformException && error.code == 'storage')
              ? 'storage'
              : 'network';
      await _persistSafely();
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<bool> _refreshIosJob(NovaDownload job) async {
    final previous = (job.status, job.received, job.total, job.error);
    try {
      final row = await _iosChannel
          .invokeMapMethod<String, dynamic>('query', {'id': job.id});
      if (row == null) {
        job.status = 'failed';
        job.error = 'interrupted';
      } else {
        final status = row['status'] as String?;
        job.status = {
          'queued',
          'downloading',
          'cancelled',
          'complete',
          'failed'
        }.contains(status)
            ? status!
            : 'failed';
        job.received =
            ((row['received'] as num?)?.toInt() ?? 0).clamp(0, 1 << 60).toInt();
        job.total =
            ((row['total'] as num?)?.toInt() ?? 0).clamp(0, 1 << 60).toInt();
        job.error = row['error'] as String?;
        if (job.status == 'complete' &&
            (!await _isVideoFile(File(job.path)) ||
                job.total <= 0 ||
                await File(job.path).length() != job.total)) {
          job.status = 'failed';
          job.error = 'missingFile';
        }
      }
    } catch (_) {
      // The OS-owned transfer continues even if Flutter cannot query it.
      return false;
    }
    return previous != (job.status, job.received, job.total, job.error);
  }

  Future<void> _startNativeTorrent(NovaDownload job) async {
    try {
      final raw = await _readSecret('nova.download.${job.id}');
      if (raw == null) throw const FormatException('Missing torrent source');
      final source =
          Map<String, dynamic>.from((jsonDecode(raw) as Map)['torrent'] as Map);
      await _torrentChannel.invokeMethod<void>('notificationPermission');
      await _torrentChannel.invokeMethod<void>('enqueue', {
        'id': job.id,
        'title': job.title,
        'fileName': job.path.split(Platform.pathSeparator).last,
        'source': source,
        'english': source['english'] == true,
        'labels': {
          for (final key in [
            'downloadInBackground',
            'downloadCompleteNotification',
            'downloadStoppedNotification'
          ])
            key: NovaStrings.lookup(source['english'] == true, key)
        },
      });
      job.status = 'downloading';
      await _persistSafely();
    } catch (_) {
      job.status = 'failed';
      job.error = 'backgroundLimit';
      await _persistSafely();
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<bool> _refreshNativeTorrent(NovaDownload job) async {
    final previous = (job.status, job.received, job.total, job.error);
    try {
      final row = await _torrentChannel
          .invokeMapMethod<String, dynamic>('query', {'id': job.id});
      if (row == null) {
        job.status = 'failed';
        job.error = 'interrupted';
      } else {
        final status = row['status'] as String?;
        job.status = {
          'queued',
          'downloading',
          'cancelled',
          'complete',
          'failed'
        }.contains(status)
            ? status!
            : 'failed';
        job.received =
            ((row['received'] as num?)?.toInt() ?? 0).clamp(0, 1 << 60);
        job.total = ((row['total'] as num?)?.toInt() ?? 0).clamp(0, 1 << 60);
        job.error = row['error'] as String?;
        if (job.status == 'complete' &&
            (!await _isVideoFile(File(job.path)) ||
                job.total <= 0 ||
                await File(job.path).length() != job.total)) {
          job.status = 'failed';
          job.error = 'missingFile';
        }
      }
    } catch (_) {
      return false;
    }
    return previous != (job.status, job.received, job.total, job.error);
  }

  /// Poll the OS-owned transfer while the Downloads screen is visible.
  /// Completion still happens and raises a system notification after exit.
  Future<void> refreshSystemDownloads() => _serial(() async {
        var changed = false;
        for (final job in _jobs.where((job) =>
            (job.systemId != null ||
                _usesNativeTorrent(job) ||
                _usesIosBackground(job)) &&
            (job.status == 'queued' || job.status == 'downloading'))) {
          changed = (_usesNativeTorrent(job)
                  ? await _refreshNativeTorrent(job)
                  : _usesIosBackground(job)
                      ? await _refreshIosJob(job)
                      : await _refreshSystemJob(job)) ||
              changed;
        }
        if (changed) {
          await _persistSafely();
          _notify();
        }
      });

  Future<bool> _refreshSystemJob(NovaDownload job) async {
    final id = job.systemId;
    if (id == null) return false;
    final previous = (job.status, job.received, job.total, job.error);
    try {
      final row = await _systemChannel
          .invokeMapMethod<String, dynamic>('query', {'id': id});
      if (row == null) {
        if (await _isVideoFile(File(job.path))) {
          job.status = 'complete';
          job.error = null;
        } else {
          job.status = 'failed';
          job.error = 'interrupted';
        }
      } else {
        job.received =
            ((row['received'] as num?)?.toInt() ?? 0).clamp(0, 1 << 60).toInt();
        job.total =
            ((row['total'] as num?)?.toInt() ?? 0).clamp(0, 1 << 60).toInt();
        final status = (row['status'] as num?)?.toInt();
        if (status == 8) {
          if (await _isVideoFile(File(job.path))) {
            job.status = 'complete';
            job.error = null;
          } else {
            job.status = 'failed';
            job.error = 'invalidSource';
          }
        } else if (status == 16) {
          job.status = 'failed';
          job.error = 'network';
        } else {
          job.status = status == 1 || status == 4 ? 'queued' : 'downloading';
          job.error = null;
        }
      }
    } catch (_) {
      // The OS transfer continues even if a UI status query fails.
      return false;
    }
    return previous != (job.status, job.received, job.total, job.error);
  }

  bool _queuedLocally(NovaDownload job) =>
      job.status == 'queued' &&
      !_usesAndroidSystem(job) &&
      !_usesNativeTorrent(job) &&
      !_usesIosBackground(job);

  void _startPump() {
    if (_disposed || _pumpFuture != null) return;
    _pumpFuture = _pump().whenComplete(() {
      _pumpFuture = null;
      if (!_disposed && _jobs.any(_queuedLocally)) {
        _startPump();
      }
    });
  }

  Future<void> _pump() async {
    while (!_disposed && _jobs.any(_queuedLocally)) {
      final job = _jobs.lastWhere(_queuedLocally);
      final token = CancelToken();
      final done = Completer<void>();
      _activeId = job.id;
      _token = token;
      _activeDone = done;
      job.status = 'downloading';
      job.error = null;
      _notify();
      var lastPaint = DateTime.now();
      try {
        if (!await _managedPath(job)) {
          throw const FileSystemException('Unsafe download destination');
        }
        final raw = await _readSecret('nova.download.${job.id}');
        if (raw == null) throw const FormatException('Missing download source');
        final source = jsonDecode(raw) as Map;
        final headers =
            Map<String, String>.from(source['headers'] as Map? ?? const {});
        final url = source['url'] as String;
        _validateSource(url, headers);
        if (token.isCancelled) continue;
        final partial = File('${job.path}.part');
        if (!await _managedPath(job, partial: true)) {
          throw const FileSystemException('Unsafe partial destination');
        }
        final response = await _dio.download(url, partial.path,
            options: Options(headers: headers),
            cancelToken: token,
            deleteOnError: false, onReceiveProgress: (received, total) {
          if (token.isCancelled || !_jobs.contains(job)) return;
          job.received = received;
          job.total = total > 0 ? total : 0;
          if (DateTime.now().difference(lastPaint).inMilliseconds >= 200) {
            lastPaint = DateTime.now();
            _notify();
          }
        });
        if (token.isCancelled ||
            job.status == 'cancelled' ||
            !_jobs.contains(job)) {
          continue;
        }
        final contentType =
            (response.headers.value('content-type') ?? '').toLowerCase();
        if (contentType.contains('text/') ||
            contentType.contains('json') ||
            contentType.contains('mpegurl') ||
            contentType.contains('dash+xml') ||
            !await _isVideoFile(partial)) {
          throw const FormatException(
              'Response is not a standalone video file');
        }
        final bytes = await partial.length();
        final expected =
            int.tryParse(response.headers.value('content-length') ?? '');
        // Compressed HTTP bodies may have a different transport length.
        if (expected != null &&
            response.headers.value('content-encoding') == null &&
            bytes != expected) {
          throw const FormatException('Incomplete download');
        }
        if (!await _managedPath(job) ||
            !await _managedPath(job, partial: true)) {
          throw const FileSystemException('Unsafe download destination');
        }
        await partial.rename(job.path);
        job.received = bytes;
        job.total = bytes;
        job.status = 'complete';
      } catch (error) {
        if (job.status != 'cancelled' && _jobs.contains(job)) {
          job.status = 'failed';
          job.error = error is FileSystemException
              ? 'storage'
              : error is FormatException
                  ? 'invalidSource'
                  : 'network';
        }
      } finally {
        try {
          await _deleteManagedFile(job, partial: true);
        } catch (_) {
          if (job.status != 'complete') job.error = 'storage';
        }
        await _persistSafely();
        _activeId = null;
        _token = null;
        _activeDone = null;
        _notify();
        done.complete();
      }
    }
  }

  Uri _validateSource(String url, Map<String, String> headers) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        RegExp(r'\.(m3u8|mpd)$', caseSensitive: false).hasMatch(uri.path) ||
        headers.entries.any((entry) =>
            RegExp(r'[\r\n]').hasMatch('${entry.key}${entry.value}'))) {
      throw const FormatException('A direct video file is required');
    }
    return uri;
  }

  String _normalized(String path) {
    final value = File(path).absolute.uri.normalizePath().toString();
    return Platform.isWindows ? value.toLowerCase() : value;
  }

  Future<bool> _managedPath(NovaDownload job, {bool partial = false}) async {
    if (_root == null || !_idPattern.hasMatch(job.id)) return false;
    final extension =
        _filePattern.firstMatch(job.path)?.group(1)?.toLowerCase();
    if (extension == null) return false;
    final parent = File(job.path).parent;
    if (_normalized(job.path) !=
            _normalized(
                '${parent.path}${Platform.pathSeparator}${job.id}.$extension') ||
        await FileSystemEntity.type(parent.path, followLinks: false) !=
            FileSystemEntityType.directory) {
      return false;
    }
    // Darwin can return /var/... while the same directory resolves to
    // /private/var/.... Compare the existing parent, not the leaf: a missing
    // download must remain a retryable row, and symlinked files stay forbidden.
    final resolvedParent = await parent.resolveSymbolicLinks();
    final roots = [_root!, if (_legacyRoot != null) _legacyRoot!];
    final root = roots
        .where((candidate) =>
            _normalized(resolvedParent) == _normalized(candidate.path))
        .firstOrNull;
    if (root == null || !await root.exists()) return false;
    if (_normalized(await root.resolveSymbolicLinks()) !=
        _normalized(root.path)) {
      return false;
    }
    final path = partial ? '${job.path}.part' : job.path;
    final type = await FileSystemEntity.type(path, followLinks: false);
    return type == FileSystemEntityType.notFound ||
        type == FileSystemEntityType.file;
  }

  Future<void> _deleteManagedFile(NovaDownload job,
      {bool partial = false}) async {
    if (!await _managedPath(job, partial: partial)) {
      throw const FileSystemException('Unsafe download destination');
    }
    final file = File(partial ? '${job.path}.part' : job.path);
    if (await file.exists()) await file.delete();
  }

  Future<bool> _isVideoFile(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() < 16) {
      return false;
    }
    final handle = await file.open();
    try {
      final bytes = await handle.read(64);
      bool asciiAt(int offset, String value) =>
          bytes.length >= offset + value.length &&
          List.generate(
                  value.length, (i) => bytes[offset + i] == value.codeUnitAt(i))
              .every((same) => same);
      return asciiAt(4, 'ftyp') || // ISO BMFF: MP4/M4V/QuickTime.
          (bytes[0] == 0x1a &&
              bytes[1] == 0x45 &&
              bytes[2] == 0xdf &&
              bytes[3] == 0xa3) || // Matroska/WebM.
          (asciiAt(0, 'RIFF') && (asciiAt(8, 'AVI ') || asciiAt(8, 'AVIX'))) ||
          asciiAt(4, 'moov') ||
          asciiAt(4, 'mdat'); // Older QuickTime containers.
    } finally {
      await handle.close();
    }
  }

  Future<void> _persist() {
    final value = jsonEncode(_jobs.map((job) => job.toJson()).toList());
    final result = _persistence.then((_) => _writeMetadata(value));
    _persistence = result.then<void>((_) {
      storageError = null;
    }, onError: (Object _, StackTrace __) {
      storageError = 'storage';
    });
    return result;
  }

  Future<void> _persistSafely() async {
    try {
      await _persist();
    } catch (_) {
      storageError = 'storage';
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @visibleForTesting
  Future<void> waitForIdle() async {
    await _operations;
    while (_pumpFuture != null) {
      await _pumpFuture;
    }
    await _persistence;
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel();
    super.dispose();
  }
}
