import 'package:nova_mobile/l10n/nova_strings.dart';
import '../shell/nova_catalog_refresh.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/nova_theme.dart';
import '../../shared/widgets/app_state_message.dart';
import '../../shared/widgets/poster_card.dart';
import '../media/media_detail_page.dart';
import '../shell/nova_browse_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CatalogBrowserPage extends StatefulWidget {
  const CatalogBrowserPage({super.key, this.initialType = 'all'});

  final String initialType;

  @override
  State<CatalogBrowserPage> createState() => _CatalogBrowserPageState();
}

class _CatalogBrowserPageState extends State<CatalogBrowserPage>
    with NovaCatalogRefresh<CatalogBrowserPage> {
  @override
  void refreshCachedCatalogs() {
    if (!_loading) unawaited(_load(query: _search.text.trim()));
  }

  final _search = TextEditingController();
  Timer? _debounce;
  List<MediaItem> _items = const [];
  bool _loading = true;
  String? _error;
  String _loadedQuery = '';
  late String _typeFilter;
  String _sort = 'popular';
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _typeFilter = widget.initialType;
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_load(query: value.trim()));
    });
  }

  int _yearOf(MediaItem item) {
    final value = item.releaseDate ?? item.releaseInfo ?? '';
    return int.tryParse(RegExp(r'\d{4}').firstMatch(value)?.group(0) ?? '') ??
        0;
  }

  Future<List<MediaItem>> _safe(Future<List<MediaItem>> future) async {
    try {
      return await future;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _load({String query = ''}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      if (query != _loadedQuery) _items = const [];
    });
    final app = context.read<AppState>();
    final catalog = app.catalogs;
    final searchQuery = query.length >= 2 ? query : null;
    final jobs = <Future<List<MediaItem>>>[];

    if (searchQuery == null) {
      jobs.add(catalog.homeTopTen());
      jobs.add(catalog.catalog('movie', 'top'));
      jobs.add(catalog.catalog('series', 'top'));
      jobs.add(catalog.addonCatalogs(app.addons));
    } else {
      jobs.add(
          catalog.catalog('movie', 'top', extras: {'search': searchQuery}));
      jobs.add(
          catalog.catalog('series', 'top', extras: {'search': searchQuery}));
    }

    final results = List<List<MediaItem>?>.filled(jobs.length, null);
    final normalizedQuery = query.toLowerCase();
    void publish() {
      if (!mounted || request != _request) return;
      final seen = <String>{};
      final hideWatched = app.webSettings['hideWatchedInCatalogs'] == true;
      final watchedIds = app.history.map((entry) => entry.item.id).toSet();
      final items = results
          .whereType<List<MediaItem>>()
          .expand((rows) => rows)
          .where((item) {
        if (query.isNotEmpty &&
            !item.name.toLowerCase().contains(normalizedQuery)) {
          return false;
        }
        if (hideWatched && watchedIds.contains(item.id)) return false;
        return seen.add(item.id);
      }).toList();
      final complete = results.every((rows) => rows != null);
      setState(() {
        _items = items;
        _loadedQuery = query;
        _loading = !complete;
        if (complete && items.isEmpty) {
          _error = NovaStrings.lookup(app.english, 'message580');
        }
      });
    }

    // Render each completed source immediately; keep source order and the
    // final deduplication stable even when add-ons respond out of order.
    await Future.wait([
      for (var index = 0; index < jobs.length; index++)
        _safe(jobs[index]).then((rows) {
          results[index] = rows;
          publish();
        }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppState, bool>((app) => app.english);
    final app = context.read<AppState>();
    final items = _items
        .where((item) => _typeFilter == 'all' || item.type == _typeFilter)
        .toList();
    switch (_sort) {
      case 'title':
        items.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'year':
        items.sort((a, b) => _yearOf(b).compareTo(_yearOf(a)));
      case 'rating':
        items.sort((a, b) => (double.tryParse(b.rating ?? '') ?? 0)
            .compareTo(double.tryParse(a.rating ?? '') ?? 0));
    }
    return Scaffold(
      appBar: AppBar(title: Text(app.tr('message582'))),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: RefreshIndicator(
          onRefresh: () => _load(query: _search.text.trim()),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
                child: NovaBrowseHeader(
              compact: true,
              eyebrow: app.tr('message583'),
              title: app.tr('message576'),
              subtitle: app.tr('message585'),
            )),
            SliverToBoxAdapter(
                child: Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
                    child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: TextField(
                              controller: _search,
                              onChanged: _onSearch,
                              onSubmitted: (value) {
                                _debounce?.cancel();
                                unawaited(_load(query: value.trim()));
                              },
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: NovaSpace.md,
                                    vertical: NovaSpace.md),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)),
                                prefixIcon: const Icon(LucideIcons.search),
                                hintText: app.tr('message586'),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: app.tr('message473'),
                                        onPressed: () {
                                          _search.clear();
                                          _debounce?.cancel();
                                          unawaited(_load());
                                          setState(() {});
                                        },
                                        icon: const Icon(LucideIcons.x)),
                              ),
                            ))))),
            SliverToBoxAdapter(
                child: Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
                    child: Wrap(
                        spacing: NovaSpace.md,
                        runSpacing: NovaSpace.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Wrap(spacing: NovaSpace.sm, children: [
                            for (final entry in [
                              ('all', app.tr('message587')),
                              ('movie', app.tr('message106')),
                              ('series', app.tr('message107'))
                            ])
                              ChoiceChip(
                                  avatar: Icon(
                                      switch (entry.$1) {
                                        'movie' => LucideIcons.film,
                                        'series' => LucideIcons.tv,
                                        _ => LucideIcons.layoutGrid,
                                      },
                                      size: 16),
                                  label: Text(entry.$2),
                                  selected: _typeFilter == entry.$1,
                                  selectedColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  showCheckmark: false,
                                  onSelected: (_) =>
                                      setState(() => _typeFilter = entry.$1)),
                          ]),
                          SizedBox(
                              width: 208,
                              child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _sort,
                                  decoration: InputDecoration(
                                      labelText: app.tr('message588'),
                                      isDense: true,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _sort = value);
                                    }
                                  },
                                  items: [
                                    for (final entry in [
                                      ('popular', app.tr('message589')),
                                      ('rating', app.tr('message158')),
                                      ('year', app.tr('message441')),
                                      ('title', app.tr('message440'))
                                    ])
                                      DropdownMenuItem(
                                          value: entry.$1,
                                          child: Text(entry.$2,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis))
                                  ])),
                        ]))),
            if (_loading && _items.isEmpty)
              const SliverToBoxAdapter(
                  child: SizedBox(height: 600, child: NovaBrowseSkeleton()))
            else if (items.isEmpty)
              SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppStateMessage(
                      icon: _error != null
                          ? LucideIcons.cloudOff
                          : LucideIcons.search,
                      message: _error ?? app.tr('message590'),
                      actionLabel: app.tr('message174'),
                      onAction: () =>
                          unawaited(_load(query: _search.text.trim()))))
            else ...[
              if (_loading)
                const SliverToBoxAdapter(
                    child: LinearProgressIndicator(minHeight: 2)),
              SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 48),
                  sliver: SliverLayoutBuilder(builder: (context, constraints) {
                    final columns =
                        (constraints.crossAxisExtent / 190).floor().clamp(2, 7);
                    final width =
                        (constraints.crossAxisExtent - (columns - 1) * 20) /
                            columns;
                    return SliverGrid.builder(
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisExtent: width / .72 +
                                78 * MediaQuery.textScalerOf(context).scale(1),
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 24),
                        itemBuilder: (context, index) => PosterCard(
                            item: items[index],
                            width: width,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        MediaDetailPage(item: items[index])))));
                  })),
            ],
          ]),
        ),
      )),
    );
  }
}
