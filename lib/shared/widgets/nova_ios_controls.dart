import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// System UIKit controls render with Liquid Glass on iOS 26 and retain the
/// appropriate native appearance on older supported iOS versions.
abstract final class NovaIosControls {
  static const MethodChannel _channel = MethodChannel('nova/ios_controls');
  static Future<bool>? _nativeReady;
  @visibleForTesting
  static bool? debugAvailableOverride;

  static bool get available =>
      debugAvailableOverride ?? (!kIsWeb && Platform.isIOS);

  static Future<bool> get nativeReady => _nativeReady ??= _channel
      .invokeMethod<bool>('isAvailable')
      .then((value) => value == true)
      .catchError((Object _) => false);

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    bool destructive = false,
    bool barrierDismissible = true,
  }) async {
    if (available) {
      try {
        final selected = await _channel.invokeMethod<int>('presentAlert', {
          'title': title,
          'message': message,
          'dark': Theme.of(context).brightness == Brightness.dark,
          'rtl': Directionality.of(context) == TextDirection.rtl,
          'actions': [
            {'label': cancelLabel, 'style': 'cancel'},
            {
              'label': confirmLabel,
              'style': destructive ? 'destructive' : 'default'
            },
          ],
        });
        return selected == null ? null : selected == 1;
      } on PlatformException {
        // Keep the action available when the scene is temporarily unavailable.
      } on MissingPluginException {
        // Older installed native hosts can still show the Flutter dialog.
      }
    }
    if (!context.mounted) return null;
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: message.isEmpty ? null : Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(cancelLabel)),
          FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(confirmLabel)),
        ],
      ),
    );
  }

  static Future<int?> choose(
    BuildContext context, {
    required String title,
    required List<String> labels,
    required String cancelLabel,
    Rect? sourceRect,
  }) async {
    if (labels.isEmpty) return null;
    if (available) {
      try {
        final selected = await _channel.invokeMethod<int>('presentChoices', {
          'title': title,
          'dark': Theme.of(context).brightness == Brightness.dark,
          'rtl': Directionality.of(context) == TextDirection.rtl,
          'sourceRect': sourceRect == null || sourceRect.isEmpty
              ? null
              : [
                  sourceRect.left,
                  sourceRect.top,
                  sourceRect.width,
                  sourceRect.height,
                ],
          'actions': [
            for (final label in labels) {'label': label},
            {'label': cancelLabel, 'style': 'cancel'},
          ],
        });
        return selected == null || selected < 0 || selected >= labels.length
            ? null
            : selected;
      } on PlatformException {
        // A Flutter sheet remains usable when native presentation is busy.
      } on MissingPluginException {
        // Supports older native hosts during an app update.
      }
    }
    if (!context.mounted) return null;
    return showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(title, style: Theme.of(sheet).textTheme.titleLarge),
            ),
            for (var i = 0; i < labels.length; i++)
              ListTile(
                title: Text(labels[i]),
                onTap: () => Navigator.pop(sheet, i),
              ),
          ],
        ),
      ),
    );
  }

  static Rect sourceRect(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

class NovaSwitch extends StatefulWidget {
  const NovaSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.activeThumbColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final Color? activeThumbColor;

  @override
  State<NovaSwitch> createState() => _NovaSwitchState();
}

class _NovaSwitchState extends State<NovaSwitch> {
  MethodChannel? _channel;

  Map<String, Object?> get _state => {
        'value': widget.value,
        'enabled': widget.onChanged != null,
        'label': widget.label,
        'dark': Theme.of(context).brightness == Brightness.dark,
        'rtl': Directionality.of(context) == TextDirection.rtl,
      };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _channel?.invokeMethod<void>('update', _state);
  }

  @override
  void didUpdateWidget(NovaSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.onChanged != widget.onChanged ||
        oldWidget.label != widget.label) {
      _channel?.invokeMethod<void>('update', _state);
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!NovaIosControls.available) {
      return Switch.adaptive(
        value: widget.value,
        onChanged: widget.onChanged,
        activeThumbColor: widget.activeThumbColor,
      );
    }
    return FutureBuilder<bool>(
      future: NovaIosControls.nativeReady,
      builder: (context, snapshot) => snapshot.data == true
          ? _nativeView()
          : Switch.adaptive(
              value: widget.value,
              onChanged: widget.onChanged,
              activeThumbColor: widget.activeThumbColor,
            ),
    );
  }

  Widget _nativeView() => SizedBox(
        width: 59,
        height: 48,
        child: UiKitView(
          viewType: 'nova/ios_switch',
          creationParamsCodec: const StandardMessageCodec(),
          creationParams: _state,
          onPlatformViewCreated: (id) {
            final channel = MethodChannel('nova/ios_switch/$id');
            _channel = channel;
            channel.setMethodCallHandler((call) async {
              if (call.method == 'changed' && mounted) {
                widget.onChanged?.call(call.arguments == true);
              }
            });
          },
        ),
      );
}

