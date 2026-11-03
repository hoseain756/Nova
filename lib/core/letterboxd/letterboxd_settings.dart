import 'dart:convert';

/// The non-secret Letterboxd choices. The Stremboxd session belongs in
/// account-scoped secure storage, never in this synced settings value.
class LetterboxdSettings {
  const LetterboxdSettings({
    this.enabled = false,
    this.mode = publicMode,
    this.username = '',
    this.selectedCatalogs = defaultCatalogs,
    this.hiddenCatalogs = const [],
    this.catalogOrder = const [],
    this.showRatingsOnPosters = true,
    this.listRefs = const [],
  });

  static const publicMode = 'public';
  static const fullMode = 'full';

  static const watchlistCatalog = 'letterboxd-watchlist';
  static const diaryCatalog = 'letterboxd-diary';
  static const likedCatalog = 'letterboxd-liked';
  static const friendsCatalog = 'letterboxd-friends';
  static const recommendedCatalog = 'letterboxd-recommended';
  static const popularCatalog = 'letterboxd-popular';
  static const top250Catalog = 'letterboxd-top250';
  static const defaultCatalogs = <String>[
    watchlistCatalog,
    likedCatalog,
    popularCatalog,
    top250Catalog,
  ];
  static const allCatalogs = <String>[
    watchlistCatalog,
    diaryCatalog,
    likedCatalog,
    friendsCatalog,
    recommendedCatalog,
    popularCatalog,
    top250Catalog,
  ];
  static const fullOnlyCatalogs = <String>[
    diaryCatalog,
    friendsCatalog,
    recommendedCatalog,
  ];

  static const defaults = LetterboxdSettings();

  final bool enabled;
  final String mode;
  final String username;
  final List<String> selectedCatalogs;
  final List<String> hiddenCatalogs;
  final List<String> catalogOrder;
  final bool showRatingsOnPosters;
  final List<LetterboxdListRef> listRefs;

  bool get isPublic => mode == publicMode;

  /// Harbor's Stremboxd public config is a UTF-8 JSON object in base64url.
  /// Full-mode credentials and the session are deliberately excluded.
  String get encodedPublicConfig {
    final selected = selectedCatalogs.toSet();
    final name = username.trim();
    final config = <String, dynamic>{
      if (name.isNotEmpty) 'u': name,
      'c': <String, dynamic>{
        'popular': selected.contains(popularCatalog),
        'top250': selected.contains(top250Catalog),
        if (selected.contains(watchlistCatalog)) 'watchlist': true,
        if (selected.contains(likedCatalog)) 'likedFilms': true,
      },
      'l': listRefs.map((ref) => ref.id).toList(),
      'r': showRatingsOnPosters,
    };
    return base64Url
        .encode(utf8.encode(jsonEncode(config)))
        .replaceAll('=', '');
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'mode': mode,
        'username': username,
        'selectedCatalogs': selectedCatalogs,
        'hiddenCatalogs': hiddenCatalogs,
        'catalogOrder': catalogOrder,
        'showRatingsOnPosters': showRatingsOnPosters,
        'listRefs': listRefs.map((ref) => ref.toJson()).toList(),
      };

  factory LetterboxdSettings.fromJson(Object? value) {
    if (value is! Map) return defaults;
    final raw = Map<String, dynamic>.from(value);
    List<String> strings(String key, List<String> fallback) => raw[key] is List
        ? (raw[key] as List)
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
        : fallback;
    final rawMode = raw['mode'];
    return LetterboxdSettings(
      enabled: raw['enabled'] == true,
      mode: rawMode == fullMode ? fullMode : publicMode,
      username: raw['username'] is String ? raw['username'] as String : '',
      selectedCatalogs: strings('selectedCatalogs', defaultCatalogs),
      hiddenCatalogs: strings('hiddenCatalogs', const []),
      catalogOrder: strings('catalogOrder', const []),
      showRatingsOnPosters: raw['showRatingsOnPosters'] != false,
      listRefs: raw['listRefs'] is List
          ? (raw['listRefs'] as List)
              .map(LetterboxdListRef.fromJson)
              .whereType<LetterboxdListRef>()
              .toList()
          : const [],
    );
  }

  LetterboxdSettings copyWith({
    bool? enabled,
    String? mode,
    String? username,
    List<String>? selectedCatalogs,
    List<String>? hiddenCatalogs,
    List<String>? catalogOrder,
    bool? showRatingsOnPosters,
    List<LetterboxdListRef>? listRefs,
  }) =>
      LetterboxdSettings(
        enabled: enabled ?? this.enabled,
        mode: mode ?? this.mode,
        username: username ?? this.username,
        selectedCatalogs: selectedCatalogs ?? this.selectedCatalogs,
        hiddenCatalogs: hiddenCatalogs ?? this.hiddenCatalogs,
        catalogOrder: catalogOrder ?? this.catalogOrder,
        showRatingsOnPosters: showRatingsOnPosters ?? this.showRatingsOnPosters,
        listRefs: listRefs ?? this.listRefs,
      );
}

class LetterboxdListRef {
  const LetterboxdListRef({
    required this.id,
    required this.name,
    this.owner,
    this.filmCount,
  });

  final String id;
  final String name;
  final String? owner;
  final int? filmCount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (owner != null) 'owner': owner,
        if (filmCount != null) 'filmCount': filmCount,
      };

  static LetterboxdListRef? fromJson(Object? value) {
    if (value is! Map) return null;
    final raw = Map<String, dynamic>.from(value);
    final id = raw['id']?.toString() ?? '';
    final name = raw['name']?.toString() ?? '';
    if (id.isEmpty || name.isEmpty) return null;
    return LetterboxdListRef(
      id: id,
      name: name,
      owner: raw['owner']?.toString(),
      filmCount:
          raw['filmCount'] is num ? (raw['filmCount'] as num).toInt() : null,
    );
  }
}

/// Serialize only into the account-keyed secure store.
class LetterboxdSession {
  const LetterboxdSession({
    required this.userToken,
    required this.userId,
    required this.username,
    required this.loginAt,
    this.displayName,
  });

  final String userToken;
  final String userId;
  final String username;
  final String? displayName;
  final DateTime loginAt;

  Map<String, dynamic> toJson() => {
        'userToken': userToken,
        'userId': userId,
        'username': username,
        'displayName': displayName,
        'loginAt': loginAt.millisecondsSinceEpoch,
      };

  static LetterboxdSession? fromJson(Object? value) {
    if (value is! Map) return null;
    final raw = Map<String, dynamic>.from(value);
    final token = raw['userToken'];
    final userId = raw['userId'];
    final username = raw['username'];
    final loginAt = raw['loginAt'];
    if (token is! String ||
        token.isEmpty ||
        userId is! String ||
        userId.isEmpty ||
        username is! String ||
        username.isEmpty ||
        loginAt is! num) {
      return null;
    }
    return LetterboxdSession(
      userToken: token,
      userId: userId,
      username: username,
      displayName: raw['displayName']?.toString(),
      loginAt: DateTime.fromMillisecondsSinceEpoch(loginAt.toInt()),
    );
  }
}
