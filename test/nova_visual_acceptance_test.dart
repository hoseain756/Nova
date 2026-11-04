import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/addon.dart';
import 'package:nova_mobile/core/models/featured_artwork.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/home/home_page.dart';
import 'package:nova_mobile/features/home/widgets/cinematic_cover_scroll.dart';
import 'package:nova_mobile/features/media/detail_hero.dart';
import 'package:nova_mobile/features/media/media_detail_page.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';

const _writeAcceptanceImages =
    bool.fromEnvironment('NOVA_WRITE_ACCEPTANCE', defaultValue: false);
const _captureBoundary = ValueKey('nova-acceptance-capture');

const _fixtureItems = <MediaItem>[
  MediaItem(
    id: 'nova-fixture-series',
    type: 'series',
    name: 'The Observatory Between Two Seas',
    originalTitle: 'المرصد بين بحرين',
    poster: 'https://nova.test/posters/observatory.png',
    background: 'https://nova.test/backdrops/observatory.png',
    description:
        'A patient astronomer follows a mysterious signal across a bilingual '
        'coastal city while her family races to preserve their observatory.',
    releaseInfo: '2026',
    rating: '8.7',
    runtime: '52 min',
    certification: 'PG-13',
    originCountry: 'SA',
    genres: ['Drama', 'Science Fiction'],
    cast: ['Layla Haddad', 'Omar Rahman', 'Mira Saleh'],
    director: ['Nadia Karim'],
    seasonCount: 2,
    episodeCount: 12,
    videos: [
      {
        'id': 'nova-fixture-series:1:1',
        'season': 1,
        'episode': 1,
        'name': 'The First Signal',
        'overview': 'A quiet night reveals an impossible pattern.',
        'released': '2026-01-08',
        'duration': '52 min',
      },
      {
        'id': 'nova-fixture-series:1:2',
        'season': 1,
        'episode': 2,
        'name': 'Across the Water',
        'overview': 'The team traces the signal beyond the old harbor.',
        'released': '2026-01-15',
        'duration': '49 min',
      },
    ],
  ),
  MediaItem(
    id: 'nova-fixture-movie-1',
    type: 'movie',
    name: 'Red Horizon',
    poster: 'https://nova.test/posters/red-horizon.png',
    background: 'https://nova.test/backdrops/red-horizon.png',
    description: 'A desert rescue becomes a journey through memory.',
    releaseInfo: '2025',
    rating: '8.2',
    runtime: '1h 48m',
    certification: 'PG',
    genres: ['Adventure', 'Drama'],
  ),
  MediaItem(
    id: 'nova-fixture-movie-2',
    type: 'movie',
    name: 'Midnight Archive',
    poster: 'https://nova.test/posters/midnight-archive.png',
    background: 'https://nova.test/backdrops/midnight-archive.png',
    description: 'An archivist finds a film that remembers its viewers.',
    releaseInfo: '2024',
    rating: '7.9',
    runtime: '1h 56m',
    certification: '12',
    genres: ['Mystery'],
  ),
  MediaItem(
    id: 'nova-fixture-series-2',
    type: 'series',
    name: 'مدينة الضوء',
    originalTitle: 'City of Light',
    poster: 'https://nova.test/posters/city-of-light.png',
    background: 'https://nova.test/backdrops/city-of-light.png',
    description: 'حكاية عائلة تعيد اكتشاف مدينتها بعد غياب طويل.',
    releaseInfo: '2026',
    rating: '8.4',
    runtime: '45 min',
    certification: 'PG',
    genres: ['دراما', 'عائلي'],
  ),
];

class _FixtureCatalogRepository extends CatalogRepository {
  _FixtureCatalogRepository(super.api);

  List<MediaItem> get _movies =>
      _fixtureItems.where((item) => item.type == 'movie').toList();
  List<MediaItem> get _series =>
      _fixtureItems.where((item) => item.type == 'series').toList();

  @override
  Future<List<MediaItem>> catalog(
    String type,
    String id, {
    Map<String, dynamic> extras = const {},
    Addon? addon,
  }) async {
    if (type == 'movie') return _movies;
    if (type == 'series') return _series;
    return _fixtureItems;
  }

  @override
  Future<List<MediaItem>> homeTopTen() async => _fixtureItems;

  @override
  Future<List<MediaItem>> anime() async =>
      [_fixtureItems.last, _fixtureItems[1]];

  @override
  Future<MediaItem?> detail(String type, String id, List<Addon> addons) async =>
      _fixtureItems.where((item) => item.id == id).firstOrNull ??
      _fixtureItems.first;

