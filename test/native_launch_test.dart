import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/app/noor_app.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/cache_reset_service.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/storage/subtitle_font_store.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/core/update/app_update_service.dart';
import 'package:nova_mobile/features/onboarding/onboarding_page.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LaunchApp extends AppState {
  _LaunchApp._(NoorApi api) : super(api, CatalogRepository(api)) {
    english = true;
    webSettings = {'themeMode': 'dark', 'cacheResetHours': 0};
  }

  factory _LaunchApp() => _LaunchApp._(NoorApi());

  Completer<void> startup = Completer<void>();
  int attempts = 0;

  @override
  Future<void> initialize() async {
    attempts++;
    await startup.future;
    initialized = true;
    notifyListeners();
  }
}

// A pending remote update check must never delay the first usable frame.
class _PendingUpdateService extends AppUpdateService {
  final response = Completer<AppUpdateStatus>();

  @override
  Future<AppUpdateStatus> checkForUpdates() => response.future;
}

class _IosUpdateService extends AppUpdateService {
  int opened = 0;

  @override
  Future<AppUpdateStatus> checkForUpdates() async => const AppUpdateStatus(
        manifest: AppUpdateManifest(
          latestVersion: '1.0.5',
          latestBuild: 68,
          minBuild: 60,
          messageAr: '',
          androidUrl: 'https://example.com/app-release.apk',
          iosUrl: 'https://example.com/ios-install',
          iosLatestVersion: '1.0.6',
          iosLatestBuild: 69,
        ),
        currentVersion: '1.0.5',
        currentBuild: 68,
        platform: AppUpdatePlatform.ios,
      );

  @override
  Future<void> openIosUpdate(String url) async {
    expect(url, 'https://example.com/ios-install');
    opened++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'nova.onboarding.complete': true});
    // Font discovery uses platform/file IO, outside the widget fake clock.
    await SubtitleFontStore.instance.initialize();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('noor/links'), (_) async => null);
  });

  tearDown(() {
    CacheResetService.instance.stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('noor/links'), null);
  });

  testWidgets('retains the native splash until ready, then releases once',
      (tester) async {
    final app = _LaunchApp();
    addTearDown(app.dispose);
    var releases = 0;
    tester.binding.deferFirstFrame();
    addTearDown(() {
      if (releases == 0) tester.binding.allowFirstFrame();
    });

    Widget host() => NovaApp(
          state: app,
          requireAccount: true,
          updateService: _PendingUpdateService(),
          onLaunchReady: () {
            releases++;
            tester.binding.allowFirstFrame();
          },
        );

    await tester.pumpWidget(host());
    await tester.pump();
    expect(releases, 0);
    expect(tester.binding.sendFramesToEngine, isFalse);

    app.startup.complete();
    await tester.pump();
    await tester.pump();
    expect(releases, 1);
    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(
      find.text(
          NovaStrings(const Locale('en')).text('accountConfigurationMissing')),
      findsOneWidget,
    );

    await tester.pumpWidget(host());
    await tester.pump();
    expect(releases, 1);
    expect(app.attempts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    CacheResetService.instance.stop();
  });

  testWidgets('opens first-run onboarding directly without an animation wait',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = _LaunchApp();
    addTearDown(app.dispose);
    var releases = 0;
    await tester.pumpWidget(NovaApp(
      state: app,
      updateService: _PendingUpdateService(),
      onLaunchReady: () => releases++,
    ));
    await tester.pump();
    app.startup.complete();
    await tester.pump();
    await tester.pump();

    expect(releases, 1);
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    CacheResetService.instance.stop();
  });

  testWidgets('offers an available iOS update without blocking launch',
      (tester) async {
    final app = _LaunchApp();
    addTearDown(app.dispose);
    final service = _IosUpdateService();
    await tester.pumpWidget(NovaApp(
      state: app,
      requireAccount: true,
      updateService: service,
    ));
    app.startup.complete();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('NOVA 1.0.6 is available.'), findsOneWidget);
    expect(find.text('Open update page'), findsOneWidget);
    await tester.tap(find.text('Open update page'));
    await tester.pumpAndSettle();
    expect(service.opened, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    CacheResetService.instance.stop();
  });

  testWidgets('startup failure releases to themed RTL retry UI and can recover',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final app = _LaunchApp()
      ..english = false
      ..webSettings = {'themeMode': 'light', 'cacheResetHours': 0};
    addTearDown(app.dispose);
    var releases = 0;
    await tester.pumpWidget(NovaApp(
      state: app,
      requireAccount: true,
      updateService: _PendingUpdateService(),
      onLaunchReady: () => releases++,
    ));
    await tester.pump();
    app.startup.completeError(StateError('local startup unavailable'));
    await tester.pump();
    await tester.pump();

    final strings = NovaStrings(const Locale('ar'));
    expect(releases, 1);
    expect(find.textContaining(strings.text('startError')), findsOneWidget);
    final retry = find.text(strings.text('retry'));
    final context = tester.element(retry);
    expect(Directionality.of(context), TextDirection.rtl);
    expect(
        Theme.of(context).scaffoldBackgroundColor, NovaColors.lightBackground);
    expect(tester.takeException(), isNull);

    app.startup = Completer<void>();
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    expect(app.attempts, 2);
    expect(releases, 1);
    expect(find.textContaining(strings.text('startError')), findsOneWidget);

    app.startup.complete();
    await tester.pump();
    await tester.pump();
    expect(releases, 1);
    expect(find.textContaining(strings.text('startError')), findsNothing);
    expect(
        find.text(strings.text('accountConfigurationMissing')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    CacheResetService.instance.stop();
  });
}
