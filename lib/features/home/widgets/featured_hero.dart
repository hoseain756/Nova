import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/featured_artwork.dart';
import '../../../core/models/media_item.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/nova_theme.dart';
import '../../../shared/widgets/media_hero.dart';
import '../../../shared/widgets/image_decode.dart';
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
  Object? _artKey;
  Future<(Object, FeaturedArtwork)>? _art;
  bool _foreground = true;
  final Set<String> _prefetchedArtwork = {};

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
    super.dispose();
  }

  void _select(int index) {
    final item = widget.items[index];
    setState(() => _selected = (item.type, item.id));
  }

  String? _stableArtwork(MediaItem item, bool portrait) => (portrait
          ? [item.poster, item.background]
          : [item.background, item.poster])
      .whereType<String>()
      .where((url) => url.trim().isNotEmpty)
      .firstOrNull;

  void _prefetchArtwork(
      BuildContext context, bool portrait, ArtworkQuality quality) {
    if (!_foreground ||
        !widget.active ||
        !TickerMode.valuesOf(context).enabled ||
        !(ModalRoute.isCurrentOf(context) ?? true)) {
      return;
    }
    final extent = portrait
        ? MediaQuery.sizeOf(context).height * .78
        : MediaQuery.sizeOf(context).width;
    final pixelExtent = quality.decodedExtent(context, extent);
    for (final item in widget.items) {
      final rawUrl = _stableArtwork(item, portrait);
      final url = rawUrl == null
          ? null
          : quality.sourceUrl(rawUrl, hero: true, portrait: portrait);
      if (url == null || !_prefetchedArtwork.add('$pixelExtent:$url')) continue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(precacheImage(
          ResizeImage.resizeIfNeeded(
            portrait ? null : pixelExtent,
            portrait ? pixelExtent : null,
            CachedNetworkImageProvider(url),
          ),
          context,
          onError: (_, __) {},
        ));
      });
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
    final portrait = MediaQuery.sizeOf(context).width < 700;
    final quality = ArtworkQuality.fromSetting(
        app.webSettings['heroArtworkQuality'],
        fallback: ArtworkQuality.high);
    _prefetchArtwork(context, portrait, quality);
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
          // Keep the catalog image fixed while optional TMDB metadata arrives.
          // A network image from enrichment is only used when the catalog has none.
          final artworkUrl = _stableArtwork(item, portrait) ??
              (portrait
                  ? art?.portrait ?? art?.landscape
                  : art?.landscape ?? art?.portrait);
          return MediaHero(
            item: item,
            immersive: true,
            artworkQuality: quality,
            title: art?.title,
            genre: art?.genre,
            story: art?.overview,
            artworkUrl: artworkUrl,
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
                    alignment: Alignment.bottomCenter,
                    child: _SlideSelector(
                      items: widget.items,
                      selected: index,
                      onSelect: _select,
                    )),
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

class _SlideSelector extends StatelessWidget {
  const _SlideSelector({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<MediaItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final widths = [
      for (var i = 0; i < items.length; i++) i == selected ? 16.0 : 8.0
    ];
    final visualWidth = widths.fold<double>(0, (sum, width) => sum + width) +
        (items.length - 1) * 8;
    final touchWidth = math.max(items.length * 48.0, visualWidth + 48);
    final leading = (touchWidth - visualWidth) / 2;

    void selectNearest(TapUpDetails details) {
      final x = Directionality.of(context) == TextDirection.rtl
          ? touchWidth - details.localPosition.dx
          : details.localPosition.dx;
      var cursor = leading;
      var nearest = 0;
      var distance = double.infinity;
      for (var i = 0; i < widths.length; i++) {
        final center = cursor + widths[i] / 2;
        final delta = (x - center).abs();
        if (delta < distance) {
          distance = delta;
          nearest = i;
        }
        cursor += widths[i] + 8;
      }
      onSelect(nearest);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: selectNearest,
      child: SizedBox(
        key: const ValueKey('hero-slide-selector'),
        width: touchWidth,
        height: 48,
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _SlideIndicator(
                item: items[i],
                index: i,
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _SlideIndicator extends StatelessWidget {
  const _SlideIndicator(
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
    return Semantics(
        label: item.name,
        button: true,
        selected: selected,
        onTap: onTap,
        child: Tooltip(
            message: item.name,
            excludeFromSemantics: true,
            child: ExcludeSemantics(
                child: SizedBox(
                    width: selected ? 16 : 8,
                    height: 48,
                    child: Center(
                        child: AnimatedContainer(
                      key: ValueKey('hero-slide-indicator-$index'),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: selected ? 16 : 8,
                      height: 6,
                      decoration: BoxDecoration(
                        color: selected
                            ? NovaColors.white
                            : NovaColors.white.withValues(alpha: .46),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ))))));
  }
}

class FeaturedSkeleton extends StatelessWidget {
  const FeaturedSkeleton({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Stack(fit: StackFit.expand, children: [
          const ShimmerBox(borderRadius: BorderRadius.zero),
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 84),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(width: 124, height: 14),
                    const SizedBox(height: 12),
                    const ShimmerBox(width: 236, height: 42),
                    const SizedBox(height: 18),
                    const ShimmerBox(width: 176, height: 48),
                  ]),
            ),
          ),
        ]),
      );
}
