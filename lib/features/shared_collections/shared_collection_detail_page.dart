import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/media_item.dart';
import '../../core/shared_collections/shared_collections_service.dart';
import '../../l10n/nova_strings.dart';
import '../../shared/widgets/nova_network_image.dart';
import '../media/media_detail_page.dart';
import 'shared_collection_control_page.dart';
import 'shared_collections_panel.dart';

class SharedCollectionDetailPage extends StatefulWidget {
  const SharedCollectionDetailPage({
    super.key,
    required this.collectionId,
    this.service,
  });

  final String collectionId;
  final SharedCollectionsService? service;

  @override
  State<SharedCollectionDetailPage> createState() =>
      _SharedCollectionDetailPageState();
}

class _SharedCollectionDetailPageState extends State<SharedCollectionDetailPage>
    with WidgetsBindingObserver {
  late final SharedCollectionsService _service;
  RealtimeChannel? _channel;
  SharedCollection? _collection;
  List<CollectionItem> _items = const [];
  List<CollectionMember> _members = const [];
  bool _loading = true;
  bool _busy = false;
  Object? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service =
        widget.service ?? SharedCollectionsService(Supabase.instance.client);
    _channel =
        _service.watchCollection(widget.collectionId, () => unawaited(_load()));
    unawaited(_load());
  }

  @override
  void dispose() {
    _loadGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    if (_channel case final channel?) {
      unawaited(_service.unwatchCollection(channel));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final results = await Future.wait<Object?>([
        _service.getCollection(widget.collectionId),
        _service.listItems(widget.collectionId),
        _service.listMembers(widget.collectionId),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _collection = results[0] as SharedCollection?;
        _items = results[1] as List<CollectionItem>;
        _members = results[2] as List<CollectionMember>;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  CollectionPermissions? get _permissions {
    final accountId = _service.currentUserId;
    for (final member in _members) {
      if (member.accountId == accountId) return member.permissions;
    }
    return null;
  }

  bool get _isOwner => _collection?.ownerId == _service.currentUserId;

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
      await _load();
    } on SharedCollectionConflictException {
      if (mounted) _showMessage(NovaStrings.of(context).text('sharedConflict'));
      await _load();
    } catch (_) {
      if (mounted) {
        _showMessage(NovaStrings.of(context).text('sharedSaveFailed'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addItem() async {
    final draft = await showSharedCollectionItemForm(context);
    if (draft == null || !mounted) return;
    await _run(() async {
      await _service.addItem(
        collectionId: widget.collectionId,
        mediaId: null,
        mediaType: draft.$2,
        title: draft.$1,
      );
    });
  }

  Future<void> _editItem(CollectionItem item) async {
    final draft = await showSharedCollectionItemForm(
      context,
      title: item.title,
      mediaType: item.mediaType,
    );
    if (draft == null || !mounted) return;
    await _run(() async {
      await _service.updateItem(
        id: item.id,
        expectedVersion: item.version,
        title: draft.$1,
        mediaType: draft.$2,
        mediaId: item.mediaId,
        posterUrl: item.posterUrl,
      );
    });
  }

  Future<void> _deleteItem(CollectionItem item) async {
    if (!await _confirm(context, 'sharedDeleteItemQuestion')) return;
    if (!mounted) return;
    await _run(() async {
      await _service.deleteItem(id: item.id, expectedVersion: item.version);
    });
  }

  Future<void> _editCollection() async {
    final collection = _collection;
    if (collection == null) return;
    final draft = await showSharedCollectionForm(
      context,
      initialName: collection.name,
      initialDescription: collection.description,
    );
    if (draft == null || !mounted) return;
    await _run(() async {
      await _service.updateCollection(
        id: collection.id,
        name: draft.$1,
        description: draft.$2 ?? '',
        expectedVersion: collection.version,
      );
    });
  }

  Future<void> _deleteCollection() async {
    if (!await _confirm(context, 'sharedDeleteCollectionQuestion')) return;
    if (!mounted) return;
    try {
      await _service.deleteCollection(widget.collectionId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        _showMessage(NovaStrings.of(context).text('sharedSaveFailed'));
      }
    }
  }

  Future<void> _leaveCollection() async {
    if (!await _confirm(context, 'sharedLeaveQuestion',
        actionKey: 'sharedLeave')) {
      return;
    }
    if (!mounted) return;
    final accountId = _service.currentUserId;
    if (accountId == null) return;
    try {
      await _service.removeMember(
        collectionId: widget.collectionId,
        accountId: accountId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        _showMessage(NovaStrings.of(context).text('sharedSaveFailed'));
      }
    }
  }

  Future<void> _openControls() async {
    final deleted =
        await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => SharedCollectionControlPage(
        collectionId: widget.collectionId,
        service: _service,
      ),
    ));
    if (!mounted) return;
    if (deleted == true) {
      Navigator.of(context).pop();
    } else {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = NovaStrings.of(context);
    final collection = _collection;
    final scheme = Theme.of(context).colorScheme;
    final canAdd = _isOwner || (_permissions?.addItems ?? false);
    final canEdit = _isOwner || (_permissions?.editItems ?? false);
    final canDelete = _isOwner || (_permissions?.deleteItems ?? false);
    return Scaffold(
      appBar: AppBar(
        title: Text(collection?.name ?? strings.text('sharedCollections')),
        actions: [
          if (_isOwner ||
              (_permissions?.manageInvites ?? false) ||
              (_permissions?.manageMembers ?? false))
            IconButton(
              tooltip: strings.text('sharedOwnerControls'),
              onPressed: _openControls,
              icon: const Icon(LucideIcons.settings2),
            ),
          if (collection != null)
            PopupMenuButton<String>(
              tooltip: strings.text('more'),
              onSelected: (action) {
                if (action == 'edit') unawaited(_editCollection());
                if (action == 'delete') unawaited(_deleteCollection());
                if (action == 'leave') unawaited(_leaveCollection());
              },
              itemBuilder: (_) => [
                if (_isOwner) ...[
                  PopupMenuItem(
                      value: 'edit',
                      child: Text(strings.text('sharedEditCollection'))),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text(strings.text('sharedDeleteCollection'))),
                ] else
                  PopupMenuItem(
                      value: 'leave', child: Text(strings.text('sharedLeave'))),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || collection == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(strings.text('sharedUnavailable')),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: _load, child: Text(strings.text('retry'))),
                ]))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                          16,
                          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                          48),
                      children: [
                        if (collection.description.isNotEmpty) ...[
                          Text(collection.description,
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 16),
                        ],
                        Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(LucideIcons.usersRound,
                                    size: 18, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Text(strings.text('sharedMemberCount',
                                    {'count': _members.length})),
                              ]),
                              if (canAdd)
                                FilledButton.icon(
                                  onPressed: _busy ? null : _addItem,
                                  icon: const Icon(LucideIcons.plus),
                                  label: Text(strings.text('sharedAddItem')),
                                ),
                            ]),
                        const SizedBox(height: 16),
                        if (_items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Column(children: [
                              Icon(LucideIcons.film,
                                  size: 48, color: scheme.onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text(strings.text('sharedNoItems'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text(strings.text('sharedNoItemsDescription'),
                                  textAlign: TextAlign.center),
                            ]),
                          )
                        else
                          for (final item in _items) ...[
                            _CollectionItemRow(
                              item: item,
                              addedBy: item.addedByName.isEmpty ||
                                      item.addedByName == 'Member'
                                  ? strings.text('sharedUnnamedMember')
                                  : item.addedByName,
                              canEdit: canEdit,
                              canDelete: canDelete,
                              busy: _busy,
                              onEdit: () => _editItem(item),
                              onDelete: () => _deleteItem(item),
                            ),
                            const Divider(height: 1),
                          ],
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _CollectionItemRow extends StatelessWidget {
  const _CollectionItemRow({
    required this.item,
    required this.addedBy,
    required this.canEdit,
    required this.canDelete,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final CollectionItem item;
  final String? addedBy;
  final bool canEdit;
  final bool canDelete;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = NovaStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mediaItem = item.mediaId == null
        ? null
        : MediaItem(
            id: item.mediaId!,
            type: item.mediaType == 'movie' ? 'movie' : 'series',
            name: item.title,
            poster: item.posterUrl,
          );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 80,
      leading: SizedBox(
        width: 48,
        height: 64,
        child: item.posterUrl == null
            ? ColoredBox(
                color: scheme.surfaceContainerHigh,
                child: Icon(LucideIcons.film, color: scheme.primary),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: NovaNetworkImage(
                  item.posterUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: scheme.surfaceContainerHigh,
                    child: Icon(LucideIcons.film, color: scheme.primary),
                  ),
                ),
              ),
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        strings.text('sharedType${switch (item.mediaType) {
          'anime' => 'Anime',
          'series' => 'Series',
          _ => 'Movie',
        }}'),
        if (addedBy != null) strings.text('sharedAddedBy', {'name': addedBy}),
      ].join(' · ')),
      onTap: mediaItem == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => MediaDetailPage(item: mediaItem),
              )),
      trailing: canEdit || canDelete
          ? PopupMenuButton<String>(
              tooltip: strings.text('more'),
              enabled: !busy,
              onSelected: (action) {
                if (action == 'edit') onEdit();
                if (action == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                if (canEdit)
                  PopupMenuItem(
                      value: 'edit', child: Text(strings.text('edit'))),
                if (canDelete)
                  PopupMenuItem(
                      value: 'delete', child: Text(strings.text('delete'))),
              ],
            )
          : null,
    );
  }
}

Future<(String, String)?> showSharedCollectionItemForm(
  BuildContext context, {
  String? title,
  String mediaType = 'movie',
}) async {
  final strings = NovaStrings.of(context);
  var enteredTitle = title ?? '';
  final formKey = GlobalKey<FormState>();
  var selected = mediaType;
  return showDialog<(String, String)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        scrollable: true,
        title: Text(
            strings.text(title == null ? 'sharedAddItem' : 'sharedEditItem')),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: (MediaQuery.sizeOf(dialogContext).width - 128)
                .clamp(0.0, 420.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                initialValue: title,
                onChanged: (value) => enteredTitle = value,
                autofocus: true,
                maxLength: 200,
                decoration:
                    InputDecoration(labelText: strings.text('sharedItemTitle')),
                validator: (value) => value == null || value.trim().isEmpty
                    ? strings.text('sharedNameRequired')
                    : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selected,
                decoration:
                    InputDecoration(labelText: strings.text('sharedItemType')),
                items: [
                  DropdownMenuItem(
                      value: 'movie',
                      child: Text(strings.text('sharedTypeMovie'))),
                  DropdownMenuItem(
                      value: 'series',
                      child: Text(strings.text('sharedTypeSeries'))),
                  DropdownMenuItem(
                      value: 'anime',
                      child: Text(strings.text('sharedTypeAnime'))),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => selected = value);
                },
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.text('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, (enteredTitle.trim(), selected));
            },
            child: Text(strings.text('save')),
          ),
        ],
      ),
    ),
  );
}

Future<bool> _confirm(BuildContext context, String messageKey,
    {String actionKey = 'delete'}) async {
  final strings = NovaStrings.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.text(messageKey)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(strings.text('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(strings.text(actionKey)),
            ),
          ],
        ),
      ) ??
      false;
}
