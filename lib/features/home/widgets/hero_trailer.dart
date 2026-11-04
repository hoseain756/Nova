import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/models/media_item.dart';
import '../../../core/state/app_state.dart';
import '../../../l10n/nova_strings.dart';
import 'hero_trailer_policy.dart';

/// One bounded, OS-provided preview. It never allocates a full playback engine
/// or touches the torrent/session ownership barrier. Removing this widget
/// retires its WebView, including when a route covers Home.
class HeroTrailer extends StatefulWidget {
  const HeroTrailer({
    super.key,
    required this.item,
    required this.app,
    required this.active,
    required this.poster,
    required this.onPlaybackChanged,
  });
  final MediaItem item;
  final AppState app;
  final bool active;
  final Widget poster;
  final ValueChanged<bool> onPlaybackChanged;

  @override
  State<HeroTrailer> createState() => _HeroTrailerState();
}

class _HeroTrailerState extends State<HeroTrailer> with WidgetsBindingObserver {
  static const _environment = MethodChannel('nova/appearance');
  WebViewController? _controller;
  Timer? _delay, _environmentTimer, _previewLimit;
  int _generation = 0;
  bool _foreground = true, _muted = true, _stopped = false, _playing = false;
  bool _checking = false;
  bool _opening = false;
  bool _hasSpace = false;
  HeroTrailerEnvironment _conditions = const HeroTrailerEnvironment.unknown();
  String _settingsSignature = '';
  String get _signature => '${widget.app.webSettings['heroTrailerAutoplay']}:'
      '${widget.app.contentTmdbLocale}:${widget.app.webSettings['tmdbUseTrailers']}';

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _visible =>
      mounted && _foreground && widget.active && !_stopped && _hasSpace;

  bool get _allowed =>
      _supported &&
      canAutoplayHeroTrailer(
        mode: heroTrailerMode(widget.app.webSettings['heroTrailerAutoplay']),
        environment: _conditions,
        visible: _visible,
        reducedMotion: MediaQuery.disableAnimationsOf(context) ||
            widget.app.webSettings['reduceMotion'] == true,
      );

  @override
  void initState() {
    super.initState();
    _settingsSignature = _signature;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _synchronize();
  }

