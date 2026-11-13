import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/shared/widgets/nova_dialog.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('dialog uses ${platform.name} route and keeps its result',
        (tester) async {
      bool? selected;
      ModalRoute<dynamic>? presentedRoute;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: Builder(builder: (context) {
            return TextButton(
              onPressed: () async {
                selected = await showNovaDialog<bool>(
                  context: context,
                  builder: (dialog) {
                    presentedRoute = ModalRoute.of(dialog);
                    return NovaGlassDialog(
                      title: const Text('Confirm'),
                      content: const Text('Continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('Continue'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text('Open'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(NovaGlassDialog), findsOneWidget);
      expect(presentedRoute is CupertinoDialogRoute,
          platform == TargetPlatform.iOS);
      await tester.tap(find.text('Continue').last);
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('required iOS dialog ignores a barrier tap', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Scaffold(body: Builder(builder: (context) {
        return TextButton(
          onPressed: () => showNovaDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialog) => NovaGlassDialog(
              title: const Text('Required'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          child: const Text('Open'),
        );
      })),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  });

  for (final size in [const Size(320, 568), const Size(1024, 768)]) {
    testWidgets('iOS form dialog fits $size with large Arabic text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: MediaQuery(
          data: MediaQueryData(
              size: size, textScaler: const TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: Builder(builder: (context) {
              return TextButton(
                onPressed: () => showNovaDialog<void>(
                  context: context,
                  builder: (dialog) => NovaGlassDialog(
                    title: const Text('إعدادات الاتصال'),
                    scrollable: true,
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                            decoration: InputDecoration(labelText: 'الرابط')),
                        CheckboxListTile(
                          value: true,
                          onChanged: null,
                          title: Text('تفعيل الاتصال بالخادم'),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
                ),
                child: const Text('فتح'),
              );
            })),
          ),
        ),
      ));
      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();
      expect(find.byType(NovaGlassDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
