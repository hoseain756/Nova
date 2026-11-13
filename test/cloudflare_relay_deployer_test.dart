import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/watch_party/cloudflare_relay_deployer.dart';

void main() {
  const account = '0123456789abcdef0123456789abcdef';
  const name = 'nova-relay';
  const token = 'test-account-token';
  late Dio api;
  late CloudflareRelayDeployer deployer;
  late List<RequestOptions> requests;
  late List<Uri> verified;
  Map<String, dynamic>? settings;
  String? subdomain;
  setUp(() {
    requests = [];
    verified = [];
    settings = null;
    subdomain = null;
    api = Dio();
    api.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      expect(request.uri.host, 'api.cloudflare.com');
      expect(request.followRedirects, isFalse);
      expect(request.headers['Authorization'], 'Bearer $token');
      requests.add(request);
      var code = 200;
      Object? result;
      final path = request.uri.path;
      if (path.endsWith('/accounts')) {
        result = [
          {'id': account, 'name': 'NOVA test'}
        ];
      } else if (path.endsWith('/settings')) {
        if (settings == null) code = 404;
        result = settings;
      } else if (path.endsWith('/workers/subdomain')) {
        if (request.method == 'PUT') {
          subdomain = (request.data as Map)['subdomain'];
        }
        result = {'subdomain': subdomain};
      }
      handler.resolve(Response(
          requestOptions: request,
          statusCode: code,
          data: {'success': code == 200, 'result': result}));
    }));
    deployer = CloudflareRelayDeployer(
        api: api,
        loadWorker: () async => 'export default {}',
        verify: (endpoint) async => verified.add(endpoint));
  });
  tearDown(() => api.close());
  test('provisions selected account, SQLite namespace and public route',
      () async {
    expect((await deployer.listAccounts(token)).single.id, account);
    final endpoint = await deployer.deploy(
        token: token,
        accountId: account,
        workerName: name,
        subdomain: 'party-test');
    expect(endpoint.origin, 'https://nova-relay.party-test.workers.dev');
    expect(verified, [endpoint]);
    expect(requests.where((r) => r.method == 'PUT').length, 2);
    final upload =
        requests.singleWhere((r) => r.data is FormData).data as FormData;
    final parts = upload.files;
    expect(parts.map((p) => p.key), ['metadata', 'worker.mjs']);
    final metadata =
        jsonDecode(await utf8.decodeStream(parts.first.value.finalize()))
            as Map;
    expect(metadata['migrations']['new_sqlite_classes'], ['NovaPartyRoom']);
    expect(metadata['bindings'].toString(), isNot(contains(token)));
    expect(requests.last.uri.path, endsWith('/scripts/$name/subdomain'));
  });
  test('upgrades owned Worker without recreating durable namespace', () async {
    subdomain = 'party-test';
    settings = {
      'bindings': [
        {
          'type': 'durable_object_namespace',
          'name': 'ROOMS',
          'class_name': 'NovaPartyRoom'
        }
      ]
    };
    await deployer.deploy(token: token, accountId: account, workerName: name);
    final upload =
        requests.singleWhere((r) => r.data is FormData).data as FormData;
    final metadata =
        jsonDecode(await utf8.decodeStream(upload.files.first.value.finalize()))
            as Map;
    expect(metadata.containsKey('migrations'), isFalse);
  });
  test('unrelated existing worker is protected for deploy and delete',
      () async {
    settings = {'bindings': []};
    for (final action in [
      () => deployer.deploy(token: token, accountId: account, workerName: name),
      () => deployer.remove(token: token, accountId: account, workerName: name)
    ]) {
      await expectLater(
          action(),
          throwsA(isA<CloudflareRelayDeployException>().having(
              (e) => e.messageKey, 'key', 'partyRelayDeployCollision')));
    }
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });
}
