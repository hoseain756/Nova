import 'package:flutter/material.dart';

enum ResumePlaybackAction { startOver, prompt, resume }

/// Pure policy helpers for translating persisted player settings into runtime
/// behavior. Keeping these decisions outside the widget makes preference
/// migrations and media-engine timing straightforward to test.
abstract final class NovaPlaybackPreferences {
  static const List<double> standardSpeeds = <double>[
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
  ];

  static ResumePlaybackAction resumeAction(
    Map<String, dynamic> settings,
    int? savedPositionMs,
  ) {
    if ((savedPositionMs ?? 0) <= 0 || settings['resumePlayback'] == false) {
      return ResumePlaybackAction.startOver;
    }
    return settings['resumePrompt'] == true && savedPositionMs! > 30000
        ? ResumePlaybackAction.prompt
        : ResumePlaybackAction.resume;
  }

  static int safeResumePositionMs(int? savedPositionMs, int durationMs) {
    if (durationMs <= 0) return 0;
    final upperBound = durationMs > 5000 ? durationMs - 5000 : 0;
    return (savedPositionMs ?? 0).clamp(0, upperBound).toInt();
  }

  static bool canRecordProgress({required bool awaitingResumeChoice}) =>
      !awaitingResumeChoice;

  static BoxFit videoFit(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'fill':
      case 'zoom':
        return BoxFit.cover;
      case 'fit':
      default:
        return BoxFit.contain;
    }
  }

  static List<double> playbackSpeeds(Object? configured, double current) {
    final values = <double>[];
    if (configured is Iterable) {
      for (final value in configured) {
        final parsed =
            value is num ? value.toDouble() : double.tryParse(value.toString());
        if (parsed != null &&
            parsed.isFinite &&
            parsed >= 0.25 &&
            parsed <= 4.0) {
          values.add(parsed);
        }
      }
    }
    if (values.isEmpty) values.addAll(standardSpeeds);
    if (current.isFinite && current >= 0.25 && current <= 4.0) {
      values.add(current);
    }
    values.sort();
    final result = <double>[];
    for (final value in values) {
      if (result.isEmpty || (result.last - value).abs() >= 0.001) {
        result.add(value);
      }
    }
    return result;
  }

  static int? preferredAudioTrack(
    List<PlaybackTrackLanguage> tracks,
    Object? preference,
  ) {
    final requested = canonicalLanguage(preference);
    if (requested == null ||
        requested == 'source' ||
        requested == 'original' ||
        requested == 'auto') {
      return null;
    }
    return _firstMatchingTrack(tracks, <String>[requested]);
  }

  static int? preferredSubtitleTrack(
    List<PlaybackTrackLanguage> tracks, {
    required Object? explicitLanguage,
    required Object? rankedLanguages,
  }) {
    final requested = <String>[];
    final explicit = canonicalLanguage(explicitLanguage);
    if (explicit != null && explicit != 'off' && explicit != 'auto') {
      requested.add(explicit);
    }
    if (rankedLanguages is Iterable) {
      for (final value in rankedLanguages) {
        final language = canonicalLanguage(value);
        if (language != null &&
            language != 'off' &&
            language != 'auto' &&
            !requested.contains(language)) {
          requested.add(language);
        }
      }
    }
    return _firstMatchingTrack(tracks, requested);
  }

  static bool subtitlesDisabled(Map<String, dynamic> settings) =>
      settings['subtitlesOffByDefault'] == true;

  static int? _firstMatchingTrack(
    List<PlaybackTrackLanguage> tracks,
    List<String> requested,
  ) {
    for (final language in requested) {
      for (var i = 0; i < tracks.length; i++) {
        if (tracks[i].matches(language)) return i;
      }
    }
    return null;
  }

  static String? canonicalLanguage(Object? value) {
    var raw = value?.toString().trim().toLowerCase() ?? '';
    if (raw.isEmpty) return null;
    raw = raw.replaceAll('_', '-');
    final primary = raw.split('-').first;
    const aliases = <String, String>{
      'ar': 'ar',
      'ara': 'ar',
      'arabic': 'ar',
      'العربية': 'ar',
      'en': 'en',
      'eng': 'en',
      'english': 'en',
      'الإنجليزية': 'en',
      'ja': 'ja',
      'jp': 'ja',
      'jpn': 'ja',
      'japanese': 'ja',
      'اليابانية': 'ja',
      'fr': 'fr',
      'fra': 'fr',
      'fre': 'fr',
      'french': 'fr',
      'الفرنسية': 'fr',
      'es': 'es',
      'spa': 'es',
      'spanish': 'es',
      'الإسبانية': 'es',
      'off': 'off',
      'none': 'off',
      'auto': 'auto',
      'source': 'source',
      'original': 'original',
    };
    return aliases[raw] ?? aliases[primary] ?? primary;
  }
}

class PlaybackTrackLanguage {
  const PlaybackTrackLanguage({this.language, this.title});

  final String? language;
  final String? title;

  bool matches(String requested) {
    if (NovaPlaybackPreferences.canonicalLanguage(language) == requested) {
      return true;
    }
    final normalizedTitle = (title ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-\.\(\)\[\]]+'), ' ')
        .trim();
    if (normalizedTitle.isEmpty) return false;
    for (final word in normalizedTitle.split(RegExp(r'\s+'))) {
      if (NovaPlaybackPreferences.canonicalLanguage(word) == requested) {
        return true;
      }
    }
    return false;
  }
}

/// Per-player selection state. Engine retries may re-run defaults, while a
/// choice made through the picker remains authoritative for the page lifetime.
class PlaybackPreferenceSession {
  bool audioPreferenceApplied = false;
  bool subtitlePreferenceApplied = false;
  bool audioSelectedManually = false;
  bool subtitleSelectedManually = false;

  bool get canApplyAudio => !audioPreferenceApplied && !audioSelectedManually;
  bool get canApplySubtitle =>
      !subtitlePreferenceApplied && !subtitleSelectedManually;

  void markAudioPreferenceApplied() => audioPreferenceApplied = true;
  void markSubtitlePreferenceApplied() => subtitlePreferenceApplied = true;

  void markAudioSelectedManually() {
    audioSelectedManually = true;
    audioPreferenceApplied = true;
  }

  void markSubtitleSelectedManually() {
    subtitleSelectedManually = true;
    subtitlePreferenceApplied = true;
  }

  void resetForEngine() {
    audioPreferenceApplied = false;
    subtitlePreferenceApplied = false;
  }
}
