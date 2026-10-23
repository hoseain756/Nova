import 'dart:async';

import 'package:nova_mobile/l10n/nova_strings.dart';
import '../shell/nova_catalog_refresh.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/data/catalog_repository.dart';
import '../../core/data/content_classifier.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/horse_theme.dart';
import '../../shared/widgets/media_rail.dart';
import '../settings/integrations_page.dart';
import '../shell/nova_browse_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../shell/noor_dock_tabs.dart';
import '../media/media_detail_page.dart';
import '../catalog/catalog_grid_page.dart';
import '../home/widgets/continue_watching_rail.dart';
import 'anime_search_sheet.dart';

class AnimePage extends StatefulWidget {
  const AnimePage({super.key});

  @override
  State<AnimePage> createState() => _AnimePageState();
}

class _AnimePageState extends State<AnimePage>
    with NovaCatalogRefresh<AnimePage> {
  @override
  void refreshCachedCatalogs() => _retry();

  late Future<List<MediaItem>> _items;
  List<AddonCatalogRow> _addonRows = const [];
  final Map<String, Future<List<MediaItem>>> _addonFutures = {};
  Future<List<MediaItem>>? _addonHeroItems;
  String? _catalogSignature;
  final Set<String> _resolving = {};
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _items = app.catalogs.anime();
    unawaited(app.refreshLinkedContent());
  }

  void _retry() {
    final app = context.read<AppState>();
    setState(() {
      _items = app.catalogs.anime();
      _catalogSignature = null;
      _loadAddonRows(app);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.watch<AppState>();
    final signature = [
      app.addons
          .map((addon) =>
              '${addon.id}:${addon.enabled}:${addon.catalogs.map((catalog) => '${catalog.type}:${catalog.id}:${catalog.name}').join(',')}')
          .join('|'),
      app.webSettings['catalogRowOrder'],
      app.webSettings['catalogRowHidden'],
    ].join('|');
    if (_catalogSignature != signature) {
      _catalogSignature = signature;
      _loadAddonRows(app);
    }
  }

  void _loadAddonRows(AppState app) {
    _addonRows = CatalogRepository.selectAddonCatalogRows(
      app.addons,
      order: (app.webSettings['catalogRowOrder'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      hidden: (app.webSettings['catalogRowHidden'] as List? ?? const [])
          .map((value) => value.toString())
          .toSet(),
    );
    _addonFutures
      ..clear()
      ..addEntries(_addonRows.map((row) => MapEntry(
            row.key,
            app.catalogs
                .catalog(row.catalog.type, row.catalog.id, addon: row.addon)
                .then((items) => items
                    .where((item) =>
                        ContentClassifier.isAnime(item) ||
                        CatalogRepository.isAnimeCatalog(row))
                    .toList()),
          )));
    _addonHeroItems = Future.wait(_addonFutures.values.map(
      (future) => future.catchError((Object _) => <MediaItem>[]),
    )).then((groups) => groups.expand((group) => group).toList());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final english = app.english;
    // Personal lists from the LINKED AniList account — CURRENT becomes the
    // "watching" rail, PLANNING the "plan to watch" rail (the same rows the
    // home page uses, scoped here so the tab is self-sufficient).
    final watching =
        app.linkedCatalogItems['anilist-watching'] ?? const <MediaItem>[];
    final planning = app.linkedCatalogItems['anilist'] ?? const <MediaItem>[];
    final anilistLinked = app.linkedServices['anilist']?['linked'] == true;
    final watchingProgress = app.linkedContinueWatching
        .where((entry) => entry.item.type == 'series')
        .toList(growable: false);
    // Keep the canvas painted across loading, catalog refreshes, and scrolling.
    // The surrounding shell is edge-to-edge and the slivers are transparent;
    // without an explicit page surface, Android can expose its black window
    // background while this tab transitions between catalog states.
    return ColoredBox(
      key: const ValueKey('anime-catalog-canvas'),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: FutureBuilder<List<MediaItem>>(
        future: _items,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <MediaItem>[];
          final series = items.where((item) => item.type == 'series').toList();
          final movies = items.where((item) => item.type == 'movie').toList();
          final filteredItems = items
              .where((item) => _filter == 'all' || item.type == _filter)
              .toList();
          final featuredItem = filteredItems
                  .where((item) => item.background?.trim().isNotEmpty == true)
                  .firstOrNull ??
              filteredItems.firstOrNull;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: NovaBrowseHeader(
                eyebrow: app.tr('message521'),
                title: app.tr('message522'),
                subtitle: app.tr('message523'),
                actions: [
                  FilledButton.tonalIcon(
                      onPressed: () => showAnimeSearchSheet(context),
                      icon: const Icon(LucideIcons.search),
                      label: Text(app.tr('message524')))
                ],
              )),
              SliverToBoxAdapter(
                  child: Padding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final entry in [
                          ('all', app.tr('message525')),
                          ('series', app.tr('message107')),
                          ('movie', app.tr('message526')),
                        ])
                          ChoiceChip(
                              label: Text(entry.$2),
                              selected: _filter == entry.$1,
                              onSelected: (_) =>
                                  setState(() => _filter = entry.$1))
                      ]))),
              if (featuredItem != null)
                SliverToBoxAdapter(
                    child: NovaBrowseFeature(
                  item: featuredItem,
                  label: app.tr('message130'),
                  actionLabel: app.tr('message527'),
                  onOpen: () => _open(featuredItem),
                )),
              if (featuredItem == null && _addonHeroItems != null)
                SliverToBoxAdapter(
                  child: FutureBuilder<List<MediaItem>>(
                    future: _addonHeroItems,
                    builder: (context, result) {
                      final candidates = (result.data ?? const <MediaItem>[])
                          .where((item) =>
                              _filter == 'all' || item.type == _filter)
                          .toList();
                      final featured = candidates
                              .where((item) =>
                                  item.background?.trim().isNotEmpty == true)
                              .firstOrNull ??
                          candidates.firstOrNull;
                      if (featured == null) return const SizedBox.shrink();
                      return NovaBrowseFeature(
                        item: featured,
                        label: app.tr('message130'),
                        actionLabel: app.tr('message527'),
                        onOpen: () => _open(featured),
                      );
                    },
                  ),
                ),
              // Personal AniList rails — rendered above the public catalogs
              // so the linked account's own lists lead the tab. `anilist:`
              // identities resolve through _open like every other card.
              if (_filter == 'all' && watchingProgress.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      bottom: MediaRail.sectionSpacing(context),
                    ),
                    child: IntegrationContinueWatchingRail(
                      entries: watchingProgress,
                      english: english,
                    ),
                  ),
                ),
              if (_filter == 'all' && anilistLinked && watching.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      bottom: MediaRail.sectionSpacing(context),
                    ),
                    child: MediaRail(
                      title: NovaStrings.lookup(english, 'message528'),
                      items: watching,
                      onTap: _open,
                    ),
                  ),
                ),
              if (_filter == 'all' && anilistLinked && planning.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      bottom: MediaRail.sectionSpacing(context),
                    ),
                    child: MediaRail(
                      title: NovaStrings.lookup(english, 'message529'),
                      items: planning,
                      onTap: _open,
                    ),
                  ),
                ),
              if (_filter == 'all' && !anilistLinked)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 18),
                    child: _AniListLinkPrompt(),
                  ),
                ),
              for (final row in _addonRows.where(
                  (row) => _filter == 'all' || row.catalog.type == _filter))
                SliverToBoxAdapter(
                  child: FutureBuilder<List<MediaItem>>(
                    future: _addonFutures[row.key],
                    builder: (context, result) {
                      final catalogItems = result.data ?? const <MediaItem>[];
                      if (catalogItems.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsetsDirectional.only(
                            bottom: MediaRail.sectionSpacing(context)),
                        child: MediaRail(
                          title: row
                              .displayTitle(app.webSettings['catalogRowNames']),
                          items: catalogItems,
                          onTap: _open,
                          onOpenSection: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => CatalogGridPage(
                                      title: row.displayTitle(
                                          app.webSettings['catalogRowNames']),
                                      subtitle: row.subtitle,
                                      items: catalogItems,
                                      onOpen: _open,
                                    )),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  items.isEmpty)
                const SliverToBoxAdapter(
                    child: SizedBox(height: 440, child: NovaBrowseSkeleton()))
              else if (items.isEmpty)
                SliverToBoxAdapter(
                  child: FutureBuilder<List<MediaItem>>(
                    future: _addonHeroItems,
                    builder: (context, result) {
                      if (result.connectionState != ConnectionState.done ||
                          (result.data ?? const <MediaItem>[]).any((item) =>
                              _filter == 'all' || item.type == _filter)) {
                        return const SizedBox.shrink();
                      }
                      return _CatalogState(
                        icon: snapshot.hasError
                            ? LucideIcons.cloudOff
                            : LucideIcons.searchX,
                        message: NovaStrings.lookup(english,
                            snapshot.hasError ? 'message530' : 'message531'),
                        actionLabel: NovaStrings.lookup(english,
                            snapshot.hasError ? 'message120' : 'message68'),
                        onRetry: _retry,
                      );
                    },
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      bottom: MediaRail.sectionSpacing(context),
                    ),
                    child: MediaRail(
                      title: NovaStrings.lookup(english, 'message113'),
                      items: items
                          .where((item) =>
                              _filter == 'all' || item.type == _filter)
                          .take(14)
                          .toList(),
                      onTap: _open,
                    ),
                  ),
                ),
                if (_filter != 'movie' && series.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        bottom: MediaRail.sectionSpacing(context),
                      ),
                      child: MediaRail(
                        title: NovaStrings.lookup(english, 'message532'),
                        items: series,
                        onTap: _open,
                      ),
                    ),
                  ),
                if (_filter != 'series' && movies.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        bottom: MediaRail.sectionSpacing(context),
                      ),
                      child: MediaRail(
                        title: NovaStrings.lookup(english, 'message114'),
                        items: movies,
                        onTap: _open,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: glassDockContentClearance(context),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _open(MediaItem item) async {
    if (!_resolving.add(item.id)) return;
    setState(() {});
    try {
      final app = context.read<AppState>();
      final resolved =
          item.id.startsWith('anilist:') || item.id.startsWith('mal:')
              ? await app.catalogs.resolveAnime(item)
              : item;
      if (!mounted) return;
      if (resolved == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(NovaStrings.lookup(app.english, 'message117')),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          // Carry the AniList/MAL identity onto the playable item so
          // library toggles and playback mirror to the linked trackers.
          builder: (_) => MediaDetailPage(
            item: resolved.withAnimeIds(
              anilistId: item.anilistId,
              idMal: item.idMal,
            ),
          ),
        ),
      );
    } finally {
      _resolving.remove(item.id);
      if (mounted) setState(() {});
    }
  }
}

class _CatalogState extends StatelessWidget {
  const _CatalogState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          // Compact (not viewport-filling): the tab now always carries a
          // personal section above (rails or the link prompt), so a full-
          // screen state would push the public rails out of reach.
          padding: const EdgeInsetsDirectional.fromSTEB(28, 8, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: NovaTheme.of(context).gold),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null && actionLabel != null) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(LucideIcons.refreshCw),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
}

/// Invitation shown on the Anime tab while no AniList account is linked:
/// one tap jumps straight into the integrations page — after linking, the
/// card is replaced by the personal watching/planning rails above.
class _AniListLinkPrompt extends StatelessWidget {
  const _AniListLinkPrompt();

  @override
  Widget build(BuildContext context) {
    final english = context.watch<AppState>().english;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: .55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NovaColors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: NovaTheme.of(context).gold.withValues(alpha: .14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.sparkles,
                  size: 22,
                  color: NovaTheme.of(context).gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  NovaStrings.lookup(english, 'message533'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            NovaStrings.lookup(english, 'message534'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: NovaTheme.of(context).muted),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonal(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const IntegrationsPage(),
                ),
              ),
              child: Text(NovaStrings.lookup(english, 'message535')),
            ),
          ),
        ],
      ),
    );
  }
}
