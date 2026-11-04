import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/shared_collections/shared_collections_service.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/core/torrent/torrent_models.dart';
import 'package:nova_mobile/features/shared_collections/shared_collection_detail_page.dart';
import 'package:nova_mobile/features/torrent/magnet_opener.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';

Widget _host(Widget child, {required bool english}) => MaterialApp(
      theme: NovaTheme.build(Brightness.light, arabic: !english),
      locale: Locale(english ? 'en' : 'ar'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        NovaStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(body: child),
    );

void main() {
  for (final english in [true, false]) {
    testWidgets(
        'collection art keeps its portrait size and edit grant $english',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final item = CollectionItem.fromJson({
        'id': 'item',
        'collection_id': 'collection',
        'title': 'A long collection title / حكاية طويلة',
        'media_type': 'movie',
        'media_id': null,
        'added_by': 'owner',
        'added_by_name': 'Member',
        'created_at': '2026-11-04T00:00:00Z',
        'updated_at': '2026-11-04T00:00:00Z',
        'version': 1,
      });
      var edits = 0;
      await tester.pumpWidget(_host(
        ListView(padding: const EdgeInsets.all(16), children: [
          SharedCollectionItemRow(
            item: item,
            addedBy: 'Member',
            canEdit: true,
            canDelete: false,
            busy: false,
            onEdit: () => edits++,
            onDelete: () => fail('Delete is not granted'),
          ),
        ]),
        english: english,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final artwork = find.byWidgetPredicate((widget) =>
          widget is SizedBox && widget.width == 64 && widget.height == 88);
      expect(tester.getSize(artwork), const Size(64, 88));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      final strings = NovaStrings(Locale(english ? 'en' : 'ar'));
      expect(find.text(strings.text('delete')), findsNothing);
      await tester.tap(find.text(strings.text('edit')));
      await tester.pumpAndSettle();
      expect(edits, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('large torrent packs build visible rows and keep native indices',
      (tester) async {
    tester.view.physicalSize = const Size(320, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selected;
    final files = [
      for (var i = 0; i < 1000; i++)
        TorrentFileInfo(
            index: 100 + i * 2, name: 'Episode $i / الحلقة', size: 1024),
    ];
    await tester.pumpWidget(_host(
      CustomScrollView(slivers: [
        MagnetFileChoicesSliver(
          files: files,
          selectedIndex: 100,
          onSelected: (index) => selected = index,
          sizeLabel: (_) => '1 KB',
        ),
      ]),
      english: false,
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('magnet-file-2098')), findsNothing);
    expect(find.byType(InkWell).evaluate().length, lessThan(20));
    await tester.tap(find.byKey(const ValueKey('magnet-file-100')));
    expect(selected, 100);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();
    expect(find.byType(InkWell).evaluate().length, lessThan(20));
    expect(tester.takeException(), isNull);
  });
}
