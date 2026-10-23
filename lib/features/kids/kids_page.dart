import '../shell/nova_catalog_refresh.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/data/content_classifier.dart';
import '../../core/data/catalog_repository.dart';
import '../../core/state/app_state.dart';
import '../../shared/widgets/poster_card.dart';
import '../media/media_detail_page.dart';
import '../shell/noor_dock_tabs.dart';
import '../shell/nova_browse_widgets.dart';

/// A genre is not a safety classification. Unknown or adult certificates are
/// deliberately withheld; never infer suitability from artwork or a title.
bool novaIsChildRated(MediaItem item) => const {
      'g',
      'pg',
      'tv-y',
      'tv-y7',
      'tv-g',
      'tv-pg',
      'u',
      '0',
      '6',
      '7',
    }.contains(item.certification?.trim().toLowerCase());

class KidsPage extends StatefulWidget {
  const KidsPage({super.key});
  @override
  State<KidsPage> createState() => _KidsPageState();
}

class _KidsPageState extends State<KidsPage> with NovaCatalogRefresh<KidsPage> {
  @override
  void refreshCachedCatalogs() => _retry();

  late Future<List<MediaItem>> _content;
  String? _catalogSignature;
  String _filter = 'all';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.watch<AppState>();
    final signature = app.addons
        .map((addon) =>
            '${addon.id}:${addon.enabled}:${addon.catalogs.map((catalog) => '${catalog.type}:${catalog.id}:${catalog.name}').join(',')}')
        .join('|');
    if (_catalogSignature != signature) {
      _catalogSignature = signature;
      _content = _loadContent();
    }
  }

  Future<List<MediaItem>> _loadContent() async {
    final app = context.read<AppState>();
    Future<(List<MediaItem>, bool)> load(Future<List<MediaItem>> source) async {
      try {
        return (await source, true);
      } catch (_) {
        return (<MediaItem>[], false);
      }
    }

    final familyRows = CatalogRepository.selectAddonCatalogRows(app.addons)
        .where((row) => RegExp(
                r'anime|animation|kids|family|children|طفل|أطفال|عائل',
                caseSensitive: false)
            .hasMatch('${row.catalog.id} ${row.title}'))
        .where((row) => !RegExp(r'anime|أنمي', caseSensitive: false)
            .hasMatch('${row.catalog.id} ${row.title}'));
    final groups = await Future.wait([
      load(app.catalogs.kids()),
      load(app.catalogs.kids(series: true)),
      for (final row in familyRows)
        load(app.catalogs
            .catalog(row.catalog.type, row.catalog.id, addon: row.addon)),
    ]);
    if (groups.every((group) => !group.$2)) {
      throw StateError('Kids catalogs are unavailable');
    }
    final seen = <String>{};
    final candidates = groups
        .expand((group) => group.$1)
        .where((item) => seen.add(item.id))
        .toList();
    final safe = candidates.where(ContentClassifier.isKidSuitable).toList();
    final unknown = candidates
        .where((item) =>
            item.certification == null &&
            !ContentClassifier.isKidSuitable(item))
        .toList();
    // Bounded concurrency; an incomplete catalog can supply its certificate
    // through detail metadata. Failed/uncertified entries remain hidden.
    for (var i = 0; i < unknown.length; i += 6) {
      if (safe.length >= 48) break;
      final batch = await Future.wait(unknown.skip(i).take(6).map((item) async {
        try {
          return await app.catalogs
              .detail(item.type, item.id, app.addons)
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          return null;
        }
      }));
      safe.addAll(
          batch.whereType<MediaItem>().where(ContentClassifier.isKidSuitable));
    }
    return {for (final item in safe) item.id: item}.values.toList();
  }

  void _retry() => setState(() => _content = _loadContent());

  @override
  Widget build(BuildContext context) {
    context.select<AppState, bool>((app) => app.english);
    final cardSize = context.select<AppState, String>(
        (app) => app.webSettings['kidsCardSize']?.toString() ?? 'medium');
    final preferredWidth = cardSize == 'large'
        ? 220.0
        : cardSize == 'small'
            ? 140.0
            : 170.0;
    final app = context.read<AppState>();
    final theme = Theme.of(context);
    return FutureBuilder<List<MediaItem>>(
        future: _content,
        builder: (context, snapshot) {
          final all = snapshot.data ?? const <MediaItem>[];
          final items = all
              .where((item) => _filter == 'all' || item.type == _filter)
              .toList();
          final featuredItem = items
                  .where((item) => item.background?.trim().isNotEmpty == true)
                  .firstOrNull ??
              items.firstOrNull;
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
                child: ColoredBox(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            24, 32, 24, 24),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(LucideIcons.sparkles,
                                    color: theme.colorScheme.onPrimaryContainer,
                                    size: 32),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(app.tr('message596'),
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                                color: theme.colorScheme
                                                    .onPrimaryContainer,
                                                fontWeight: FontWeight.w800))),
                                Icon(LucideIcons.shieldCheck,
                                    color: theme.colorScheme.onPrimaryContainer)
                              ]),
                              const SizedBox(height: 24),
                              Text(app.tr('message597'),
                                  style: theme.textTheme.headlineLarge
                                      ?.copyWith(
                                          color: theme
                                              .colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w900,
                                          height: 1.25)),
                              const SizedBox(height: 16),
                              Text(app.tr('message598'),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme
                                          .colorScheme.onPrimaryContainer)),
                            ])))),
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final filter in [
                        ('all', app.tr('message599'), LucideIcons.sparkles),
                        ('movie', app.tr('message600'), LucideIcons.film),
                        ('series', app.tr('message601'), LucideIcons.tv),
                      ])
                        ChoiceChip(
                            avatar: Icon(filter.$3, size: 22),
                            label: Text(filter.$2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            selected: _filter == filter.$1,
                            onSelected: (_) =>
                                setState(() => _filter = filter.$1))
                    ]))),
            if (featuredItem != null)
              SliverToBoxAdapter(
                child: NovaBrowseFeature(
                  item: featuredItem,
                  label: app.tr('message596'),
                  actionLabel: app.tr('message131'),
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MediaDetailPage(
                        item: featuredItem,
                        kidsMode: true,
                      ),
                    ),
                  ),
                ),
              ),
            if (snapshot.connectionState == ConnectionState.waiting &&
                all.isEmpty)
              const SliverToBoxAdapter(
                  child: SizedBox(height: 480, child: NovaBrowseSkeleton()))
            else if (items.isEmpty)
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(children: [
                        Icon(
                            snapshot.hasError
                                ? LucideIcons.cloudOff
                                : LucideIcons.shieldCheck,
                            size: 56,
                            color: theme.colorScheme.secondary),
                        const SizedBox(height: 24),
                        Text(
                            snapshot.hasError
                                ? app.tr('message602')
                                : app.tr('message603'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        Text(app.tr('message604'), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                            onPressed: _retry,
                            icon: const Icon(LucideIcons.refreshCw),
                            label: Text(app.tr('message174'))),
                      ])))
            else
              SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
                  sliver: SliverLayoutBuilder(builder: (context, constraints) {
                    final columns =
                        (constraints.crossAxisExtent / preferredWidth)
                            .floor()
                            .clamp(2, 6);
                    final width =
                        (constraints.crossAxisExtent - (columns - 1) * 20) /
                            columns;
                    return SliverGrid.builder(
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisExtent: width / .72 +
                                86 * MediaQuery.textScalerOf(context).scale(1),
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 24),
                        itemBuilder: (context, index) => PosterCard(
                            item: items[index],
                            width: width,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => MediaDetailPage(
                                        item: items[index], kidsMode: true)))));
                  })),
            SliverToBoxAdapter(
                child: SizedBox(height: glassDockContentClearance(context))),
          ]);
        });
  }
}
