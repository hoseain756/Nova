import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/home/widgets/hero_trailer_policy.dart';

void main() {
  const wifi =
      HeroTrailerEnvironment(wifi: true, lowPower: false, dataSaver: false);
  const cellular =
      HeroTrailerEnvironment(wifi: false, lowPower: false, dataSaver: false);
  bool allowed(HeroTrailerMode mode, HeroTrailerEnvironment environment,
          {bool visible = true, bool reducedMotion = false}) =>
      canAutoplayHeroTrailer(
          mode: mode,
          environment: environment,
          visible: visible,
          reducedMotion: reducedMotion);

  test('default is Wi-Fi; cellular requires an explicit Always preference', () {
    expect(heroTrailerMode(null), HeroTrailerMode.wifi);
    expect(heroTrailerMode('future-value'), HeroTrailerMode.wifi);
    expect(allowed(HeroTrailerMode.wifi, wifi), isTrue);
    expect(allowed(HeroTrailerMode.wifi, cellular), isFalse);
    expect(allowed(HeroTrailerMode.always, cellular), isTrue);
  });

  test(
      'Never, hidden routes, reduced motion and either OS saver override Always',
      () {
    expect(allowed(HeroTrailerMode.never, wifi), isFalse);
    expect(allowed(HeroTrailerMode.always, wifi, visible: false), isFalse);
    expect(allowed(HeroTrailerMode.always, wifi, reducedMotion: true), isFalse);
    for (final environment in [
      const HeroTrailerEnvironment(
          wifi: true, lowPower: true, dataSaver: false),
      const HeroTrailerEnvironment(
          wifi: true, lowPower: false, dataSaver: true),
      const HeroTrailerEnvironment.unknown(),
      HeroTrailerEnvironment.fromMap({}),
    ]) {
      expect(allowed(HeroTrailerMode.always, environment), isFalse);
    }
  });

  test('only validated provider IDs can become executable embeds', () {
    const id = 'aB_12345-xy';
    for (final url in [
      'https://youtu.be/$id',
      'https://www.youtube.com/watch?v=$id',
      'https://youtube.com/embed/$id'
    ]) {
      expect(heroYoutubeId(url), id);
    }
    for (final url in [
      null,
      '',
      'javascript:alert(1)',
      'http://www.youtube.com/watch?v=$id',
      'https://youtube.com.example.test/watch?v=$id',
      'https://youtube.com/watch?v=bad',
      'https://youtube.com/watch?v=%27%3Cscript%3E',
      'https://example.test/trailer.mp4'
    ]) {
      expect(heroYoutubeId(url), isNull, reason: url);
    }
  });
}
