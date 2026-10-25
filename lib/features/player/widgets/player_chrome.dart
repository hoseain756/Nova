import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/horse_theme.dart';

/// Visual language of the cinematic player chrome (reference design):
/// white controls over the video, a NOVA-red gradient timeline, a large
/// outlined central play control and slim translucent scrims.
///
/// Task 124/125 layout mandate:
///  · top bar — exit at the directional END, title at the START, with a
///    zero-padded `S01E12` tag underneath for series;
///  · progress row (current · timeline · total) sits ABOVE every control and
///    follows the locale's logical start/end seek direction;
///  · bottom row: fullscreen+volume at the directional END, source /
///    subtitles / audio at the START; the [rewind][play][forward] trio is
///    dead CENTER;
///  · gesture and rail placement follows the player's directional helpers.
/// Mirroring follows the inherited Directionality (Arabic RTL / English LTR).
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

String formatPlayerTime(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '${value.inMinutes}:$seconds';
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
  });

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
    // Directional mirror (spec §0): RTL → title right / exit left;
    // LTR → title left / exit right. START = title, END = exit.
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
            padding: EdgeInsetsDirectional.fromSTEB(12, 6, wide ? 24 : 12, 26),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
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
                const SizedBox(width: 10),
                PlayerBackButton(onTap: onClose),
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

// ── Rails ──────────────────────────────────────────────────────────────────

class PlayerRailButton extends StatelessWidget {
  const PlayerRailButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.active = false,
    this.iconSize = 22,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool active;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticLabel,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: active ? PlayerPalette.thumb : NovaColors.white,
              size: iconSize,
              shadows: PlayerPalette.iconShadow,
            ),
          ),
        ),
      );
}

/// Task 139 (user mandate): the transport trio [rewind][play/pause][forward]
/// lives in the MIDDLE of the screen — floating center controls — never
/// mirrored (rewind always left), with the seek step rendered inside the
/// circular arrows exactly as configured in settings.
class PlayerCenterTransport extends StatelessWidget {
  const PlayerCenterTransport({
    super.key,
    required this.isPlaying,
    required this.backStepSec,
    required this.forwardStepSec,
    required this.scale,
    required this.wide,
    required this.onPlayPause,
    required this.onSkip,
  });

  final bool isPlaying;
  final int backStepSec;
  final int forwardStepSec;
  final double scale;
  final bool wide;
  final VoidCallback onPlayPause;
  final ValueChanged<int> onSkip;

