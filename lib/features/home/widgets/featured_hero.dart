import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/featured_artwork.dart';
import '../../../core/models/media_item.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/nova_theme.dart';
import '../../../shared/widgets/media_hero.dart';
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
            immersive: true,
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
                    alignment: Alignment.bottomCenter,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < widget.items.length; i++)
                        _SlideIndicator(
                            item: widget.items[i],
                            index: i,
                            selected: i == index,
                            onTap: () => _select(i)),
                    ])),
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
        child: Tooltip(
            message: item.name,
            excludeFromSemantics: true,
            child: InkWell(
                onTap: onTap,
                child: ExcludeSemantics(
                    child: SizedBox(
                        width: 48,
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
                        )))))));
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
