import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart' show SubtitleTrack;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Imports a device file into NOVA's temporary area so its URI remains valid
/// when Android's document grant or the picker cache expires during playback.
/// The player engine parses the original format; no lossy text conversion is
/// performed here. Unsupported codecs surface through the normal player error.
Future<SubtitleTrack?> pickLocalSubtitleTrack() async {
  final picked = await FilePicker.pickFile(type: FileType.any);
  if (picked == null) return null;
  final extension = picked.extension?.toLowerCase() ?? '';
  // Let libmpv probe every format it supports, including extensionless files.
  final suffix =
      RegExp(r'^[a-z0-9]{1,10}$').hasMatch(extension) ? '.$extension' : '';
  final length = await picked.length();
  if (length == 0 || (length != null && length > 30 * 1024 * 1024)) {
    throw const FormatException('subtitleSize');
  }
  final cache = await getTemporaryDirectory();
  final directory =
      Directory('${cache.path}${Platform.pathSeparator}nova_player_subtitles');
  await directory.create(recursive: true);
  final file = File(
      '${directory.path}${Platform.pathSeparator}${const Uuid().v4()}$suffix');
  try {
    final sink = file.openWrite();
    var copied = 0;
    try {
      await for (final chunk in picked.readAsByteStream()) {
        copied += chunk.length;
        if (copied > 30 * 1024 * 1024) {
          throw const FormatException('subtitleSize');
        }
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }
    if (copied == 0) throw const FormatException('subtitleSize');
    return SubtitleTrack.uri(file.uri.toString(), title: picked.name);
  } catch (_) {
    if (await file.exists()) await file.delete();
    rethrow;
  }
}
