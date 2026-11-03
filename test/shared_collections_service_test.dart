import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/shared_collections/shared_collections_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('create uses the server RPC and parses the returned collection',
      () async {
    final requests = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add({
        'path': request.uri.path,
        'body': jsonDecode(await utf8.decoder.bind(request).join()),
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_collectionRow));
      await request.response.close();
    });
    final client = _client(server);
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    final collection = await SharedCollectionsService(client).createCollection(
      name: 'Weekend picks',
      description: 'Together',
    );

    expect(collection.id, _collectionRow['id']);
    expect(collection.version, 1);
    expect(requests, [
      {
        'path': '/rest/v1/rpc/create_shared_collection',
        'body': {'p_name': 'Weekend picks', 'p_description': 'Together'},
      },
    ]);
  });

  test('a server revision conflict is surfaced for an item edit', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = HttpStatus.conflict;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'code': '40001',
        'message': 'revision_conflict',
        'details': null,
        'hint': null,
      }));
      await request.response.close();
    });
    final client = _client(server);
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    expect(
      () => SharedCollectionsService(client).updateItem(
        id: '22222222-2222-4222-8222-222222222222',
        expectedVersion: 2,
        mediaType: 'anime',
        title: 'Changed title',
        mediaId: null,
        posterUrl: null,
      ),
      throwsA(isA<SharedCollectionConflictException>()),
    );
  });

  test('add item records the contributor name supplied by the server',
      () async {
    Map<String, dynamic>? sent;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      sent = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_itemRow));
      await request.response.close();
    });
    final client = _client(server);
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    final item = await SharedCollectionsService(client).addItem(
      collectionId: _collectionRow['id'] as String,
      mediaType: 'anime',
      title: 'A Series',
    );

    expect(item.addedByName, 'weekend_fan');
    expect(sent?.containsKey('p_added_by'), isFalse);
    expect(sent?.containsKey('p_added_by_name'), isFalse);
    expect(sent?['p_media_id'], isNull);
  });

  test('member rows preserve owner role and permission values', () {
    final owner = CollectionMember.fromJson({
      'account_id': 'owner',
      'username': 'owner_name',
      'role': 'owner',
      'can_view': true,
      'can_add': true,
      'can_edit': true,
      'can_delete': true,
      'can_manage_members': true,
      'can_manage_invites': true,
      'joined_at': '2026-11-03T00:00:00Z',
    });
    expect(owner.isOwner, isTrue);
    expect(owner.permissions.manageMembers, isTrue);
    expect(const CollectionPermissions.memberDefaults().editItems, isFalse);
  });
}

SupabaseClient _client(HttpServer server) => SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
      accessToken: () async => 'test-token',
    );

final Map<String, dynamic> _collectionRow = {
  'id': '11111111-1111-4111-8111-111111111111',
  'owner_id': '22222222-2222-4222-8222-222222222222',
  'name': 'Weekend picks',
  'description': 'Together',
  'version': 1,
  'created_at': '2026-11-03T00:00:00Z',
  'updated_at': '2026-11-03T00:00:00Z',
};

final Map<String, dynamic> _itemRow = {
  'id': '33333333-3333-4333-8333-333333333333',
  'collection_id': _collectionRow['id'],
  'media_type': 'anime',
  'media_id': null,
  'title': 'A Series',
  'poster_url': null,
  'added_by': '22222222-2222-4222-8222-222222222222',
  'added_by_name': 'weekend_fan',
  'version': 1,
  'created_at': '2026-11-03T00:00:00Z',
  'updated_at': '2026-11-03T00:00:00Z',
};
