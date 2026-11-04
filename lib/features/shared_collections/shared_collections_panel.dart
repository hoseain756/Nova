import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/shared_collections/invite_link.dart';
import '../../core/shared_collections/shared_collections_service.dart';
import '../../l10n/nova_strings.dart';
import 'shared_collection_detail_page.dart';

/// Server-backed collections are separate from the profile's private lists.
class SharedCollectionsPanel extends StatefulWidget {
  const SharedCollectionsPanel({super.key, this.service});

  final SharedCollectionsService? service;

  @override
  State<SharedCollectionsPanel> createState() => _SharedCollectionsPanelState();
}

class _SharedCollectionsPanelState extends State<SharedCollectionsPanel>
    with WidgetsBindingObserver {
  late final SharedCollectionsService _service;
  RealtimeChannel? _channel;
  List<SharedCollection> _collections = const [];
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
    _channel = _service.watchCollections(() => unawaited(_load()));
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
      final collections = await _service.listCollections();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _collections = collections;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final values = await showSharedCollectionForm(context);
    if (values == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final created = await _service.createCollection(
        name: values.$1,
        description: values.$2 ?? '',
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SharedCollectionDetailPage(collectionId: created.id),
      ));
      await _load();
    } catch (_) {
      if (mounted) _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final strings = NovaStrings.of(context);
    var input = '';
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.text('sharedJoinTitle')),
        content: TextField(
          onChanged: (value) => input = value,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: strings.text('sharedInviteLink'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.text('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, input.trim()),
            child: Text(strings.text('sharedJoin')),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    final token = sharedCollectionInviteToken(value);
    if (token == null) {
      _showError(message: strings.text('sharedInvalidInvite'));
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await _service.joinInvite(token);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SharedCollectionDetailPage(collectionId: id),
      ));
      await _load();
    } on PostgrestException catch (error) {
      if (mounted) {
        _showError(
          message: strings.text(
              error.code == '22023' ? 'sharedJoinFailed' : 'sharedJoinRetry'),
        );
      }
    } catch (_) {
      if (mounted) _showError(message: strings.text('sharedJoinRetry'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError({String? message}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(message ?? NovaStrings.of(context).text('sharedSaveFailed')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final strings = NovaStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.text('sharedCollections'),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(strings.text('sharedCollectionsDescription'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _create,
                  icon: const Icon(LucideIcons.plus),
                  label: Text(strings.text('sharedCreate')),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _join,
                  icon: const Icon(LucideIcons.link),
                  label: Text(strings.text('sharedJoin')),
                ),
              ]),
            ],
          ),
        ),
      ),
      if (_loading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        )
      else if (_error != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
            child: Row(children: [
              Expanded(child: Text(strings.text('sharedLoadFailed'))),
              TextButton(onPressed: _load, child: Text(strings.text('retry'))),
            ]),
          ),
        )
      else if (_collections.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
            child: Text(strings.text('sharedEmpty'),
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
          sliver: SliverList.separated(
            itemCount: _collections.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final collection = _collections[index];
              final isOwner = collection.ownerId == _service.currentUserId;
              return ListTile(
                minTileHeight: 72,
                contentPadding: EdgeInsets.zero,
                leading: Icon(LucideIcons.usersRound, color: scheme.primary),
                title: Text(collection.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(isOwner
                    ? strings.text('sharedOwner')
                    : strings.text('sharedMember')),
                trailing: Icon(Directionality.of(context) == TextDirection.rtl
                    ? LucideIcons.chevronLeft
                    : LucideIcons.chevronRight),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => SharedCollectionDetailPage(
                      collectionId: collection.id,
                    ),
                  ));
                  if (mounted) await _load();
                },
              );
            },
          ),
        ),
    ]);
  }
}

/// Accepts the app link or a raw 64-character invite code.
String? sharedCollectionInviteToken(String input) {
  final value = input.trim();
  if (RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) return value;
  return parseSharedCollectionInvite(value);
}

Future<(String, String?)?> showSharedCollectionForm(
  BuildContext context, {
  String? initialName,
  String? initialDescription,
}) async {
  final strings = NovaStrings.of(context);
  var name = initialName ?? '';
  var description = initialDescription ?? '';
  final formKey = GlobalKey<FormState>();
  return showDialog<(String, String?)>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(strings
          .text(initialName == null ? 'sharedCreate' : 'sharedEditCollection')),
      content: Form(
        key: formKey,
        child: SizedBox(
          width:
              (MediaQuery.sizeOf(dialogContext).width - 128).clamp(0.0, 420.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              initialValue: initialName,
              onChanged: (value) => name = value,
              autofocus: true,
              maxLength: 80,
              decoration:
                  InputDecoration(labelText: strings.text('sharedName')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? strings.text('sharedNameRequired')
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: initialDescription,
              onChanged: (value) => description = value,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: strings.text('sharedDescription'),
              ),
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
            final details = description.trim();
            Navigator.pop(
                dialogContext, (name.trim(), details.isEmpty ? null : details));
          },
          child: Text(strings.text('save')),
        ),
      ],
    ),
  );
}
