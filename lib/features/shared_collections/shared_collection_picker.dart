import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/media_item.dart';
import '../../core/shared_collections/shared_collections_service.dart';
import '../../l10n/nova_strings.dart';
import '../shell/nova_browse_widgets.dart';

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
    builder: (sheetContext) => NovaBrowseSheet(slivers: [
      SliverToBoxAdapter(
          child: NovaBrowseSheetHeading(
        title: strings.text('sharedAddToCollection'),
        subtitle: item.name,
        closeLabel: strings.text('close'),
        onClose: () => Navigator.pop(sheetContext),
      )),
      if (collections.isEmpty)
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(LucideIcons.usersRound, size: 40),
            const SizedBox(height: 20),
            Text(strings.text('sharedNoWritableCollections')),
          ]),
        ))
      else
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
          sliver: SliverList.separated(
            itemCount: collections.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final collection = collections[index];
              return ListTile(
                minTileHeight: 88,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.usersRound),
                title: Text(collection.name,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                trailing: const Icon(LucideIcons.plus),
                onTap: () => Navigator.pop(sheetContext, collection),
              );
            },
          ),
        ),
    ]),
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