class NovaSwitchListTile extends StatelessWidget {
  const NovaSwitchListTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.activeThumbColor,
  });

  final Widget title;
  final Widget? subtitle, secondary;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;
  final Color? activeThumbColor;

  @override
  Widget build(BuildContext context) {
    if (!NovaIosControls.available) {
      return SwitchListTile.adaptive(
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        value: value,
        onChanged: onChanged,
        contentPadding: contentPadding,
        activeThumbColor: activeThumbColor,
      );
    }
    return ListTile(
      title: title,
      subtitle: subtitle,
      leading: secondary,
      contentPadding: contentPadding,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: NovaSwitch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: activeThumbColor,
        label: title is Text ? (title as Text).data : null,
      ),
    );
  }
}

class NovaSelectionButton<T> extends StatelessWidget {
  const NovaSelectionButton({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.title,
    this.expanded = false,
    this.isDense = false,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? title;
  final bool expanded, isDense;

  @override
  Widget build(BuildContext context) {
    final labels = [for (final item in items) _menuLabel(item.child)];
    if (!NovaIosControls.available || labels.any((label) => label == null)) {
      return DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: expanded,
        isDense: isDense,
      );
    }
    final selected = items.indexWhere((item) => item.value == value);
    return Builder(builder: (anchor) {
      return InkWell(
        onTap: onChanged == null
            ? null
            : () async {
                final choice = await NovaIosControls.choose(
                  anchor,
                  title: title ?? '',
                  labels: labels.cast<String>(),
                  cancelLabel:
                      MaterialLocalizations.of(anchor).cancelButtonLabel,
                  sourceRect: NovaIosControls.sourceRect(anchor),
                );
                if (choice != null && anchor.mounted) {
                  onChanged!(items[choice].value);
                }
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (selected >= 0)
                  if (expanded)
                    Expanded(child: items[selected].child)
                  else
                    items[selected].child,
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down, size: 20),
              ]),
        ),
      );
    });
  }
}

class NovaDropdownFormField<T> extends StatelessWidget {
  const NovaDropdownFormField({
    super.key,
    required this.initialValue,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.isExpanded = false,
  });

  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final labels = [for (final item in items) _menuLabel(item.child)];
    if (!NovaIosControls.available || labels.any((label) => label == null)) {
      return DropdownButtonFormField<T>(
        initialValue: initialValue,
        items: items,
        onChanged: onChanged,
        decoration: decoration,
        isExpanded: isExpanded,
      );
    }
    return FormField<T>(
      initialValue: initialValue,
      builder: (field) {
        final selected = items.indexWhere((item) => item.value == field.value);
        return Builder(builder: (anchor) {
          return InkWell(
            onTap: onChanged == null
                ? null
                : () async {
                    final choice = await NovaIosControls.choose(
                      anchor,
                      title: decoration.labelText ?? '',
                      labels: labels.cast<String>(),
                      cancelLabel:
                          MaterialLocalizations.of(anchor).cancelButtonLabel,
                      sourceRect: NovaIosControls.sourceRect(anchor),
                    );
                    if (choice == null || !field.mounted) return;
                    field.didChange(items[choice].value);
                    onChanged!(items[choice].value);
                  },
            child: InputDecorator(
              decoration: decoration.copyWith(errorText: field.errorText),
              isEmpty: selected < 0,
              child: Row(children: [
                if (selected >= 0)
                  Expanded(child: items[selected].child)
                else
                  const Spacer(),
                const Icon(Icons.keyboard_arrow_down, size: 20),
              ]),
            ),
          );
        });
      },
    );
  }
}

class NovaPopupMenuButton<T> extends StatelessWidget {
  const NovaPopupMenuButton({
    super.key,
    required this.itemBuilder,
    required this.onSelected,
    this.icon,
    this.child,
    this.tooltip,
    this.enabled = true,
    this.constraints,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final ValueChanged<T> onSelected;
  final Widget? icon, child;
  final String? tooltip;
  final bool enabled;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final entries = itemBuilder(context);
    final choices = entries.whereType<PopupMenuItem<T>>().toList();
    final labels = [for (final entry in choices) _menuLabel(entry.child)];
    if (!NovaIosControls.available ||
        entries.length != choices.length ||
        labels.any((label) => label == null)) {
      return PopupMenuButton<T>(
        itemBuilder: itemBuilder,
        onSelected: onSelected,
        icon: icon,
        tooltip: tooltip,
        enabled: enabled,
        constraints: constraints,
        child: child,
      );
    }
    return Builder(builder: (anchor) {
      final open = enabled
          ? () async {
              final selected = await NovaIosControls.choose(
                anchor,
                title: tooltip ?? '',
                labels: labels.cast<String>(),
                cancelLabel: MaterialLocalizations.of(anchor).cancelButtonLabel,
                sourceRect: NovaIosControls.sourceRect(anchor),
              );
              if (selected != null && context.mounted) {
                final value = choices[selected].value;
                if (value != null) onSelected(value);
              }
            }
          : null;
      if (child != null) return InkWell(onTap: open, child: child);
      return IconButton(
        tooltip: tooltip,
        onPressed: open,
        icon: icon ?? const Icon(Icons.more_vert),
      );
    });
  }
}

String? _menuLabel(Widget? child) {
  if (child is Text) return child.data;
  if (child is ListTile && child.title is Text) {
    return (child.title as Text).data;
  }
  return null;
}
