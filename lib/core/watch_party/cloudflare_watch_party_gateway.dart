import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'watch_party_relay_settings.dart';
import 'watch_party_service.dart';

typedef WatchPartyRelayPost = Future<Map<String, dynamic>> Function(
    Uri uri, String capability, Map<String, dynamic> body);
typedef WatchPartyRelayTicket = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> params);

/// Supabase authenticates only the dedicated capability issuance RPC. A fresh
/// independent HTTP/WebSocket client sends that opaque capability to the chosen
/// relay. Its headers can never inherit Supabase's account Authorization token.
class CloudflareWatchPartyGateway implements WatchPartyGateway {
  CloudflareWatchPartyGateway({
    required String endpoint,
    required SupabaseClient client,
    SharedPreferences? preferences,
    WatchPartyRelayPost? post,
    WatchPartyRelayTicket? issueTicket,
  })  : endpoint = normalizeWatchPartyRelayEndpoint(endpoint),
        _client = client,
        _preferences = preferences,
        _post = post ?? _postJson,
        _issueTicket = issueTicket;

  final Uri endpoint;
  final SupabaseClient _client;
  final WatchPartyRelayPost _post;
  final WatchPartyRelayTicket? _issueTicket;
  SharedPreferences? _preferences;
  Map<String, dynamic>? _ticket;
  Future<String>? _ticketPending;
  String? _scope, _code, _device, _profile;
  WebSocket? _socket;
  Timer? _retry;
  int _generation = 0, _attempt = 0, _identityGeneration = 0;

  String get _resumeKey =>
      'nova.watch-party.relay.resume.${sha256.convert(utf8.encode('$endpoint|$_scope'))}';

  Future<String> _capability() async {
    final cached = _ticket;
    if (cached != null &&
        (cached['expires_at_ms'] as num).toInt() >
            DateTime.now().millisecondsSinceEpoch + 30000) {
      return cached['token'] as String;
    }
    final pending = _ticketPending;
    if (pending != null) return pending;
    final issuing = _mintCapability();
    _ticketPending = issuing;
    try {
      return await issuing;
    } finally {
      if (identical(_ticketPending, issuing)) _ticketPending = null;
    }
  }

