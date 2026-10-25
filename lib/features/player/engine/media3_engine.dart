import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../player_diagnostics.dart';
import 'playback_engine.dart';

/// Android Media3 transport. Native IDs reject callbacks from retired players.
class Media3Engine extends PlaybackEngine {
  static const _methods = MethodChannel('nova/player/media3');
  static const _events = EventChannel('nova/player/media3/events');
  static final Stream<dynamic> _broadcast = _events.receiveBroadcastStream();
  int? _id;
  int? _texture;
  bool _closing = false;
  Future<void>? _closeFuture;
  Future<void>? _creation;
  StreamSubscription<dynamic>? _subscription;
  Directory? _subtitleDirectory;
  File? _subtitleFile;
  final _texts = StreamController<List<String>>.broadcast(sync: true);
  final _geometry = ValueNotifier<(double, int)>((1, 0));
  Map<dynamic, dynamic> _state = const {};
  List<String> _cues = const [];
  List<AudioTrack> _audio = const [];
  List<SubtitleTrack> _subtitles = const [];
  AudioTrack _selectedAudio = AudioTrack.auto();
  SubtitleTrack _selectedSubtitle = SubtitleTrack.auto();
  SubtitleTrack? _external;
  double _lastVolume = 1;
  int? _errorCode;
  final _diagnosticClock = Stopwatch()..start();
  int _lastDiagnosticMs = 0;

  /// Parsing/decoder incompatibility only. Network, authorization and DRM errors
  /// are deliberately excluded, as replacing the decoder cannot repair them.
  bool get canFallback => compatibilityFailure(_errorCode);
  static bool compatibilityFailure(int? code) =>
      code != null &&
      ((code >= 3001 && code <= 3004) ||
          (code >= 4001 && code <= 4005) ||
          code == 5001 ||
          code == 7100);

  @override
  bool get ready => _state['ready'] == true;
  @override
  bool get playing => _state['playing'] == true;
  @override
  bool get buffering => _state['buffering'] == true;
  @override
  bool get completed => _state['completed'] == true;
  @override
  bool get failed => _errorCode != null;
  @override
  String? get errorMessage => failed ? 'media3_$_errorCode' : null;
  Duration _time(String key) =>
      Duration(milliseconds: (_state[key] as num?)?.toInt() ?? 0);
  @override
  Duration get position => _time('positionMs');
  @override
  Duration get duration => _time('durationMs');
  @override
  Duration get bufferedEnd => _time('bufferedMs');
  @override
  double get rate => (_state['rate'] as num?)?.toDouble() ?? 1;
  @override
  double get volume => (_state['volume'] as num?)?.toDouble() ?? 1;
  @override
  bool get muted => volume <= .001;
  @override
  List<AudioTrack> get audioTracks => _audio;
  @override
  List<SubtitleTrack> get subtitleTracks => _subtitles;
  @override
  AudioTrack get selectedAudio => _selectedAudio;
  @override
  SubtitleTrack get selectedSubtitle => _selectedSubtitle;
  @override
  Stream<List<String>> get subtitleTexts => _texts.stream;
  @override
  List<String> get subtitleTextSnapshot => _cues;

  Map<String, Object?> get diagnostics => {
        'engine': 'media3',
        'firstFrameMs': _state['firstFrameMs'],
        'droppedFrames': _state['droppedFrames'],
        'bufferTargetBytes': _state['bufferTargetBytes'],
      };

  Future<void> _create() async {
    final response = await _methods.invokeMapMethod<String, dynamic>('create');
    _id = (response!['id'] as num).toInt();
    _texture = (response['textureId'] as num).toInt();
    if (_closing) return; // close() waits for allocation before retiring it.
    _subscription = _broadcast.listen((value) {
      if (_closing || value is! Map || value['id'] != _id) return;
      if (value['event'] == 'tracks') {
        _receiveTracks(value['tracks'] as List? ?? const []);
      } else if (value['event'] == 'cues') {
        _receiveCues(value['cues']);
      } else {
        _receiveState(value);
      }
    }, onError: (Object error) {
      if (!_closing) {
        _errorCode = -1;
        notifyListeners();
      }
    });
  }

