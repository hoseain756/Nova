import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/platform/app_icon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nova/app_icon');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('native state is authoritative and set reports the applied icon',
      () async {
    var selected = 'dark';
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'set') selected = call.arguments['id'] as String;
      return {
        'supported': true,
        'selected': selected,
        'ids': ['classic', 'clear', 'dark']
      };
    });
    const controller = NativeAppIconController();
    expect((await controller.current()).selected, 'dark');
    expect((await controller.select('clear')).selected, 'clear');
    expect(calls, ['get', 'set']);
  });

  test('unsupported host and unknown native values remain safe', () async {
    const controller = NativeAppIconController();
    expect((await controller.current()).supported, isFalse);
    final parsed = AppIconSelection.fromMap({
      'supported': true,
      'selected': 'unexpected',
      'ids': ['unexpected', 'clear']
    });
    expect(parsed.selected, 'classic');
    expect(parsed.ids, ['clear']);
  });
}
