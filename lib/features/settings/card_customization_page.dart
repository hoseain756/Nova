import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/models/visual_preferences.dart';
import '../../core/state/app_state.dart';
import '../../shared/widgets/poster_card.dart';
import 'widgets/settings_tiles.dart';

class CardCustomizationPage extends StatelessWidget {
  const CardCustomizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.select<AppState, bool>((app) => app.english);
    final preferences = context.select<AppState, CardPreferences>(
        (app) => CardPreferences.fromSettings(app.webSettings));
    final app = context.read<AppState>();
    final dimensions = preferences.dimensions(MediaQuery.sizeOf(context).width);
    final previewArtwork = app.watchlist
        .where((item) => item.poster?.isNotEmpty == true)
        .firstOrNull
        ?.poster;
    final previewItem = MediaItem(
      id: 'nova-card-preview',
      type: 'movie',
      name: app.tr('cardPreviewTitle'),
      releaseInfo: 'NOVA',
      poster: previewArtwork,
    );
    return Scaffold(
      appBar: AppBar(title: Text(app.tr('cardCustomizationTitle'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .45),
                child: SingleChildScrollView(
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.tr('cardPreviewTitle'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: IgnorePointer(
                            child: PosterCard(
                              item: previewItem,
                              width: dimensions.railWidth *
                                  (MediaQuery.sizeOf(context).width < 700
                                      ? .85
                                      : 1),
                              onTap: () {},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant),
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 48),
                  children: [
                    SettingsPageIntro(
                      title: app.tr('cardCustomizationTitle'),
                      description: app.tr('cardCustomizationDescription'),
                      icon: LucideIcons.clapperboard,
                    ),
                    SettingsContentSection(
                      title: app.tr('cardSizeTitle'),
                      children: [
                        _ChoiceRow<CardSize>(
                          selected: preferences.size,
                          choices: [
                            (CardSize.small, app.tr('cardSizeSmall')),
                            (CardSize.medium, app.tr('cardSizeMedium')),
                            (CardSize.large, app.tr('cardSizeLarge')),
                          ],
                          onSelected: (value) =>
                              app.setSetting('cardSize', value.name),
                        ),
                      ],
                    ),
                    SettingsContentSection(
                      title: app.tr('cardOrientationTitle'),
                      children: [
                        _ChoiceRow<CardOrientation>(
                          selected: preferences.orientation,
                          choices: [
                            (
                              CardOrientation.vertical,
                              app.tr('cardOrientationVertical')
                            ),
                            (
                              CardOrientation.horizontal,
                              app.tr('cardOrientationHorizontal')
                            ),
                          ],
                          onSelected: (value) =>
                              app.setSetting('cardOrientation', value.name),
                        ),
                      ],
                    ),
                    SettingsContentSection(
                      title: app.tr('cardShapeTitle'),
                      children: [
                        _ChoiceRow<bool>(
                          selected: preferences.radius > 0,
                          choices: [
                            (false, app.tr('cardShapeSharp')),
                            (true, app.tr('cardShapeRounded')),
                          ],
                          onSelected: (rounded) =>
                              app.setSetting('posterRadius', rounded ? 18 : 0),
                        ),
                        _CornerRadiusControl(
                          value: preferences.radius,
                          label: app.tr('cardRadiusTitle'),
                        ),
                      ],
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () async {
                          await app.setSetting(
                              'cardSize', CardSize.medium.name);
                          await app.setSetting(
                              'cardOrientation', CardOrientation.vertical.name);
                          await app.setSetting('posterRadius', 12);
                        },
                        icon: const Icon(LucideIcons.rotateCcw),
                        label: Text(app.tr('cardReset')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.selected,
    required this.choices,
    required this.onSelected,
  });

  final T selected;
  final List<(T, String)> choices;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in choices)
              ChoiceChip(
                label: Text(choice.$2),
                selected: selected == choice.$1,
                onSelected: (_) => onSelected(choice.$1),
                showCheckmark: false,
              ),
          ],
        ),
      );
}

class _CornerRadiusControl extends StatefulWidget {
  const _CornerRadiusControl({required this.value, required this.label});
  final double value;
  final String label;

  @override
  State<_CornerRadiusControl> createState() => _CornerRadiusControlState();
}

class _CornerRadiusControlState extends State<_CornerRadiusControl> {
  late double _value = widget.value;

  @override
  void didUpdateWidget(covariant _CornerRadiusControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.label)),
                Text(
                    context
                        .read<AppState>()
                        .tr('cardRadiusValue')
                        .replaceAll('{value}', '${_value.round()}'),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            Slider.adaptive(
              value: _value.clamp(0, 28),
              min: 0,
              max: 28,
              divisions: 14,
              semanticFormatterCallback: (value) => context
                  .read<AppState>()
                  .tr('cardRadiusValue')
                  .replaceAll('{value}', '${value.round()}'),
              onChanged: (value) {
                setState(() => _value = value);
                context
                    .read<AppState>()
                    .setSetting('posterRadius', value.round());
              },
            ),
          ],
        ),
      );
}
