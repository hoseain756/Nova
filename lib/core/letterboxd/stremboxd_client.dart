import 'dart:convert';

import 'package:dio/dio.dart';

import 'letterboxd_settings.dart';

class StremboxdException implements Exception {
  const StremboxdException(this.message, {this.status = 0, this.code});

  final String message;
  final int status;
  final String? code;

  bool get requiresTotp => code == '2FA_REQUIRED';

  @override
  String toString() => 'StremboxdException(status: $status, code: $code)';
}

class LetterboxdValidation {
  const LetterboxdValidation(
      {required this.catalogs, required this.hasWatchlist});
  final int catalogs;
  final bool hasWatchlist;
}

class LetterboxdCatalogItem {
  const LetterboxdCatalogItem({
    required this.id,
    required this.name,
    this.poster,
    this.background,
    this.description,
    this.year,
    this.imdbRating,
    this.letterboxdUrl,
  });

  final String id;
  final String name;
  final String? poster;
  final String? background;
  final String? description;
  final int? year;
  final String? imdbRating;
  final Uri? letterboxdUrl;

  static LetterboxdCatalogItem? fromJson(Object? value) {
    if (value is! Map) return null;
    final raw = Map<String, dynamic>.from(value);
    final id = raw['id']?.toString() ?? '';
    final name = raw['name']?.toString() ?? '';
    if (id.isEmpty || name.isEmpty) return null;
    Uri? link;
    if (raw['links'] is List) {
      for (final candidate in raw['links'] as List) {
        if (candidate is! Map || candidate['category'] != 'Letterboxd') {
          continue;
        }
        link = _letterboxdUri(candidate['url']?.toString());
        if (link != null) break;
      }
    }
    return LetterboxdCatalogItem(
      id: id,
      name: name,
      poster: raw['poster']?.toString(),
      background: raw['background']?.toString(),
      description: raw['description']?.toString(),
      year: raw['year'] is num ? (raw['year'] as num).toInt() : null,
      imdbRating: raw['imdbRating']?.toString(),
      letterboxdUrl: link,
    );
  }
}

class LetterboxdCatalogPage {
  const LetterboxdCatalogPage(
      {required this.metas, required this.items, required this.hasMore});
  final List<Map<String, dynamic>> metas;
  final List<LetterboxdCatalogItem> items;
  final bool hasMore;
}

class LetterboxdFilm {
  const LetterboxdFilm({
    required this.id,
    required this.name,
    this.releaseYear,
    this.imdbId,
    this.tmdbId,
  });
  final String id;
  final String name;
  final int? releaseYear;
  final String? imdbId;
  final String? tmdbId;

  static LetterboxdFilm? fromJson(Object? value) {
    if (value is! Map) return null;
    final raw = Map<String, dynamic>.from(value);
    final id = raw['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    return LetterboxdFilm(
      id: id,
      name: raw['name']?.toString() ?? '',
      releaseYear: raw['releaseYear'] is num
          ? (raw['releaseYear'] as num).toInt()
          : null,
      imdbId: raw['imdbId']?.toString(),
      tmdbId: raw['tmdbId']?.toString(),
    );
  }
}

class LetterboxdFilmRating {
  const LetterboxdFilmRating({
    this.filmId,
    this.rating,
    this.userRating,
    this.watched = false,
    this.liked = false,
    this.inWatchlist = false,
    this.communityRating,
    this.communityRatings,
    this.watchCount,
  });

  final String? filmId;
  final double? rating;
  final double? userRating;
  final bool watched;
  final bool liked;
  final bool inWatchlist;
  final double? communityRating;
  final int? communityRatings;
  final int? watchCount;

  factory LetterboxdFilmRating.fromJson(Map<String, dynamic> raw) =>
      LetterboxdFilmRating(
        filmId: raw['filmId']?.toString(),
        rating: _number(raw['rating']),
        userRating: _number(raw['userRating']),
        watched: raw['watched'] == true,
        liked: raw['liked'] == true,
        inWatchlist: raw['inWatchlist'] == true,
        communityRating:
            _number(raw['communityRating']) ?? _number(raw['globalRating']),
        communityRatings: _integer(raw['communityRatings']),
        watchCount: _integer(raw['watchCount']),
      );
}

