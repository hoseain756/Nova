import 'package:flutter/services.dart';

/// The launcher icon is device-owned OS state, not a synced app preference.
class AppIconSelection {
  const AppIconSelection({
    required this.supported,
    required this.selected,
    required this.ids,
  });

  final bool supported;
  final String selected;
  final List<String> ids;

  factory AppIconSelection.fromMap(Map<String, dynamic>? value) {
    const known = {'classic', 'clear', 'dark'};
    final ids = (value?['ids'] as List?)
            ?.whereType<String>()
            .where(known.contains)
            .toList(growable: false) ??
        const <String>[];
    final selected = value?['selected'] as String?;
    return AppIconSelection(
      supported: value?['supported'] == true && ids.isNotEmpty,
      selected: known.contains(selected) ? selected! : 'classic',
      ids: ids,
    );
  }
}

abstract class AppIconController {
  Future<AppIconSelection> current();
  Future<AppIconSelection> select(String id);
}

class NativeAppIconController implements AppIconController {
  const NativeAppIconController();

  static const _channel = MethodChannel('nova/app_icon');

  @override
  Future<AppIconSelection> current() async {
    try {
      return AppIconSelection.fromMap(
          await _channel.invokeMapMethod<String, dynamic>('get'));
    } on MissingPluginException {
      return const AppIconSelection(
          supported: false, selected: 'classic', ids: []);
    }
  }

  @override
  Future<AppIconSelection> select(String id) async => AppIconSelection.fromMap(
      await _channel.invokeMapMethod<String, dynamic>('set', {'id': id}));
}
