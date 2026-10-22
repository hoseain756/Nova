import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/data/catalog_repository.dart';
import '../../core/state/app_state.dart';

/// Order and visibility apply immediately to installed add-on catalogs.
/// Keys include the add-on identity, so similarly named rows stay independent.
class CatalogSettingsPage extends StatelessWidget {
  const CatalogSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final order = (app.webSettings['catalogRowOrder'] as List? ?? const [])
        .map((value) => value.toString())
        .toList();
    final hidden = (app.webSettings['catalogRowHidden'] as List? ?? const [])
        .map((value) => value.toString())
        .toSet();
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
              return Padding(
                key: ValueKey(row.key),
                padding: const EdgeInsetsDirectional.only(bottom: 6),
                child: Material(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  child: SwitchListTile.adaptive(
                    secondary: const Icon(LucideIcons.gripVertical),
                    title: Text(row.title),
                    subtitle: Text(row.subtitle),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
