import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/media/widgets/linked_comments.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:provider/provider.dart';

class _CommentsApi extends NoorApi {
  List<Map<String, dynamic>> trakt = [];
  List<Map<String, dynamic>> anilist = [];
  int requests = 0;

  @override
  Future<List<Map<String, dynamic>>> traktComments({
    required String mediaId,
    required String type,
  }) async {
    requests++;
    return trakt;
  }

  @override
  Future<List<Map<String, dynamic>>> aniListThreads(int mediaId) async {
    requests++;
    return anilist;
  }
}

class _CommentsApp extends AppState {
  _CommentsApp(_CommentsApi api) : super(api, CatalogRepository(api)) {
    english = true;
    webSettings = {
      ...webSettings,
      'showTraktComments': true,
      'showAnilistComments': true,
    };
  }

  String? account = 'account-a';
  String? profile = 'profile-a';

  @override
  String? get activeAccountId => account;
  @override
  String? get activeProfileId => profile;

  void switchProfile(String value) {
    profile = value;
    notifyListeners();
  }
}

const _item = MediaItem(
  id: 'tt1234567',
  type: 'series',
  name: 'Test series',
  anilistId: 42,
);

Map<String, dynamic> _comment({
  int id = 1,
  String source = 'trakt',
  String? title,
  String text = 'A thoughtful discussion of the story.',
  bool spoiler = false,
  String? url,
}) =>
    {
      'source': source,
      'id': id,
      'username': 'reader-$id',
      if (title != null) 'title': title,
      'text': text,
      'spoiler': spoiler,
      'url': url ?? 'https://trakt.tv/comments/$id',
    };

Widget _harness(
  _CommentsApp app, {
  Brightness brightness = Brightness.dark,
  double scale = 1,
}) =>
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(
        theme: NovaTheme.build(brightness, arabic: !app.english),
        locale: Locale(app.english ? 'en' : 'ar'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          NovaStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: LinkedComments(item: _item),
          ),
        ),
      ),
    );

