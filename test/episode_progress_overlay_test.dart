import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/media/episode_views.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';

void main() {
  for (final (label, english, direction) in [
    ('English LTR', true, TextDirection.ltr),
    ('Arabic RTL', false, TextDirection.rtl),
  ]) {
    testWidgets('watched episode uses an accessible check only — $label',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final watchedLabel = NovaStrings.lookup(english, 'message98');

      await tester.pumpWidget(
        MaterialApp(
          theme: NovaTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 240,
                    child: EpisodeThumbnail(
                      url: '',
                      episodeNumber: 3,
                      watched: true,
                      progress: 1,
                      watchedSemanticLabel: watchedLabel,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final check = find.byIcon(LucideIcons.check);
      expect(check, findsOneWidget);
      expect(find.text(watchedLabel), findsNothing);
      final semantics = tester.widget<Semantics>(
        find.ancestor(of: check, matching: find.byType(Semantics)).first,
      );
      expect(semantics.properties.label, watchedLabel);
      final rect = tester.getRect(check);
      expect(
        direction == TextDirection.rtl
            ? rect.center.dx > 195
            : rect.center.dx < 195,
        isTrue,
        reason: 'direction=$direction rect=$rect',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('episode playback progress stays over its thumbnail',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: NovaTheme.dark,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: EpisodeThumbnail(
                url: '',
                episodeNumber: 3,
                watched: false,
                progress: .42,
                watchedSemanticLabel: 'Watched',
              ),
            ),
          ),
        ),
      ),
    );

    final progress =
        tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(progress.widthFactor, closeTo(.42, .001));
    expect(tester.takeException(), isNull);
  });
}
