import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';
import '../../../core/storage/subtitle_font_store.dart';
import '../../../l10n/nova_strings.dart';
import 'subtitle_overlay.dart';

/// Shared by general subtitle settings and the live player style sheet.
class SubtitleFontPicker extends StatelessWidget {
  const SubtitleFontPicker({super.key, this.onSelected});

  /// The player sheet previews before the AppState write; general settings
  /// can use the default write path.
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final (english, selected) =
        context.select<AppState, (bool, String)>((app) => (
              app.english,
              (app.webSettings['subFontFamily'] as String?) ??
                  SubtitleStyle.subtitleFontFamily,
            ));
    final store = SubtitleFontStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final name = selected == SubtitleStyle.subtitleFontFamily
            ? NovaStrings.lookup(english, 'subtitleDefaultFont')
            : store.fonts
                    .where((font) => font.family == selected)
                    .map((font) => font.name)
                    .firstOrNull ??
                NovaStrings.lookup(english, 'subtitleDefaultFont');
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.type),
          title: Text(NovaStrings.lookup(english, 'subtitleFont')),
          subtitle: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(LucideIcons.chevronDown),
          onTap: () => _showPicker(context, english, selected),
        );
      },
    );
  }

  void _select(BuildContext context, String family) {
    if (onSelected != null) {
      onSelected!(family);
    } else {
      unawaited(context.read<AppState>().setSetting('subFontFamily', family));
    }
  }

  Future<void> _showPicker(
      BuildContext context, bool english, String selected) async {
    final store = SubtitleFontStore.instance;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
      builder: (sheetContext) => SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (sheetContext, _) => ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
                child: Text(NovaStrings.lookup(english, 'subtitleFont'),
                    style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
              ListTile(
                leading: Icon(selected == SubtitleStyle.subtitleFontFamily
                    ? LucideIcons.circleDot
                    : LucideIcons.circle),
                title: Text(NovaStrings.lookup(english, 'subtitleDefaultFont')),
                onTap: () {
                  _select(context, SubtitleStyle.subtitleFontFamily);
                  Navigator.pop(sheetContext);
                },
              ),
              for (final font in store.fonts)
                ListTile(
                  leading: Icon(selected == font.family
                      ? LucideIcons.circleDot
                      : LucideIcons.circle),
                  title: Text(font.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    _select(context, font.family);
                    Navigator.pop(sheetContext);
                  },
                  trailing: IconButton(
                    tooltip: NovaStrings.lookup(english, 'remove'),
                    icon: const Icon(LucideIcons.trash2),
                    onPressed: () async {
                      if (selected == font.family) {
                        _select(context, SubtitleStyle.subtitleFontFamily);
                        selected = SubtitleStyle.subtitleFontFamily;
                      }
                      await store.remove(font.family);
                    },
                  ),
                ),
              ListTile(
                leading: const Icon(LucideIcons.plus),
                title: Text(NovaStrings.lookup(english, 'subtitleAddFont')),
                subtitle:
                    Text(NovaStrings.lookup(english, 'subtitleFontFormats')),
                onTap: () async {
                  try {
                    final font = await store.pickAndImport();
                    if (font == null || !context.mounted) return;
                    _select(context, font.family);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  } catch (error) {
                    if (!sheetContext.mounted) return;
                    final key =
                        error is FormatException && error.message == 'fontSize'
                            ? 'subtitleFontTooLarge'
                            : 'subtitleFontInvalid';
                    ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                        content: Text(NovaStrings.lookup(english, key))));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
