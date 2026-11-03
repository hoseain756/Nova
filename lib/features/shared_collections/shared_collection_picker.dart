import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/media_item.dart';
import '../../core/shared_collections/shared_collections_service.dart';
import '../../l10n/nova_strings.dart';

/// Adds an existing catalog title without changing its playback identity.
Future<void> showSharedCollectionPicker(
  BuildContext context,
  MediaItem item,
) async {
  if (!Supabase.instance.isInitialized ||
      Supabase.instance.client.auth.currentUser == null) {
    return;
  }
  final service = SharedCollectionsService(Supabase.instance.client);
  final strings = NovaStrings.of(context);
  List<SharedCollection> collections;
  try {
    final all = await service.listCollections();
    final memberships = await Future.wait([
      for (final collection in all) service.listMembers(collection.id),
    ]);
    collections = [
      for (var index = 0; index < all.length; index++)
        if (memberships[index]
                .where((member) => member.accountId == service.currentUserId)
                .firstOrNull
                ?.permissions
                .addItems ==
            true)
          all[index],
    ];
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(strings.text('sharedLoadFailed')),
      ));
    }
    return;
  }
  if (!context.mounted) return;
  final selection = await showModalBottomSheet<SharedCollection>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * .65,
      child: SafeArea(
        top: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.text('sharedAddToCollection'),
                      style: Theme.of(sheetContext).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          Expanded(
            child: collections.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(LucideIcons.usersRound, size: 40),
                        const SizedBox(height: 12),
                        Text(strings.text('sharedNoWritableCollections'),
                            textAlign: TextAlign.center),
                      ]),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
                    itemCount: collections.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final collection = collections[index];
                      return ListTile(
                        minTileHeight: 64,
                        leading: const Icon(LucideIcons.usersRound),
                        title: Text(collection.name,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(LucideIcons.plus),
                        onTap: () => Navigator.pop(sheetContext, collection),
                      );
                    },
                  ),
          ),
        ]),
      ),
    ),
  );
  if (selection == null || !context.mounted) return;
  final mediaType = item.hasAnimeIds ||
          item.type == 'anime' ||
          item.id.startsWith('anilist:') ||
          item.id.startsWith('mal:')
      ? 'anime'
      : item.type == 'series'
          ? 'series'
          : 'movie';
  try {
    await service.addItem(
      collectionId: selection.id,
      mediaType: mediaType,
      mediaId: item.id,
      title: item.name,
      posterUrl:
          item.poster?.startsWith('https://') == true ? item.poster : null,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(strings.text('sharedItemAdded')),
      ));
    }
  } on PostgrestException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(strings.text(error.code == '23505'
            ? 'sharedItemAlreadyAdded'
            : 'sharedSaveFailed')),
      ));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(strings.text('sharedSaveFailed')),
      ));
    }
  }
}
