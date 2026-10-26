import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../core/models/media_item.dart';
import 'skip_segment.dart';

/// Public, read-only timing lookups. Every result is tied to the current
/// episode and checked against the real file duration before it reaches UI.
class SkipTimingSources {
  SkipTimingSources({Dio? client})
      : _client = client ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
            ));

  static final shared = SkipTimingSources();

  final Dio _client;
  final Map<String, Future<List<SkipSegment>>> _cache = {};

  Future<List<SkipSegment>> fetch({
    required MediaItem item,
    required int durationMs,
    int? season,
    int? episode,
    int? exactMalId,
    int? exactAnimeEpisode,
    String? theIntroDbKey,
    int credentialsRevision = 0,
  }) {
    if (durationMs <= 0) return Future.value(const []);
    final imdb = RegExp(r'tt\d+').firstMatch(item.id)?.group(0);
    final mal = exactMalId ?? item.idMal;
    final animeEpisode = exactAnimeEpisode;
    if (imdb == null && (mal == null || animeEpisode == null)) {
      return Future.value(const []);
    }
    final key =
        '${item.type}:$imdb:$season:$episode:$mal:$animeEpisode:$durationMs:$credentialsRevision';
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_cache.length >= 64) _cache.remove(_cache.keys.first);
    return _cache[key] = _fetch(
      imdb: imdb,
      mal: mal,
      animeEpisode: animeEpisode,
      season: season,
      episode: episode,
      isMovie: item.type == 'movie',
      durationMs: durationMs,
      theIntroDbKey: theIntroDbKey,
    );
  }

  Future<List<SkipSegment>> _fetch({
    required String? imdb,
    required int? mal,
    required int? animeEpisode,
    required int? season,
    required int? episode,
    required bool isMovie,
    required int durationMs,
    required String? theIntroDbKey,
  }) async {
    final tvEpisode =
        season != null && season >= 0 && episode != null && episode > 0;
    final calls = <Future<List<SkipSegment>>>[
      if (mal != null && mal > 0 && animeEpisode != null && animeEpisode > 0)
        _aniSkip(mal, animeEpisode, durationMs),
      if (imdb != null && (isMovie || tvEpisode))
        _introDb(imdb, season, episode, isMovie, durationMs),
      if (imdb != null && (isMovie || tvEpisode))
        _theIntroDb(imdb, season, episode, isMovie, durationMs, theIntroDbKey),
    ];
    if (calls.isEmpty) return const [];
    final results = await Future.wait(calls);
    return chooseExternalSegments(results.expand((rows) => rows), durationMs);
  }

  Future<List<SkipSegment>> _aniSkip(
      int mal, int episode, int durationMs) async {
    try {
      final seconds = (durationMs / 1000).toStringAsFixed(3);
      final response = await _client.get<dynamic>(
        'https://api.aniskip.com/v2/skip-times/$mal/$episode'
        '?types=op&types=ed&types=recap&episodeLength=$seconds',
      );
      return parseAniSkip(response.data, durationMs);
    } catch (_) {
      return const [];
    }
  }

  Future<List<SkipSegment>> _introDb(String imdb, int? season, int? episode,
      bool isMovie, int durationMs) async {
    try {
      final response = await _client.get<dynamic>(
        'https://api.introdb.app/segments',
        queryParameters: {
          'imdb_id': imdb,
          if (isMovie) 'is_movie': 'true',
          if (!isMovie) 'season': season,
          if (!isMovie) 'episode': episode,
        },
      );
      return parseIntroDb(response.data, durationMs);
    } catch (_) {
      return const [];
    }
  }

  Future<List<SkipSegment>> _theIntroDb(String imdb, int? season, int? episode,
      bool isMovie, int durationMs, String? userKey) async {
    final query = {
      'imdb_id': imdb,
      if (!isMovie) 'season': season,
      if (!isMovie) 'episode': episode,
      'duration_ms': durationMs,
      'details': 'true',
    };
    const url = 'https://api.theintrodb.org/v4/media';
    try {
      final response = await _client.get<dynamic>(
        url,
        queryParameters: query,
        options: userKey == null || userKey.isEmpty
            ? null
            : Options(
                headers: {'Authorization': 'Bearer $userKey'},
                followRedirects: false,
              ),
      );
      return parseTheIntroDb(response.data, durationMs);
    } on DioException catch (error) {
      if (userKey == null ||
          (error.response?.statusCode != 401 &&
              error.response?.statusCode != 403)) {
        return const [];
      }
      // A stale optional key must not disable the public timing lookup.
      try {
        final response =
            await _client.get<dynamic>(url, queryParameters: query);
        return parseTheIntroDb(response.data, durationMs);
      } catch (_) {
        return const [];
      }
    } catch (_) {
      return const [];
    }
  }

  static Map? _body(Object? value) {
    if (value is Map) return value;
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        return decoded is Map ? decoded : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static int? _ms(Object? value, {bool seconds = false}) {
    if (value is! num || !value.isFinite) return null;
    return (value * (seconds ? 1000 : 1)).round();
  }

  static SkipSegment? _segment({
    required SkipSegmentType type,
    required Object? start,
    required Object? end,
    required String source,
    required int durationMs,
    bool seconds = false,
    bool nullStartIsZero = false,
    bool nullEndIsDuration = false,
    Object? confidence,
  }) {
    final from =
        start == null && nullStartIsZero ? 0 : _ms(start, seconds: seconds);
    final to = end == null && nullEndIsDuration
        ? durationMs
        : _ms(end, seconds: seconds);
    if (from == null ||
        to == null ||
        from < 0 ||
        to <= from ||
        to > durationMs) {
      return null;
    }
    final score =
        confidence is num && confidence.isFinite ? confidence.toDouble() : null;
    if (score != null && (score < 0.6 || score > 1)) return null;
    return SkipSegment(
      type: type,
      startMs: from,
      endMs: to,
      source: source,
      confidence: score,
    );
  }

  static List<SkipSegment> parseAniSkip(Object? body, int durationMs) {
    final data = _body(body);
    if (data == null || data['found'] != true || data['results'] is! List) {
      return const [];
    }
    final result = <SkipSegment>[];
    for (final raw in data['results'] as List) {
      if (raw is! Map || raw['interval'] is! Map) continue;
      final length = _ms(raw['episodeLength'], seconds: true);
      if (length == null ||
          (length - durationMs).abs() > math.max(10000, durationMs ~/ 100)) {
        continue;
      }
      final type = switch (raw['skipType']) {
        'op' => SkipSegmentType.opening,
        'ed' => SkipSegmentType.outro,
        'recap' => SkipSegmentType.recap,
        _ => null,
      };
      if (type == null) continue;
      final interval = raw['interval'] as Map;
      final segment = _segment(
        type: type,
        start: interval['startTime'],
        end: interval['endTime'],
        source: 'aniskip',
        durationMs: durationMs,
        seconds: true,
      );
      if (segment != null) result.add(segment);
    }
    return result;
  }

  /// Embedded chapter boundaries are tied to this exact file. Only an
  /// explicitly named chapter is skippable; the next chapter marks its end.
  static List<SkipSegment> parseChapterList(Object? body, int durationMs) {
    if (durationMs <= 0) return const [];
    Object? decoded = body;
    if (body is String) {
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        return const [];
      }
    }
    if (decoded is! List || decoded.length > 500) return const [];
    final chapters = <({int startMs, String title})>[];
    for (final raw in decoded) {
      if (raw is! Map) continue;
      final start = _ms(raw['time'], seconds: true);
      if (start == null || start < 0 || start >= durationMs) continue;
      chapters.add((
        startMs: start,
        title: raw['title'] is String ? raw['title'] as String : '',
      ));
    }
    chapters.sort((a, b) => a.startMs.compareTo(b.startMs));
    final segments = <SkipSegment>[];
    for (var index = 0; index < chapters.length; index++) {
      final type = _chapterType(chapters[index].title);
      if (type == null) continue;
      final end = index + 1 < chapters.length
          ? chapters[index + 1].startMs
          : durationMs;
      final segment = _segment(
        type: type,
        start: chapters[index].startMs,
        end: end,
        source: 'file-chapter',
        durationMs: durationMs,
      );
      if (segment != null) segments.add(segment);
    }
    return List.unmodifiable(segments);
  }

  static SkipSegmentType? _chapterType(String title) {
    final value = title.trim().toLowerCase();
    if (RegExp(r'^(?:op|opening)(?:[\s._-]*\d+)?$').hasMatch(value) ||
        value == 'افتتاحية' ||
        value == 'شارة البداية') {
      return SkipSegmentType.opening;
    }
    if (value == 'intro' || value == 'مقدمة') return SkipSegmentType.intro;
    if (value == 'recap' || value == 'ملخص') return SkipSegmentType.recap;
    if (value == 'credits' || value == 'اعتمادات') {
      return SkipSegmentType.credits;
    }
    if (value == 'outro' ||
        value == 'ending' ||
        value == 'ed' ||
        value == 'نهاية' ||
        value == 'شارة النهاية') {
      return SkipSegmentType.outro;
    }
    return null;
  }

  static List<SkipSegment> parseIntroDb(Object? body, int durationMs) {
    final data = _body(body);
    if (data == null) return const [];
    final result = <SkipSegment>[];
    for (final (field, type) in [
      ('intro', SkipSegmentType.intro),
      ('recap', SkipSegmentType.recap),
      ('outro', SkipSegmentType.outro),
    ]) {
      final raw = data[field];
      if (raw is! Map) continue;
      final segment = _segment(
        type: type,
        start: raw['start_ms'],
        end: raw['end_ms'],
        source: 'introdb',
        durationMs: durationMs,
        confidence: raw['confidence'],
      );
      if (segment != null) result.add(segment);
    }
    return result;
  }

  static List<SkipSegment> parseTheIntroDb(Object? body, int durationMs) {
    final data = _body(body);
    if (data == null || (data['kind'] != null && data['kind'] != 'media')) {
      return const [];
    }
    final groupDuration =
        _ms(data['groupDurationMs'] ?? data['group_duration_ms']);
    if (groupDuration != null &&
        (groupDuration - durationMs).abs() >
            math.max(10000, durationMs ~/ 100)) {
      return const [];
    }
    final result = <SkipSegment>[];
    for (final (field, type) in [
      ('intro', SkipSegmentType.intro),
      ('recap', SkipSegmentType.recap),
      ('credits', SkipSegmentType.outro),
    ]) {
      final rows = data[field];
      if (rows is! List) continue;
      for (final raw in rows) {
        if (raw is! Map) continue;
        final segment = _segment(
          type: type,
          start: raw['start_ms'],
          end: raw['end_ms'],
          source: 'theintrodb',
          durationMs: durationMs,
          nullStartIsZero:
              type == SkipSegmentType.intro || type == SkipSegmentType.recap,
          nullEndIsDuration: type == SkipSegmentType.outro,
          confidence: raw['confidence'],
        );
        if (segment != null) result.add(segment);
      }
    }
    return result;
  }

  /// Close but distinct providers corroborate a timing; large disagreements
  /// suppress that type so the player cannot skip story content by mistake.
  static List<SkipSegment> chooseExternalSegments(
      Iterable<SkipSegment> segments, int durationMs) {
    final output = <SkipSegment>[];
    for (final type in SkipSegmentType.values) {
      final sameType = segments
          .where((row) =>
              row.type == type &&
              row.startMs >= 0 &&
              row.endMs > row.startMs &&
              row.endMs <= durationMs)
          .toList();
      if (sameType.isEmpty) continue;
      final preferred =
          sameType.where((row) => row.source == 'theintrodb').toList();
      final selected = preferred.isNotEmpty
          ? preferred
          : sameType.where((row) => row.source == 'aniskip').isNotEmpty
              ? sameType.where((row) => row.source == 'aniskip').toList()
              : sameType.where((row) => row.source == 'introdb').toList();
      final otherSources =
          sameType.where((row) => row.source != selected.first.source);
      final conflict = otherSources.any((other) => selected.every((chosen) =>
          (chosen.startMs - other.startMs).abs() > 10000 ||
          (chosen.endMs - other.endMs).abs() > 10000));
      if (!conflict) output.addAll(selected);
    }
    return List.unmodifiable(output);
  }
}