  @override
  Future<FeaturedArtwork> featuredArtwork(
    MediaItem item, {
    String language = 'en-US',
    String region = 'US',
    String uiLanguage = 'en',
  }) async =>
      FeaturedArtwork(
        portrait: item.poster,
        landscape: item.background,
        genre: item.genres.firstOrNull,
        overview: item.description,
      );

  @override
  Future<MediaItem> detailEnrichment(MediaItem item,
          {String language = 'en-US', String region = 'US'}) async =>
      item;

  @override
  Future<List<MediaItem>> tmdbRecommendations(
    MediaItem seed, {
    String language = 'en-US',
    String region = 'US',
  }) async =>
      _fixtureItems.where((item) => item.id != seed.id).toList();
}

void main() {
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  setUpAll(() async {
    final cache = Directory('build/nova-review/test-image-cache').absolute;
    await cache.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (_) async => cache.path);
    await _loadAcceptanceFonts();
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
  });

  final surfaces = <(String, Size)>[
    ('phone-320x640', const Size(320, 640)),
    ('tablet-landscape-1024x768', const Size(1024, 768)),
  ];

  for (final (surfaceName, size) in surfaces) {
    for (final english in [true, false]) {
      for (final brightness in Brightness.values) {
        final localeName = english ? 'en' : 'ar';
        final themeName = brightness.name;

        testWidgets(
            'Home $surfaceName $localeName $themeName is bounded and coverable',
            (tester) async {
          await _exercisePage(
            tester,
            pageName: 'home',
            surfaceName: surfaceName,
            size: size,
            english: english,
            brightness: brightness,
            pageBuilder: () => const Scaffold(body: HomePage()),
            heroOpacityKey: const ValueKey('home-hero-content-opacity'),
          );
        });

        testWidgets(
            'Details $surfaceName $localeName $themeName is bounded and coverable',
            (tester) async {
          await _exercisePage(
            tester,
            pageName: 'details',
            surfaceName: surfaceName,
            size: size,
            english: english,
            brightness: brightness,
            pageBuilder: () => MediaDetailPage(item: _fixtureItems.first),
            heroOpacityKey: const ValueKey('detail-hero-content-opacity'),
            verifyBackPill: true,
          );
        });
      }
    }
  }

  for (final english in [true, false]) {
    testWidgets(
        'Home phone-320x640 ${english ? 'en' : 'ar'} dark at 200% text scale',
        (tester) async {
      await _exercisePage(
        tester,
        pageName: 'home-a11y-200',
        surfaceName: 'phone-320x640',
        size: const Size(320, 640),
        english: english,
        brightness: Brightness.dark,
        pageBuilder: () => const Scaffold(body: HomePage()),
        heroOpacityKey: const ValueKey('home-hero-content-opacity'),
        textScale: 2,
      );
    });
  }
}

Future<void> _loadAcceptanceFonts() async {
  final poppins = FontLoader('Poppins');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    poppins.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
  }
  final arabic = FontLoader('IBMPlexSansArabic');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    arabic
        .addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-$weight.ttf'));
  }
  final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
  await Future.wait([poppins.load(), arabic.load(), lucide.load()]);
}

