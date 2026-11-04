import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:nova_mobile/shared/widgets/nova_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/state/app_state.dart';
import '../shell/nova_browse_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/track/track_link.dart';
import '../../shared/widgets/image_decode.dart';
import '../../shared/widgets/noor_toast.dart';

/// Anime tracking sheet: pick a watch status, nudge the episodes-watched
/// counter and set a 0–10 score — saved to EVERY linked tracker the item can
/// reach (AniList by its media id, MyAnimeList by idMal), each independent.
///
/// Preloads the current remote entries so the controls open on the real
/// provider state; supports "remove from list" (deletes pure planning rows,
/// never entries carrying progress or scores).
Future<void> showAnimeTrackerSheet(BuildContext context, MediaItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (_) => _TrackerSheet(item: item),
  );
}

class _TrackerSheet extends StatefulWidget {
  const _TrackerSheet({required this.item});

  final MediaItem item;

  @override
  State<_TrackerSheet> createState() => _TrackerSheetState();
}

class _TrackerSheetState extends State<_TrackerSheet> {
  AnimeTrackStatus? _status;
  int _progress = 0;
  double _score = 0;
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _preload();
  }

  Future<void> _preload() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final app = context.read<AppState>();
    try {
      final preview = await app.api.animeTrackerPreview(
        anilistId: widget.item.anilistId,
        malId: widget.item.idMal,
      );
      // Prefer AniList's state, fall back to MAL's.
      final entry = (preview['anilist'] ?? preview['mal']) as Map?;
      if (!mounted) return;
      setState(() {
        if (entry != null) {
          final statusName = entry['status']?.toString();
          _status = AnimeTrackStatus.values
              .where((s) => s.name == statusName)
              .firstOrNull;
          _progress = (entry['progress'] as num?)?.toInt() ?? 0;
          _score =
              ((entry['score10'] as num?)?.toDouble() ?? 0).clamp(0.0, 10.0);
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final app = context.read<AppState>();
    setState(() => _saving = true);
    final outcomes = await app.saveAnimeEntry(
      item: widget.item,
      status: _status,
      progress: _status == null ? null : _progress,
      score10: _score > 0 ? _score : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final english = app.english;
    final anyOk = outcomes.values.contains(true);
    final allFail = outcomes.isNotEmpty && !anyOk;
    if (outcomes.isEmpty) {
      NoorToast.show(
        context,
        NovaStrings.lookup(english, 'message542'),
        error: true,
      );
      return;
    }
    NoorToast.show(
      context,
      allFail
          ? (NovaStrings.lookup(english, 'message543'))
          : (NovaStrings.lookup(english, 'message544')),
      error: allFail,
    );
    if (anyOk) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    if (_saving) return;
    final app = context.read<AppState>();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              icon: const Icon(LucideIcons.listMinus),
              title: Text(app.tr('message545')),
              content: Text(app.tr('message546')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(app.tr('cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(app.tr('remove')))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final outcomes = await app.saveAnimeEntry(item: widget.item);
    if (!mounted) return;
    setState(() => _saving = false);
    final english = app.english;
    final anyOk = outcomes.values.contains(true);
    NoorToast.show(
      context,
      anyOk
          ? (NovaStrings.lookup(english, 'message547'))
          : (NovaStrings.lookup(english, 'message543')),
      error: !anyOk,
    );
    if (anyOk) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final statuses = <(AnimeTrackStatus, String, IconData)>[
      (AnimeTrackStatus.watching, app.tr('message548'), LucideIcons.play),
      (AnimeTrackStatus.completed, app.tr('message549'), LucideIcons.check),
      (AnimeTrackStatus.planning, app.tr('message550'), LucideIcons.bookmark),
      (AnimeTrackStatus.paused, app.tr('message551'), LucideIcons.pause),
      (AnimeTrackStatus.dropped, app.tr('message552'), LucideIcons.x),
      (AnimeTrackStatus.rewatching, app.tr('message553'), LucideIcons.repeat),
    ];
    return NovaBrowseSheet(slivers: [
      SliverToBoxAdapter(
          child: NovaBrowseSheetHeading(
        title: app.tr('message554'),
        closeLabel: app.tr('close'),
        onClose: _saving ? null : () => Navigator.pop(context),
      )),
      SliverPadding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
        sliver: SliverToBoxAdapter(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.item.poster != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: NovaNetworkImage(widget.item.poster!,
                      width: 80,
                      height: 112,
                      fit: BoxFit.cover,
                      cacheWidth: imageCacheWidth(context, 80),
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(width: 80, height: 112)),
                ),
                const SizedBox(width: 20),
              ],
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.item.name,
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Text(app.tr('message555'),
                        style: theme.textTheme.bodyMedium),
                  ])),
            ]),
            const Divider(height: 48),
            if (_loading)
              const LinearProgressIndicator()
            else if (_loadFailed) ...[
              Text(app.tr('message556')),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                  onPressed: _preload,
                  icon: const Icon(LucideIcons.refreshCw),
                  label: Text(app.tr('message174'))),
            ] else ...[
              Text(app.tr('message557'), style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final entry in statuses)
                  ChoiceChip(
                    avatar: Icon(entry.$3, size: 18),
                    label: Text(entry.$2),
                    selected: _status == entry.$1,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _status = entry.$1),
                  ),
              ]),
              const Divider(height: 48),
              if (_status != null && _status != AnimeTrackStatus.completed) ...[
                Text(app.tr('message558'), style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton.filledTonal(
                        tooltip: app.tr('message559'),
                        onPressed: _saving || _progress <= 0
                            ? null
                            : () => setState(() => _progress--),
                        icon: const Icon(LucideIcons.minus)),
                    Semantics(
                        liveRegion: true,
                        child: Text('$_progress',
                            style: theme.textTheme.headlineLarge)),
                    IconButton.filledTonal(
                        tooltip: app.tr('message560'),
                        onPressed:
                            _saving ? null : () => setState(() => _progress++),
                        icon: const Icon(LucideIcons.plus)),
                  ],
                ),
                const Divider(height: 48),
              ],
              Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(app.tr('message561'),
                        style: theme.textTheme.titleLarge),
                    Text(
                        _score > 0
                            ? '${_score.toStringAsFixed(0)} / 10'
                            : app.tr('message562'),
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(color: theme.colorScheme.primary)),
                  ]),
              Slider.adaptive(
                  value: _score,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  semanticFormatterCallback: (value) => '${value.toInt()} / 10',
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _score = value)),
            ],
            const Divider(height: 48),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton.icon(
                onPressed: _saving || _loading || _loadFailed ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.check),
                label: Text(app.tr('message563')),
              ),
              TextButton.icon(
                  onPressed:
                      _saving || _loading || _loadFailed ? null : _remove,
                  icon: const Icon(LucideIcons.listMinus),
                  label: Text(app.tr('remove'))),
            ]),
          ],
        )),
      ),
    ]);
  }
}
