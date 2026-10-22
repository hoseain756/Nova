import 'package:media_kit/media_kit.dart' show SubtitleTrack;

import '../../../core/api/noor_api.dart';

/// Downloads add-on subtitles through the app HTTP client and gives media_kit
/// their text as data. Some subtitle hosts return valid SRT files that libmpv
/// cannot open directly from their remote URL.
Future<SubtitleTrack> loadExternalSubtitleTrack(
  NoorApi api,
  SubtitleTrack track,
) async {
  if (!track.uri || track.id.isEmpty) return track;

  final text =
      await api.proxyText(track.id).timeout(const Duration(seconds: 20));
  final content = text.trimLeft();
  final lower = content.toLowerCase();
  if (content.isEmpty ||
      lower.startsWith('<!doctype html') ||
      lower.startsWith('<html')) {
    throw const FormatException('Subtitle URL did not return subtitle text.');
  }

  return SubtitleTrack.data(
    text,
    title: track.title,
    language: track.language,
  );
}
