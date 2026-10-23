import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/data/catalog_repository.dart';
import '../../core/state/app_state.dart';

/// Order and visibility apply immediately to installed add-on catalogs.
/// Keys include the add-on identity, so similarly named rows stay independent.
class CatalogSettingsPage extends StatelessWidget {
  const CatalogSettingsPage({super.key});

  Future<void> _rename(BuildContext context, AppState app, AddonCatalogRow row,
      Map<String, String> names) async {
    var editedName = names[row.key] ?? row.title;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(app.tr('catalogRename')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                initialValue: editedName,
                autofocus: true,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    InputDecoration(labelText: app.tr('catalogRenameHint')),
                onChanged: (value) => editedName = value,
                onFieldSubmitted: (value) =>
                    Navigator.of(dialogContext).pop(value),
              ),
              Text(app.tr('catalogRenameResetHint')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child:
                Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(editedName),
            child: Text(app.tr('catalogRenameSave')),
          ),
        ],
      ),
    );
    if (result == null) return;
    final next = {...names};
    final value = result.trim();
    if (value.isEmpty || value == row.title) {
      next.remove(row.key);
    } else {
      next[row.key] = value;
    }
    await app.setSetting('catalogRowNames', next);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final order = (app.webSettings['catalogRowOrder'] as List? ?? const [])
        .map((value) => value.toString())
        .toList();
    final hidden = (app.webSettings['catalogRowHidden'] as List? ?? const [])
        .map((value) => value.toString())
        .toSet();
    final names = Map<String, String>.from(
        app.webSettings['catalogRowNames'] as Map? ?? const {});
    final rows = CatalogRepository.selectAddonCatalogRows(
      app.addons,
      order: order,
    );
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(app.tr('catalogManagement'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            // Keep the item's own rounded Material while it is in the overlay.
            proxyDecorator: (child, index, animation) => child,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 32)
                .resolve(Directionality.of(context)),
            header: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(app.tr('catalogManagementDescription'),
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(app.tr('hideKidsCatalogsHome')),
                    subtitle: Text(app.tr('hideKidsCatalogsHomeDescription')),
                    value: app.webSettings['hideKidsCatalogsHome'] == true,
                    onChanged: (value) =>
                        app.setSetting('hideKidsCatalogsHome', value),
                  ),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(app.tr('noAddonCatalogs')),
                    ),
                ],
              ),
            ),
            itemCount: rows.length,
            onReorderItem: (oldIndex, newIndex) {
              final next = [...rows];
              final moved = next.removeAt(oldIndex);
              next.insert(newIndex, moved);
              app.setSetting(
                  'catalogRowOrder', next.map((row) => row.key).toList());
            },
            itemBuilder: (context, index) {
              final row = rows[index];
              final title = row.displayTitle(names);
              return Padding(
                key: ValueKey(row.key),
                padding: const EdgeInsetsDirectional.only(bottom: 6),
                child: Material(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 8, 8),
                    child: Row(
                      children: [
                        Semantics(
                          label: app.tr('catalogDragHandle', {'name': title}),
                          child: ReorderableDragStartListener(
                            index: index,
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(LucideIcons.gripVertical),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(row.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: app.tr('catalogRename'),
                          onPressed: () => _rename(context, app, row, names),
                          icon: const Icon(LucideIcons.pencil),
                        ),
                        Semantics(
                          label: title,
                          child: Switch.adaptive(
                            value: !hidden.contains(row.key),
                            onChanged: (visible) {
                              final next = {...hidden};
                              if (visible) {
                                next.remove(row.key);
                              } else {
                                next.add(row.key);
                              }
                              app.setSetting('catalogRowHidden', next.toList());
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
