import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/storage/resume_snapshot_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('legacy frames import only into the chosen profile', () async {
    final dir = await Directory.systemTemp.createTemp('nova-resume-scope-');
    addTearDown(() => dir.delete(recursive: true));
    final frame = File('${dir.path}${Platform.pathSeparator}legacy.jpg');
    await frame.writeAsBytes([1, 2, 3]);
    SharedPreferences.setMockInitialValues({
      ResumeSnapshotStore.storageKey: jsonEncode({
        'film': {
          'path': frame.path,
          'capturedAtMs': DateTime.now().millisecondsSinceEpoch,
        }
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    Future<Directory> supportDirectory() async => dir;
    final first = ResumeSnapshotStore(prefs,
        scope: 'account-a/profile-a', supportDirectory: supportDirectory);
    final second = ResumeSnapshotStore(prefs,
        scope: 'account-a/profile-b', supportDirectory: supportDirectory);

    expect(await first.load(retentionDays: 30), isEmpty);
    expect(await second.load(retentionDays: 30), isEmpty);
    await first.importLegacy(retentionDays: 30);
    final imported = await first.load(retentionDays: 30);
    expect(imported.keys, ['film']);
    expect(imported['film']!.path, isNot(frame.path));
    expect(await second.load(retentionDays: 30), isEmpty);
    await first.clear();
    expect(await frame.exists(), isTrue);
  });
}
