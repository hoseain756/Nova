import 'package:nova_mobile/shared/widgets/media_hero.dart';
// Widget smoke test — pumps the rebuilt detail presentation widgets
// (hero + the Task 118 sliver episodes composition) on phone + tablet sizes
// to catch layout exceptions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/features/media/detail_hero.dart';
import 'package:nova_mobile/features/media/episode_views.dart';

void main() {
  final item = MediaItem(
    id: 'tt1',
    type: 'series',
    name: 'Smoke Series',
    background: '',
    description: 'A smoke-test description for layout verification purposes.',
    releaseInfo: '2024',
    rating: '8.5',
    runtime: '58 min',
    certification: '16+',
    genres: const ['Drama', 'Crime'],
    cast: const ['A Actor', 'B Actor', 'C Actor', 'D Actor', 'E Actor'],
    director: const ['Some Director'],
    videos: [
      for (var e = 1; e <= 8; e++)
        {
          'id': 'tt1:1:$e',
          'season': 1,
          'episode': e,
          'name': 'Episode $e',
          'overview': 'Story $e',
          'released': '2024-01-0$e',
          'duration': '${45 + e} min',
        },
      for (var e = 1; e <= 3; e++)
        {
          'id': 'tt1:2:$e',
          'season': 2,
          'episode': e,
          'name': 'S2 Episode $e',
        },
    ],
  );

  Widget harness(double width, double height) {
    final isWide = width >= 700;
    // Fresh controller per pump — mirrors how the page creates it lazily.
    final controller = EpisodesController(
      item: item,
      entries: const [],
      savedView: 'auto',
    );
    return MaterialApp(
      theme: ThemeData.dark(),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: MediaHero(
                      item: item,
                      detail: true,
                      actions: DetailActionRow(
                        english: false,
                        isWide: isWide,
                        inList: false,
                        showTrackAnime: true,
                        primaryLabel: 'مشاهدة',
                        primaryIsResume: false,
                        loading: false,
                        onPrimaryPressed: () {},
                        onToggleWatchlist: () {},
                        onOpenStreams: () {},
                        onTrackAnime: () {},
                        onShare: () {},
                        onAddToList: () {},
                      ))),
              ...buildEpisodeSlivers(
                controller: controller,
                english: false,
                isWide: isWide,
                contentWidth: width - (isWide ? 68.0 : 40.0),
                blurUnwatched: true,
                ratingsEnabled: true,
                onViewChange: (_) {},
                onPlay: (_) {},
                onLongPress: (_) {},
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      DetailCastCrew(item: item, english: false),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The hero shimmer may still be alive during the first frames — pump a
  // fixed frame budget instead of pumpAndSettle.
  Future<void> settleFrames(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  void setViewport(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final (label, size) in [
    ('phone', const Size(400, 800)),
    ('tablet', const Size(900, 1200)),
  ]) {
    testWidgets('layout smoke — $label', (tester) async {
      setViewport(tester, size);
      await tester.pumpWidget(harness(size.width, size.height));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('الحلقات'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overlay menus smoke — $label', (tester) async {
      setViewport(tester, size);
      await tester.pumpWidget(harness(size.width, size.height));
      await settleFrames(tester);

      // Season dropdown → glass menu opens with season options. Scoped
      // finder: the season pill carries the ValueKey('season-<id>') key
      // (the DetailActionRow chevron is a different widget), scrolled into
      // view before the tap.
      final seasonTrigger = find
          .descendant(
            of: find.byKey(const ValueKey('season-tt1')),
            matching: find.byIcon(LucideIcons.chevronDown),
          )
          .first;
      await tester.ensureVisible(seasonTrigger);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(seasonTrigger);
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('الموسم 2'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Pick season 2 → menu closes, label updates.
      await tester.ensureVisible(find.text('الموسم 2').last);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('الموسم 2').last);
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);

      // Return to the title header to open its action menu.
      final actionRow = find.byType(DetailActionRow);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump(const Duration(milliseconds: 100));
      final menuTrigger = find
          .descendant(
            of: actionRow,
            matching: find.byIcon(LucideIcons.ellipsis),
          )
          .first;
      await tester.ensureVisible(menuTrigger);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(menuTrigger);
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('مصادر التشغيل'), findsOneWidget);
      expect(find.byTooltip('مشاركة'), findsOneWidget);
      expect(find.text('تتبّع الأنمي'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Outside tap closes.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('مصادر التشغيل'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
