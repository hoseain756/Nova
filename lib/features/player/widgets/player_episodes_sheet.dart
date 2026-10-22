import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/nova_strings.dart';
import '../../../shared/widgets/nova_network_image.dart';
import 'player_sheets.dart' show SheetScaffold;

/// Season and episode picker shared by the legacy and Core player routes.
/// The episode rows use only the metadata already supplied by the media item.
class PlayerEpisodesSheet extends StatefulWidget {
  const PlayerEpisodesSheet({
    super.key,
    required this.english,
    required this.episodes,
    required this.currentVideoId,
    required this.onPick,
    this.fallbackArtwork,
    this.loading = false,
  });

  final bool english;
  final List<Map<String, dynamic>> episodes;
  final String currentVideoId;
  final ValueChanged<Map<String, dynamic>> onPick;
  final String? fallbackArtwork;
  final bool loading;

  @override
  State<PlayerEpisodesSheet> createState() => _PlayerEpisodesSheetState();
}

class _PlayerEpisodesSheetState extends State<PlayerEpisodesSheet> {
  int? _selectedSeason;

  int _seasonOf(Map<String, dynamic> episode) =>
      (episode['season'] as num?)?.toInt() ?? 0;

  int _episodeOf(Map<String, dynamic> episode) =>
      (episode['episode'] as num?)?.toInt() ?? 0;

  List<int> get _seasons {
    final values = widget.episodes.map(_seasonOf).where((value) => value > 0);
    return values.toSet().toList()..sort();
  }

  int? get _activeSeason {
    final seasons = _seasons;
    if (seasons.isEmpty) return null;
    if (_selectedSeason != null && seasons.contains(_selectedSeason)) {
      return _selectedSeason;
    }
    for (final episode in widget.episodes) {
      if ((episode['id'] ?? '').toString() == widget.currentVideoId) {
        final current = _seasonOf(episode);
        if (seasons.contains(current)) return current;
      }
    }
    return seasons.first;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final season = _activeSeason;
    final visible = widget.episodes
        .where((episode) => _seasonOf(episode) == season)
        .toList()
      ..sort((a, b) => _episodeOf(a).compareTo(_episodeOf(b)));
    return SheetScaffold(
      title: NovaStrings.lookup(widget.english, 'message43'),
      expanded: true,
      child: Column(
        children: [
          if (_seasons.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DropdownButton<int>(
                value: season,
                isDense: true,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(LucideIcons.chevronDown, size: 18),
                items: [
                  for (final value in _seasons)
                    DropdownMenuItem(
                      value: value,
                      child: Text(NovaStrings.lookup(
                          widget.english, 'message45', {'p0': value})),
                    ),
                ],
                onChanged: (value) => setState(() => _selectedSeason = value),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: widget.loading
                ? Center(
                    child: CircularProgressIndicator(
                        color: scheme.primary, strokeWidth: 2.5))
                : visible.isEmpty
                    ? Center(
                        child: Text(
                          NovaStrings.lookup(
                              widget.english, 'playerNoEpisodes'),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _EpisodeRow(
                          english: widget.english,
                          episode: visible[index],
                          currentVideoId: widget.currentVideoId,
                          fallbackArtwork: widget.fallbackArtwork,
                          onPick: widget.onPick,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.english,
    required this.episode,
    required this.currentVideoId,
    required this.fallbackArtwork,
    required this.onPick,
  });

  final bool english;
  final Map<String, dynamic> episode;
  final String currentVideoId;
  final String? fallbackArtwork;
  final ValueChanged<Map<String, dynamic>> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final season = (episode['season'] as num?)?.toInt() ?? 0;
    final number = (episode['episode'] as num?)?.toInt() ?? 0;
    final tag =
        'S${season.toString().padLeft(2, '0')}E${number.toString().padLeft(2, '0')}';
    final title = (episode['name'] ?? episode['title'] ?? '').toString().trim();
    final ratingRaw = episode['rating'] ?? episode['imdbRating'];
    final rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw?.toString() ?? '');
    final artwork =
        (episode['thumbnail'] ?? episode['thumb'] ?? fallbackArtwork ?? '')
            .toString();
    final current = (episode['id'] ?? '').toString() == currentVideoId;
    final imageWidth = MediaQuery.sizeOf(context).width < 420 ? 112.0 : 140.0;

    return Material(
      color: current ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: imageWidth,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      artwork.isEmpty
                          ? ColoredBox(color: scheme.surfaceContainerHighest)
                          : NovaNetworkImage(artwork,
                              fit: BoxFit.cover,
                              cacheWidth: 320,
                              excludeFromSemantics: true),
                      PositionedDirectional(
                        start: 5,
                        bottom: 5,
                        child: _ImageBadge(label: tag),
                      ),
                      if (rating != null && rating > 0)
                        PositionedDirectional(
                          end: 5,
                          top: 5,
                          child: _ImageBadge(
                              label: rating.toStringAsFixed(1),
                              icon: LucideIcons.star),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty
                        ? NovaStrings.lookup(
                            english, 'message44', {'p0': number})
                        : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 5),
                  FilledButton.tonalIcon(
                    onPressed: current
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            onPick(episode);
                          },
                    icon: const Icon(LucideIcons.play, size: 15),
                    label: Text(NovaStrings.lookup(
                        english,
                        current
                            ? 'playerCurrentEpisode'
                            : 'playerEpisodePlay')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(80, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageBadge extends StatelessWidget {
  const _ImageBadge({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 10, color: Theme.of(context).colorScheme.onSurface),
                  const SizedBox(width: 2),
                ],
                Text(label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    )),
              ],
            ),
          ),
        ),
      );
}
