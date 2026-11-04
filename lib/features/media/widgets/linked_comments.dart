import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/media_item.dart';
import '../../../core/state/app_state.dart';
import 'detail_discussion_rail.dart';

/// Public tracker discussion, shown only when the viewer enables it.
class LinkedComments extends StatefulWidget {
  const LinkedComments({super.key, required this.item});

  final MediaItem item;

  @override
  State<LinkedComments> createState() => _LinkedCommentsState();
}

class _LinkedCommentsState extends State<LinkedComments> {
  AppState? _loadedFor;
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
    return value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\[/?spoiler\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final trakt = app.webSettings['showTraktComments'] == true;
    final anilist = app.webSettings['showAnilistComments'] == true;
    if (!trakt && !anilist) {
      _signature = null;
      _revealed.clear();
      return const SizedBox.shrink();
    }
    final signature = [
      widget.item.id,
      widget.item.type,
      widget.item.anilistId,
      app.activeAccountId,
      app.activeProfileId,
      trakt,
      anilist,
      app.webSettings['blurTraktComments'],
      app.webSettings['anilistBlurComments'],
    ].join('|');
    if (!identical(_loadedFor, app) || _signature != signature) {
      _loadedFor = app;
      _signature = signature;
      _revealed.clear();
      _request = _load(app, trakt, anilist);
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _request,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return DetailDiscussionRail(
          key: ValueKey(signature),
          title: app.tr('linkedComments'),
          hiddenLabel: app.tr('discussionHidden'),
          revealLabel: app.tr('linkedRevealComment'),
          readLabel: app.tr('discussionReadMore'),
          loading: loading,
          entries: loading
              ? const []
              : rows.map((row) {
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
                  final allowedUrl = url != null &&
                      url.scheme == 'https' &&
                      url.userInfo.isEmpty &&
                      url.port == 443 &&
                      (url.host == 'trakt.tv' || url.host == 'anilist.co');
                  return DetailDiscussionEntry(
                    id: id,
                    source: source == 'trakt' ? 'Trakt' : 'AniList',
                    author: row['username']?.toString(),
                    title: title,
                    body: text,
                    hidden: hidden,
                    onReveal: () => setState(() => _revealed.add(id)),
                    onOpen: allowedUrl
                        ? () =>
                            launchUrl(url, mode: LaunchMode.externalApplication)
                        : null,
                    openLabel: app.tr('linkedOpenDiscussion'),
                  );
                }).toList(growable: false),
        );
      },
    );
  }
}