Future<void> _exercisePage(
  WidgetTester tester, {
  required String pageName,
  required String surfaceName,
  required Size size,
  required bool english,
  required Brightness brightness,
  required Widget Function() pageBuilder,
  required Key heroOpacityKey,
  bool verifyBackPill = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final api = NoorApi();
  final app = AppState(api, _FixtureCatalogRepository(api))
    ..english = english
    ..webSettings = {
      ...AppState.defaultSettings,
      'themeMode': brightness.name,
      'reduceMotion': true,
      'tmdbEnabled': false,
      'ratingsEnabled': false,
      'cloudSyncEnabled': false,
    };

  Widget host() => ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: NovaTheme.build(brightness, arabic: !english),
          locale: Locale(english ? 'en' : 'ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            NovaStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: size,
              padding: const EdgeInsets.only(top: 24, bottom: 16),
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(
              key: _captureBoundary,
              child: child!,
            ),
          ),
          home: pageBuilder(),
        ),
      );

  // Discover the exact production ImageProviders at both scroll positions,
  // then seed Flutter's image cache with generated local art. The acceptance
  // pass that follows performs no live image request.
  await tester.pumpWidget(host());
  await _settleFrames(tester);
  final discoveredImages = await _discoverVisibleImages(tester);
  await _scrollToCoveredState(tester);
  discoveredImages.addAll(await _discoverVisibleImages(tester));

  await tester.pumpWidget(const SizedBox.shrink());
  await _settleFrames(tester);
  while (tester.takeException() != null) {}
  await _seedFixtureImages(discoveredImages);
  await tester.pumpWidget(host());
  await _settleFrames(tester);

  expect(tester.takeException(), isNull);
  expect(Directionality.of(tester.element(find.byKey(_captureBoundary))),
      english ? TextDirection.ltr : TextDirection.rtl);
  expect(tester.getSize(find.byType(CinematicLayerStack)), size);
  expect(
      find.byKey(const ValueKey('cinematic-content-surface'),
          skipOffstage: false),
      findsOneWidget);
  expect(tester.widget<Opacity>(find.byKey(heroOpacityKey)).opacity, 1);

  if (verifyBackPill) {
    final button = find.descendant(
        of: find.byType(DetailBackPill), matching: find.byType(IconButton));
    final center = tester.getCenter(button);
    expect(center.dx,
        english ? lessThan(size.width / 2) : greaterThan(size.width / 2),
        reason: 'The back control must stay at directional start.');
  }

  await _captureIfRequested(
      tester,
      '$pageName-$surfaceName-${english ? 'en' : 'ar'}-'
      '${brightness.name}-initial.png');

  final position = await _scrollToCoveredState(tester);
  expect(position.pixels, greaterThan(300));
  expect(tester.widget<Opacity>(find.byKey(heroOpacityKey)).opacity,
      lessThanOrEqualTo(.05));
  expect(tester.takeException(), isNull);
  expect(tester.getSize(find.byType(CinematicLayerStack)), size);

  await _captureIfRequested(
      tester,
      '$pageName-$surfaceName-${english ? 'en' : 'ar'}-'
      '${brightness.name}-covered.png');

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  app.dispose();
  if (_writeAcceptanceImages) {
    await tester.pump(const Duration(seconds: 11));
  }
}

Future<ScrollPosition> _scrollToCoveredState(WidgetTester tester) async {
  final scrollView = find.byType(CustomScrollView).first;
  await tester.drag(scrollView, const Offset(0, -900));
  await _settleFrames(tester);
  return tester.state<ScrollableState>(find.byType(Scrollable).first).position;
}

Future<void> _settleFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<Map<Object, String>> _discoverVisibleImages(WidgetTester tester) async {
  final discovered = <Object, String>{};
  final entries = find.byType(Image).evaluate().toList(growable: false);
  for (final element in entries) {
    final provider = (element.widget as Image).image;
    final signature = _imageSignature(provider);
    if (!signature.contains('nova.test/')) continue;
    final configuration = createLocalImageConfiguration(element);
    final key = await provider.obtainKey(configuration);
    discovered[key] = signature;
  }
  return discovered;
}

Future<void> _seedFixtureImages(Map<Object, String> discovered) async {
  for (final entry in discovered.entries) {
    final key = entry.key;
    final image = await _buildFixtureImage(entry.value);
    PaintingBinding.instance.imageCache.evict(key, includeLive: true);
    PaintingBinding.instance.imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: image)),
      ),
    );
  }
}

String _imageSignature(ImageProvider provider) {
  if (provider is ResizeImage) return _imageSignature(provider.imageProvider);
  if (provider is CachedNetworkImageProvider) return provider.url;
  if (provider is NetworkImage) return provider.url;
  return provider.toString();
}

Future<ui.Image> _buildFixtureImage(String signature) {
  var seed = 17;
  for (final unit in signature.codeUnits) {
    seed = (seed * 31 + unit) & 0x7fffffff;
  }
  final hue = (seed % 360).toDouble();
  final first = HSVColor.fromAHSV(1, hue, .72, .60).toColor();
  final second = HSVColor.fromAHSV(1, (hue + 65) % 360, .82, .22).toColor();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = Size(180, 270);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(180, 270),
        [first, second],
      ),
  );
  canvas.drawCircle(const Offset(135, 68), 48,
      Paint()..color = Colors.white.withValues(alpha: .18));
  canvas.drawRect(const Rect.fromLTWH(18, 180, 144, 4),
      Paint()..color = Colors.white.withValues(alpha: .72));
  canvas.drawRect(const Rect.fromLTWH(18, 190, 90, 2),
      Paint()..color = Colors.white.withValues(alpha: .46));
  return recorder.endRecording().toImage(180, 270);
}

Future<void> _captureIfRequested(WidgetTester tester, String fileName) async {
  if (!_writeAcceptanceImages) return;
  await tester.runAsync(() async {
    final boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byKey(_captureBoundary));
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Could not encode $fileName');
    final file = File('build/nova-review/acceptance/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  });
}
