import 'dart:async';
import '../../core/watch_party/watch_party_controller.dart';
import '../../core/watch_party/watch_party_models.dart';
import 'engine/playback_engine.dart';

/// Uses exact engine reads, never the coalesced display timeline. Its own
/// timer/listener never calls setState on either fullscreen player page.
class WatchPartyPlayerBinding {
  WatchPartyPlayerBinding(
      {required this.controller,
      required this.engine,
      required this.media,
      required this.isActive,
      this.onError}) {
    _handler = _intercept;
    engine.watchPartyCommand = _handler;
    _canChangeMedia = controller.snapshot?.isHost ?? false;
    controller.addListener(_changed);
    _timer = Timer.periodic(
        const Duration(milliseconds: 250), (_) => unawaited(_tick()));
    unawaited(_tick());
  }
  final WatchPartyController controller;
  final PlaybackEngine engine;
  final WatchPartyMedia media;
  final bool Function() isActive;
  final void Function(String messageKey)? onError;
  late final Future<bool> Function(String, double?) _handler;
  Timer? _timer;
  bool _disposed = false,
      _working = false,
      _foreground = true,
      _canChangeMedia = false;
  bool _wasMatching = false,
      _nudging = false,
      _compatible = true,
      _announcedMismatch = false;
  String? _adoptedRoom;
  String? _notifiedMediaKey;
  int _lastSeek = -10000, _lastPublish = -10000, _bufferSince = -1;
  double? _baseRate;
  bool? _lastPlaying;
  bool get _active =>
      !_disposed &&
      isActive() &&
      _foreground &&
      identical(engine.watchPartyCommand, _handler);

  Future<bool> _intercept(String action, double? value) async {
    final room = controller.snapshot;
    if (!_active || !_compatible || room?.media?.key != media.key) return false;
    if (!room!.canControl) {
      onError?.call('partyHostRequired');
      return true;
    }
    try {
      await controller.command(action,
          mediaKey: media.key,
          positionMs:
              action == 'seek' ? value?.round().clamp(0, 43200000) : null,
          rate: action == 'rate' ? value?.clamp(0.25, 4).toDouble() : null);
    } on WatchPartyException catch (error) {
      if (!_disposed) onError?.call(error.messageKey);
    }
    return true;
  }

  void setForeground(bool value) {
    _foreground = value;
    if (!value) {
      controller.releasePlaybackStatus(this);
    } else {
      _wasMatching = false;
      unawaited(controller.refresh());
    }
  }

  void _changed() {
    if (!_disposed) unawaited(_tick());
  }

  Future<void> _native(Future<void> Function() action) =>
      runZoned(action, zoneValues: {PlaybackEngine.watchPartyRemoteZone: true});

  Future<void> _restoreRate() async {
    final rate = _baseRate;
    final restore = _nudging && rate != null && engine.ready;
    _nudging = false;
    if (restore) await _native(() => engine.setRate(rate));
  }

  Future<void> _tick() async {
    if (_working || !_active) return;
    _working = true;
    try {
      final room = controller.snapshot;
      if (room == null || !media.supported) {
        await _restoreRate();
        _wasMatching = false;
        return;
      }
      if (room.isHost &&
          (room.media == null || _canChangeMedia) &&
          room.media?.key != media.key &&
          _adoptedRoom != room.id &&
          engine.ready &&
          !engine.failed) {
        _adoptedRoom = room.id;
        try {
          await controller.setMedia(media,
              positionMs: engine.position.inMilliseconds,
              playing: engine.playing,
              rate: engine.rate);
        } on WatchPartyException catch (error) {
          _adoptedRoom = null;
          if (_active) onError?.call(error.messageKey);
        }
        return;
      }
      if (room.media?.key != media.key) {
        await _restoreRate();
        if (!_active) return;
        controller.setPlaybackStatus('browsing', null, owner: this);
        if (_wasMatching &&
            room.media != null &&
            _notifiedMediaKey != room.media!.key) {
          _notifiedMediaKey = room.media!.key;
          onError?.call('partyTitleChanged');
        }
        _wasMatching = false;
        return;
      }
      _adoptedRoom = room.id;
      final now = controller.clock.monotonicMs;
      _compatible = room.durationMs <= 0 ||
          engine.duration.inMilliseconds <= 0 ||
          (room.durationMs - engine.duration.inMilliseconds).abs() <=
              (room.durationMs / 100).clamp(10000, 30000);
      if (!_compatible) {
        await _restoreRate();
        if (!_active) return;
        controller.setPlaybackStatus('browsing', null, owner: this);
        if (!_announcedMismatch) {
          _announcedMismatch = true;
          onError?.call('partyDifferentVersion');
        }
        return;
      }
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
      if (!engine.ready || engine.failed) return;
      // Natural completion must stop the shared clock before reconciliation;
      // otherwise a playing room would repeatedly restart the final frames.
      if (room.isHost && room.playing && !room.waiting && engine.completed) {
        await controller.command('pause', mediaKey: media.key);
        return;
      }
      // A paused-open backend may require play intent to finish filling its
      // buffer. Waiting for buffering=false before play would deadlock it.
      if (engine.buffering) {
        if (_active &&
            controller.snapshot?.revision == room.revision &&
            engine.playing != room.playing) {
          await _native(() => room.playing ? engine.play() : engine.pause());
        }
        return;
      }
      final revision = room.revision, roomId = room.id;
      bool current() =>
          _active &&
          engine.ready &&
          controller.snapshot?.id == roomId &&
          controller.snapshot?.revision == revision &&
          identical(engine.watchPartyCommand, _handler);
      final target = room.targetMs(controller.clock.nowMs,
          localDurationMs: engine.duration.inMilliseconds);
      final drift = target - engine.position.inMilliseconds;
      final stateChanged = _lastPlaying != room.playing;
      final forceSeek = !_wasMatching || stateChanged;
      final shouldSeek =
          forceSeek || (room.playing ? drift.abs() > 1500 : drift.abs() > 500);
      if (shouldSeek && now - _lastSeek >= 500 && current()) {
        _lastSeek = now;
        await _native(() => engine.seekTo(Duration(milliseconds: target)));
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
      _wasMatching = true;
      _lastPlaying = room.playing;
      if (room.isHost &&
          !room.waiting &&
          now - _lastPublish >= 2000 &&
          now - _lastSeek >= 1000 &&
          drift.abs() <= 1500) {
        _lastPublish = now;
        await controller.publish(
            mediaKey: media.key,
            positionMs: engine.position.inMilliseconds,
            durationMs: engine.duration.inMilliseconds);
      }
    } catch (_) {
      /* A retiring/failed native engine cannot keep the binding alive. */
    } finally {
      _working = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    controller.removeListener(_changed);
    if (identical(engine.watchPartyCommand, _handler)) {
      engine.watchPartyCommand = null;
    }
    controller.releasePlaybackStatus(this);
  }
}
