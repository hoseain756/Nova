import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/engine/media3_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('nova/player/media3');
  const events = MethodChannel('nova/player/media3/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const state = <String, dynamic>{
    'id': 7,
    'event': 'state',
    'ready': true,
    'playing': false,
    'positionMs': 12000,
    'durationMs': 120000,
    'bufferedMs': 20000,
    'seekable': true,
    'rate': 1.0,
    'volume': 1.0,
    'aspect': 1.777,
  };
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (call.method == 'create') return {'id': 7, 'textureId': 8};
      if (call.method == 'close') return null;
      return state;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
  });
  Future<void> emit(Map<String, dynamic> value) async {
    final done = Completer<void>();
    messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(value),
        (_) => done.complete());
    await done.future;
    await Future<void>.delayed(Duration.zero);
  }

  test('paused open forwards headers and accepts only its native ID', () async {
    final engine = Media3Engine();
    await engine
        .open('https://example.test/video', httpHeaders: {'X-Test': 'value'});
    expect(engine.ready, isTrue);
    expect(engine.playing, isFalse);
    expect(engine.position.inMilliseconds, 12000);
    expect(calls.last.arguments['headers'], {'X-Test': 'value'});
    await emit({...state, 'id': 90, 'positionMs': 99000});
    expect(engine.position.inMilliseconds, 12000);
    await emit({...state, 'positionMs': 15000});
    expect(engine.position.inMilliseconds, 15000);
    await engine.close();
    await engine.close();
    expect(calls.where((call) => call.method == 'close').length, 1);
  });

  test(
      'close during native allocation retires returned ID without opening media',
      () async {
    final allocation = Completer<Map<String, int>>();
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (call.method == 'create') return allocation.future;
      return null;
    });
    final engine = Media3Engine();
    final opening = engine.open('https://example.test/video');
    final closing = engine.close();
    allocation.complete({'id': 7, 'textureId': 8});
    await Future.wait([opening, closing]);
    expect(calls.map((call) => call.method), ['create', 'close']);
  });

  test('decoder errors retain typed fallback evidence; HTTP errors do not',
      () async {
    final engine = Media3Engine();
    await engine.open('https://example.test/video');
    await emit({...state, 'errorCode': 4001});
    expect(engine.failed, isTrue);
    expect(engine.canFallback, isTrue);
    await emit({...state, 'errorCode': 2004});
    expect(engine.canFallback, isFalse);
    await engine.close();
  });
}
