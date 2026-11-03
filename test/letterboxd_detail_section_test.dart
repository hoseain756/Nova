import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/letterboxd/letterboxd_settings.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/features/media/letterboxd_detail_section.dart';
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

void main() {
  testWidgets('Full film detail shows bridge ratings, status and review reveal',
      (tester) async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final data = options.uri.path.contains('/stream/')
          ? {
              'streams': [
                {
                  'name': 'Letterboxd',
                  'description':
                      '4.2 / 5 (1.2K ratings)\n✓ Watched\nYour rating: 4.5',
                  'externalUrl': 'https://letterboxd.com/film/test-film/',
                },
                {
                  'name': 'Rate',
                  'externalUrl':
                      'https://api.stremboxd.com/action/user123/rate/film123?tok=signed',
                },
              ],
            }
          : {
              'meta': {
                'id': 'tt1234567',
                'name': 'Test film',
                'links': [
                  {
                    'category': 'Letterboxd Popular Reviews',
                    'name': 'Short review',
                    'url': 'https://letterboxd.com/film/test-film/reviews/',
                  },
                ],
              },
            };
      handler.resolve(Response<dynamic>(
          requestOptions: options, statusCode: 200, data: data));
    }));
    final api = NoorApi(dio: dio);
    final app = _DetailApp(api);
    app.webSettings = {
      ...app.webSettings,
      'letterboxd': LetterboxdSettings.defaults
          .copyWith(
            enabled: true,
            mode: LetterboxdSettings.fullMode,
            username: 'viewer',
          )
          .toJson(),
    };

    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LetterboxdDetailSection(
              item: MediaItem(id: 'tt1234567', type: 'movie', name: 'Test'),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Letterboxd rating'), findsOneWidget);
    expect(find.text('4.2 / 5'), findsOneWidget);
    expect(find.text('Watched'), findsOneWidget);
    expect(find.text('Rate on Letterboxd'), findsOneWidget);
    expect(find.text('Short review'), findsNothing);
    await tester.tap(find.text('Reveal review'));
    await tester.pump();
    expect(find.text('Short review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
