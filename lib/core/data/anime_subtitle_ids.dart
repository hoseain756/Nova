import '../models/media_item.dart';

/// Resolve additional subtitle IDs only when a trusted AniZip record matches
/// the exact provider season/episode. Playback and stream IDs stay unchanged.
abstract final class AnimeSubtitleIds {
  static String? mappingQuery(MediaItem item) {
    if (item.type != 'series') return null;
    final anime = item.hasAnimeIds ||
        item.genres.any((genre) =>
            genre.toLowerCase() == 'anime' ||
            genre.toLowerCase() == 'animation');
    if (!anime) return null;
    if (item.idMal != null) return 'mal_id=${item.idMal}';
    if (item.anilistId != null) return 'anilist_id=${item.anilistId}';
    if (RegExp(r'^tt\d+$').hasMatch(item.id)) return 'imdb_id=${item.id}';
    return null;
  }

  static List<String> fromMapping({
    required MediaItem item,
    required String videoId,
    required Map<String, dynamic> mapping,
  }) {
    final video =
        item.videos.where((entry) => entry['id'] == videoId).firstOrNull;
    if (video == null) return const [];
    final season = _positive(video['season']);
    final episode = _positive(video['episode']);
    if (season == null || episode == null) return const [];

    final ids = mapping['mappings'];
    final episodes = mapping['episodes'];
    if (ids is! Map || episodes is! Map) return const [];
    if (RegExp(r'^tt\d+$').hasMatch(item.id) &&
        ids['imdb_id']?.toString() != item.id) {
      return const [];
    }
    if (item.idMal != null && _positive(ids['mal_id']) != item.idMal) {
      return const [];
    }
    if (item.anilistId != null &&
        _positive(ids['anilist_id']) != item.anilistId) {
      return const [];
    }

    final matches = <(int, Map)>[];
    for (final entry in episodes.entries) {
      final row = entry.value;
      if (row is! Map ||
          _positive(row['seasonNumber']) != season ||
          _positive(row['episodeNumber']) != episode) {
        continue;
      }
      final absolute =
          _positive(row['absoluteEpisodeNumber']) ?? _positive(entry.key);
      if (absolute == null) continue;
      final released = video['released']?.toString();
      final airDate = row['airDate']?.toString();
      if (released != null &&
          released.length >= 10 &&
          airDate != null &&
          airDate.length >= 10 &&
          released.substring(0, 10) != airDate.substring(0, 10)) {
        continue;
      }
      matches.add((absolute, row));
    }
    if (matches.length != 1) return const [];
    final absolute = matches.single.$1;
    final candidates = <String>[
      if (_positive(ids['mal_id']) case final mal?) 'mal:$mal:$absolute',
      if (_positive(ids['kitsu_id']) case final kitsu?)
        'kitsu:$kitsu:$absolute',
      if (_positive(ids['anilist_id']) case final anilist?)
        'anilist:$anilist:$absolute',
      if (_positive(ids['anidb_id']) case final anidb?)
        'anidb:$anidb:$absolute',
      if (ids['imdb_id']?.toString() case final imdb?)
        if (RegExp(r'^tt\d+$').hasMatch(imdb)) '$imdb:1:$absolute',
    ];
    return candidates.where((id) => id != videoId).toSet().toList();
  }

  static int? _positive(Object? value) {
    final number = value is num ? value.toInt() : int.tryParse('$value');
    return number != null && number > 0 ? number : null;
  }
}
