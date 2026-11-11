import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:nova_mobile/shared/widgets/nova_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/media_item.dart';
import '../../core/theme/nova_theme.dart';
import '../../shared/widgets/image_decode.dart';
import '../../shared/widgets/shimmer_box.dart';
export '../../shared/widgets/shimmer_box.dart';

class DetailBackPill extends StatelessWidget {
  const DetailBackPill({super.key, required this.english});
  final bool english;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.only(
            start: 16, top: MediaQuery.paddingOf(context).top + 12),
        child: Align(
            alignment: AlignmentDirectional.topStart,
            child: IconButton.filledTonal(
              tooltip: NovaStrings.lookup(english, 'message136'),
              style: IconButton.styleFrom(minimumSize: const Size.square(48)),
              icon: Icon(Directionality.of(context) == TextDirection.rtl
                  ? LucideIcons.arrowRight
                  : LucideIcons.arrowLeft),
              onPressed: () => Navigator.of(context).maybePop(),
            )),
      );
}

class DetailActionRow extends StatelessWidget {
  const DetailActionRow(
      {super.key,
      required this.english,
      required this.isWide,
      required this.inList,
      required this.showTrackAnime,
      required this.primaryLabel,
      required this.primaryIsResume,
      required this.loading,
      required this.onPrimaryPressed,
      required this.onToggleWatchlist,
      required this.onOpenStreams,
      required this.onTrackAnime,
      required this.onShare,
      required this.onAddToList,
      this.nativeTopActions = false,
      this.onDownload});
  final bool english, isWide, inList, showTrackAnime, primaryIsResume, loading;
  final bool nativeTopActions;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed,
      onToggleWatchlist,
      onOpenStreams,
      onTrackAnime,
      onShare,
      onAddToList;
  final VoidCallback? onDownload;
  @override
  Widget build(BuildContext context) => Wrap(
          spacing: 8,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
                onPressed: loading ? null : onPrimaryPressed,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        primaryIsResume
                            ? LucideIcons.rotateCcw
                            : LucideIcons.play,
                        size: 20),
                label: Text(primaryLabel),
                style:
                    FilledButton.styleFrom(minimumSize: const Size(176, 52))),
            OutlinedButton.icon(
                onPressed: onToggleWatchlist,
                icon: Icon(inList ? LucideIcons.check : LucideIcons.plus,
                    size: 20),
                label: Text(inList
                    ? (NovaStrings.lookup(english, 'message137'))
                    : (NovaStrings.lookup(english, 'message138'))),
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(112, 52))),
            if (!nativeTopActions)
              IconButton.outlined(
                  onPressed: onShare,
                  tooltip: NovaStrings.lookup(english, 'message139'),
                  icon: const Icon(LucideIcons.share2),
                  style:
                      IconButton.styleFrom(minimumSize: const Size.square(52))),
            if (onDownload != null)
              IconButton.outlined(
                  onPressed: onDownload,
                  tooltip: NovaStrings.lookup(english, 'message140'),
                  icon: const Icon(LucideIcons.download),
                  style:
                      IconButton.styleFrom(minimumSize: const Size.square(52))),
            if (!nativeTopActions)
              PopupMenuButton<String>(
                tooltip: NovaStrings.lookup(english, 'message141'),
                icon: const Icon(LucideIcons.ellipsis),
                constraints: const BoxConstraints(minWidth: 240),
                onSelected: (action) {
                  switch (action) {
                    case 'sources':
                      onOpenStreams();
                    case 'list':
                      onAddToList();
                    case 'track':
                      onTrackAnime();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: 'sources',
                      child: ListTile(
                          leading: const Icon(LucideIcons.layers),
                          title:
                              Text(NovaStrings.lookup(english, 'message142')))),
                  PopupMenuItem(
                      value: 'list',
                      child: ListTile(
                          leading: const Icon(LucideIcons.listPlus),
                          title:
                              Text(NovaStrings.lookup(english, 'message143')))),
                  if (showTrackAnime)
                    PopupMenuItem(
                        value: 'track',
                        child: ListTile(
                            leading: const Icon(LucideIcons.activity),
                            title: Text(
                                NovaStrings.lookup(english, 'message144')))),
                ],
              ),
          ]);
}

