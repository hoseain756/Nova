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
import 'package:nova_mobile/core/watch_party/watch_party_invite.dart';
import 'package:nova_mobile/core/watch_party/watch_party_relay_settings.dart';
import 'package:nova_mobile/core/watch_party/cloudflare_relay_deployer.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/watch_party/watch_party_page.dart';
import 'package:nova_mobile/features/watch_party/watch_party_join_dialog.dart';
import 'package:nova_mobile/features/watch_party/widgets/watch_party_connection_settings.dart';
import 'package:nova_mobile/features/watch_party/widgets/watch_party_cloudflare_setup.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';
import 'support/watch_party_fixture.dart';

Widget app(WatchPartyController? controller,
        {String locale = 'en',
        double scale = 1,
        bool dark = true,
        double keyboardInset = 0,
        bool safeArea = false,
        WatchPartyRelaySettings? relay,
        Widget page = const WatchPartyPage()}) =>
    MultiProvider(
        providers: [
          ChangeNotifierProvider<WatchPartyController?>.value(
              value: controller),
          ChangeNotifierProvider<WatchPartyRelaySettings?>.value(value: relay)
        ],
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

class _RelaySettings extends WatchPartyRelaySettings {
  String? value;
  bool selected = false, failCheck = false;
  VoidCallback? onCheck;
  final events = <String>[];
  @override
  String? get endpoint => value;
  @override
  bool get configured => value != null;
  @override
  bool get enabled => selected;
  @override
  Future<void> configure(String endpoint) async {
    value = normalizeWatchPartyRelayEndpoint(endpoint).toString();
    selected = true;
    events.add('configure');
    notifyListeners();
  }

  @override
  Future<void> useSupabase() async {
    selected = false;
    events.add('default');
    notifyListeners();
  }

  @override
  Future<void> reset() async {
    value = null;
    selected = false;
    notifyListeners();
  }

  @override
  Future<WatchPartyRelayHealth> check({String? endpoint}) async {
    events.add('check');
    onCheck?.call();
    if (failCheck) throw const FormatException('incompatible');
    return const WatchPartyRelayHealth(version: 1, latencyMs: 20);
  }
}

class _Deployer extends CloudflareRelayDeployer {
  int deployments = 0, removals = 0;
  @override
  Future<List<CloudflareRelayAccount>> listAccounts(String token) async =>
      const [
        CloudflareRelayAccount(
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'My account'),
        CloudflareRelayAccount('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'Another account with a very long name')
      ];
  @override
  Future<String?> workersSubdomain(
          {required String token, required String accountId}) async =>
      'our-room';
  @override
  Future<bool> status(
          {required String token,
          required String accountId,
          required String workerName}) async =>
      true;
  @override
  Future<Uri> deploy(
      {required String token,
      required String accountId,
      required String workerName,
      String? subdomain}) async {
    deployments++;
    return Uri.https('$workerName.our-room.workers.dev');
  }

  @override
  Future<void> remove(
      {required String token,
      required String accountId,
      required String workerName}) async {
    removals++;
  }
}

Widget _joinButton() => Scaffold(
    body: Builder(
        builder: (context) => FilledButton(
            onPressed: () => showWatchPartyJoinDialog(context),
            child: const Text('join-shortcut'))));

class _ReplacingControllerScope extends StatefulWidget {
  const _ReplacingControllerScope(
      {required this.relay, required this.first, required this.second});
  final _RelaySettings relay;
  final FakeWatchPartyGateway first, second;
  @override
  State<_ReplacingControllerScope> createState() =>
      _ReplacingControllerScopeState();
}

class _ReplacingControllerScopeState extends State<_ReplacingControllerScope> {
  late WatchPartyController _controller;
  bool _usingRelay = false;
  @override
  void initState() {
    super.initState();
    _replace();
    widget.relay.addListener(_changed);
  }

  void _replace() {
    _controller = WatchPartyController(
        _usingRelay ? widget.second : widget.first,
        deviceId: partyDeviceId)
      ..bindIdentity('a', partyProfileId);
  }

  void _changed() {
    if (_usingRelay == widget.relay.enabled) return;
    _controller.dispose();
    _usingRelay = widget.relay.enabled;
    _replace();
    setState(() {});
  }

  @override
  void dispose() {
    widget.relay.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      app(_controller, relay: widget.relay, page: _joinButton());
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

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
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Join a room'));
    await tester.pumpAndSettle();
    expect(find.text('ABCD EFGH'), findsOneWidget);
    expect(g.requests.where((p) => p['p_action'] == 'join').single['p_code'],
        'ABCDEFGH');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('Home join accepts six-character code and full legacy invitation',
      (tester) async {
    for (final input in ['abc def', watchPartyInvite('ABCDEFGH')]) {
      final g = FakeWatchPartyGateway();
      final c = WatchPartyController(g, deviceId: partyDeviceId)
        ..bindIdentity('a', partyProfileId);
      await tester.pumpWidget(app(c, page: _joinButton()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('join-shortcut'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('party-invite-input')), input);
      await tester.tap(find.widgetWithText(FilledButton, 'Join a room'));
      await tester.pumpAndSettle();
      expect(g.requests.where((p) => p['p_action'] == 'join').single['p_code'],
          input.startsWith('abc') ? 'ABCDEF' : 'ABCDEFGH');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }
  });
  testWidgets('relay invitation contacts nothing until named server consent',
      (tester) async {
    final g = FakeWatchPartyGateway();
    final c = WatchPartyController(g, deviceId: partyDeviceId)
      ..bindIdentity('a', partyProfileId);
    final relay = _RelaySettings();
    final invitation = watchPartyInvite('ABCDEF',
        relay: Uri.https('trusted-room.workers.dev'));
    await tester.pumpWidget(app(c, relay: relay, page: _joinButton()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('join-shortcut'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('party-invite-input')), invitation);
    await tester.pumpAndSettle();
    expect(relay.events, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Join a room'));
    await tester.pumpAndSettle();
    expect(find.text('https://trusted-room.workers.dev'), findsOneWidget);
    expect(relay.events, isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();
    expect(relay.events, isEmpty);
    expect(g.requests.where((p) => p['p_action'] == 'join'), isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Join a room'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Use service and join'));
    await tester.pumpAndSettle();
    expect(relay.events, ['check', 'configure']);
    expect(relay.endpoint, 'https://trusted-room.workers.dev');
    expect(g.requests.where((p) => p['p_action'] == 'join').single['p_code'],
        'ABCDEF');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    relay.dispose();
  });
  testWidgets('unavailable relay cannot switch transport or join the room',
      (tester) async {
    final g = FakeWatchPartyGateway();
    final c = WatchPartyController(g, deviceId: partyDeviceId)
      ..bindIdentity('a', partyProfileId);
    final relay = _RelaySettings()..failCheck = true;
    await tester.pumpWidget(app(c, relay: relay, page: _joinButton()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('join-shortcut'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('party-invite-input')),
        watchPartyInvite('ABCDEF',
            relay: Uri.https('trusted-room.workers.dev')));
    await tester.tap(find.widgetWithText(FilledButton, 'Join a room'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Use service and join'));
    await tester.pumpAndSettle();
    expect(relay.events, ['check']);
    expect(relay.enabled, isFalse);
    expect(g.requests.where((p) => p['p_action'] == 'join'), isEmpty);
    expect(
        find.text(
            'The relay is unavailable or does not support this NOVA version.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    relay.dispose();
  });
  testWidgets(
      'confirmed relay invitation joins the replacement provider controller',
      (tester) async {
    final first = FakeWatchPartyGateway();
    final second = FakeWatchPartyGateway();
    final relay = _RelaySettings();
    await tester.pumpWidget(
        _ReplacingControllerScope(relay: relay, first: first, second: second));
    await tester.pumpAndSettle();
    await tester.tap(find.text('join-shortcut'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('party-invite-input')),
        watchPartyInvite('ABCDEF',
            relay: Uri.https('trusted-room.workers.dev')));
    await tester.tap(find.widgetWithText(FilledButton, 'Join a room'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Use service and join'));
    await tester.pumpAndSettle();
    expect(first.requests.where((p) => p['p_action'] == 'join'), isEmpty);
    expect(
        second.requests.where((p) => p['p_action'] == 'join').single['p_code'],
        'ABCDEF');
    expect(find.byType(WatchPartyJoinDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    relay.dispose();
  });
  testWidgets(
      'identity changes during relay health check cancel selection and join',
      (tester) async {
    final g = FakeWatchPartyGateway();
    final c = WatchPartyController(g, deviceId: partyDeviceId)
      ..bindIdentity('a', partyProfileId);
    final relay = _RelaySettings()
      ..onCheck = () => c.bindIdentity('another-account', partyProfileId);
    await tester.pumpWidget(app(c, relay: relay, page: _joinButton()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('join-shortcut'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('party-invite-input')),
        watchPartyInvite('ABCDEF',
            relay: Uri.https('trusted-room.workers.dev')));
    await tester.tap(find.widgetWithText(FilledButton, 'Join a room'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Use service and join'));
    await tester.pumpAndSettle();
    expect(relay.events, ['check']);
    expect(relay.enabled, isFalse);
    expect(g.requests.where((p) => p['p_action'] == 'join'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    relay.dispose();
  });
  testWidgets(
      'relay endpoint configuration validates and stays read-only inside a room',
      (tester) async {
    final relay = _RelaySettings();
    await tester.pumpWidget(app(null,
        relay: relay,
        page: Scaffold(
            body: SingleChildScrollView(
                child: WatchPartyConnectionSettings(settings: relay)))));
    await tester.enterText(
        find.byKey(const ValueKey('party-relay-endpoint')), 'http://localhost');
    await _tapVisible(
        tester, find.widgetWithText(FilledButton, 'Use this relay'));
    expect(relay.configured, isFalse);
    expect(
        find.text(
            'Enter a public HTTPS server address without a path, query or credentials.'),
        findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('party-relay-endpoint')),
        'https://trusted-room.workers.dev');
    await _tapVisible(
        tester, find.widgetWithText(FilledButton, 'Use this relay'));
    expect(relay.enabled, isTrue);
    await relay.configure('https://deployed-room.workers.dev');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(
                find.byKey(const ValueKey('party-relay-endpoint')))
            .controller!
            .text,
        'https://deployed-room.workers.dev');
    await tester.pumpWidget(app(null,
        relay: relay,
        page: Scaffold(
            body: SingleChildScrollView(
                child: WatchPartyConnectionSettings(
                    key: const ValueKey('locked'),
                    settings: relay,
                    locked: true)))));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(
        find.text('Leave the room to change its connection.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    relay.dispose();
  });
  testWidgets('pasted default-service invitation retains service consent',
      (tester) async {
    final relay = _RelaySettings();
    await relay.configure('https://trusted-room.workers.dev');
    relay.events.clear();
    final g = FakeWatchPartyGateway();
    final c = WatchPartyController(g, deviceId: partyDeviceId)
      ..bindIdentity('a', partyProfileId);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async => call.method == 'Clipboard.getData'
                ? {'text': watchPartyInvite('ABCDEFGH')}
                : null);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(app(c, relay: relay));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byTooltip('Paste code or invitation'));
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('party-code-input')))
            .controller!
            .text,
        watchPartyInvite('ABCDEFGH'));
    await _tapVisible(
        tester, find.widgetWithText(OutlinedButton, 'Join a room'));
    expect(find.text('Use this room service?'), findsOneWidget);
    expect(relay.events, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Use service and join'));
    await tester.pumpAndSettle();
    expect(relay.events, ['default']);
    expect(relay.enabled, isFalse);
    expect(g.requests.where((p) => p['p_action'] == 'join').single['p_code'],
        'ABCDEFGH');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    relay.dispose();
  });
  testWidgets('same episode returns only when locked source also matches',
      (tester) async {
    const roomSource = WatchPartySource(
        key:
            'stream:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        name: 'Host version');
    const otherSource = WatchPartySource(
        key:
            'stream:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        name: 'Other version');
    for (final source in [null, otherSource, roomSource]) {
      final g = FakeWatchPartyGateway();
      (g.data['room'] as Map)
        ..['source_locked'] = true
        ..['source'] = roomSource.toJson();
      final c = WatchPartyController(g, deviceId: partyDeviceId)
        ..bindIdentity('a', partyProfileId);
      await tester.runAsync(() => c.join('ABCDEFGH'));
      await tester.pumpWidget(
          app(c, page: WatchPartyPage(media: partyMedia, source: source)));
      await tester.pumpAndSettle();
      expect(
          find.widgetWithText(FilledButton,
              source == roomSource ? 'Return to playback' : 'Join playback'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }
  });
  testWidgets(
      'Cloudflare setup deploys selected account and clears its token field',
      (tester) async {
    final c =
        WatchPartyController(FakeWatchPartyGateway(), deviceId: partyDeviceId)
          ..bindIdentity('a', partyProfileId);
    final relay = _RelaySettings();
    final deployer = _Deployer();
    await tester.pumpWidget(app(c,
        relay: relay,
        page: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => WatchPartyCloudflareSetup(
                            settings: relay, deployer: deployer)),
                    child: const Text('setup'))))));
    await tester.tap(find.text('setup'));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('party-cloudflare-token'));
    expect(tester.widget<TextField>(input).obscureText, isTrue);
    await tester.enterText(input, 'ephemeral-test-token');
    await _tapVisible(
        tester, find.widgetWithText(OutlinedButton, 'Load accounts'));
    await _tapVisible(
        tester, find.widgetWithText(FilledButton, 'Deploy relay'));
    expect(deployer.deployments, 1);
    expect(relay.endpoint, 'https://nova-watch-party.our-room.workers.dev');
    expect(find.byKey(const ValueKey('party-cloudflare-token')), findsNothing);
    expect(find.text('Relay deployed and selected on this device.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    relay.dispose();
  });
  testWidgets('Cloudflare relay deletion requires explicit acknowledgement',
      (tester) async {
    final c =
        WatchPartyController(FakeWatchPartyGateway(), deviceId: partyDeviceId)
          ..bindIdentity('a', partyProfileId);
    final relay = _RelaySettings();
    final deployer = _Deployer();
    await tester.pumpWidget(app(c,
        relay: relay,
        page: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => WatchPartyCloudflareSetup(
                            settings: relay, deployer: deployer)),
                    child: const Text('setup'))))));
    await tester.tap(find.text('setup'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('party-cloudflare-token')),
        'ephemeral-test-token');
    await _tapVisible(
        tester, find.widgetWithText(OutlinedButton, 'Load accounts'));
    await _tapVisible(
        tester, find.widgetWithText(TextButton, 'Check deployment'));
    await _tapVisible(
        tester, find.widgetWithText(TextButton, 'Delete Cloudflare relay'));
    final remove = find.widgetWithText(FilledButton, 'Delete Cloudflare relay');
    expect(tester.widget<FilledButton>(remove).onPressed, isNull);
    expect(deployer.removals, 0);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(deployer.removals, 1);
    expect(
        tester
            .widget<TextField>(
                find.byKey(const ValueKey('party-cloudflare-token')))
            .controller!
            .text,
        isEmpty);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    relay.dispose();
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
  testWidgets(
      'explicit follow opens current room playback once after its first frame',
      (tester) async {
    final g = FakeWatchPartyGateway();
    final c = WatchPartyController(g, deviceId: partyDeviceId)
      ..bindIdentity('a', partyProfileId);
    await tester.runAsync(() => c.join('ABCDEFGH'));
    var calls = 0;
    WatchPartySnapshot? followed;
    Future<void> launch(BuildContext context, WatchPartySnapshot room) async {
      calls++;
      followed = room;
    }

    await tester.pumpWidget(app(c,
        page: WatchPartyPage(followPlayback: true, onJoinPlayback: launch)));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(followed?.id, partyRoomId);
    expect(followed?.media?.key, partyMedia.key);
    g.status!(true);
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(c,
        page: WatchPartyPage(followPlayback: true, onJoinPlayback: launch)));
    await tester.pumpAndSettle();
    expect(calls, 1);
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
    expect(find.byType(SwitchListTile), findsNWidgets(2));
    expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
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
    testWidgets(
        '$locale join and Cloudflare setup fit a narrow phone at 200% text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final relay = _RelaySettings();
      final deployer = _Deployer();
      final g = FakeWatchPartyGateway();
      final c = WatchPartyController(g, deviceId: partyDeviceId)
        ..bindIdentity('a', partyProfileId);
      await tester.pumpWidget(app(c,
          locale: locale,
          scale: 2,
          dark: locale == 'ar',
          relay: relay,
          page: _joinButton()));
      await tester.tap(find.text('join-shortcut'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, 'join-$locale-320-large');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(c,
          locale: locale,
          scale: 2,
          dark: locale == 'ar',
          relay: relay,
          page: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => WatchPartyCloudflareSetup(
                              settings: relay, deployer: deployer)),
                      child: const Text('setup'))))));
      await tester.tap(find.text('setup'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, 'cloudflare-$locale-320-large');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      relay.dispose();
    });
  }
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
