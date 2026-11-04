import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/visual_preferences.dart';
import '../../core/state/app_state.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'card_customization_page.dart';
import 'widgets/settings_tiles.dart';
import '../../shared/widgets/nova_parental_gate.dart';

class SettingsDisplayPage extends StatelessWidget {
  const SettingsDisplayPage({super.key, this.kidsOnly = false});
  final bool kidsOnly;
  @override
  Widget build(BuildContext context) {
    context.select<AppState, bool>((app) => app.english);
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
          title: Text(kidsOnly ? app.tr('message415') : app.tr('message416'))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 48),
                children: [
                  SettingsPageIntro(
                      title: kidsOnly
                          ? app.tr('message417')
                          : app.tr('message418'),
                      description: kidsOnly
                          ? app.tr('message419')
                          : app.tr('message420'),
                      icon: kidsOnly
                          ? LucideIcons.smile
                          : LucideIcons.layoutGrid),
                  if (!kidsOnly) ...[
                    SettingsContentSection(
                        title: app.tr('message421'),
                        children: [
                          _SettingSelect(
                              settingKey: 'homeMode',
                              fallback: 'harbor',
                              title: app.tr('message422'),
                              options: {
                                'harbor': app.tr('message423'),
                                'classic': app.tr('message424')
                              }),
                          _SettingToggle(
                              settingKey: 'hideWatchedInCatalogs',
                              title: app.tr('message426')),
                          _HideContentToggle(
                              kind: 'anime', title: app.tr('message427')),
                          _HideContentToggle(
                              kind: 'adult', title: app.tr('message428')),
                        ]),
                    SettingsContentSection(
                        title: app.tr('message429'),
                        children: [
                          _SettingToggle(
                              settingKey: 'showImdbBadge',
                              onWhenAbsent: true,
                              title: app.tr('message430')),
                          _SettingToggle(
                              settingKey: 'hidePosterTitles',
                              title: app.tr('message431')),
                          SettingsTile(
                            icon: LucideIcons.clapperboard,
                            title: app.tr('cardCustomizationTitle'),
                            subtitle: app.tr('cardCustomizationDescription'),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CardCustomizationPage(),
                              ),
                            ),
                          ),
                          _SettingToggle(
                              settingKey: 'blurEpisodeThumbnails',
                              title: app.tr('message432')),
                          _SettingSelect(
                              settingKey: 'episodesView',
                              fallback: 'auto',
                              title: app.tr('message433'),
                              options: {
                                'auto': app.tr('message434'),
                                'list': app.tr('message435'),
                                'grid': app.tr('message436')
                              }),
                        ]),
                    SettingsContentSection(
                        title: app.tr('message437'),
                        children: [
                          _SettingSelect(
                              settingKey: 'librarySort',
                              fallback: 'recent',
                              title: app.tr('message438'),
                              options: {
                                'recent': app.tr('message439'),
                                'title': app.tr('message440'),
                                'year': app.tr('message441')
                              }),
                        ]),
                    SettingsContentSection(
                      title: app.tr('imageQualityTitle'),
                      description: app.tr('imageQualityDescription'),
                      children: const [
                        _ImageQualityRow(
                          settingKey: 'heroImageQuality',
                          titleKey: 'heroImageQualityTitle',
                        ),
                        _ImageQualityRow(
                          settingKey: 'cardImageQuality',
                          titleKey: 'cardImageQualityTitle',
                        ),
                      ],
                    ),
                    SettingsContentSection(
                      title: app.tr('heroTrailerAutoplayTitle'),
                      description: app.tr('heroTrailerAutoplayDescription'),
                      children: [
                        _SettingSelect(
                          settingKey: 'heroTrailerAutoplay',
                          fallback: 'wifi',
                          title: app.tr('heroTrailerAutoplayTitle'),
                          options: {
                            'always': app.tr('heroTrailerAlways'),
                            'wifi': app.tr('heroTrailerWifi'),
                            'never': app.tr('heroTrailerNever'),
                          },
                        ),
                      ],
                    ),
                    SettingsInfoBanner(
                      icon: LucideIcons.accessibility,
                      message: app.tr('heroTrailerCaveat'),
                    ),
                  ],
                  SettingsContentSection(
                      title: app.tr('message443'),
                      children: [
                        _SettingSelect(
                            settingKey: 'kidsCardSize',
                            fallback: 'inherit',
                            title: app.tr('message444'),
                            options: {
                              'inherit': app.tr('kidsCardSizeInherit'),
                              'large': app.tr('message445'),
                              'mediumOverride': app.tr('message446'),
                              'small': app.tr('message447')
                            }),
                        if (kidsOnly)
                          SettingsTile(
                              icon: LucideIcons.keyRound,
                              title: app.tr('message448'),
                              subtitle: app.tr('message449'),
                              onTap: () => NovaParentalGate.change(context)),
                      ]),
                  if (kidsOnly)
                    SettingsInfoBanner(
                        icon: LucideIcons.shieldCheck,
                        message: app.tr('message450')),
                ],
              ))),
    );
  }
}

