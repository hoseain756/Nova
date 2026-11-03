import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/letterboxd/letterboxd_settings.dart';
import '../../core/letterboxd/stremboxd_client.dart';
import '../../core/models/media_item.dart';
import '../../core/state/app_state.dart';
import '../../shared/widgets/shimmer_box.dart';

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
    return text.length > 400 ? '${text.substring(0, 400)}…' : text;
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

    final scheme = Theme.of(context).colorScheme;
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
              SizedBox(height: 12),
              ShimmerBox(height: 68),
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
            Text('Letterboxd', style: textTheme.titleLarge),
            if (communityRating != null || userRating != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (communityRating != null)
                    _Rating(
                      label: app.tr('letterboxdCommunityRating'),
                      value: communityRating,
                    ),
                  if (userRating != null)
                    _Rating(
                      label: app.tr('letterboxdYourRating'),
                      value: userRating,
                    ),
                ],
              ),
            ],
            if (info != null &&
                (info.watched || info.liked || info.inWatchlist)) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (info.watched)
                    _Status(
                        icon: Icons.check_circle_outline,
                        label: app.tr('letterboxdWatched')),
                  if (info.liked)
                    _Status(
                        icon: Icons.favorite_border,
                        label: app.tr('letterboxdLiked')),
                  if (info.inWatchlist)
                    _Status(
                        icon: Icons.bookmark_border,
                        label: app.tr('letterboxdInWatchlist')),
                ],
              ),
            ],
            const SizedBox(height: 8),
            _ExternalLink(
              icon: Icons.open_in_new,
              label: app.tr('letterboxdOpenFilm'),
              onTap: () => _open(filmUrl),
            ),
            if (info?.rateUrl case final Uri uri)
              _ExternalLink(
                icon: Icons.star_border,
                label: app.tr('letterboxdRateAction'),
                onTap: () => _open(uri),
              ),
            if (info?.watchedUrl case final Uri uri)
              _ExternalLink(
                icon: Icons.check_circle_outline,
                label: app.tr('letterboxdWatchedAction'),
                onTap: () => _open(uri),
              ),
            if (info?.likedUrl case final Uri uri)
              _ExternalLink(
                icon: Icons.favorite_border,
                label: app.tr('letterboxdLikedAction'),
                onTap: () => _open(uri),
              ),
            if (info?.watchlistUrl case final Uri uri)
              _ExternalLink(
                icon: Icons.bookmark_border,
                label: app.tr('letterboxdWatchlistAction'),
                onTap: () => _open(uri),
              ),
            if (details.reviews.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 12),
              Text(app.tr('letterboxdReviews'), style: textTheme.titleMedium),
              const SizedBox(height: 8),
              for (var index = 0; index < details.reviews.length; index++) ...[
                if (blurReviews && !_revealedReviews.contains(index))
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _revealedReviews.add(index)),
                      child: Text(app.tr('letterboxdRevealReview')),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 8),
                    child: Text(details.reviews[index].preview,
                        style: textTheme.bodyMedium),
                  ),
                _ExternalLink(
                  icon: Icons.open_in_new,
                  label: app.tr('letterboxdOpenReviews'),
                  onTap: () => _open(details.reviews[index].url),
                ),
                if (index < details.reviews.length - 1)
                  Divider(color: scheme.outlineVariant),
              ],
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

class _Rating extends StatelessWidget {
  const _Rating({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 2),
            Text('${value.toStringAsFixed(1)} / 5',
                textDirection: TextDirection.ltr,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      );
}

class _ExternalLink extends StatelessWidget {
  const _ExternalLink(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: onTap,
      );
}
