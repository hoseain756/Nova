import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova_mobile/core/watch_party/cloudflare_watch_party_gateway.dart';

const _account = '00000000-0000-4000-8000-000000000001';
const _profile = '00000000-0000-4000-8000-000000000002';
const _otherProfile = '00000000-0000-4000-8000-000000000003';
const _device = '00000000-0000-4000-8000-000000000004';
Map<String, dynamic> _params(String action, {String profile = _profile}) => {
      'p_action': action,
      'p_device_id': _device,
      'p_profile_id': profile,
    };
Map<String, dynamic> _ticket(Map<String, dynamic> params,
        {String account = _account}) =>
    {
      'token': 'a' * 64,
      'expires_at_ms': DateTime.now().millisecondsSinceEpoch + 600000,
      'identity': {
        'account_id': account,
        'profile_id': params['p_profile_id'],
        'device_id': params['p_device_id']
      },
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('custom relay receives an opaque origin-bound capability only',
      () async {
    final client =
        SupabaseClient('https://trusted.supabase.co', 'sb_publishable_test');
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? issuance;
    final gateway = CloudflareWatchPartyGateway(
        endpoint: 'wss://relay.example.com/',
        client: client,
        preferences: prefs,
        issueTicket: (params) async {
          issuance = params;
          return _ticket(params);
        },
        post: (uri, capability, body) async {
          expect(uri.toString(), 'https://relay.example.com/rpc');
          expect(capability, 'a' * 64);
          expect(capability.contains('.'), isFalse);
          expect(body.keys, isNot(contains('authorization')));
          return {
            'room': {'code': 'ABC234'}
          };
        });
    await gateway.request(_params('create'));
    expect(issuance, {
      'p_device_id': _device,
      'p_profile_id': _profile,
      'p_relay_url': 'https://relay.example.com'
    });
    await gateway.unsubscribe();
    await client.dispose();
  });

  test('restore keys isolate account, profile, device and relay origin',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final client =
        SupabaseClient('https://trusted.supabase.co', 'sb_publishable_test');
    final requests = <Map<String, dynamic>>[];
    var account = _account;
    final gateway = CloudflareWatchPartyGateway(
        endpoint: 'https://relay.example.com',
        client: client,
        preferences: prefs,
        issueTicket: (params) async => _ticket(params, account: account),
        post: (_, __, params) async {
          requests.add(params);
          return {
            'room': {'code': 'ABC234'}
          };
        });
    await gateway.request(_params('create'));
    final absent =
        await gateway.request(_params('resume', profile: _otherProfile));
    expect(absent['snapshot'], isNull);
    expect(requests, hasLength(1));
    await gateway.request(_params('resume'));
    expect(requests.last['p_code'], 'ABC234');
    await gateway.unsubscribe();
    account = '00000000-0000-4000-8000-000000000099';
    final otherAccount = await gateway.request(_params('resume'));
    expect(otherAccount['snapshot'], isNull);
    expect(requests, hasLength(2));
    await gateway.unsubscribe();
    await client.dispose();
  });

  test('identity reset invalidates cached and in-flight relay tickets',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final client =
        SupabaseClient('https://trusted.supabase.co', 'sb_publishable_test');
    final issuance = Completer<Map<String, dynamic>>();
    var calls = 0, posts = 0;
    final gateway = CloudflareWatchPartyGateway(
        endpoint: 'https://relay.example.com',
        client: client,
        preferences: prefs,
        issueTicket: (params) async {
          calls++;
          return calls == 1 ? issuance.future : _ticket(params);
        },
        post: (_, __, ___) async {
          posts++;
          return {
            'room': {'code': 'ABC234'}
          };
        });
    final first = gateway.request(_params('create'));
    final denied = expectLater(first, throwsStateError);
    await gateway.unsubscribe();
    issuance.complete(_ticket(_params('create')));
    await denied;
    expect(posts, 0);
    await gateway.request(_params('create'));
    expect(calls, 2);
    expect(posts, 1);
    await gateway.unsubscribe();
    await client.dispose();
  });

  test('concurrent commands coalesce capability issuance', () async {
    final prefs = await SharedPreferences.getInstance();
    final client =
        SupabaseClient('https://trusted.supabase.co', 'sb_publishable_test');
    final issuance = Completer<Map<String, dynamic>>();
    var calls = 0;
    final gateway = CloudflareWatchPartyGateway(
        endpoint: 'https://relay.example.com',
        client: client,
        preferences: prefs,
        issueTicket: (_) {
          calls++;
          return issuance.future;
        },
        post: (_, __, ___) async => {
              'room': {'code': 'ABC234'}
            });
    final a = gateway.request(_params('create'));
    final b = gateway.request(_params('snapshot'));
    expect(calls, 1);
    issuance.complete(_ticket(_params('create')));
    await Future.wait([a, b]);
    await gateway.unsubscribe();
    await client.dispose();
  });
}
