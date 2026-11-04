import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/custom_list.dart';
import '../../core/models/media_item.dart';
import '../../core/state/app_state.dart';
import '../../l10n/nova_strings.dart';
import 'custom_lists_page.dart';
import '../shell/nova_browse_widgets.dart';
import '../shared_collections/shared_collection_picker.dart';

Future<void> showCustomListPicker(BuildContext context, MediaItem item) async {
  final app = context.read<AppState>();
  final selection = await showModalBottomSheet<Object>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (sheetContext) => NovaBrowseSheet(slivers: [
      SliverToBoxAdapter(
          child: NovaBrowseSheetHeading(
        title: app.tr('message631'),
        subtitle: item.name,
        closeLabel: app.tr('close'),
        onClose: () => Navigator.pop(sheetContext),
      )),
      if (app.customLists.isEmpty)
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(LucideIcons.library,
                size: 40,
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
            const SizedBox(height: 20),
            Text(app.tr('message632'),
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(app.tr('message633')),
          ]),
        ))
      else
        SliverPadding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 24),
          sliver: SliverList.separated(
            itemCount: app.customLists.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final list = app.customLists[index];
              final exists = list.items.any((entry) => entry.id == item.id);
              return ListTile(
                minTileHeight: 88,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    exists ? LucideIcons.circleCheck : LucideIcons.library,
                    color: Theme.of(sheetContext).colorScheme.primary),
                title: Text(list.name,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Text(exists
                    ? app.tr('message634')
                    : '${list.items.length} ${app.tr('message607')}'),
                trailing: exists ? null : const Icon(LucideIcons.plus),
                onTap: exists ? null : () => Navigator.pop(sheetContext, list),
              );
            },
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.all(24),
        sliver: SliverToBoxAdapter(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 24),
            FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'create'),
                icon: const Icon(LucideIcons.plus),
                label: Text(app.tr('message605'))),
            if (Supabase.instance.isInitialized &&
                Supabase.instance.client.auth.currentUser != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'shared'),
                  icon: const Icon(LucideIcons.usersRound),
                  label: Text(NovaStrings.of(sheetContext)
                      .text('sharedAddToCollection'))),
            ],
          ],
        )),
      ),
    ]),
  );
  if (selection == null || !context.mounted) return;
  if (selection == 'shared') {
    await showSharedCollectionPicker(context, item);
    return;
  }
  if (selection == 'create') {
    await createNovaCollection(context);
    if (context.mounted && app.customLists.isNotEmpty) {
      await showCustomListPicker(context, item);
    }
    return;
  }
  final list = selection as CustomMediaList;
  final added = await app.addToCustomList(list.id, item);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added ? app.tr('message635') : app.tr('message634'))));
}
