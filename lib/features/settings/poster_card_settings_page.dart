import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/models/poster_card_style.dart';
import '../../core/state/app_state.dart';
import '../../shared/widgets/poster_card.dart';
import 'widgets/settings_tiles.dart';

class PosterCardSettingsPage extends StatefulWidget {
  const PosterCardSettingsPage({super.key});

  @override
  State<PosterCardSettingsPage> createState() => _PosterCardSettingsPageState();
}

class _PosterCardSettingsPageState extends State<PosterCardSettingsPage> {
  final _pending = <String, dynamic>{};

  void _preview(String key, double value) =>
      setState(() => _pending[key] = value);

  void _save(String key, dynamic value) {
    context.read<AppState>().setSetting(key, value);
    setState(() => _pending.remove(key));
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppState, bool>((app) => app.english);
    context.select<AppState, PosterCardStyle>(
        (app) => PosterCardStyle.fromSettings(app.webSettings));
    final app = context.read<AppState>();
    final style =
        PosterCardStyle.fromSettings({...app.webSettings, ..._pending});
    final width = style.railWidth(MediaQuery.sizeOf(context).width);
    final sample = app.watchlist.firstOrNull ??
        MediaItem(
            id: 'nova-card-preview',
            type: 'movie',
            name: app.tr('posterPreviewTitle'),
            releaseInfo: '2026',
            rating: '8.7');

    return Scaffold(
      appBar: AppBar(title: Text(app.tr('posterCustomization'))),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 48),
          children: [
            SettingsPageIntro(
                title: app.tr('posterCustomization'),
                description: app.tr('posterCustomizationDescription'),
                icon: LucideIcons.panelsTopLeft),
            Text(app.tr('posterLivePreview'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 16),
            LayoutBuilder(
                builder: (context, constraints) => Center(
                      child: IgnorePointer(
                          child: ExcludeSemantics(
                              child: PosterCard(
                        key: const ValueKey('poster-style-preview'),
                        item: sample,
                        onTap: () {},
                        style: style,
                        width: width.clamp(1, constraints.maxWidth),
                      ))),
                    )),
            const SizedBox(height: 24),
            SettingsContentSection(title: app.tr('posterShape'), children: [
              for (final landscape in [false, true])
                ListTile(
                  leading: Icon(landscape
                      ? LucideIcons.rectangleHorizontal
                      : LucideIcons.rectangleVertical),
                  title: Text(
                      app.tr(landscape ? 'posterLandscape' : 'posterPortrait')),
                  trailing: style.landscape == landscape
                      ? const Icon(LucideIcons.check)
                      : null,
                  selected: style.landscape == landscape,
                  onTap: () => _save(
                      'posterShape', landscape ? 'landscape' : 'portrait'),
                ),
            ]),
            SettingsContentSection(title: app.tr('posterSize'), children: [
              _slider(context,
                  title: app.tr('posterSize'),
                  value: style.scale,
                  min: .8,
                  max: 1.5,
                  divisions: 14,
                  label:
                      '${(style.scale * 100).round()}% · ${width.round()} × ${(width / style.aspectRatio).round()}',
                  setting: 'posterScale'),
              Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final preset in <(double, String)>[
                      (.8, 'posterSizeCompact'),
                      (.9, 'posterSizeDense'),
                      (1, 'posterSizeStandard'),
                      (1.15, 'posterSizeBalanced'),
                      (1.3, 'posterSizeComfort'),
                      (1.5, 'posterSizeLarge'),
                    ])
                      ChoiceChip(
                          label: Text(app.tr(preset.$2)),
                          selected: (style.scale - preset.$1).abs() < .001,
                          onSelected: (_) => _save('posterScale', preset.$1)),
                  ])),
            ]),
            SettingsContentSection(title: app.tr('message451'), children: [
              _slider(context,
                  title: app.tr('message451'),
                  value: style.radius,
                  min: 0,
                  max: 40,
                  divisions: 20,
                  label: app
                      .tr('logicalPixelValue', {'value': style.radius.round()}),
                  setting: 'posterRadius'),
              Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final preset in <(int, String)>[
                      (0, 'posterCornersSharp'),
                      (6, 'posterCornersSubtle'),
                      (12, 'posterCornersClassic'),
                      (18, 'posterCornersRounded'),
                      (28, 'posterCornersPill'),
                    ])
                      ChoiceChip(
                          label: Text(app.tr(preset.$2)),
                          selected: style.radius == preset.$1,
                          onSelected: (_) => _save('posterRadius', preset.$1)),
                  ])),
            ]),
            SettingsContentSection(title: app.tr('posterLabels'), children: [
              SettingsOptimisticSwitchTile(
                  title: Text(app.tr('message431')),
                  value: style.hideTitles,
                  onChanged: (value) => _save('hidePosterTitles', value)),
              if (style.landscape) ...[
                SettingsOptimisticSwitchTile(
                    title: Text(app.tr('posterShowLogo')),
                    value: style.showLogo,
                    onChanged: (value) => _save('showPosterLogo', value)),
                if (style.showLogo)
                  Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(app.tr('posterLogoPosition')),
                            const SizedBox(height: 8),
                            SettingsLanguageDropdown(
                                value: style.logoPosition,
                                expanded: true,
                                items: [
                                  for (final entry in <String, String>{
                                    'bottomStart': 'posterLogoStart',
                                    'center': 'posterLogoCenter',
                                    'bottomEnd': 'posterLogoEnd',
                                  }.entries)
                                    DropdownMenuItem(
                                        value: entry.key,
                                        child: Text(app.tr(entry.value)))
                                ],
                                onChanged: (value) =>
                                    _save('posterLogoPosition', value)),
                          ])),
              ],
            ]),
            TextButton.icon(
                icon: const Icon(LucideIcons.rotateCcw),
                label: Text(app.tr('posterReset')),
                onPressed: () {
                  for (final entry in PosterCardStyle.defaults.entries) {
                    app.setSetting(entry.key, entry.value);
                  }
                  setState(_pending.clear);
                }),
          ],
        ),
      )),
    );
  }

  Widget _slider(BuildContext context,
          {required String title,
          required double value,
          required double min,
          required double max,
          required int divisions,
          required String label,
          required String setting}) =>
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(label,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.bodySmall),
          Semantics(
              label: title,
              child: Slider.adaptive(
                key: ValueKey(setting),
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                label: label,
                onChanged: (next) => _preview(setting, next),
                onChangeEnd: (next) => _save(setting, next),
              )),
        ]),
      );
}
