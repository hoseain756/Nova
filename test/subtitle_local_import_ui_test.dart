import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nova_mobile/features/player/widgets/player_side_panel.dart';

void main() {
  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets('local subtitle import stays reachable in $direction',
        (tester) async {
      var imports = 0;
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
                onImportLocal: () => imports++,
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(direction == TextDirection.ltr
          ? 'Import subtitle file'
          : 'استيراد ملف ترجمة'));
      expect(imports, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('selected device subtitle appears as a selectable row',
      (tester) async {
    final track =
        SubtitleTrack.uri('file:///tmp/movie.ass', title: 'movie.ass');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 460,
          child: SubtitleTracksPanelBody(
            english: true,
            embedded: const [],
            selected: track,
            onPick: (_) {},
            external: const [],
            loadingExternal: false,
          ),
        ),
      ),
    ));
    expect(find.text('From device'), findsOneWidget);
    expect(find.text('movie.ass'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
