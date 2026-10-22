import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nova_mobile/features/player/engine/playback_engine.dart';
import 'package:nova_mobile/features/player/widgets/player_side_panel.dart';

void main() {
  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets(
        'subtitle fetch error is distinct from an empty result in $direction',
        (tester) async {
      var retries = 0;
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: SizedBox(
              width: 320,
              height: 400,
              child: SubtitleTracksPanelBody(
                english: direction == TextDirection.ltr,
                embedded: const [],
                selected: SubtitleTrack.no(),
                onPick: (_) {},
                external: const [],
                loadingExternal: false,
                loadFailed: true,
                onRefresh: () => retries++,
              ),
            ),
          ),
        ),
      ));
      expect(
          find.textContaining(direction == TextDirection.ltr
              ? 'Could not load subtitles'
              : 'تعذر تحميل الترجمات'),
          findsOneWidget);
      await tester.tap(find.byType(TextButton));
      expect(retries, 1);
    });

    testWidgets(
        'subtitle search shares a row with style and refresh in $direction',
        (tester) async {
      var styles = 0;
      var refreshes = 0;
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: SizedBox(
              width: 320,
              height: 400,
              child: SubtitleTracksPanelBody(
                english: direction == TextDirection.ltr,
                embedded: const [],
                selected: SubtitleTrack.no(),
                onPick: (_) {},
                external: const [],
                loadingExternal: false,
                onOpenSettings: () => styles++,
                onRefresh: () => refreshes++,
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      final search = tester.getCenter(find.byType(TextField).first);
      final style = tester.getCenter(find.byIcon(LucideIcons.settings2));
      final refresh = tester.getCenter(find.byIcon(LucideIcons.refreshCw));
      expect((search.dy - style.dy).abs(), lessThan(1));
      expect((search.dy - refresh.dy).abs(), lessThan(1));
      await tester.tap(find.byIcon(LucideIcons.settings2));
      await tester.tap(find.byIcon(LucideIcons.refreshCw));
      expect((styles, refreshes), (1, 1));
    });

    testWidgets('source search shares a row with refresh in $direction',
        (tester) async {
      var refreshes = 0;
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: SizedBox(
              width: 320,
              height: 400,
              child: StreamsPanelBody(
                english: direction == TextDirection.ltr,
                streams: const [],
                currentStream: null,
                onPick: (_) {},
                onRefresh: () => refreshes++,
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      final search = tester.getCenter(find.byType(TextField).first);
      final refresh = tester.getCenter(find.byIcon(LucideIcons.refreshCw));
      expect((search.dy - refresh.dy).abs(), lessThan(1));
      await tester.tap(find.byIcon(LucideIcons.refreshCw));
      expect(refreshes, 1);
    });
  }
}
