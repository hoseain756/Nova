import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/platform/ios_chrome_bridge.dart';
import '../../core/theme/system_bars.dart';
import '../../shared/widgets/glass_navigation.dart';
import '../../shared/widgets/nova_parental_gate.dart';
import '../../shared/widgets/nova_brand.dart';
import '../anime/anime_page.dart';
import '../calendar/calendar_page.dart';
import '../catalog/catalog_browser_page.dart';
import '../downloads/downloads_page.dart';
import '../home/home_page.dart';
import '../kids/kids_page.dart';
import '../library/library_page.dart';
import '../media/detail_chrome_registry.dart';
import '../live_tv/live_tv_page.dart';
import '../settings/addons_page.dart';
import '../settings/settings_page.dart';
import '../settings/stats_page.dart';
import 'dock_tab.dart';
import 'glass_dock.dart';
import 'noor_dock_tabs.dart';
import 'search_sheet.dart';

final ValueNotifier<bool> shellRouteVisible = ValueNotifier<bool>(true);
final ValueNotifier<Route<dynamic>?> shellTopRoute = ValueNotifier(null);

class ShellChromeRouteObserver extends NavigatorObserver {
  void _update(Route<dynamic>? route) {
    shellTopRoute.value = route;
    shellRouteVisible.value = route?.isFirst ?? false;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (shellTopRoute.value == route) _update(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (shellTopRoute.value == oldRoute) _update(newRoute);
  }
}

final shellChromeRouteObserver = ShellChromeRouteObserver();

/// A known iPhone keeps phone navigation when its landscape window is wide.
/// iPad compact windows continue to use the existing Flutter dock.
bool usesTabletNavigation(double width, {required bool iosPhone}) =>
    width >= 840 && !iosPhone;

/// Resolves the single shell/detail presentation from Flutter's top route.
/// A player (or any other pushed route) owns the screen until it is popped.
class ShellChromeRouteState {
  const ShellChromeRouteState({required this.tabsVisible, this.detail});

