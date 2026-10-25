import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ImportedSubtitleFont {
  const ImportedSubtitleFont(this.family, this.name);
  final String family;
  final String name;
}

/// Device-local font files. The selected family remains in AppState settings;
/// file bytes and this manifest never enter the cloud settings payload.
class SubtitleFontStore extends ChangeNotifier {
  SubtitleFontStore._({Directory? testDirectory, SharedPreferences? testPrefs})
      : _testDirectory = testDirectory,
        _testPrefs = testPrefs;
  @visibleForTesting
  SubtitleFontStore.forTesting(Directory directory, SharedPreferences prefs)
      : this._(testDirectory: directory, testPrefs: prefs);
  static final instance = SubtitleFontStore._();
  static const _manifestKey = 'nova.subtitleFonts.v1';
  static const _maxBytes = 10 * 1024 * 1024;
  final List<ImportedSubtitleFont> _fonts = [];
  final Directory? _testDirectory;
  final SharedPreferences? _testPrefs;
  bool _initialized = false;

  List<ImportedSubtitleFont> get fonts => List.unmodifiable(_fonts);

  Future<Directory> _directory() async {
    if (_testDirectory != null) {
      await _testDirectory.create(recursive: true);
      return _testDirectory;
    }
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}${Platform.pathSeparator}subtitle_fonts')
      ..createSync(recursive: true);
  }

  Future<SharedPreferences> _prefs() async =>
      _testPrefs ?? SharedPreferences.getInstance();

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await _prefs();
      final directory = await _directory();
      final rows = jsonDecode(prefs.getString(_manifestKey) ?? '[]');
      if (rows is! List) return;
      for (final row in rows) {
        if (row is! Map) continue;
        final family = row['family'];
        final name = row['name'];
        if (family is! String ||
            name is! String ||
            !RegExp(r'^NovaSubtitleUser_[a-f0-9-]{36}$').hasMatch(family)) {
          continue;
        }
        final file =
            File('${directory.path}${Platform.pathSeparator}$family.font');
        if (!await file.exists()) continue;
        try {
          await _load(family, await file.readAsBytes());
          _fonts.add(ImportedSubtitleFont(family, name));
        } catch (_) {
          // A damaged local file must not prevent NOVA from starting.
        }
      }
      notifyListeners();
    } catch (_) {
      // Picker support is optional on unsupported/test platforms.
    }
  }

  Future<ImportedSubtitleFont?> pickAndImport() async {
    final picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null) return null;
    final extension = picked.extension?.toLowerCase();
    if (extension != 'ttf' && extension != 'otf') {
      throw const FormatException('fontType');
    }
    final length = await picked.length();
    if (length == 0 || (length != null && length > _maxBytes)) {
      throw const FormatException('fontSize');
    }
    final bytes = await picked.readAsBytes();
    return importBytes(picked.name, bytes);
  }

  @visibleForTesting
  Future<ImportedSubtitleFont> importBytes(String name, Uint8List bytes) async {
    final extension = name.split('.').last.toLowerCase();
    if (extension != 'ttf' && extension != 'otf') {
      throw const FormatException('fontType');
    }
    if (bytes.isEmpty || bytes.length > _maxBytes) {
      throw const FormatException('fontSize');
    }
    if (!_validFont(bytes)) throw const FormatException('fontType');
    final family = 'NovaSubtitleUser_${const Uuid().v4()}';
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}$family.font');
    try {
      await file.writeAsBytes(bytes, flush: true);
      await _load(family, bytes);
      final font = ImportedSubtitleFont(family, name);
      _fonts.add(font);
      await _save();
      notifyListeners();
      return font;
    } catch (_) {
      _fonts.removeWhere((font) => font.family == family);
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<void> remove(String family) async {
    if (!RegExp(r'^NovaSubtitleUser_[a-f0-9-]{36}$').hasMatch(family)) {
      return;
    }
    _fonts.removeWhere((font) => font.family == family);
    await _save();
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}$family.font');
    if (await file.exists()) await file.delete();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await _prefs();
    await prefs.setString(
      _manifestKey,
      jsonEncode([
        for (final font in _fonts) {'family': font.family, 'name': font.name},
      ]),
    );
  }

  static bool _validFont(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final tag = String.fromCharCodes(bytes.take(4));
    return tag == 'OTTO' ||
        tag == 'true' ||
        (bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0);
  }

  static Future<void> _load(String family, Uint8List bytes) async {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}