_CommentsApp _app(_CommentsApi api) {
  final app = _CommentsApp(api);
  addTearDown(app.dispose);
  addTearDown(api.dispose);
  return app;
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const launcher = MethodChannel('plugins.flutter.io/url_launcher');
  final launches = <MethodCall>[];

  setUp(() {
    launches.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (call) async {
      launches.add(call);
      return true;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, null);
  });

  testWidgets('disabled discussions make no provider requests', (tester) async {
    final api = _CommentsApi()..trakt = [_comment()];
    final app = _app(api);
    app.webSettings = {
      ...app.webSettings,
      'showTraktComments': false,
      'showAnilistComments': false,
    };

    await tester.pumpWidget(_harness(app));
    await tester.pumpAndSettle();

    expect(api.requests, 0);
    expect(find.text('Comments and discussions'), findsNothing);
  });

  testWidgets('concealed discussion excludes both title and body until reveal',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final api = _CommentsApi()
      ..anilist = [
        _comment(
          source: 'anilist',
          title: 'The secret ending',
          text: '<p>The hidden conclusion.</p>',
          url: 'https://anilist.co/forum/thread/1',
        ),
      ];
    final app = _app(api);
    await tester.pumpWidget(_harness(app));
    await tester.pumpAndSettle();

    try {
      expect(find.text('The secret ending'), findsNothing);
      expect(find.textContaining('The hidden conclusion'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('secret ending|hidden conclusion')),
          findsNothing);
    } finally {
      semantics.dispose();
    }
    await tester.tap(find.text('Reveal comment'));
    await tester.pumpAndSettle();

    expect(find.text('The secret ending'), findsOneWidget);
    expect(find.textContaining('The hidden conclusion'), findsOneWidget);
    expect(find.text('Read more'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit and inline spoilers remain concealed when blur is off',
      (tester) async {
    _viewport(tester, const Size(1000, 700));
    final api = _CommentsApi()
      ..trakt = [
        _comment(text: 'Flagged spoiler', spoiler: true),
        _comment(id: 2, text: '[spoiler]Inline surprise[/spoiler]'),
      ]
      ..anilist = [
        _comment(
          id: 3,
          source: 'anilist',
          title: 'Spoiler thread title',
          text: '<span class="spoiler">Another secret</span>',
        ),
      ];
    final app = _app(api);
    app.webSettings = {
      ...app.webSettings,
      'blurTraktComments': false,
      'anilistBlurComments': false,
    };
    await tester.pumpWidget(_harness(app));
    await tester.pumpAndSettle();

    expect(find.text('Flagged spoiler'), findsNothing);
    expect(find.textContaining('Inline surprise'), findsNothing);
    expect(find.text('Spoiler thread title'), findsNothing);
    expect(find.textContaining('Another secret'), findsNothing);
    expect(find.text('Read more'), findsNothing);
    await tester.tap(find.text('Reveal comment').first);
    await tester.pumpAndSettle();
    expect(find.text('Flagged spoiler'), findsOneWidget);
    expect(find.textContaining('Inline surprise'), findsNothing);
    expect(find.textContaining('Another secret'), findsNothing);
  });

  testWidgets('reader keeps the full sanitized comment and opens its source',
      (tester) async {
    _viewport(tester, const Size(390, 844));
    final fullText =
        '${List.filled(50, 'A detailed observation about the story.').join(' ')} END_OF_LONG_COMMENT';
    final api = _CommentsApi()..trakt = [_comment(text: '<p>$fullText</p>')];
    final app = _app(api);
    app.webSettings = {...app.webSettings, 'blurTraktComments': false};
    await tester.pumpWidget(_harness(app));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    final body = find.descendant(of: sheet, matching: find.text(fullText));
    expect(body, findsOneWidget);
    expect(find.textContaining('<p>'), findsNothing);
    final open =
        find.descendant(of: sheet, matching: find.text('Open discussion'));
    final scrollable =
        find.descendant(of: sheet, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(open, 300, scrollable: scrollable);
    await tester.tap(open);
    await tester.pumpAndSettle();

    expect(launches, hasLength(1));
    expect(launches.single.method, 'launch');
    final arguments = launches.single.arguments as Map;
    expect(arguments['url'], 'https://trakt.tv/comments/1');
    expect(arguments['useSafariVC'], false);
    expect(arguments['useWebView'], false);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reader omits external actions for unsafe discussion URLs',
      (tester) async {
    for (final url in [
      'http://trakt.tv/comments/1',
      'https://trakt.tv.example.com/comments/1',
      'https://someone@trakt.tv/comments/1',
      'https://anilist.co:8443/forum/thread/1',
    ]) {
      final api = _CommentsApi()..trakt = [_comment(url: url)];
      final app = _app(api);
      app.webSettings = {...app.webSettings, 'blurTraktComments': false};
      await tester.pumpWidget(_harness(app));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Open discussion'), findsNothing, reason: url);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
    expect(launches, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching profiles clears previously revealed comments',
      (tester) async {
    final api = _CommentsApi()
      ..trakt = [_comment(text: 'Private reveal choice')];
    final app = _app(api);
    await tester.pumpWidget(_harness(app));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reveal comment'));
    await tester.pumpAndSettle();
    expect(find.text('Private reveal choice'), findsOneWidget);

    app.switchProfile('profile-b');
    await tester.pumpAndSettle();
    expect(find.text('Private reveal choice'), findsNothing);
    expect(find.text('Reveal comment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final layout in [
    (english: true, brightness: Brightness.light, width: 320.0, scale: 2.0),
    (english: true, brightness: Brightness.dark, width: 320.0, scale: 2.0),
    (english: false, brightness: Brightness.light, width: 320.0, scale: 2.0),
    (english: false, brightness: Brightness.dark, width: 320.0, scale: 2.0),
    (english: true, brightness: Brightness.dark, width: 1000.0, scale: 1.0),
  ]) {
    testWidgets(
        'horizontal cards and reader fit ${layout.width} ${layout.english} '
        '${layout.brightness} at ${layout.scale}x', (tester) async {
      _viewport(tester, Size(layout.width, 568));
      final api = _CommentsApi()
        ..trakt = [
          for (var index = 1; index <= 3; index++)
            _comment(
              id: index,
              title: layout.english
                  ? 'A long discussion title about the whole season'
                  : 'نقاش طويل عن تفاصيل القصة وأحداث الموسم بالكامل',
              text: layout.english
                  ? List.filled(
                          12, 'A thoughtful observation about this story.')
                      .join(' ')
                  : List.filled(12, 'رأي عن أحداث هذه القصة وتفاصيل الشخصيات.')
                      .join(' '),
            ),
        ];
      final app = _app(api)..english = layout.english;
      app.webSettings = {...app.webSettings, 'blurTraktComments': false};
      await tester.pumpWidget(
          _harness(app, brightness: layout.brightness, scale: layout.scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final rail = find.byKey(const ValueKey('detail-discussion-scroll'));
      expect(tester.widget<ListView>(rail).scrollDirection, Axis.horizontal);
      if (layout.width < 600) {
        expect(find.text('reader-3').hitTestable(), findsNothing);
        for (var index = 0; index < 2; index++) {
          await tester.drag(rail, Offset(layout.english ? -270 : 270, 0));
          await tester.pumpAndSettle();
        }
        expect(find.text('reader-3').hitTestable(), findsOneWidget);
      }

      final read = find
          .text(NovaStrings.lookup(layout.english, 'discussionReadMore'))
          .last;
      await tester.ensureVisible(read);
      await tester.pumpAndSettle();
      await tester.tap(read);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      final open = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(
              NovaStrings.lookup(layout.english, 'linkedOpenDiscussion')));
      final scrollable = find
          .descendant(
              of: find.byType(BottomSheet), matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(open, 220, scrollable: scrollable);
      expect(open.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