class DetailCastCrew extends StatelessWidget {
  const DetailCastCrew(
      {super.key,
      required this.item,
      required this.english,
      this.centered = false});
  final MediaItem item;
  final bool english, centered;
  @override
  Widget build(BuildContext context) {
    final people = <MediaPerson>[
      ...item.castMembers,
      if (item.castMembers.isEmpty)
        ...item.cast.map((name) => MediaPerson(
            name: name, role: NovaStrings.lookup(english, 'message145'))),
      ...item.crewMembers,
      if (item.crewMembers.isEmpty)
        ...item.director.map((name) => MediaPerson(
            name: name, role: NovaStrings.lookup(english, 'message146'))),
    ];
    if (people.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(NovaStrings.lookup(english, 'message147'),
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 20),
      SizedBox(
          height: 180 + (scale - 1) * 72,
          child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: people.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final person = people[index];
                final initials = person.name
                    .trim()
                    .split(RegExp(r'\s+'))
                    .take(2)
                    .map((part) => part.characters.first)
                    .join();
                return SizedBox(
                    width: 112,
                    child: Column(children: [
                      ClipOval(
                          child: SizedBox.square(
                              dimension: 88,
                              child: ColoredBox(
                                  color: scheme.surfaceContainerHighest,
                                  child: person.photo == null
                                      ? Center(
                                          child: Text(initials,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall))
                                      : NovaNetworkImage(person.photo!,
                                          fit: BoxFit.cover,
                                          cacheWidth:
                                              imageCacheWidth(context, 88),
                                          excludeFromSemantics: true,
                                          errorBuilder: (_, __, ___) => Center(
                                              child: Text(initials,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineSmall)))))),
                      const SizedBox(height: 12),
                      Text(person.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall),
                      if (person.role?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(person.role!,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant))
                      ],
                    ]));
              })),
    ]);
  }
}

class DetailProduction extends StatelessWidget {
  const DetailProduction(
      {super.key, required this.item, required this.english});
  final MediaItem item;
  final bool english;
  @override
  Widget build(BuildContext context) {
    if (item.productionCompanies.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsetsDirectional.only(top: 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(NovaStrings.lookup(english, 'message148'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SizedBox(
              height:
                  128 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 2.8,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.productionCompanies.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 24),
                  itemBuilder: (context, index) {
                    final company = item.productionCompanies[index];
                    return SizedBox(
                        width: 144,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  height: 72,
                                  width: 144,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: company.logo == null
                                      ? Icon(LucideIcons.clapperboard,
                                          color: scheme.onSurfaceVariant)
                                      : NovaNetworkImage(company.logo!,
                                          fit: BoxFit.contain,
                                          cacheWidth:
                                              imageCacheWidth(context, 112),
                                          semanticLabel: company.name,
                                          errorBuilder: (_, __, ___) => Icon(
                                              LucideIcons.clapperboard,
                                              color: scheme.onSurfaceVariant))),
                              const SizedBox(height: 8),
                              Text(company.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.labelLarge),
                            ]));
                  })),
        ]));
  }
}

