import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class ResumeSnapshot {
  const ResumeSnapshot({required this.path, required this.capturedAtMs});

  final String path;
  final int capturedAtMs;

  Map<String, Object> toJson() => {'path': path, 'capturedAtMs': capturedAtMs};

  factory ResumeSnapshot.fromJson(Map<String, dynamic> json) => ResumeSnapshot(
        path: json['path']?.toString() ?? '',
        capturedAtMs: (json['capturedAtMs'] as num?)?.toInt() ?? 0,
      );
}

/// Device-local video frame storage for local resume cards.
///
/// Snapshot paths and bytes never enter synced watch-history/settings buckets.
class ResumeSnapshotStore {
  ResumeSnapshotStore(
    this._preferences, {
    Future<Directory> Function()? supportDirectory,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  static const storageKey = 'nova.local.resume-snapshots';
  static const maxSnapshots = 120;
  static const maxWidth = 960;

  final SharedPreferences _preferences;
  final Future<Directory> Function() _supportDirectory;

  Future<Map<String, ResumeSnapshot>> load({
    required int retentionDays,
    DateTime? now,
  }) async =>
      _prune(_decode(_preferences.getString(storageKey)),
          retentionDays: retentionDays, now: now);

  Future<ResumeSnapshot?> save({
    required String itemId,
    required Uint8List frame,
    required int retentionDays,
    DateTime? now,
  }) async {
    if (itemId.isEmpty || frame.isEmpty) return null;
    final jpeg = await compute(_resizeJpeg, frame);
    if (jpeg == null || jpeg.isEmpty) return null;

    final parent = await _supportDirectory();
    final separator = Platform.pathSeparator;
    final dir = Directory(
      '${parent.path}${separator}nova${separator}resume-snapshots',
    );
    await dir.create(recursive: true);
    final name = sha256.convert(utf8.encode(itemId)).toString();
    final path = '${dir.path}$separator$name.jpg';
    await File(path).writeAsBytes(jpeg, flush: true);

    final capturedAt = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final records = _decode(_preferences.getString(storageKey));
    records[itemId] = ResumeSnapshot(path: path, capturedAtMs: capturedAt);
    final pruned = await _prune(
      records,
      retentionDays: retentionDays,
      now: now,
      persist: false,
    );
    await _persist(pruned);
    return pruned[itemId];
  }

  Future<Map<String, ResumeSnapshot>> remove(String itemId) async {
    final records = _decode(_preferences.getString(storageKey));
    final removed = records.remove(itemId);
    if (removed != null) await _deleteFile(removed.path);
    await _persist(records);
    return records;
  }

  Future<Map<String, ResumeSnapshot>> clear() async {
    final records = _decode(_preferences.getString(storageKey));
    for (final value in records.values) {
      await _deleteFile(value.path);
    }
    await _preferences.remove(storageKey);
    return {};
  }

  Future<Map<String, ResumeSnapshot>> _prune(
    Map<String, ResumeSnapshot> records, {
    required int retentionDays,
    DateTime? now,
    bool persist = true,
  }) async {
    final cutoff = (now ?? DateTime.now())
        .subtract(Duration(days: retentionDays.clamp(1, 365)))
        .millisecondsSinceEpoch;
    final valid = <MapEntry<String, ResumeSnapshot>>[];
    for (final entry in records.entries) {
      final file = File(entry.value.path);
      if (entry.value.capturedAtMs < cutoff || !await file.exists()) {
        await _deleteFile(entry.value.path);
      } else {
        valid.add(entry);
      }
    }
    valid.sort((a, b) => b.value.capturedAtMs.compareTo(a.value.capturedAtMs));
    for (final excess in valid.skip(maxSnapshots)) {
      await _deleteFile(excess.value.path);
    }
    final kept = Map<String, ResumeSnapshot>.fromEntries(
      valid.take(maxSnapshots),
    );
    if (persist) await _persist(kept);
    return kept;
  }

  Map<String, ResumeSnapshot> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final records = <String, ResumeSnapshot>{};
      for (final entry in decoded.entries) {
        if (entry.value is! Map) continue;
        final snapshot = ResumeSnapshot.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (snapshot.path.isNotEmpty && snapshot.capturedAtMs > 0) {
          records[entry.key.toString()] = snapshot;
        }
      }
      return records;
    } catch (_) {
      return {};
    }
  }

  Future<void> _persist(Map<String, ResumeSnapshot> records) =>
      _preferences.setString(
        storageKey,
        jsonEncode(records.map((key, value) => MapEntry(key, value.toJson()))),
      );

  Future<void> _deleteFile(String path) async {
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A stale or already removed local image should never block playback.
    }
  }
}

Uint8List? _resizeJpeg(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) return null;
  final resized = decoded.width > ResumeSnapshotStore.maxWidth
      ? image.copyResize(decoded, width: ResumeSnapshotStore.maxWidth)
      : decoded;
  return Uint8List.fromList(image.encodeJpg(resized, quality: 78));
}