  void _receiveCues(dynamic values) {
    final next = (values as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    if (next.join('\n') == _cues.join('\n')) return;
    _cues = next;
    _texts.add(next);
  }

  void _receiveState(Map<dynamic, dynamic> value) {
    if (_closing) return;
    if (PlayerDiagnostics.enabled &&
        value['firstFrameMs'] is num &&
        _state['firstFrameMs'] == null) {
      PlayerDiagnostics.instance.recordFirstFrame(
          Duration(milliseconds: (value['firstFrameMs'] as num).toInt()));
    }
    _state = value;
    _errorCode = (value['errorCode'] as num?)?.toInt();
    final aspect = (value['aspect'] as num?)?.toDouble() ?? 1;
    if (aspect.isFinite && aspect > 0) {
      _geometry.value =
          (aspect, ((value['rotationDegrees'] as num?)?.toInt() ?? 0) ~/ 90);
    }
    _receiveCues(value['cues']);
    if (PlayerDiagnostics.enabled &&
        _diagnosticClock.elapsedMilliseconds - _lastDiagnosticMs >= 10000) {
      _lastDiagnosticMs = _diagnosticClock.elapsedMilliseconds;
      debugPrint('NOVA_DIAG media3 firstFrameMs=${value['firstFrameMs']} '
          'decoderDrops=${value['droppedFrames']} bufferTargetBytes=${value['bufferTargetBytes']}');
    }
    notifyListeners();
  }

  void _receiveTracks(List<dynamic> rows) {
    final audio = <AudioTrack>[AudioTrack.auto()];
    final subtitles = <SubtitleTrack>[SubtitleTrack.auto(), SubtitleTrack.no()];
    var selectedAudio = AudioTrack.auto();
    var selectedSubtitle = SubtitleTrack.no();
    for (final row in rows.whereType<Map>()) {
      final id = row['id'] as String;
      if (row['type'] == 1) {
        final track =
            AudioTrack(id, row['title'] as String?, row['language'] as String?);
        audio.add(track);
        if (row['selected'] == true) selectedAudio = track;
      } else if (row['type'] == 3) {
        final track = SubtitleTrack(
            id, row['title'] as String?, row['language'] as String?);
        subtitles.add(track);
        if (row['selected'] == true) selectedSubtitle = track;
      }
    }
    _audio = audio;
    _subtitles = subtitles;
    _selectedAudio = selectedAudio;
    _selectedSubtitle = _external ?? selectedSubtitle;
    notifyListeners();
  }

  Future<void> _command(String method,
      [Map<String, Object?> args = const {}]) async {
    if (_closing || _id == null) return;
    try {
      final value = await _methods
          .invokeMapMethod<dynamic, dynamic>(method, {'id': _id, ...args});
      if (value != null) _receiveState(value);
    } on PlatformException catch (error) {
      if (!_closing && error.details is Map) {
        _errorCode = ((error.details as Map)['errorCode'] as num?)?.toInt();
        notifyListeners();
      }
      rethrow;
    }
  }

  @override
  Future<void> open(String url,
      {Duration? startAt, Map<String, String>? httpHeaders}) async {
    await (_creation ??= _create());
    if (_closing) return;
    await _command('open',
        {'url': url, 'headers': httpHeaders ?? const <String, String>{}});
    if (startAt != null && startAt > Duration.zero) await seekTo(startAt);
  }

  Future<bool?> querySeekable() async {
    await _command('state');
    return _state['seekable'] as bool?;
  }

  Future<Uint8List?> captureFrame() async {
    if (_closing || !ready || _id == null) return null;
    return _methods.invokeMethod<Uint8List>('capture', {'id': _id});
  }

  @override
  Future<void> play() => _command('play');
  @override
  Future<void> pause() => _command('pause');
  @override
  Future<void> togglePlayPause() => playing ? pause() : play();
  @override
  Future<void> seekTo(Duration target) => _command('seek',
      {'positionMs': target.inMilliseconds.clamp(0, duration.inMilliseconds)});
  @override
  Future<void> seekBy(int seconds) =>
      seekTo(position + Duration(seconds: seconds));
  @override
  Future<void> setRate(double rate) =>
      _command('rate', {'value': rate.clamp(.25, 4)});
  @override
  Future<void> setVolume(double volume) {
    if (volume > .001) _lastVolume = volume.clamp(0, 1);
    return _command('volume', {'value': volume.clamp(0, 1)});
  }

  @override
  Future<void> toggleMute() => setVolume(muted ? _lastVolume : 0);
  @override
  Future<void> selectAudio(AudioTrack track) =>
      _command('audio', {'track': track.id});
  @override
  Future<void> selectSubtitle(SubtitleTrack track) async {
    if (track.uri) return setSubtitleUri(track.id, title: track.title);
    if (track.data) {
      if (_closing) return;
      final text = track.id.trimLeft();
      final mime = text.startsWith('WEBVTT')
          ? 'text/vtt'
          : text.startsWith('[Script Info]')
              ? 'text/x-ssa'
              : 'application/x-subrip';
      final directory = _subtitleDirectory ??=
          await Directory.systemTemp.createTemp('nova-subtitle-');
      if (_closing) {
        await directory.delete(recursive: true);
        return;
      }
      final file = File(
          '${directory.path}/subtitle-${DateTime.now().microsecondsSinceEpoch}.txt');
      await file.writeAsString(track.id);
      await _command('externalSubtitle', {
        'uri': file.uri.toString(),
        'mime': mime,
        'title': track.title,
        'language': track.language
      });
      if (!_closing) {
        final previous = _subtitleFile;
        _subtitleFile = file;
        if (previous != null && await previous.exists()) {
          await previous.delete();
        }
        if (_closing) return;
        _external = track;
        _selectedSubtitle = track;
        notifyListeners();
      }
      return;
    }
    _external = null;
    await _command('subtitle', {'track': track.id});
    if (!_closing) {
      _selectedSubtitle = track;
      notifyListeners();
    }
  }

  @override
  Future<void> setSubtitleUri(String url, {String? title}) async {
    final path = Uri.parse(url).path.toLowerCase();
    final mime = path.endsWith('.vtt')
        ? 'text/vtt'
        : path.endsWith('.ass') || path.endsWith('.ssa')
            ? 'text/x-ssa'
            : 'application/x-subrip';
    await _command(
        'externalSubtitle', {'uri': url, 'mime': mime, 'title': title});
    if (!_closing) {
      _external = SubtitleTrack.uri(url, title: title);
      _selectedSubtitle = _external!;
      notifyListeners();
    }
  }

  // Core switches to libmpv before applying non-zero timing offsets.
  @override
  Future<void> setSubtitleDelayMs(int delayMs) async {
    if (delayMs != 0) throw UnsupportedError('Timing offset requires libmpv');
  }

  @override
  Future<void> setAudioDelayMs(int delayMs) async {
    if (delayMs != 0) throw UnsupportedError('Timing offset requires libmpv');
  }

  @override
  Widget buildVideoSurface(BoxFit fit) => ValueListenableBuilder<(double, int)>(
      valueListenable: _geometry,
      builder: (context, geometry, child) => _texture == null
          ? const SizedBox.shrink()
          : SizedBox.expand(
              child: FittedBox(
                  fit: fit,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                      width: geometry.$1 * 1000,
                      height: 1000,
                      child: RotatedBox(
                          quarterTurns: geometry.$2,
                          child: Texture(textureId: _texture!))))));

  Future<void> close() => _closeFuture ??= _close();
  Future<void> _close() async {
    _closing = true;
    try {
      await _creation;
    } catch (_) {/* Allocation failure has no live ID. */}
    if (_id != null) await _methods.invokeMethod<void>('close', {'id': _id});
    await _subscription?.cancel();
    await _texts.close();
    _geometry.dispose();
    final directory = _subtitleDirectory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
    super.dispose();
  }

  @override
  // close() calls super.dispose after awaitable native retirement.
  // ignore: must_call_super
  void dispose() {
    unawaited(close());
  }
}
