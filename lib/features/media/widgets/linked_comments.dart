import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/media_item.dart';
import '../../../core/state/app_state.dart';
import '../../../l10n/nova_strings.dart';
import '../../../shared/widgets/shimmer_box.dart';

/// Public tracker discussion, shown only when the viewer enables it.
class LinkedComments extends StatefulWidget {
  const LinkedComments({super.key, required this.item});

  final MediaItem item;

  @override
  State<LinkedComments> createState() => _LinkedCommentsState();
}

class _LinkedCommentsState extends State<LinkedComments> {
  String? _signature;
  Future<List<Map<String, dynamic>>>? _request;
  final Set<String> _revealed = {};

  Future<List<Map<String, dynamic>>> _load(
      AppState app, bool trakt, bool anilist) async {
    final imdb =
        RegExp(r'^tt\d+$').hasMatch(widget.item.id) ? widget.item.id : null;
    final jobs = <Future<List<Map<String, dynamic>>>>[
      if (trakt && imdb != null)
        app.api.traktComments(mediaId: imdb, type: widget.item.type),
      if (anilist && widget.item.anilistId != null)
        app.api.aniListThreads(widget.item.anilistId!),
    ];
    final groups = await Future.wait(jobs);
    return groups.expand((group) => group).toList(growable: false);
  }

  static String _plain(String value) {
    final text = value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
    return text.length > 600 ? '${text.substring(0, 600)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final trakt = app.webSettings['showTraktComments'] == true;
    final anilist = app.webSettings['showAnilistComments'] == true;
    if (!trakt && !anilist) return const SizedBox.shrink();
    final signature = [
      widget.item.id,
      widget.item.type,
      widget.item.anilistId,
      trakt,
      anilist,
    ].join('|');
    if (_signature != signature) {
      _signature = signature;
      _revealed.clear();
      _request = _load(app, trakt, anilist);
    }
    final english = app.english;
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 180, height: 24),
              SizedBox(height: 12),
              ShimmerBox(height: 70),
            ],
          );
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(NovaStrings.lookup(english, 'linkedComments'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final row in rows) ...[
              Builder(builder: (context) {
                final source = row['source']?.toString() ?? '';
                final id = '$source:${row['id']}';
                final blurred = source == 'trakt'
                    ? app.webSettings['blurTraktComments'] != false
                    : app.webSettings['anilistBlurComments'] != false;
                final raw = row['text']?.toString() ?? '';
                final hasInlineSpoiler = RegExp(
                        r'\[spoiler\]|<span[^>]*spoiler',
                        caseSensitive: false)
                    .hasMatch(raw);
                final hidden =
                    (blurred || row['spoiler'] == true || hasInlineSpoiler) &&
                        !_revealed.contains(id);
                final text = _plain(raw);
                final title = row['title']?.toString() ?? '';
                final url = Uri.tryParse(row['url']?.toString() ?? '');
                final allowedUrl = url?.scheme == 'https' &&
                    (url?.host == 'trakt.tv' || url?.host == 'anilist.co');
                return Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${source == 'trakt' ? 'Trakt' : 'AniList'} · ${row['username'] ?? ''}',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      if (title.isNotEmpty)
                        Text(title,
                            style: Theme.of(context).textTheme.titleSmall),
                      if (hidden)
                        TextButton(
                          onPressed: () => setState(() => _revealed.add(id)),
                          child: Text(NovaStrings.lookup(
                              english, 'linkedRevealComment')),
                        )
                      else if (text.isNotEmpty)
                        Text(text,
                            style: Theme.of(context).textTheme.bodyMedium),
                      if (allowedUrl)
                        TextButton(
                          onPressed: () => launchUrl(url!,
                              mode: LaunchMode.externalApplication),
                          child: Text(NovaStrings.lookup(
                              english, 'linkedOpenDiscussion')),
                        ),
                      Divider(color: scheme.outlineVariant),
                    ],
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }
}
