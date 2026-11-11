import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/horse_theme.dart';
import 'player_blur_action_pill.dart';

/// High-contrast controls drawn over fullscreen video.
class PlayerPalette {
  static const Color gradientStart = NovaColors.red;
  static const Color gradientEnd = NovaColors.redSoft;
  static const Color thumb = NovaColors.redSoft;

  static const List<Shadow> iconShadow = [
    Shadow(color: NovaColors.scrim, blurRadius: 6, offset: Offset(0, 1)),
  ];

  static const LinearGradient played = LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [gradientStart, gradientEnd],
  );
}

String formatPlayerTime(Duration value, {bool padMinutes = false}) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  final displayMinutes = padMinutes
      ? value.inMinutes.toString().padLeft(2, '0')
      : value.inMinutes.toString();
  return hours > 0 ? '$hours:$minutes:$seconds' : '$displayMinutes:$seconds';
}

/// Zero-padded episode tag per the user mandate: `S01E12`.
String seasonEpisodeTag(int? season, int? episode) {
  if (season == null || episode == null) return '';
  final s = season.toString().padLeft(2, '0');
  final e = episode.toString().padLeft(2, '0');
  return 'S${s}E$e';
}

// ── Top bar ────────────────────────────────────────────────────────────────

class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.title,
    required this.episodeTag,
    required this.onClose,
    this.streamInfo,
    this.streamInfoSemanticLabel,
    this.statusInfo,
    this.wide = false,
    required this.onLock,
    this.locked = false,
    this.onResetZoom,
  });

  final VoidCallback onLock;
  final bool locked;
  final VoidCallback? onResetZoom;
  final String title;

  /// Empty for movies; `S01E12` for series (rendered under the title).
  final String episodeTag;
  final String? streamInfo;
  final String? streamInfoSemanticLabel;
  final Widget? statusInfo;
  final VoidCallback onClose;

  /// Tablet sizing (larger title font).
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: 0,
      start: 0,
      end: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NovaColors.scrim, Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                wide ? 24 : 16, 6, wide ? 24 : 16, 12),
            child: Row(
              children: [
                if (locked)
                  IconButton(
                      icon: const Icon(LucideIcons.lockOpen,
                          color: NovaColors.white),
                      tooltip: NovaStrings.of(context).text('unlock'),
                      onPressed: onLock)
                else
                  PlayerBackButton(onTap: onClose),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: NovaColors.white,
                          fontSize: wide ? 16.5 : 14,
                          fontWeight: FontWeight.w600,
                          shadows: PlayerPalette.iconShadow,
                        ),
                      ),
                      if (episodeTag.isNotEmpty ||
                          streamInfo?.isNotEmpty == true ||
                          statusInfo != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (episodeTag.isNotEmpty)
                                Directionality(
                                  // Mixed-script mandate: the tag is always LTR.
                                  textDirection: TextDirection.ltr,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          NovaColors.ink.withValues(alpha: .84),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: NovaColors.white
                                            .withValues(alpha: .24),
                                      ),
                                    ),
                                    child: Text(
                                      episodeTag,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: NovaColors.white,
                                        fontSize: wide ? 12 : 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: .8,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (episodeTag.isNotEmpty &&
                                  (streamInfo?.isNotEmpty == true ||
                                      statusInfo != null))
                                const SizedBox(width: 6),
                              if (streamInfo?.isNotEmpty == true)
                                Flexible(
                                  flex: statusInfo == null ? 1 : 2,
                                  child: Semantics(
                                    label:
                                        streamInfoSemanticLabel ?? streamInfo,
                                    excludeSemantics: true,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: NovaColors.ink
                                            .withValues(alpha: .84),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: NovaColors.white
                                              .withValues(alpha: .24),
                                        ),
                                      ),
                                      child: Text(
                                        streamInfo!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: NovaColors.white,
                                          fontSize: 11.5,
                                          height: 1.2,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (streamInfo?.isNotEmpty == true &&
                                  statusInfo != null)
                                const SizedBox(width: 6),
                              if (statusInfo != null)
                                Flexible(flex: 3, child: statusInfo!),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (locked)
                  const SizedBox(width: 48)
                else ...[
                  if (onResetZoom != null)
                    TextButton(
                        onPressed: onResetZoom,
                        style: TextButton.styleFrom(
                            foregroundColor: NovaColors.white),
                        child: const Text('1×')),
                  IconButton(
                      tooltip:
                          NovaStrings.of(context).text('playerLockControls'),
                      onPressed: onLock,
                      icon: const Icon(LucideIcons.lockKeyhole,
                          color: NovaColors.white),
                      constraints:
                          const BoxConstraints.tightFor(width: 48, height: 48)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerBackButton extends StatelessWidget {
  const PlayerBackButton({super.key, required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
        onPressed: onTap,
        tooltip: MaterialLocalizations.of(context).closeButtonLabel,
        style: IconButton.styleFrom(
            minimumSize: const Size.square(48),
            backgroundColor: NovaColors.ink.withValues(alpha: .72),
            foregroundColor: NovaColors.white),
        icon: const Icon(LucideIcons.x, size: 22),
      );
}

class PlayerCenterTransport extends StatelessWidget {
  const PlayerCenterTransport(
      {super.key, required this.isPlaying, required this.onPlayPause});
  final bool isPlaying;
  final VoidCallback onPlayPause;
  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Center(
            child: IconButton.filled(
          tooltip: NovaStrings.of(context)
              .text(isPlaying ? 'playerPause' : 'message714'),
          onPressed: onPlayPause,
          style: IconButton.styleFrom(
              fixedSize: const Size.square(72),
              backgroundColor: NovaColors.ink.withValues(alpha: .76),
              foregroundColor: NovaColors.white),
          iconSize: 32,
          icon: Icon(isPlaying ? LucideIcons.pause : LucideIcons.play),
        )),
      );
}

// ── Gradient timeline ──────────────────────────────────────────────────────

class GradientTimeline extends StatefulWidget {
  const GradientTimeline({
    super.key,
    required this.durationMs,
    required this.positionMs,
    required this.bufferedMs,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    this.thickness = 4.0,
    this.readExactPositionMs,
    this.readExactDurationMs,
    this.interactionIdentity,
  });

  final int durationMs;
  final int positionMs;
  final int bufferedMs;

  /// Display samples may lag; commands read authoritative values on demand.
  final int Function()? readExactPositionMs;
  final int Function()? readExactDurationMs;
  final Object? interactionIdentity;

  /// Bar thickness — slightly thicker on tablets (spec §0-ب).
  final double thickness;

  /// Called when a scrub gesture starts (hold controls visible).
  final VoidCallback onScrubStart;
  final ValueChanged<double> onScrubUpdate; // seconds preview
  final ValueChanged<double> onScrubEnd; // seconds commit

  @override
  State<GradientTimeline> createState() => _GradientTimelineState();
}

class _GradientTimelineState extends State<GradientTimeline> {
  bool _dragging = false;
  double _dragFraction = 0;
  Object? _dragIdentity;

  int get _exactDurationMs =>
      widget.readExactDurationMs?.call() ?? widget.durationMs;

  @override
  void didUpdateWidget(covariant GradientTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.interactionIdentity, widget.interactionIdentity) ||
        _exactDurationMs <= 0) {
      _dragging = false;
    }
  }

  bool _current(Object? identity) =>
      identical(identity, widget.interactionIdentity);

  void _commitFraction(double fraction, Object? identity) {
    if (!_current(identity)) return;
    final duration = _exactDurationMs;
    if (duration <= 0) return;
    widget.onScrubEnd(fraction.clamp(0.0, 1.0) * duration / 1000);
  }

  void _step(int deltaMs) {
    final duration = _exactDurationMs;
    if (duration <= 0) return;
    final position = widget.readExactPositionMs?.call() ?? widget.positionMs;
    widget.onScrubEnd((position + deltaMs).clamp(0, duration) / 1000);
  }

  double get _progress {
    if (_dragging) return _dragFraction;
    if (widget.durationMs <= 0) return 0;
    return (widget.positionMs / widget.durationMs).clamp(0.0, 1.0);
  }

  double _valueFromDx(double dx, double width) {
    final position = (dx / (width == 0 ? 1 : width)).clamp(0.0, 1.0);
    return Directionality.of(context) == TextDirection.rtl
        ? 1 - position
        : position;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final duration = widget.durationMs;
        final canSeek = _exactDurationMs > 0;
        final thickness = widget.thickness;
        final thumbSize = thickness + 10;
        final buffered =
            duration > 0 ? (widget.bufferedMs / duration).clamp(0.0, 1.0) : 0.0;
        final progress = _progress;

        void handleTap(double dx) {
          final value = _valueFromDx(dx, width);
          final identity = widget.interactionIdentity;
          widget.onScrubStart();
          _commitFraction(value, identity);
        }

        return Semantics(
          label: NovaStrings.lookup(
              Localizations.localeOf(context).languageCode != 'ar',
              'playbackPosition'),
          value: formatPlayerTime(Duration(milliseconds: widget.positionMs)),
          increasedValue: duration > 0
              ? formatPlayerTime(Duration(
                  milliseconds: (widget.positionMs + 10000).clamp(0, duration)))
              : null,
          decreasedValue: duration > 0
              ? formatPlayerTime(Duration(
                  milliseconds: (widget.positionMs - 10000).clamp(0, duration)))
              : null,
          onIncrease: canSeek ? () => _step(10000) : null,
          onDecrease: canSeek ? () => _step(-10000) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: !canSeek
                ? null
                : (details) {
                    final identity = widget.interactionIdentity;
                    widget.onScrubStart();
                    if (!_current(identity) || _exactDurationMs <= 0) return;
                    setState(() {
                      _dragging = true;
                      _dragIdentity = identity;
                      _dragFraction =
                          _valueFromDx(details.localPosition.dx, width);
                    });
                    widget
                        .onScrubUpdate(_dragFraction * _exactDurationMs / 1000);
                  },
            onHorizontalDragUpdate: !canSeek
                ? null
                : (details) {
                    if (!_dragging) return;
                    if (!_current(_dragIdentity) || _exactDurationMs <= 0) {
                      setState(() => _dragging = false);
                      return;
                    }
                    setState(() {
                      _dragFraction =
                          _valueFromDx(details.localPosition.dx, width);
                    });
                    widget
                        .onScrubUpdate(_dragFraction * _exactDurationMs / 1000);
                  },
            onHorizontalDragEnd: !canSeek
                ? null
                : (details) {
                    if (!_dragging) return;
                    final fraction = _dragFraction;
                    final identity = _dragIdentity;
                    setState(() => _dragging = false);
                    _commitFraction(fraction, identity);
                  },
            onHorizontalDragCancel: () => setState(() => _dragging = false),
            onTapUp: !canSeek
                ? null
                : (details) => handleTap(details.localPosition.dx),
            child: SizedBox(
              height: 48,
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  // Remaining track.
                  Container(
                    height: thickness,
                    decoration: BoxDecoration(
                      color: NovaColors.white.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  // Buffered portion — second color per spec §2.
                  FractionallySizedBox(
                    widthFactor: buffered,
                    child: Container(
                      height: thickness,
                      decoration: BoxDecoration(
                        color: NovaColors.white.withValues(alpha: .38),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  // Played gradient.
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: thickness,
                      decoration: BoxDecoration(
                        gradient: PlayerPalette.played,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  // Thumb + scrub bubble.
                  PositionedDirectional(
                    start: (progress * width - thumbSize / 2)
                        .clamp(0.0, (width - thumbSize).clamp(0.0, width)),
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 120),
                      width: _dragging ? thumbSize + 4 : thumbSize,
                      height: _dragging ? thumbSize + 4 : thumbSize,
                      decoration: BoxDecoration(
                        color: PlayerPalette.thumb,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: NovaColors.ink.withValues(alpha: .45),
                            blurRadius: 5,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_dragging && duration > 0)
                    PositionedDirectional(
                      start: (progress * width - 44)
                          .clamp(0.0, (width - 88).clamp(0.0, width)),
                      bottom: 26,
                      child: Container(
                        width: thickness > 4 ? 120 : 88,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: NovaColors.ink.withValues(alpha: .78),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          formatPlayerTime(
                            Duration(
                                milliseconds:
                                    (progress * _exactDurationMs).round()),
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: NovaColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Bottom cluster ─────────────────────────────────────────────────────────

/// The timeline or live status sits above the localized player tools.
class PlayerBottomCluster extends StatelessWidget {
  const PlayerBottomCluster({
    super.key,
    required this.durationMs,
    required this.positionMs,
    required this.bufferedMs,
    required this.showRemaining,
    required this.wide,
    required this.english,
    required this.onOpenSpeed,
    required this.onOpenSettings,
    this.onOpenEpisodes,
    this.onOpenParty,
    this.live = false,
    required this.onOpenStreams,
    required this.onOpenSubtitles,
    required this.onOpenAudio,
    required this.onToggleRemaining,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    this.readExactPositionMs,
    this.readExactDurationMs,
    this.interactionIdentity,
  });

  final int durationMs;
  final int positionMs;
  final int bufferedMs;
  final int Function()? readExactPositionMs;
  final int Function()? readExactDurationMs;
  final Object? interactionIdentity;
  final bool showRemaining;

  final bool wide;
  final bool english;
  final bool live;
  final VoidCallback onOpenSettings, onOpenSpeed;
  final VoidCallback? onOpenEpisodes;
  final VoidCallback? onOpenParty;
  final VoidCallback onOpenStreams;
  final VoidCallback onOpenSubtitles;
  final VoidCallback onOpenAudio;
  final VoidCallback onToggleRemaining;
  final VoidCallback onScrubStart;
  final ValueChanged<double> onScrubUpdate;
  final ValueChanged<double> onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final margin = wide ? 28.0 : 14.0;
    final thickness = wide ? 6.0 : 4.0;
    return PositionedDirectional(
      start: 0,
      end: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              NovaColors.ink.withValues(alpha: .97),
              NovaColors.ink.withValues(alpha: .87),
              NovaColors.ink.withValues(alpha: 0),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(margin, 12, margin, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User-selected timeline convention: Arabic begins on the
                // left, English on the right. Keep fill, thumb, labels and
                // touch coordinates in the same direction.
                if (live)
                  Text(NovaStrings.lookup(english, 'message658'),
                      style: const TextStyle(color: NovaColors.white))
                else
                  Directionality(
                    textDirection:
                        english ? TextDirection.rtl : TextDirection.ltr,
                    child: Row(
                      children: [
                        _TimeLabel(
                          text: formatPlayerTime(
                            Duration(milliseconds: positionMs),
                          ),
                          wide: wide,
                          onTap: onToggleRemaining,
                        ),
                        Expanded(
                          child: GradientTimeline(
                            durationMs: durationMs,
                            positionMs: positionMs,
                            bufferedMs: bufferedMs,
                            readExactPositionMs: readExactPositionMs,
                            readExactDurationMs: readExactDurationMs,
                            interactionIdentity: interactionIdentity,
                            thickness: thickness,
                            onScrubStart: onScrubStart,
                            onScrubUpdate: onScrubUpdate,
                            onScrubEnd: onScrubEnd,
                          ),
                        ),
                        _TimeLabel(
                          text: showRemaining && durationMs > 0
                              ? '-${formatPlayerTime(Duration(milliseconds: durationMs - positionMs))}'
                              : formatPlayerTime(
                                  Duration(milliseconds: durationMs)),
                          wide: wide,
                          onTap: onToggleRemaining,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 2),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final (icon, key, callback) in [
                        (LucideIcons.volume2, 'message6', onOpenAudio),
                        (LucideIcons.captions, 'message7', onOpenSubtitles),
                        (LucideIcons.fastForward, 'message82', onOpenSpeed),
                        (
                          LucideIcons.slidersHorizontal,
                          'message8',
                          onOpenStreams
                        ),
                        (LucideIcons.settings2, 'message9', onOpenSettings),
                        if (onOpenEpisodes != null)
                          (LucideIcons.listVideo, 'message43', onOpenEpisodes!),
                        if (onOpenParty != null)
                          (LucideIcons.usersRound, 'partyTitle', onOpenParty!),
                      ])
                        _PlayerTool(
                            icon: icon,
                            label: NovaStrings.lookup(english, key),
                            onTap: callback),
                    ])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerTool extends StatelessWidget {
  const _PlayerTool(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final children = [
      Icon(icon, size: 20),
      SizedBox(width: compact ? 0 : 6, height: compact ? 3 : 0),
      Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
    ];
    return TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
            foregroundColor: NovaColors.white,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
        child: compact
            ? Column(mainAxisSize: MainAxisSize.min, children: children)
            : Row(mainAxisSize: MainAxisSize.min, children: children));
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel(
      {required this.text, required this.onTap, this.wide = false});
  final String text;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Text(
            text,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: NovaColors.white.withValues(alpha: .70),
              fontSize: wide ? 13.5 : 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
}

// ── Double-tap ripple (user mandate: animated ±N feedback) ────────────────

/// YouTube-style double-tap feedback: a soft circular burst anchored to the
/// tapped side, showing the arrow glyph and the ±N seconds label, scaling in
/// and fading out once.
class DoubleTapRipple extends StatefulWidget {
  const DoubleTapRipple({
    super.key,
    required this.forward,
    required this.seconds,
    required this.english,
  });

  final bool forward;
  final int seconds;
  final bool english;

  @override
  State<DoubleTapRipple> createState() => _DoubleTapRippleState();
}

class _DoubleTapRippleState extends State<DoubleTapRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: .55, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 42,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 58),
  ]).animate(_controller);

  late final Animation<double> _fade = TweenSequence<double>([
    TweenSequenceItem(
      tween:
          Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 18,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 42),
    TweenSequenceItem(
      tween:
          Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
      weight: 40,
    ),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: MediaQuery.disableAnimationsOf(context)
            ? const AlwaysStoppedAnimation(1.0)
            : _fade,
        child: ScaleTransition(
          scale: MediaQuery.disableAnimationsOf(context)
              ? const AlwaysStoppedAnimation(1.0)
              : _scale,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  NovaColors.white.withValues(alpha: .20),
                  NovaColors.white.withValues(alpha: .06),
                  NovaColors.white.withValues(alpha: 0),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NovaColors.white.withValues(alpha: .13),
                border:
                    Border.all(color: NovaColors.white.withValues(alpha: .24)),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.forward ==
                            (Directionality.of(context) == TextDirection.ltr)
                        ? LucideIcons.chevronsRight
                        : LucideIcons.chevronsLeft,
                    color: NovaColors.white,
                    size: 32,
                    shadows: PlayerPalette.iconShadow,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    NovaStrings.lookup(widget.english, 'message41', {
                      'p0': widget.forward ? '+' : '-',
                      'p1': widget.seconds
                    }),
                    style: const TextStyle(
                      color: NovaColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                      shadows: PlayerPalette.iconShadow,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── Gesture HUDs ───────────────────────────────────────────────────────────

class SeekHud extends StatelessWidget {
  const SeekHud({
    super.key,
    required this.deltaSeconds,
    required this.targetText,
  });

  final int deltaSeconds;
  final String targetText;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: NovaColors.ink.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    deltaSeconds >= 0
                        ? LucideIcons.chevronsRight
                        : LucideIcons.chevronsLeft,
                    color: PlayerPalette.thumb,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${deltaSeconds >= 0 ? '+' : ''}$deltaSeconds s',
                    style: const TextStyle(
                      color: NovaColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                targetText,
                style: TextStyle(
                  color: NovaColors.white.withValues(alpha: .70),
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      );
}

class VerticalHud extends StatelessWidget {
  const VerticalHud({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.vertical = false,
  });

  final IconData icon;
  final String label;
  final double value; // 0..1

  /// True = spec §6 side-anchored indicator (icon + vertical bar + percent);
  /// false = legacy compact centered card.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NovaColors.ink.withValues(alpha: .66),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: NovaColors.white.withValues(alpha: .12)),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: NovaColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 5,
                height: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(
                    alignment: AlignmentDirectional.bottomStart,
                    children: [
                      Container(color: NovaColors.white.withValues(alpha: .24)),
                      FractionallySizedBox(
                        heightFactor: value.clamp(0.0, 1.0),
                        child: Container(color: PlayerPalette.thumb),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Icon(icon, color: NovaColors.white, size: 20),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.ink.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: NovaColors.white, size: 22),
            const SizedBox(height: 8),
            SizedBox(
              width: 110,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: NovaColors.white.withValues(alpha: .24),
                  valueColor: const AlwaysStoppedAnimation(PlayerPalette.thumb),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$label · ${(value * 100).round()}%',
              style: TextStyle(
                color: NovaColors.white.withValues(alpha: .70),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ZoomHud extends StatelessWidget {
  const ZoomHud({super.key, required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: NovaColors.ink.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${scale.toStringAsFixed(1)}×',
          style: const TextStyle(
            color: NovaColors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      );
}

class LockHintHud extends StatelessWidget {
  const LockHintHud({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: NovaColors.ink.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.lock, color: NovaColors.white, size: 15),
            const SizedBox(width: 7),
            Text(
              message,
              style: const TextStyle(
                color: NovaColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

// ── Cards ──────────────────────────────────────────────────────────────────

/// Keeps the Up-Next card above the player controls without letting a short
/// landscape viewport or enlarged text push its header off screen. The card
/// remains scrollable when its content is taller than the available area.
class PlayerUpNextPlacement extends StatelessWidget {
  const PlayerUpNextPlacement({
    super.key,
    required this.scale,
    required this.child,
  });

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final safeEnd = Directionality.of(context) == TextDirection.rtl
        ? safe.left
        : safe.right;
    final bottom = (size.height * .28).clamp(48.0, 100.0 * scale) + safe.bottom;
    final maxHeight =
        (size.height - safe.top - bottom - 8).clamp(1.0, double.infinity);
    final maxWidth = (size.width - safe.horizontal - 32).clamp(1.0, 288.0);
    return PositionedDirectional(
      bottom: bottom,
      end: 16 + safeEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class PlayerCardShell extends StatelessWidget {
  const PlayerCardShell({
    super.key,
    required this.child,
    this.width,
  });

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HorseTheme.raised.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NovaColors.white.withValues(alpha: .07)),
          boxShadow: [
            BoxShadow(
              color: NovaColors.ink.withValues(alpha: .45),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
}

class PlayerCardHeader extends StatelessWidget {
  const PlayerCardHeader({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 15, color: HorseTheme.gold),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: NovaColors.white.withValues(alpha: .54),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      );
}

class PlayerUpNextActions extends StatelessWidget {
  const PlayerUpNextActions({
    super.key,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) => PlayerBlurActionPill(
        label: primaryLabel,
        onAction: onPrimary,
        onDismiss: onSecondary,
        dismissTooltip: secondaryLabel,
      );
}

class PlayerPrimaryAction extends StatelessWidget {
  const PlayerPrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(48),
        ),
        onPressed: onPressed,
        child: Text(label),
      );
}

class PlayerSecondaryAction extends StatelessWidget {
  const PlayerSecondaryAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
        ),
        onPressed: onPressed,
        child: Text(label),
      );
}
