import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/shared_collections/shared_collections_service.dart';
import '../../l10n/nova_strings.dart';
import 'shared_collections_panel.dart';

class SharedCollectionControlPage extends StatefulWidget {
  const SharedCollectionControlPage({
    super.key,
    required this.collectionId,
    this.service,
  });

  final String collectionId;
  final SharedCollectionsService? service;

  @override
  State<SharedCollectionControlPage> createState() =>
      _SharedCollectionControlPageState();
}

class _SharedCollectionControlPageState
    extends State<SharedCollectionControlPage> with WidgetsBindingObserver {
  late final SharedCollectionsService _service;
  RealtimeChannel? _channel;
  SharedCollection? _collection;
  List<CollectionMember> _members = const [];
  String? _token;
  bool _owner = false;
  bool _loading = true;
  bool _busy = false;
  Object? _error;
  int _loadGeneration = 0;

  CollectionPermissions? get _selfPermissions => _members
      .where((member) => member.accountId == _service.currentUserId)
      .firstOrNull
      ?.permissions;

  bool get _canManageMembers =>
      _owner || (_selfPermissions?.manageMembers ?? false);

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
      final collection = await _service.getCollection(widget.collectionId);
      final members = await _service.listMembers(widget.collectionId);
      final me = members
          .where((member) => member.accountId == _service.currentUserId)
          .firstOrNull;
      final token = me?.permissions.manageInvites == true
          ? await _service.getInviteToken(widget.collectionId)
          : null;
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _collection = collection;
        _members = members;
        _token = token;
        _owner = collection?.ownerId == _service.currentUserId;
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

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } on SharedCollectionConflictException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(NovaStrings.of(context).text('sharedConflict')),
        ));
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(NovaStrings.of(context).text('sharedSaveFailed')),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final strings = NovaStrings.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(strings.text('sharedDeleteCollectionQuestion')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.text('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(strings.text('delete')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      await _service.deleteCollection(widget.collectionId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(strings.text('sharedSaveFailed')),
        ));
      }
    }
  }

  Future<void> _setPermission(
    CollectionMember member,
    CollectionPermissions permissions,
  ) {
    // A member without View cannot retain any other permission.
    final normalized = permissions.view
        ? permissions
        : const CollectionPermissions(
            view: false,
            addItems: false,
            editItems: false,
            deleteItems: false,
            manageMembers: false,
            manageInvites: false,
          );
    return _run(() => _service.setMemberPermissions(
          collectionId: widget.collectionId,
          accountId: member.accountId,
          permissions: normalized,
        ));
  }

  Future<void> _removeMember(CollectionMember member) async {
    final strings = NovaStrings.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(strings.text('sharedRemoveMemberQuestion')),
            content: Text(member.username ?? member.accountId),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.text('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(strings.text('sharedRemoveMember')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await _run(() => _service.removeMember(
          collectionId: widget.collectionId,
          accountId: member.accountId,
        ));
  }

  String get _link =>
      'app.nova.mobile://collection-invite?token=${_token ?? ''}';

  Future<void> _copyInvite() async {
    await Clipboard.setData(ClipboardData(text: _link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(NovaStrings.of(context).text('sharedInviteCopied')),
      ));
    }
  }

  Future<void> _shareInvite() async {
    try {
      await SharePlus.instance.share(ShareParams(text: _link));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(NovaStrings.of(context).text('sharedShareFailed')),
        ));
      }
    }
  }

  Future<void> _disableInvite() async {
    final strings = NovaStrings.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(strings.text('sharedDisableInviteQuestion')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.text('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(strings.text('sharedDisableInvite')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await _run(() => _service.disableInvite(widget.collectionId));
  }

  @override
  Widget build(BuildContext context) {
    final strings = NovaStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final canInvite = _owner || (_selfPermissions?.manageInvites ?? false);
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('sharedOwnerControls'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(strings.text('sharedLoadFailed')),
                  TextButton(
                      onPressed: _load, child: Text(strings.text('retry'))),
                ]))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: ListView(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                          16,
                          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                          48),
                      children: [
                        Semantics(
                            header: true,
                            child: Text(
                                _collection?.name ??
                                    strings.text('sharedCollections'),
                                style:
                                    Theme.of(context).textTheme.headlineLarge)),
                        const SizedBox(height: 12),
                        Text(strings.text('sharedMembersDescription'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                        const Divider(height: 48),
                        if (_owner) ...[
                          Text(strings.text('sharedCollectionSettings'),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _editCollection,
                              icon: const Icon(LucideIcons.pencil),
                              label: Text(strings.text('sharedEditCollection')),
                            ),
                            TextButton.icon(
                              onPressed: _busy ? null : _deleteCollection,
                              icon: const Icon(LucideIcons.trash2),
                              label:
                                  Text(strings.text('sharedDeleteCollection')),
                            ),
                          ]),
                          const SizedBox(height: 32),
                        ],
                        if (canInvite) ...[
                          Text(strings.text('sharedInviteLink'),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(strings.text('sharedInviteDescription'),
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 12),
                          if (_token == null)
                            Text(strings.text('sharedInviteDisabled'),
                                style: Theme.of(context).textTheme.bodyMedium)
                          else
                            SelectableText(_link,
                                textDirection: TextDirection.ltr,
                                style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            if (_token != null) ...[
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _copyInvite,
                                icon: const Icon(LucideIcons.copy),
                                label: Text(strings.text('sharedCopyInvite')),
                              ),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _shareInvite,
                                icon: const Icon(LucideIcons.share2),
                                label: Text(strings.text('sharedShareInvite')),
                              ),
                            ],
                            FilledButton.tonalIcon(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                        await _service.rotateInviteToken(
                                            widget.collectionId);
                                      }),
                              icon: const Icon(LucideIcons.rotateCw),
                              label: Text(strings.text(_token == null
                                  ? 'sharedEnableInvite'
                                  : 'sharedRegenerateInvite')),
                            ),
                            if (_token != null)
                              TextButton(
                                onPressed: _busy ? null : _disableInvite,
                                child:
                                    Text(strings.text('sharedDisableInvite')),
                              ),
                          ]),
                          const SizedBox(height: 32),
                        ],
                        Text(strings.text('sharedMembers'),
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(strings.text('sharedMembersDescription'),
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        for (final member in _members) ...[
                          ExpansionTile(
                            tilePadding: const EdgeInsetsDirectional.symmetric(
                                vertical: 12),
                            childrenPadding:
                                const EdgeInsetsDirectional.fromSTEB(
                                    8, 0, 8, 16),
                            leading: Icon(
                              member.isOwner
                                  ? LucideIcons.crown
                                  : LucideIcons.userRound,
                              color: member.isOwner
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                            title: Text(member.username ?? member.accountId,
                                style: Theme.of(context).textTheme.titleMedium),
                            subtitle: Text(strings.text(member.isOwner
                                ? 'sharedOwner'
                                : 'sharedMember')),
                            children: member.isOwner ||
                                    !_canManageMembers ||
                                    member.accountId == _service.currentUserId
                                ? [
                                    ListTile(
                                      title: Text(strings.text(member.isOwner
                                          ? 'sharedOwnerFullAccess'
                                          : 'sharedMemberPermissions')),
                                    ),
                                  ]
                                : [
                                    _permissionSwitch(
                                      context,
                                      member,
                                      'sharedPermissionView',
                                      member.permissions.view,
                                      (value) => value
                                          ? member.permissions
                                              .copyWith(view: true)
                                          : const CollectionPermissions(
                                              view: false,
                                              addItems: false,
                                              editItems: false,
                                              deleteItems: false,
                                              manageMembers: false,
                                              manageInvites: false,
                                            ),
                                    ),
                                    _permissionSwitch(
                                      context,
                                      member,
                                      'sharedPermissionAdd',
                                      member.permissions.addItems,
                                      (value) => member.permissions.copyWith(
                                          view: value ? true : null,
                                          addItems: value),
                                      canEnable: _owner ||
                                          (_selfPermissions?.addItems ?? false),
                                    ),
                                    _permissionSwitch(
                                      context,
                                      member,
                                      'sharedPermissionEdit',
                                      member.permissions.editItems,
                                      (value) => member.permissions.copyWith(
                                          view: value ? true : null,
                                          editItems: value),
                                      canEnable: _owner ||
                                          (_selfPermissions?.editItems ??
                                              false),
                                    ),
                                    _permissionSwitch(
                                      context,
                                      member,
                                      'sharedPermissionDelete',
                                      member.permissions.deleteItems,
                                      (value) => member.permissions.copyWith(
                                          view: value ? true : null,
                                          deleteItems: value),
                                      canEnable: _owner ||
                                          (_selfPermissions?.deleteItems ??
                                              false),
                                    ),
                                    _permissionSwitch(
                                      context,
                                      member,
                                      'sharedPermissionManageMembers',
                                      member.permissions.manageMembers,
                                      (value) => member.permissions.copyWith(
                                          view: value ? true : null,
                                          manageMembers: value),
                                    ),
                                    _permissionSwitch(
                                      context,
                                      member,
                                      'sharedPermissionManageInvites',
                                      member.permissions.manageInvites,
                                      (value) => member.permissions.copyWith(
                                          view: value ? true : null,
                                          manageInvites: value),
                                      canEnable: _owner ||
                                          (_selfPermissions?.manageInvites ??
                                              false),
                                    ),
                                    Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: TextButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _removeMember(member),
                                        icon:
                                            const Icon(LucideIcons.userRoundX),
                                        label: Text(
                                            strings.text('sharedRemoveMember')),
                                      ),
                                    ),
                                  ],
                          ),
                          const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _permissionSwitch(
    BuildContext context,
    CollectionMember member,
    String labelKey,
    bool value,
    CollectionPermissions Function(bool value) updated, {
    bool canEnable = true,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(NovaStrings.of(context).text(labelKey)),
      value: value,
      onChanged: _busy || (!value && !canEnable)
          ? null
          : (enabled) => _setPermission(member, updated(enabled)),
    );
  }
}
