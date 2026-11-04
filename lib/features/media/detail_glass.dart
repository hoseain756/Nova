/// Liquid-glass primitives shared by the detail page's floating controls:
/// the season dropdown pill, the sort chip, the view toggle and the
/// expandable action menu.
///
/// The pill surface wears the OLD detail back-pill recipe (user mandate,
/// Task 120: the pre-118 glow background for the search button, the
/// navigation bar and the episode toolbar): blur backdrop over a black/55
/// fill with a 1px white/15 ring and a soft black drop shadow — mirroring
/// `shared/widgets/glass_navigation.dart` and `features/shell/glass_dock.dart`
/// which swapped the same day. Only the shape changes (rounded pill instead
/// of circle).
///
/// [showGlassMenu] is the Flutter idiom replacing the web's Radix
/// DropdownMenu portal: a root overlay with an outside-tap barrier, Escape
/// handling and viewport-clamped positioning under the anchor.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/horse_theme.dart';

/// The glass-dock recipe as a pill/rounded-rect surface. Children paint on
/// top of the glass fill; the caller supplies ink/labels.
///
/// Task 136 (perf): the LIVE BackdropFilter is retired — these pills sit
/// over the detail/sources pages' scrolling lists, so the blur recomputed on
/// every scroll frame. Static black/72 fill under the same ring + shadow.
class GlassPillSurface extends StatelessWidget {
  const GlassPillSurface({
    super.key,
    required this.child,
    this.borderRadius = 999,
    this.blurSigma,
  });

  final Widget child;
  final double borderRadius;

  /// Legacy blur knob — retired by Task 136 (the live BackdropFilter was
  /// removed); kept so existing call sites compile untouched.
  final double? blurSigma;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(borderRadius > 20 ? 16 : borderRadius),
          side: BorderSide(color: scheme.outlineVariant)),
      child: child,
    );
  }
}

/// Menu content: receives the panel's `close` function — call it with the
/// value to complete [showGlassMenu] with (null = dismissed).
typedef GlassMenuBuilder<T> = Widget Function(void Function(T? value) close);

/// Opens a glass dropdown panel anchored under [anchor] (a rect in global
/// coordinates). Closes on outside tap and Escape; completes with the value
/// the menu content passed to `close` (null when dismissed).
Future<T?> showGlassMenu<T>({
  required BuildContext context,
  required Rect anchor,
  required GlassMenuBuilder<T> builder,
  double width = 240,
  double gap = 8,
  double? maxHeight,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<T?>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (menuContext) => _GlassMenuRoute<T>(
      anchor: anchor,
      width: width,
      gap: gap,
      maxHeight: maxHeight ?? MediaQuery.sizeOf(menuContext).height * 0.6,
      builder: builder,
      onClose: (value) {
        if (!completer.isCompleted) completer.complete(value);
        entry.remove();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _GlassMenuRoute<T> extends StatefulWidget {
  const _GlassMenuRoute({
    required this.anchor,
    required this.width,
    required this.gap,
    required this.maxHeight,
    required this.builder,
    required this.onClose,
  });

  final Rect anchor;
  final double width;
  final double gap;
  final double maxHeight;
  final GlassMenuBuilder<T> builder;
  final void Function(T? value) onClose;

  @override
  State<_GlassMenuRoute<T>> createState() => _GlassMenuRouteState<T>();
}

class _GlassMenuRouteState<T> extends State<_GlassMenuRoute<T>> {
  late final FocusNode _escapeNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Grab focus so the keyboard Escape reaches the panel's handler.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _escapeNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _escapeNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose(null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final safe = EdgeInsets.fromLTRB(
      math.max(media.viewPadding.left, media.viewInsets.left) + 12,
      math.max(media.viewPadding.top, media.viewInsets.top) + 12,
      math.max(media.viewPadding.right, media.viewInsets.right) + 12,
      math.max(media.viewPadding.bottom, media.viewInsets.bottom) + 12,
    );
    return Stack(
      children: [
        // Outside tap closes (barrier over the whole app below the panel).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onClose(null),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _GlassMenuLayout(
                anchor: widget.anchor,
                width: widget.width,
                gap: widget.gap,
                maxHeight: widget.maxHeight,
                safe: safe,
                rtl: rtl),
            child: Focus(
              focusNode: _escapeNode,
              onKeyEvent: _onKey,
              child: _GlassMenuPanel(
                maxHeight: widget.maxHeight,
                child: widget.builder(widget.onClose),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Constrains the actual panel to the usable viewport, then positions it
/// using its measured height so a short menu does not float above its anchor.
class _GlassMenuLayout extends SingleChildLayoutDelegate {
  _GlassMenuLayout(
      {required this.anchor,
      required this.width,
      required this.gap,
      required this.maxHeight,
      required this.safe,
      required this.rtl});
  final Rect anchor;
  final double width;
  final double gap;
  final double maxHeight;
  final EdgeInsets safe;
  final bool rtl;

  Rect _usable(Size size) => Rect.fromLTRB(
      safe.left.clamp(0, size.width),
      safe.top.clamp(0, size.height),
      (size.width - safe.right)
          .clamp(safe.left.clamp(0, size.width), size.width),
      (size.height - safe.bottom)
          .clamp(safe.top.clamp(0, size.height), size.height));

  bool _above(Rect area) {
    final below = math.max(0.0, area.bottom - (anchor.bottom + gap));
    final above = math.max(0.0, anchor.top - gap - area.top);
    return below < maxHeight && above > below;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final area = _usable(constraints.biggest);
    final space = _above(area)
        ? math.max(0.0, anchor.top - gap - area.top)
        : math.max(0.0, area.bottom - anchor.bottom - gap);
    final height = math.min(maxHeight, space > 0 ? space : area.height);
    return BoxConstraints.tightFor(width: math.min(width, area.width))
        .copyWith(maxHeight: height);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final area = _usable(size);
    final left = (rtl ? anchor.right - childSize.width : anchor.left)
        .clamp(area.left, math.max(area.left, area.right - childSize.width));
    final top = (_above(area)
            ? anchor.top - gap - childSize.height
            : anchor.bottom + gap)
        .clamp(area.top, math.max(area.top, area.bottom - childSize.height));
    return Offset(left.toDouble(), top.toDouble());
  }

  @override
  bool shouldRelayout(covariant _GlassMenuLayout old) =>
      anchor != old.anchor ||
      width != old.width ||
      gap != old.gap ||
      maxHeight != old.maxHeight ||
      safe != old.safe ||
      rtl != old.rtl;
}

class _GlassMenuPanel extends StatelessWidget {
  const _GlassMenuPanel({required this.maxHeight, required this.child});

  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 8,
      shadowColor: scheme.shadow.withValues(alpha: .20),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(8), child: child)),
    );
  }
}

/// One menu row: 44dp min height, rounded-xl hover/highlight, 14px w500 ink.
class GlassMenuItem extends StatelessWidget {
  const GlassMenuItem({
    super.key,
    required this.leading,
    required this.label,
    required this.onTap,
  });

  final Widget leading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: NovaTheme.of(context).ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
