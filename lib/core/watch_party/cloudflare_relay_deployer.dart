import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../auth/nova_backend_config.dart';
import 'watch_party_relay_settings.dart';

class CloudflareRelayAccount {
  const CloudflareRelayAccount(this.id, this.name);
  final String id, name;
}

class CloudflareRelayDeployException implements Exception {
  const CloudflareRelayDeployException(this.messageKey);
  final String messageKey;
}

/// Cloudflare management tokens are supplied per call and never retained.
/// Health requests use a separate, unauthenticated HTTP client.
class CloudflareRelayDeployer {
  CloudflareRelayDeployer(
      {Dio? api,
      Future<String> Function()? loadWorker,
      Future<void> Function(Uri)? verify})
      : _api = api ??
            Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 35),
                receiveTimeout: const Duration(seconds: 30))),
        _loadWorker = loadWorker ??
            (() =>
                rootBundle.loadString('cloudflare/watch-party/src/worker.mjs')),
        _verify = verify ?? _verifyPublicEndpoint;
  static const _base = 'https://api.cloudflare.com/client/v4';
  static final _id = RegExp(r'^[0-9a-f]{32}$');
  static final _label = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
  final Dio _api;
  final Future<String> Function() _loadWorker;
  final Future<void> Function(Uri) _verify;

  static Future<void> _verifyPublicEndpoint(Uri endpoint) async {
    final settings = WatchPartyRelaySettings();
    try {
      for (var attempt = 0;; attempt++) {
        try {
          await settings.check(endpoint: endpoint.origin);
          return;
        } catch (_) {
          if (attempt >= 3) {
            throw const CloudflareRelayDeployException(
                'partyRelayDeployPending');
          }
          await Future<void>.delayed(Duration(seconds: 1 << attempt));
        }
      }
    } finally {
      settings.dispose();
    }
  }

  String _accountPath(String accountId) {
    if (!_id.hasMatch(accountId)) {
      throw const CloudflareRelayDeployException('partyRelayDeployAccount');
    }
    return '/accounts/$accountId/workers';
  }

  String _workerPath(String accountId, String workerName) {
    if (!_label.hasMatch(workerName)) {
      throw const CloudflareRelayDeployException('partyRelayDeployName');
    }
    return '${_accountPath(accountId)}/scripts/$workerName';
  }

  Future<Map?> _request(String token, String method, String path,
      {Object? body,
      bool allowMissing = false,
      String errorKey = 'partyRelayDeployFailed'}) async {
    if (token.trim().isEmpty || token.contains(RegExp(r'[\r\n]'))) {
      throw const CloudflareRelayDeployException('partyRelayDeployToken');
    }
    try {
      final response = await _api.request<Object?>('$_base$path',
          data: body,
          options: Options(
              method: method,
              followRedirects: false,
              headers: {'Authorization': 'Bearer ${token.trim()}'},
              validateStatus: (_) => true));
      final data = response.data;
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const CloudflareRelayDeployException('partyRelayDeployToken');
      }
      if (allowMissing && response.statusCode == 404) return null;
      if (response.statusCode == null ||
          response.statusCode! ~/ 100 != 2 ||
          data is! Map ||
          data['success'] != true) {
        throw CloudflareRelayDeployException(errorKey);
      }
      return data;
    } on DioException {
      // Dio errors include request options; never expose the Authorization header.
      throw CloudflareRelayDeployException(errorKey);
    }
  }

  Future<List<CloudflareRelayAccount>> listAccounts(String token) async {
    final accounts = <CloudflareRelayAccount>[];
    for (var page = 1;; page++) {
      final data =
          await _request(token, 'GET', '/accounts?per_page=50&page=$page');
      final rows = data?['result'];
      if (rows is! List) {
        throw const CloudflareRelayDeployException('partyRelayDeployAccount');
      }
      for (final row in rows.whereType<Map>()) {
        if (row['id'] is String && _id.hasMatch(row['id'])) {
          accounts.add(CloudflareRelayAccount(
              row['id'], row['name']?.toString() ?? row['id']));
        }
      }
      final info = data?['result_info'];
      if (rows.isEmpty ||
          info is! Map ||
          page >= (info['total_pages'] as num? ?? 1)) {
        break;
      }
    }
    return accounts;
  }

  Future<String?> workersSubdomain(
      {required String token, required String accountId}) async {
    final response = await _request(
        token, 'GET', '${_accountPath(accountId)}/subdomain',
        allowMissing: true, errorKey: 'partyRelayDeploySubdomain');
    final result = response?['result'];
    final name = result is Map ? result['subdomain'] : null;
    return name is String && _label.hasMatch(name) ? name : null;
  }

  Future<bool> status(
      {required String token,
      required String accountId,
      required String workerName}) async {
    final response = await _request(
        token, 'GET', '${_workerPath(accountId, workerName)}/settings',
        allowMissing: true);
    if (response == null) return false;
    final data = response['result'];
    final bindings = data is Map ? data['bindings'] : null;
    if (bindings is! List ||
        !bindings.whereType<Map>().any((b) =>
            b['type'] == 'durable_object_namespace' &&
            b['name'] == 'ROOMS' &&
            b['class_name'] == 'NovaPartyRoom')) {
      throw const CloudflareRelayDeployException('partyRelayDeployCollision');
    }
    return true;
  }

  Future<Uri> deploy(
      {required String token,
      required String accountId,
      required String workerName,
      String? subdomain}) async {
    final script = _workerPath(accountId, workerName);
    final exists = await status(
        token: token, accountId: accountId, workerName: workerName);
    var address = await workersSubdomain(token: token, accountId: accountId);
    if (address == null) {
      if (subdomain == null || !_label.hasMatch(subdomain)) {
        throw const CloudflareRelayDeployException('partyRelayDeploySubdomain');
      }
      await _request(token, 'PUT', '${_accountPath(accountId)}/subdomain',
          body: {'subdomain': subdomain},
          errorKey: 'partyRelayDeploySubdomain');
      address = subdomain;
    }
    final endpoint = Uri.https('$workerName.$address.workers.dev');
    final metadata = {
      'main_module': 'worker.mjs',
      'compatibility_date': '2026-07-30',
      'bindings': [
        {
          'type': 'durable_object_namespace',
          'name': 'ROOMS',
          'class_name': 'NovaPartyRoom'
        },
        for (final entry in {
          'NOVA_SUPABASE_URL': novaSupabaseUrl,
          'NOVA_SUPABASE_PUBLIC_KEY': novaSupabasePublishableKey,
          'NOVA_RELAY_ORIGIN': endpoint.origin
        }.entries)
          {'type': 'plain_text', 'name': entry.key, 'text': entry.value}
      ],
      if (!exists)
        'migrations': {
          'new_tag': 'v1',
          'new_sqlite_classes': ['NovaPartyRoom']
        },
    };
    final upload = FormData();
    upload.files.addAll([
      MapEntry(
          'metadata',
          MultipartFile.fromString(jsonEncode(metadata),
              contentType: DioMediaType.parse('application/json'))),
      MapEntry(
          'worker.mjs',
          MultipartFile.fromString(await _loadWorker(),
              filename: 'worker.mjs',
              contentType:
                  DioMediaType.parse('application/javascript+module'))),
    ]);
    await _request(token, 'PUT', script, body: upload);
    await _request(token, 'POST', '$script/subdomain', body: {'enabled': true});
    await _verify(endpoint);
    return endpoint;
  }

  Future<void> remove(
      {required String token,
      required String accountId,
      required String workerName}) async {
    if (await status(
        token: token, accountId: accountId, workerName: workerName)) {
      await _request(token, 'DELETE', _workerPath(accountId, workerName));
    }
  }
}
