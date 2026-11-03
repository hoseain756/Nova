import 'package:supabase_flutter/supabase_flutter.dart';

import 'shared_collection_models.dart';

export 'shared_collection_models.dart';

/// An optimistic write was rejected because the row changed since it was read.
/// Reload the row before offering the user's edit again.
class SharedCollectionConflictException implements Exception {
  const SharedCollectionConflictException();
}

/// Account-scoped API for shared collections. Every write goes through an RPC
/// that checks the current Auth user and permissions inside one transaction.
class SharedCollectionsService {
  SharedCollectionsService(this._client);

  final SupabaseClient _client;
  int _nextChannel = 0;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<SharedCollection>> listCollections() async {
    final rows = await _client
        .from('shared_collections')
        .select('id,owner_id,name,description,version,created_at,updated_at')
        .order('updated_at', ascending: false);
    return rows.map(SharedCollection.fromJson).toList();
  }

  Future<SharedCollection?> getCollection(String id) async {
    final row = await _client
        .from('shared_collections')
        .select('id,owner_id,name,description,version,created_at,updated_at')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : SharedCollection.fromJson(row);
  }

  Future<List<CollectionItem>> listItems(String collectionId) async {
    final rows = await _client
        .from('shared_collection_items')
        .select()
        .eq('collection_id', collectionId)
        .order('created_at', ascending: false);
    return rows.map(CollectionItem.fromJson).toList();
  }

  Future<List<CollectionMember>> listMembers(String collectionId) async {
    final rows = await _client.rpc(
      'shared_collection_member_details',
      params: {'p_collection_id': collectionId},
    );
    return (rows as List)
        .map((row) => CollectionMember.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<SharedCollection> createCollection({
    required String name,
    String description = '',
  }) async {
    final row = await _client.rpc(
      'create_shared_collection',
      params: {'p_name': name, 'p_description': description},
    );
    return SharedCollection.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<SharedCollection> updateCollection({
    required String id,
    required String name,
    required int expectedVersion,
    String description = '',
  }) async {
    try {
      final row = await _client.rpc(
        'update_shared_collection',
        params: {
          'p_collection_id': id,
          'p_name': name,
          'p_description': description,
          'p_expected_version': expectedVersion,
        },
      );
      return SharedCollection.fromJson(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (error) {
      _rethrowConflict(error);
    }
  }

  Future<void> deleteCollection(String id) async {
    await _client.rpc(
      'delete_shared_collection',
      params: {'p_collection_id': id},
    );
  }

  /// Returns null when the invite is disabled. The raw token is available only
  /// through this owner/permission-checked RPC, never a public table read.
  Future<String?> getInviteToken(String collectionId) async {
    final token = await _client.rpc(
      'read_shared_collection_invite',
      params: {'p_collection_id': collectionId},
    );
    return token as String?;
  }

  Future<String> rotateInviteToken(String collectionId) async {
    final token = await _client.rpc(
      'rotate_shared_collection_invite',
      params: {'p_collection_id': collectionId},
    );
    return token as String;
  }

  Future<void> disableInvite(String collectionId) async {
    await _client.rpc(
      'disable_shared_collection_invite',
      params: {'p_collection_id': collectionId},
    );
  }

  /// Invite redemption is atomic; the server validates token and Auth user.
  Future<String> joinInvite(String token) async {
    final id = await _client.rpc(
      'join_shared_collection',
      params: {'p_token': token},
    );
    return id as String;
  }

  Future<String> joinCollection(String token) => joinInvite(token);

  Future<CollectionItem> addItem({
    required String collectionId,
    required String mediaType,
    required String title,
    String? mediaId,
    String? posterUrl,
  }) async {
    final row = await _client.rpc(
      'add_shared_collection_item',
      params: {
        'p_collection_id': collectionId,
        'p_media_type': mediaType,
        'p_title': title,
        'p_media_id': mediaId,
        'p_poster_url': posterUrl,
      },
    );
    return CollectionItem.fromJson(Map<String, dynamic>.from(row as Map));
  }

  /// Full-row edits use the caller's expected version. A concurrent edit is
  /// rejected by the RPC rather than silently overwritten.
  Future<CollectionItem> updateItem({
    required String id,
    required int expectedVersion,
    required String mediaType,
    required String title,
    required String? mediaId,
    required String? posterUrl,
  }) async {
    try {
      final row = await _client.rpc(
        'update_shared_collection_item',
        params: {
          'p_item_id': id,
          'p_expected_version': expectedVersion,
          'p_media_type': mediaType,
          'p_title': title,
          'p_media_id': mediaId,
          'p_poster_url': posterUrl,
        },
      );
      return CollectionItem.fromJson(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (error) {
      _rethrowConflict(error);
    }
  }

  Future<void> deleteItem({
    required String id,
    required int expectedVersion,
  }) async {
    try {
      await _client.rpc(
        'delete_shared_collection_item',
        params: {'p_item_id': id, 'p_expected_version': expectedVersion},
      );
    } on PostgrestException catch (error) {
      _rethrowConflict(error);
    }
  }

  Future<void> setMemberPermissions({
    required String collectionId,
    required String accountId,
    required CollectionPermissions permissions,
  }) async {
    await _client.rpc(
      'set_shared_collection_member_permissions',
      params: {
        'p_collection_id': collectionId,
        'p_account_id': accountId,
        ...permissions.toRpcParams(),
      },
    );
  }

  Future<void> removeMember({
    required String collectionId,
    required String accountId,
  }) async {
    await _client.rpc(
      'remove_shared_collection_member',
      params: {'p_collection_id': collectionId, 'p_account_id': accountId},
    );
  }

  /// Sync rows contain only an account ID and revision. On any signal, clients
  /// refetch RLS-scoped data; this also handles deletes and lost socket events.
  RealtimeChannel watchCollections(void Function() onChanged) {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('A signed-in account is required');
    }
    final channel = _client
        .channel('shared-collections:$userId:${_nextChannel++}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shared_collection_sync',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: userId,
          ),
          callback: (_) => onChanged(),
        );
    // A reconnect may skip events sent while the socket was down. Treat every
    // successful (re)subscription as an invalidation as well.
    channel.subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) onChanged();
    });
    return channel;
  }

  /// The account-wide revision covers all of this user's collections. The
  /// detail page refetches just [collectionId] when it receives a signal.
  RealtimeChannel watchCollection(
    String collectionId,
    void Function() onChanged,
  ) =>
      watchCollections(onChanged);

  Future<void> unwatchCollection(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }

  Never _rethrowConflict(PostgrestException error) {
    if (error.code == '40001') {
      throw const SharedCollectionConflictException();
    }
    throw error;
  }
}
