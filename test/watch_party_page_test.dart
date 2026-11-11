import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nova_mobile/core/watch_party/watch_party_controller.dart';
import 'package:nova_mobile/core/watch_party/watch_party_models.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/watch_party/watch_party_page.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'support/watch_party_fixture.dart';

Widget app(WatchPartyController? controller,
        {String locale = 'en', double scale = 1, bool dark = true}) =>
    ChangeNotifierProvider<WatchPartyController?>.value(
        value: controller,
        child: MaterialApp(
            theme: dark ? NovaTheme.dark : NovaTheme.light,
            locale: Locale(locale),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              NovaStrings.delegate,
              ...GlobalMaterialLocalizations.delegates
            ],
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const WatchPartyPage()));
void main() {
  testWidgets(
      'incoming chat retains the composer and oversized Unicode stays editable',
      (tester) async {
    final g = FakeWatchPartyGateway();
    final c = WatchPartyController(g, deviceId: partyDeviceId);
    c.bindIdentity('a', partyProfileId);
    await tester.runAsync(() => c.join('ABCDEFGH'));
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('party-message-input'));
    await tester.scrollUntilVisible(input, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(input);
    await tester.enterText(input, 'Draft');
    final before = tester.element(input);
    g.event!('chat', {
      'id': 1,
      'member_id': partyHostId,
      'display_name': 'Host',
      'client_id': partyProfileId,
      'body': 'Hello'
    });
    await tester.pumpAndSettle();
    expect(identical(tester.element(input), before), isTrue);
    expect(tester.widget<TextField>(input).controller!.text, 'Draft');
    final oversized = List.filled(100, '👨‍👩‍👧‍👦').join();
    await tester.enterText(input, oversized);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, oversized);
    expect(
        find.text('Keep the message within 500 characters.'), findsOneWidget);
    final send = find.widgetWithText(FilledButton, 'Send');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
      'guest sees the account requirement without native or backend work',
      (tester) async {
    await tester.pumpWidget(app(null, locale: 'ar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('حساب NOVA كامل'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
  testWidgets('join input enters the room through the service', (tester) async {
    final g = FakeWatchPartyGateway();
    final c = WatchPartyController(g, deviceId: partyDeviceId);
    c.bindIdentity('a', partyProfileId);
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ABCD EFGH');
    await tester
        .ensureVisible(find.widgetWithText(OutlinedButton, 'Join a room'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Join a room'));
    await tester.pumpAndSettle();
    expect(find.text('ABCD EFGH'), findsOneWidget);
    expect(g.requests.where((p) => p['p_action'] == 'join').single['p_code'],
        'ABCDEFGH');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  for (final locale in ['en', 'ar']) {
    for (final size in [const Size(320, 640), const Size(900, 360)]) {
      testWidgets(
          '$locale room fits $size at large text with chat and host actions',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final g = FakeWatchPartyGateway()
          ..data = partyData(selfId: partyHostId);
        ((g.data['members'] as List)[1] as Map)['name'] =
            'A long viewer name that must wrap';
        final c = WatchPartyController(g, deviceId: partyDeviceId);
        c.bindIdentity('a', partyProfileId);
        await tester.runAsync(() => c.join('ABCDEFGH'));
        c.messages = const [
          WatchPartyMessage(
              memberId: partyHostId,
              name: 'Host',
              clientId: partyDeviceId,
              body:
                  'رسالة طويلة للمشاهدة الجماعية مع الأصدقاء. A long message for everyone in the room.',
              failed: true)
        ];
        await tester
            .pumpWidget(app(c, locale: locale, scale: 2, dark: locale == 'ar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 5; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      });
    }
  }
}