  @override
  Widget build(BuildContext context) {
    final big = wide ? 76.0 : 64.0;
    final skipSize = (wide ? 54.0 : 48.0) * scale;
    return Positioned.fill(
      child: Center(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SkipButton(
                forward: false,
                seconds: backStepSec,
                size: skipSize,
                onTap: () => onSkip(-backStepSec),
              ),
              SizedBox(width: 20 * scale),
              Semantics(
                button: true,
                label: NovaStrings.of(context)
                    .text(isPlaying ? 'playerPause' : 'message714'),
                child: GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    width: big,
                    height: big,
                    decoration: BoxDecoration(
                      color: NovaColors.white.withValues(alpha: .14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: NovaColors.white,
                        width: 2.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: NovaColors.ink.withValues(alpha: .38),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isPlaying ? LucideIcons.pause : LucideIcons.play,
                      color: NovaColors.white,
                      size: big * .5,
                      shadows: PlayerPalette.iconShadow,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 20 * scale),
              _SkipButton(
                forward: true,
                seconds: forwardStepSec,
                size: skipSize,
                onTap: () => onSkip(forwardStepSec),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerSpeedPill extends StatelessWidget {
  const PlayerSpeedPill({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticLabel,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 44,
            child: Center(
              child: Container(
                width: 52,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: NovaColors.ink.withValues(alpha: .30),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: NovaColors.white.withValues(alpha: .85),
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: NovaColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .4,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class PlayerSideRail extends StatelessWidget {
  const PlayerSideRail({
    super.key,
    required this.side,
    required this.topInset,
    required this.children,
  });

  final AxisSide side;
  final double topInset;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isLeft = side == AxisSide.left;
    return PositionedDirectional(
      top: topInset,
      start: isLeft ? 6 : null,
      end: isLeft ? null : 6,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isLeft ? 4 : 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final child in children) ...[
              child,
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

enum AxisSide { left, right }

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

/// Spec-exact bottom block (Task 124/125, trimmed by Task 139): progress row
/// above ALL controls; fullscreen+volume at the directional END, source /
/// subtitles / audio at the directional START. The [rewind][play][forward]
/// trio moved to the MIDDLE OF THE SCREEN (PlayerCenterTransport — Task 139
/// user mandate), so this row is slimmer and purely positional.
class PlayerBottomCluster extends StatelessWidget {
  const PlayerBottomCluster({
    super.key,
    required this.durationMs,
    required this.positionMs,
    required this.bufferedMs,
    required this.showRemaining,
    required this.volume,
    required this.muted,
    required this.fullscreen,
    required this.canPrev,
    required this.canNext,
    required this.scale,
    required this.wide,
    required this.english,
    required this.onPrev,
    required this.onNext,
    required this.onVolumeChanged,
    required this.onVolumeDragEnd,
    required this.onMuteToggle,
    required this.onToggleFullscreen,
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

  /// mpv volume, normalized 0..1 (drives the left slider).
  final double volume;
  final bool muted;

  /// True = system UI hidden (immersive); false = system UI visible.
  final bool fullscreen;

  final bool canPrev;
  final bool canNext;
  final double scale; // 1.0 phone · ~1.28 tablet

  /// Tablet mode: wider margins, labels under side icons, thicker bar.
  final bool wide;
  final bool english;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onVolumeDragEnd;
  final VoidCallback onMuteToggle;
  final VoidCallback onToggleFullscreen;

  /// Task 139: the pickers now open the right-half side panel — always
  /// available (the panel loads/refreshes its own data), never null.
  final VoidCallback onOpenStreams;
  final VoidCallback onOpenSubtitles;
  final VoidCallback onOpenAudio;
  final VoidCallback onToggleRemaining;
  final VoidCallback onScrubStart;
  final ValueChanged<double> onScrubUpdate;
  final ValueChanged<double> onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final controlSize = 48.0 * scale;
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
              NovaColors.ink.withValues(alpha: .70),
              NovaColors.ink.withValues(alpha: .40),
              NovaColors.ink.withValues(alpha: 0),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding:
                EdgeInsetsDirectional.fromSTEB(margin, 30, margin, 8 * scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User-selected timeline convention: Arabic begins on the
                // left, English on the right. Keep fill, thumb, labels and
                // touch coordinates in the same direction.
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
                SizedBox(height: 2 * scale),
                // Control row: side groups mirror with the direction; the
                // transport trio lives center-screen (Task 139).
                LayoutBuilder(builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _trackGroup(controlSize)),
                      const SizedBox(height: 4),
                      _mediaGroup(controlSize),
                    ]);
                  }
                  return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _trackGroup(controlSize),
                        _mediaGroup(controlSize)
                      ]);
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // END side: volume icon (tap = mute) + slider + fullscreen, with small
  // labels underneath on tablets (spec §0-ب).
  Widget _mediaGroup(double controlSize) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RaillessControl(
            icon: muted
                ? LucideIcons.volumeX
                : volume < .5
                    ? LucideIcons.volume1
                    : LucideIcons.volume2,
            semanticLabel:
                NovaStrings.lookup(english, muted ? 'unmute' : 'mute'),
            label: wide ? (NovaStrings.lookup(english, 'message36')) : null,
            scale: scale,
            onTap: onMuteToggle,
          ),
          _VolumeSlider(
            value: muted ? 0 : volume,
            width: (wide ? 130 : 84) * scale,
            onChanged: onVolumeChanged,
            onChangeEnd: (_) => onVolumeDragEnd(),
          ),
          _RaillessControl(
            icon: fullscreen ? LucideIcons.maximize : LucideIcons.minimize,
            semanticLabel: NovaStrings.lookup(
              english,
              fullscreen ? 'playerExitFullscreen' : 'message37',
            ),
            label: wide ? (NovaStrings.lookup(english, 'message37')) : null,
            scale: scale,
            onTap: onToggleFullscreen,
          ),
        ],
      );

  // START side: source / subtitles / audio (+ prev & next episode for
  // series), with small labels underneath on tablets. The pickers open the
  // right-half side panel (Task 139) — always available.
  Widget _trackGroup(double controlSize) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canPrev)
            _RaillessControl(
              icon: LucideIcons.skipBack,
              semanticLabel:
                  NovaStrings.lookup(english, 'playerPreviousEpisode'),
              scale: scale,
              iconSize: 28,
              onTap: onPrev,
            ),
          _RaillessControl(
            icon: LucideIcons.arrowLeftRight,
            semanticLabel: NovaStrings.lookup(english, 'playerChangeSource'),
            label: wide ? (NovaStrings.lookup(english, 'message38')) : null,
            scale: scale,
            onTap: onOpenStreams,
          ),
          _RaillessControl(
            icon: LucideIcons.captions,
            semanticLabel: NovaStrings.lookup(english, 'message7'),
            label: wide ? (NovaStrings.lookup(english, 'message39')) : null,
            scale: scale,
            onTap: onOpenSubtitles,
          ),
          _RaillessControl(
            icon: LucideIcons.audioLines,
            semanticLabel: NovaStrings.lookup(english, 'message87'),
            label: wide ? (NovaStrings.lookup(english, 'message40')) : null,
            scale: scale,
            onTap: onOpenAudio,
          ),
          if (canNext)
            _RaillessControl(
              icon: LucideIcons.skipForward,
              semanticLabel: NovaStrings.lookup(english, 'message23'),
              scale: scale,
              iconSize: 28,
              onTap: onNext,
            ),
        ],
      );
}

/// Compact persistent volume bar (user mandate: "volume icon AND bar").
class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.value,
    required this.width,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value; // 0..1
  final double width;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            padding: EdgeInsets.zero,
          ),
          child: Slider.adaptive(
            value: value.clamp(0.0, 1.0),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            activeColor: NovaColors.white,
            inactiveColor: NovaColors.white.withValues(alpha: .24),
          ),
        ),
      );
}

/// Circular-arrow skip button with the configurable seconds rendered inside
/// (replaces the fixed replay_10/forward_10 glyphs).
class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.forward,
    required this.seconds,
    required this.size,
    required this.onTap,
  });

