import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../core/platform/ios_chrome_bridge.dart';

/// Route-scoped detail presentation. The shell owns the single native channel;
/// detail routes register only semantic data and Flutter action handlers.
class DetailChromeEntry {
  DetailChromeEntry({
    required this.chrome,
    required this.onAction,
  }) : signature = jsonEncode(chrome.toMap());

  final IosDetailChrome chrome;
  final void Function(String id) onAction;
  final String signature;
}

class DetailChromeRegistry extends ChangeNotifier {
  final Map<Route<dynamic>, DetailChromeEntry> _entries = {};
  final ValueNotifier<Route<dynamic>?> nativeRoute = ValueNotifier(null);

  DetailChromeEntry? forRoute(Route<dynamic>? route) => _entries[route];

  void register(Route<dynamic> route, DetailChromeEntry entry) {
    final previous = _entries[route];
    _entries[route] = entry;
    if (previous?.signature != entry.signature) notifyListeners();
  }

  void unregister(Route<dynamic>? route) {
    if (route == null) return;
    if (_entries.remove(route) != null) notifyListeners();
    if (nativeRoute.value == route) nativeRoute.value = null;
  }

  void dispatch(Route<dynamic>? route, String id) {
    final entry = _entries[route];
    if (route == null || !route.isCurrent || entry == null) return;
    if (entry.chrome.enabledActions.contains(id)) entry.onAction(id);
  }
}

final detailChromeRegistry = DetailChromeRegistry();
