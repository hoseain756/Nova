import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'nova_ios_controls.dart';

/// Uses iOS dialog transitions for Flutter-owned forms and tool panels.
/// Plain confirmations and choices use UIKit through [NovaIosControls].
Future<T?> showNovaDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  AnimationStyle? animationStyle,
}) {
  if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoDialog<T>(
      context: context,
      builder: (dialogContext) => Material(
        type: MaterialType.transparency,
        child: builder(dialogContext),
      ),
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      anchorPoint: anchorPoint,
    );
  }
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    animationStyle: animationStyle,
  );
}

/// Keeps Flutter form state while UIKit supplies the iOS 26 glass material.
/// UIKit is presentation-only; actions and validation stay in Flutter.
class NovaGlassDialog extends StatelessWidget {
  const NovaGlassDialog({
    super.key,
    this.icon,
    this.title,
    this.content,
    this.actions,
    this.scrollable = false,
    this.constraints,
    this.backgroundColor,
    this.contentPadding,
  });

  final Widget? icon, title, content;
  final List<Widget>? actions;
  final bool scrollable;
  final BoxConstraints? constraints;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || Theme.of(context).platform != TargetPlatform.iOS) {
      return AlertDialog(
        icon: icon,
        title: title,
        content: content,
        actions: actions,
        scrollable: scrollable,
        constraints: constraints,
        backgroundColor: backgroundColor,
        contentPadding: contentPadding,
      );
    }
    final theme = Theme.of(context);
    final actionButtons = actions ?? const <Widget>[];
    final maxWidth =
        constraints?.maxWidth.isFinite == true ? constraints!.maxWidth : 520.0;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * .86,
        ),
        child: NovaIosGlassSurface(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (icon != null) ...[
                  Center(child: icon!),
                  const SizedBox(height: 12),
                ],
                if (title != null) ...[
                  DefaultTextStyle(
                    style: theme.textTheme.titleLarge!,
                    child: title!,
                  ),
                  if (content != null) const SizedBox(height: 12),
                ],
                if (content != null)
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      padding: contentPadding ?? EdgeInsets.zero,
                      child: content!,
                    ),
                  ),
                if (actionButtons.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in actionButtons) _iosAction(action)
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iosAction(Widget action) {
    if (action is FilledButton) {
      return CupertinoButton.filled(
          onPressed: action.onPressed,
          child: action.child ?? const SizedBox.shrink());
    }
    if (action is ButtonStyleButton) {
      return CupertinoButton(
          onPressed: action.onPressed,
          child: action.child ?? const SizedBox.shrink());
    }
    return action;
  }
}

class NovaIosGlassSurface extends StatelessWidget {
  const NovaIosGlassSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(children: [
          Positioned.fill(
              child: _IosGlassDialogBackground(theme: Theme.of(context))),
          child,
        ]),
      );
}

class _IosGlassDialogBackground extends StatelessWidget {
  const _IosGlassDialogBackground({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (!NovaIosControls.available) return _fallback();
    return FutureBuilder<bool>(
      future: NovaIosControls.nativeReady,
      builder: (context, ready) => ready.data == true
          ? UiKitView(
              viewType: 'nova/ios_glass_dialog',
              creationParamsCodec: const StandardMessageCodec(),
              creationParams: {
                'dark': theme.brightness == Brightness.dark,
                'rtl': Directionality.of(context) == TextDirection.rtl,
              },
              hitTestBehavior: PlatformViewHitTestBehavior.transparent,
            )
          : _fallback(),
    );
  }

  Widget _fallback() =>
      ColoredBox(color: theme.colorScheme.surface.withValues(alpha: .96));
}
