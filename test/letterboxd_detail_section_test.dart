import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/letterboxd/letterboxd_settings.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/media/letterboxd_detail_section.dart';
import 'package:nova_mobile/features/media/widgets/detail_discussion_rail.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:provider/provider.dart';

class _DetailApp extends AppState {
  _DetailApp(NoorApi api) : super(api, CatalogRepository(api)) {
    english = true;
  }

  @override
  LetterboxdSession? get letterboxdSession => LetterboxdSession(
        userToken: 'unit-token',
        userId: 'user123',
        username: 'viewer',
        loginAt: DateTime.utc(2026, 11, 4),
      );
}

_DetailApp _fixture({List<String>? reviews, bool full = true}) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    final data = options.uri.path.contains('/stream/')
        ? {
            'streams': [
              {
                'name': 'Letterboxd',
                'description':
                    '4.2 / 5 (1.2K ratings)\n✓ Watched\n♥ Liked\nIn Watchlist\nYour rating: 4.5',
                'externalUrl': 'https://letterboxd.com/film/test-film/',
              },
              for (final action in ['rate', 'watched', 'liked', 'watchlist'])
                {
                  'name': action,
                  'externalUrl':
                      'https://api.stremboxd.com/action/user123/$action/film123?tok=signed',
                },
            ],
          }
        : {
            'meta': {
              'id': 'tt1234567',
              'name': 'Test film',
              'links': [
                for (final (index, text) in (reviews ??
                        ['Short review', 'Second review', 'Last review'])
                    .indexed)
                  {
                    'category': 'Letterboxd Popular Reviews',
                    'name': text,
                    'url':
                        'https://letterboxd.com/viewer/film/test-film/$index/',
                  },
              ],
            },
          };
    handler.resolve(Response<dynamic>(
        requestOptions: options, statusCode: 200, data: data));
  }));
  final app = _DetailApp(NoorApi(dio: dio));
  app.webSettings = {
    ...app.webSettings,
    'letterboxd': LetterboxdSettings.defaults
        .copyWith(
          enabled: true,
          mode: full
              ? LetterboxdSettings.fullMode
              : LetterboxdSettings.publicMode,
          username: 'viewer',
        )
        .toJson(),
  };
  return app;
}

Widget _harness(_DetailApp app, {bool light = false, double scale = 1}) =>
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(
        theme: NovaTheme.build(light ? Brightness.light : Brightness.dark,
            arabic: !app.english),
        locale: Locale(app.english ? 'en' : 'ar'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          NovaStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LetterboxdDetailSection(
                item: MediaItem(id: 'tt1234567', type: 'movie', name: 'Test'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _show(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  final launched = <String>[];

  setUp(() {
    launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async {
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, null);
  });

  testWidgets(
      'Full details retain ratings, status and protected horizontal reviews',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _fixture();
    addTearDown(app.dispose);
    await tester.pumpWidget(_harness(app));
    await tester.pumpAndSettle();

    expect(find.text('Letterboxd rating'), findsOneWidget);
    expect(find.text('4.2 / 5'), findsOneWidget);
    expect(find.text('4.5 / 5'), findsOneWidget);
    expect(find.text('Watched'), findsOneWidget);
    expect(find.text('Liked'), findsOneWidget);
    expect(find.text('In watchlist'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Short review'), findsNothing);
    expect(find.text('Second review'), findsNothing);

    final reveal = find.text('Reveal review').first;
    await _show(tester, reveal);
    await tester.tap(reveal);
    await tester.pumpAndSettle();
    expect(find.text('Short review'), findsOneWidget);
    expect(find.text('Second review'), findsNothing);

    final rail = find.byKey(const ValueKey('detail-discussion-scroll'));
    expect(tester.widget<ListView>(rail).scrollDirection, Axis.horizontal);
    await tester.drag(rail, const Offset(-650, 0));
    await tester.pumpAndSettle();
    final lastCard = find.byKey(const ValueKey('letterboxd-review-2'));
    expect(lastCard, findsOneWidget);
    final lastReveal =
        find.descendant(of: lastCard, matching: find.text('Reveal review'));
    await tester.tap(lastReveal);
    await tester.pumpAndSettle();
    expect(find.text('Last review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all Letterboxd actions keep their external destinations',
      (tester) async {
    final app = _fixture(reviews: []);
    addTearDown(app.dispose);
    await tester.pumpWidget(_harness(app));
    await tester.pumpAndSettle();
    final actions = {
      'Open on Letterboxd': 'https://letterboxd.com/film/test-film/',
      for (final (label, action) in [
        ('Rate', 'rate'),
        ('Mark watched', 'watched'),
        ('Like', 'liked'),
        ('Watchlist', 'watchlist'),
      ])
        label:
            'https://api.stremboxd.com/action/user123/$action/film123?tok=signed',
    };
    for (final action in actions.entries) {
      final target = find.text(action.key);
      await _show(tester, target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(launched.last, action.value);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('reader retains long review and original external review link',
      (tester) async {
    final review =
        '${List.filled(100, 'Thoughtful cinema.').join(' ')} Final line.';
    final app = _fixture(reviews: [review]);
    app.webSettings['letterboxdBlurReviews'] = false;
    addTearDown(app.dispose);
    await tester.pumpWidget(_harness(app));
    await tester.pumpAndSettle();
    final rail =
        tester.widget<DetailDiscussionRail>(find.byType(DetailDiscussionRail));
    expect(rail.entries.single.body, review);
    final read = find.text(app.tr('discussionReadMore'));
    await _show(tester, read);
    await tester.tap(read);
    await tester.pumpAndSettle();
    final open = find.text('Open reviews on Letterboxd');
    await _show(tester, open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(launched.single, 'https://letterboxd.com/viewer/film/test-film/0/');
    expect(tester.takeException(), isNull);
  });

  for (final english in [true, false]) {
    for (final light in [true, false]) {
      for (final width in [320.0, 1024.0]) {
        testWidgets(
            'responsive details: english=$english light=$light width=$width scale=2',
            (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final app = _fixture()..english = english;
          addTearDown(app.dispose);
          await tester.pumpWidget(_harness(app, light: light, scale: 2));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final reveal = find.text(app.tr('letterboxdRevealReview')).first;
          await _show(tester, reveal);
          await tester.tap(reveal);
          await tester.pumpAndSettle();
          expect(find.text('Short review'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
      'Public mode keeps a useful film link without empty rating panels',
      (tester) async {
    final app = _fixture(full: false);
    addTearDown(app.dispose);
    await tester.pumpWidget(_harness(app));
    await tester.pumpAndSettle();
    expect(find.text('Letterboxd'), findsOneWidget);
    expect(find.text('Letterboxd rating'), findsNothing);
    expect(find.byType(DetailDiscussionRail), findsNothing);
    await tester.tap(find.text('Open on Letterboxd'));
    await tester.pumpAndSettle();
    expect(launched.single, 'https://letterboxd.com/imdb/tt1234567/');
    expect(tester.takeException(), isNull);
  });
}
