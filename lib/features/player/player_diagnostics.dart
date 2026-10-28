import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Playback diagnostics for Debug/Profile, or an explicitly instrumented
/// Release build. Ordinary Release builds keep these hooks disabled.
class PlayerDiagnostics {
  PlayerDiagnostics._();

  static const bool enabled = kDebugMode ||
      kProfileMode ||
      bool.fromEnvironment('NOVA_PLAYER_DIAGNOSTICS');
  static final PlayerDiagnostics instance = PlayerDiagnostics._();

  static const Duration _summaryInterval = Duration(seconds: 10);
  static double get _frameBudgetMs {
    final views = SchedulerBinding.instance.platformDispatcher.views;
    final refreshRate = views.isEmpty ? 60.0 : views.first.display.refreshRate;
    return 1000 / (refreshRate > 0 ? refreshRate : 60.0);
  }

  final Map<String, int> _counts = <String, int>{};
  final ListQueue<double> _buildMs = ListQueue<double>();
  final ListQueue<double> _rasterMs = ListQueue<double>();
  int _jankyBuildFrames = 0;
  int _jankyRasterFrames = 0;
  int _frames = 0;
  DateTime? _lastSummary;
  bool _started = false;

  void start() {
    if (!enabled || _started) return;
    _started = true;
    _lastSummary = DateTime.now();
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    final mode =
        kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug');
    debugPrint('NOVA_DIAG enabled mode=$mode '
        'frameBudgetMs=${_frameBudgetMs.toStringAsFixed(2)}');
  }

  void record(String event) {
    if (!enabled) return;
    start();
    _counts.update(event, (value) => value + 1, ifAbsent: () => 1);
  }

  void recordFirstFrame(Duration elapsed) {
    if (!enabled) return;
    debugPrint('NOVA_DIAG firstFrameMs=${elapsed.inMicroseconds / 1000}');
  }

  /// Initial state is separate from transitions. Buffer-position callbacks
  /// never count as a stall; only an actual native buffering-state change does.
  void recordBufferingState({
    required bool media3,
    required bool? previous,
    required bool current,
  }) {
    if (!enabled) return;
    if (previous == current) return;
    final engine = media3 ? 'media3' : 'mpv';
    if (previous == null) {
      debugPrint('NOVA_DIAG engine=$engine bufferingInitial=$current');
      return;
    }
    record('${engine}Buffering${current ? 'Started' : 'Ended'}');
    debugPrint('NOVA_DIAG engine=$engine buffering=$current');
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!enabled) return;
    for (final timing in timings) {
      final build = timing.buildDuration.inMicroseconds / 1000;
      final raster = timing.rasterDuration.inMicroseconds / 1000;
      _frames++;
      if (build > _frameBudgetMs) _jankyBuildFrames++;
      if (raster > _frameBudgetMs) _jankyRasterFrames++;
      _addBounded(_buildMs, build);
      _addBounded(_rasterMs, raster);
    }
    final now = DateTime.now();
    final last = _lastSummary ?? now;
    if (now.difference(last) < _summaryInterval || _frames == 0) return;
    final buildP50 = _percentile(_buildMs, .50);
    final rasterP50 = _percentile(_rasterMs, .50);
    debugPrint('NOVA_DIAG frames=$_frames '
        'buildP50Ms=${buildP50.toStringAsFixed(2)} '
        'rasterP50Ms=${rasterP50.toStringAsFixed(2)} '
        'buildOverBudget=$_jankyBuildFrames '
        'rasterOverBudget=$_jankyRasterFrames '
        'budgetMs=${_frameBudgetMs.toStringAsFixed(2)} '
        'events=${Map<String, int>.from(_counts)}');
    _counts.clear();
    _buildMs.clear();
    _rasterMs.clear();
    _jankyBuildFrames = 0;
    _jankyRasterFrames = 0;
    _frames = 0;
    _lastSummary = now;
  }

  void _addBounded(ListQueue<double> values, double value) {
    if (values.length == 600) values.removeFirst();
    values.addLast(value);
  }

  double _percentile(ListQueue<double> values, double percentile) {
    if (values.isEmpty) return 0;
    final sorted = values.toList()..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index];
  }
}

/// A bounded, read-only mpv probe. One native sample may be outstanding at a
/// time, including after a timeout: a hung property request never accumulates
/// more requests. Source replacement and retirement invalidate pending output.
class MpvPlaybackDiagnostics {
  MpvPlaybackDiagnostics({
    required this.readProperty,
    required this.emit,
    this.interval = const Duration(seconds: 5),
    this.readTimeout = const Duration(seconds: 2),
  });

  final Future<String> Function(String property) readProperty;
  final void Function(String message) emit;
  final Duration interval;
  final Duration readTimeout;
  Timer? _timer;
  int _generation = 0;
  bool _sampling = false;

  static const _properties = <String>[
    'video-codec',
    'hwdec-current',
    'video-pts',
    'avsync',
    'paused-for-cache',
    'demuxer-cache-duration',
    'frame-drop-count',
    'decoder-frame-drop-count',
  ];

  void start() {
    stop();
    final generation = _generation;
    _timer = Timer.periodic(interval, (_) => unawaited(_capture(generation)));
  }

  void stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  bool _current(int generation) => _timer != null && generation == _generation;

  Future<void> _capture(int generation) async {
    if (_sampling || !_current(generation)) return;
    _sampling = true;
    final pending = Future.wait(_properties.map((property) async {
      try {
        return await readProperty(property);
      } catch (_) {
        return '';
      }
    }));
    // Future.timeout does not cancel the underlying native read. Keep the
    // exclusion held until those reads actually finish, even after stop/start.
    unawaited(pending.then((_) {
      _sampling = false;
    }));
    try {
      final values = await pending.timeout(readTimeout);
      if (!_current(generation)) return;
      emit('NOVA_DIAG engine=mpv '
          'codec=${_codec(values[0])} hwdec=${_token(values[1])} '
          'videoPts=${diagnosticNumber(values[2])} '
          'avsync=${diagnosticNumber(values[3])} '
          'pausedForCache=${_flag(values[4])} '
          'cacheSeconds=${diagnosticNumber(values[5])} '
          'outputDrops=${diagnosticNumber(values[6])} '
          'decoderDrops=${diagnosticNumber(values[7])}');
    } on TimeoutException {
      if (_current(generation)) emit('NOVA_DIAG engine=mpv sample=timeout');
    }
  }

  static String _codec(String value) => _token(value.split(' ').first);
  static String _token(String value) {
    final match = RegExp(r'[a-zA-Z0-9_.+-]{1,64}').matchAsPrefix(value);
    return match != null && match.end == value.length ? value : 'unknown';
  }

  static String _flag(String value) => switch (value) {
        'yes' || 'true' || '1' => 'true',
        'no' || 'false' || '0' => 'false',
        _ => 'unknown',
      };
}

/// Only finite numeric telemetry is emitted. Native errors and unexpected
/// strings (including source URLs or headers) are never interpolated into logs.
String diagnosticNumber(Object? value) {
  final number = value is num
      ? value
      : value is String && value.length <= 64
          ? num.tryParse(value)
          : null;
  return number != null && number.isFinite ? number.toString() : 'unknown';
}