  Future<String> _mintCapability() async {
    final device = _device, profile = _profile;
    final generation = _identityGeneration;
    final params = <String, dynamic>{
      'p_device_id': device,
      'p_profile_id': profile,
      'p_relay_url': endpoint.toString(),
    };
    final data = _issueTicket != null
        ? await _issueTicket(params)
        : Map<String, dynamic>.from(await _client
            .rpc('nova_party_relay_ticket', params: params)
            .timeout(const Duration(seconds: 10)) as Map);
    final identity = data['identity'];
    final expiry = data['expires_at_ms'];
    if (data['token'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{32,128}$').hasMatch(data['token'] as String) ||
        expiry is! num ||
        expiry <= DateTime.now().millisecondsSinceEpoch ||
        identity is! Map ||
        identity['profile_id'] != profile ||
        identity['device_id'] != device ||
        identity['account_id'] is! String) {
      throw const FormatException('Invalid relay capability');
    }
    if (_device != device ||
        _profile != profile ||
        generation != _identityGeneration) {
      throw StateError('Relay account scope changed');
    }
    _ticket = data;
    _scope = '${identity['account_id']}|$_profile|$_device';
    return data['token'] as String;
  }

  @override
  Future<Map<String, dynamic>> request(Map<String, dynamic> params) async {
    if (_device != params['p_device_id'] ||
        _profile != params['p_profile_id']) {
      _ticket = null;
      _ticketPending = null;
      _identityGeneration++;
      _scope = null;
      _code = null;
      _device = params['p_device_id'] as String?;
      _profile = params['p_profile_id'] as String?;
    }
    final generation = _identityGeneration;
    final capability = await _capability();
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    if (generation != _identityGeneration) {
      throw StateError('Relay account scope changed');
    }
    final action = params['p_action'];
    if (action != 'create' && action != 'join' && _code == null) {
      _code = prefs.getString(_resumeKey);
    }
    if (action == 'resume' && _code == null) return {'snapshot': null};
    final result = await _post(endpoint.resolve('/rpc'), capability, {
      ...params,
      if (params['p_code'] == null && _code != null) 'p_code': _code,
    });
    if (generation != _identityGeneration) {
      throw StateError('Relay account scope changed');
    }
    final snapshot =
        result['snapshot'] is Map ? result['snapshot'] as Map : result;
    final room = snapshot['room'];
    if (room is Map && room['code'] is String && result['error'] == null) {
      _code = room['code'] as String;
      await prefs.setString(_resumeKey, _code!);
    }
    if ((action == 'leave' || action == 'end') && result['error'] == null ||
        const ['not_member', 'removed', 'ended', 'not_found']
            .contains(result['error'])) {
      _code = null;
      await prefs.remove(_resumeKey);
    }
    return result;
  }

  @override
  void subscribe(
      String memberId,
      void Function(String, Map<String, dynamic>) onEvent,
      void Function(bool) onStatus) {
    final generation = ++_generation;
    _retry?.cancel();
    final old = _socket;
    _socket = null;
    unawaited(old?.close());
    _attempt = 0;
    unawaited(_connect(generation, memberId, onEvent, onStatus));
  }

  Future<void> _connect(
      int generation,
      String memberId,
      void Function(String, Map<String, dynamic>) onEvent,
      void Function(bool) onStatus) async {
    if (generation != _generation || _code == null) return;
    void retry() {
      if (generation != _generation) return;
      onStatus(false);
      _retry?.cancel();
      final seconds = min(10, 1 << min(_attempt++, 3));
      _retry = Timer(Duration(seconds: seconds),
          () => unawaited(_connect(generation, memberId, onEvent, onStatus)));
    }

    try {
      final capability = await _capability();
      if (generation != _generation) return;
      final socket =
          await _openSocket(endpoint.resolve('/r/$_code'), capability);
      if (generation != _generation) {
        await socket.close();
        return;
      }
      _socket = socket;
      _attempt = 0;
      onStatus(true);
      socket.listen((frame) {
        if (generation != _generation ||
            frame is! String ||
            frame.length > 262144) {
          return;
        }
        try {
          final data = jsonDecode(frame);
          if (data is! Map || data['payload'] is! Map) return;
          final event = data['event'];
          final payload = Map<String, dynamic>.from(data['payload'] as Map);
          if (event == 'snapshot' && payload['self_member_id'] != memberId) {
            return;
          }
          if (const ['snapshot', 'chat', 'closed'].contains(event)) {
            onEvent(event as String, payload);
          }
        } catch (_) {/* A malformed relay frame cannot update trusted state. */}
      }, onDone: () {
        if (identical(_socket, socket)) _socket = null;
        if (socket.closeCode == 4001) _ticket = null;
        retry();
      }, onError: (_) => retry(), cancelOnError: true);
    } catch (_) {
      retry();
    }
  }

  @override
  Future<void> unsubscribe() async {
    ++_generation;
    ++_identityGeneration;
    _ticket = null;
    _ticketPending = null;
    _scope = null;
    _code = null;
    _retry?.cancel();
    _retry = null;
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }
}

Future<Map<String, dynamic>> _postJson(
    Uri uri, String capability, Map<String, dynamic> body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.postUrl(uri);
    request.followRedirects = false;
    request.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.authorizationHeader, 'Bearer $capability');
    request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw const HttpException('Relay request rejected');
    }
    final bytes = await response.fold<List<int>>(<int>[], (bytes, chunk) {
      if (bytes.length + chunk.length > 262144) {
        throw const FormatException('Relay response too large');
      }
      return bytes..addAll(chunk);
    }).timeout(const Duration(seconds: 10));
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
  } finally {
    client.close(force: true);
  }
}

/// Perform the upgrade ourselves so redirects are disabled before an opaque
/// capability is attached. WebSocket.connect otherwise uses HTTP redirect policy.
Future<WebSocket> _openSocket(Uri uri, String capability) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final nonce = base64Encode(
        List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $capability')
      ..set(HttpHeaders.connectionHeader, 'Upgrade')
      ..set(HttpHeaders.upgradeHeader, 'websocket')
      ..set('Sec-WebSocket-Key', nonce)
      ..set('Sec-WebSocket-Version', '13');
    final response = await request.close().timeout(const Duration(seconds: 10));
    final expected = base64Encode(sha1
        .convert(utf8.encode('${nonce}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
        .bytes);
    if (response.statusCode != 101 ||
        response.headers.value('Sec-WebSocket-Accept') != expected ||
        response.headers.value(HttpHeaders.upgradeHeader)?.toLowerCase() !=
            'websocket') {
      throw const HttpException('Relay websocket upgrade rejected');
    }
    return WebSocket.fromUpgradedSocket(await response.detachSocket(),
        serverSide: false);
  } finally {
    client.close(force: true);
  }
}