/// Task 122-c: content-language row — a [_SelectRow] reading ONLY
/// [AppState.contentLanguage] via context.select. The 11 options are the
/// static [AppState.kContentLanguages] native labels, shown natively in
/// BOTH UI languages (a content language may differ from the UI one).
/// Task 122-c F4: self-subscribing toggle row bound to one `webSettings`
/// bool key (`== true` semantics, or `!= false` with [onWhenAbsent]) —
/// renders through the optimistic switch tile so taps paint instantly.
class _SettingToggle extends StatelessWidget {
  const _SettingToggle({
    required this.settingKey,
    required this.title,
    this.onWhenAbsent = false,
  });
  final String settingKey;
  final String title;
  final bool onWhenAbsent;

  @override
  Widget build(BuildContext context) {
    final value = context.select<AppState, bool>((app) {
      final raw = app.webSettings[settingKey];
      return onWhenAbsent ? raw != false : raw == true;
    });
    return SettingsOptimisticSwitchTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 10, 16, 10),
      title: Text(title),
      value: value,
      onChanged: (next) =>
          context.read<AppState>().setSetting(settingKey, next),
    );
  }
}

/// Self-subscribing toggle row over the `hideContent` map (`anime`/`adult`).
class _HideContentToggle extends StatelessWidget {
  const _HideContentToggle({required this.kind, required this.title});
  final String kind;
  final String title;

  @override
  Widget build(BuildContext context) {
    final value = context.select<AppState, bool>(
        (app) => (app.webSettings['hideContent'] as Map?)?[kind] == true);
    return SettingsOptimisticSwitchTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 10, 16, 10),
      title: Text(title),
      value: value,
      onChanged: (next) {
        final app = context.read<AppState>();
        final hide = Map<String, dynamic>.from(
            app.webSettings['hideContent'] as Map? ?? const {});
        app.setSetting('hideContent', {...hide, kind: next});
      },
    );
  }
}

/// Self-subscribing select row bound to one `webSettings` string key with
/// a fallback ([_SelectRow]'s rendering is unchanged for these rows).
class _SettingSelect extends StatelessWidget {
  const _SettingSelect({
    required this.settingKey,
    required this.fallback,
    required this.title,
    required this.options,
  });
  final String settingKey;
  final String fallback;
  final String title;
  final Map<String, String> options;

  @override
  Widget build(BuildContext context) {
    final value = context.select<AppState, String>(
        (app) => (app.webSettings[settingKey] ?? fallback).toString());
    return _SelectRow(
      title: title,
      value: value,
      options: options,
      onChanged: (next) =>
          context.read<AppState>().setSetting(settingKey, next),
    );
  }
}

class _ImageQualityRow extends StatelessWidget {
  const _ImageQualityRow({
    required this.settingKey,
    required this.titleKey,
  });

  final String settingKey;
  final String titleKey;

  @override
  Widget build(BuildContext context) {
    final (_, quality) =
        context.select<AppState, (bool, ImageQuality)>((app) => (
              app.english,
              ImageQuality.fromValue(app.webSettings[settingKey]),
            ));
    final app = context.read<AppState>();
    final options = {
      ImageQuality.auto: app.tr('imageQualityAuto'),
      ImageQuality.low: app.tr('imageQualityLow'),
      ImageQuality.medium: app.tr('imageQualityMedium'),
      ImageQuality.high: app.tr('imageQualityHigh'),
      ImageQuality.original: app.tr('imageQualityOriginal'),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(app.tr(titleKey), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SettingsLanguageDropdown(
            expanded: true,
            value: quality.name,
            items: [
              for (final entry in options.entries)
                DropdownMenuItem(
                  value: entry.key.name,
                  child: Text(entry.value),
                ),
            ],
            onChanged: (value) => app.setSetting(settingKey, value),
          ),
        ],
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow(
      {required this.title,
      required this.value,
      required this.options,
      required this.onChanged});
  final String title;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        SettingsLanguageDropdown(
            expanded: true,
            value: options.containsKey(value) ? value : options.keys.first,
            items: options.entries
                .map((entry) => DropdownMenuItem(
                    value: entry.key, child: Text(entry.value)))
                .toList(),
            onChanged: onChanged),
      ]));
}
