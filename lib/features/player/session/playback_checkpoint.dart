import 'dart:async';
import 'dart:typed_data';

import '../../../core/models/media_item.dart';
import 'playback_state.dart';

enum CheckpointCause { periodic, pause, source, exit }

enum CheckpointResult { saved, superseded, rejected, failed }

class PlaybackCheckpoint {
  PlaybackCheckpoint({
    required this.owner,
    required this.sequence,
    required this.contentKey,
    required MediaItem item,
    required this.videoId,
    required this.season,
    required this.episode,
    required this.positionMs,
    required this.durationMs,
    required this.cause,
    required this.eligible,
    Uint8List? frame,
  })  : frame = frame == null
            ? null
            : Uint8List.fromList(frame).asUnmodifiableView(),
        _itemData = freezePlaybackValue(item.toJson()) as Map<String, dynamic>;

  final Object owner;
  final int sequence;
  final String contentKey;
  final Map<String, dynamic> _itemData;
  MediaItem get item => MediaItem.fromJson(_itemData);
  final String videoId;
  final int? season;
  final int? episode;
  final int positionMs;
  final int durationMs;
  final CheckpointCause cause;
  final bool eligible;
  final Uint8List? frame;

  PlaybackCheckpoint withFrame(Uint8List? bytes) => PlaybackCheckpoint(
        owner: owner,
        sequence: sequence,
        contentKey: contentKey,
        item: item,
        videoId: videoId,
        season: season,
        episode: episode,
        positionMs: positionMs,
        durationMs: durationMs,
        cause: cause,
        eligible: eligible,
        frame: bytes,
      );
}

typedef PlaybackCheckpointSink = Future<void> Function(
    PlaybackCheckpoint checkpoint);

/// Shared across core-route handoffs. Serializes existing local writes, not
/// remote provider acknowledgements. A stalled sink blocks later writes only.
class PlaybackCheckpointWriter {
  static final shared = PlaybackCheckpointWriter();

  final List<_CheckpointWrite> _queue = [];
  final Expando<bool> _retired = Expando<bool>();
  final Expando<int> _lastSequence = Expando<int>();
  bool _writing = false;
  Completer<void>? _drain;

  Future<CheckpointResult> write(
      PlaybackCheckpoint snapshot, PlaybackCheckpointSink sink) {
    if (!snapshot.eligible ||
        _retired[snapshot.owner] == true ||
        snapshot.sequence <= (_lastSequence[snapshot.owner] ?? -1)) {
      return Future.value(CheckpointResult.rejected);
    }
    _lastSequence[snapshot.owner] = snapshot.sequence;
    // Supersede only queued periodic values belonging to this exact owner.
    for (var i = _queue.length - 1; i >= 0; i--) {
      final pending = _queue[i];
      if (identical(pending.snapshot.owner, snapshot.owner) &&
          pending.snapshot.contentKey == snapshot.contentKey &&
          pending.snapshot.cause == CheckpointCause.periodic) {
        _queue.removeAt(i).result.complete(CheckpointResult.superseded);
      }
    }
    final write = _CheckpointWrite(snapshot, sink);
    _queue.add(write);
    _drain ??= Completer<void>();
    unawaited(_pump());
    return write.result.future;
  }

  void retire(Object owner) => _retired[owner] = true;
  Future<void> drain() => _drain?.future ?? Future.value();

  Future<void> _pump() async {
    if (_writing) return;
    _writing = true;
    while (_queue.isNotEmpty) {
      final write = _queue.removeAt(0);
      try {
        await write.sink(write.snapshot);
        write.result.complete(CheckpointResult.saved);
      } catch (_) {
        write.result.complete(CheckpointResult.failed);
      }
    }
    _writing = false;
    final drain = _drain;
    _drain = null;
    drain?.complete();
  }
}

class _CheckpointWrite {
  _CheckpointWrite(this.snapshot, this.sink);
  final PlaybackCheckpoint snapshot;
  final PlaybackCheckpointSink sink;
  final result = Completer<CheckpointResult>();
}
