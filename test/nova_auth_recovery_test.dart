import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/settings/integrations_page.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:provider/provider.dart';

class _AuthApi extends NoorApi {
  _AuthApi({this.failCodeSubmission = false});

  final bool failCodeSubmission;
  int startCalls = 0;
  int submitCalls = 0;

  @override
  Future<Map<String, dynamic>?> startAniListLink() async {
    startCalls++;
    return <String, dynamic>{
      'authorizeUrl': 'https://anilist.example/authorize',
    };
  }

  @override
  Future<Map<String, dynamic>?> startTraktLink() async {
    startCalls++;
    return <String, dynamic>{
      'authorizeUrl': 'https://trakt.example/authorize',
    };
  }

  @override
  Future<String> traktLinkMethod() async => 'direct';

  @override
  Future<Map<String, dynamic>?> startLinkedService(String service) async {
    startCalls++;
    return <String, dynamic>{
      'device_code': 'device-code',
      'user_code': 'USER-CODE',
      'verification_url': 'https://simkl.example/activate',
      'interval': 3,
      'expires_in': 600,
    };
  }

  @override
  Future<Map<String, dynamic>> submitAniListCode(String input) async {
    submitCalls++;
    if (failCodeSubmission) {
      throw StateError('secure storage unavailable');
    }
    return <String, dynamic>{'status': 'success'};
  }
}

class _AuthAppState extends AppState {
  _AuthAppState(_AuthApi api) : super(api, CatalogRepository(api)) {
    english = true;
  }
}

Widget _harness(_AuthAppState app) => ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(
        theme: NovaTheme.dark,
        locale: const Locale('en'),
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          NovaStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: const IntegrationsPage(),
      ),
    );

Future<void> _openAniList(WidgetTester tester) async {
  await _openService(tester, 'AniList');
}

Future<void> _openService(WidgetTester tester, String service) async {
  await tester.tap(find.text(service));
  await tester.pumpAndSettle();
  expect(find.text('Connect $service'), findsOneWidget);
}

Dio _rejectingDio(DioException Function(RequestOptions) error) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(error(options)),
    ),
  );
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  var launchSucceeds = true;

  setUp(() {
    launchSucceeds = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async {
      if (call.method == 'launch') return launchSucceeds;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, null);
  });

  testWidgets('failed browser launch returns AniList card to a retryable state',
      (tester) async {
    launchSucceeds = false;
    final api = _AuthApi();
    final app = _AuthAppState(api);
    addTearDown(app.dispose);

    await tester.pumpWidget(_harness(app));
    await _openAniList(tester);
    await tester.tap(find.text('Connect AniList'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Could not start the link.'), findsOneWidget);
    final retryButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Connect AniList'),
    );
    expect(retryButton.onPressed, isNotNull);
    expect(find.text('Waiting for browser approval…'), findsNothing);

    await tester.tap(find.text('Connect AniList'));
    await tester.pump();
    expect(api.startCalls, 2);
  });

  for (final (service, errorMessage) in const <(String, String)>[
    ('Trakt', 'Could not start the Trakt link.'),
    ('Simkl', 'Could not create the link code.'),
  ]) {
    testWidgets('failed $service launch returns its card to a retryable state',
        (tester) async {
      launchSucceeds = false;
      final api = _AuthApi();
      final app = _AuthAppState(api);
      addTearDown(app.dispose);

      await tester.pumpWidget(_harness(app));
      await _openService(tester, service);
      await tester.tap(find.text('Connect $service'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(errorMessage), findsOneWidget);
      final retryButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Connect $service'),
      );
      expect(retryButton.onPressed, isNotNull);
    });
  }

  testWidgets('manual OAuth failure restores the Finish action',
      (tester) async {
    final api = _AuthApi(failCodeSubmission: true);
    final app = _AuthAppState(api);
    addTearDown(app.dispose);

    await tester.pumpWidget(_harness(app));
    await _openAniList(tester);
    await tester.tap(find.text('Connect AniList'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField), 'oauth-code');
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(
          'Could not complete with this code — check it or restart the link.'),
      findsOneWidget,
    );
    final finishButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Finish'),
    );
    expect(finishButton.onPressed, isNotNull);

    await tester.tap(find.text('Finish'));
    await tester.pump();
    expect(api.submitCalls, 2);
  });

  test('device polling keeps connection timeouts pending', () async {
    final dio = _rejectingDio(
      (options) => DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      ),
    );
    final api = NoorApi(dio: dio);
    addTearDown(api.dispose);

    final result = await api.pollLinkedService(
      'simkl',
      const <String, dynamic>{'device_code': 'device-code'},
    );

    expect(result, <String, dynamic>{
      'status': 'pending',
      'reason': 'transient_network',
    });
  });

  test('device polling keeps temporary provider failures pending', () async {
    final dio = _rejectingDio(
      (options) => DioException.badResponse(
        statusCode: 503,
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 503,
          data: const <String, dynamic>{'error': 'unavailable'},
        ),
      ),
    );
    final api = NoorApi(dio: dio);
    addTearDown(api.dispose);

    final result = await api.pollLinkedService(
      'simkl',
      const <String, dynamic>{'device_code': 'device-code'},
    );

    expect(result?['status'], 'pending');
  });

  test('device polling preserves terminal authorization failures', () async {
    final dio = _rejectingDio(
      (options) => DioException.badResponse(
        statusCode: 401,
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 401,
          data: const <String, dynamic>{'error': 'invalid_grant'},
        ),
      ),
    );
    final api = NoorApi(dio: dio);
    addTearDown(api.dispose);

    final result = await api.pollLinkedService(
      'simkl',
      const <String, dynamic>{'device_code': 'device-code'},
    );

    expect(result?['status'], 'error');
  });
}