class LetterboxdFilmStreamInfo {
  const LetterboxdFilmStreamInfo({
    this.communityRating,
    this.communityRatings = 0,
    this.userRating,
    this.watched = false,
    this.liked = false,
    this.inWatchlist = false,
    this.letterboxdUrl,
    this.rateUrl,
    this.watchedUrl,
    this.likedUrl,
    this.watchlistUrl,
  });

  final double? communityRating;
  final int communityRatings;
  final double? userRating;
  final bool watched;
  final bool liked;
  final bool inWatchlist;
  final Uri? letterboxdUrl;
  final Uri? rateUrl;
  final Uri? watchedUrl;
  final Uri? likedUrl;
  final Uri? watchlistUrl;
}

double? _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

int? _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

Uri? _letterboxdUri(String? value) {
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https') return null;
  if (uri.host != 'letterboxd.com' && uri.host != 'www.letterboxd.com') {
    return null;
  }
  return uri;
}

/// Stremboxd is a community bridge, not Letterboxd's official OAuth API.
/// Only a user-entered Full-mode password is sent to /auth/login, once, and it
/// never enters any persisted settings or diagnostic output.
class StremboxdClient {
  StremboxdClient({Dio? dio, String baseUrl = 'https://api.stremboxd.com'})
      : _dio = dio ?? Dio(),
        _base = Uri.parse(baseUrl) {
    if (_base.scheme != 'https' ||
        _base.host.isEmpty ||
        _base.userInfo.isNotEmpty ||
        _base.hasQuery ||
        _base.hasFragment) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Expected an HTTPS origin');
    }
  }

  final Dio _dio;
  final Uri _base;

  static final RegExp _pathId = RegExp(r'^[a-zA-Z0-9_-]+$');
  static final RegExp _imdbId = RegExp(r'^tt\d+$');

  String _segment(String value) {
    if (!_pathId.hasMatch(value)) {
      throw const StremboxdException('Invalid catalog or account ID');
    }
    return value;
  }

  String _imdb(String value) {
    if (!_imdbId.hasMatch(value)) {
      throw const StremboxdException('Invalid IMDb ID');
    }
    return value;
  }

  Uri _url(String path, [Map<String, String>? query]) => _base.replace(
        path: path,
        queryParameters: query,
      );

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, String>? query,
      Map<String, dynamic>? body,
      String? bearer}) async {
    Response<dynamic> response;
    try {
      response = await _dio.requestUri<dynamic>(
        _url(path, query),
        data: body,
        options: Options(
          method: method,
          contentType: body == null ? null : Headers.jsonContentType,
          headers: bearer == null ? null : {'Authorization': 'Bearer $bearer'},
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (error) {
      final response = error.response;
      if (response == null) {
        throw const StremboxdException('Could not reach Stremboxd');
      }
      throw _httpError(response);
    }
    if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) {
      throw _httpError(response);
    }
    Object? data = response.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        throw const StremboxdException('Unexpected Stremboxd response');
      }
    }
    if (data is! Map) {
      throw const StremboxdException('Unexpected Stremboxd response');
    }
    return Map<String, dynamic>.from(data);
  }

  StremboxdException _httpError(Response<dynamic> response) {
    Object? data = response.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        data = null;
      }
    }
    final details = data is Map ? data : const <String, dynamic>{};
    final code = details['code']?.toString();
    return StremboxdException(
      code == '2FA_REQUIRED'
          ? 'Two-factor authentication required'
          : 'Stremboxd request failed',
      status: response.statusCode ?? 0,
      code: code,
    );
  }

  Future<LetterboxdValidation> verifyPublic(LetterboxdSettings settings) async {
    final config = settings.encodedPublicConfig;
    final manifest = await _request('GET', '/$config/manifest.json');
    final rawCatalogs = manifest['catalogs'];
    if (manifest['id'] != 'community.stremboxd' ||
        rawCatalogs is! List ||
        rawCatalogs.isEmpty) {
      throw const StremboxdException('Unexpected Stremboxd manifest');
    }
    final hasWatchlist = rawCatalogs.any((entry) =>
        entry is Map && entry['id'] == LetterboxdSettings.watchlistCatalog);
    if (settings.username.trim().isNotEmpty &&
        settings.selectedCatalogs
            .contains(LetterboxdSettings.watchlistCatalog) &&
        !hasWatchlist) {
      throw const StremboxdException('Letterboxd watchlist unavailable');
    }
    return LetterboxdValidation(
        catalogs: rawCatalogs.length, hasWatchlist: hasWatchlist);
  }

  Future<LetterboxdListRef> resolvePublicList(String address) async {
    final cleaned = address.trim();
    final uri = Uri.tryParse(
        cleaned.startsWith('letterboxd.com/') ? 'https://$cleaned' : cleaned);
    final segments =
        uri?.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (uri == null ||
        uri.scheme != 'https' ||
        (uri.host != 'letterboxd.com' && uri.host != 'www.letterboxd.com') ||
        segments == null ||
        segments.length < 3 ||
        segments[1] != 'list') {
      throw const StremboxdException('Invalid Letterboxd list URL');
    }
    final data = await _request('POST', '/auth/resolve-list-public',
        body: {'url': uri.toString()});
    final ref = LetterboxdListRef.fromJson(data);
    if (ref == null || !_pathId.hasMatch(ref.id)) {
      throw const StremboxdException('Unexpected Stremboxd list response');
    }
    return ref;
  }

  Future<LetterboxdSession> login(String username, String password,
      {String? totp}) async {
    final name = username.trim();
    if (name.isEmpty || password.isEmpty) {
      throw const StremboxdException('Username and password are required');
    }
    final code = totp?.trim();
    final data = await _request('POST', '/auth/login', body: {
      'username': name,
      'password': password,
      if (code != null && code.isNotEmpty) 'totp': code,
    });
    final user = data['user'];
    final token = data['userToken'];
    if (user is! Map ||
        token is! String ||
        token.isEmpty ||
        user['id'] is! String ||
        user['username'] is! String) {
      throw const StremboxdException('Unexpected Stremboxd login response');
    }
    return LetterboxdSession(
      userToken: token,
      userId: user['id'] as String,
      username: user['username'] as String,
      displayName: user['displayName']?.toString(),
      loginAt: DateTime.now(),
    );
  }

  Future<LetterboxdCatalogPage> fetchCatalog(
      LetterboxdSettings settings, String catalogId,
      {LetterboxdSession? session, int skip = 0}) async {
    if (skip < 0) throw const StremboxdException('Invalid catalog offset');
    final id = _segment(catalogId);
    final root = settings.mode == LetterboxdSettings.fullMode
        ? '/stremio/${_segment(_requireSession(session).userId)}'
        : '/${settings.encodedPublicConfig}';
    final suffix = skip == 0 ? '$id.json' : '$id/skip=$skip.json';
    final data = await _request('GET', '$root/catalog/movie/$suffix');
    final metas = data['metas'];
    if (metas is! List) {
      throw const StremboxdException('Unexpected Stremboxd catalog response');
    }
    final rawItems =
        metas.whereType<Map>().map(Map<String, dynamic>.from).toList();
    final items = rawItems
        .map(LetterboxdCatalogItem.fromJson)
        .whereType<LetterboxdCatalogItem>()
        .toList();
    return LetterboxdCatalogPage(
        metas: rawItems, items: items, hasMore: metas.length >= 100);
  }

  Future<LetterboxdCatalogItem?> fetchPublicMeta(
      LetterboxdSettings settings, String imdbId) async {
    final data = await _request('GET',
        '/${settings.encodedPublicConfig}/meta/movie/${_imdb(imdbId)}.json');
    return LetterboxdCatalogItem.fromJson(data['meta']);
  }

  /// Full-mode metadata keeps the bridge's review links intact for detail UI.
  Future<Map<String, dynamic>?> fetchFullMeta(
      String userId, String imdbId) async {
    try {
      final data = await _request('GET',
          '/stremio/${_segment(userId)}/meta/movie/${_imdb(imdbId)}.json');
      final meta = data['meta'];
      return meta is Map ? Map<String, dynamic>.from(meta) : null;
    } on StremboxdException catch (error) {
      if (error.status == 404) return null;
      rethrow;
    }
  }

  LetterboxdSession _requireSession(LetterboxdSession? session) {
    if (session == null || session.userToken.isEmpty) {
      throw const StremboxdException('Letterboxd Full mode is not connected');
    }
    return session;
  }

  Future<void> updatePreferences(
      LetterboxdSettings settings, LetterboxdSession session) async {
    final selected = settings.selectedCatalogs.toSet();
    final data = await _request('POST', '/auth/preferences', body: {
      'userToken': session.userToken,
      'preferences': {
        'catalogs': {
          'watchlist': selected.contains(LetterboxdSettings.watchlistCatalog),
          'diary': selected.contains(LetterboxdSettings.diaryCatalog),
          'friends': selected.contains(LetterboxdSettings.friendsCatalog),
          'popular': selected.contains(LetterboxdSettings.popularCatalog),
          'top250': selected.contains(LetterboxdSettings.top250Catalog),
          'likedFilms': selected.contains(LetterboxdSettings.likedCatalog),
          'recommended':
              selected.contains(LetterboxdSettings.recommendedCatalog),
        },
        'ownLists': settings.listRefs.map((ref) => ref.id).toList(),
        'externalLists': const [],
        'showActions': true,
        'showRatings': settings.showRatingsOnPosters,
      },
    });
    if (data['success'] == false) {
      throw const StremboxdException('Stremboxd rejected preferences');
    }
  }

  Future<LetterboxdFilm?> resolveFilm(
      String imdbId, LetterboxdSession session) async {
    try {
      final data = await _request('GET', '/v1/resolve-film',
          query: {'imdbId': _imdb(imdbId)}, bearer: session.userToken);
      return LetterboxdFilm.fromJson(data);
    } on StremboxdException catch (error) {
      if (error.status == 404) return null;
      rethrow;
    }
  }

  Future<LetterboxdFilmRating> fetchFilmRating(
      String filmId, LetterboxdSession session) async {
    if (filmId.isEmpty) throw const StremboxdException('Invalid film ID');
    final data = await _request('GET', '/v1/film-rating',
        query: {'filmId': filmId}, bearer: session.userToken);
    return LetterboxdFilmRating.fromJson(data);
  }

  Uri? _actionUri(String? value, String userId) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host != _base.host ||
        uri.port != _base.port ||
        !uri.path.startsWith('/action/$userId/')) {
      return null;
    }
    return uri;
  }

  Future<LetterboxdFilmStreamInfo?> fetchFilmStreamInfo(
      String userId, String imdbId) async {
    final data = await _request('GET',
        '/stremio/${_segment(userId)}/stream/movie/${_imdb(imdbId)}.json');
    final streams = data['streams'];
    if (streams is! List || streams.isEmpty) return null;
    double? communityRating;
    int communityRatings = 0;
    double? userRating;
    bool watched = false, liked = false, inWatchlist = false;
    Uri? letterboxdUrl, rateUrl, watchedUrl, likedUrl, watchlistUrl;
    final scorePattern = RegExp(r'(\d+(?:\.\d+)?)\s*/\s*5');
    final userPattern = RegExp(r'Your rating:.*?(\d+(?:\.\d+)?)');
    final countPattern = RegExp(r'\(([\d.]+[KM]?)\s*ratings\)');
    for (final raw in streams) {
      if (raw is! Map) continue;
      final name = raw['name']?.toString() ?? '';
      final url = raw['externalUrl']?.toString();
      if (name == 'Letterboxd') {
        letterboxdUrl = _letterboxdUri(url);
        for (final line in (raw['description']?.toString() ?? '').split('\n')) {
          communityRating ??= _number(scorePattern.firstMatch(line)?.group(1));
          userRating ??= _number(userPattern.firstMatch(line)?.group(1));
          watched |= line.contains('✓ Watched');
          liked |= line.contains('♥ Liked');
          inWatchlist |= line.contains('In Watchlist');
          final count = countPattern.firstMatch(line)?.group(1);
          if (count != null) {
            final numeric =
                double.tryParse(count.replaceAll(RegExp(r'[KM]$'), ''));
            if (numeric != null) {
              communityRatings = (numeric *
                      (count.endsWith('M')
                          ? 1000000
                          : count.endsWith('K')
                              ? 1000
                              : 1))
                  .round();
            }
          }
        }
      }
      final action = _actionUri(url, userId);
      if (action == null) continue;
      if (action.path.contains('/rate/')) rateUrl = action;
      if (action.path.contains('/watched/')) watchedUrl = action;
      if (action.path.contains('/liked/')) likedUrl = action;
      if (action.path.contains('/watchlist/')) watchlistUrl = action;
    }
    return LetterboxdFilmStreamInfo(
      communityRating: communityRating,
      communityRatings: communityRatings,
      userRating: userRating,
      watched: watched,
      liked: liked,
      inWatchlist: inWatchlist,
      letterboxdUrl: letterboxdUrl,
      rateUrl: rateUrl,
      watchedUrl: watchedUrl,
      likedUrl: likedUrl,
      watchlistUrl: watchlistUrl,
    );
  }
}
