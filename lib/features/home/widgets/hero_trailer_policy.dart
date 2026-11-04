/// Network and power restrictions are checked before requesting trailer media.
enum HeroTrailerMode { always, wifi, never }

HeroTrailerMode heroTrailerMode(Object? value) => switch (value) {
      'always' => HeroTrailerMode.always,
      'never' => HeroTrailerMode.never,
      _ => HeroTrailerMode.wifi,
    };

class HeroTrailerEnvironment {
  const HeroTrailerEnvironment({
    required this.wifi,
    required this.lowPower,
    required this.dataSaver,
  });

  const HeroTrailerEnvironment.unknown()
      : wifi = false,
        lowPower = true,
        dataSaver = true;

  factory HeroTrailerEnvironment.fromMap(Map<Object?, Object?> map) =>
      HeroTrailerEnvironment(
        wifi: map['wifi'] == true,
        lowPower: map['lowPower'] != false,
        dataSaver: map['dataSaver'] != false,
      );

  final bool wifi, lowPower, dataSaver;
}

bool canAutoplayHeroTrailer({
  required HeroTrailerMode mode,
  required HeroTrailerEnvironment environment,
  required bool visible,
  required bool reducedMotion,
}) =>
    visible &&
    !reducedMotion &&
    mode != HeroTrailerMode.never &&
    !environment.lowPower &&
    !environment.dataSaver &&
    (mode == HeroTrailerMode.always || environment.wifi);

/// Only the documented YouTube identity is embedded. Unknown websites are
/// never loaded as executable content inside NOVA.
String? heroYoutubeId(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null || uri.scheme != 'https') return null;
  final host = uri.host.toLowerCase();
  String? id;
  if (host == 'youtu.be') {
    id = uri.pathSegments.firstOrNull;
  } else if (const {'youtube.com', 'www.youtube.com', 'm.youtube.com'}
      .contains(host)) {
    id = uri.path == '/watch'
        ? uri.queryParameters['v']
        : uri.pathSegments.length == 2 && uri.pathSegments.first == 'embed'
            ? uri.pathSegments.last
            : null;
  }
  return id != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id) ? id : null;
}