  final bool forward;
  final int seconds;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: NovaStrings.lookup(
          Localizations.localeOf(context).languageCode != 'ar',
          forward ? 'forwardSeconds' : 'rewindSeconds',
          {'p0': seconds},
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  forward ? LucideIcons.rotateCw : LucideIcons.rotateCcw,
                  color: NovaColors.white,
                  size: size * .62,
                  shadows: PlayerPalette.iconShadow,
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    forward ? size * .16 : 0,
                    size * .08,
                    forward ? 0 : size * .16,
                    0,
                  ),
                  child: Text(
                    '$seconds',
                    style: const TextStyle(
                      color: NovaColors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
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

class _RaillessControl extends StatelessWidget {
  const _RaillessControl({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    required this.scale,
    this.iconSize = 25,
    this.label,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double scale;
  final double iconSize;

  /// Small caption under the icon — tablet only (spec §0-ب).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final iconWidget = Icon(
      icon,
      color:
          enabled ? NovaColors.white : NovaColors.white.withValues(alpha: .30),
      size: iconSize * scale,
      shadows: enabled ? PlayerPalette.iconShadow : null,
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1.0 : .55,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: label == null
              ? SizedBox(
                  width: 48 * scale,
                  height: 48 * scale,
                  child: Center(child: iconWidget),
                )
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 48 * scale,
                        height: 48 * scale,
                        child: Center(child: iconWidget),
                      ),
                      Text(
                        label!,
                        style: TextStyle(
                          color: enabled
                              ? NovaColors.white.withValues(alpha: .70)
                              : NovaColors.white.withValues(alpha: .24),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 250 ||
              MediaQuery.textScalerOf(context).scale(16) > 22;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                PlayerPrimaryAction(label: primaryLabel, onPressed: onPrimary),
                const SizedBox(height: 8),
                PlayerSecondaryAction(
                    label: secondaryLabel, onPressed: onSecondary),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: PlayerPrimaryAction(
                    label: primaryLabel, onPressed: onPrimary),
              ),
              const SizedBox(width: 8),
              PlayerSecondaryAction(
                  label: secondaryLabel, onPressed: onSecondary),
            ],
          );
        },
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
          backgroundColor: HorseTheme.gold,
          foregroundColor: NovaColors.white,
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
