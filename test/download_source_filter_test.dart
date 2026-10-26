import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/media/stream_loading.dart';

void main() {
  const hash = '0123456789abcdef0123456789abcdef01234567';
  test('offline source filter keeps torrent hashes, magnets and direct files',
      () {
    expect(isDownloadableStreamMap({'infoHash': hash, 'fileIdx': 3}), isTrue);
    expect(
        isDownloadableStreamMap({'url': 'magnet:?xt=urn:btih:$hash'}), isTrue);
    expect(isPlayableStreamMap({'url': 'magnet:?xt=urn:btih:$hash'}), isTrue);
    expect(
        isDownloadableStreamMap(
            {'url': 'https://example.test/file.mkv|User-Agent=NOVA'}),
        isTrue);
    expect(isDownloadableStreamMap({'infoHash': 'bad'}), isFalse);
    expect(
        isDownloadableStreamMap({'externalUrl': 'https://example.test/page'}),
        isFalse);
  });
  test('offline source filter rejects adaptive playlists and invalid URLs', () {
    expect(
        isDownloadableStreamMap(
            {'url': 'https://example.test/live.M3U8?token=x'}),
        isFalse);
    expect(isDownloadableStreamMap({'url': 'https://example.test/live.mpd'}),
        isFalse);
    expect(isDownloadableStreamMap({'url': 'https://'}), isFalse);
  });

  test('unsupported torrent results remain visible and are marked for UI', () {
    final torrent = <String, dynamic>{
      'infoHash': hash,
      'addonName': 'Torrent add-on'
    };
    final direct = <String, dynamic>{
      'url': 'https://example.test/movie.mp4',
      'addonName': 'Direct add-on'
    };
    final rows = markUnavailableTorrentSources([torrent, direct]);
    expect(rows, hasLength(2));
    expect(rows.first[unavailableTorrentSourceKey], isTrue);
    expect(rows.last[unavailableTorrentSourceKey], isNull);
    expect(torrent.containsKey(unavailableTorrentSourceKey), isFalse);
  });
}
