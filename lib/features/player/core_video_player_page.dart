import 'package:nova_mobile/l10n/nova_strings.dart';
import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../core/models/media_item.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/horse_theme.dart';
import '../../core/torrent/torrent_models.dart';
import '../../core/torrent/torrent_service.dart';
import '../media/sources_page.dart';
import '../media/stream_loading.dart';
import 'engine/playback_engine.dart';
import 'gesture_math.dart';
import 'playback_preferences.dart';
import 'player_diagnostics.dart';
import 'segments/playback_segments.dart';
import 'session/playback_progress.dart';
import 'session/playback_session.dart';
import 'session/playback_state.dart';
import 'session/playback_checkpoint.dart';
import 'temporary_speed_hold.dart';
import 'widgets/player_session_surface.dart';
import 'stream_headers.dart';
import 'widgets/player_chrome.dart';
import 'widgets/player_side_panel.dart';
import 'widgets/player_sheets.dart';
import 'widgets/subtitle_overlay.dart';

/// Cinematic player (reference design): the video is the screen — white
/// controls, teal→blue gradient timeline, large outlined central play
/// control, side rails (orientation / fit / lock · audio / episodes / speed)
/// and gesture-first interaction:
///   · tap            — show / hide chrome
///   · double-tap     — ±10 s (edges) · play/pause (center)
///   · horizontal drag— scrub with live seek HUD
///   · vertical drag  — left: brightness · right: system volume
///   · pinch          — zoom 1×–4×
/// Engine is libmpv (media_kit) behind the [PlaybackEngine] facade.
class CoreVideoPlayerPage extends StatefulWidget {
  const CoreVideoPlayerPage({
    super.key,
    required this.item,
    required this.url,
    required this.streamName,
    required this.videoId,
    this.initialPositionMs,
    this.season,
    this.episode,
    this.streams = const [],
    this.streamIndex,
    this.headers,
    this.filename,
    this.torrent,
    this.recordProgress = true,
    this.continuity,
  });

  final MediaItem item;
  final String url;
  final String streamName;
  final String videoId;
  final int? initialPositionMs;
  final int? season;
  final int? episode;

  /// The stream row(s) known at launch — at least the PICKED one. The
  /// skip-intro/outro + Up-Next resolver reads the current row's metadata
  /// (behaviorHints etc.), and the sources side-panel seeds its list from
  /// it (refresh re-fetches the full ranked list).
  final List<Map<String, dynamic>> streams;
  final int? streamIndex;

  /// Extra HTTP headers (addon behaviorHints.proxyHeaders) for direct streams.
  final Map<String, String>? headers;

  /// Human stream name hint (used for debrid resolution).
  final String? filename;

  /// Prepared on-device torrent stream (when source was an infoHash).
  final PreparedTorrent? torrent;
  final bool recordProgress;
  final PlaybackContinuity? continuity;

  @override
  State<CoreVideoPlayerPage> createState() => _CoreVideoPlayerPageState();
}

enum _GestureMode { none, seek, brightness, volume, zoom }

