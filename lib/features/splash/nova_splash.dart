import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/nova_theme.dart';
import '../../l10n/nova_strings.dart';

/// One-shot NOVA launch artwork based on the supplied 1080 x 1920 reference.
///
/// The animation intentionally owns no application readiness state. Startup
/// work can run in parallel, and [onFinished] simply releases the launch gate
/// once the visible 3.4 second sequence is complete. Reduced motion displays
/// the final lockup immediately.
class NovaSplash extends StatefulWidget {
  const NovaSplash({
    super.key,
    required this.footer,
    this.onFinished,
  });

  static const animationDuration = Duration(milliseconds: 3400);

  final Widget footer;
  final VoidCallback? onFinished;

  @override
  State<NovaSplash> createState() => _NovaSplashState();
}

class _NovaSplashState extends State<NovaSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: NovaSplash.animationDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _finish();
    } else if (!_started && !_finished) {
      _started = true;
      _controller.forward();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: background,
      body: ColoredBox(
        key: const ValueKey('nova-splash-background'),
        color: background,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compactHeight = constraints.maxHeight < 420;
              final horizontalPadding = compactHeight ? 24.0 : 32.0;
              final footerGap = compactHeight ? 12.0 : 28.0;
              final topPadding = compactHeight ? 12.0 : 24.0;
              final bottomPadding = compactHeight ? 12.0 : 28.0;
              final contentHeight =
                  (constraints.maxHeight - topPadding - bottomPadding)
                      .clamp(0.0, double.infinity);
              final logoAreaHeight = compactHeight
                  ? (contentHeight * .52).clamp(88.0, 196.0)
                  : (contentHeight * .7).clamp(140.0, 560.0);
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    child: compactHeight
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                height: logoAreaHeight,
                                child: Center(
                                  child: _AnimatedNovaLockup(
                                    animation: _controller,
                                    dark: dark,
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    EdgeInsetsDirectional.only(top: footerGap),
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 420),
                                  child: widget.footer,
                                ),
                              ),
                            ],
                          )
                        : SizedBox(
                            height: contentHeight,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _AnimatedNovaLockup(
                                  animation: _controller,
                                  dark: dark,
                                ),
                                Align(
                                  alignment: AlignmentDirectional.bottomCenter,
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 420),
                                    child: widget.footer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnimatedNovaLockup extends StatelessWidget {
  const _AnimatedNovaLockup({required this.animation, required this.dark});

  final Animation<double> animation;
  final bool dark;

  static const _aspectRatio = 820 / 230;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, 520.0);
        final height =
            (width / _aspectRatio).clamp(0.0, constraints.maxHeight * .72);
        final fittedWidth = height * _aspectRatio;

        return SizedBox(
          key: const ValueKey('nova-splash-lockup'),
          width: fittedWidth,
          height: height,
          child: Semantics(
            label: NovaStrings.of(context).text('appName'),
            image: true,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final seconds = animation.value *
                      NovaSplash.animationDuration.inMilliseconds /
                      1000;
                  final appear = Curves.easeOutCubic.transform(
                    _segment(seconds, 0, .7),
                  );
                  final slide = Curves.easeInOutCubic.transform(
                    _segment(seconds, 1, 1.8),
                  );
                  final glowFade = _segment(seconds, 2.6, 3.4);
                  final symbolScale = .82 + .18 * appear;
                  final symbolSize = height;
                  final symbolStart = (fittedWidth - symbolSize) / 2;
                  final symbolLeft = ui.lerpDouble(symbolStart, 0, slide)!;
                  final wordmarkLeft = height * (266.5 / 230);
                  final wordmarkWidth = height * (553.5 / 230);
                  final wordmarkHeight = height * (124.2 / 230);
                  final glowDiameter = fittedWidth * 1.5;
                  final glowStrongAlpha = dark ? .55 : .24;
                  final glowSoftAlpha = dark ? .16 : .08;

                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: (fittedWidth - glowDiameter) / 2,
                        top: (height - glowDiameter) / 2,
                        width: glowDiameter,
                        height: glowDiameter,
                        child: IgnorePointer(
                          child: Opacity(
                            key: const ValueKey('nova-splash-glow'),
                            opacity: appear * (.95 - .45 * glowFade),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    NovaColors.red
                                        .withValues(alpha: glowStrongAlpha),
                                    NovaColors.red
                                        .withValues(alpha: glowSoftAlpha),
                                    NovaColors.red.withValues(alpha: 0),
                                  ],
                                  stops: const [0, .5, 1],
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: wordmarkLeft,
                        top: (height - wordmarkHeight) / 2,
                        width: wordmarkWidth,
                        height: wordmarkHeight,
                        child: CustomPaint(
                          key: const ValueKey('nova-splash-wordmark'),
                          painter: _NovaWordmarkPainter(
                            time: seconds,
                            color: dark ? NovaColors.white : NovaColors.ink,
                          ),
                        ),
                      ),
                      Positioned(
                        key: const ValueKey('nova-splash-symbol-position'),
                        left: symbolLeft,
                        width: symbolSize,
                        height: symbolSize,
                        child: Center(
                          child: Opacity(
                            key: const ValueKey('nova-splash-symbol'),
                            opacity: appear,
                            child: Transform.scale(
                              scale: symbolScale,
                              child: SvgPicture.asset(
                                'assets/brand/svg/icon_red.svg',
                                fit: BoxFit.contain,
                                matchTextDirection: false,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

double _segment(double value, double start, double end) =>
    ((value - start) / (end - start)).clamp(0.0, 1.0);

class _NovaWordmarkPainter extends CustomPainter {
  const _NovaWordmarkPainter({required this.time, required this.color});

  final double time;
  final Color color;

  static const _sourceSize = Size(2484.6, 557.5);
  static const _starts = [1.65, 1.95, 2.3, 2.6];
  static const _durations = [.45, .5, .45, .45];

  static final List<Path> _letters = [
    Path()
      ..moveTo(69.7, 488)
      ..lineTo(69.7, 284.4)
      ..arcToPoint(
        const Offset(499.1, 284.4),
        radius: const Radius.elliptical(214.7, 214.7),
        clockwise: true,
      )
      ..lineTo(499.1, 488),
    Path()
      ..moveTo(970.5, 69.6)
      ..arcToPoint(
        const Offset(970.5, 488),
        radius: const Radius.elliptical(242.6, 209.2),
        largeArc: true,
        clockwise: true,
      )
      ..arcToPoint(
        const Offset(970.5, 69.6),
        radius: const Radius.elliptical(242.6, 209.2),
        largeArc: true,
        clockwise: true,
      ),
    Path()
      ..moveTo(1371.2, 69.7)
      ..lineTo(1613.8, 488)
      ..lineTo(1856.4, 69.7),
    Path()
      ..moveTo(1929.5, 488)
      ..lineTo(2172.1, 69.7)
      ..lineTo(2414.7, 488),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
        size.width / _sourceSize.width, size.height / _sourceSize.height);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 139.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var index = 0; index < _letters.length; index++) {
      final progress = Curves.easeInOutCubic.transform(
        _segment(
          time,
          _starts[index],
          _starts[index] + _durations[index],
        ),
      );
      if (progress <= 0) continue;
      for (final metric in _letters[index].computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NovaWordmarkPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.color != color;
}