  final bool tabsVisible;
  final IosDetailChrome? detail;
}

ShellChromeRouteState resolveShellChromeRoute({
  required Route<dynamic>? topRoute,
  required bool shellVisible,
  required bool phone,
  required bool shellRouteCurrent,
  required bool reduceTransparency,
}) {
  if (!phone || !shellRouteCurrent) {
    return const ShellChromeRouteState(tabsVisible: false);
  }
  final detail = topRoute?.isCurrent == true && !reduceTransparency
      ? detailChromeRegistry.forRoute(topRoute)?.chrome
      : null;
  return ShellChromeRouteState(
    tabsVisible: !reduceTransparency && shellVisible && shellRouteVisible.value,
    detail: detail,
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  final IosChromeBridge _iosChrome = IosChromeBridge();
  bool _nativeChrome = false;
  bool _iosPhone = false;
  String? _lastChromeSignature;
  bool _appActive = true;
  int _chromeRevision = 0;
  int _selected = 0;
  final Set<int> _visited = {0};
  bool _chromeVisible = true;
  bool _checkingGate = false;
  bool _changingTab = false;
  double _scrollDelta = 0;
  late final Widget _animePage =
      const SafeArea(bottom: false, child: AnimePage());
  late final Widget _kidsPage =
      const SafeArea(bottom: false, child: KidsPage());
  late final Widget _libraryPage =
      const SafeArea(bottom: false, child: LibraryPage());
  late final Widget _settingsPage = SafeArea(
      bottom: false,
      child: SettingsPage(onOpenLibrary: () => unawaited(_selectTab(3))));
  HomePage _homePage = const HomePage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selected = context.read<AppState>().kidsSession ? 2 : 0;
    _visited
      ..clear()
      ..add(_selected);
    _homePage = HomePage(active: _selected == 0);
    shellRouteVisible.addListener(_onRouteVisibility);
    shellTopRoute.addListener(_onRouteVisibility);
    detailChromeRegistry.addListener(_onRouteVisibility);
    unawaited(_initializeIosChrome());
  }

  void _onRouteVisibility() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive != active && mounted) {
      setState(() => _appActive = active);
    }
  }

  Future<void> _initializeIosChrome() async {
    final capabilities = await _iosChrome.capabilities();
    if (!mounted) return;
    setState(() => _iosPhone = capabilities.phoneIdiom);
    if (!capabilities.phoneIdiom ||
        !capabilities.systemGlassAvailable ||
        !capabilities.nativeChromeAvailable ||
        capabilities.osMajor < 26) {
      return;
    }
    _iosChrome.onSelectIntent = (id, _) {
      if (!_chromeVisible ||
          !shellRouteVisible.value ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      final tabs = noorDockTabsFor(rtl: !context.read<AppState>().english);
      if (!tabs.any((tab) => tab.id == id)) return;
      unawaited(_selectTab(noorDockIndexForTabId(id)).then((_) {
        if (mounted) _publishIosChrome();
      }));
    };
    _iosChrome.onActionIntent = (id, _) {
      if (id == 'search' &&
          _selected == 0 &&
          _chromeVisible &&
          shellRouteVisible.value) {
        unawaited(_openSearch());
      } else if (IosDetailActionId.all.contains(id)) {
        detailChromeRegistry.dispatch(shellTopRoute.value, id);
      }
    };
    _iosChrome.listenForIntents();
    setState(() => _nativeChrome = true);
    if (!await _publishIosChrome() && mounted) {
      setState(() => _nativeChrome = false);
    }
  }

  Future<bool> _publishIosChrome() async {
    if (!_nativeChrome || !mounted) return false;
    final app = context.read<AppState>();
    final topRoute = shellTopRoute.value;
    final routeState = resolveShellChromeRoute(
      topRoute: topRoute,
      shellVisible: _chromeVisible,
      phone: _iosPhone,
      shellRouteCurrent: ModalRoute.of(context)?.isCurrent ?? true,
      reduceTransparency: app.webSettings['reduceTransparency'] == true,
    );
    final detail = routeState.detail;
    final shellVisible = routeState.tabsVisible;
    final revision = _chromeRevision + 1;
    final state = IosChromePresentation(
      revision: revision,
      selectedId: noorDockTabIdForIndex(_selected),
      tabs: [
        for (final tab in noorDockTabsFor(rtl: !app.english))
          IosChromeTab(id: tab.id, label: tab.label(arabic: !app.english)),
      ],
      visible: shellVisible,
      locale: app.english ? 'en' : 'ar',
      rtl: !app.english,
      dark: Theme.of(context).brightness == Brightness.dark,
      active: _appActive,
      searchVisible: _selected == 0 && shellVisible && detail == null,
      searchLabel: app.tr('message679'),
      detail: detail,
    );
    final signature = jsonEncode(state.toMap()..remove('revision'));
    if (signature == _lastChromeSignature) return true;
    _chromeRevision = revision;
    _lastChromeSignature = signature;
    final published = await _iosChrome.publish(state);
    if (mounted && revision == _chromeRevision) {
      detailChromeRegistry.nativeRoute.value =
          published && _appActive && detail != null ? topRoute : null;
      if (!published) {
        _lastChromeSignature = null;
        unawaited(_iosChrome.dispose());
        setState(() => _nativeChrome = false);
      }
    }
    return published;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    shellRouteVisible.removeListener(_onRouteVisibility);
    shellTopRoute.removeListener(_onRouteVisibility);
    detailChromeRegistry.removeListener(_onRouteVisibility);
    detailChromeRegistry.nativeRoute.value = null;
    unawaited(_iosChrome.dispose());
    super.dispose();
  }

  Widget _pageAt(int index) => switch (index) {
        0 => _homePage,
        1 => _animePage,
        2 => _kidsPage,
        3 => _libraryPage,
        _ => _settingsPage,
      };

  Future<bool> _mayLeaveKids() async {
    if (_selected != 2) return true;
    if (_checkingGate) return false;
    _checkingGate = true;
    try {
      return await NovaParentalGate.verify(context);
    } finally {
      _checkingGate = false;
    }
  }

  Future<void> _selectTab(int index) async {
    if (index == _selected) {
      if (!_chromeVisible) setState(() => _chromeVisible = true);
      return;
    }
    if (_changingTab) return;
    _changingTab = true;
    try {
      if (!await _mayLeaveKids() || !mounted) return;
      if (index == 2 && !await NovaParentalGate.ensureConfigured(context)) {
        return;
      }
      if (!mounted) return;
      await context.read<AppState>().setKidsSession(index == 2);
      if (!mounted) return;
      setState(() {
        _selected = index;
        _visited.add(index);
        _chromeVisible = true;
        _scrollDelta = 0;
        if ((index == 0) != _homePage.active) {
          _homePage = HomePage(active: index == 0);
        }
      });
    } finally {
      _changingTab = false;
    }
  }

  bool _onScroll(ScrollNotification event) {
    if (event.depth > 0 ||
        event.metrics.axis != Axis.vertical ||
        event is! ScrollUpdateNotification) {
      return false;
    }
    final app = context.read<AppState>();
    if (_selected == 2 ||
        app.webSettings['dockAutoHide'] == false ||
        usesTabletNavigation(MediaQuery.sizeOf(context).width,
            iosPhone: _iosPhone) ||
        MediaQuery.accessibleNavigationOf(context)) {
      if (!_chromeVisible) setState(() => _chromeVisible = true);
      return false;
    }
    if (event.metrics.pixels <= event.metrics.minScrollExtent + 24) {
      _scrollDelta = 0;
      if (!_chromeVisible) setState(() => _chromeVisible = true);
      return false;
    }
    final delta = event.scrollDelta ?? 0;
    _scrollDelta =
        delta.sign == _scrollDelta.sign ? _scrollDelta + delta : delta;
    if (_scrollDelta >= 40 && _chromeVisible) {
      setState(() => _chromeVisible = false);
      _scrollDelta = 0;
    } else if (_scrollDelta <= -16 && !_chromeVisible) {
      setState(() => _chromeVisible = true);
      _scrollDelta = 0;
    }
    return false;
  }

  Future<void> _openSearch() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 1100),
        builder: (_) => const SearchSheet(),
      );

  Future<void> _openSecondary(Widget page) async {
    if (!await _mayLeaveKids() || !mounted) return;
    if (_selected == 2) {
      await context.read<AppState>().setKidsSession(false);
      if (!mounted) return;
      setState(() {
        _selected = 0;
        _visited.add(0);
        _homePage = const HomePage();
      });
    }
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    if (_nativeChrome) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _publishIosChrome());
    }
    final english = context.select<AppState, bool>((app) => app.english);
    final reduceSetting = context.select<AppState, bool>(
        (app) => app.webSettings['reduceMotion'] == true);
    final reduceTransparency = context.select<AppState, bool>(
        (app) => app.webSettings['reduceTransparency'] == true);
    final navigationBarStyle = context.select<AppState, NavigationBarStyle>(
        (app) => NavigationBarStyle.fromSetting(
            app.webSettings['navigationBarStyle']));
    final tablet = usesTabletNavigation(MediaQuery.sizeOf(context).width,
        iosPhone: _iosPhone);
    final useNativeChrome = _nativeChrome && !reduceTransparency;
    final reduce = MediaQuery.disableAnimationsOf(context) || reduceSetting;
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 220);
    final app = context.read<AppState>();
    final pages = Stack(children: [
      // A tab's API calls and state are created only on its first visit.
      for (final i in _visited)
        Positioned.fill(
            key: ValueKey(i),
            child: TickerMode(
                enabled: _selected == i,
                child: Offstage(offstage: _selected != i, child: _pageAt(i)))),
    ]);
    return PopScope(
      canPop: _selected != 2,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selected == 2) unawaited(_selectTab(0));
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: noorSystemBarOverlayStyle(Theme.of(context).brightness),
        child: Scaffold(
            body: Row(children: [
          if (tablet)
            // Bottom-dock appearance preferences do not replace the tablet
            // side rail: all three options are horizontal dock presentations.
            _TabletNavigation(
                selected: _selected,
                onTabSelected: (i) => unawaited(_selectTab(i)),
                onPageSelected: (page) => unawaited(_openSecondary(page)),
                onSearch: _selected == 2 ? null : _openSearch),
          Expanded(
              child: Stack(children: [
            Positioned.fill(
                child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll, child: pages)),
            if (!tablet && !useNativeChrome && _selected == 0)
              PositionedDirectional(
                  end: 20,
                  top: MediaQuery.paddingOf(context).top + 12,
                  child: IgnorePointer(
                      ignoring: !_chromeVisible,
                      child: AnimatedOpacity(
                          opacity: _chromeVisible ? 1 : 0,
                          duration: duration,
                          child: GlassSearchButton(
                              tooltip: app.tr('message679'),
                              onPressed: _openSearch)))),
            if (!tablet && !useNativeChrome)
              PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 0,
                  child: GlassDock(
                      tabs: noorDockTabsFor(rtl: !english),
                      activeId: noorDockTabIdForIndex(_selected),
                      onTabSelected: (DockTab tab) => unawaited(
                          _selectTab(noorDockIndexForTabId(tab.view))),
                      languageCode: english ? 'en' : 'ar',
                      style: navigationBarStyle,
                      hidden: !_chromeVisible,
                      reduceMotion: reduce,
                      reduceTransparency: reduceTransparency)),
          ])),
        ])),
      ),
    );
  }
}

