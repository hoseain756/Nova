import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/engine/playback_engine.dart';
import 'package:nova_mobile/features/player/session/playback_progress_binding.dart';

void main() {
  late Duration now;
  late List<({Duration due, VoidCallback run, bool Function() cancelled})>
      tasks;
  late PlaybackProgressBinding binding;
  late _Engine engine;

  setUp(() {
    now = Duration.zero;
    tasks = [];
    binding = PlaybackProgressBinding(
      now: () => now,
      schedule: (delay, run) {
        var cancelled = false;
        tasks.add((due: now + delay, run: run, cancelled: () => cancelled));
        return () => cancelled = true;
      },
    );
    engine = _Engine();
  });

  tearDown(() {
    binding.dispose();
    engine.dispose();
  });

  test('bind seeds exact values without owning native lifecycle', () {
    engine.position = const Duration(microseconds: 123456);
    binding.bind(engine);
    expect(binding.value!.position, engine.position);
    expect(binding.value!.duration, engine.duration);
    expect(engine.hasProgressListeners, isTrue);
    expect(binding.owns(engine, binding.interactionIdentity), isTrue);
    binding.unbind();
    expect(engine.hasProgressListeners, isFalse);
    expect(engine.disposed, isFalse);
    expect(binding.value, isNull);
  });

  test('sampled display trails exact state and publishes latest once', () {
    binding.bind(engine);
    engine.position = const Duration(milliseconds: 20);
    engine.notifyListeners();
    engine.position = const Duration(milliseconds: 80);
    engine.bufferedEnd = const Duration(seconds: 8);
    engine.notifyListeners();
    expect(binding.value!.position, Duration.zero);
    expect(engine.position.inMilliseconds, 80);
    expect(tasks, hasLength(1));
    now = const Duration(milliseconds: 100);
    tasks.single.run();
    expect(binding.value!.position.inMilliseconds, 80);
    expect(binding.value!.bufferedEnd.inSeconds, 8);
  });

  test('source replacement rejects old token, event and late callback', () {
    binding.bind(engine);
    final token = binding.interactionIdentity;
    engine.position = const Duration(seconds: 5);
    engine.notifyListeners();
    final oldTask = tasks.single;
    final next = _Engine()..position = const Duration(seconds: 40);
    binding.bind(next);
    expect(binding.owns(engine, token), isFalse);
    expect(engine.hasProgressListeners, isFalse);
    expect(oldTask.cancelled(), isTrue);
    now = const Duration(seconds: 1);
    oldTask.run(); // A cancelled native/event-loop callback arriving late.
    engine.notifyListeners();
    expect(binding.value!.position.inSeconds, 40);
    binding.unbind();
    next.dispose();
  });

  test('rebinding same engine creates fresh interaction identity', () {
    binding.bind(engine);
    final token = binding.interactionIdentity;
    final generation = binding.value!.sourceGeneration;
    binding.bind(engine);
    expect(binding.owns(engine, token), isFalse);
    expect(binding.value!.sourceGeneration, greaterThan(generation));
    expect(binding.owns(engine, binding.interactionIdentity), isTrue);
  });

  test('unbind clears projection immediately and cancels pending delivery', () {
    binding.bind(engine);
    engine.position = const Duration(seconds: 1);
    engine.notifyListeners();
    binding.unbind();
    expect(binding.value, isNull);
    expect(binding.interactionIdentity, isNull);
    expect(tasks.single.cancelled(), isTrue);
    now = const Duration(seconds: 2);
    tasks.single.run();
    expect(binding.value, isNull);
  });

  test('dispose detaches and suppresses late delivery and later binds', () {
    binding.bind(engine);
    final token = binding.interactionIdentity;
    engine.position = const Duration(seconds: 1);
    engine.notifyListeners();
    binding.dispose();
    now = const Duration(seconds: 2);
    tasks.single.run();
    binding.bind(engine);
    expect(binding.owns(engine, token), isFalse);
    expect(engine.hasProgressListeners, isFalse);
    expect(engine.disposed, isFalse);
  });

  test('duration and buffer changes publish without a position tick', () {
    binding.bind(engine);
    engine.duration = const Duration(seconds: 200);
    engine.bufferedEnd = const Duration(seconds: 30);
    engine.notifyListeners();
    now = const Duration(milliseconds: 100);
    tasks.single.run();
    expect(binding.value!.position, Duration.zero);
    expect(binding.value!.duration, engine.duration);
    expect(binding.value!.bufferedEnd, engine.bufferedEnd);
  });
}

class _Engine extends ChangeNotifier implements PlaybackEngine {
  @override
  Duration position = Duration.zero;
  @override
  Duration duration = const Duration(seconds: 100);
  @override
  Duration bufferedEnd = Duration.zero;
  bool disposed = false;
  bool get hasProgressListeners => hasListeners;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
