import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'torrent_models.dart';

/// TorrServer identifies torrents by a 40-character hex hash. Add-ons may
/// supply the equivalent 32-character base32 BitTorrent v1 hash.
String? canonicalIosTorrentHash(String value) {
  final match = RegExp(r'urn:btih:([a-zA-Z0-9]{32,40})(?![a-zA-Z0-9])',
          caseSensitive: false)
      .firstMatch(value);
  final raw = (match?.group(1) ?? value).trim().toLowerCase();
  if (RegExp(r'^[0-9a-f]{40}$').hasMatch(raw)) return raw;
  if (!RegExp(r'^[a-z2-7]{32}$').hasMatch(raw)) return null;
  const alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
  var bits = 0;
  var buffer = 0;
  final bytes = <int>[];
  for (final character in raw.split('')) {
    buffer = (buffer << 5) | alphabet.indexOf(character);
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.add((buffer >> bits) & 0xff);
      buffer &= (1 << bits) - 1;
    }
  }
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

/// Talks only to the embedded iOS engine on its loopback HTTP listener.
/// The native bridge owns the listener; no remote torrent service is involved.
class IosTorrentService {
  IosTorrentService._();

  static final instance = IosTorrentService._();
  static const _channel = MethodChannel('noor/ios_torrent');
  Uri? _base;
  String? _activeHash;
  HttpClient? _http;

  Future<bool> get isSupported async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<Uri> start() async {
    final current = _base;
    if (current != null) return current;
    try {
      final raw = await _channel.invokeMethod<String>('start');
      final uri = raw == null ? null : Uri.tryParse(raw);
      if (uri == null ||
          uri.scheme != 'http' ||
          uri.host != '127.0.0.1' ||
          uri.port == 0) {
        throw const TorrentException(
            'unavailable', 'Invalid local torrent URL');
      }
      return _base = uri;
    } on PlatformException catch (error) {
      throw TorrentException(error.code, 'iOS torrent engine failed to start');
    } on MissingPluginException {
      throw const TorrentException(
          'unavailable', 'iOS torrent engine is absent');
    }
  }

  Future<PreparedTorrent> prepare({
    required String infoHash,
    required String magnet,
    String? filename,
    int? fileIndex,
  }) async {
    final hash = canonicalIosTorrentHash(infoHash);
    if (hash == null) {
      throw const TorrentException(
          'invalid_magnet', 'A v1 torrent hash is required');
    }
    final base = await start();
    final previous = _activeHash;
    if (previous != null && previous != hash) {
      await remove(previous, deleteFiles: false);
    }
    final metadata = await resolve(magnet, infoHash: hash);
    final target = selectTorrentFile(metadata, filename, fileIndex);
    if (target == null) {
      throw const TorrentException(
          'no_files', 'Torrent contains no playable file');
    }
    // TorrServer's HTTP file IDs are one-based; addon fileIdx is zero-based.
    final stream = base.replace(pathSegments: [
      'stream',
      target.name.split('/').last
    ], queryParameters: <String, String>{
      'link': hash,
      'index': '${target.index + 1}',
      'play': '',
    });
    _activeHash = hash;
    return PreparedTorrent(
      infoHash: hash,
      url: stream.toString(),
      statusStream: _statuses(base, hash, target.size),
      onStop: () => remove(hash, deleteFiles: false),
    );
  }

  Future<TorrentMetadata> resolve(String magnet, {String? infoHash}) async {
    final hash = canonicalIosTorrentHash(infoHash ?? magnet);
    if (hash == null) {
      throw const TorrentException(
          'invalid_magnet', 'A v1 torrent hash is required');
    }
    final base = await start();
    await _request(base, 'add', <String, Object?>{'link': magnet});
    final status = await _waitForFiles(base, hash);
    if (status['hash'] != null &&
        status['hash'].toString().toLowerCase() != hash) {
      throw const TorrentException(
          'hash_mismatch', 'Torrent metadata hash mismatch');
    }
    final rawFiles = status['file_stats'] as List? ?? const [];
    final files = <TorrentFileInfo>[
      for (final raw in rawFiles)
        if (raw is Map && raw['id'] is num && raw['path'] is String)
          TorrentFileInfo(
            index: (raw['id'] as num).toInt() - 1,
            name: raw['path'] as String,
            size: (raw['length'] as num?)?.toInt() ?? 0,
          ),
    ]..sort((a, b) => a.index.compareTo(b.index));
    return TorrentMetadata(
      name: (status['name'] ?? status['title'] ?? '').toString(),
      infoHash: hash,
      files: files,
    );
  }

  Future<void> remove(String hash, {required bool deleteFiles}) async {
    final base = _base;
    if (base == null) return;
    await _request(base, deleteFiles ? 'rem' : 'drop', {'hash': hash});
    if (_activeHash == hash) _activeHash = null;
  }

  Future<void> shutdown() async {
    _base = null;
    _activeHash = null;
    _http?.close(force: true);
    _http = null;
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // An older iOS build has no embedded engine.
    } on PlatformException {
      // The native side has already stopped.
    }
  }

  Future<Map<String, dynamic>> _waitForFiles(Uri base, String hash) async {
    final deadline = DateTime.now().add(const Duration(seconds: 55));
    while (DateTime.now().isBefore(deadline)) {
      Map<String, dynamic> status;
      try {
        status = await _request(base, 'get', {'hash': hash});
      } on TorrentException catch (error) {
        if (error.code != 'engine_http_404') rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        continue;
      }
      if (status['file_stats'] is List &&
          (status['file_stats'] as List).isNotEmpty) {
        return status;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw const TorrentException(
        'metadata_timeout', 'Torrent metadata timed out');
  }

  Stream<TorrentStatus> _statuses(Uri base, String hash, int fileSize) async* {
    while (_activeHash == hash) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (_activeHash != hash) break;
      Map<String, dynamic> state;
      try {
        state = await _request(base, 'get', {'hash': hash});
      } catch (_) {
        break;
      }
      final total = (state['torrent_size'] as num?)?.toInt() ?? 0;
      final loaded = (state['loaded_size'] as num?)?.toInt() ?? 0;
      yield TorrentStatus(
        infoHash: hash,
        progress: total > 0 ? (loaded / total).clamp(0.0, 1.0) : 0,
        downloadRate: (state['download_speed'] as num?)?.toInt() ?? 0,
        uploadRate: (state['upload_speed'] as num?)?.toInt() ?? 0,
        numPeers: (state['active_peers'] as num?)?.toInt() ?? 0,
        numSeeds: (state['connected_seeders'] as num?)?.toInt() ?? 0,
        state: (state['stat_string'] ?? 'checking').toString(),
        filePath: null,
        fileSize: fileSize,
        ready: (state['preload_size'] as num? ?? 0) > 0 &&
            (state['preloaded_bytes'] as num? ?? 0) >=
                (state['preload_size'] as num? ?? 0),
      );
    }
  }

  Future<Map<String, dynamic>> _request(
      Uri base, String action, Map<String, Object?> arguments) async {
    final client = _http ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 5);
    final request = await client.postUrl(base.resolve('/torrents'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'action': action, ...arguments}));
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != HttpStatus.ok) {
      throw TorrentException('engine_http_${response.statusCode}',
          'Local torrent engine request failed');
    }
    final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }
}
