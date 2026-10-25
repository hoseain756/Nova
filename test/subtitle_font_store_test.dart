import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/storage/subtitle_font_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imported font survives store reinitialization and can be removed',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final directory = await Directory.systemTemp.createTemp('nova-font-test-');
    addTearDown(() => directory.delete(recursive: true));
    final bytes = await File('assets/fonts/Tajawal-Regular.ttf').readAsBytes();

    final store = SubtitleFontStore.forTesting(directory, prefs);
    final imported = await store.importBytes('Arabic.ttf', bytes);
    expect(store.fonts.single.name, 'Arabic.ttf');
    expect(await File('${directory.path}/${imported.family}.font').exists(),
        isTrue);

    final restarted = SubtitleFontStore.forTesting(directory, prefs);
    await restarted.initialize();
    expect(restarted.fonts.single.family, imported.family);
    expect(restarted.fonts.single.name, 'Arabic.ttf');

    await restarted.remove(imported.family);
    expect(restarted.fonts, isEmpty);
    expect(await File('${directory.path}/${imported.family}.font').exists(),
        isFalse);
  });

  test('rejects a renamed non-font file', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final directory = await Directory.systemTemp.createTemp('nova-font-test-');
    addTearDown(() => directory.delete(recursive: true));
    final store = SubtitleFontStore.forTesting(directory, prefs);
    await expectLater(
      store.importBytes('fake.ttf', Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<FormatException>()),
    );
    expect(store.fonts, isEmpty);
  });
}