  @override
  void didUpdateWidget(covariant HeroTrailer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _signature;
    if (oldWidget.item.id != widget.item.id ||
        signature != _settingsSignature) {
      _settingsSignature = signature;
      _stopped = false;
      _retire();
    }
    _synchronize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!mounted) return;
    setState(_synchronize);
  }

  void _synchronize() {
    if (!_visible ||
        !_supported ||
        heroTrailerMode(widget.app.webSettings['heroTrailerAutoplay']) ==
            HeroTrailerMode.never ||
        MediaQuery.disableAnimationsOf(context) ||
        widget.app.webSettings['reduceMotion'] == true) {
      _environmentTimer?.cancel();
      _environmentTimer = null;
      _retire();
      return;
    }
    if (_environmentTimer == null) {
      unawaited(_refreshEnvironment());
      _environmentTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        unawaited(_refreshEnvironment());
      });
    }
    if (!_allowed) {
      _retire();
    } else if (_controller == null && _delay == null && !_opening) {
      _delay = Timer(const Duration(seconds: 3), () {
        _delay = null;
        if (_allowed) unawaited(_open());
      });
    }
  }

  Future<void> _refreshEnvironment() async {
    if (_checking || !_visible) return;
    _checking = true;
    try {
      final value =
          await _environment.invokeMapMethod<Object?, Object?>('environment');
      if (!mounted || !_visible) return;
      setState(() {
        _conditions = value == null
            ? const HeroTrailerEnvironment.unknown()
            : HeroTrailerEnvironment.fromMap(value);
        _synchronize();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _conditions = const HeroTrailerEnvironment.unknown();
          _retire();
        });
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    final generation = ++_generation;
    try {
      final url = await widget.app.catalogs
          .heroTrailer(widget.item, language: widget.app.contentTmdbLocale);
      final id = heroYoutubeId(url);
      if (!mounted || generation != _generation || !_allowed) return;
      if (id == null) {
        _stopped = true;
        _environmentTimer?.cancel();
        _environmentTimer = null;
        return;
      }
      final package = await PackageInfo.fromPlatform();
      if (!mounted || generation != _generation || !_allowed) return;
      final origin = Uri(scheme: 'https', host: package.packageName).origin;
      PlatformWebViewControllerCreationParams params =
          const PlatformWebViewControllerCreationParams();
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      }
      final controller = WebViewController.fromPlatformCreationParams(params);
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0xFF121416));
      await controller.addJavaScriptChannel('NovaTrailer',
          onMessageReceived: (message) {
        if (!mounted || generation != _generation) return;
        if (message.message == 'playing') {
          setState(() => _playing = true);
          widget.onPlaybackChanged(true);
        } else if (message.message == 'ended' || message.message == 'error') {
          _stop();
        }
      });
      await controller.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (!request.isMainFrame) return NavigationDecision.navigate;
          if (request.url == 'about:blank') return NavigationDecision.navigate;
          final uri = Uri.tryParse(request.url);
          return uri?.scheme == 'https' && uri?.origin == origin
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true &&
              mounted &&
              generation == _generation) {
            _stop();
          }
        },
      ));
      if (controller.platform is AndroidWebViewController) {
        await (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }
      if (!mounted || generation != _generation || !_allowed) return;
      _muted = true;
      setState(() {
        _controller = controller;
        _playing = true;
      });
      widget.onPlaybackChanged(true);
      // Include provider loading in the lifetime bound. A slow platform call
      // must not leave an allocated preview alive indefinitely.
      _previewLimit = Timer(const Duration(seconds: 35), _stop);
      // The OS WebView supplies the app-identity Referer from this base URL.
      // Keep the provider player unobscured: title/mute/stop sit below it.
      await controller.loadHtmlString(_playerHtml(id, origin),
          baseUrl: '$origin/');
    } catch (_) {
      if (mounted && generation == _generation) {
        _stop();
      }
    } finally {
      if (generation == _generation) _opening = false;
    }
  }

  void _retire() {
    _generation++;
    _opening = false;
    _delay?.cancel();
    _delay = null;
    _previewLimit?.cancel();
    final old = _controller;
    _controller = null;
    if (old != null) {
      unawaited(old
          .runJavaScript('if(window.player){player.stopVideo();}')
          .catchError((Object _) {}));
      unawaited(
          old.loadRequest(Uri.parse('about:blank')).catchError((Object _) {}));
    }
    if (_playing) {
      _playing = false;
      // Avoid notifying a parent while its children are building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPlaybackChanged(false);
      });
    }
  }

  void _stop() {
    if (!mounted) return;
    setState(() {
      _stopped = true;
      _environmentTimer?.cancel();
      _environmentTimer = null;
      _retire();
    });
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller
          .runJavaScript(_muted ? 'player.unMute();' : 'player.mute();');
      if (mounted && identical(controller, _controller)) {
        setState(() => _muted = !_muted);
      }
    } catch (_) {/* Leave a working muted preview available. */}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _environmentTimer?.cancel();
    _retire();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final strings = NovaStrings.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final fits = constraints.maxHeight >= 260 && constraints.maxWidth >= 200;
      if (fits != _hasSpace) {
        _hasSpace = fits;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(_synchronize);
        });
      }
      if (!fits) return widget.poster;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
            child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context) ||
                        widget.app.webSettings['reduceMotion'] == true
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                child: controller == null
                    ? KeyedSubtree(
                        key: const ValueKey('trailer-poster'),
                        child: widget.poster)
                    : WebViewWidget(
                        key: ValueKey(controller),
                        controller: controller,
                      ))),
        if (controller != null)
          Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Row(children: [
                const SizedBox(width: 12),
                Expanded(
                    child: Text(strings.text('heroTrailerPreview'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium)),
                IconButton(
                    onPressed: _toggleMute,
                    tooltip: strings
                        .text(_muted ? 'heroTrailerUnmute' : 'heroTrailerMute'),
                    icon: Icon(
                        _muted ? LucideIcons.volumeX : LucideIcons.volume2)),
                IconButton(
                    onPressed: _stop,
                    tooltip: strings.text('heroTrailerStop'),
                    icon: const Icon(LucideIcons.pause)),
              ])),
      ]);
    });
  }
}

String _playerHtml(String id, String origin) => '''<!doctype html>
<html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body,#player{margin:0;width:100%;height:100%;background:#121416;overflow:hidden}</style>
</head><body><div id="player"></div><script src="https://www.youtube.com/iframe_api"></script>
<script>var player;function send(v){NovaTrailer.postMessage(v);}
function onYouTubeIframeAPIReady(){player=new YT.Player('player',{
videoId:${jsonEncode(id)},host:'https://www.youtube-nocookie.com',
playerVars:{autoplay:1,playsinline:1,controls:1,origin:${jsonEncode(origin)},rel:0},
events:{onReady:function(e){e.target.mute();e.target.playVideo();},
onStateChange:function(e){if(e.data===1)send('playing');if(e.data===0)send('ended');},
onError:function(){send('error');},onAutoplayBlocked:function(){send('error');}}});}
</script></body></html>''';