class _CoreVideoPlayerPageState extends State<CoreVideoPlayerPage>
    with WidgetsBindingObserver {
  PlaybackSession? _engine;
  PlaybackPanelToken? _panelToken;
  Object? _featureProjection;
  late final AppState _app = context.read<AppState>();
  Timer? _hideTimer;
  StreamSubscription<TorrentStatus>? _torrentSub;
  TorrentStatus? _torrentStatus;
  Timer? _hintTimer;

  bool _controlsVisible = true;
  final TemporarySpeedHold _temporarySpeed = TemporarySpeedHold();
  final ValueNotifier<int> _hudRevision = ValueNotifier<int>(0);
  bool _controlsVisibleBeforeHold = true;
  bool _locked = false;
  bool _sheetOpen = false;

  // Task 139: the right-half picker panel (subtitles / audio / sources).
  // `_panelWasPlaying` + `_panelEngine` reproduce the A1 pause/resume
  // contract for the in-page overlay: pause on open, resume ONLY if it was
  // playing, and never resume an engine that was swapped mid-panel.
  PlayerPanelKind? _panel;
  bool _panelWasPlaying = false;

  // Panel data (owned by the page so the header refresh button works):
  // streams seed from the delivered list, addon subtitles re-fetch on open.
  List<Map<String, dynamic>> _panelStreams = const [];
  List<Map<String, dynamic>> _panelExternalSubs = const [];
  bool _panelLoading = false;
  bool _panelRefreshing = false;
  BoxFit _fit = BoxFit.contain;
  double _zoom = 1.0;
  bool _showRemaining = false;
  bool _fullscreen = true;

  // Persisted playback preferences are applied once after mpv exposes its
  // embedded tracks. Manual picker choices permanently win for this page.
  final PlaybackPreferenceSession _preferenceSession =
      PlaybackPreferenceSession();

  // All page exits pass through the same progress-saving confirmation flow.
  bool _allowRoutePop = false;
  bool _leaveDialogOpen = false;
  bool _closing = false;

  // Resume flow.
  bool _resuming = false;
  int? _resumePositionMs;
  bool _resumeTransitioning = false;
  // Task 127: engine-construction failure (e.g. missing native libs) — must
  // surface through the in-page error panel instead of the release grey box.
  String? _engineInitError;
  bool _stopScrobbled = false;
  bool _upNextDismissed = false;
  int _streamIndex = 0;

  // Task 130: live subtitle style. The settings sheet pushes every preview
  // tick here (instant on-screen effect); commits persist through
  // AppState.setSetting, and initState seeds from the persisted values so
  // the style survives player re-open and the next-episode push-replacement.
  late final ValueNotifier<SubtitleStyle> _subStyle;

  // Gesture state.
  _GestureMode _mode = _GestureMode.none;
  double _zoomStart = 1.0;
  double _dragStartDx = 0;
  double _dragAccumDx = 0;
  int _positionAtDragStartMs = 0;
  double? _brightnessStart;
  double _hudValue = 0;
  int _hudDeltaSeconds = 0;
  int _hudTargetMs = 0;

  // Double-tap ripple state (Task 125: cumulative ±N burst per side).
  int _rippleKey = 0;
  bool _rippleForward = false;
  int _rippleSeconds = 0;
  Timer? _rippleTimer;

  // Gesture HUD linger (spec §6: fade ~1s after the drag ends).
  Timer? _hudLingerTimer;

  // Workstream C: the last subtitle-values projection applied to the
  // overlay/engine. AppState notifications diff against this, so subtitle
  // writes from OUTSIDE the player (settings page, cloud-sync merge, backup
  // restore) restyle a live player instantly.
  Map<String, Object?> _lastSubValues = const {};

  // Workstream B: timing segments resolved once per page instance, plus the
  // guards against double next-episode navigation.
  late PlaybackSegments _segments;
  bool _episodeTransitionBusy = false;
  bool _autoAdvanceFired = false;

  // Workstream A2: the volume gesture captures the system level ONCE per
  // drag (the old per-tick getVolume() raced the platform round-trip and
  // let stale reads snap the level back mid-drag), and the vertical delta
  // ACCUMULATES across ticks like the seek gesture's dx — the old code
  // re-applied only the current tick's delta from the start value, so drags
  // barely moved the value.
  double? _volumeStart;
  double _dragAccumDy = 0;

  @override
  void initState() {
    super.initState();
    PlayerDiagnostics.instance.start();
    WidgetsBinding.instance.addObserver(this);
    _streamIndex = widget.streamIndex ?? 0;
    final resumeAction = NovaPlaybackPreferences.resumeAction(
      _app.webSettings,
      widget.initialPositionMs,
    );
    _resumePositionMs = resumeAction == ResumePlaybackAction.startOver
        ? 0
        : widget.initialPositionMs;
    _resuming = resumeAction == ResumePlaybackAction.prompt;
    final continuity = widget.continuity;
    if (continuity != null) {
      _resuming = !continuity.resumeResolved;
      _resumePositionMs = continuity.position.inMilliseconds;
    }
    _fit = NovaPlaybackPreferences.videoFit(_app.webSettings['videoFill']);
    SystemChrome.setPreferredOrientations(const [
      // Spec §0-ب: landscape-only player — portrait rotation is locked out.
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _subStyle = ValueNotifier<SubtitleStyle>(
      SubtitleStyle.fromMap(context.read<AppState>().webSettings),
    );
    _lastSubValues = SubtitleStyle.valuesFrom(_app.webSettings);
    // Workstream C: the player now listens to AppState so every subtitle
    // write reaches the running video (see [_onAppSettingsChanged]).
    _app.addListener(_onAppSettingsChanged);
    _resolveSegments();
    _createEngine();
    _listenTorrent();
  }

  /// Workstream B: timing windows for skip-intro/outro + next-episode are
  /// resolved ONCE per page instance from the current stream row + episode
  /// row. Episode switches push a NEW page (pushReplacement), so a fresh
  /// resolve happens naturally — no per-episode bookkeeping needed.
  void _resolveSegments() {
    Map<String, dynamic>? currentVideo;
    for (final v in widget.item.videos) {
      if (v['id'] == widget.videoId) {
        currentVideo = v;
        break;
      }
    }
    final currentStream =
        (_streamIndex >= 0 && _streamIndex < widget.streams.length)
            ? widget.streams[_streamIndex]
            : null;
    _segments = PlaybackSegmentsResolver.resolve(
      video: currentVideo,
      stream: currentStream,
    );
  }

  /// Workstream C: any subtitle-relevant write that did NOT come from the
  /// player's own sheet (settings page, cloud-sync merge, backup restore)
  /// updates [_subStyle] + the mpv sub-delay immediately. Diffing against
  /// [_lastSubValues] keeps sheet previews authoritative and avoids
  /// redundant notifier writes.
  void _onAppSettingsChanged() {
    final values = SubtitleStyle.valuesFrom(_app.webSettings);
    if (mapEquals(values, _lastSubValues)) return;
    final oldOffset =
        (_lastSubValues['subtitleOffsetMs'] as num?)?.toInt() ?? 0;
    final newOffset = (values['subtitleOffsetMs'] as num?)?.toInt() ?? 0;
    _lastSubValues = Map<String, Object?>.of(values);
    _subStyle.value = SubtitleStyle.fromMap(values);
    if (newOffset != oldOffset) {
      unawaited(_engine?.setSubtitleDelayMs(newOffset));
    }
  }

  void _listenTorrent() {
    final torrent = widget.torrent;
    if (torrent == null) return;
    _torrentSub = torrent.statusStream.listen((status) {
      if (!mounted) return;
      setState(() => _torrentStatus = status);
    });
  }

  bool get _showTorrentHud {
    final status = _torrentStatus;
    if (status == null || _locked || (!_controlsVisible && _panel == null)) {
      return false;
    }
    // The pill rounds to one decimal place, so hide it when it would display
    // 100.0%, as well as for the engine's explicit terminal states.
    return status.progress < 0.9995 &&
        status.state != 'finished' &&
        status.state != 'seeding';
  }

  void _applyPreferredTracks(PlaybackSession engine) {
    final settings = _app.webSettings;
    if (_preferenceSession.canApplyAudio) {
      final preference = settings['defaultAudioLanguage'];
      final automatic = NovaPlaybackPreferences.canonicalLanguage(preference);
      if (automatic == null ||
          automatic == 'source' ||
          automatic == 'original' ||
          automatic == 'auto') {
        _preferenceSession.markAudioPreferenceApplied();
      } else if (engine.audioTracks.isNotEmpty) {
        final index = NovaPlaybackPreferences.preferredAudioTrack(
          engine.audioTracks
              .map((track) => PlaybackTrackLanguage(
                    language: track.language,
                    title: track.title,
                  ))
              .toList(),
          preference,
        );
        if (index != null) {
          _preferenceSession.markAudioPreferenceApplied();
          unawaited(engine.selectAudio(engine.audioTracks[index]));
        }
      }
    }

    if (_preferenceSession.canApplySubtitle) {
      if (NovaPlaybackPreferences.subtitlesDisabled(settings)) {
        _preferenceSession.markSubtitlePreferenceApplied();
        unawaited(engine.selectSubtitle(SubtitleTrack.no()));
      } else if (engine.subtitleTracks.isNotEmpty) {
        final index = NovaPlaybackPreferences.preferredSubtitleTrack(
          engine.subtitleTracks
              .map((track) => PlaybackTrackLanguage(
                    language: track.language,
                    title: track.title,
                  ))
              .toList(),
          explicitLanguage: settings['subtitleTranslationLanguage'],
          rankedLanguages: settings['preferredSubLangs'],
        );
        if (index != null) {
          _preferenceSession.markSubtitlePreferenceApplied();
          unawaited(engine.selectSubtitle(engine.subtitleTracks[index]));
        }
      }
    }
  }

  /// Configurable skip steps (spec: "preset seconds in the settings").
  int get _backStepSec =>
      (context.read<AppState>().webSettings['seekBackStepSec'] as num?)
          ?.toInt() ??
      10;

  int get _forwardStepSec =>
      (context.read<AppState>().webSettings['seekForwardStepSec'] as num?)
          ?.toInt() ??
      10;

  void _createEngine() {
    final wasHolding = _temporarySpeed.active;
    _temporarySpeed.invalidate();
    if (wasHolding) _controlsVisible = _controlsVisibleBeforeHold;
    _engineInitError = null;
    _preferenceSession.resetForEngine();
    if (widget.continuity != null) {
      _preferenceSession.markAudioSelectedManually();
      _preferenceSession.markSubtitleSelectedManually();
    }
    final request = PlaybackRequest(
      item: widget.item,
      url: widget.url,
      streamName: widget.streamName,
      videoId: widget.videoId,
      initialPositionMs: widget.initialPositionMs,
      season: widget.season,
      episode: widget.episode,
      streams: widget.streams,
      streamIndex: widget.streamIndex,
      headers: widget.headers,
      filename: widget.filename,
      torrent: widget.torrent,
      recordProgress: widget.recordProgress,
    );
    final session = PlaybackSession(
      request: request,
      canRecord: () => !_resuming && !_resumeTransitioning,
      startInBackground: WidgetsBinding.instance.lifecycleState != null &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed,
      startupSettings: PlaybackStartupSettings(
        subtitleDelayMs:
            (_app.webSettings['subtitleOffsetMs'] as num?)?.toInt() ?? 0,
        audioDelayMs: (_app.webSettings['audioDelayMs'] as num?)?.toInt() ?? 0,
        subtitlesOff:
            NovaPlaybackPreferences.subtitlesDisabled(_app.webSettings),
      ),
      persist: (snapshot) async {
        try {
          final frame = snapshot.frame;
          if (frame != null && frame.isNotEmpty) {
            await _app.saveResumeSnapshot(snapshot.item.id, frame);
          }
        } finally {
          await _app.recordPlayback(snapshot.item,
              positionMs: snapshot.positionMs,
              durationMs: snapshot.durationMs,
              videoId: snapshot.videoId,
              season: snapshot.season,
              episode: snapshot.episode);
        }
      },
      onExactProgress: _onExactProgress,
    );
    _engine = session;
    session.resumeResolved = !_resuming;
    session.addListener(_onEngineTick);
    unawaited(session.open(
      widget.url,
      startAt:
          !_resuming ? Duration(milliseconds: _resumePositionMs ?? 0) : null,
      httpHeaders: widget.headers,
      playWhenReady: !_resuming,
      continuity: widget.continuity,
    ));
    _bumpControls();
  }

  void _onExactProgress(PlaybackSession session) {
    if (!mounted || !identical(session, _engine)) return;
    _maybeAutoAdvance(session);
    final position = session.position.inMilliseconds;
    final duration = session.duration.inMilliseconds;
    final intro = SegmentWindows.introVisible(
        segments: _segments, positionMs: position, durationMs: duration);
    final outro = SegmentWindows.outroVisible(
        segments: _segments, positionMs: position, durationMs: duration);
    final appear = SegmentWindows.cardAppearAtMs(
        segments: _segments, durationMs: duration);
    final card = appear >= 0 && position >= appear;
    final projection =
        (intro, outro, card, card ? _cardCountdown(duration, position) : '');
    if (projection != _featureProjection) {
      _featureProjection = projection;
      setState(() {});
    }
  }

  bool _persistenceFailureReported = false;

  void _onEngineTick() {
    if (!mounted) return;
    final engine = _engine;
    if (engine == null) return;
    if (engine.persistenceFailed && !_persistenceFailureReported) {
      _persistenceFailureReported = true;
      scheduleMicrotask(() {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(NovaStrings.lookup(english, 'playerProgressSaveFailed')),
        ));
      });
    }
    if (engine.ready) _applyPreferredTracks(engine);
    if (engine.completed && !_stopScrobbled) {
      _stopScrobbled = true;
      _scrobble('stop');
      unawaited(_saveProgress());
    }
    setState(() {});
  }

  /// Workstream B: fires the next-episode SOURCE flow when a data-provided
  /// auto-advance countdown elapses. Without timing data this never arms
  /// (autoAdvanceAtMs returns null) — the card stays manual, exactly as
  /// shipped. Honors the Cancel latch and the autoplay preference.
  void _maybeAutoAdvance(PlaybackSession engine) {
    if (!engine.ready || !engine.resumeResolved || engine.isClosing) return;
    if (_autoAdvanceFired ||
        _upNextDismissed ||
        _stopScrobbled ||
        _episodeTransitionBusy) {
      return;
    }
    if ((_app.webSettings['autoPlayNextEpisode'] ?? true) != true) return;
    final at = SegmentWindows.autoAdvanceAtMs(
      segments: _segments,
      durationMs: engine.duration.inMilliseconds,
    );
    if (at == null || engine.position.inMilliseconds < at) return;
    _autoAdvanceFired = true;
    final next = _episodeAt(_currentEpisodeIndex() + 1);
    if (next != null) unawaited(_startEpisodeSources(next));
  }

  // ── Episodes ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _episodes => widget.item.videos
      .where((v) => ((v['season'] as num?)?.toInt() ?? 0) > 0)
      .toList()
    ..sort((a, b) {
      final bySeason =
          ((a['season'] as num?) ?? 0).compareTo((b['season'] as num?) ?? 0);
      if (bySeason != 0) return bySeason;
      return ((a['episode'] as num?) ?? 0)
          .compareTo((b['episode'] as num?) ?? 0);
    });

  int _currentEpisodeIndex() {
    if (widget.item.type != 'series') return -1;
    final episodes = _episodes;
    for (var i = 0; i < episodes.length; i++) {
      if (episodes[i]['id'] == widget.videoId) return i;
    }
    return episodes.isEmpty ? -1 : 0;
  }

  Map<String, dynamic>? _episodeAt(int index) {
    final episodes = _episodes;
    if (index < 0 || index >= episodes.length) return null;
    return episodes[index];
  }

  // ── Chrome visibility ───────────────────────────────────────────────────

  void _bumpControls() {
    if (_locked || _temporarySpeed.active) return;
    setState(() => _controlsVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 4000), () {
      if (!mounted) return;
      final engine = _engine;
      final playing = engine?.playing ?? false;
      if (playing && !_sheetOpen && _mode == _GestureMode.none) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_temporarySpeed.active) return;
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _bumpControls();
    }
  }

  void _flashHint(String message) {
    _hintTimer?.cancel();
    _lastHint = message;
    setState(() {});
    _hintTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() {});
    });
  }

  String _lastHint = '';

  bool get _hintVisible => _hintTimer?.isActive ?? false;

  // ── Transport ───────────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    final engine = _engine;
    if (engine == null || !engine.ready) return;
    if (engine.playing) {
      await engine.pause();
      _scrobble('pause');
      await _captureResumeSnapshot();
      _hideTimer?.cancel();
      if (mounted) setState(() => _controlsVisible = true);
    } else {
      await engine.play();
      _scrobble('start');
      _bumpControls();
    }
  }

  Future<void> _seekBy(int seconds) async {
    final engine = _engine;
    if (engine == null || !engine.ready) return;
    final result = await engine.seekBy(seconds);
    if (!result.applied) return;
    _flashHint(
      NovaStrings.lookup(
          english, 'message1', {'p0': seconds > 0 ? '+' : '', 'p1': seconds}),
    );
    _bumpControls();
  }

  /// Fullscreen toggle (Task 124): hides/shows the system UI around the
  /// immersive video surface.
  Future<void> _toggleFullscreen() async {
    final next = !_fullscreen;
    setState(() => _fullscreen = next);
    await SystemChrome.setEnabledSystemUIMode(
      next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    _bumpControls();
  }

  /// Shows the mandated double-tap ripple (Task 125): consecutive taps on
  /// the same half accumulate the counter (+10 -> +20 -> +30 ...) and the
  /// burst fades ~800 ms after the last tap.
  void _showRipple({required bool forward, required int step}) {
    _rippleTimer?.cancel();
    setState(() {
      if (_rippleVisible && _rippleForward == forward) {
        _rippleSeconds += step;
      } else {
        _rippleSeconds = step;
        _rippleForward = forward;
        _rippleKey++;
      }
    });
    _rippleTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() {});
    });
  }

  bool get _rippleVisible => _rippleTimer?.isActive ?? false;

  Future<void> _saveProgress() async {
    final session = _engine;
    if (session == null) return;
    session.resumeResolved = !_resuming && !_resumeTransitioning;
    final result = await session.checkpoint(CheckpointCause.pause);
    if (result == CheckpointResult.failed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(NovaStrings.lookup(english, 'playerProgressSaveFailed'))));
    }
  }

  Future<void> _captureResumeSnapshot() async {
    final session = _engine;
    if (session == null) return;
    session.resumeResolved = !_resuming && !_resumeTransitioning;
    await session.checkpoint(CheckpointCause.pause, capture: true);
  }

  bool _backgroundScrobbled = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = _engine;
    if (session == null) return;
    if (state == AppLifecycleState.resumed) {
      _backgroundScrobbled = false;
      session.foreground();
    } else {
      unawaited(_endTemporarySpeed());
      unawaited(_pauseAndSaveResumeFrame());
    }
  }

  Future<void> _pauseAndSaveResumeFrame() async {
    final session = _engine;
    if (session == null) return;
    final scrobble = session.playing && !_backgroundScrobbled;
    _backgroundScrobbled = true;
    await session.background();
    if (scrobble && mounted) _scrobble('pause');
  }

  void _scrobble(String action) {
    if (!NovaPlaybackPreferences.canRecordProgress(
      awaitingResumeChoice: _resuming || _resumeTransitioning,
    )) {
      return;
    }
    final app = context.read<AppState>();
    final engine = _engine;
    final duration = engine?.duration.inMilliseconds ?? 0;
    final progress = duration <= 0
        ? 0.0
        : (engine!.position.inMilliseconds / duration) * 100;
    final type = widget.item.type == 'series' ? 'series' : 'movie';
    final year =
        RegExp(r'^\d{4}').firstMatch(widget.item.releaseInfo ?? '')?.group(0);
    for (final service in const ['trakt', 'simkl']) {
      if (!app.api.isLinked(service) ||
          app.webSettings['${service}Scrobbling'] == false ||
          !widget.recordProgress) {
        continue;
      }
      unawaited(app.api.scrobbleLinkedService(
        service,
        action: action,
        type: type,
        title: widget.item.name,
        year: year,
        imdb: widget.item.id,
        progress: progress,
      ));
    }
  }

  Future<void> _performClose() async {
    if (_closing || _allowRoutePop) return;
    _closing = true;
    _temporarySpeed.invalidate();
    _engine?.cancelResolution();
    _scrobble('stop');
    _stopScrobbled = true;
    try {
      await _engine?.close();
    } catch (_) {
      _closing = false;
      if (mounted) {
        setState(
            () => _engineInitError = NovaStrings.lookup(english, 'message15'));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _allowRoutePop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _requestClose() async {
    if (_panel != null) {
      _closePanel();
      return;
    }
    if (_leaveDialogOpen || _closing || _allowRoutePop) return;
    if (_app.webSettings['playerConfirmLeave'] != true) {
      await _performClose();
      return;
    }

    _leaveDialogOpen = true;
    final engine = _engine;
    final dialogToken = engine?.pauseForPanel();
    if (!mounted) return;
    final leave = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(
              NovaStrings.lookup(english, 'playerLeaveTitle'),
            ),
            content: Text(
              NovaStrings.lookup(english, 'playerLeaveBody'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(NovaStrings.lookup(english, 'cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  NovaStrings.lookup(english, 'playerLeaveAction'),
                ),
              ),
            ],
          ),
        ) ??
        false;
    _leaveDialogOpen = false;
    if (!mounted) return;
    if (leave) {
      await _performClose();
    } else if (dialogToken != null && identical(_engine, engine)) {
      await engine!.restorePanel(dialogToken);
      _bumpControls();
    }
  }

  Future<void> _resumeFromSaved() async {
    final engine = _engine;
    if (engine == null || !engine.ready) return;
    _resumeTransitioning = true;
    if (mounted) {
      setState(() {
        _resuming = false;
      });
    }
    try {
      final result = await engine.seekTo(
        Duration(
          milliseconds: NovaPlaybackPreferences.safeResumePositionMs(
            _resumePositionMs,
            engine.duration.inMilliseconds,
          ),
        ),
      );
      if (!result.applied) {
        if (mounted) setState(() => _resuming = true);
        return;
      }
    } finally {
      _resumeTransitioning = false;
      _engine?.resumeResolved = !_resuming;
    }
    await engine.play();
    _scrobble('start');
    _bumpControls();
  }

  Future<void> _startOverFromPrompt() async {
    _resumeTransitioning = true;
    if (mounted) {
      setState(() {
        _resuming = false;
        _resumePositionMs = 0;
      });
    }
    try {
      final session = _engine;
      if (session != null && session.position > Duration.zero) {
        final result = await session.seekTo(Duration.zero);
        if (!result.applied) {
          if (mounted) setState(() => _resuming = true);
          return;
        }
      }
    } finally {
      _resumeTransitioning = false;
      _engine?.resumeResolved = !_resuming;
    }
    await _engine?.play();
    _scrobble('start');
    _bumpControls();
  }

  // ── Chrome actions ──────────────────────────────────────────────────────

  void _lock() {
    unawaited(_endTemporarySpeed());
    _hideTimer?.cancel();
    setState(() {
      _locked = true;
      _controlsVisible = false;
    });
  }

  void _unlock() {
    setState(() => _locked = false);
    _bumpControls();
  }

  String get _speedLabel {
    final rate = _engine?.rate ?? 1.0;
    return '${rate == rate.roundToDouble() ? rate.toStringAsFixed(1) : rate}X';
  }

  // ── Sheets ──────────────────────────────────────────────────────────────

  Future<void> _openSheet(
    Future<void> Function() show, {
    bool pauseVideo = false,
  }) async {
    await _endTemporarySpeed();
    _sheetOpen = true;
    _hideTimer?.cancel();
    if (mounted) setState(() => _controlsVisible = true);
    final engine = _engine;
    // Workstream A1: the full-screen selection panels pause the video for
    // their lifetime and resume ONLY if it was playing before — closing
    // must never leave the player paused, and opening must never auto-start
    // a video the user had paused. The `identical` guard keeps the resume
    // off an engine that was swapped/disposed while the panel was open.
    final token = pauseVideo ? engine?.pauseForPanel() : null;
    try {
      await show();
    } finally {
      if (token != null && mounted && identical(_engine, engine)) {
        await engine!.restorePanel(token);
      }
      if (mounted) {
        setState(() => _sheetOpen = false);
        _bumpControls();
      }
    }
  }

  /// Task 141 (user mandate): the playback settings open as the SAME
  /// right-half panel as the subtitle picker — a single setState, no route,
  /// no await. The old pop-result sheet flow (speed:/fit:/audio/...) is gone.
  void _openSettingsPanel() => _openPanel(PlayerPanelKind.settings);

  String get _audioLabel {
    final track = _engine?.selectedAudio;
    if (track == null || track.id == 'auto' || track.id.isEmpty) {
      return NovaStrings.lookup(english, 'message2');
    }
    return (track.title?.isNotEmpty == true
            ? track.title!
            : track.language?.isNotEmpty == true
                ? track.language!
                : '${NovaStrings.lookup(english, 'message3')} ${track.id}')
        .split('\n')
        .first;
  }

  String get _subtitleLabel {
    final track = _engine?.selectedSubtitle;
    if (track == null || track.id == 'no') {
      return NovaStrings.lookup(english, 'message4');
    }
    if (track.id == 'auto' || track.id.isEmpty) {
      return NovaStrings.lookup(english, 'message5');
    }
    return (track.title?.isNotEmpty == true
            ? track.title!
            : track.language?.isNotEmpty == true
                ? track.language!
                : '${NovaStrings.lookup(english, 'message3')} ${track.id}')
        .split('\n')
        .first;
  }

  void _openAudioPanel() => _openPanel(PlayerPanelKind.audio);

  void _openSubtitlesPanel() => _openPanel(PlayerPanelKind.subtitles);

  void _openStreamsPanel() => _openPanel(PlayerPanelKind.streams);

  /// Opens a right-half side panel INSTANTLY (a single setState — no route,
  /// no await): the video pauses for the panel's lifetime and resumes ONLY
  /// if it was playing; never resumes an engine that was swapped mid-panel.
  void _openPanel(PlayerPanelKind kind) {
    if (_locked) return;
    if (_temporarySpeed.active || _temporarySpeed.settling) {
      unawaited(_endTemporarySpeed().then((_) {
        if (mounted && !_locked && !_closing) _openPanel(kind);
      }));
      return;
    }
    final engine = _engine;
    if (_panel == kind) {
      _closePanel();
      return;
    }
    // Task 141: panel→panel hand-offs (settings → audio / subtitles) keep
    // the ORIGINAL session's pause contract — no double pause, and the final
    // close still resumes exactly when the first panel interrupted playback.
    final switching = _panel != null;
    final wasPlaying =
        switching ? _panelWasPlaying : (engine?.playing ?? false);
    if (!switching && engine != null) _panelToken = engine.pauseForPanel();
    _hideTimer?.cancel();
    setState(() {
      _panel = kind;
      _panelWasPlaying = wasPlaying;
      _sheetOpen = true;
      _controlsVisible = false;
    });
    // Data loading happens in front of the user INSIDE the panel:
    // addon subtitles always re-fetch; streams seed from the delivered
    // list and only fetch when it is empty.
    if (kind == PlayerPanelKind.subtitles) {
      _panelExternalSubs = const [];
      unawaited(_loadPanelData(refresh: false));
    } else if (kind == PlayerPanelKind.streams) {
      _panelStreams = widget.streams;
      if (widget.streams.isEmpty) {
        unawaited(_loadPanelData(refresh: false));
      }
    }
  }

  void _closePanel() {
    final engine = _engine;
    final token = _panelToken;
    _panelToken = null;
    setState(() {
      _panel = null;
      _panelWasPlaying = false;
      _sheetOpen = false;
    });
    if (token != null && engine != null) unawaited(engine.restorePanel(token));
    _bumpControls();
  }

  /// The right-half panel hosting the currently open picker (Task 139).
  /// Rendered as an in-page overlay at the END of the build Stack — opening
  /// is instant, loading happens INSIDE the panel in front of the user,
  /// and the header refresh button re-fetches without leaving the player.
  Widget _buildPanel(PlaybackSession? engine) {
    final kind = _panel!;
    switch (kind) {
      case PlayerPanelKind.audio:
        return PlayerSidePanel(
          title: NovaStrings.lookup(english, 'message6'),
          english: english,
          onClose: _closePanel,
          // The engine is the audio data source — a refresh re-reads its
          // track list (genuinely useful on slow devices where track
          // enumeration lands after the panel opened).
          onRefresh: () => setState(() {}),
          refreshing: false,
          child: AudioTracksPanelBody(
            english: english,
            tracks: engine?.audioTracks ?? const [],
            selected: engine?.selectedAudio ?? const AudioTrack('', null, null),
            onPick: (track) {
              _preferenceSession.markAudioSelectedManually();
              unawaited(engine?.selectAudio(track));
            },
            delayMs: (_app.webSettings['audioDelayMs'] as num?)?.toInt() ?? 0,
            onDelayChanged: (ms) async {
              await engine?.setAudioDelayMs(ms);
              if (!mounted) return;
              await _app.setSetting('audioDelayMs', ms);
            },
          ),
        );
      case PlayerPanelKind.subtitles:
        return PlayerSidePanel(
          title: NovaStrings.lookup(english, 'message7'),
          english: english,
          onClose: _closePanel,
          // Refresh re-fetches the add-on subtitles in place.
          onRefresh: () => unawaited(_loadPanelData(refresh: true)),
          refreshing: _panelRefreshing,
          headerAction: PanelSettingsButton(onTap: _openSubtitleStyleSheet),
          child: SubtitleTracksPanelBody(
            english: english,
            embedded: engine?.subtitleTracks ?? const [],
            selected: engine?.selectedSubtitle ?? SubtitleTrack.no(),
            onPick: (track) {
              _preferenceSession.markSubtitleSelectedManually();
              if (track.uri && track.id.isNotEmpty) {
                unawaited(engine?.setSubtitleUri(track.id, title: track.title));
              } else {
                unawaited(engine?.selectSubtitle(track));
              }
            },
            external: _panelExternalSubs,
            loadingExternal: _panelLoading,
          ),
        );
      case PlayerPanelKind.streams:
        final currentStream =
            (_streamIndex >= 0 && _streamIndex < widget.streams.length)
                ? widget.streams[_streamIndex]
                : null;
        return PlayerSidePanel(
          title: NovaStrings.lookup(english, 'message8'),
          english: english,
          onClose: _closePanel,
          // Refresh re-runs the full add-on query + ranking in place.
          onRefresh: () => unawaited(_loadPanelData(refresh: true)),
          refreshing: _panelRefreshing,
          child: StreamsPanelBody(
            english: english,
            streams: _panelStreams,
            currentStream: currentStream,
            onPick: (stream) => unawaited(_switchToStream(stream)),
          ),
        );
      case PlayerPanelKind.settings:
        // Task 141 (user mandate): the settings fill the SAME right-half
        // panel as the subtitle picker. No refresh button — everything here
        // is engine/device state, applied live in front of the user.
        return PlayerSidePanel(
          title: NovaStrings.lookup(english, 'message9'),
          english: english,
          onClose: _closePanel,
          child: PlayerSettingsPanelBody(
            english: english,
            speed: _engine?.rate ?? 1.0,
            speeds: NovaPlaybackPreferences.playbackSpeeds(
              _app.webSettings['customPlaybackSpeeds'],
              _engine?.rate ?? 1.0,
            ),
            fit: _fit,
            audioLabel: _audioLabel,
            subtitleLabel: _subtitleLabel,
            hasEpisodes: widget.item.type == 'series' && _episodes.isNotEmpty,
            // Speed + fit apply LIVE — the panel stays open so the user can
            // audition values (same contract as picking audio tracks).
            onSpeed: (value) {
              unawaited(_engine?.setRate(value));
              if (mounted) setState(() {});
            },
            onFit: (value) => setState(() => _fit = value),
            // Audio / subtitles hand the panel over IN PLACE (no route, no
            // flash) — the original pause/resume session is preserved by
            // _openPanel's switching branch.
            onOpenAudio: () => _openPanel(PlayerPanelKind.audio),
            onOpenSubtitles: () => _openPanel(PlayerPanelKind.subtitles),
            // Episodes stays a dense bottom sheet (SheetScaffold route); the
            // panel closes with its normal resume contract, matching the old
            // flow where playback kept running under the sheet.
            onOpenEpisodes: () {
              _closePanel();
              unawaited(_openEpisodesSheet());
            },
          ),
        );
    }
  }

  /// Panel data loader — run on panel open AND on the header refresh
  /// button. Failures surface as the in-panel empty note, never a crash.
  Future<void> _loadPanelData({required bool refresh}) async {
    final kind = _panel;
    if (kind == null) return;
    if (kind == PlayerPanelKind.streams &&
        _panelStreams.isNotEmpty &&
        !refresh) {
      return; // instant content from the delivered list
    }
    setState(() {
      if (refresh) {
        _panelRefreshing = true;
      } else {
        _panelLoading = true;
      }
    });
    try {
      if (kind == PlayerPanelKind.streams) {
        final streams = await loadRankedSources(
          app: _app,
          item: widget.item,
          videoId: widget.videoId,
        );
        if (!mounted || _panel != PlayerPanelKind.streams) return;
        _panelStreams = streams;
      } else if (kind == PlayerPanelKind.subtitles) {
        final subs = await _fetchExternalSubs();
        if (!mounted || _panel != PlayerPanelKind.subtitles) return;
        _panelExternalSubs = subs;
      }
    } catch (_) {
      // The panel shows its empty/refresh note — the error itself is not
      // actionable beyond the refresh button.
    } finally {
      if (mounted) {
        setState(() {
          _panelLoading = false;
          _panelRefreshing = false;
        });
      }
    }
  }

  /// Addon subtitles for the panel body — refetched on every panel open and
  /// on the header refresh button.
  Future<List<Map<String, dynamic>>> _fetchExternalSubs() async {
    try {
      final app = _app;
      final subs = await app.catalogs
          .subtitles(widget.item.type, widget.videoId, app.addons);
      return subs.where((sub) => sub['url'] is String).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Live-editing subtitle style/timing sheet (user request): every change is
  /// pushed to the engine immediately and persisted through AppState.
  Future<void> _openSubtitleStyleSheet() => _openSheet(() async {
        await showPlayerSheet<void>(
          context,
          builder: (_) => SubtitleStyleSheet(
            english: english,
            onApply: _applySubtitleValues,
          ),
        );
      });

  void _applySubtitleValues(Map<String, Object?> values) {
    // Workstream C: remember exactly what the sheet applied so the AppState
    // listener's diff treats this as the new baseline (no double-apply, no
    // clobbering the preview).
    _lastSubValues = Map<String, Object?>.of(values);
    // Visual settings: straight into the overlay's notifier — the running
    // video restyles instantly (Task 130 requirement: no restart, no
    // re-open, no leaving the player).
    _subStyle.value = SubtitleStyle.fromMap(values);
    // Timing offset: mpv `sub-delay` — shifts WHICH text mpv emits.
    final engineRef = _engine;
    if (engineRef == null) return;
    unawaited(engineRef.setSubtitleDelayMs(
        (values['subtitleOffsetMs'] as num?)?.toInt() ?? 0));
  }

  Future<void> _openEpisodesSheet() => _openSheet(() async {
        if (_episodes.isEmpty) return;
        await showPlayerSheet<void>(
          context,
          builder: (_) => EpisodesSheet(
            english: english,
            episodes: _episodes,
            currentVideoId: widget.videoId,
            onPick: (episode) => unawaited(_switchEpisode(episode)),
          ),
        );
      });

  /// In-player source switching (Task 139): resolve the picked stream and
  /// replace this player around the SAME episode. The transition latch is
  /// shared with the episode flows against double taps.
  PlaybackContinuity? _pendingContinuity;

  Future<void> _switchToStream(Map<String, dynamic> stream) async {
    if (_episodeTransitionBusy) return;
    _episodeTransitionBusy = true;
    await _endTemporarySpeed();
    _pendingContinuity = _engine == null ? null : PlaybackContinuity(_engine!);
    try {
      if (!mounted) return;
      await _replaceWithResolved(
        videoId: widget.videoId,
        season: widget.season,
        episode: widget.episode,
        stream: stream,
        streams: [stream],
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(torrentFriendlyMessage(error, english: english)),
          ),
        );
      }
    } finally {
      _episodeTransitionBusy = false;
    }
  }

  Future<void> _switchEpisode(Map<String, dynamic> episode) async {
    final episodeId = (episode['id'] ?? widget.item.id).toString();
    if (episodeId == widget.videoId) return;
    try {
      final playable = await _fetchPlayableStreams(episodeId);
      if (!mounted) return;
      if (playable.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                NovaStrings.lookup(english, 'message10'),
              ),
            ),
          );
        }
        return;
      }
      final stream = _bestStream(playable);
      await _replaceWithResolved(
        videoId: episodeId,
        season: (episode['season'] as num?)?.toInt(),
        episode: (episode['episode'] as num?)?.toInt(),
        stream: stream,
        streams: playable,
      );
    } catch (error) {
      if (mounted) {
        // Task 128: actionable message instead of the raw exception string.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(torrentFriendlyMessage(error, english: english)),
          ),
        );
      }
    }
  }

  /// Resolves [stream] (direct / debrid / on-device torrent) and replaces
  /// this player instance with one playing it — shared by the episode
  /// switch, the next-episode flow and the in-player source switch. The
  /// fresh page resolves its own skip/next-episode data per instance.
  Future<void> _replaceWithResolved({
    required String videoId,
    required int? season,
    required int? episode,
    required Map<String, dynamic> stream,
    required List<Map<String, dynamic>> streams,
    bool allowRetired = false,
  }) async {
    await _endTemporarySpeed();
    final owner = _engine;
    if (owner == null || (owner.isClosing && !allowRetired)) return;
    final resolutionIdentity = owner.beginResolution();
    final pausing = owner.pause();
    final handoffIntent = owner.handoffIntent(
        resolutionIdentity, _pendingContinuity?.playing ?? false);
    await pausing;
    await _saveProgress();
    if (!mounted || !owner.acceptsResolution(resolutionIdentity)) return;
    final resolved = await owner.resolve(resolutionIdentity, () async {
      final candidate =
          await _resolveForPlayback(_app, stream, owner, resolutionIdentity);
      if (!mounted || !owner.acceptsResolution(resolutionIdentity)) {
        if (!identical(candidate?.torrent, widget.torrent)) {
          await candidate?.torrent?.stop();
        }
        return null;
      }
      return candidate;
    });
    if (!mounted ||
        !identical(_engine, owner) ||
        !owner.acceptsResolution(resolutionIdentity)) {
      if (!identical(resolved?.torrent, widget.torrent)) {
        await resolved?.torrent?.stop();
      }
      return;
    }
    if (resolved == null) {
      if (owner.isClosing) {
        setState(
            () => _engineInitError = NovaStrings.lookup(english, 'message15'));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            NovaStrings.lookup(english, 'message11'),
          ),
        ),
      );
      return;
    }
    try {
      await owner.closeForResolution(resolutionIdentity);
    } catch (_) {
      if (!identical(resolved.torrent, widget.torrent)) {
        await resolved.torrent?.stop();
      }
      rethrow;
    }
    if (!mounted || !owner.acceptsResolution(resolutionIdentity)) {
      if (!identical(resolved.torrent, widget.torrent)) {
        await resolved.torrent?.stop();
      }
      return;
    }
    final pickedIndex = streams.indexOf(stream);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CoreVideoPlayerPage(
          item: widget.item,
          url: resolved.url,
          streamName:
              (stream['title'] ?? stream['addonName'] ?? 'NOVA').toString(),
          videoId: videoId,
          initialPositionMs: videoId == widget.videoId
              ? _pendingContinuity?.position.inMilliseconds
              : null,
          continuity: videoId == widget.videoId
              ? _pendingContinuity
                  ?.restrictPlay(owner.canRestoreHandoff(handoffIntent))
              : null,
          recordProgress: widget.recordProgress,
          season: season,
          episode: episode,
          headers: resolved.headers.isEmpty ? null : resolved.headers,
          torrent: resolved.torrent,
          streams: streams,
          streamIndex: pickedIndex < 0 ? null : pickedIndex,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Playable-stream fetch shared by the episode-switch paths (the same
  /// debrid/P2P gate the detail page applies before showing sources).
  Future<List<Map<String, dynamic>>> _fetchPlayableStreams(
    String episodeId,
  ) async {
    final app = _app;
    final streams =
        await app.catalogs.streams(widget.item.type, episodeId, app.addons);
    return streams.where((stream) {
      if (stream['url'] != null) return true;
      if (stream['infoHash'] != null) {
        if (app.api.debridService != null) return true;
        return app.webSettings['p2pEnabled'] == true;
      }
      return false;
    }).toList();
  }

  /// Next-episode flow routed through the EXISTING source-selection page
  /// (spec B2.3: never bypass source selection). Task 139: the page loads
  /// its own streams (spinner + refresh INSIDE the page) instead of a
  /// blocking pre-fetch here — an empty result shows the page's refreshable
  /// empty state, never a dead end. Used by the Up-Next card's Next button
  /// AND by the auto-advance when a data-provided countdown exists.
  Future<void> _startEpisodeSources(Map<String, dynamic> episode) async {
    if (_episodeTransitionBusy) return;
    _episodeTransitionBusy = true;
    try {
      final episodeId = (episode['id'] ?? widget.item.id).toString();
      if (episodeId == widget.videoId) return;
      await _engine?.pause();
      await _saveProgress();
      if (!mounted) return;
      final picked = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => SourcesPage(
            item: widget.item,
            video: episode,
            english: english,
            loader: () => loadRankedSources(
              app: _app,
              item: widget.item,
              videoId: episodeId,
            ),
          ),
        ),
      );
      if (!mounted || picked == null) return;
      await _replaceWithResolved(
        videoId: episodeId,
        season: (episode['season'] as num?)?.toInt(),
        episode: (episode['episode'] as num?)?.toInt(),
        stream: picked,
        streams: [picked],
      );
    } catch (error) {
      if (mounted) {
        // Task 128: actionable message instead of the raw exception string.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(torrentFriendlyMessage(error, english: english)),
          ),
        );
      }
    } finally {
      _episodeTransitionBusy = false;
    }
  }

  // ── Skip intro / outro (workstream B) ────────────────────────────────

  Future<void> _skipSegment({required bool intro}) async {
    final engine = _engine;
    if (engine == null || !engine.ready) return;
    if (intro) {
      final end = _segments.introEndMs;
      if (end == null) return;
      final result = await engine.seekTo(Duration(milliseconds: end));
      if (!result.applied) return;
      _flashHint(NovaStrings.lookup(english, 'message12'));
    } else {
      final end = _segments.outroEndMs;
      if (end == null) return;
      final duration = engine.duration.inMilliseconds;
      final next = _episodeAt(_currentEpisodeIndex() + 1);
      if (duration > 0 && end >= duration - 1500 && next != null) {
        // The outro runs to the end of the video — skipping it moves the
        // user to the next stage: the next-episode source flow.
        await _startEpisodeSources(next);
        return;
      }
      final result = await engine.seekTo(Duration(milliseconds: end));
      if (!result.applied) return;
      _flashHint(NovaStrings.lookup(english, 'message13'));
    }
    _bumpControls();
  }

  Map<String, dynamic> _bestStream(List<Map<String, dynamic>> list) {
    // Keep automatic episode transitions consistent with the source page:
    // in particular, honor the user's H.264 preference instead of selecting
    // a higher-resolution HEVC/Main10 torrent that the phone may software-decode.
    return rankStreams(list, _app.webSettings).first;
  }

  Future<_PlaybackResolution?> _resolveForPlayback(
    AppState app,
    Map<String, dynamic> stream,
    PlaybackSession owner,
    Object resolutionIdentity,
  ) async {
    // Task 127: normalize every header shape (pipe syntax, flat/nested
    // proxyHeaders, legacy headers) before handing the URL to the engine.
    final direct = parsePlaybackSource(stream);
    // Task 128: addons increasingly return magnet: URIs in the url field.
    // They must resolve through debrid/engine — never reach mpv raw.
    final magnetUrl = (direct?.url ?? '').toLowerCase().startsWith('magnet:')
        ? direct!.url
        : null;
    if (direct != null && magnetUrl == null) {
      return _PlaybackResolution(
        url: direct.url,
        headers: direct.headers,
        torrent: null,
      );
    }
    // InfoHash-only stream (or magnet: URI): source headers still apply to
    // debrid/engine URLs.
    final headers = direct?.headers ?? const <String, String>{};
    // Task 142: derive every torrent argument through the SHARED helper —
    // this path used to drop Torrentio's `sources` trackers, `fileIdx` and
    // `behaviorHints.filename` (the media-detail path kept them), so
    // in-player torrents ran on the static default tracker list alone and
    // picked the wrong file inside multi-episode packs.
    final hints = TorrentStreamHints.fromStream(
      stream,
      magnetUri: magnetUrl,
      fallbackName: widget.filename,
    );
    if (hints.infoHash.isEmpty) return null;
    // Premium debrid first: instant direct link, zero buffering.
    if (app.api.debridService != null) {
      final debridUrl = await app.api.resolveDebridTorrent(
        infoHash: hints.infoHash,
        filename: hints.filename,
        filesize: hints.filesize,
      );
      if (debridUrl != null) {
        return _PlaybackResolution(
            url: debridUrl, headers: headers, torrent: null);
      }
    }
    // On-device torrent engine: sequential streaming via localhost server.
    // The addon's own magnet (when present) carries its trackers through,
    // merged with the stream `sources` and the verified defaults (Task 142).
    if (!owner.acceptsResolution(resolutionIdentity)) return null;
    if (widget.torrent != null) {
      await owner.closeForResolution(resolutionIdentity);
      if (!mounted || !owner.acceptsResolution(resolutionIdentity)) return null;
    }
    try {
      final torrent = await TorrentService.instance.prepare(
        infoHash: hints.infoHash,
        magnet: magnetUrl,
        filename: hints.filename,
        filesize: hints.filesize,
        displayName: widget.item.name,
        trackers: hints.trackers,
        fileIndex: hints.fileIndex,
      );
      return _PlaybackResolution(
          url: torrent.url, headers: headers, torrent: torrent);
    } on TorrentException {
      return null;
    }
  }

  // ── Gestures ────────────────────────────────────────────────────────────

  bool get _videoGesturesEnabled =>
      !_locked &&
      !_sheetOpen &&
      _panel == null &&
      !_leaveDialogOpen &&
      !_closing &&
      !_temporarySpeed.active;

  void _startTemporarySpeed(LongPressStartDetails details) {
    final engine = _engine;
    if (!_videoGesturesEnabled ||
        engine == null ||
        !engine.ready ||
        !engine.playing) {
      return;
    }
    final identity = engine.interactionIdentity;
    final started = _temporarySpeed.begin(
      previousRate: engine.rate,
      setRate: (rate) async {
        await engine.setRate(rate);
      },
      ownsSource: () =>
          mounted &&
          !_closing &&
          identical(_engine, engine) &&
          engine.owns(identity),
    );
    if (!started) return;
    _controlsVisibleBeforeHold = _controlsVisible;
    _hideTimer?.cancel();
    _hudLingerTimer?.cancel();
    setState(() {
      _mode = _GestureMode.none;
      _controlsVisible = false;
    });
  }

  Future<void> _endTemporarySpeed() async {
    if (!_temporarySpeed.active) {
      await _temporarySpeed.end();
      return;
    }
    final wasVisible = _controlsVisibleBeforeHold;
    if (mounted) setState(() => _controlsVisible = wasVisible);
    await _temporarySpeed.end();
    if (mounted && wasVisible && !_locked && !_sheetOpen) _bumpControls();
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (!_videoGesturesEnabled) return;
    final width = MediaQuery.sizeOf(context).width;
    final backStep = _backStepSec;
    final forwardStep = _forwardStepSec;
    final logicalX = logicalSeekPosition(details.localPosition.dx, width,
        rtl: Directionality.of(context) == TextDirection.rtl);
    if (logicalX < width * .34) {
      _showRipple(forward: false, step: backStep);
      unawaited(_seekBy(-backStep));
    } else if (logicalX > width * .66) {
      _showRipple(forward: true, step: forwardStep);
      unawaited(_seekBy(forwardStep));
    } else {
      unawaited(_togglePlay());
    }
  }

  PlaybackSession? _gestureSession;
  Object? _gestureIdentity;

  void _onScaleStart(ScaleStartDetails details) {
    if (!_videoGesturesEnabled) return;
    _hideTimer?.cancel();
    _hudLingerTimer?.cancel();
    final engine = _engine;
    _gestureSession = engine;
    _gestureIdentity = engine?.interactionIdentity;
    _gestureModeStart(details.pointerCount);
    if (details.pointerCount >= 2) {
      _mode = _GestureMode.zoom;
      _zoomStart = _zoom;
      return;
    }
    if (engine == null || !engine.ready) return;
    _dragStartDx = logicalSeekPosition(
        details.localFocalPoint.dx, MediaQuery.sizeOf(context).width,
        rtl: Directionality.of(context) == TextDirection.rtl);
    _dragAccumDx = 0;
    _dragAccumDy = 0;
    _positionAtDragStartMs = engine.position.inMilliseconds;
    _brightnessStart = null;
    _volumeStart = null;
    _mode = _GestureMode.none;
  }

  void _gestureModeStart(int pointerCount) {
    // reset per-gesture HUD values
    _hudValue = 0;
    _hudDeltaSeconds = 0;
    _hudTargetMs = 0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_videoGesturesEnabled) return;
    if (!identical(_engine, _gestureSession) ||
        !(_gestureSession?.owns(_gestureIdentity) ?? false)) {
      return;
    }
    if (_locked || _mode == _GestureMode.none && details.pointerCount == 0) {
      return;
    }
    if (_mode == _GestureMode.zoom) {
      setState(() {
        _zoom = (_zoomStart * details.scale).clamp(1.0, 4.0);
        _hudValue = _zoom;
      });
      return;
    }
    final engine = _engine;
    if (engine == null || !engine.ready) return;
    final size = MediaQuery.sizeOf(context);

    // Axis lock on first significant movement (the dead zone — taps and
    // micro-jitters below [kGestureAxisLockPx] never claim a gesture).
    if (_mode == _GestureMode.none) {
      final dx = details.focalPointDelta.dx;
      final dy = details.focalPointDelta.dy;
      if (dx.abs() < kGestureAxisLockPx && dy.abs() < kGestureAxisLockPx) {
        return;
      }
      if (dx.abs() >= dy.abs()) {
        _mode = _GestureMode.seek;
      } else if (_dragStartDx < size.width * .35) {
        _mode = _GestureMode.brightness;
      } else if (_dragStartDx > size.width * .65) {
        _mode = _GestureMode.volume;
      } else {
        _mode = _GestureMode.seek; // center: default to scrub
      }
    }

    switch (_mode) {
      case _GestureMode.seek:
        _dragAccumDx += details.focalPointDelta.dx;
        final durationMs = engine.duration.inMilliseconds;
        // Full screen width covers half the runtime — comfortable scrub rate.
        final deltaMs = directionalSeekDeltaMs(
            dx: _dragAccumDx,
            width: size.width,
            durationMs: durationMs,
            rtl: Directionality.of(context) == TextDirection.rtl);
        _hudDeltaSeconds = (deltaMs / 1000).round();
        _hudTargetMs =
            clampSeekTargetMs(_positionAtDragStartMs + deltaMs, durationMs);
        _hudRevision.value++;
      case _GestureMode.brightness:
        // Accumulate BEFORE applying: the value tracks the total drag from
        // the captured start, not just this tick's delta (A2 fix).
        _dragAccumDy += details.focalPointDelta.dy;
        unawaited(_updateBrightness(_dragAccumDy, size.height));
      case _GestureMode.volume:
        _dragAccumDy += details.focalPointDelta.dy;
        unawaited(_updateVolume(_dragAccumDy, size.height));
      case _GestureMode.zoom:
      case _GestureMode.none:
        break;
    }
  }

  Future<void> _updateBrightness(double totalDy, double height) async {
    try {
      _brightnessStart ??= await ScreenBrightness().application;
      final next = gestureScaledValue(
        start: _brightnessStart!,
        totalDy: totalDy,
        height: height,
      );
      await ScreenBrightness().setApplicationScreenBrightness(next);
      if (mounted) {
        _hudValue = next;
        _hudRevision.value++;
      }
    } catch (_) {
      // Platform refused (rare); HUD stays silent rather than lying.
      _mode = _GestureMode.none;
      if (mounted) _hudRevision.value++;
    }
  }

  Future<void> _updateVolume(double totalDy, double height) async {
    try {
      // Captured ONCE per gesture (see [_volumeStart]): re-reading the
      // system value every tick raced the platform round-trip.
      _volumeStart ??= await VolumeController.instance.getVolume();
      final next = gestureScaledValue(
        start: _volumeStart!,
        totalDy: totalDy,
        height: height,
      );
      VolumeController.instance.showSystemUI = false;
      await VolumeController.instance.setVolume(next);
      if (mounted) {
        _hudValue = next;
        _hudRevision.value++;
      }
    } catch (_) {
      _mode = _GestureMode.none;
      if (mounted) _hudRevision.value++;
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!_videoGesturesEnabled) {
      _mode = _GestureMode.none;
      return;
    }
    if (!identical(_engine, _gestureSession) ||
        !(_gestureSession?.owns(_gestureIdentity) ?? false)) {
      if (mounted) setState(() => _mode = _GestureMode.none);
      return;
    }
    if (_mode == _GestureMode.seek && _hudTargetMs > 0) {
      unawaited(_engine?.seekTo(Duration(milliseconds: _hudTargetMs)));
      _mode = _GestureMode.none;
      _hudValue = 0;
      _hudDeltaSeconds = 0;
      _hudTargetMs = 0;
      if (mounted) setState(() {});
      _bumpControls();
      return;
    }
    // Spec §6: the side indicator (volume / brightness) lingers ~1s after
    // the drag ends instead of vanishing instantly.
    if (_mode == _GestureMode.volume || _mode == _GestureMode.brightness) {
      _hudLingerTimer?.cancel();
      _hudLingerTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _mode = _GestureMode.none;
        _hudRevision.value++;
      });
      _bumpControls();
      return;
    }
    _mode = _GestureMode.none;
    _hudValue = 0;
    _hudDeltaSeconds = 0;
    _hudTargetMs = 0;
    if (mounted) setState(() {});
    _bumpControls();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  bool get _english => context.read<AppState>().english;
  bool get english => _english;

  @override
  void dispose() {
    _temporarySpeed.invalidate();
    _hudRevision.dispose();
    _engine?.cancelResolution();
    WidgetsBinding.instance.removeObserver(this);
    _app.removeListener(_onAppSettingsChanged);
    _hideTimer?.cancel();
    _hintTimer?.cancel();
    _rippleTimer?.cancel();
    _hudLingerTimer?.cancel();
    _torrentSub?.cancel();
    _subStyle.dispose();
    final engine = _engine;
    engine?.removeListener(_onEngineTick);
    engine?.dispose();
    unawaited(_restoreBrightness());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  Future<void> _retrySession() async {
    final session = _engine;
    if (session == null) return;
    if (session.isClosing) {
      if (widget.torrent == null) return;
      final stream = _streamIndex >= 0 && _streamIndex < widget.streams.length
          ? widget.streams[_streamIndex]
          : <String, dynamic>{
              'infoHash': widget.torrent!.infoHash,
              'title': widget.streamName
            };
      try {
        await _replaceWithResolved(
            videoId: widget.videoId,
            season: widget.season,
            episode: widget.episode,
            stream: stream,
            streams: [stream],
            allowRetired: true);
      } catch (_) {
        if (mounted) {
          setState(() =>
              _engineInitError = NovaStrings.lookup(english, 'message15'));
        }
      }
      return;
    }
    await session.retry();
    if (mounted) {
      setState(() {
        _controlsVisible = true;
        _zoom = 1;
      });
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {
      // Nothing to restore.
    }
  }

  @override
  Widget build(BuildContext context) {
    PlayerDiagnostics.instance.record('playerPageBuild');
    final engine = _engine;
    final ready = engine != null && engine.ready;
    final nativeEngine = engine?.nativeEngine;
    // Task 128: a stuck stream (dead source / wedged texture) is a first-class
    // failure — the error panel must also WIN over the (white) video branch.
    final failed = (engine?.failed ?? false) || _engineInitError != null;
    final duration = engine?.duration.inMilliseconds ?? 0;
    final position = engine?.position.inMilliseconds ?? 0;
    // Workstream B: skip pills exist ONLY inside data-provided windows; the
    // next-episode card trigger is data-first with the shipped nearEnd
    // fallback (≤30 s left or ≥95% elapsed) inherited from the old code.
    final introVisible = ready &&
        !_locked &&
        SegmentWindows.introVisible(
          segments: _segments,
          positionMs: position,
          durationMs: duration,
        );
    final outroVisible = ready &&
        !_locked &&
        SegmentWindows.outroVisible(
          segments: _segments,
          positionMs: position,
          durationMs: duration,
        );
    final cardAppearAt = SegmentWindows.cardAppearAtMs(
      segments: _segments,
      durationMs: duration,
    );
    final nextEpisode = widget.item.type == 'series'
        ? _episodeAt(_currentEpisodeIndex() + 1)
        : null;
    final prevEpisode = widget.item.type == 'series'
        ? _episodeAt(_currentEpisodeIndex() - 1)
        : null;
    final width = MediaQuery.sizeOf(context).width;
    // Spec §0-ب: phone (~844×390) vs tablet (~1180×820) sizing.
    final wide = width >= 900;
    final scale = wide ? 1.28 : 1.0;
    final showStreamInfo = _app.webSettings['showQualityInfo'] == true &&
        widget.streamName.trim().isNotEmpty;
    final scaledBodyText = MediaQuery.textScalerOf(context).scale(16);
    final hasTorrentInfo = widget.torrent != null && _torrentStatus != null;
    final hasHeaderMetadata = showStreamInfo || hasTorrentInfo;
    final metadataInset =
        120.0 + (scaledBodyText - 16).clamp(0.0, 32.0).toDouble() * 3;
    final railTopInset = (hasHeaderMetadata ? metadataInset : 108.0) * scale;

    Widget buildBottomCluster(
      PlaybackSession engine, {
      PlaybackProgress? progress,
      Object? identity,
    }) {
      bool current() =>
          mounted && identical(_engine, engine) && engine.owns(identity);
      return PlayerBottomCluster(
        durationMs: progress?.duration.inMilliseconds ?? 0,
        positionMs: progress?.position.inMilliseconds ?? 0,
        bufferedMs: progress?.bufferedEnd.inMilliseconds ?? 0,
        readExactPositionMs: () =>
            current() && engine.canSeek ? engine.position.inMilliseconds : 0,
        readExactDurationMs: () =>
            current() && engine.canSeek ? engine.duration.inMilliseconds : 0,
        interactionIdentity: identity,
        volume: engine.volume,
        muted: engine.muted,
        fullscreen: _fullscreen,
        showRemaining: _showRemaining,
        canPrev: prevEpisode != null,
        canNext: nextEpisode != null,
        scale: scale,
        wide: wide,
        english: english,
        onPrev: prevEpisode == null
            ? null
            : () => unawaited(_switchEpisode(prevEpisode)),
        // Task 139: NEXT always routes through the sources
        // page (spec B2.3 — never bypass source selection),
        // so the next-episode flow is reachable at ANY
        // time, not only inside the card's last-30 s
        // window. Prev keeps the fast already-watched path.
        onNext: nextEpisode == null
            ? null
            : () => unawaited(_startEpisodeSources(nextEpisode)),
        onVolumeChanged: (value) async {
          await engine.setVolume(value);
        },
        onVolumeDragEnd: () => _bumpControls(),
        onMuteToggle: () async {
          await engine.toggleMute();
          _bumpControls();
        },
        onToggleFullscreen: () => unawaited(_toggleFullscreen()),
        // Task 139: the pickers open the right-half panel
        // INSTANTLY — always available (the panel loads
        // and refreshes its own data).
        onOpenStreams: _openStreamsPanel,
        onOpenSubtitles: _openSubtitlesPanel,
        onOpenAudio: _openAudioPanel,
        onToggleRemaining: () =>
            setState(() => _showRemaining = !_showRemaining),
        onScrubStart: () {
          if (!current()) return;
          _hideTimer?.cancel();
          setState(() => _controlsVisible = true);
        },
        onScrubUpdate: (seconds) {},
        onScrubEnd: (seconds) async {
          if (!current()) return;
          await engine.seekTo(
            Duration(milliseconds: (seconds * 1000).round()),
          );
          if (mounted) _bumpControls();
        },
      );
    }

    return PopScope(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestClose());
      },
      child: Scaffold(
        backgroundColor: NovaColors.ink,
        // The chrome follows the reference layout (LTR media convention);
        // Arabic strings still render correctly via bidi.
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_sheetOpen ||
                _panel != null ||
                _leaveDialogOpen ||
                _closing ||
                _temporarySpeed.active) {
              return;
            }
            if (_locked) {
              _flashHint(NovaStrings.lookup(english, 'message14'));
            } else {
              _toggleControls();
            }
          },
          onDoubleTapDown: _handleDoubleTap,
          onLongPressStart: _startTemporarySpeed,
          onLongPressEnd: (_) => unawaited(_endTemporarySpeed()),
          onLongPressCancel: () => unawaited(_endTemporarySpeed()),
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Match the legacy player lifecycle: attach the native video
              // output only after the session has completed open/seek/startup
              // preparation. Mounting it as soon as the backend exists can
              // race media_kit's Android SurfaceProducer initialization.
              if (ready && nativeEngine != null)
                ClipRect(
                    child: Transform.scale(
                  scale: _zoom,
                  child: PlaybackSessionSurface(
                    identity: nativeEngine,
                    geometry: _fit,
                    buildSurface: () => PlayerVideoSurface(
                      engine: nativeEngine,
                      fit: _fit,
                      overlay:
                          SubtitleOverlay(engine: engine, style: _subStyle),
                    ),
                  ),
                )),
              if (failed)
                _ErrorPanel(
                  message: NovaStrings.lookup(english, 'message15'),
                  english: english,
                  onRetry: () => unawaited(_retrySession()),
                )
              else if (!ready)
                const Center(
                    child: CircularProgressIndicator(
                        color: HorseTheme.gold, strokeWidth: 2)),

              // Before the ready chrome exists, keep torrent connection
              // feedback in its standalone position. Once ready, the same
              // HUD joins PlayerTopBar's flow so it cannot cover the title.
              if (hasTorrentInfo && (!ready || failed))
                PositionedDirectional(
                  top: MediaQuery.paddingOf(context).top + 8,
                  start: 12,
                  child: AnimatedOpacity(
                    opacity: _showTorrentHud ? 1 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    child: IgnorePointer(
                      ignoring: !_showTorrentHud,
                      child: _TorrentHud(
                        status: _torrentStatus!,
                        english: english,
                      ),
                    ),
                  ),
                ),

              // Buffering spark.
              if (engine != null && engine.ready && engine.buffering)
                Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: NovaColors.white.withValues(alpha: .70),
                      strokeWidth: 2,
                    ),
                  ),
                ),

              if (ready && !failed) ...[
                // Chrome — fades together.
                AnimatedOpacity(
                  opacity: _controlsVisible && !_locked ? 1 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 280),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible || _locked,
                    child: Stack(
                      children: [
                        PlayerTopBar(
                          title: widget.item.name,
                          episodeTag: widget.item.type == 'series'
                              ? seasonEpisodeTag(widget.season, widget.episode)
                              : '',
                          streamInfo:
                              showStreamInfo ? widget.streamName.trim() : null,
                          streamInfoSemanticLabel: showStreamInfo
                              ? '${NovaStrings.lookup(english, 'message189')}: '
                                  '${widget.streamName.trim()}'
                              : null,
                          statusInfo: hasTorrentInfo
                              ? AnimatedOpacity(
                                  opacity: _showTorrentHud ? 1 : 0,
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 280),
                                  child: IgnorePointer(
                                    ignoring: !_showTorrentHud,
                                    child: _TorrentHud(
                                      status: _torrentStatus!,
                                      english: english,
                                    ),
                                  ),
                                )
                              : null,
                          onClose: () => unawaited(_requestClose()),
                          wide: wide,
                        ),
                        PlayerSideRail(
                          side: AxisSide.left,
                          topInset: railTopInset,
                          children: [
                            // Task 139 (user mandate): the vertical rail is
                            // LOCK + SPEED only — the video-fit and episodes
                            // entries moved into the settings sheet.
                            PlayerRailButton(
                              icon: LucideIcons.lockKeyhole,
                              semanticLabel: NovaStrings.lookup(
                                english,
                                'playerLockControls',
                              ),
                              onTap: _lock,
                            ),
                            PlayerSpeedPill(
                              label: _speedLabel,
                              semanticLabel: NovaStrings.lookup(
                                english,
                                'playerPlaybackSpeed',
                              ),
                              onTap: _openSettingsPanel,
                            ),
                          ],
                        ),
                        // Task 139 (user mandate): the transport trio
                        // [rewind][play/pause][forward] lives in the MIDDLE
                        // of the screen with the configured seek steps.
                        PlayerCenterTransport(
                          isPlaying: engine.playing,
                          backStepSec: _backStepSec,
                          forwardStepSec: _forwardStepSec,
                          scale: scale,
                          wide: wide,
                          onPlayPause: () => unawaited(_togglePlay()),
                          onSkip: (s) => unawaited(_seekBy(s)),
                        ),
                        ValueListenableBuilder<PlaybackProgress?>(
                          valueListenable: engine.progress,
                          builder: (context, progress, _) => buildBottomCluster(
                            engine,
                            progress: progress,
                            identity: engine.interactionIdentity,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Gesture updates rebuild only this HUD, not the video page.
                ValueListenableBuilder<int>(
                  valueListenable: _hudRevision,
                  builder: (context, _, child) {
                    if (_mode == _GestureMode.seek) {
                      return Center(
                        child: SeekHud(
                          deltaSeconds: _hudDeltaSeconds,
                          targetText: formatPlayerTime(
                            Duration(milliseconds: _hudTargetMs),
                          ),
                        ),
                      );
                    }
                    if (_mode == _GestureMode.brightness) {
                      return Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 24),
                          child: VerticalHud(
                            icon: LucideIcons.sunMoon,
                            label: NovaStrings.lookup(english, 'message16'),
                            value: _hudValue,
                            vertical: true,
                          ),
                        ),
                      );
                    }
                    if (_mode == _GestureMode.volume) {
                      return Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 24),
                          child: VerticalHud(
                            icon: LucideIcons.volume2,
                            label: NovaStrings.lookup(english, 'message17'),
                            value: _hudValue,
                            vertical: true,
                          ),
                        ),
                      );
                    }
                    if (_mode == _GestureMode.zoom && _zoom > 1.01) {
                      return Center(child: ZoomHud(scale: _zoom));
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Reset-zoom chip.
                if (_zoom > 1.01 &&
                    _mode == _GestureMode.none &&
                    _controlsVisible)
                  PositionedDirectional(
                    top: railTopInset + 168,
                    end: 14,
                    child: Material(
                      color: NovaColors.ink.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => setState(() => _zoom = 1),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.scan,
                                  size: 14, color: NovaColors.white),
                              SizedBox(width: 6),
                              Text(
                                '1×',
                                style: TextStyle(
                                  color: NovaColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Lock pill — the only chrome while locked.
                if (_locked)
                  PositionedDirectional(
                    bottom: 26,
                    start: 16,
                    child: Material(
                      color: NovaColors.ink.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _unlock,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            LucideIcons.lock,
                            color: NovaColors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Hint pill.
                if (_hintVisible && !_temporarySpeed.active)
                  Center(child: LockHintHud(message: _lastHint)),

                // Double-tap seek ripple (Task 124: animated ±N feedback),
                // anchored to the tapped third of the screen.
                if (_rippleVisible && !_locked && !_temporarySpeed.active)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Align(
                        alignment: _rippleForward
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 56,
                          ),
                          child: DoubleTapRipple(
                            key: ValueKey(_rippleKey),
                            forward: _rippleForward,
                            seconds: _rippleSeconds,
                            english: english,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Resume card.
                if (!_locked && _resuming && (_resumePositionMs ?? 0) > 30000)
                  PositionedDirectional(
                    bottom: 180 * scale,
                    start: 16,
                    child: PlayerCardShell(
                      width: 340,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlayerCardHeader(
                            icon: LucideIcons.history,
                            label: NovaStrings.lookup(english, 'message18'),
                            trailing: InkWell(
                              onTap: () => unawaited(_startOverFromPrompt()),
                              child: Icon(LucideIcons.x,
                                  size: 17,
                                  color:
                                      NovaColors.white.withValues(alpha: .38)),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            NovaStrings.lookup(english, 'message19', {
                              'p0': formatPlayerTime(Duration(
                                  milliseconds: _resumePositionMs ?? 0))
                            }),
                            style: const TextStyle(
                              color: NovaColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              Expanded(
                                child: PlayerPrimaryAction(
                                  label:
                                      NovaStrings.lookup(english, 'message20'),
                                  onPressed: () =>
                                      unawaited(_resumeFromSaved()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: PlayerSecondaryAction(
                                  label:
                                      NovaStrings.lookup(english, 'message21'),
                                  onPressed: () =>
                                      unawaited(_startOverFromPrompt()),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // Up-Next card. Suppressed while the skip-outro pill is up
                // (the same corner — the outro pill is the actionable one
                // there; the card returns once the outro window passes).
                if (!_locked &&
                    !_temporarySpeed.active &&
                    ready &&
                    !failed &&
                    nextEpisode != null &&
                    cardAppearAt >= 0 &&
                    position >= cardAppearAt &&
                    !outroVisible &&
                    !_upNextDismissed &&
                    !_stopScrobbled)
                  PositionedDirectional(
                    bottom: 180 * scale,
                    end: 16,
                    child: PlayerCardShell(
                      width: 288,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlayerCardHeader(
                            icon: LucideIcons.skipForward,
                            label: NovaStrings.lookup(english, 'message22'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: HorseTheme.canvas,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: HorseTheme.line),
                              ),
                              child: Text(
                                _cardCountdown(duration, position),
                                style: TextStyle(
                                  color:
                                      NovaColors.white.withValues(alpha: .54),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            (nextEpisode['name'] ??
                                    nextEpisode['title'] ??
                                    'Episode')
                                .toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: NovaColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (nextEpisode['season'] != null &&
                              nextEpisode['episode'] != null)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(top: 3),
                              child: Text(
                                'S${(nextEpisode['season'] as num).toInt()}:E${(nextEpisode['episode'] as num).toInt()}',
                                style: TextStyle(
                                  color:
                                      NovaColors.white.withValues(alpha: .54),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              Expanded(
                                child: PlayerPrimaryAction(
                                  label:
                                      NovaStrings.lookup(english, 'message23'),
                                  // Spec B2.3: ALWAYS through the existing
                                  // source-selection page — never auto-pick.
                                  onPressed: () => unawaited(
                                    _startEpisodeSources(nextEpisode),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PlayerSecondaryAction(
                                label: NovaStrings.lookup(english, 'cancel'),
                                onPressed: () =>
                                    setState(() => _upNextDismissed = true),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                // Workstream B: skip-intro / skip-outro pill. Visible ONLY
                // while the playhead is inside a data-provided window — with
                // no timing data it never appears (spec B1.4/B3: no guessed
                // timings, feature inactive).
                if (!_temporarySpeed.active && (introVisible || outroVisible))
                  PositionedDirectional(
                    bottom: 180 * scale,
                    end: 16,
                    child: _SegmentSkipPill(
                      key: ValueKey(introVisible ? 'intro' : 'outro'),
                      label: introVisible
                          ? (NovaStrings.lookup(english, 'message24'))
                          : (NovaStrings.lookup(english, 'message25')),
                      icon: introVisible
                          ? LucideIcons.fastForward
                          : LucideIcons.skipForward,
                      onTap: () => unawaited(_skipSegment(intro: introVisible)),
                    ),
                  ),
              ],

              // Task 139: the right-half picker panel (subtitles / audio /
              // sources) — an in-page overlay on the RIGHT HALF of the
              // screen, opened with a single setState (instant), loading
              // and refreshing its data in front of the user.
              if (_panel != null) ...[
                Positioned.fill(
                    child: GestureDetector(
                        onTap: _closePanel,
                        behavior: HitTestBehavior.opaque,
                        child: ColoredBox(
                            color: Theme.of(context)
                                .colorScheme
                                .scrim
                                .withValues(alpha: .32)))),
                PositionedDirectional(
                  end: 0,
                  start: MediaQuery.sizeOf(context).width < 600 &&
                          MediaQuery.sizeOf(context).height > width
                      ? 0
                      : null,
                  top: MediaQuery.sizeOf(context).width < 600 &&
                          MediaQuery.sizeOf(context).height > width
                      ? null
                      : 0,
                  bottom: 0,
                  width: MediaQuery.sizeOf(context).width < 600 &&
                          MediaQuery.sizeOf(context).height > width
                      ? null
                      : playerPanelWidth(width),
                  height: MediaQuery.sizeOf(context).width < 600 &&
                          MediaQuery.sizeOf(context).height > width
                      ? MediaQuery.sizeOf(context).height * .82
                      : null,
                  child: _buildPanel(engine),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The card's countdown: to the auto-advance moment when data provides
  /// one, otherwise to the end of the episode (shipped display behavior).
  String _cardCountdown(int duration, int position) {
    final at = SegmentWindows.autoAdvanceAtMs(
          segments: _segments,
          durationMs: duration,
        ) ??
        duration;
    final seconds = ((at - position) / 1000).ceil().clamp(0, 9999);
    final s = seconds.toString();
    final unit = NovaStrings.lookup(english, 'message26');
    return seconds > 0
        ? (NovaStrings.lookup(english, 'message27', {'p0': s, 'p1': unit}))
        : (NovaStrings.lookup(english, 'message28'));
  }
}

// ── Error panel ────────────────────────────────────────────────────────────

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.english,
    required this.onRetry,
  });

  final String? message;
  final bool english;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.circleAlert,
                size: 46,
                color: NovaColors.redSoft,
              ),
              const SizedBox(height: 14),
              Text(
                NovaStrings.lookup(english, 'message29'),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (message != null)
                Text(
                  message!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.refreshCw),
                label: Text(NovaStrings.lookup(english, 'retry')),
              ),
            ],
          ),
        ),
      );
}

class _PlaybackResolution {
  const _PlaybackResolution({
    required this.url,
    required this.headers,
    required this.torrent,
  });

  final String url;
  final Map<String, String> headers;
  final PreparedTorrent? torrent;
}

/// Skip-intro / skip-outro pill (workstream B). Material icon + label in the
/// translucent pill language of the player's other chrome (_TorrentHud);
/// 44px-tall touch target for landscape phones.
class _SegmentSkipPill extends StatelessWidget {
  const _SegmentSkipPill({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: NovaColors.ink.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: NovaColors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: NovaColors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _TorrentHud extends StatelessWidget {
  const _TorrentHud({required this.status, required this.english});

  final TorrentStatus status;
  final bool english;

  String _speed(num bps) {
    if (bps >= 1024 * 1024) {
      return '${(bps / 1024 / 1024).toStringAsFixed(1)} MB/s';
    }
    if (bps >= 1024) return '${(bps / 1024).toStringAsFixed(0)} kB/s';
    return '${bps.toStringAsFixed(0)} B/s';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (status.progress.clamp(0.0, 1.0) * 100).toStringAsFixed(1);
    final state = switch (status.state) {
      'downloading' => NovaStrings.lookup(english, 'message30'),
      'finished' => NovaStrings.lookup(english, 'message31'),
      'seeding' => NovaStrings.lookup(english, 'message32'),
      'paused' => NovaStrings.lookup(english, 'message33'),
      'checking' => NovaStrings.lookup(english, 'message34'),
      _ => NovaStrings.lookup(english, 'message35'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NovaColors.ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NovaColors.white.withValues(alpha: .24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 7,
            height: 7,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: NovaColors.white.withValues(alpha: .70),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$state · \u2066↓ ${_speed(status.downloadRate)}'
              ' · P:${status.numPeers} S:${status.numSeeds} · $pct%\u2069',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NovaColors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
