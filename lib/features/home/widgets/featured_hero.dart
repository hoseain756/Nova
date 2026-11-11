import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/featured_artwork.dart';
import '../../../core/models/media_item.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/widgets/image_decode.dart';
import '../../../shared/widgets/media_hero.dart';
import '../../../shared/widgets/nova_network_image.dart';
import '../../../shared/widgets/shimmer_box.dart';

/// Manual selection stays local to this destination when a detail route opens.
class FeaturedHero extends StatefulWidget {
  const FeaturedHero(
      {super.key,
      required this.items,
      required this.onTap,
      this.active = true,
      this.enrich = true,
      this.topChrome = false,
      this.showSave = true,
      this.actionLabel});
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onTap;
  final bool active, enrich, topChrome, showSave;
  final String? actionLabel;

  static List<MediaItem> browseItems(List<MediaItem> items) {
    bool hasBackdrop(MediaItem item) =>
        item.background?.trim().isNotEmpty == true;
    return items
        .where(hasBackdrop)
        .followedBy(items.where((item) => !hasBackdrop(item)))
        .take(3)
        .toList(growable: false);
  }

  @override
  State<FeaturedHero> createState() => _FeaturedHeroState();
}

class _FeaturedHeroState extends State<FeaturedHero>
    with WidgetsBindingObserver {
  (String, String)? _selected;
  double _dragStart = 0;
  final _strip = ScrollController();
  Object? _artKey;
  Future<(Object, FeaturedArtwork)>? _art;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _foreground = binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    if (visible != _foreground) setState(() => _foreground = visible);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _strip.dispose();
    super.dispose();
  }

  void _select(int index) {
    final item = widget.items[index];
    setState(() => _selected = (item.type, item.id));
    if (!_strip.hasClients) return;
    final position = _strip.position;
    final offset = (index * 64.0 + 32 - position.viewportDimension / 2)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      _strip.jumpTo(offset);
    } else {
      unawaited(_strip.animateTo(offset,
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final app = context.watch<AppState>();
    final selected =
        widget.items.indexWhere((m) => _selected == (m.type, m.id));
    final index = selected < 0 ? 0 : selected;
    final item = widget.items[index];
    final locale = app.contentTmdbLocale;
    final region = app.webSettings['region']?.toString() ?? 'US';
    final useTmdb = widget.enrich && app.webSettings['tmdbEnabled'] != false;
    final artKey = (
      app.catalogs,
      item.type,
      item.id,
      locale,
      region,
      useTmdb,
      app.webSettings['tmdbUseArtwork'],
      app.webSettings['tmdbUseBasicInfo'],
      app.api.hasUserTmdbKey
    );
    if (_artKey != artKey) {
      _artKey = artKey;
      _art = null;
    }
    if (useTmdb &&
        _foreground &&
        widget.active &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true)) {
      _art ??= app.catalogs
          .featuredArtwork(item,
              language: locale, region: region, uiLanguage: locale)
          .then((art) => (artKey, art));
    }
    return FutureBuilder<(Object, FeaturedArtwork)>(
        future: _art,
        builder: (context, snapshot) {
          final result = snapshot.data;
          final art = result?.$1 == artKey ? result?.$2 : null;
          return MediaHero(
            item: item,
            title: art?.title,
            genre: art?.genre,
            story: art?.overview,
            artworkUrl: MediaHero.artwork(item, art?.landscape, art?.portrait),
            topChrome: widget.topChrome,
            onArtworkTap: () => widget.onTap(item),
            onSwipeStart: widget.items.length < 2
                ? null
                : (details) => _dragStart = details.globalPosition.dx,
            onSwipe: widget.items.length == 1
                ? null
                : (details) {
                    final distance = details.globalPosition.dx - _dragStart;
                    if (distance.abs() < 36) return;
                    final forward =
                        Directionality.of(context) == TextDirection.rtl
                            ? distance > 0
                            : distance < 0;
                    _select((index + (forward ? 1 : -1)) % widget.items.length);
                  },
            selector: widget.items.length < 2
                ? null
                : Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SingleChildScrollView(
                        controller: _strip,
                        scrollDirection: Axis.horizontal,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          for (var i = 0; i < widget.items.length; i++)
                            _Thumbnail(
                                item: widget.items[i],
                                index: i,
                                selected: i == index,
                                onTap: () => _select(i)),
                        ]))),
            actions: Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  onPressed: () => widget.onTap(item),
                  icon: const Icon(LucideIcons.arrowUpRight, size: 18),
                  label: Text(widget.actionLabel ?? app.tr('message131'))),
              if (widget.showSave)
                OutlinedButton.icon(
                    onPressed: () => unawaited(app.toggleWatchlist(item)),
                    icon: Icon(
                        app.contains(item)
                            ? LucideIcons.check
                            : LucideIcons.bookmark,
                        size: 18),
                    label: Text(
                        app.tr(app.contains(item) ? 'message137' : 'save'))),
            ]),
          );
        });
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail(
      {required this.item,
      required this.index,
      required this.selected,
      required this.onTap});
  final MediaItem item;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = MediaHero.artwork(item);
    final fallback = Center(
        child: Text('${index + 1}', style: TextStyle(color: colors.onSurface)));
    return Semantics(
        label: item.name,
        button: true,
        selected: selected,
        child: Tooltip(
            message: item.name,
            excludeFromSemantics: true,
            child: InkWell(
                onTap: onTap,
                child: ExcludeSemantics(
                    child: SizedBox(
                        width: 64,
                        height: 48,
                        child: Center(
                            child: Container(
                          width: 58,
                          height: 36,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(6)),
                          foregroundDecoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: selected
                                      ? colors.primary
                                      : colors.outline,
                                  width: selected ? 3 : 1)),
                          child: url == null
                              ? fallback
                              : NovaNetworkImage(url,
                                  fit: BoxFit.cover,
                                  cacheWidth: imageCacheWidth(context, 58),
                                  errorBuilder: (_, __, ___) => fallback),
                        )))))));
  }
}

class FeaturedSkeleton extends StatelessWidget {
  const FeaturedSkeleton({super.key});
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final art = ShimmerBox(
            height: (constraints.maxWidth * (wide ? .33 : .55))
                .clamp(160.0, wide ? 420.0 : 320.0),
            borderRadius: BorderRadius.zero);
        const caption = Padding(
            padding: EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ShimmerBox(width: 128, height: 16),
              SizedBox(height: 10),
              ShimmerBox(width: 208, height: 36),
              SizedBox(height: 16),
              ShimmerBox(width: 152, height: 48),
            ]));
        return wide
            ? Row(children: [
                const Expanded(flex: 44, child: caption),
                Expanded(flex: 56, child: art)
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [art, caption]);
      });
}
