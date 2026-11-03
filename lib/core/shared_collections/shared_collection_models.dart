/// Server-backed collections are account scoped, unlike the local profile lists.
class CollectionPermissions {
  const CollectionPermissions({
    required this.view,
    required this.addItems,
    required this.editItems,
    required this.deleteItems,
    required this.manageMembers,
    required this.manageInvites,
  });

  const CollectionPermissions.memberDefaults()
      : view = true,
        addItems = true,
        editItems = false,
        deleteItems = false,
        manageMembers = false,
        manageInvites = false;

  const CollectionPermissions.owner()
      : view = true,
        addItems = true,
        editItems = true,
        deleteItems = true,
        manageMembers = true,
        manageInvites = true;

  final bool view;
  final bool addItems;
  final bool editItems;
  final bool deleteItems;
  final bool manageMembers;
  final bool manageInvites;

  factory CollectionPermissions.fromJson(Map<String, dynamic> json) =>
      CollectionPermissions(
        view: json['can_view'] as bool? ?? false,
        addItems: json['can_add'] as bool? ?? false,
        editItems: json['can_edit'] as bool? ?? false,
        deleteItems: json['can_delete'] as bool? ?? false,
        manageMembers: json['can_manage_members'] as bool? ?? false,
        manageInvites: json['can_manage_invites'] as bool? ?? false,
      );

  CollectionPermissions copyWith({
    bool? view,
    bool? addItems,
    bool? editItems,
    bool? deleteItems,
    bool? manageMembers,
    bool? manageInvites,
  }) =>
      CollectionPermissions(
        view: view ?? this.view,
        addItems: addItems ?? this.addItems,
        editItems: editItems ?? this.editItems,
        deleteItems: deleteItems ?? this.deleteItems,
        manageMembers: manageMembers ?? this.manageMembers,
        manageInvites: manageInvites ?? this.manageInvites,
      );

  Map<String, bool> toRpcParams() => {
        'p_can_view': view,
        'p_can_add': addItems,
        'p_can_edit': editItems,
        'p_can_delete': deleteItems,
        'p_can_manage_members': manageMembers,
        'p_can_manage_invites': manageInvites,
      };
}

class SharedCollection {
  const SharedCollection({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SharedCollection.fromJson(Map<String, dynamic> json) =>
      SharedCollection(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        version: (json['version'] as num).toInt(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class CollectionMember {
  const CollectionMember({
    required this.accountId,
    required this.username,
    required this.role,
    required this.permissions,
    required this.joinedAt,
  });

  final String accountId;
  final String? username;
  final String role;
  final CollectionPermissions permissions;
  final DateTime joinedAt;

  bool get isOwner => role == 'owner';

  factory CollectionMember.fromJson(Map<String, dynamic> json) =>
      CollectionMember(
        accountId: json['account_id'] as String,
        username: json['username'] as String?,
        role: json['role'] as String,
        permissions: CollectionPermissions.fromJson(json),
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );
}

class CollectionItem {
  const CollectionItem({
    required this.id,
    required this.collectionId,
    required this.mediaType,
    required this.mediaId,
    required this.title,
    required this.posterUrl,
    required this.addedBy,
    required this.addedByName,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String collectionId;
  final String mediaType;
  final String? mediaId;
  final String title;
  final String? posterUrl;
  final String addedBy;
  final String addedByName;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CollectionItem.fromJson(Map<String, dynamic> json) => CollectionItem(
        id: json['id'] as String,
        collectionId: json['collection_id'] as String,
        mediaType: json['media_type'] as String,
        mediaId: json['media_id'] as String?,
        title: json['title'] as String,
        posterUrl: json['poster_url'] as String?,
        addedBy: json['added_by'] as String,
        addedByName: json['added_by_name'] as String? ?? '',
        version: (json['version'] as num).toInt(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
