import '../../core/watch_party/watch_party_models.dart';
import 'engine/playback_engine.dart';

List<AudioTrack> _realTracks(List<AudioTrack> tracks) =>
    tracks.where((track) => !const ['auto', 'no'].contains(track.id)).toList();

WatchPartyAudioSelection describeWatchPartyAudio(
    PlaybackEngine engine, WatchPartySource? source,
    {AudioTrack? selected}) {
  var track = selected ?? engine.selectedAudio;
  final real = _realTracks(engine.audioTracks);
  if (track.id == 'auto' && real.isNotEmpty) {
    track = real.firstWhere((track) => track.isDefault == true,
        orElse: () => real.first);
  }
  if (track.id == 'auto' || track.id == 'no') {
    return WatchPartyAudioSelection(mode: track.id == 'no' ? 'off' : 'auto');
  }
  final index = real.indexWhere((t) => t.id == track.id);
  return WatchPartyAudioSelection(
      mode: 'track',
      language: WatchPartyAudioSelection.normalizeLanguage(track.language),
      title: WatchPartyAudioSelection.normalizeTitle(track.title),
      index: index < 0 ? null : index,
      sourceKey: source?.key);
}

/// Native IDs and track order differ between Media3/libmpv and video files.
/// Match semantics first, and never guess between several language variants.
AudioTrack? matchWatchPartyAudio(WatchPartyAudioSelection selection,
    List<AudioTrack> tracks, WatchPartySource? source) {
  if (selection.mode == 'auto') return AudioTrack.auto();
  if (selection.mode == 'off') return AudioTrack.no();
  final real = _realTracks(tracks);
  final language =
      WatchPartyAudioSelection.normalizeLanguage(selection.language);
  final title =
      WatchPartyAudioSelection.normalizeTitle(selection.title)?.toLowerCase();
  bool matchesTitle(AudioTrack track) =>
      WatchPartyAudioSelection.normalizeTitle(track.title)?.toLowerCase() ==
      title;
  bool matchesLanguage(AudioTrack track) =>
      WatchPartyAudioSelection.normalizeLanguage(track.language) == language;
  if (title != null) {
    final matches = real
        .where((track) =>
            matchesTitle(track) && (language == null || matchesLanguage(track)))
        .toList();
    if (matches.length == 1) return matches.single;
  }
  if (language != null) {
    var matches = real.where(matchesLanguage).toList();
    if (matches.isEmpty) {
      matches = real
          .where((track) =>
              WatchPartyAudioSelection.normalizeLanguage(track.language)
                  ?.split('-')
                  .first ==
              language.split('-').first)
          .toList();
    }
    if (matches.length == 1) return matches.single;
  }
  if (language == null &&
      title == null &&
      source != null &&
      selection.sourceKey == source.key &&
      selection.index != null &&
      selection.index! >= 0 &&
      selection.index! < real.length) {
    return real[selection.index!];
  }
  return null;
}
