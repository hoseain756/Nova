import 'package:nova_mobile/l10n/nova_strings.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/catalog_repository.dart';
import '../../core/models/media_item.dart';
import '../../core/models/visual_preferences.dart';
import '../../core/state/app_state.dart';
import '../shell/nova_browse_widgets.dart';
import '../../shared/widgets/poster_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../media/media_detail_page.dart';

/// Live anime search over AniList's public GraphQL (works without linking).
/// Debounced, poster-grid results; tapping a result resolves it to a
/// playable Stremio entry and opens the shared detail page.
Future<void> showAnimeSearchSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 960),
    builder: (_) => const _AnimeSearchSheet(),
  );
}

class _AnimeSearchSheet extends StatefulWidget {
  const _AnimeSearchSheet();

  @override
  State<_AnimeSearchSheet> createState() => _AnimeSearchSheetState();
}

class _AnimeSearchSheetState extends State<_AnimeSearchSheet> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  Future<List<MediaItem>>? _results;
  final Set<String> _resolving = {};

  /// Which provider's catalog the sheet is querying — both searches are
  /// public (no link required) and parse through the same shared row shape.
  String _provider = 'anilist';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() => _results = _search(value.trim()));
    });
  }

  /// Switching provider re-runs the current query immediately so the grid
  /// reflects the other catalog without requiring a re-type.
  void _switchProvider(String provider) {
    if (provider == _provider) return;
    setState(() {
      _provider = provider;
      final term = _query.text.trim();
      _results = term.isEmpty ? null : _search(term);
    });
  }

  Future<List<MediaItem>> _search(String term) async {
    final app = context.read<AppState>();
    final rows = _provider == 'mal'
        ? await app.api.malSearch(term, limit: 30)
        : await app.api.aniListSearch(term, perPage: 30);
    if (!mounted) return const [];
    // 122 follow-up: honor the ja native-title preference here too, matching
    // the repository's AniList catalog/meta paths.
    return CatalogRepository.parseAnimeResponse(
      {
        'data': {
          'Page': {'media': rows},
        },
      },
      preferNativeTitles: app.catalogs.prefersNativeAnimeTitles(),
    );
  }

  Future<void> _open(MediaItem item) async {
    if (!_resolving.add(item.id)) return;
    setState(() {});
    try {
      final app = context.read<AppState>();
      final resolved = await app.catalogs.resolveAnime(item);
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

  @override
  Widget build(BuildContext context) {
    context.select<AppState, bool>((a) => a.english);
    final app = context.read<AppState>();
    final theme = Theme.of(context);
    final cards = context.select<AppState, CardPreferences>(
        (app) => CardPreferences.fromSettings(app.webSettings));
    final dimensions = cards.dimensions(MediaQuery.sizeOf(context).width);
    return NovaBrowseSheet(slivers: [
      SliverToBoxAdapter(
          child: NovaBrowseSheetHeading(
        title: app.tr('message536'),
        closeLabel: app.tr('close'),
        onClose: () => Navigator.pop(context),
      )),
      SliverPadding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
        sliver: SliverToBoxAdapter(
            child: TextField(
          controller: _query,
          focusNode: _focus,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(LucideIcons.search),
            hintText: app.tr('message537'),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: app.tr('message473'),
                    icon: const Icon(LucideIcons.x),
                    onPressed: () {
                      _query.clear();
                      _onChanged('');
                    },
                  ),
          ),
        )),
      ),
      SliverPadding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
        sliver: SliverToBoxAdapter(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final provider in [
            ('anilist', 'AniList'),
            ('mal', 'MyAnimeList')
          ])
            ChoiceChip(
                label: Text(provider.$2),
                selected: _provider == provider.$1,
                onSelected: (_) => _switchProvider(provider.$1)),
        ])),
      ),
      if (_results == null)
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            Icon(LucideIcons.sparkles,
                size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 20),
            Text(app.tr('message538'),
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(app.tr('message539'), textAlign: TextAlign.center),
          ]),
        ))
      else
        FutureBuilder<List<MediaItem>>(
          future: _results,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                  child: SizedBox(height: 440, child: NovaBrowseSkeleton()));
            }
            final items = snapshot.data ?? const <MediaItem>[];
            if (snapshot.hasError || items.isEmpty) {
              return SliverToBoxAdapter(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Text(
                      snapshot.hasError
                          ? app.tr('message540')
                          : app.tr('message541'),
                      textAlign: TextAlign.center),
                  if (snapshot.hasError) ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => setState(
                          () => _results = _search(_query.text.trim())),
                      child: Text(app.tr('message174')),
                    ),
                  ],
                ]),
              ));
            }
            return SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
              sliver: SliverLayoutBuilder(builder: (context, constraints) {
                final columns = dimensions
                    .gridColumns(constraints.crossAxisExtent, gap: 16);
                final width = dimensions.gridCellWidth(
                    constraints.crossAxisExtent, columns,
                    gap: 16);
                final scale = MediaQuery.textScalerOf(context).scale(1);
                return SliverGrid.builder(
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: cards.isHorizontal
                        ? dimensions.horizontalExtent(width, scale)
                        : width / CardDimensions.verticalArtworkRatio +
                            78 * scale,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 16,
                  ),
                  itemBuilder: (_, i) => Stack(children: [
                    PosterCard(
                        item: items[i],
                        width: width,
                        onTap: () => _open(items[i])),
                    if (_resolving.contains(items[i].id))
                      const PositionedDirectional(
                          top: 8,
                          end: 8,
                          child: SizedBox.square(
                              dimension: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))),
                  ]),
                );
              }),
            );
          },
        ),
    ]);
  }
}
