import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/platform/app_icon_service.dart';
import '../../core/state/app_state.dart';
import 'widgets/settings_tiles.dart';

class AppIconSettingsPage extends StatefulWidget {
  const AppIconSettingsPage({super.key, this.controller});

  @visibleForTesting
  final AppIconController? controller;

  @override
  State<AppIconSettingsPage> createState() => _AppIconSettingsPageState();
}

class _AppIconSettingsPageState extends State<AppIconSettingsPage> {
  late final AppIconController _controller =
      widget.controller ?? const NativeAppIconController();
  AppIconSelection? _selection;
  bool _busy = false;
  bool _loadFailed = false;
  bool _changeFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final selection = await _controller.current();
      if (mounted) setState(() => _selection = selection);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _select(String? id) async {
    if (id == null || _busy || id == _selection?.selected) return;
    setState(() {
      _busy = true;
      _changeFailed = false;
    });
    try {
      final selection = await _controller.select(id);
      if (mounted) setState(() => _selection = selection);
    } catch (_) {
      if (mounted) setState(() => _changeFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _imageFor(String id) => switch (id) {
        'clear' => 'assets/brand/ios/no_background/red_glyph/AppIcon-120.png',
        'dark' => 'assets/brand/ios/ios18_variants/AppIcon-dark-1024.png',
        _ => 'assets/brand/ios/with_background/AppIcon-120.png',
      };

  Widget _preview(BuildContext context, String id) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(_imageFor(id), fit: BoxFit.contain, cacheWidth: 160),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final selection = _selection;
    return Scaffold(
      appBar: AppBar(title: Text(app.tr('appIconTitle'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 48),
            children: [
              SettingsPageIntro(
                title: app.tr('appIconTitle'),
                description: app.tr('appIconDescription'),
                icon: LucideIcons.image,
              ),
              if (_loadFailed)
                SettingsInfoBanner(
                  icon: LucideIcons.circleAlert,
                  message: app.tr('appIconLoadFailed'),
                  error: true,
                )
              else if (selection == null)
                const Center(child: CircularProgressIndicator.adaptive())
              else if (!selection.supported)
                SettingsInfoBanner(message: app.tr('appIconUnavailable'))
              else ...[
                SettingsContentSection(
                  title: app.tr('appIconChoose'),
                  children: [
                    RadioGroup<String>(
                      groupValue: selection.selected,
                      onChanged: (id) => unawaited(_select(id)),
                      child: Column(
                        children: [
                          for (final id in selection.ids)
                            RadioListTile<String>(
                              value: id,
                              selected: selection.selected == id,
                              title: Text(switch (id) {
                                'clear' => app.tr('appIconClear'),
                                'dark' => app.tr('appIconDark'),
                                _ => app.tr('appIconClassic'),
                              }),
                              subtitle: Text(switch (id) {
                                'clear' => app.tr('appIconClearDescription'),
                                'dark' => app.tr('appIconDarkDescription'),
                                _ => app.tr('appIconClassicDescription'),
                              }),
                              secondary: _preview(context, id),
                              contentPadding:
                                  const EdgeInsetsDirectional.fromSTEB(
                                      12, 8, 20, 8),
                            ),
                        ],
                      ),
                    ),
                    if (_busy) const LinearProgressIndicator(),
                  ],
                ),
                if (_changeFailed) ...[
                  SettingsInfoBanner(
                    icon: LucideIcons.circleAlert,
                    message: app.tr('appIconChangeFailed'),
                    error: true,
                  ),
                  const SizedBox(height: 16),
                ],
                SettingsInfoBanner(message: app.tr('appIconSystemNote')),
              ],
              if (_loadFailed)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: _load,
                    child: Text(app.tr('retry')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
