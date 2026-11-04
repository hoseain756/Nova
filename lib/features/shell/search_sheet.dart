import 'nova_catalog_refresh.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/models/visual_preferences.dart';
import '../../core/state/app_state.dart';
import '../../shared/widgets/poster_card.dart';
import '../calendar/calendar_page.dart';
import '../catalog/catalog_browser_page.dart';
import '../downloads/downloads_page.dart';
import '../live_tv/live_tv_page.dart';
import '../media/media_detail_page.dart';
import '../settings/addons_page.dart';
import '../settings/stats_page.dart';
import 'nova_browse_widgets.dart';

class SearchSheet extends StatefulWidget {
  const SearchSheet({super.key});
  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet>
    with NovaCatalogRefresh<SearchSheet> {
  @override
  void refreshCachedCatalogs() {
    final query = _controller.text.trim();
    if (!_loading && query.length >= 2) unawaited(_search(query));
  }

  final _controller = TextEditingController();
  final Map<String, List<MediaItem>> _cache = {};
  Timer? _timer;
  bool _loading = false;
  bool _failed = false;
  List<MediaItem> _results = [];
  int _request = 0;
  String _type = 'all';

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    ++_request; // An in-flight old query can never overwrite the latest input.
    final query = value.trim();
    setState(() {
      _failed = false;
      _results = _cache[query.toLowerCase()] ?? [];
      _loading = query.length >= 2;
    });
    if (query.length < 2) return;
    _timer = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final token = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final catalogs = context.read<AppState>().catalogs;
    var failures = 0;
    final results = await Future.wait([
      catalogs.catalog('movie', 'top', extras: {'search': query}),
      catalogs.catalog('series', 'top', extras: {'search': query}),
    ].map((job) async {
      try {
        return await job;
      } catch (_) {
        failures++;
        return <MediaItem>[];
      }
    }));
    if (!mounted || token != _request) return;
    final seen = <String>{};
    setState(() {
      _results = results
          .expand((e) => e)
          .where((e) => seen.add(e.id))
          .take(60)
          .toList();
      _loading = false;
      _failed = failures == 2;
      if (!_failed) _cache[query.toLowerCase()] = _results;
      if (_cache.length > 12) _cache.remove(_cache.keys.first);
    });
  }

  void _openPage(Widget page) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppState, bool>((a) => a.english);
    final app = context.read<AppState>();
    final theme = Theme.of(context);
    final searching = _controller.text.trim().length >= 2;
    final items =
        _results.where((item) => _type == 'all' || item.type == _type).toList();
    final shortcuts = <(IconData, String, String, Widget)>[
      (
        LucideIcons.compass,
        app.tr('message576'),
        app.tr('message682'),
        const CatalogBrowserPage()
      ),
      (
        LucideIcons.radio,
        app.tr('message658'),
        app.tr('message686'),
        const LiveTvPage()
      ),
      (
        LucideIcons.calendarDays,
        app.tr('message565'),
        app.tr('message687'),
        const CalendarPage()
      ),
      (
        LucideIcons.download,
        app.tr('downloads'),
        app.tr('message688'),
        const DownloadsPage()
      ),
      (
        LucideIcons.chartNoAxesCombined,
        app.tr('message689'),
        app.tr('message690'),
        const StatsPage()
      ),
      (
        LucideIcons.puzzle,
        app.tr('message220'),
        app.tr('message691'),
        const AddonsPage()
      ),
    ];
    final cards = context.select<AppState, CardPreferences>(
        (app) => CardPreferences.fromSettings(app.webSettings));
    final dimensions = cards.dimensions(MediaQuery.sizeOf(context).width);
    return NovaBrowseSheet(slivers: [
      SliverToBoxAdapter(
          child: NovaBrowseSheetHeading(
        title: app.tr('message682'),
        closeLabel: app.tr('message692'),
        onClose: () => Navigator.pop(context),
      )),
      SliverPadding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 20),
        sliver: SliverToBoxAdapter(
            child: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          onSubmitted: (value) {
            _timer?.cancel();
            if (value.trim().length >= 2) unawaited(_search(value.trim()));
          },
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(LucideIcons.search),
            hintText: app.tr('message693'),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: app.tr('message473'),
                    icon: const Icon(LucideIcons.x),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
        )),
      ),
      if (searching)
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 20),
          sliver: SliverToBoxAdapter(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final option in [
              ('all', app.tr('message587')),
              ('movie', app.tr('message577')),
              ('series', app.tr('message578')),
            ])
              ChoiceChip(
                  label: Text(option.$2),
                  selected: _type == option.$1,
                  onSelected: (_) => setState(() => _type = option.$1)),
          ])),
        ),
      if (!searching)
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
          sliver: SliverToBoxAdapter(
              child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            return Wrap(spacing: 40, children: [
              for (final shortcut in shortcuts)
                SizedBox(
                  width: wide
                      ? (constraints.maxWidth - 40) / 2
                      : constraints.maxWidth,
                  child: Column(children: [
                    NovaBrowseDestination(
                        icon: shortcut.$1,
                        title: shortcut.$2,
                        subtitle: shortcut.$3,
                        onTap: () => _openPage(shortcut.$4)),
                    const Divider(height: 1),
                  ]),
                ),
            ]);
          })),
        )
      else if (_loading && items.isEmpty)
        const SliverToBoxAdapter(
            child: SizedBox(height: 440, child: NovaBrowseSkeleton()))
      else if (items.isEmpty)
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            Icon(_failed ? LucideIcons.wifiOff : LucideIcons.search,
                size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 20),
            Text(_failed ? app.tr('message694') : app.tr('message695'),
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(_failed ? app.tr('message696') : app.tr('message697'),
                textAlign: TextAlign.center),
            if (_failed) ...[
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: () => _search(_controller.text.trim()),
                  child: Text(app.tr('message174'))),
            ],
          ]),
        ))
      else
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
          sliver: SliverLayoutBuilder(builder: (context, constraints) {
            final columns =
                dimensions.gridColumns(constraints.crossAxisExtent, gap: 16);
            final width = dimensions
                .gridCellWidth(constraints.crossAxisExtent, columns, gap: 16);
            final scale = MediaQuery.textScalerOf(context).scale(1);
            return SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: cards.isHorizontal
                    ? dimensions.horizontalExtent(width, scale)
                    : width / CardDimensions.verticalArtworkRatio + 78 * scale,
                crossAxisSpacing: 16,
                mainAxisSpacing: 24,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => PosterCard(
                  item: items[index],
                  width: width,
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              MediaDetailPage(item: items[index])))),
            );
          }),
        ),
    ]);
  }
}
