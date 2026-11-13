import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Relay addresses are origins, never credential-bearing URLs. A custom relay
/// gets a short-lived, origin-bound capability rather than the account JWT.
Uri normalizeWatchPartyRelayEndpoint(String value) {
  final uri = Uri.tryParse(value.trim());
  final host = uri?.host.toLowerCase() ?? '';
  if (uri == null ||
      !const ['https', 'wss'].contains(uri.scheme.toLowerCase()) ||
      host.isEmpty ||
      !host.contains('.') ||
      InternetAddress.tryParse(host) != null ||
      host == 'localhost' ||
      const ['.localhost', '.local', '.internal', '.test', '.invalid']
          .any(host.endsWith) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      (uri.hasPort && uri.port != 443)) {
    throw const FormatException('A public HTTPS relay origin is required.');
  }
  return Uri(scheme: 'https', host: host);
}

class WatchPartyRelayHealth {
  const WatchPartyRelayHealth({required this.version, required this.latencyMs});
  final int version, latencyMs;
}

class WatchPartyRelaySettings extends ChangeNotifier {
  WatchPartyRelaySettings({SharedPreferences? preferences, this.canChange})
      : _preferences = preferences;
  static const _endpointKey = 'nova.watch-party.relay.endpoint';
  static const _enabledKey = 'nova.watch-party.relay.enabled';
  SharedPreferences? _preferences;
  final bool Function()? canChange;
  String? _endpoint;
  bool _enabled = false;
  bool _changing = false, _disposed = false;
  String? get endpoint => _endpoint;
  bool get configured => _endpoint != null;
  bool get enabled => _enabled && configured;
  bool get changing => _changing;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    if (_disposed) return;
    final saved = prefs.getString(_endpointKey);
    try {
      _endpoint = saved == null
          ? null
          : normalizeWatchPartyRelayEndpoint(saved).toString();
    } on FormatException {
      _endpoint = null;
    }
    _enabled = prefs.getBool(_enabledKey) == true && configured;
    _notify();
  }

  void _checkChange() {
    if (_disposed) throw StateError('Relay settings are closed.');
    if (canChange?.call() == false) {
      throw StateError('Leave the active room before changing its relay.');
    }
  }

  void _startChange() {
    _checkChange();
    if (_changing) throw StateError('Relay settings are changing.');
    _changing = true;
    // Scope temporarily makes entry unavailable before asynchronous preference
    // writes, so joining a room cannot race switching its transport underneath it.
    _notify();
  }

  Future<void> configure(String endpoint) async {
    final normalized = normalizeWatchPartyRelayEndpoint(endpoint).toString();
    _startChange();
    try {
      final prefs = _preferences ??= await SharedPreferences.getInstance();
      _checkChange();
      await prefs.setString(_endpointKey, normalized);
      await prefs.setBool(_enabledKey, true);
      _endpoint = normalized;
      _enabled = true;
    } finally {
      _changing = false;
      _notify();
    }
  }

  Future<void> useSupabase() async {
    _startChange();
    try {
      final prefs = _preferences ??= await SharedPreferences.getInstance();
      _checkChange();
      await prefs.setBool(_enabledKey, false);
      _enabled = false;
    } finally {
      _changing = false;
      _notify();
    }
  }

  Future<void> reset() async {
    _startChange();
    try {
      final prefs = _preferences ??= await SharedPreferences.getInstance();
      _checkChange();
      await prefs.remove(_endpointKey);
      await prefs.remove(_enabledKey);
      _enabled = false;
      _endpoint = null;
    } finally {
      _changing = false;
      _notify();
    }
  }

  /// This checks public protocol compatibility, not account authorization or a
  /// working room. It deliberately sends no account/capability credentials.
  Future<WatchPartyRelayHealth> check({String? endpoint}) async {
    final base = normalizeWatchPartyRelayEndpoint(endpoint ?? _endpoint ?? '');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final clock = Stopwatch()..start();
    try {
      final request = await client.getUrl(base.resolve('/health'));
      request.followRedirects = false;
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw const FormatException('Relay unavailable');
      }
      final bytes = await response.fold<List<int>>(<int>[], (bytes, chunk) {
        if (bytes.length + chunk.length > 4096) {
          throw const FormatException('Invalid relay health');
        }
        return bytes..addAll(chunk);
      }).timeout(const Duration(seconds: 8));
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map ||
          data['protocol'] != 'nova-watch-party' ||
          data['version'] != 1 ||
          data['ok'] != true) {
        throw const FormatException('Incompatible relay protocol');
      }
      return WatchPartyRelayHealth(
          version: 1, latencyMs: clock.elapsedMilliseconds);
    } finally {
      client.close(force: true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
