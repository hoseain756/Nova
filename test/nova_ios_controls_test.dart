import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/shared/widgets/nova_ios_controls.dart';

void main() {
  const channel = MethodChannel('nova/ios_controls');

  testWidgets(
      'native alert maps actions and cancellation without changing state',
      (tester) async {
    NovaIosControls.debugAvailableOverride = true;
    addTearDown(() => NovaIosControls.debugAvailableOverride = null);
    final calls = <MethodCall>[];
    var response = 1;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call);
        return response;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    late BuildContext anchor;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          anchor = context;
          return const Scaffold(body: SizedBox());
        }),
      ),
    ));
    expect(
      await NovaIosControls.confirm(
        anchor,
        title: 'حذف',
        message: 'حذف العنصر؟',
        confirmLabel: 'احذف',
        cancelLabel: 'إلغاء',
        destructive: true,
      ),
      isTrue,
    );
    expect(calls.single.method, 'presentAlert');
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(args['rtl'], true);
    expect(args['dark'], true);
    expect((args['actions'] as List)[1],
        {'label': 'احذف', 'style': 'destructive'});

    response = 0;
    expect(
      await NovaIosControls.confirm(
        anchor,
        title: 'حذف',
        message: '',
        confirmLabel: 'احذف',
        cancelLabel: 'إلغاء',
      ),
      isFalse,
    );
  });

  testWidgets('native choice returns only a valid selected option',
      (tester) async {
    NovaIosControls.debugAvailableOverride = true;
    addTearDown(() => NovaIosControls.debugAvailableOverride = null);
    MethodCall? captured;
    var response = 1;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        captured = call;
        return response;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    late BuildContext anchor;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      anchor = context;
      return const Scaffold(body: SizedBox());
    })));
    expect(
      await NovaIosControls.choose(
        anchor,
        title: 'Quality',
        labels: const ['Auto', 'High'],
        cancelLabel: 'Cancel',
        sourceRect: const Rect.fromLTWH(12, 24, 48, 48),
      ),
      1,
    );
    expect(captured?.method, 'presentChoices');
    expect(
        (captured?.arguments as Map)['sourceRect'], [12.0, 24.0, 48.0, 48.0]);
    response = 2; // The final action is Cancel.
    expect(
      await NovaIosControls.choose(
        anchor,
        title: 'Quality',
        labels: const ['Auto', 'High'],
        cancelLabel: 'Cancel',
      ),
      isNull,
    );
  });

  testWidgets('native dropdown and popup send the selected Flutter value',
      (tester) async {
    NovaIosControls.debugAvailableOverride = true;
    addTearDown(() => NovaIosControls.debugAvailableOverride = null);
    final methods = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        methods.add(call.method);
        return call.method == 'presentChoices' ? 1 : true;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          NovaSelectionButton<String>(
            value: 'auto',
            title: 'Quality',
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Auto')),
              DropdownMenuItem(value: 'high', child: Text('High')),
            ],
            onChanged: (value) => selected = value,
          ),
          NovaDropdownFormField<String>(
            key: const ValueKey('native-form-choice'),
            initialValue: 'auto',
            decoration: const InputDecoration(labelText: 'Quality setting'),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Auto')),
              DropdownMenuItem(value: 'high', child: Text('High')),
            ],
            onChanged: (value) => selected = value,
          ),
          NovaPopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            onSelected: (value) => selected = value,
          ),
        ]),
      ),
    ));
    await tester.tap(find.text('Auto').first);
    await tester.pump();
    expect(selected, 'high');
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('native-form-choice')),
        matching: find.text('Auto')));
    await tester.pump();
    expect(selected, 'high');
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('native-form-choice')),
            matching: find.text('High')),
        findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    expect(selected, 'delete');
    expect(methods, ['presentChoices', 'presentChoices', 'presentChoices']);
  });
}
