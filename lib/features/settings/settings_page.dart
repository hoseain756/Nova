import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/state/app_state.dart';
import '../shell/noor_dock_tabs.dart';
import 'addons_page.dart';
import 'integrations_page.dart';
import 'stats_page.dart';
import 'settings_preferences_page.dart';
import 'settings_data_page.dart';
import 'settings_display_page.dart';
import 'settings_personalization_page.dart';
import 'catalog_settings_page.dart';
import 'card_customization_page.dart';
import 'widgets/settings_tiles.dart';

class _Destination {
  const _Destination(this.id, this.icon, this.title, this.description,
      this.keywords, this.page);
  final String id;
  final IconData icon;
  final String title, description, keywords;
  final Widget page;
}

class _SettingsGroup {
  const _SettingsGroup(
      this.id, this.icon, this.title, this.description, this.destinations);
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final List<_Destination> destinations;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.onOpenLibrary});
  final VoidCallback? onOpenLibrary;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _query = '';
  String? _selected = 'appearance';
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Destination> _destinations(AppState app) => [
        _Destination(
            'account',
            LucideIcons.userRound,
            app.tr('message346'),
            app.tr('message452'),
            app.tr('settingsSearchAccountKeywords'),
            const SettingsDataPage(section: 'account')),
        _Destination(
            'playback',
            LucideIcons.play,
            app.tr('message453'),
            app.tr('message454'),
            app.tr('settingsSearchPlaybackKeywords'),
            const SettingsPreferencesPage(subtitles: false)),
        _Destination(
            'subtitles',
            LucideIcons.captions,
            app.tr('message7'),
            app.tr('message455'),
            app.tr('settingsSearchSubtitleKeywords'),
            const SettingsPreferencesPage(subtitles: true)),
        _Destination(
            'downloads',
            LucideIcons.download,
            app.tr('message345'),
            app.tr('message456'),
            app.tr('settingsSearchDownloadKeywords'),
            const SettingsDataPage(section: 'storage')),
        _Destination(
            'appearance',
            LucideIcons.palette,
            app.tr('appearance'),
            app.tr('message457'),
            app.tr('settingsSearchAppearanceKeywords'),
            const SettingsPersonalizationPage(section: 'appearance')),
        _Destination(
            'cards',
            LucideIcons.clapperboard,
            app.tr('cardCustomizationTitle'),
            app.tr('cardCustomizationDescription'),
            app.tr('settingsSearchVisualKeywords'),
            const CardCustomizationPage()),
        _Destination(
            'display',
            LucideIcons.layoutGrid,
            app.tr('message416'),
            app.tr('message458'),
            app.tr('settingsSearchDisplayKeywords'),
            const SettingsDisplayPage()),
        _Destination(
            'catalogs',
            LucideIcons.listFilter,
            app.tr('catalogManagement'),
            app.tr('catalogManagementDescription'),
            app.tr('catalogManagementKeywords'),
            const CatalogSettingsPage()),
        _Destination(
            'language',
            LucideIcons.languages,
            app.tr('language'),
            app.tr('message459'),
            app.tr('settingsSearchLanguageKeywords'),
            const SettingsPersonalizationPage(section: 'language')),
        _Destination(
            'notifications',
            LucideIcons.bell,
            app.tr('message460'),
            app.tr('message461'),
            app.tr('settingsSearchNotificationsKeywords'),
            const SettingsPersonalizationPage(section: 'notifications')),
        _Destination(
            'privacy',
            LucideIcons.shieldCheck,
            app.tr('message347'),
            app.tr('message462'),
            app.tr('settingsSearchPrivacyKeywords'),
            const SettingsDataPage(section: 'privacy')),
        _Destination(
            'addons',
            LucideIcons.puzzle,
            app.tr('message220'),
            app.tr('message463'),
            app.tr('settingsSearchAddonKeywords'),
            const AddonsPage()),
        _Destination(
            'services',
            LucideIcons.orbit,
            app.tr('message252'),
            app.tr('message464'),
            app.tr('settingsSearchServiceKeywords'),
            const IntegrationsPage()),
        _Destination(
            'kids',
            LucideIcons.smile,
            app.tr('message415'),
            app.tr('message465'),
            app.tr('settingsSearchKidsKeywords'),
            const SettingsDisplayPage(kidsOnly: true)),
        _Destination(
            'stats',
            LucideIcons.chartNoAxesCombined,
            app.tr('message466'),
            app.tr('message467'),
            app.tr('settingsSearchStatsKeywords'),
            const StatsPage()),
        _Destination(
            'about',
            LucideIcons.info,
            app.tr('message468'),
            app.tr('message469'),
            app.tr('settingsSearchAboutKeywords'),
            const SettingsAboutPage()),
      ];

  List<_SettingsGroup> _groups(AppState app, List<_Destination> destinations) {
    final byId = {
      for (final destination in destinations) destination.id: destination
    };
    return [
      _SettingsGroup(
          'account',
          LucideIcons.userRound,
          app.tr('settingsGroupAccountFamily'),
          app.tr('settingsGroupAccountFamilyDescription'), [
        byId['account']!,
        byId['kids']!,
        byId['privacy']!,
      ]),
      _SettingsGroup(
          'watching',
          LucideIcons.play,
          app.tr('settingsGroupWatching'),
          app.tr('settingsGroupWatchingDescription'), [
        byId['playback']!,
        byId['subtitles']!,
        byId['downloads']!,
        byId['stats']!,
      ]),
      _SettingsGroup(
          'content',
          LucideIcons.layoutGrid,
          app.tr('settingsGroupContentServices'),
          app.tr('settingsGroupContentServicesDescription'), [
        byId['display']!,
        byId['catalogs']!,
        byId['addons']!,
        byId['services']!,
      ]),
      _SettingsGroup(
          'app',
          LucideIcons.palette,
          app.tr('settingsGroupAppPersonalization'),
          app.tr('settingsGroupAppPersonalizationDescription'), [
        byId['appearance']!,
        byId['cards']!,
        byId['language']!,
        byId['notifications']!,
        byId['about']!,
      ]),
    ];
  }

  void _openDestination(
      BuildContext context, _Destination destination, bool wide) {
    if (wide) {
      setState(() => _selected = destination.id);
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => destination.page));
    }
  }

  Widget _groupTile(
      BuildContext context, _SettingsGroup group, bool wide, String? selected) {
    final entries = <Widget>[
      for (final destination in group.destinations) ...[
        const Divider(height: 1, indent: 20, endIndent: 20),
        ColoredBox(
          color: wide && destination.id == selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : Colors.transparent,
          child: SettingsTile(
            icon: destination.icon,
            title: destination.title,
            subtitle: wide ? null : destination.description,
            onTap: () => _openDestination(context, destination, wide),
          ),
        ),
      ],
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Column(children: [
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        ExpansionTile(
          key: ValueKey('settings-group-${group.id}'),
          initiallyExpanded: wide && group.id == 'app',
          leading: Icon(group.icon,
              color: Theme.of(context).colorScheme.secondary, size: 22),
          title: Text(group.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(group.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          tilePadding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
          childrenPadding: const EdgeInsetsDirectional.only(bottom: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          children: entries,
        ),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppState, bool>((app) => app.english);
    final app = context.read<AppState>();
    final destinations = _destinations(app);
    final groups = _groups(app, destinations);
    final query = _query.trim().toLowerCase();
    final results = query.isEmpty
        ? const <(_Destination, _SettingsGroup)>[]
        : [
            for (final group in groups)
              for (final destination in group.destinations)
                if ('${group.title} ${destination.title} ${destination.description} ${destination.keywords}'
                    .toLowerCase()
                    .contains(query))
                  (destination, group),
          ];
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      final selected = destinations.where((d) => d.id == _selected).firstOrNull;
      final menu = ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
              wide ? 24 : 20,
              16,
              wide ? 24 : 20,
              widget.onOpenLibrary == null
                  ? 40
                  : glassDockContentClearance(context)),
          children: [
            SettingsPageIntro(
                title: app.tr('message470'), description: app.tr('message471')),
            TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                    hintText: app.tr('message472'),
                    prefixIcon: const Icon(LucideIcons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: app.tr('message473'),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(LucideIcons.x)))),
            const SizedBox(height: 24),
            if (widget.onOpenLibrary != null && query.isEmpty)
              Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 20),
                  child: SettingsTile(
                      icon: LucideIcons.bookmark,
                      title: app.tr('message474'),
                      onTap: widget.onOpenLibrary)),
            if (query.isEmpty)
              for (final group in groups)
                _groupTile(context, group, wide, _selected),
            if (query.isNotEmpty && results.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(24),
                  child: SettingsInfoBanner(
                      icon: LucideIcons.searchX,
                      message: app.tr('message475'))),
            for (final (destination, group) in results)
              Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 2),
                  child: Column(children: [
                    Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant),
                    ColoredBox(
                      color: wide && destination.id == _selected
                          ? Theme.of(context).colorScheme.surfaceContainerLow
                          : Colors.transparent,
                      child: SettingsTile(
                          icon: destination.icon,
                          title: destination.title,
                          subtitle:
                              '${group.title} · ${destination.description}',
                          onTap: () =>
                              _openDestination(context, destination, wide)),
                    ),
                  ])),
          ]);
      return Scaffold(
          appBar: AppBar(title: Text(app.tr('settings'))),
          body: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(width: 340, child: menu),
                  const VerticalDivider(width: 1),
                  Expanded(
                      child: selected?.page ??
                          const SettingsPersonalizationPage(
                              section: 'appearance')),
                ])
              : Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: menu)));
    });
  }
}
