import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/media/detail_hero.dart';

void main() {
  for (final english in [true, false]) {
    for (final dark in [true, false]) {
      for (final width in [320.0, 900.0]) {
        testWidgets('trailer $english dark=$dark width=$width', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1200);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          var plays = 0;
          await tester.pumpWidget(MaterialApp(
            theme: dark ? NovaTheme.dark : NovaTheme.light,
            home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 1200), textScaler: TextScaler.linear(2)),
              child: Directionality(
                textDirection: english ? TextDirection.ltr : TextDirection.rtl,
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: DetailTrailer(
                      item: const MediaItem(
                        id: 'test',
                        type: 'movie',
                        name:
                            'A long film title / عنوان فيلم طويل لاختبار التصميم',
                      ),
                      english: english,
                      onPlay: () => plays++,
                    ),
                  ),
                ),
              ),
            ),
          ));
          expect(tester.takeException(), isNull);
          final preview = find.byType(AspectRatio);
          expect(tester.getSize(preview).width, lessThanOrEqualTo(560));
          expect(tester.getSize(preview).aspectRatio, closeTo(16 / 9, .001));
          // The image and caption both open the same trailer, exactly once.
          await tester.tapAt(tester.getCenter(preview));
          expect(plays, 1);
          await tester.tap(find.byIcon(LucideIcons.externalLink));
          expect(plays, 2);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('facts hide a blank trailer URL', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DetailFactsTable(
            item: const MediaItem(
                id: 'test', type: 'movie', name: 'Film', trailerUrl: '  '),
            english: true,
          ),
        ),
      ),
    ));
    expect(find.byType(DetailTrailer), findsNothing);
  });
}