class DetailFactsTable extends StatelessWidget {
  const DetailFactsTable(
      {super.key, required this.item, required this.english});
  final MediaItem item;
  final bool english;
  @override
  Widget build(BuildContext context) {
    final series = item.type == 'series';
    final rows = <(String, String?)>[
      (
        NovaStrings.lookup(english, 'message149'),
        series
            ? (NovaStrings.lookup(english, 'message129'))
            : (NovaStrings.lookup(english, 'message128'))
      ),
      (NovaStrings.lookup(english, 'message150'), item.originalTitle),
      (
        NovaStrings.lookup(english, 'message151'),
        item.releaseDate ?? item.releaseInfo
      ),
      (NovaStrings.lookup(english, 'message152'), item.status),
      if (!series) (NovaStrings.lookup(english, 'message153'), item.runtime),
      if (series && item.seasonCount != null)
        (
          NovaStrings.lookup(english, 'message154'),
          item.seasonCount.toString()
        ),
      if (series && (item.episodeCount != null || item.videos.isNotEmpty))
        (
          NovaStrings.lookup(english, 'message43'),
          (item.episodeCount ?? item.videos.length).toString()
        ),
      (NovaStrings.lookup(english, 'message155'), item.genres.join(' · ')),
      (NovaStrings.lookup(english, 'language'), item.language),
      (NovaStrings.lookup(english, 'message156'), item.originCountry),
      (
        NovaStrings.lookup(english, 'message148'),
        item.productionCompanies.map((company) => company.name).join(' · ')
      ),
      (NovaStrings.lookup(english, 'tmdbNetworks'), item.networks.join(' · ')),
      (NovaStrings.lookup(english, 'tmdbCollection'), item.collectionName),
      (
        NovaStrings.lookup(english, 'message157'),
        item.director.isNotEmpty
            ? item.director.join(' · ')
            : item.crewMembers
                .where((person) =>
                    person.role == 'Creator' || person.role == 'Director')
                .map((person) => person.name)
                .join(' · ')
      ),
      (NovaStrings.lookup(english, 'message158'), item.rating),
      (NovaStrings.lookup(english, 'message159'), item.certification),
    ].where((row) => row.$2?.trim().isNotEmpty == true).toList();
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(NovaStrings.lookup(english, 'message160'),
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Table(
          columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
              horizontalInside: BorderSide(color: scheme.outlineVariant)),
          children: [
            for (final row in rows)
              TableRow(children: [
                Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(0, 16, 16, 16),
                    child: Text(row.$1,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant))),
                Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(0, 16, 0, 16),
                    child: SelectableText(row.$2!,
                        style: Theme.of(context).textTheme.bodyMedium)),
              ]),
          ]),
      if (item.trailerUrl case final trailer? when trailer.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: NovaSpace.xl),
          child: DetailTrailer(
            item: item,
            english: english,
            onPlay: () => launchUrl(Uri.parse(trailer),
                mode: LaunchMode.externalApplication),
          ),
        ),
    ]);
  }
}

/// A single, artwork-led trailer entry with a separate, readable caption.
class DetailTrailer extends StatelessWidget {
  const DetailTrailer({
    super.key,
    required this.item,
    required this.english,
    required this.onPlay,
  });

  final MediaItem item;
  final bool english;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = NovaStrings.lookup(english, 'tmdbWatchTrailer');
    final artwork = [item.background, item.poster]
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .firstOrNull;
    final fallback = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(LucideIcons.clapperboard,
            size: 96, color: scheme.onSurfaceVariant.withValues(alpha: .16)),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(NovaStrings.lookup(english, 'tmdbUseTrailers'),
            style: theme.textTheme.titleLarge),
        const SizedBox(height: NovaSpace.md),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Semantics(
              button: true,
              label: '$label، ${item.name}',
              onTap: onPlay,
              excludeSemantics: true,
              child: Material(
                color: scheme.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: InkWell(
                  onTap: onPlay,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (artwork != null)
                              NovaNetworkImage(
                                artwork,
                                fit: BoxFit.cover,
                                cacheWidth: imageCacheWidth(context, 560),
                                excludeFromSemantics: true,
                                errorBuilder: (_, __, ___) => fallback,
                              )
                            else
                              fallback,
                            ColoredBox(
                                color: NovaColors.ink.withValues(alpha: .24)),
                            Center(
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const ShapeDecoration(
                                  color: NovaColors.red,
                                  shape: CircleBorder(),
                                ),
                                child: const Icon(LucideIcons.play,
                                    color: NovaColors.white, size: 28),
                              ),
                            ),
                            // Keep focus, hover and press feedback above artwork.
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onPlay,
                                canRequestFocus: false,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(NovaSpace.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label,
                                      style: theme.textTheme.titleMedium),
                                  const SizedBox(height: NovaSpace.xs),
                                  Text(item.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            const SizedBox(width: NovaSpace.md),
                            Icon(LucideIcons.externalLink,
                                size: 20, color: scheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DetailLoadingSkeleton extends StatelessWidget {
  const DetailLoadingSkeleton({super.key});
  @override
  Widget build(BuildContext context) => ListView(children: [
        ShimmerBox(
            height: (MediaQuery.sizeOf(context).height * .6).clamp(320, 600),
            borderRadius: BorderRadius.zero),
        const Padding(
            padding: EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ShimmerBox(width: 240, height: 24),
              SizedBox(height: 24),
              ShimmerBox(height: 52),
              SizedBox(height: 24),
              ShimmerBox(height: 96)
            ])),
      ]);
}
