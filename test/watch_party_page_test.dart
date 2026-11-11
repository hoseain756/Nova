import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
        {String locale = 'en',
        double scale = 1,
        bool dark = true,
        double keyboardInset = 0,
        bool safeArea = false,
        Widget page = const WatchPartyPage()}) =>
    ChangeNotifierProvider<WatchPartyController?>.value(
        value: controller,
        child: MaterialApp(
            theme: NovaTheme.build(dark ? Brightness.dark : Brightness.light,
                arabic: locale == 'ar'),
            locale: Locale(locale),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              NovaStrings.delegate,
              ...GlobalMaterialLocalizations.delegates
            ],
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    viewInsets: EdgeInsets.only(bottom: keyboardInset),
                    padding: safeArea
                        ? const EdgeInsets.only(top: 24, bottom: 24)
                        : EdgeInsets.zero,
                    viewPadding: safeArea
                        ? const EdgeInsets.only(top: 24, bottom: 24)
                        : EdgeInsets.zero),
                child: RepaintBoundary(key: _captureBoundary, child: child!)),
            home: page));
const _captureBoundary = ValueKey('party-capture-boundary');

Future<void> _showChat(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('party-chat-tab')));
  await tester.pumpAndSettle();
}

Future<void> _showDetails(WidgetTester tester) async {
  final list = find.byKey(const PageStorageKey('party-room-content'));
  await tester.scrollUntilVisible(
      find.byKey(const PageStorageKey('party-room-details')), 200,
      scrollable:
          find.descendant(of: list, matching: find.byType(Scrollable)).first);
  await tester.pumpAndSettle();
  for (var attempt = 0;
      attempt < 10 &&
          find
              .byKey(const PageStorageKey('party-room-details'))
              .hitTestable()
              .evaluate()
              .isEmpty;
      attempt++) {
    await tester.drag(list, const Offset(0, -120));
    await tester.pumpAndSettle();
  }
  expect(find.byKey(const PageStorageKey('party-room-details')).hitTestable(),
      findsOneWidget);
  await tester.tap(find.byKey(const PageStorageKey('party-room-details')));
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('NOVA_PARTY_CAPTURE')) return;
  await tester.runAsync(() async {
    final boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byKey(_captureBoundary));
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('build/nova-review/watch-party/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = <Future<void>>[];
    for (final family in ['Poppins', 'IBMPlexSansArabic']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(rootBundle.load('assets/fonts/$family-$weight.ttf'));
      }
      fonts.add(loader.load());
    }
    final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
    await Future.wait([...fonts, icons.load()]);
  });
  testWidgets(
      'incoming chat retains the composer and oversized Unicode stays editable',
      (tester) async {
    final g = FakeWatchPartyGateway();
    final c = WatchPartyController(g, deviceId: partyDeviceId);
    c.bindIdentity('a', partyProfileId);
    await tester.runAsync(() => c.join('ABCDEFGH'));
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    await _showChat(tester);
    final input = find.byKey(const ValueKey('party-message-input'));
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
    final send = find.byKey(const ValueKey('party-send-message'));
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('party-room-tab')));
    await tester.pumpAndSettle();
    await _showChat(tester);
    expect(tester.widget<TextField>(input).controller!.text, oversized);
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
  testWidgets('room joins the exact episode directly with one prominent action',
      (tester) async {
    const episode = WatchPartyMedia(
        id: 'tt1234',
        type: 'series',
        title: 'A shared story',
        videoId: 'tt1234:2:5',
        season: 2,
        episode: 5);
    final g = FakeWatchPartyGateway();
    (g.data['room'] as Map)['media'] = episode.toJson();
    final c = WatchPartyController(g, deviceId: partyDeviceId)
      ..bindIdentity('a', partyProfileId);
    await tester.runAsync(() => c.join('ABCDEFGH'));
    WatchPartySnapshot? launched;
    await tester.pumpWidget(app(c,
        page: WatchPartyPage(
            onJoinPlayback: (_, room) async => launched = room)));
    await tester.pumpAndSettle();
    expect(find.text('Season 2 · Episode 5'), findsOneWidget);
    expect(
        find.text('The host controls playback for everyone.'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.byKey(const ValueKey('party-join-playback')));
    await tester.pumpAndSettle();
    expect(launched?.media?.videoId, 'tt1234:2:5');
    expect(launched?.id, partyRoomId);
    await _capture(tester, 'room-en-phone');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('shared controls are explicit and host tools stay expandable',
      (tester) async {
    final g = FakeWatchPartyGateway()
      ..data = partyData(selfId: partyHostId, hostOnly: false);
    final c = WatchPartyController(g, deviceId: partyDeviceId)
      ..bindIdentity('a', partyProfileId);
    await tester.runAsync(() => c.join('ABCDEFGH'));
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    expect(find.text('Everyone can pause, play and seek.'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    await _showDetails(tester);
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('ending the room requires confirmation', (tester) async {
    final g = FakeWatchPartyGateway()..data = partyData(selfId: partyHostId);
    final c = WatchPartyController(g, deviceId: partyDeviceId)
      ..bindIdentity('a', partyProfileId);
    await tester.runAsync(() => c.join('ABCDEFGH'));
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('party-room-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End room'));
    await tester.pumpAndSettle();
    expect(g.requests.where((p) => p['p_action'] == 'end'), isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(c.snapshot, isNotNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  for (final locale in ['en', 'ar']) {
    testWidgets('$locale phone room and chat have reachable primary actions',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final g = FakeWatchPartyGateway()..data = partyData(hostOnly: false);
      (g.data['room'] as Map)['media'] = const WatchPartyMedia(
              id: 'tt1234',
              type: 'series',
              title: 'A shared story',
              videoId: 'tt1234:2:5',
              season: 2,
              episode: 5)
          .toJson();
      final c = WatchPartyController(g, deviceId: partyDeviceId)
        ..bindIdentity('a', partyProfileId);
      await tester.runAsync(() => c.join('ABCDEFGH'));
      g.status!(true);
      c.messages = [
        WatchPartyMessage(
            id: 1,
            memberId: partyHostId,
            name: locale == 'ar' ? 'سارة' : 'Sarah',
            clientId: partyDeviceId,
            body: locale == 'ar'
                ? 'الجميع جاهز؟ لنبدأ الحلقة معًا.'
                : 'Everyone ready? Let’s start this episode together.'),
        WatchPartyMessage(
            id: 2,
            memberId: partyGuestId,
            name: locale == 'ar' ? 'عمر' : 'Omar',
            clientId: partyProfileId,
            body: locale == 'ar'
                ? 'جاهز! أحضرت الفشار'
                : 'Ready! I brought popcorn')
      ];
      await tester.pumpWidget(
          app(c, locale: locale, dark: locale == 'ar', safeArea: true));
      await tester.pumpAndSettle();
      final join = find.byKey(const ValueKey('party-join-playback'));
      expect(tester.getRect(join).bottom, lessThan(820));
      expect(join.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'room-$locale-390x844');
      await _showChat(tester);
      final input = find.byKey(const ValueKey('party-message-input'));
      await tester.enterText(
          input, locale == 'ar' ? 'لنشاهد معًا' : 'Let’s watch together');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('party-send-message')).hitTestable(),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'chat-$locale-390x844');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
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
        await _capture(tester, 'room-$locale-${size.width.toInt()}-top-large');
        await _showDetails(tester);
        await tester.drag(
            find.byKey(const PageStorageKey('party-room-content')),
            const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _capture(tester, 'room-$locale-${size.width.toInt()}-large');
        await _showChat(tester);
        final input = find.byKey(const ValueKey('party-message-input'));
        expect(input, findsOneWidget);
        expect(tester.getRect(input).bottom, lessThanOrEqualTo(size.height));
        await tester.enterText(
            input, locale == 'ar' ? 'رسالة جديدة' : 'A new message');
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<IconButton>(
                    find.byKey(const ValueKey('party-send-message')))
                .onPressed,
            isNotNull);
        expect(tester.takeException(), isNull);
        await _capture(tester, 'chat-$locale-${size.width.toInt()}-large');
        await tester.pumpWidget(app(c,
            locale: locale,
            scale: 2,
            dark: locale == 'ar',
            keyboardInset: size.height < 500 ? 100 : 250));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(input, findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      });
    }
  }
}
