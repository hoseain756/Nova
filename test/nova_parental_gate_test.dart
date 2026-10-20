import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:nova_mobile/shared/widgets/nova_parental_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _pinKey = 'nova.parent-pin.v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> secure;
  late bool storageFails;
  late int writes;
  Completer<void>? pendingWrite;

  setUp(() {
    secure = {};
    storageFails = false;
    writes = 0;
    pendingWrite = null;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (storageFails) throw PlatformException(code: 'storage_unavailable');
      final args = call.arguments as Map;
      final key = args['key'] as String;
      if (call.method == 'read') return secure[key];
      if (call.method == 'write') {
        writes++;
        await pendingWrite?.future;
        secure[key] = args['value'] as String;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  void seedPin() {
    const salt = 'test-salt';
    secure[_pinKey] = jsonEncode({
      'salt': salt,
      'hash': sha256.convert(utf8.encode('$salt:1234')).toString(),
    });
  }

  Future<void> open(WidgetTester tester,
      {bool english = true,
      Brightness brightness = Brightness.dark,
      double scale = 1,
      double keyboard = 0,
      Size size = const Size(390, 800),
      Future<bool> Function(BuildContext)? action,
      ValueChanged<bool>? onResult}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      locale: Locale(english ? 'en' : 'ar'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        NovaStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: NovaTheme.build(brightness, arabic: !english),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(body: Builder(builder: (context) {
        return TextButton(
          onPressed: () async {
            final result = await (action ?? NovaParentalGate.ensureConfigured)(
              context,
            );
            onResult?.call(result);
          },
          child: const Text('open'),
        );
      })),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Arabic and Persian PIN digits save and unlock the same PIN',
      (tester) async {
    bool? result;
    await open(tester, english: false, onResult: (value) => result = value);
    await tester.enterText(find.byType(TextField).first, '١٢٣٤');
    await tester.enterText(find.byType(TextField).last, '۱۲۳۴');
    await tester.tap(find.text(NovaStrings.lookup(false, 'save')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(secure[_pinKey], isNot(contains('1234')));
    result = null;
    await open(tester,
        action: NovaParentalGate.verify, onResult: (value) => result = value);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('five wrong PINs remain locked after reopening the dialog',
      (tester) async {
    seedPin();
    bool? result;
    await open(tester,
        action: NovaParentalGate.verify, onResult: (value) => result = value);
    for (var attempt = 0; attempt < 5; attempt++) {
      await tester.enterText(find.byType(TextField), '9999');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
    }
    expect(find.text(NovaStrings.lookup(true, 'pinLocked')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    result = null;
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text(NovaStrings.lookup(true, 'pinLocked')), findsOneWidget);
  });

  testWidgets(
      'missing credentials and storage errors fail closed with feedback',
      (tester) async {
    bool? result;
    await open(tester,
        action: NovaParentalGate.verify, onResult: (value) => result = value);
    expect(result, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    storageFails = true;
    result = null;
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(result, isFalse);
    expect(find.text(NovaStrings.lookup(true, 'errorBody')), findsOneWidget);
  });

  testWidgets('keyboard submit cannot race a pending secure-storage write',
      (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, '1234');
    await tester.enterText(find.byType(TextField).last, '1234');
    pendingWrite = Completer<void>();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    field.onSubmitted!('1234');
    await tester.pump();
    field.onSubmitted!('1234');
    await tester.pump();
    expect(writes, 1);
    pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final english in [true, false]) {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(320, 568), const Size(640, 360)]) {
        testWidgets(
            'parent gate fits keyboard and 200% $english $brightness $size',
            (tester) async {
          await open(tester,
              english: english,
              brightness: brightness,
              scale: 2,
              keyboard: size.height < 400 ? 120 : 180,
              size: size);
          expect(tester.takeException(), isNull);
          final cancel = find.text(NovaStrings.lookup(english, 'cancel'));
          await tester.ensureVisible(cancel);
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
        });
      }
    }
  }
}
