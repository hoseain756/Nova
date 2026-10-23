import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nova_mobile/features/shell/main_shell.dart';
import 'package:nova_mobile/core/platform/ios_chrome_bridge.dart';
import 'package:nova_mobile/features/media/detail_chrome_registry.dart';
import 'package:nova_mobile/features/media/detail_hero.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nova/ios_chrome/v1');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('unsupported platforms make no native calls', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls++;
      return null;
    });
    final bridge = IosChromeBridge(channel: channel, isIOS: false);
    expect((await bridge.capabilities()).nativeChromeAvailable, isFalse);
    expect(await bridge.publish(_state(1)), isFalse);
    await bridge.dispose();
    expect(calls, 0);
  });

  test('iOS capability and snapshot use discrete calls', () async {
    final methods = <String>[];
    Map<dynamic, dynamic>? snapshot;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'getCapabilities') {
        return {
          'osMajor': 26,
          'systemGlassAvailable': true,
          'nativeChromeAvailable': true,
          'phoneIdiom': true,
        };
      }
      if (call.method == 'setPresentation') {
        snapshot = call.arguments as Map;
      }
      return null;
    });
    final bridge = IosChromeBridge(channel: channel, isIOS: true);
    final capability = await bridge.capabilities();
    expect(capability.osMajor, 26);
    expect(capability.systemGlassAvailable, isTrue);
    expect(capability.nativeChromeAvailable, isTrue);
    expect(capability.phoneIdiom, isTrue);
    expect(await bridge.publish(_state(1)), isTrue);
    expect(await bridge.publish(_state(1)), isFalse);
    expect(snapshot?['selectedId'], 'home');
    expect((snapshot?['tabs'] as List).single['label'], 'Home');
    expect(snapshot?['searchVisible'], isFalse);
    await bridge.dispose();
    expect(methods, ['getCapabilities', 'setPresentation', 'dispose']);
  });

  test('missing native channel falls back safely', () async {
    final bridge = IosChromeBridge(channel: channel, isIOS: true);
    expect(await bridge.capabilities(), IosChromeCapabilities.unsupported);
    expect(await bridge.publish(_state(1)), isFalse);
    await bridge.dispose();
  });

  test('iOS 15 capability does not enable presentation', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'getCapabilities') {
        return {
          'osMajor': 15,
          'systemGlassAvailable': false,
          'nativeChromeAvailable': false,
          'phoneIdiom': true,
        };
      }
      return null;
    });
    final bridge = IosChromeBridge(channel: channel, isIOS: true);
    expect((await bridge.capabilities()).osMajor, 15);
    expect(usesTabletNavigation(900, iosPhone: true), isFalse);
    expect(await bridge.publish(_state(1)), isFalse);
    await bridge.dispose();
    expect(methods, ['getCapabilities', 'dispose']);
  });

  test('iOS 18 capability keeps Flutter presentation', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'getCapabilities') {
        return {
          'osMajor': 18,
          'systemGlassAvailable': false,
          'nativeChromeAvailable': false,
        };
      }
      return null;
    });
    final bridge = IosChromeBridge(channel: channel, isIOS: true);
    expect((await bridge.capabilities()).nativeChromeAvailable, isFalse);
    expect(await bridge.publish(_state(1)), isFalse);
    await bridge.dispose();
    expect(methods, ['getCapabilities', 'dispose']);
  });

  test(
      'iPad keeps Flutter navigation at wide sizes and dock in compact windows',
      () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'getCapabilities') {
        return {
          'osMajor': 26,
          'systemGlassAvailable': true,
          'nativeChromeAvailable': false,
          'phoneIdiom': false,
        };
      }
      return null;
    });
    final bridge = IosChromeBridge(channel: channel, isIOS: true);
    final capability = await bridge.capabilities();
    expect(capability.phoneIdiom, isFalse);
    expect(usesTabletNavigation(1024, iosPhone: capability.phoneIdiom), isTrue);
    expect(usesTabletNavigation(700, iosPhone: capability.phoneIdiom), isFalse);
    expect(usesTabletNavigation(900, iosPhone: true), isFalse);
    expect(usesTabletNavigation(900, iosPhone: false), isTrue);
    expect(await bridge.publish(_state(1)), isFalse);
    expect(methods, ['getCapabilities']);
    await bridge.dispose();
  });

  test('pre-26 cannot publish even if a host misreports native capability',
      () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'getCapabilities') {
        return {
          'osMajor': 25,
          'systemGlassAvailable': true,
          'nativeChromeAvailable': true,
        };
      }
      return null;
    });
    final bridge = IosChromeBridge(channel: channel, isIOS: true);
    await bridge.capabilities();
    expect(await bridge.publish(_detailState(1)), isFalse);
    expect(methods, ['getCapabilities']);
    await bridge.dispose();
  });

  test('detail actions use localized stable IDs and reject stale or disabled',
      () async {
    Map<dynamic, dynamic>? snapshot;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getCapabilities') {
        return {
          'osMajor': 26,
          'systemGlassAvailable': true,
          'nativeChromeAvailable': true,
        };
      }
      if (call.method == 'setPresentation') snapshot = call.arguments as Map;
      return null;
    });
    final bridge = IosChromeBridge(channel: channel, isIOS: true);
    await bridge.capabilities();
    final received = <String>[];
    bridge.onActionIntent = (id, _) => received.add(id);
    bridge.listenForIntents();
    expect(await bridge.publish(_detailState(9)), isTrue);
    expect(snapshot?['selectedId'], 'home');
    expect(snapshot?['visible'], isFalse);
    expect(snapshot?['searchVisible'], isFalse);
    expect(snapshot?['rtl'], isTrue);
    expect(snapshot?['locale'], 'ar');
    final detail = snapshot?['detail'] as Map;
    expect(detail['backLabel'], 'رجوع');
    expect(detail['shareLabel'], 'مشاركة');
    expect((detail['menu'] as List).map((item) => item['id']),
        [IosDetailActionId.sources, IosDetailActionId.list]);
    expect((detail['menu'] as List).first['enabled'], isFalse);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Future<void> intent(String id, int revision) =>
        messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(MethodCall(
            'actionIntent',
            {'id': id, 'revision': revision},
          )),
          (_) {},
        );
    await intent(IosDetailActionId.back, 8);
    await intent('search', 9);
    await intent(IosDetailActionId.sources, 9);
    await intent('detail.unknown', 9);
    expect(received, isEmpty);
    await intent(IosDetailActionId.back, 9);
    await intent(IosDetailActionId.share, 9);
    await intent(IosDetailActionId.list, 9);
    expect(received, [
      IosDetailActionId.back,
      IosDetailActionId.share,
      IosDetailActionId.list,
    ]);
    await bridge.publish(const IosChromePresentation(
      revision: 10,
      selectedId: 'home',
      tabs: [IosChromeTab(id: 'home', label: 'Home')],
      visible: false,
      locale: 'en',
      rtl: false,
      dark: true,
      active: true,
      detail: IosDetailChrome(
        backLabel: 'Back',
        shareLabel: 'Share',
        moreLabel: 'More',
        shareEnabled: false,
        menu: [],
      ),
    ));
    expect((snapshot?['detail'] as Map)['backLabel'], 'Back');
    expect((snapshot?['detail'] as Map)['shareEnabled'], isFalse);
    expect(snapshot?['rtl'], isFalse);
    await intent(IosDetailActionId.share, 10);
    expect(received.length, 3);
    await intent(IosDetailActionId.back, 9);
    await intent(IosDetailActionId.back, 10);
    expect(received.length, 4);
    await bridge.publish(_state(11));
    await intent(IosDetailActionId.back, 11);
    expect(received.length, 4);
    await bridge.dispose();
  });

  test('an older failed publish cannot clear the newer intent gate', () async {
    final first = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getCapabilities') {
        return {
          'osMajor': 26,
          'systemGlassAvailable': true,
          'nativeChromeAvailable': true,
          'phoneIdiom': true,
        };
      }
      if (call.method == 'setPresentation' &&
          (call.arguments as Map)['revision'] == 1) {
        await first.future;
        throw PlatformException(code: 'old_failure');
      }
      return null;
    });
    final bridge = IosChromeBridge(channel: channel, isIOS: true);
    await bridge.capabilities();
    final received = <String>[];
    bridge.onActionIntent = (id, _) => received.add(id);
    bridge.listenForIntents();
    final oldPublish = bridge.publish(_state(1));
    expect(
        await bridge.publish(const IosChromePresentation(
          revision: 2,
          selectedId: 'home',
          tabs: [IosChromeTab(id: 'home', label: 'Home')],
          visible: true,
          locale: 'en',
          rtl: false,
          dark: true,
          active: true,
          searchVisible: true,
          searchLabel: 'Search',
        )),
        isTrue);
    first.complete();
    expect(await oldPublish, isFalse);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(const MethodCall(
        'actionIntent',
        {'id': 'search', 'revision': 2},
      )),
      (_) {},
    );
    expect(received, ['search']);
    await bridge.dispose();
  });

  test('search action uses stable ID and current revision only', () async {
    Map<dynamic, dynamic>? snapshot;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getCapabilities') {
        return {
          'osMajor': 26,
          'systemGlassAvailable': true,
          'nativeChromeAvailable': true,
        };
      }
      if (call.method == 'setPresentation') {
        snapshot = call.arguments as Map;
      }
      return null;
    });
    final bridge = IosChromeBridge(channel: channel, isIOS: true);
    await bridge.capabilities();
    final actions = <String>[];
    bridge.onActionIntent = (id, _) => actions.add(id);
    bridge.listenForIntents();
    await bridge.publish(const IosChromePresentation(
      revision: 7,
      selectedId: 'home',
      tabs: [IosChromeTab(id: 'home', label: 'الرئيسية')],
      visible: true,
      locale: 'ar',
      rtl: true,
      dark: false,
      active: true,
      searchVisible: true,
      searchLabel: 'بحث',
    ));
    expect(snapshot?['searchLabel'], 'بحث');
    expect(snapshot?['searchVisible'], isTrue);
    expect(snapshot?['rtl'], isTrue);
    expect(snapshot?['dark'], isFalse);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Future<void> intent(String id, int revision) async {
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(
          'actionIntent',
          {'id': id, 'revision': revision},
        )),
        (_) {},
      );
    }

    await intent('search', 6);
    await intent('unknown', 7);
    expect(actions, isEmpty);
    await intent('search', 7);
    expect(actions, ['search']);
    await bridge.publish(const IosChromePresentation(
      revision: 8,
      selectedId: 'home',
      tabs: [IosChromeTab(id: 'home', label: 'الرئيسية')],
      visible: false,
      locale: 'ar',
      rtl: true,
      dark: false,
      active: true,
      searchVisible: true,
      searchLabel: 'بحث',
    ));
    await intent('search', 8);
    expect(actions, ['search']);
    await bridge.dispose();
    await intent('search', 8);
    expect(actions, ['search']);
  });

  test('player presentation hides every shell surface and rejects tab intents',
      () async {
    final snapshots = <Map<dynamic, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getCapabilities') {
        return {
          'osMajor': 26,
          'systemGlassAvailable': true,
          'nativeChromeAvailable': true,
        };
      }
      if (call.method == 'setPresentation') {
        snapshots.add(call.arguments as Map);
      }
      return null;
    });
    final bridge = IosChromeBridge(channel: channel, isIOS: true);
    await bridge.capabilities();
    final tabs = <String>[];
    final actions = <String>[];
    bridge.onSelectIntent = (id, _) => tabs.add(id);
    bridge.onActionIntent = (id, _) => actions.add(id);
    bridge.listenForIntents();

    Future<void> intent(String method, String id, int revision) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(
          method,
          {'id': id, 'revision': revision},
        )),
        (_) {},
      );
    }

    expect(await bridge.publish(_detailState(1)), isTrue);
    expect(
        await bridge.publish(const IosChromePresentation(
          revision: 2,
          selectedId: 'home',
          tabs: [IosChromeTab(id: 'home', label: 'Home')],
          visible: false,
          locale: 'en',
          rtl: false,
          dark: true,
          active: true,
        )),
        isTrue);
    final player = snapshots.last;
    expect(player['visible'], isFalse);
    expect(player['searchVisible'], isFalse);
    expect(player['detail'], isNull);
    expect(player.keys.toSet(), {
      'revision',
      'selectedId',
      'tabs',
      'visible',
      'locale',
      'rtl',
      'dark',
      'active',
      'searchVisible',
      'searchLabel',
      'detail',
    });
    await intent('actionIntent', IosDetailActionId.back, 1);
    await intent('actionIntent', IosDetailActionId.back, 2);
    await intent('actionIntent', 'search', 2);
    await intent('selectIntent', 'home', 2);
    expect(actions, isEmpty);
    expect(tabs, isEmpty);

    expect(await bridge.publish(_detailState(3)), isTrue);
    await intent('actionIntent', IosDetailActionId.back, 2);
    await intent('actionIntent', IosDetailActionId.back, 3);
    await intent('selectIntent', IosDetailActionId.back, 3);
    expect(actions, [IosDetailActionId.back]);
    expect(
        await bridge.publish(const IosChromePresentation(
          revision: 4,
          selectedId: 'home',
          tabs: [IosChromeTab(id: 'home', label: 'Home')],
          visible: true,
          locale: 'en',
          rtl: false,
          dark: true,
          active: true,
          searchVisible: true,
          searchLabel: 'Search',
        )),
        isTrue);
    expect(snapshots.last['visible'], isTrue);
    expect(snapshots.last['searchVisible'], isTrue);
    expect(snapshots.last['detail'], isNull);
    await intent('selectIntent', 'home', 4);
    await intent('selectIntent', 'search', 4);
    await intent('actionIntent', 'search', 4);
    expect(tabs, ['home']);
    expect(actions, [IosDetailActionId.back, 'search']);
    expect(
        await bridge.publish(const IosChromePresentation(
          revision: 5,
          selectedId: 'home',
          tabs: [IosChromeTab(id: 'home', label: 'Home', enabled: false)],
          visible: true,
          locale: 'en',
          rtl: false,
          dark: true,
          active: true,
        )),
        isTrue);
    await intent('selectIntent', 'home', 5);
    await intent('selectIntent', 'unknown', 5);
    expect(tabs, ['home']);
    await bridge.dispose();
    await intent('actionIntent', 'search', 4);
    expect(actions, [IosDetailActionId.back, 'search']);
  });

  testWidgets('player route hides tabs, search and detail then restores detail',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [shellChromeRouteObserver],
      home: const Scaffold(body: Text('home')),
    ));
    ShellChromeRouteState state() => resolveShellChromeRoute(
          topRoute: shellTopRoute.value,
          shellVisible: true,
          phone: true,
          shellRouteCurrent: true,
          reduceTransparency: false,
        );
    expect(state().tabsVisible, isTrue);
    expect(state().detail, isNull);
    expect(
        resolveShellChromeRoute(
          topRoute: shellTopRoute.value,
          shellVisible: true,
          phone: true,
          shellRouteCurrent: true,
          reduceTransparency: true,
        ).tabsVisible,
        isFalse);

    final detailRoute = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('detail')),
    );
    navigatorKey.currentState!.push(detailRoute);
    await tester.pumpAndSettle();
    detailChromeRegistry.register(
      detailRoute,
      DetailChromeEntry(
        chrome: const IosDetailChrome(
          backLabel: 'Back',
          shareLabel: 'Share',
          moreLabel: 'More',
          menu: [],
        ),
        onAction: (_) {},
      ),
    );
    expect(state().tabsVisible, isFalse);
    expect(state().detail?.backLabel, 'Back');
    final dialog = showDialog<void>(
      context: navigatorKey.currentState!.overlay!.context,
      builder: (_) => const AlertDialog(title: Text('detail modal')),
    );
    await tester.pumpAndSettle();
    expect(state().detail, isNull);
    expect(state().tabsVisible, isFalse);
    navigatorKey.currentState!.pop();
    await dialog;
    await tester.pumpAndSettle();
    expect(state().detail?.backLabel, 'Back');
    expect(
        resolveShellChromeRoute(
          topRoute: shellTopRoute.value,
          shellVisible: true,
          phone: false,
          shellRouteCurrent: true,
          reduceTransparency: false,
        ).detail,
        isNull);
    expect(
        resolveShellChromeRoute(
          topRoute: shellTopRoute.value,
          shellVisible: true,
          phone: true,
          shellRouteCurrent: true,
          reduceTransparency: true,
        ).detail,
        isNull);

    final playerRoute = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('player')),
    );
    navigatorKey.currentState!.push(playerRoute);
    await tester.pumpAndSettle();
    expect(shellTopRoute.value, playerRoute);
    expect(state().tabsVisible, isFalse);
    expect(state().detail, isNull);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(state().detail?.backLabel, 'Back');
    expect(state().tabsVisible, isFalse);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    detailChromeRegistry.unregister(detailRoute);
    expect(state().tabsVisible, isTrue);
    expect(state().detail, isNull);
  });

  testWidgets('shell route observer hides chrome above a pushed route',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [shellChromeRouteObserver],
      home: Builder(
          builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const Text('detail'))),
              child: const Text('open'))),
    ));
    expect(shellRouteVisible.value, isTrue);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(shellRouteVisible.value, isFalse);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(shellRouteVisible.value, isTrue);
  });

  testWidgets('shell route observer hides chrome for a modal sheet',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [shellChromeRouteObserver],
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => const Text('search sheet'),
          ),
          child: const Text('search'),
        ),
      ),
    ));
    expect(shellRouteVisible.value, isTrue);
    await tester.tap(find.text('search'));
    await tester.pumpAndSettle();
    expect(shellRouteVisible.value, isFalse);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(shellRouteVisible.value, isTrue);
  });

  testWidgets('detail registry sends Flutter actions only for top route',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [shellChromeRouteObserver],
      home: const Text('home'),
    ));
    final detailRoute = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('detail')));
    navigatorKey.currentState!.push(detailRoute);
    await tester.pumpAndSettle();
    final received = <String>[];
    detailChromeRegistry.register(
      detailRoute,
      DetailChromeEntry(
        chrome: const IosDetailChrome(
          backLabel: 'Back',
          shareLabel: 'Share',
          moreLabel: 'More',
          menu: [
            IosDetailMenuAction(id: IosDetailActionId.list, label: 'List')
          ],
        ),
        onAction: received.add,
      ),
    );
    detailChromeRegistry.nativeRoute.value = detailRoute;
    detailChromeRegistry.dispatch(shellTopRoute.value, IosDetailActionId.back);
    expect(received, [IosDetailActionId.back]);
    final modal = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('modal')));
    navigatorKey.currentState!.push(modal);
    await tester.pumpAndSettle();
    detailChromeRegistry.dispatch(detailRoute, IosDetailActionId.share);
    expect(received.length, 1);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    detailChromeRegistry.dispatch(shellTopRoute.value, IosDetailActionId.list);
    expect(received.last, IosDetailActionId.list);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    detailChromeRegistry.unregister(detailRoute);
    expect(detailChromeRegistry.forRoute(detailRoute), isNull);
    expect(detailChromeRegistry.nativeRoute.value, isNull);
  });

  testWidgets('detail row retains Flutter actions until native chrome is live',
      (tester) async {
    Widget row(bool native) => MaterialApp(
          home: Scaffold(
            body: DetailActionRow(
              english: true,
              isWide: false,
              inList: false,
              showTrackAnime: false,
              primaryLabel: 'Play',
              primaryIsResume: false,
              loading: false,
              nativeTopActions: native,
              onPrimaryPressed: () {},
              onToggleWatchlist: () {},
              onOpenStreams: () {},
              onTrackAnime: () {},
              onShare: () {},
              onAddToList: () {},
            ),
          ),
        );
    await tester.pumpWidget(row(false));
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    await tester.pumpWidget(row(true));
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('Play'), findsOneWidget);
  });
}

IosChromePresentation _state(int revision) => IosChromePresentation(
      revision: revision,
      selectedId: 'home',
      tabs: const [IosChromeTab(id: 'home', label: 'Home')],
      visible: true,
      locale: 'en',
      rtl: false,
      dark: true,
      active: true,
    );

IosChromePresentation _detailState(int revision) => IosChromePresentation(
      revision: revision,
      selectedId: 'home',
      tabs: const [IosChromeTab(id: 'home', label: 'الرئيسية')],
      visible: false,
      locale: 'ar',
      rtl: true,
      dark: false,
      active: true,
      searchVisible: false,
      detail: const IosDetailChrome(
        backLabel: 'رجوع',
        shareLabel: 'مشاركة',
        moreLabel: 'المزيد',
        menu: [
          IosDetailMenuAction(
            id: IosDetailActionId.sources,
            label: 'المصادر',
            enabled: false,
          ),
          IosDetailMenuAction(
            id: IosDetailActionId.list,
            label: 'القوائم',
          ),
        ],
      ),
    );
