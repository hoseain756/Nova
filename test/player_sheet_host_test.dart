import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/widgets/player_side_panel.dart';
import 'package:nova_mobile/features/player/widgets/player_sheets.dart';
import 'package:nova_mobile/shared/widgets/nova_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Landscape phone surface (SM-A217F class): 888×412 logical, dpr 1.0 —
  // short height must trigger the compact geometry and still fit content.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(888, 412);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(800, 600);
    view.devicePixelRatio = 1.0;
  });

  Widget host({
    VoidCallback? onRefresh,
    bool refreshing = false,
    VoidCallback? onClose,
    EdgeInsets padding = EdgeInsets.zero,
    TextDirection direction = TextDirection.ltr,
  }) {
    return MaterialApp(
      home: Builder(
          builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: padding),
              child: Directionality(
                  textDirection: direction,
                  child: Scaffold(
                      body: Stack(children: [
                    PlayerPanelOverlay(
                      onClose: onClose ?? () {},
                      child: PlayerSidePanel(
                        title: 'Panel',
                        english: true,
                        onClose: onClose ?? () {},
                        onRefresh: onRefresh,
                        refreshing: refreshing,
                        child: ListView.builder(
                          itemCount: 60,
                          itemBuilder: (context, index) => ListTile(
                            dense: true,
                            title: Text('Row $index'),
                          ),
                        ),
                      ),
                    ),
                  ]))))),
    );
  }

  Finder headerButton(String label) => find.bySemanticsLabel(label);

  testWidgets('player dialog fits within a compact portrait viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpWidget(host());
    final box = tester.getRect(find.byType(PlayerSidePanel));
    expect(box.width, 296);
    expect(box.center, const Offset(160, 320));
  });

  testWidgets('landscape dialog is centered and bounded', (tester) async {
    await tester.pumpWidget(host());
    final box = tester.getRect(find.byType(PlayerSidePanel));
    expect(box.width, 520);
    expect(box.height, closeTo(412 * .88, .01));
    expect(box.center.dx, closeTo(444, .01));
    expect(box.center.dy, closeTo(206, .01));
  });

  testWidgets(
      'episode and subtitle dialogs use the same bounds and dismiss outside',
      (tester) async {
    const content = ValueKey('dialog content');
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showPlayerSheet<void>(context,
                          builder: (_) => const SizedBox.expand(key: content)),
                      child: const Text('Open')),
                ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byKey(content));
    expect(box.width, 520);
    expect(box.height, closeTo(412 * .88, .01));
    expect(box.center.dy, closeTo(206, .01));
    await tester.tapAt(const Offset(10, 206));
    await tester.pumpAndSettle();
    expect(find.byKey(content), findsNothing);
  });

  testWidgets('iOS player tools use a glass surface within safe bounds',
      (tester) async {
    const content = ValueKey('ios-tool-content');
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showPlayerSheet<void>(context,
                builder: (_) => const SizedBox.expand(key: content)),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(NovaIosGlassSurface), findsOneWidget);
    expect(tester.getSize(find.byKey(content)).width, 520);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact geometry on a short landscape screen', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // pumpAndSettle above would have thrown on a RenderFlex overflow).
    final title = tester.widget<Text>(find.text('Panel'));
    expect(
      title.style,
      Theme.of(tester.element(find.text('Panel'))).textTheme.titleLarge,
    );
  });

  testWidgets('refresh button sits in the header and fires onRefresh',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var refreshed = 0;
    await tester.pumpWidget(host(onRefresh: () => refreshed++));
    await tester.pumpAndSettle();

    final refreshButton = headerButton('Refresh');
    expect(refreshButton, findsOneWidget);
    // Header zone: above the scrollable list body.
    final center = tester.getCenter(refreshButton);
    expect(center.dy, lessThan(tester.getTopLeft(find.byType(ListView)).dy));
    await tester.tap(refreshButton);
    await tester.pumpAndSettle();
    expect(refreshed, 1);
    // The panel stays open — refreshing never dismisses it.
    expect(find.byType(PlayerSidePanel), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('refreshing state replaces the icon with a spinner',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(onRefresh: () {}, refreshing: true));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('close button fires onClose', (tester) async {
    final semantics = tester.ensureSemantics();
    var closed = 0;
    await tester.pumpWidget(host(onClose: () => closed++));
    await tester.pumpAndSettle();

    final closeButton = headerButton('Close');
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();
    expect(closed, 1);
    semantics.dispose();
  });

  testWidgets('tool dialog stays open while scrolling the list',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Scroll the list DOWN (drag up) until a far row is visible — content
    // moves, panel stays (the panel never dismisses on scroll: it is an
    // in-page overlay, not a drag-to-dismiss route).
    await tester.dragUntilVisible(
      find.text('Row 30'),
      find.byType(ListView),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlayerSidePanel), findsOneWidget);
    expect(find.text('Row 30'), findsOneWidget);
  });

  for (final direction in TextDirection.values) {
    testWidgets('dialog stays within asymmetric safe insets in $direction',
        (tester) async {
      await tester.pumpWidget(host(
          direction: direction,
          padding: const EdgeInsets.only(left: 40, right: 16)));
      final box = tester.getRect(find.byType(PlayerSidePanel));
      expect(box.center.dx, (40 + 888 - 16) / 2);
      expect(box.left, greaterThan(40));
      expect(box.right, lessThan(888 - 16));
      final row = tester.getRect(find.text('Row 0'));
      expect(box.contains(row.center), isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
