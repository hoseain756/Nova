import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/downloads/download_manager.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/downloads/downloads_page.dart';
import 'package:nova_mobile/features/downloads/downloads_view.dart';
import 'package:nova_mobile/features/onboarding/onboarding_page.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:nova_mobile/shared/widgets/nova_network_image.dart';
import 'package:provider/provider.dart';

class _FlowApp extends AppState {
  _FlowApp._(NoorApi api) : super(api, CatalogRepository(api));

  factory _FlowApp() => _FlowApp._(NoorApi());

  @override
  Future<void> setLanguage(bool value) async {
    english = value;
    webSettings = {...webSettings, 'uiLanguage': value ? 'en' : 'ar'};
    notifyListeners();
  }

  @override
  Future<void> setSetting(String key, dynamic value) async {
    webSettings = {...webSettings, key: value};
    notifyListeners();
  }
}

class _NeverAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      throw StateError('The layout acceptance test must not use the network.');
}

class _WidgetDownloadManager extends DownloadManager {
  _WidgetDownloadManager(this._items)
      : super.forTesting(
          downloadDirectory: () async => Directory.systemTemp,
          readMetadata: () async => null,
          writeMetadata: (_) async {},
          readSecret: (_) async => null,
          writeSecret: (_, __) async {},
          deleteSecret: (_) async {},
          dio: Dio()..httpClientAdapter = _NeverAdapter(),
        ) {
    initialized = true;
  }

  final List<NovaDownload> _items;

  @override
  List<NovaDownload> get jobs => List.unmodifiable(_items);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> remove(NovaDownload job) async {
    _items.remove(job);
    notifyListeners();
  }

  @override
  Future<void> cancel(NovaDownload job) async {
    job.status = 'cancelled';
    notifyListeners();
  }

  @override
  Future<void> retry(NovaDownload job) async {
    job.status = 'queued';
    notifyListeners();
  }
}

_WidgetDownloadManager _downloadManager() => _WidgetDownloadManager([
      NovaDownload(
        id: '11111111-1111-4111-8111-111111111111',
        title:
            'A deliberately long mixed title — الحلقة النهائية 2026 with commentary and extras',
        path: 'complete.mp4',
        status: 'complete',
        received: 314572800,
        total: 314572800,
      ),
      NovaDownload(
        id: '22222222-2222-4222-8222-222222222222',
        title: 'Downloading episode',
        path: 'active.mp4',
        status: 'downloading',
        received: 52428800,
        total: 104857600,
      ),
      NovaDownload(
        id: '33333333-3333-4333-8333-333333333333',
        title: 'Unavailable source',
        path: 'failed.mp4',
        status: 'failed',
        error: 'invalidSource',
      ),
    ]);

Widget _onboardingHarness({
  required _FlowApp app,
  required Size size,
  required Brightness brightness,
  required VoidCallback onComplete,
  double textScale = 2,
}) =>
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: Builder(builder: (context) {
        final english = context.watch<AppState>().english;
        return MaterialApp(
          theme: NovaTheme.build(brightness, arabic: !english),
          locale: Locale(english ? 'en' : 'ar'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            NovaStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: size,
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: OnboardingPage(onComplete: onComplete),
        );
      }),
    );

Widget _downloadsHarness({
  required DownloadManager manager,
  required Size size,
  required bool english,
  required Brightness brightness,
  double textScale = 2,
}) =>
    MaterialApp(
      theme: NovaTheme.build(brightness, arabic: !english),
      locale: Locale(english ? 'en' : 'ar'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        NovaStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: DownloadsPage(manager: manager),
    );

void main() {
  testWidgets('download row uses saved poster artwork when available',
      (tester) async {
    final job = NovaDownload(
      id: '44444444-4444-4444-8444-444444444444',
      title: 'Movie with artwork',
      path: 'movie.mp4',
      poster: 'https://images.example/poster.jpg',
      status: 'complete',
    );
    await tester.pumpWidget(MaterialApp(
      theme: NovaTheme.dark,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        NovaStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Scaffold(
        body: DownloadRow(
          job: job,
          onPlay: () {},
          onCancel: () {},
          onRetry: () {},
          onRemove: () {},
        ),
      ),
    ));
    expect(find.byType(NovaNetworkImage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  const scenarios = <({
    String name,
    Size size,
    bool english,
    Brightness brightness,
  })>[
    (
      name: 'English dark 320px at 200%',
      size: Size(320, 740),
      english: true,
      brightness: Brightness.dark,
    ),
    (
      name: 'Arabic light 320px at 200%',
      size: Size(320, 740),
      english: false,
      brightness: Brightness.light,
    ),
    (
      name: 'English light landscape at 200%',
      size: Size(740, 320),
      english: true,
      brightness: Brightness.light,
    ),
    (
      name: 'Arabic dark landscape at 200%',
      size: Size(740, 320),
      english: false,
      brightness: Brightness.dark,
    ),
    (
      name: 'Arabic light tablet at 200%',
      size: Size(1200, 800),
      english: false,
      brightness: Brightness.light,
    ),
  ];

  for (final scenario in scenarios) {
    testWidgets('onboarding fits ${scenario.name}', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = _FlowApp()..english = scenario.english;
      addTearDown(app.dispose);
      var completed = false;

      await tester.pumpWidget(_onboardingHarness(
        app: app,
        size: scenario.size,
        brightness: scenario.brightness,
        onComplete: () => completed = true,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final scrollable = find.byType(SingleChildScrollView);
      expect(scrollable, findsOneWidget);
      await tester.drag(scrollable, const Offset(0, -4000));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final startLabel = NovaStrings(
        Locale(scenario.english ? 'en' : 'ar'),
      ).text('startExploring');
      await tester.tap(find.text(startLabel));
      expect(completed, isTrue);
    });

    testWidgets('downloads fit ${scenario.name}', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final manager = _downloadManager();
      addTearDown(manager.dispose);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(_downloadsHarness(
        manager: manager,
        size: scenario.size,
        english: scenario.english,
        brightness: scenario.brightness,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final downloading = NovaStrings(
        Locale(scenario.english ? 'en' : 'ar'),
      ).text('downloading');
      await tester.scrollUntilVisible(
        find.text('Downloading episode'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is LinearProgressIndicator &&
              widget.semanticsLabel == downloading,
        ),
        findsOneWidget,
      );
      final cancel = NovaStrings(
        Locale(scenario.english ? 'en' : 'ar'),
      ).text('cancel');
      expect(
        find.bySemanticsLabel('$cancel: Downloading episode'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pump();
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('download removal cancel and confirmation preserve state',
      (tester) async {
    const size = Size(320, 740);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final manager = _downloadManager();
    addTearDown(manager.dispose);
    await tester.pumpWidget(_downloadsHarness(
      manager: manager,
      size: size,
      english: true,
      brightness: Brightness.dark,
    ));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text(
        'A deliberately long mixed title — الحلقة النهائية 2026 with commentary and extras',
      ),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final rowRemove = find.widgetWithText(TextButton, 'Remove').first;
    await tester.ensureVisible(rowRemove);
    await tester.pump();
    await tester.tap(rowRemove);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Cancel'),
    ));
    await tester.pumpAndSettle();
    expect(manager.jobs, hasLength(3));

    await tester.ensureVisible(rowRemove);
    await tester.tap(rowRemove);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(manager.jobs, hasLength(2));
    expect(tester.takeException(), isNull);
  });
}
