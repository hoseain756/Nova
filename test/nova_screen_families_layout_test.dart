import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/account/account_pages.dart';
import 'package:nova_mobile/features/shell/nova_browse_widgets.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';

Widget _host({
  required Widget child,
  required Size size,
  required Brightness brightness,
  required bool arabic,
  double keyboard = 0,
}) =>
    MaterialApp(
      theme: NovaTheme.build(brightness, arabic: arabic),
      locale: Locale(arabic ? 'ar' : 'en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        NovaStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
      home: Scaffold(resizeToAvoidBottomInset: false, body: child),
    );

void main() {
  for (final width in [320.0, 1000.0]) {
    for (final arabic in [false, true]) {
      for (final brightness in Brightness.values) {
        testWidgets('browse spread reflows $width $arabic $brightness at 200%',
            (tester) async {
          final size = Size(width, 700);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var opened = 0;
          const title =
              'A very long film title حكاية طويلة 2026 ABCDEFGHIJKLMNOPQRSTUVWXYZ';
          await tester.pumpWidget(_host(
            size: size,
            brightness: brightness,
            arabic: arabic,
            child: SingleChildScrollView(
              child: NovaBrowseFeature(
                item:
                    const MediaItem(id: 'fixture', type: 'movie', name: title),
                label: 'Featured / مختارات',
                actionLabel: 'Open title / افتح العنوان',
                onOpen: () => opened++,
              ),
            ),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull);
          final image = tester.getRect(find.byType(AspectRatio));
          final copy = tester.getRect(find.text(title));
          expect(image.overlaps(copy), isFalse);
          await tester.ensureVisible(find.text('Open title / افتح العنوان'));
          await tester.tap(find.text('Open title / افتح العنوان'));
          expect(opened, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final arabic in [false, true]) {
    testWidgets('sheet keeps its action reachable above a keyboard $arabic',
        (tester) async {
      const size = Size(320, 300);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saved = 0;
      await tester.pumpWidget(_host(
        size: size,
        brightness: Brightness.light,
        arabic: arabic,
        keyboard: 120,
        child: NovaBrowseSheet(slivers: [
          SliverToBoxAdapter(
            child: NovaBrowseSheetHeading(
              title: 'A long collection title / اسم مجموعة طويل',
              subtitle: 'A complete explanation that wraps at large text size.',
              closeLabel: 'Close',
              onClose: () {},
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const TextField(decoration: InputDecoration(labelText: 'Name')),
                const SizedBox(height: 24),
                const Text('A full description / وصف كامل يمكن قراءته بالكامل'),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: () => saved++, child: const Text('Save')),
              ]),
            ),
          ),
        ]),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CustomScrollView)).height,
          lessThanOrEqualTo(180));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pump();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      expect(saved, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('portrait profile choices scroll and keep selection callbacks',
      (tester) async {
    const size = Size(320, 600);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(_host(
      size: size,
      brightness: Brightness.dark,
      arabic: true,
      child: ProfilePickerPage(
        profiles: [
          for (var i = 0; i < 5; i++)
            ProfileSummary(id: '$i', name: 'A long profile / ملف شخصي $i'),
        ],
        onSelect: (id, _) async => selected = id,
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('A long profile / ملف شخصي 4'));
    await tester.tap(find.text('A long profile / ملف شخصي 4'));
    await tester.pump();
    expect(selected, '4');
    expect(tester.takeException(), isNull);
  });
}
