import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Presentation-only protocol. Flutter remains the source of tab and route state.
class IosChromeCapabilities {
  const IosChromeCapabilities({
    required this.osMajor,
    required this.systemGlassAvailable,
    required this.nativeChromeAvailable,
    this.phoneIdiom = false,
  });

  final int osMajor;
  final bool systemGlassAvailable;
  final bool nativeChromeAvailable;
  final bool phoneIdiom;

  static const unsupported = IosChromeCapabilities(
    osMajor: 0,
    systemGlassAvailable: false,
    nativeChromeAvailable: false,
    phoneIdiom: false,
  );

  factory IosChromeCapabilities.fromMap(Map<Object?, Object?> value) =>
      IosChromeCapabilities(
        osMajor: value['osMajor'] is int ? value['osMajor'] as int : 0,
        systemGlassAvailable: value['systemGlassAvailable'] == true,
        nativeChromeAvailable: value['nativeChromeAvailable'] == true,
        phoneIdiom: value['phoneIdiom'] == true,
      );
}

class IosChromeTab {
  const IosChromeTab({
    required this.id,
    required this.label,
    this.enabled = true,
  });

  final String id;
  final String label;
  final bool enabled;

  Map<String, Object> toMap() => {
        'id': id,
        'label': label,
        'enabled': enabled,
      };
}

/// The only detail actions that the scene overlay may report to Flutter.
abstract final class IosDetailActionId {
  static const back = 'detail.back';
  static const share = 'detail.share';
  static const sources = 'detail.sources';
  static const list = 'detail.list';
  static const track = 'detail.track';

  static const all = {back, share, sources, list, track};
}

class IosDetailMenuAction {
  const IosDetailMenuAction({
    required this.id,
    required this.label,
    this.enabled = true,
  }) : assert(id == IosDetailActionId.sources ||
            id == IosDetailActionId.list ||
            id == IosDetailActionId.track);

  final String id;
  final String label;
  final bool enabled;

  Map<String, Object> toMap() => {
        'id': id,
        'label': label,
        'enabled': enabled,
      };
}

class IosDetailChrome {
  const IosDetailChrome({
    required this.backLabel,
    required this.shareLabel,
    required this.moreLabel,
    required this.menu,
    this.shareEnabled = true,
  });

  final String backLabel;
  final String shareLabel;
  final String moreLabel;
  final List<IosDetailMenuAction> menu;
  final bool shareEnabled;

  Map<String, Object> toMap() => {
        'backLabel': backLabel,
        'shareLabel': shareLabel,
        'moreLabel': moreLabel,
        'shareEnabled': shareEnabled,
        'menu': menu.map((action) => action.toMap()).toList(growable: false),
      };

  Set<String> get enabledActions => {
        IosDetailActionId.back,
        if (shareEnabled) IosDetailActionId.share,
        for (final action in menu)
          if (action.enabled) action.id,
      };
}

class IosChromePresentation {
  const IosChromePresentation({
    required this.revision,
    required this.selectedId,
    required this.tabs,
    required this.visible,
    required this.locale,
    required this.rtl,
    required this.dark,
    required this.active,
    this.searchVisible = false,
    this.searchLabel = '',
    this.detail,
  });

  final int revision;
  final String selectedId;
  final List<IosChromeTab> tabs;
  final bool visible;
  final String locale;
  final bool rtl;
  final bool dark;
  final bool active;
  final bool searchVisible;
  final String searchLabel;
  final IosDetailChrome? detail;

  Map<String, Object?> toMap() => {
        'revision': revision,
        'selectedId': selectedId,
        'tabs': tabs.map((tab) => tab.toMap()).toList(growable: false),
        'visible': visible,
        'locale': locale,
        'rtl': rtl,
        'dark': dark,
        'active': active,
        'searchVisible': searchVisible,
        'searchLabel': searchLabel,
        'detail': detail?.toMap(),
      };
}

/// MainShell owns this bridge and validates native intents before changing
/// Flutter navigation or route state.
class IosChromeBridge {
  IosChromeBridge({MethodChannel? channel, bool? isIOS})
      : _channel = channel ?? const MethodChannel('nova/ios_chrome/v1'),
        _isIOS =
            isIOS ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  final MethodChannel _channel;
  final bool _isIOS;
  bool _disposed = false;
  int _latestRevision = -1;
  bool _tabsVisible = false;
  Set<String> _enabledTabs = const {};
  bool _searchVisible = false;
  Set<String> _detailActions = const {};
  IosChromeCapabilities? _capabilities;
  void Function(String id, int revision)? onSelectIntent;
  void Function(String id, int revision)? onActionIntent;

  Future<IosChromeCapabilities> capabilities() async {
    if (!_isIOS || _disposed) return IosChromeCapabilities.unsupported;
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'getCapabilities',
      );
      _capabilities = result == null
          ? IosChromeCapabilities.unsupported
          : IosChromeCapabilities.fromMap(result);
      return _capabilities!;
    } on MissingPluginException {
      _capabilities = IosChromeCapabilities.unsupported;
      return IosChromeCapabilities.unsupported;
    } on PlatformException {
      _capabilities = IosChromeCapabilities.unsupported;
      return IosChromeCapabilities.unsupported;
    }
  }

  Future<bool> publish(IosChromePresentation state) async {
    if (!_isIOS ||
        _disposed ||
        _capabilities?.nativeChromeAvailable != true ||
        _capabilities!.systemGlassAvailable != true ||
        _capabilities!.osMajor < 26 ||
        state.revision <= _latestRevision) {
      return false;
    }
    try {
      _latestRevision = state.revision;
      _tabsVisible = state.visible && state.active;
      _enabledTabs = _tabsVisible
          ? {
              for (final tab in state.tabs)
                if (tab.enabled) tab.id
            }
          : const {};
      _searchVisible = state.visible && state.active && state.searchVisible;
      _detailActions = state.active && state.detail != null
          ? state.detail!.enabledActions
          : const {};
      await _channel.invokeMethod<void>('setPresentation', state.toMap());
      return true;
    } on MissingPluginException {
      _clearFailedRevision(state.revision);
      return false;
    } on PlatformException {
      _clearFailedRevision(state.revision);
      return false;
    }
  }

  void _clearFailedRevision(int revision) {
    if (revision != _latestRevision) return;
    _tabsVisible = false;
    _enabledTabs = const {};
    _searchVisible = false;
    _detailActions = const {};
  }

  void listenForIntents() {
    if (!_isIOS || _disposed || _capabilities?.nativeChromeAvailable != true) {
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'selectIntent' && call.method != 'actionIntent') {
        return;
      }
      final args = call.arguments;
      if (args is! Map) return;
      final id = args['id'];
      final revision = args['revision'];
      if (id is String && revision is int && revision == _latestRevision) {
        if (call.method == 'selectIntent' &&
            _tabsVisible &&
            _enabledTabs.contains(id)) {
          onSelectIntent?.call(id, revision);
        } else if (call.method == 'actionIntent' &&
            id == 'search' &&
            _searchVisible) {
          onActionIntent?.call(id, revision);
        } else if (call.method == 'actionIntent' &&
            _detailActions.contains(id)) {
          onActionIntent?.call(id, revision);
        }
      }
    });
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    onSelectIntent = null;
    onActionIntent = null;
    if (!_isIOS) return;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod<void>('dispose');
    } on MissingPluginException {
      // Existing Flutter chrome remains the safe fallback.
    } on PlatformException {
      // Existing Flutter chrome remains the safe fallback.
    }
  }
}
