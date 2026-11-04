// Widget test — pins the Task 119 edge-to-edge contract of the main shell:
//
//  1. The HOME page is FULL-BLEED: its scroll view starts at y=0, so the
//     featured hero (and its artwork) bleeds behind the fully transparent
//     status bar instead of leaving a solid strip above the content.
//  2. The other four tabs keep their status-bar inset (SafeArea wrapper) —
//     identical geometry to the old shell-wide SafeArea.
//  3. The floating chrome (glass search button) is pushed below the status
//     bar (`safeTop + 12`) and never collides with the clock/battery icons.
//
// The shell is pumped with a REAL AppState whose CatalogRepository is an
// offline fake (instant empty results) so no network access is needed.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/addon.dart';
import 'package:nova_mobile/core/models/featured_artwork.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/horse_theme.dart';
import 'package:nova_mobile/features/anime/anime_page.dart';
import 'package:nova_mobile/features/home/home_page.dart';
import 'package:nova_mobile/features/kids/kids_page.dart';
import 'package:nova_mobile/features/library/library_page.dart';
import 'package:nova_mobile/features/settings/settings_page.dart';
import 'package:nova_mobile/features/shell/main_shell.dart';
import 'package:nova_mobile/features/shell/glass_dock.dart';
import 'package:nova_mobile/shared/widgets/glass_navigation.dart';

/// Offline, instant repository: every catalog source resolves empty so the
/// shell can be pumped deterministically without network access.
class _FakeCatalogRepository extends CatalogRepository {
  _FakeCatalogRepository(super.api);

  @override
  Future<List<MediaItem>> catalog(
    String type,
    String id, {
    Map<String, dynamic> extras = const {},
    Addon? addon,
  }) async =>
      const <MediaItem>[];

  @override
  Future<List<MediaItem>> homeTopTen() async => const <MediaItem>[];

  @override
  Future<List<MediaItem>> anime() async => const <MediaItem>[];

  @override
  Future<List<MediaItem>> kids({bool series = false}) async =>
      const <MediaItem>[];

  @override
  Future<FeaturedArtwork> featuredArtwork(
    MediaItem item, {
    String language = 'en-US',
    String region = 'US',
    String uiLanguage = 'en',
  }) async =>
      const FeaturedArtwork();

  @override
  Future<List<MediaItem>> tmdbRecommendations(
    MediaItem seed, {
    String language = 'en-US',
    String region = 'US',
  }) async =>
      const <MediaItem>[];
}

Widget _harness(
    {double safeTop = 44,
    Size size = const Size(400, 860),
    TextDirection direction = TextDirection.ltr,
    TextScaler scaler = TextScaler.noScaling,
    TargetPlatform? platform}) {
  final api = NoorApi();
  final app = AppState(api, _FakeCatalogRepository(api));
  return ChangeNotifierProvider<AppState>.value(
    value: app,
    child: MaterialApp(
      theme: platform == null
          ? HorseTheme.dark
          : HorseTheme.dark.copyWith(platform: platform),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: scaler,
          padding: EdgeInsets.only(top: safeTop),
          viewPadding: EdgeInsets.only(top: safeTop),
        ),
        child:
            Directionality(textDirection: direction, child: const MainShell()),
      ),
    ),
  );
}

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
        'tablet sidebar is at logical start with large text: $direction',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_harness(
          size: const Size(1024, 900),
          direction: direction,
          scaler: const TextScaler.linear(2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final home = tester.getRect(find.byType(HomePage));
      expect(home.width, 1024 - 228);
      expect(home.left, direction == TextDirection.ltr ? 228 : 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('iOS capability changes retire and restore shell chrome',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    // Other shell tests may have initialized the cached theme on Android.
    expect(HorseTheme.dark.brightness, Brightness.dark);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const channel = MethodChannel('nova/ios_chrome/v1');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var available = true;
    var capabilitiesRead = 0;
    var retirements = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getCapabilities') {
        capabilitiesRead++;
        return {
          'osMajor': 26,
          'systemGlassAvailable': true,
          'nativeChromeAvailable': available,
          'phoneIdiom': true
        };
      }
      if (call.method == 'dispose') retirements++;
      return null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    try {
      await tester.pumpWidget(_harness(platform: TargetPlatform.iOS));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(GlassDock), findsNothing);
      available = false;
      await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec()
              .encodeMethodCall(const MethodCall('capabilitiesChanged')),
          (_) {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(retirements, greaterThanOrEqualTo(1));
      expect(find.byType(GlassDock), findsOneWidget);
      available = true;
      await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec()
              .encodeMethodCall(const MethodCall('capabilitiesChanged')),
          (_) {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(GlassDock), findsNothing);
      final beforeResume = capabilitiesRead;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(capabilitiesRead, greaterThan(beforeResume));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('shell edge-to-edge contract (Task 119)', (tester) async {
    // Keep the RenderView's logical bounds aligned with the MediaQuery below;
    // otherwise the dock is laid out past the test view and cannot receive taps.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_harness());
    // Let the page futures resolve (fake repo → instant) and frames settle.
    // Fixed pumps — pumpAndSettle can hang on the loading skeletons.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 80));

    expect(tester.takeException(), isNull);

    // 1) Home is edge-to-edge: the page's scroll view starts at the very
    //    top of the screen (y=0) — before Task 119 it sat at `safeTop`
    //    because the shell SafeArea pushed every page below the status bar.
    //    (Task 136: the pages now live in an Offstage Stack instead of an
    //    IndexedStack — the geometry contract is unchanged.)
    final homeScroll = find
        .descendant(
          of: find.byType(MainShell),
          matching: find.byType(CustomScrollView),
        )
        .first;
    expect(
      tester.getTopLeft(homeScroll).dy,
      0,
      reason: 'HomePage content must start at y=0 (edge-to-edge hero)',
    );

    // Tabs remain unmounted until their first visit; lazy startup must not
    // fetch Kids/Library/Settings merely because the shell became visible.
    for (final page in const [AnimePage, KidsPage, LibraryPage, SettingsPage]) {
      expect(find.byType(page, skipOffstage: false), findsNothing);
    }
    expect(
      find.ancestor(
        of: find.byType(HomePage, skipOffstage: false),
        matching: find.byType(SafeArea, skipOffstage: false),
      ),
      findsNothing,
      reason: 'HomePage is the edge-to-edge page — no SafeArea ancestor',
    );

    // 3) The glass search button clears the status icons: safeTop + 12.
    expect(
      tester.getTopLeft(find.byType(GlassSearchButton)).dy,
      44 + 12,
      reason: 'shell chrome must sit below the status bar',
    );

    // 4) Scrolling the home page keeps working (content flows under the
    //    transparent bar) — drag up and expect no exceptions.
    await tester.drag(homeScroll, const Offset(0, -240));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);

    await tester.drag(homeScroll, const Offset(0, 140));
    // Process the reveal state change, then let its slide transition finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('My Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LibraryPage), findsOneWidget);
    expect(
        find.ancestor(
            of: find.byType(LibraryPage), matching: find.byType(SafeArea)),
        findsWidgets);
    expect(tester.getTopLeft(find.byType(LibraryPage)).dy, 44);
    expect(find.byType(AnimePage, skipOffstage: false), findsNothing);
    expect(find.byType(KidsPage, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
