import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/features/player/core_video_player_page.dart';
import 'package:nova_mobile/features/player/playback_entry_page.dart';
import 'package:nova_mobile/features/player/session/playback_state.dart';
import 'package:nova_mobile/features/player/video_player_page.dart';

void main() {
  test('build selection and every playback argument survive route choice', () {
    final request = PlaybackRequest(
        item: const MediaItem(id: 'item', type: 'movie', name: 'Title'),
        url: 'url',
        streamName: 'Source',
        videoId: 'video',
        initialPositionMs: 12345,
        season: 1,
        episode: 2,
        streams: [
          {'url': 'url'}
        ],
        streamIndex: 0,
        headers: {'X-Test': 'value'},
        filename: 'file',
        recordProgress: false);
    final selected = playbackPageForRequest(request);
    expect(
      selected,
      useCorePlayerByDefault
          ? isA<CoreVideoPlayerPage>()
          : isA<VideoPlayerPage>(),
    );
    final core =
        playbackPageForRequest(request, useCore: true) as CoreVideoPlayerPage;
    final legacy =
        playbackPageForRequest(request, useCore: false) as VideoPlayerPage;
    expect(legacy.item.toJson(), core.item.toJson());
    expect(legacy.url, core.url);
    expect(legacy.streamName, core.streamName);
    expect(legacy.videoId, core.videoId);
    expect(legacy.initialPositionMs, core.initialPositionMs);
    expect(legacy.season, core.season);
    expect(legacy.episode, core.episode);
    expect(legacy.streams, core.streams);
    expect(legacy.streamIndex, core.streamIndex);
    expect(legacy.headers, core.headers);
    expect(legacy.filename, core.filename);
    expect(legacy.torrent, core.torrent);
    expect(legacy.recordProgress, isFalse);
    expect(core.recordProgress, isFalse);
  });
}
