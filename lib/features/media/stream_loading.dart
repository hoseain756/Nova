/// Task 139 (user mandate): shared source loading for the watch flow.
/// The detail page no longer pre-fetches streams — it pushes the sources
/// page with THIS loader and the loading happens INSIDE the sources page
/// (spinner + refresh button in front of the user). The player's side
/// panel and the next-episode flow reuse the exact same pipeline, so every
/// entry point applies the same playable/torrent gates and ranking.
library;

import '../../core/models/media_item.dart';
import '../../core/state/app_state.dart';
import '../../core/torrent/torrent_service.dart';

/// UI-only marker for an add-on torrent result with no playback path here.
/// Never mutate the provider's stream map or send this marker to an add-on.
const unavailableTorrentSourceKey = '_novaUnavailableTorrent';

bool isTorrentStreamMap(Map<String, dynamic> stream) {
  final url = stream['url'];
  final hash = (stream['infoHash'] ?? '').toString().trim().toLowerCase();
  if (RegExp(r'^(?:[0-9a-f]{40}|[a-z2-7]{32})$').hasMatch(hash)) return true;
  return url is String &&
      url.startsWith('magnet:') &&
      RegExp(r'urn:btih:(?:[0-9a-f]{40}|[a-z2-7]{32})(?![a-z0-9])',
              caseSensitive: false)
          .hasMatch(url);
}

bool isDownloadableStreamMap(Map<String, dynamic> stream) {
  final url = stream['url'];
  if (url is! String || !url.startsWith('http')) {
    return isTorrentStreamMap(stream);
  }
  final uri = Uri.tryParse(url.split('|').first);
  return uri != null &&
      ['http', 'https'].contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      !RegExp(r'\.(m3u8|mpd)$', caseSensitive: false).hasMatch(uri.path);
}

/// A stream the app can actually start: a direct HTTP URL (headers are
/// normalized later by parsePlaybackSource) or an infoHash torrent row.
bool isPlayableStreamMap(Map<String, dynamic> stream) {
  final url = stream['url'];
  return (url is String && url.startsWith('http')) ||
      stream['infoHash'] is String ||
      isTorrentStreamMap(stream);
}

/// Detail-page ranking carried over verbatim (quality target + optional
/// H.264 preference — pure ordering, no rows added or dropped).
List<Map<String, dynamic>> rankStreams(
  List<Map<String, dynamic>> streams,
  Map<String, dynamic> settings,
) {
  final preferred = (settings['preferredQuality'] ?? 'auto').toString();
  final preferH264 = settings['preferH264'] == true;
  if (preferred == 'auto' && settings['streamSort'] != 'score' && !preferH264) {
    return streams;
  }
  final ranked = [...streams];
  int quality(Map<String, dynamic> stream) {
    final text = '${stream['title'] ?? ''} ${stream['name'] ?? ''}';
    final match = RegExp(
      r'(2160|1080|720|480)p?',
      caseSensitive: false,
    ).firstMatch(text);
    final height = int.tryParse(match?.group(1) ?? '') ?? 0;
    final target = int.tryParse(preferred.replaceAll('p', ''));
    final codec = text.toLowerCase();
    final codecPreference = preferH264
        ? (codec.contains('x265') || codec.contains('hevc') ? -100000 : 100000)
        : 0;
    return target == null
        ? codecPreference + height
        : codecPreference + (height == target ? 10000 + height : height);
  }

  ranked.sort((a, b) => quality(b).compareTo(quality(a)));
  return ranked;
}

/// Fetches every enabled add-on's streams for [videoId], applies the user's
/// playable-only filter, marks torrent rows without a playback path
/// (Debrid connected OR the on-device engine), and ranks all results.
/// Tolerates add-on failures for existing callers; player panels opt into an
/// error when all add-ons fail so a failed fetch is not shown as empty data.
Future<List<Map<String, dynamic>>> loadRankedSources({
  required AppState app,
  required MediaItem item,
  required String videoId,
  bool reportFailures = false,
}) async {
  List<Map<String, dynamic>> streams;
  try {
    streams = await app.catalogs.streams(item.type, videoId, app.addons,
        reportFailures: reportFailures);
  } catch (_) {
    if (reportFailures) rethrow;
    return const [];
  }
  if (streams.isEmpty) return streams;
  if (app.webSettings['playableOnly'] == true) {
    streams = streams.where(isPlayableStreamMap).toList();
  }
  // Torrent sources stay available when a Debrid service is connected or
  // the device itself can run the torrent engine.
  final debridConfigured = app.api.debridService != null;
  final p2pAllowed = app.webSettings['p2pEnabled'] != false;
  var torrentSourcesAllowed = debridConfigured;
  if (!torrentSourcesAllowed && p2pAllowed) {
    try {
      torrentSourcesAllowed = await TorrentService.instance.isSupported;
    } catch (_) {
      torrentSourcesAllowed = false;
    }
  }
  if (!torrentSourcesAllowed) {
    streams = markUnavailableTorrentSources(streams);
  }
  return rankStreams(streams, app.webSettings);
}

List<Map<String, dynamic>> markUnavailableTorrentSources(
    List<Map<String, dynamic>> streams) {
  return [
    for (final stream in streams)
      if (isTorrentStreamMap(stream) &&
          !(stream['url'] is String &&
              (stream['url'] as String).startsWith('http')))
        {...stream, unavailableTorrentSourceKey: true}
      else
        stream,
  ];
}
