import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/core/data/catalog_repository.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/state/app_state.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/shared/widgets/poster_card.dart';
import 'package:provider/provider.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
        'poster rating badge keeps artwork-overlay contrast in $brightness mode',
        (tester) async {
      final api = NoorApi();
      final app = AppState(api, CatalogRepository(api));
      addTearDown(app.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: app,
          child: MaterialApp(
            theme: brightness == Brightness.light
                ? NovaTheme.light
                : NovaTheme.dark,
            home: const Scaffold(
              body: PosterCard(
                item: MediaItem(
                  id: 'rated',
                  type: 'movie',
                  name: 'Rated movie',
                  rating: '8.7',
                ),
                onTap: _noop,
              ),
            ),
          ),
        ),
      );

      final ratingText = tester.widget<Text>(find.text('8.7'));
      expect(ratingText.style?.color, NovaColors.white);

      final star = tester.widget<Icon>(find.byIcon(LucideIcons.star));
      expect(star.color, NovaColors.rating);

      final badge = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.text('8.7'),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = badge.decoration as BoxDecoration;
      expect(decoration.color, NovaColors.ink.withValues(alpha: .72));
      expect(tester.takeException(), isNull);
    });
  }
}

void _noop() {}
