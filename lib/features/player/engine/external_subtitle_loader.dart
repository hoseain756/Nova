import 'package:dio/dio.dart';
import 'package:media_kit/media_kit.dart' show SubtitleTrack;

import '../../../core/api/noor_api.dart';

class ExternalSubtitleException implements Exception {
  const ExternalSubtitleException(this.reason, {this.statusCode});

  final ExternalSubtitleFailure reason;
  final int? statusCode;

  @override
  String toString() => 'External subtitle $reason (HTTP $statusCode)';
}

enum ExternalSubtitleFailure { providerNoFile, http, invalidContent }

String externalSubtitleErrorMessageKey(Object error) {
  if (error is ExternalSubtitleException) {
    if (error.reason == ExternalSubtitleFailure.providerNoFile) {
      return 'subtitleProviderNoFile';
    }
    if (error.statusCode != null) return 'subtitleProviderHttpError';
  }
  return 'subtitleLoadFailed';
}

/// Downloads add-on subtitles through the app HTTP client and gives media_kit
/// their text as data. Some subtitle hosts return valid SRT files that libmpv
/// cannot open directly from their remote URL.
Future<SubtitleTrack> loadExternalSubtitleTrack(
  NoorApi api,
  SubtitleTrack track,
) async {
  if (!track.uri || track.id.isEmpty) return track;

  final String text;
  try {
    text = await api.proxyText(track.id).timeout(const Duration(seconds: 20));
  } on DioException catch (error) {
    final body = error.response?.data?.toString() ?? '';
    throw ExternalSubtitleException(
      body.contains('No supported subtitle file found in the subtitle archive')
          ? ExternalSubtitleFailure.providerNoFile
          : ExternalSubtitleFailure.http,
      statusCode: error.response?.statusCode,
    );
  }
  final content = text.trimLeft();
  final lower = content.toLowerCase();
  if (lower
      .contains('no supported subtitle file found in the subtitle archive')) {
    throw const ExternalSubtitleException(
        ExternalSubtitleFailure.providerNoFile);
  }
  if (content.isEmpty ||
      lower.startsWith('<!doctype html') ||
      lower.startsWith('<html') ||
      !_isSubtitleText(content)) {
    throw const ExternalSubtitleException(
        ExternalSubtitleFailure.invalidContent);
  }

  return SubtitleTrack.data(
    text,
    title: track.title,
    language: track.language,
  );
}

bool _isSubtitleText(String text) {
  final value = text.replaceFirst('\ufeff', '').trimLeft();
  return value.startsWith('WEBVTT') ||
      value.startsWith('[Script Info]') ||
      RegExp(r'\d{2}:\d{2}:\d{2}[,.]\d{3}\s+-->\s+\d{2}:\d{2}:\d{2}[,.]\d{3}')
          .hasMatch(value);
}
