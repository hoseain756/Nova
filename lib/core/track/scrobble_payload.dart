/// Shared Trakt/Simkl scrobble identity. A series event must identify the
/// exact episode; sending only the parent show can attach progress to the
/// wrong item or be rejected by the provider.
Map<String, dynamic>? buildScrobblePayload({
  required String type,
  required String title,
  String? year,
  String? imdb,
  int? season,
  int? episode,
  required double progress,
}) {
  final name = title.trim();
  if (name.isEmpty) return null;
  final ids = <String, dynamic>{
    if (imdb != null && RegExp(r'^tt\d+$').hasMatch(imdb)) 'imdb': imdb,
  };
  final identity = <String, dynamic>{
    'title': name,
    if (int.tryParse(year ?? '') case final int value) 'year': value,
    if (ids.isNotEmpty) 'ids': ids,
  };
  final percent = progress.clamp(0.0, 100.0).toDouble();
  if (type.toLowerCase() == 'movie') {
    return {'movie': identity, 'progress': percent};
  }
  if (season == null || season < 0 || episode == null || episode <= 0) {
    return null;
  }
  return {
    'show': identity,
    'episode': {'season': season, 'number': episode},
    'progress': percent,
  };
}
