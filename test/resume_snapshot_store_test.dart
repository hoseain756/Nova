import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:nova_mobile/core/storage/resume_snapshot_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temp;
  late SharedPreferences preferences;
  late ResumeSnapshotStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    temp = await Directory.systemTemp.createTemp('nova-resume-snapshots-');
    store = ResumeSnapshotStore(
      preferences,
      supportDirectory: () async => temp,
    );
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('saves compressed local frame metadata outside synced history',
      () async {
    final source = image.Image(width: 1920, height: 1080);
    image.fill(source, color: image.ColorRgb8(24, 24, 28));
    final bytes = Uint8List.fromList(image.encodeJpg(source, quality: 90));
    final now = DateTime.utc(2026, 10, 19, 12);

    final snapshot = await store.save(
      itemId: 'tmdb:movie:42',
      frame: bytes,
      retentionDays: 30,
      now: now,
    );

    expect(snapshot, isNotNull);
    expect(File(snapshot!.path).existsSync(), isTrue);
    expect(image.decodeImage(File(snapshot.path).readAsBytesSync())!.width,
        lessThanOrEqualTo(960));
    expect(
      jsonDecode(preferences.getString(ResumeSnapshotStore.storageKey)!).keys,
      contains('tmdb:movie:42'),
    );
    expect(preferences.getString('horse.mobile.history'), isNull);
  });

  test('retention setting removes expired image files and records', () async {
    final oldFile = File('${temp.path}${Platform.pathSeparator}old.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    final recentFile = File('${temp.path}${Platform.pathSeparator}recent.jpg')
      ..writeAsBytesSync([4, 5, 6]);
    final now = DateTime.utc(2026, 10, 19, 12);
    await preferences.setString(
      ResumeSnapshotStore.storageKey,
      jsonEncode({
        'old': {
          'path': oldFile.path,
          'capturedAtMs':
              now.subtract(const Duration(days: 11)).millisecondsSinceEpoch,
        },
        'recent': {
          'path': recentFile.path,
          'capturedAtMs':
              now.subtract(const Duration(days: 9)).millisecondsSinceEpoch,
        },
      }),
    );

    final retained = await store.load(retentionDays: 10, now: now);

    expect(retained.keys, ['recent']);
    expect(oldFile.existsSync(), isFalse);
    expect(recentFile.existsSync(), isTrue);
  });
}
