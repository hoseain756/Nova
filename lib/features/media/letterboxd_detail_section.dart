import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/letterboxd/letterboxd_settings.dart';
import '../../core/letterboxd/stremboxd_client.dart';
import '../../core/models/media_item.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/nova_theme.dart';
import '../../shared/widgets/shimmer_box.dart';
import 'widgets/detail_discussion_rail.dart';

/// Letterboxd film details supplied by the configured Stremboxd bridge.
class LetterboxdDetailSection extends StatefulWidget {
  const LetterboxdDetailSection({super.key, required this.item});

  final MediaItem item;

  @override
  State<LetterboxdDetailSection> createState() =>
      _LetterboxdDetailSectionState();
}

class _LetterboxdDetailSectionState extends State<LetterboxdDetailSection>
    with WidgetsBindingObserver {
  AppState? _loadedFor;
  String? _signature;
  Future<_FilmDetails>? _request;
  final Set<int> _revealedReviews = {};
  bool _openedExternal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _openedExternal) {
      _openedExternal = false;
      setState(() => _signature = null);
    }
  }

  Future<void> _open(Uri uri) async {
    _openedExternal = true;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) _openedExternal = false;
  }

  static Future<T?> _tryLoad<T>(Future<T?> Function() request) async {
    try {
      return await request();
    } catch (_) {
      return null;
    }
  }

  static Uri? _letterboxdUri(Object? raw) {
    if (raw is! String) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        (uri.host != 'letterboxd.com' && uri.host != 'www.letterboxd.com')) {
      return null;
    }
    return uri;
  }

  static String _plain(String value) {
    final text = value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text;
  }

  static _FilmDetails _fromFullMeta(
      LetterboxdFilmStreamInfo? stream, Map<String, dynamic>? meta) {
    Uri? filmUrl = stream?.letterboxdUrl;
    final reviews = <_ReviewPreview>[];
    final links = meta?['links'];
    if (links is List) {
      for (final raw in links) {
        if (raw is! Map) continue;
        final category = raw['category']?.toString().toLowerCase() ?? '';
        final uri = _letterboxdUri(raw['url']);
        if (uri == null || !category.contains('letterboxd')) continue;
        if (category.contains('review')) {
          final preview = _plain(raw['name']?.toString() ?? '');
          if (preview.isNotEmpty && reviews.length < 3) {
            reviews.add(_ReviewPreview(preview, uri));
          }
        } else {
          filmUrl ??= uri;
        }
      }
    }
    return _FilmDetails(stream: stream, filmUrl: filmUrl, reviews: reviews);
  }

  Future<_FilmDetails> _load(AppState app, LetterboxdSettings settings) async {
    final client = app.api.stremboxd;
    final imdbId = widget.item.id;
    final session = app.letterboxdSession;
    if (settings.mode == LetterboxdSettings.fullMode && session != null) {
      final streamRequest =
          _tryLoad(() => client.fetchFilmStreamInfo(session.userId, imdbId));
      final metaRequest =
          _tryLoad(() => client.fetchFullMeta(session.userId, imdbId));
      final stream = await streamRequest;
      final meta = await metaRequest;
      return _fromFullMeta(stream, meta);
    }
    if (settings.mode == LetterboxdSettings.publicMode) {
      final meta =
          await _tryLoad(() => client.fetchPublicMeta(settings, imdbId));
      return _FilmDetails(filmUrl: meta?.letterboxdUrl);
    }
    return const _FilmDetails();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final settings = app.letterboxdSettings;
    if (!settings.enabled ||
        widget.item.type != 'movie' ||
        !RegExp(r'^tt\d+$').hasMatch(widget.item.id)) {
      return const SizedBox.shrink();
    }

    final session = app.letterboxdSession;
    final signature = [
      widget.item.id,
      app.activeAccountId,
      app.activeProfileId,
      settings.mode,
      settings.encodedPublicConfig,
      session?.userId,
      session?.loginAt.millisecondsSinceEpoch,
    ].join('|');
    if (!identical(_loadedFor, app) || _signature != signature) {
      _loadedFor = app;
      _signature = signature;
      _revealedReviews.clear();
      _request = _load(app, settings);
    }

    final textTheme = Theme.of(context).textTheme;
    final blurReviews = app.webSettings['letterboxdBlurReviews'] != false;
    return FutureBuilder<_FilmDetails>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 180, height: 24),
              SizedBox(height: NovaSpace.md),
              ShimmerBox(height: 136),
              SizedBox(height: NovaSpace.sm),
              ShimmerBox(width: 200, height: 48),
            ],
          );
        }
        final details = snapshot.data ?? const _FilmDetails();
        final info = details.stream;
        final filmUrl = details.filmUrl ??
            Uri.https('letterboxd.com', '/imdb/${widget.item.id}/');
        final communityRating = info?.communityRating;
        final userRating = info?.userRating;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Letterboxd', style: textTheme.titleLarge),
            ),
            if (info != null &&
                (communityRating != null ||
                    userRating != null ||
                    info.watched ||
                    info.liked ||
                    info.inWatchlist)) ...[
              const SizedBox(height: NovaSpace.md),
              _FilmSummary(info: info, app: app),
            ],
            const SizedBox(height: NovaSpace.sm),
            Wrap(
              spacing: NovaSpace.sm,
              runSpacing: NovaSpace.sm,
              children: [
                _ExternalLink(
                  icon: LucideIcons.externalLink,
                  label: app.tr('letterboxdOpenFilm'),
                  onTap: () => _open(filmUrl),
                ),
                if (info?.rateUrl case final Uri uri)
                  _ExternalLink(
                    icon: LucideIcons.star,
                    label: app.tr('letterboxdRateShort'),
                    semanticLabel: app.tr('letterboxdRateAction'),
                    onTap: () => _open(uri),
                  ),
                if (info?.watchedUrl case final Uri uri)
                  _ExternalLink(
                    icon: LucideIcons.check,
                    label: app.tr('letterboxdWatchedShort'),
                    semanticLabel: app.tr('letterboxdWatchedAction'),
                    onTap: () => _open(uri),
                  ),
                if (info?.likedUrl case final Uri uri)
                  _ExternalLink(
                    icon: LucideIcons.heart,
                    label: app.tr('letterboxdLikeShort'),
                    semanticLabel: app.tr('letterboxdLikedAction'),
                    onTap: () => _open(uri),
                  ),
                if (info?.watchlistUrl case final Uri uri)
                  _ExternalLink(
                    icon: LucideIcons.bookmark,
                    label: app.tr('watchlist'),
                    semanticLabel: app.tr('letterboxdWatchlistAction'),
                    onTap: () => _open(uri),
                  ),
              ],
            ),
            if (details.reviews.isNotEmpty) ...[
              const SizedBox(height: NovaSpace.lg),
              DetailDiscussionRail(
                key: ValueKey('letterboxd-reviews-$_signature'),
                title: app.tr('letterboxdReviews'),
                hiddenLabel: app.tr('discussionHidden'),
                revealLabel: app.tr('letterboxdRevealReview'),
                readLabel: app.tr('discussionReadMore'),
                entries: [
                  for (var index = 0; index < details.reviews.length; index++)
                    DetailDiscussionEntry(
                      id: 'letterboxd-review-$index',
                      source: 'Letterboxd',
                      body: details.reviews[index].preview,
                      hidden: blurReviews && !_revealedReviews.contains(index),
                      onReveal: () =>
                          setState(() => _revealedReviews.add(index)),
                      onOpen: () => _open(details.reviews[index].url),
                      openLabel: app.tr('letterboxdOpenReviews'),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FilmDetails {
  const _FilmDetails({this.stream, this.filmUrl, this.reviews = const []});

  final LetterboxdFilmStreamInfo? stream;
  final Uri? filmUrl;
  final List<_ReviewPreview> reviews;
}

class _ReviewPreview {
  const _ReviewPreview(this.preview, this.url);

  final String preview;
  final Uri url;
}

class _FilmSummary extends StatelessWidget {
  const _FilmSummary({required this.info, required this.app});

  final LetterboxdFilmStreamInfo info;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasRatings = info.communityRating != null || info.userRating != null;
    final hasStatus = info.watched || info.liked || info.inWatchlist;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpace.md),
        child: LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context);
          final minimumRatingWidth = scale.scale(124);
          final ratingWidth =
              constraints.maxWidth < minimumRatingWidth * 2 + NovaSpace.lg
                  ? constraints.maxWidth
                  : ((constraints.maxWidth - NovaSpace.lg) / 2)
                      .clamp(minimumRatingWidth, scale.scale(280));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasRatings)
                Wrap(
                  spacing: NovaSpace.lg,
                  runSpacing: NovaSpace.md,
                  children: [
                    if (info.communityRating case final double value)
                      SizedBox(
                        width: ratingWidth,
                        child: _Rating(
                          label: app.tr('letterboxdCommunityRating'),
                          value: value,
                        ),
                      ),
                    if (info.userRating case final double value)
                      SizedBox(
                        width: ratingWidth,
                        child: _Rating(
                          label: app.tr('letterboxdYourRating'),
                          value: value,
                        ),
                      ),
                  ],
                ),
              if (hasRatings && hasStatus) ...[
                const SizedBox(height: NovaSpace.sm),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: NovaSpace.sm),
              ],
              if (hasStatus)
                Wrap(
                  spacing: NovaSpace.md,
                  runSpacing: NovaSpace.sm,
                  children: [
                    if (info.watched)
                      _Status(
                        icon: LucideIcons.check,
                        label: app.tr('letterboxdWatched'),
                      ),
                    if (info.liked)
                      _Status(
                        icon: LucideIcons.heart,
                        label: app.tr('letterboxdLiked'),
                      ),
                    if (info.inWatchlist)
                      _Status(
                        icon: LucideIcons.bookmark,
                        label: app.tr('letterboxdInWatchlist'),
                      ),
                  ],
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: NovaSpace.xs),
          Row(
            children: [
              Icon(LucideIcons.star,
                  size: 20, color: theme.colorScheme.secondary),
              const SizedBox(width: NovaSpace.sm),
              Flexible(
                child: Text('${value.toStringAsFixed(1)} / 5',
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: NovaSpace.sm),
          Flexible(
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
        ],
      );
}

class _ExternalLink extends StatelessWidget {
  const _ExternalLink(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.semanticLabel});

  final IconData icon;
  final String label;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: semanticLabel ?? label,
        excludeFromSemantics: true,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label, semanticsLabel: semanticLabel),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(
                horizontal: NovaSpace.md, vertical: NovaSpace.sm),
          ),
        ),
      );
}
