import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Temporary Station 03 diagnostics. Runtime hooks are active only in Debug
/// and Profile builds; Release compiles the guarded call sites away.
class PlayerDiagnostics {
  PlayerDiagnostics._();

  static const bool enabled = kDebugMode || kProfileMode;
  static final PlayerDiagnostics instance = PlayerDiagnostics._();

  static const Duration _summaryInterval = Duration(seconds: 10);
  static const double _frameBudgetMs = 1000 / 60;

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
    debugPrint('NOVA_DIAG enabled mode=${kProfileMode ? 'profile' : 'debug'} '
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

  /// Reads mpv decoder properties only when a diagnostics surface explicitly
  /// requests a snapshot. This is never scheduled or called by the player.
  Future<void> captureDecoderSnapshot({
    required Future<String> Function(String property) readProperty,
  }) async {
    if (!enabled) return;
    try {
      final values = await Future.wait(<Future<String>>[
        readProperty('video-codec'),
        readProperty('hwdec-current'),
        readProperty('decoder-frame-drop-count'),
        readProperty('frame-drop-count'),
      ]);
      recordDecoderSnapshot(
        codec: values[0],
        hardwareDecoder: values[1].isEmpty ? 'software/unknown' : values[1],
        decodedDrops: values[2],
        outputDrops: values[3],
      );
    } catch (_) {
      // Optional mpv statistics must never affect playback.
    }
  }

  void recordDecoderSnapshot({
    required String codec,
    required String hardwareDecoder,
    required String decodedDrops,
    required String outputDrops,
  }) {
    if (!enabled) return;
    debugPrint('NOVA_DIAG decoder codec=$codec hwdec=$hardwareDecoder '
        'decoderDrops=$decodedDrops outputDrops=$outputDrops');
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