class _TabletNavigation extends StatelessWidget {
  const _TabletNavigation(
      {required this.selected,
      required this.onTabSelected,
      required this.onPageSelected,
      required this.onSearch});
  final int selected;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<Widget> onPageSelected;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final theme = Theme.of(context);
    final expanded = MediaQuery.sizeOf(context).width >= 1200;
    final tabs = noorDockTabsFor(rtl: !app.english);
    final secondary = <(IconData, String, Widget)>[
      (
        LucideIcons.compass,
        app.tr('message576'),
        const CatalogBrowserPage(mode: CatalogBrowseMode.discover)
      ),
      (
        LucideIcons.film,
        app.tr('message577'),
        const CatalogBrowserPage(mode: CatalogBrowseMode.movies)
      ),
      (
        LucideIcons.tv,
        app.tr('message578'),
        const CatalogBrowserPage(mode: CatalogBrowseMode.shows)
      ),
      (
        LucideIcons.layoutGrid,
        app.tr('message680'),
        const CatalogBrowserPage(mode: CatalogBrowseMode.catalogs)
      ),
      (LucideIcons.radio, app.tr('message658'), const LiveTvPage()),
      (LucideIcons.calendarDays, app.tr('message565'), const CalendarPage()),
      (LucideIcons.download, app.tr('downloads'), const DownloadsPage()),
      (
        LucideIcons.chartNoAxesCombined,
        app.tr('message681'),
        const StatsPage()
      ),
      (LucideIcons.puzzle, app.tr('message220'), const AddonsPage()),
    ];
    Widget destination(
            IconData icon, String label, bool active, VoidCallback tap) =>
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
          child: Tooltip(
              message: label,
              child: Semantics(
                  selected: active,
                  child: Material(
                      color: active
                          ? theme.colorScheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: tap,
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: expanded
                                ? Row(children: [
                                    Icon(icon,
                                        size: 22,
                                        color: active
                                            ? theme
                                                .colorScheme.onPrimaryContainer
                                            : theme
                                                .colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 16),
                                    Expanded(
                                        child: Text(label,
                                            style: theme.textTheme.labelLarge))
                                  ])
                                : Icon(icon,
                                    size: 24,
                                    color: active
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurfaceVariant)),
                      )))),
        );
    return SizedBox(
        width: expanded ? 240 : 84,
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: BorderDirectional(
                  end: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: .45)))),
          child: SafeArea(
              child: ListView(children: [
            Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 24),
                child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: NovaBrand(
                        symbolOnly: !expanded, width: expanded ? 144 : 40))),
            if (onSearch != null)
              destination(
                  LucideIcons.search, app.tr('message679'), false, onSearch!),
            for (final tab in tabs)
              destination(
                  tab.iconOutline,
                  tab.label(arabic: !app.english),
                  noorDockIndexForTabId(tab.view) == selected,
                  () => onTabSelected(noorDockIndexForTabId(tab.view))),
            const Padding(padding: EdgeInsets.all(16), child: Divider()),
            for (final item in secondary)
              destination(
                  item.$1, item.$2, false, () => onPageSelected(item.$3)),
            const SizedBox(height: 24),
          ])),
        ));
  }
}
