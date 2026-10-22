import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/features/player/session/playback_checkpoint.dart';
import 'package:nova_mobile/features/player/session/playback_state.dart';

PlaybackCheckpoint _snapshot(Object owner, int sequence,
        {CheckpointCause cause = CheckpointCause.periodic,
        String id = 'one',
        bool eligible = true}) =>
    PlaybackCheckpoint(
      owner: owner,
      sequence: sequence,
      contentKey: id,
      item: MediaItem(id: id, type: 'series', name: id),
      videoId: '$id:1:2',
      season: 1,
      episode: 2,
      positionMs: sequence * 1234,
      durationMs: 1200000,
      cause: cause,
      eligible: eligible,
    );

void main() {
  test(
      'coalesces pending periodic snapshots while preserving exact final order',
      () async {
    final writer = PlaybackCheckpointWriter();
    final owner = Object();
    final gate = Completer<void>();
    final saved = <int>[];
    Future<void> sink(PlaybackCheckpoint snapshot) async {
      saved.add(snapshot.sequence);
      if (snapshot.sequence == 1) await gate.future;
    }

    final one = writer.write(_snapshot(owner, 1), sink);
    final two = writer.write(_snapshot(owner, 2), sink);
    final three = writer.write(_snapshot(owner, 3), sink);
    final finalSave =
        writer.write(_snapshot(owner, 4, cause: CheckpointCause.exit), sink);
    expect(await two, CheckpointResult.superseded);
    expect(await three, CheckpointResult.superseded);
    writer.retire(owner);
    expect(await writer.write(_snapshot(owner, 5), sink),
        CheckpointResult.rejected);
    gate.complete();
    expect(await one, CheckpointResult.saved);
    expect(await finalSave, CheckpointResult.saved);
    expect(saved, [1, 4]);
    await writer.drain();
  });

  test(
      'handoff never overtakes the old final save or coalesces different content',
      () async {
    final writer = PlaybackCheckpointWriter();
    final old = Object();
    final next = Object();
    final gate = Completer<void>();
    final saved = <String>[];
    Future<void> sink(PlaybackCheckpoint snapshot) async {
      saved.add(snapshot.contentKey);
      if (snapshot.contentKey == 'old') await gate.future;
    }

    final first = writer.write(
        _snapshot(old, 1, id: 'old', cause: CheckpointCause.exit), sink);
    final second = writer.write(_snapshot(next, 1, id: 'next'), sink);
    await Future<void>.delayed(Duration.zero);
    expect(saved, ['old']);
    gate.complete();
    await Future.wait([first, second]);
    expect(saved, ['old', 'next']);
  });

  test('failed sink is reported and subsequent writes still run', () async {
    final writer = PlaybackCheckpointWriter();
    final owner = Object();
    expect(
        await writer.write(
            _snapshot(owner, 1), (_) async => throw StateError('disk')),
        CheckpointResult.failed);
    expect(await writer.write(_snapshot(owner, 2), (_) async {}),
        CheckpointResult.saved);
    expect(await writer.write(_snapshot(owner, 1), (_) async {}),
        CheckpointResult.rejected);
    expect(
        await writer.write(_snapshot(owner, 3, eligible: false),
            (_) async => fail('not eligible')),
        CheckpointResult.rejected);
  });

  test('request snapshots deeply isolate mutable source/catalog input', () {
    final videos = <Map<String, dynamic>>[
      {'id': 'episode', 'name': 'Before'}
    ];
    final streams = <Map<String, dynamic>>[
      {
        'url': 'source',
        'behaviorHints': {
          'headers': {'X-Test': 'before'}
        }
      }
    ];
    final headers = <String, String>{'X-Test': 'before'};
    final request = PlaybackRequest(
        item:
            MediaItem(id: 'one', type: 'series', name: 'Title', videos: videos),
        url: 'source',
        streamName: 'name',
        videoId: 'episode',
        streams: streams,
        headers: headers);
    videos.first['name'] = 'After';
    (streams.first['behaviorHints'] as Map)['headers'] = {'X-Test': 'after'};
    headers['X-Test'] = 'after';
    expect(request.item.videos.first['name'], 'Before');
    expect(request.headers!['X-Test'], 'before');
    expect(
        ((request.streams.first['behaviorHints'] as Map)['headers']
            as Map)['X-Test'],
        'before');
    expect(
        () => request.streams.first['url'] = 'changed', throwsUnsupportedError);
    final copy = request.item;
    copy.videos.clear();
    expect(request.item.videos, hasLength(1));
  });
}
