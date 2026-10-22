import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/kids/kids_page.dart';
import 'package:nova_mobile/features/shell/nova_browse_widgets.dart';

class _KidsCatalog extends CatalogRepository {
  _KidsCatalog(super.api);

  @override
  Future<List<MediaItem>> kids({bool series = false}) async => series
      ? const []
      : const [
          MediaItem(
            id: 'movie:unsafe',
            type: 'movie',
            name: 'Adult title',
            certification: 'R',
            genres: ['Family'],
          ),
          MediaItem(
            id: 'movie:safe',
            type: 'movie',
            name: 'Family title',
            certification: 'G',
            genres: ['Family'],
          ),
        ];
}

void main() {
  testWidgets('Kids hero features only a child suitable title', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final api = NoorApi();
    final app = AppState(api, _KidsCatalog(api));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(
        theme: NovaTheme.dark,
        home: const Scaffold(body: KidsPage()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final feature = tester.widget<NovaBrowseFeature>(
      find.byType(NovaBrowseFeature),
    );
    expect(feature.item.id, 'movie:safe');
    expect(tester.takeException(), isNull);
  });
}
