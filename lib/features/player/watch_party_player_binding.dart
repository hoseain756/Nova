import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/watch_party/watch_party_controller.dart';
import '../../core/watch_party/watch_party_models.dart';
import 'engine/playback_engine.dart';
import 'session/playback_state.dart';
import 'watch_party_audio.dart';

/// Uses exact engine reads, never the coalesced display timeline. Its own
/// timer/listener never calls setState on either fullscreen player page.
class WatchPartyPlayerBinding {
  static const pausedToleranceMs = 80;
  static const maxPausedCorrectionAttempts = 3;
  WatchPartyPlayerBinding(
      {required this.controller,
      required this.engine,
      required this.media,
      this.source,
      required this.isActive,
      this.onFollowRequired,
      this.onError}) {
    _handler = _intercept;
    engine.watchPartyCommand = _handler;
    _audioHandler = _interceptAudio;
    engine.watchPartyAudioCommand = _audioHandler;
    _canChangeMedia = controller.snapshot?.isHost ?? false;
    _observedSnapshot = controller.snapshot;
    controller.addListener(_changed);
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _immediateFollowUpAvailable = true;
      unawaited(_tick());
    });
    unawaited(_tick());
  }
  final WatchPartyController controller;
  final PlaybackEngine engine;
  final WatchPartyMedia media;
  final WatchPartySource? source;
  final bool Function() isActive;
  final void Function(String messageKey)? onError;
  final bool Function(String messageKey)? onFollowRequired;
  late final Future<bool> Function(String, double?) _handler;
  late final Future<bool> Function(AudioTrack) _audioHandler;
  Timer? _timer;
  bool _disposed = false,
      _working = false,
      _tickPending = false,
      _immediateFollowUpAvailable = true,
      _foreground = true,
      _canChangeMedia = false;
  bool _wasMatching = false, _nudging = false, _announcedMismatch = false;
  String? _adoptedRoom;
  String? _followNoticeKey;
  int _lastSeek = -10000, _lastPublish = -10000, _bufferSince = -1;
  int _lastMediaAttempt = -10000, _lastSourceAttempt = -10000;
  WatchPartySnapshot? _observedSnapshot;
  double? _baseRate;
  bool _reportedNativeFailure = false;
  String? _sourcePublishedRoom, _audioAppliedKey, _audioUnavailableKey;
  String? _pausedCorrectionKey;
  int _pausedCorrectionAttempts = 0;
  bool _pausedCorrectionWarned = false;
  bool get _active =>
      !_disposed &&
      isActive() &&
      _foreground &&
      identical(engine.watchPartyCommand, _handler);

  Future<bool> _intercept(String action, double? value) async {
    final room = controller.snapshot;
    if (!_active || room == null) return false;
    if (_awaitingRoomMedia(room)) {
      _requestFollow(room, 'partyTitleChanged', force: true);
      return true;
    }
    if (room.media?.key != media.key) return false;
    if (_sourceMismatch(room)) {
      _requestFollow(room, 'partySourceLockedMismatch', force: true);
      return true;
    }
    if (!room.canControl) {
      onError?.call('partyHostRequired');
      return true;
    }
    try {
      await controller.command(action,
          mediaKey: media.key,
          sourceKey: source?.key,
          positionMs: action == 'seek'
              ? value?.round().clamp(0, 43200000)
              : action == 'pause' && room.isHost
                  ? engine.position.inMilliseconds.clamp(0, 43200000)
                  : null,
          rate: action == 'rate' ? value?.clamp(0.25, 4).toDouble() : null);
    } on WatchPartyException catch (error) {
      if (!_disposed) onError?.call(error.messageKey);
    }
    return true;
  }

  bool _sourceMismatch(WatchPartySnapshot room) =>
      !room.isHost &&
      room.sourceLocked &&
      (source == null || room.source?.key != source!.key);

  bool _awaitingRoomMedia(WatchPartySnapshot room) =>
      !room.isHost && room.media != null && room.media!.key != media.key;

  void _requestFollow(WatchPartySnapshot room, String messageKey,
      {bool force = false}) {
    final key = '${room.id}|${room.media?.key}|'
        '${room.sourceLocked ? room.source?.key : ''}';
    if (!force && _followNoticeKey == key) return;
    final notify = onFollowRequired;
    if (notify != null) {
      if (notify(messageKey)) _followNoticeKey = key;
    } else {
      onError?.call(messageKey);
      _followNoticeKey = key;
    }
  }

  Future<bool> _interceptAudio(AudioTrack track) async {
    final room = controller.snapshot;
    if (!_active || room == null) return false;
    if (_awaitingRoomMedia(room)) {
      _requestFollow(room, 'partyTitleChanged', force: true);
      return true;
    }
    if (room.media?.key != media.key) return false;
    if (_sourceMismatch(room)) {
      _requestFollow(room, 'partySourceLockedMismatch', force: true);
      return true;
    }
    if (!room.canControl) {
      onError?.call('partyHostRequired');
      return true;
    }
    try {
      await controller.command('audio',
          mediaKey: media.key,
          sourceKey: source?.key,
          audioTrack: describeWatchPartyAudio(engine, source, selected: track));
    } on WatchPartyException catch (error) {
      if (_active && error.code != 'cancelled') onError?.call(error.messageKey);
    }
    return true;
  }

  Future<void> _syncAudio(WatchPartySnapshot room) async {
    final desired = room.audioTrack;
    if (desired == null) return;
    final signature = '${room.id}|${desired.key}|${engine.selectedAudio.id}|'
        '${engine.audioTracks.map((t) => '${t.id}:${t.language}:${t.title}').join('|')}';
    if (_audioAppliedKey == signature) return;
    final track = matchWatchPartyAudio(desired, engine.audioTracks, source);
    if (track == null) {
      if (engine.audioTracks.isNotEmpty && _audioUnavailableKey != signature) {
        _audioUnavailableKey = signature;
        onError?.call('partyAudioTrackUnavailable');
      }
      return;
    }
    try {
      if (engine.selectedAudio.id != track.id) {
        await _native(() => engine.selectAudio(track));
      }
      if (_active && controller.snapshot?.audioTrack?.key == desired.key) {
        _audioAppliedKey = signature;
        _audioUnavailableKey = null;
      }
    } catch (_) {
      if (_active && _audioUnavailableKey != signature) {
        _audioUnavailableKey = signature;
        onError?.call('partyAudioTrackUnavailable');
      }
    }
  }

  void setForeground(bool value) {
    _foreground = value;
    if (!value) {
      controller.releasePlaybackStatus(this);
    } else {
      _wasMatching = false;
      _lastSeek = -10000;
      _resetPausedCorrection();
      unawaited(controller.refresh());
    }
  }

  void _changed() {
    if (_disposed) return;
    final previous = _observedSnapshot;
    final current = controller.snapshot;
    _observedSnapshot = current;
    final intentChanged = previous?.id != current?.id ||
        (previous != null &&
            current != null &&
            (!_sameTransport(previous, current) ||
                previous.audioTrack?.key != current.audioTrack?.key));
    if (_working) {
      _tickPending = true;
    } else if (intentChanged) {
      // Error/status notifications are not fresh playback intent. Reacting
      // immediately to our own failed RPC would otherwise retry in a loop.
      unawaited(_tick());
    }
  }

  Future<void> _native(Future<dynamic> Function() action) async {
    final result = await runZoned(action,
        zoneValues: {PlaybackEngine.watchPartyRemoteZone: true});
    // Core reports command outcomes without throwing; Legacy reports native
    // failures as exceptions. Both must keep failed sync visible to the user.
    if (result is PlaybackCommandResult && !result.applied && _active) {
      throw StateError('Watch Party native command rejected');
    }
  }

  Future<void> _restoreRate() async {
    final rate = _baseRate;
    final restore = _nudging && rate != null && engine.ready;
    _nudging = false;
    if (restore) await _native(() => engine.setRate(rate));
  }

  void _resetPausedCorrection() {
    _pausedCorrectionKey = null;
    _pausedCorrectionAttempts = 0;
    _pausedCorrectionWarned = false;
  }

  Future<void> _tick() async {
    if (!_active) return;
    if (_working) {
      _tickPending = true;
      return;
    }
    _working = true;
    try {
      final room = controller.snapshot;
      if (room == null || !media.supported) {
        await _restoreRate();
        _wasMatching = false;
        _lastSeek = -10000;
        _reportedNativeFailure = false;
        _resetPausedCorrection();
        return;
      }
      if (room.isHost &&
          (room.media == null || _canChangeMedia) &&
          room.media?.key != media.key &&
          _adoptedRoom != room.id &&
          controller.clock.monotonicMs - _lastMediaAttempt >= 1000 &&
          engine.ready &&
          !engine.failed) {
        _lastMediaAttempt = controller.clock.monotonicMs;
        _adoptedRoom = room.id;
        try {
          await controller.setMedia(media,
              positionMs: engine.position.inMilliseconds,
              playing: engine.playing,
              rate: engine.rate,
              source: source,
              audioTrack: describeWatchPartyAudio(engine, source));
        } on WatchPartyException catch (error) {
          _adoptedRoom = null;
          if (_active) onError?.call(error.messageKey);
        }
        return;
      }
      if (room.media?.key != media.key) {
        if (_awaitingRoomMedia(room)) {
          _requestFollow(room, 'partyTitleChanged');
          if (engine.playing) await _native(() => engine.pause());
        }
        await _restoreRate();
        if (!_active) return;
        controller.setPlaybackStatus('browsing', null, owner: this);
        _wasMatching = false;
        _lastSeek = -10000;
        _resetPausedCorrection();
        return;
      }
      _adoptedRoom = room.id;
      if (room.isHost &&
          engine.ready &&
          !engine.failed &&
          _sourcePublishedRoom != room.id) {
        if (room.source?.key != source?.key) {
          if (controller.clock.monotonicMs - _lastSourceAttempt >= 1000) {
            _lastSourceAttempt = controller.clock.monotonicMs;
            try {
              await controller.setSource(source);
              if (!_active) return;
              _sourcePublishedRoom = room.id;
              return;
            } on WatchPartyException catch (error) {
              if (_active) onError?.call(error.messageKey);
            }
          }
        } else {
          _sourcePublishedRoom = room.id;
        }
      }
      if (_sourceMismatch(room)) {
        _requestFollow(room, 'partySourceLockedMismatch');
        if (engine.playing) await _native(() => engine.pause());
        controller.setPlaybackStatus('browsing', null, owner: this);
        _wasMatching = false;
        _lastSeek = -10000;
        _resetPausedCorrection();
        return;
      }
      _followNoticeKey = null;
      final now = controller.clock.monotonicMs;
      final runtimeCompatible = room.durationMs <= 0 ||
          engine.duration.inMilliseconds <= 0 ||
          (room.durationMs - engine.duration.inMilliseconds).abs() <=
              (room.durationMs / 100).clamp(10000, 30000);
      if (!runtimeCompatible) {
        if (!_announcedMismatch) {
          _announcedMismatch = true;
          onError?.call('partyDifferentVersion');
        }
      } else {
        _announcedMismatch = false;
      }
      final roomId = room.id;
      bool validTransport() =>
          _active &&
          controller.snapshot?.id == roomId &&
          // Membership/readiness heartbeats advance the room revision too.
          // Only a newer transport intent invalidates an in-flight command.
          _sameTransport(controller.snapshot!, room) &&
          identical(engine.watchPartyCommand, _handler);
      bool current() => engine.ready && validTransport();
      String status;
      if (!engine.ready || engine.failed) {
        status = 'loading';
      } else if (engine.buffering) {
        if (_bufferSince < 0) _bufferSince = now;
        status = now - _bufferSince >= 1000 ? 'buffering' : 'ready';
      } else {
        _bufferSince = -1;
        status = 'ready';
      }
      controller.setPlaybackStatus(status, media.key, owner: this);
      // Native seeking can be unavailable, fail, or wait for network data on
      // either backend. Even a failed Core session can still be playing; a
      // room pause must reach native before readiness or seek correction.
      if (!room.playing && engine.playing && validTransport()) {
        await _native(() => engine.pause());
        if (!validTransport()) return;
      }
      if (!engine.ready || engine.failed) return;
      // Natural completion must stop the shared clock before reconciliation;
      // otherwise a playing room would repeatedly restart the final frames.
      if (room.isHost && room.playing && !room.waiting && engine.completed) {
        await controller.command('pause', mediaKey: media.key);
        return;
      }
      // A shorter independent edition can end before the host's file. Keep
      // the shared clock running, without replaying its final frames locally.
      if (!room.isHost &&
          engine.completed &&
          engine.duration > Duration.zero &&
          room.targetMs(controller.clock.nowMs) >=
              engine.duration.inMilliseconds - 250) {
        _wasMatching = true;
        return;
      }
      // A paused-open backend may require play intent to finish filling its
      // buffer. Waiting for buffering=false before play would deadlock it.
      if (engine.buffering) {
        if (current() && engine.playing != room.playing) {
          await _native(() => room.playing ? engine.play() : engine.pause());
        }
        return;
      }
      final target = room.targetMs(controller.clock.nowMs,
          localDurationMs: engine.duration.inMilliseconds);
      final drift = target - engine.position.inMilliseconds;
      // An already aligned paused-open source can play even when seeking is
      // unavailable. Only meaningful initial drift needs an alignment seek.
      bool shouldSeek;
      if (room.playing) {
        _resetPausedCorrection();
        shouldSeek = (!_wasMatching && drift.abs() > 250) || drift.abs() > 1500;
      } else {
        final pausedKey = '${room.id}|${media.key}|$target';
        if (_pausedCorrectionKey != pausedKey) {
          _pausedCorrectionKey = pausedKey;
          _pausedCorrectionAttempts = 0;
          _pausedCorrectionWarned = false;
          _lastSeek = -10000;
        }
        shouldSeek = drift.abs() > pausedToleranceMs &&
            _pausedCorrectionAttempts < maxPausedCorrectionAttempts;
        if (!shouldSeek &&
            drift.abs() > pausedToleranceMs &&
            !_pausedCorrectionWarned) {
          _pausedCorrectionWarned = true;
          onError?.call('partySyncFailed');
        }
      }
      if (shouldSeek) {
        // A throttled correction is still pending; do not play or announce a
        // successful match until that seek has actually been accepted.
        if (now - _lastSeek < 500 || !current()) return;
        _lastSeek = now;
        await _native(() => engine.seekTo(Duration(milliseconds: target)));
        if (!room.playing) _pausedCorrectionAttempts++;
        if (!current()) return;
      }
      _baseRate = room.rate;
      var rate = room.rate;
      if (!room.isHost && room.playing && !shouldSeek) {
        final threshold = _nudging ? 80 : 250;
        if (drift.abs() > threshold) rate *= drift > 0 ? 1.05 : 0.95;
      }
      _nudging = (rate - room.rate).abs() > 0.001;
      if ((engine.rate - rate).abs() > 0.005 && current()) {
        await _native(() => engine.setRate(rate.clamp(0.25, 4).toDouble()));
        if (!current()) return;
      }
      if (engine.playing != room.playing && current()) {
        await _native(() => room.playing ? engine.play() : engine.pause());
        if (!current()) return;
      }
      await _syncAudio(room);
      if (!current()) return;
      _wasMatching = true;
      _reportedNativeFailure = false;
      if (room.isHost &&
          !room.waiting &&
          now - _lastPublish >= 2000 &&
          now - _lastSeek >= 1000 &&
          drift.abs() <= 1500) {
        _lastPublish = now;
        await controller.publish(
            mediaKey: media.key,
            positionMs: engine.position.inMilliseconds,
            durationMs: engine.duration.inMilliseconds,
            source: source,
            audioTrack: room.audioTrack == null &&
                    engine.audioTracks.any(
                        (track) => !const ['auto', 'no'].contains(track.id))
                ? describeWatchPartyAudio(engine, source)
                : null);
      }
    } catch (error) {
      // Retired routes are expected to reject late work. An active route's
      // failure needs visible feedback instead of silently losing room sync.
      if (_active && !_reportedNativeFailure) {
        _reportedNativeFailure = true;
        debugPrint('Watch Party native reconciliation failed: '
            '${error.runtimeType}');
        onError?.call('partySyncFailed');
      }
    } finally {
      _working = false;
      if (_tickPending) {
        _tickPending = false;
        // One immediate reconciliation is enough to catch an intent received
        // during native work. Further self-notifications wait for the 250 ms
        // cadence, yielding to UI/timers even when an RPC fails synchronously.
        if (_immediateFollowUpAvailable) {
          _immediateFollowUpAvailable = false;
          scheduleMicrotask(() => unawaited(_tick()));
        }
      }
    }
  }

  bool _sameTransport(WatchPartySnapshot a, WatchPartySnapshot b) =>
      a.media?.key == b.media?.key &&
      a.playing == b.playing &&
      a.rate == b.rate &&
      a.positionMs == b.positionMs &&
      a.atMs == b.atMs &&
      a.sourceLocked == b.sourceLocked &&
      (!a.sourceLocked || a.source?.key == b.source?.key) &&
      a.waiting == b.waiting;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    controller.removeListener(_changed);
    if (identical(engine.watchPartyCommand, _handler)) {
      engine.watchPartyCommand = null;
    }
    if (identical(engine.watchPartyAudioCommand, _audioHandler)) {
      engine.watchPartyAudioCommand = null;
    }
    controller.releasePlaybackStatus(this);
  }
}
