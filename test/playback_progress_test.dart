import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/session/playback_progress.dart';

void main() {
  group('PlaybackProgress', () {
    test('value equality includes identity and all exact timing fields', () {
      final original = _sample(123456);
      expect(original, _sample(123456));
      expect(original.hashCode, _sample(123456).hashCode);
      expect({original, _sample(123456)}, hasLength(1));
      for (final different in [
        _sample(123456, content: 2),
        _sample(123456, source: 2),
        _sample(123457),
        _sample(123456, duration: 9000001),
        _sample(123456, buffered: 8000001),
      ]) {
        expect(original, isNot(different));
      }
      expect(original == Object(), isFalse);
    });
  });

  group('PlaybackProgressCoalescer', () {
    late _Scheduler scheduler;
    late List<PlaybackProgress> emitted;
    late List<Duration> emittedAt;
    late PlaybackProgressCoalescer coalescer;

    setUp(() {
      scheduler = _Scheduler();
      emitted = [];
      emittedAt = [];
      coalescer = PlaybackProgressCoalescer(
        contentGeneration: 1,
        sourceGeneration: 1,
        now: () => scheduler.now,
        schedule: scheduler.schedule,
        onProgress: (sample) {
          emitted.add(sample);
          emittedAt.add(scheduler.now);
        },
      );
    });

    tearDown(() => coalescer.close());

    test('first exact sample publishes immediately with no idle timer', () {
      final sample = _sample(123456, duration: 0, buffered: 9999999);
      expect(coalescer.latest, isNull);
      expect(coalescer.published, isNull);
      expect(coalescer.add(sample), isTrue);
      expect(emitted, [sample]);
      expect(coalescer.latest, same(sample));
      expect(coalescer.published, same(sample));
      expect(scheduler.activeCount, 0);
      scheduler.elapse(const Duration(seconds: 5));
      expect(emitted, hasLength(1));
    });

    test('high-rate input emits only latest at each 100 ms boundary', () {
      coalescer.add(_sample(0));
      for (var millisecond = 1; millisecond <= 1000; millisecond++) {
        scheduler.elapse(const Duration(milliseconds: 1));
        coalescer.add(_sample(millisecond * 1000));
        expect(scheduler.activeCount, lessThanOrEqualTo(1));
      }
      expect(emittedAt, [
        Duration.zero,
        for (var ms = 100; ms <= 1000; ms += 100) Duration(milliseconds: ms),
      ]);
      expect(emitted[1].position, const Duration(milliseconds: 99));
      expect(coalescer.latest!.position, const Duration(seconds: 1));
      expect(coalescer.published!.position, const Duration(milliseconds: 999));
      scheduler.elapse(const Duration(milliseconds: 100));
      expect(emitted.last.position, const Duration(seconds: 1));
      expect(scheduler.activeCount, 0);
    });

    test('publishes latest trailing sample at exactly 100 ms, never early', () {
      coalescer.add(_sample(0));
      scheduler.elapse(const Duration(milliseconds: 10));
      coalescer.add(_sample(123456));
      scheduler.elapse(const Duration(milliseconds: 89));
      expect(emitted, hasLength(1));
      expect(coalescer.latest!.position.inMicroseconds, 123456);
      expect(coalescer.published!.position, Duration.zero);
      scheduler.elapse(const Duration(milliseconds: 1));
      expect(emitted.last, _sample(123456));
      expect(emittedAt.last, const Duration(milliseconds: 100));
      expect(scheduler.activeCount, 0);
    });

    test('unchanged samples do not schedule or repeatedly publish', () {
      coalescer.add(_sample(10));
      coalescer.add(_sample(10));
      scheduler.elapse(const Duration(seconds: 1));
      coalescer.add(_sample(10));
      expect(emitted, hasLength(1));
      expect(scheduler.tasks, isEmpty);
    });

    test('reverting to published sample cancels an obsolete trailing update',
        () {
      coalescer.add(_sample(0));
      coalescer.add(_sample(1));
      coalescer.add(_sample(0));
      expect(scheduler.activeCount, 0);
      scheduler.fire(scheduler.tasks.single); // Simulate late cancellation.
      scheduler.elapse(const Duration(seconds: 1));
      expect(emitted, [_sample(0)]);
    });

    test('seek, duration and buffer changes share the same rate limit', () {
      coalescer.add(_sample(7000000));
      scheduler.elapse(const Duration(milliseconds: 25));
      coalescer.add(_sample(1000000)); // A backwards seek is still exact.
      scheduler.elapse(const Duration(milliseconds: 25));
      coalescer.add(_sample(1000000, duration: 10000000));
      scheduler.elapse(const Duration(milliseconds: 25));
      final newest = _sample(1000000, duration: 10000000, buffered: 8500000);
      coalescer.add(newest);
      expect(coalescer.latest, same(newest));
      expect(emitted, hasLength(1));
      scheduler.elapse(const Duration(milliseconds: 25));
      expect(emitted.last, same(newest));
      expect(emittedAt.last, const Duration(milliseconds: 100));
    });

    test('duration-only and buffer-only changes publish without position ticks',
        () {
      coalescer.add(_sample(10));
      coalescer.add(_sample(10, duration: 10000000));
      scheduler.elapse(const Duration(milliseconds: 100));
      expect(emitted.last.duration.inMicroseconds, 10000000);
      coalescer.add(_sample(10, duration: 10000000, buffered: 8500000));
      scheduler.elapse(const Duration(milliseconds: 100));
      expect(emitted.last.bufferedEnd.inMicroseconds, 8500000);
      expect(emitted, hasLength(3));
    });

    test(
        'late scheduler publishes once and anchors next interval to actual time',
        () {
      coalescer.add(_sample(0));
      coalescer.add(_sample(1));
      scheduler.now = const Duration(seconds: 5); // Do not service the timer.
      coalescer.add(_sample(5000000));
      scheduler.runDue();
      expect(emitted, [_sample(0), _sample(5000000)]);
      expect(scheduler.activeCount, 0);
      coalescer.add(_sample(5000001));
      scheduler.runDue();
      expect(emitted, hasLength(2));
      scheduler.elapse(const Duration(milliseconds: 99));
      expect(emitted, hasLength(2));
      scheduler.elapse(const Duration(milliseconds: 1));
      expect(emittedAt.last, const Duration(milliseconds: 5100));
    });

    test('an early scheduler callback waits out the remaining interval', () {
      coalescer.add(_sample(0));
      coalescer.add(_sample(1));
      scheduler.now = const Duration(milliseconds: 40);
      scheduler.fire(scheduler.tasks.single);
      expect(emitted, hasLength(1));
      expect(scheduler.activeCount, 1);
      scheduler.elapse(const Duration(milliseconds: 60));
      expect(emittedAt.last, const Duration(milliseconds: 100));
      expect(emitted.last, _sample(1));
    });

    test('sample after an idle interval publishes without a new timer', () {
      coalescer.add(_sample(0));
      scheduler.elapse(const Duration(milliseconds: 250));
      coalescer.add(_sample(250000));
      expect(emitted, hasLength(2));
      expect(emittedAt.last, const Duration(milliseconds: 250));
      expect(scheduler.tasks, isEmpty);
    });

    test('source reset clears snapshots and invalidates old pending callbacks',
        () {
      coalescer.add(_sample(1));
      coalescer.add(_sample(2));
      final oldTask = scheduler.tasks.single;
      expect(
          coalescer.reset(contentGeneration: 1, sourceGeneration: 2), isTrue);
      expect(coalescer.latest, isNull);
      expect(coalescer.published, isNull);
      expect(coalescer.add(_sample(3)), isFalse);
      coalescer.add(_sample(10, source: 2));
      coalescer.add(_sample(11, source: 2));
      scheduler.fire(oldTask); // Must not clear the new pending callback.
      expect(emitted, [_sample(1), _sample(10, source: 2)]);
      expect(scheduler.activeCount, 1);
      scheduler.elapse(const Duration(milliseconds: 100));
      expect(emitted.last, _sample(11, source: 2));
    });

    test(
        'content reset rejects old content even when source generation matches',
        () {
      coalescer.add(_sample(1));
      coalescer.reset(contentGeneration: 2, sourceGeneration: 1);
      expect(coalescer.add(_sample(2)), isFalse);
      expect(coalescer.latest, isNull);
      coalescer.add(_sample(0, content: 2));
      expect(emitted.last, _sample(0, content: 2));
    });

    test('resetting unchanged generations cannot bypass the interval', () {
      coalescer.add(_sample(0));
      coalescer.add(_sample(1));
      expect(
          coalescer.reset(contentGeneration: 1, sourceGeneration: 1), isFalse);
      expect(coalescer.latest, _sample(1));
      expect(emitted, hasLength(1));
      scheduler.elapse(const Duration(milliseconds: 100));
      expect(emitted.last, _sample(1));
    });

    test('close is idempotent and suppresses late callbacks, input and reset',
        () {
      coalescer.add(_sample(0));
      coalescer.add(_sample(1));
      final pending = scheduler.tasks.single;
      coalescer.close();
      coalescer.close();
      scheduler.fire(pending);
      expect(coalescer.isClosed, isTrue);
      expect(coalescer.add(_sample(2)), isFalse);
      expect(
          coalescer.reset(contentGeneration: 2, sourceGeneration: 1), isFalse);
      expect(coalescer.latest, _sample(1));
      expect(coalescer.published, _sample(0));
      expect(emitted, [_sample(0)]);
      expect(scheduler.activeCount, 0);
    });

    test('a regressing clock is rejected before accepting the sample', () {
      scheduler.now = const Duration(seconds: 2);
      coalescer.add(_sample(0));
      scheduler.now = const Duration(seconds: 1);
      expect(() => coalescer.add(_sample(1)), throwsStateError);
      expect(coalescer.latest, _sample(0));
      scheduler.now = const Duration(milliseconds: 2100);
      coalescer.add(_sample(2));
      expect(emitted.last, _sample(2));
    });

    test('reentrant input waits a full interval', () {
      coalescer.close();
      coalescer = PlaybackProgressCoalescer(
        contentGeneration: 1,
        sourceGeneration: 1,
        now: () => scheduler.now,
        schedule: scheduler.schedule,
        onProgress: (sample) {
          emitted.add(sample);
          if (sample.position == Duration.zero) coalescer.add(_sample(1));
        },
      );
      coalescer.add(_sample(0));
      expect(emitted, [_sample(0)]);
      scheduler.elapse(const Duration(milliseconds: 100));
      expect(emitted, [_sample(0), _sample(1)]);
    });

    test('callback can close during publication without leaving pending work',
        () {
      coalescer.close();
      coalescer = PlaybackProgressCoalescer(
        contentGeneration: 1,
        sourceGeneration: 1,
        now: () => scheduler.now,
        schedule: scheduler.schedule,
        onProgress: (sample) {
          emitted.add(sample);
          coalescer.add(_sample(2));
          coalescer.close();
        },
      );
      coalescer.add(_sample(1));
      scheduler.elapse(const Duration(seconds: 1));
      expect(emitted, [_sample(1)]);
      expect(scheduler.activeCount, 0);
    });

    test('publication state remains usable if the consumer throws', () {
      coalescer.close();
      coalescer = PlaybackProgressCoalescer(
        contentGeneration: 1,
        sourceGeneration: 1,
        now: () => scheduler.now,
        schedule: scheduler.schedule,
        onProgress: (sample) {
          if (sample.position == Duration.zero) throw StateError('consumer');
          emitted.add(sample);
        },
      );
      expect(() => coalescer.add(_sample(0)), throwsStateError);
      coalescer.add(_sample(1));
      scheduler.elapse(const Duration(milliseconds: 100));
      expect(emitted, [_sample(1)]);
    });
  });

  test('default Stopwatch and Timer deliver a trailing sample without wiring',
      () async {
    final finished = Completer<void>();
    final emitted = <PlaybackProgress>[];
    final coalescer = PlaybackProgressCoalescer(
      contentGeneration: 1,
      sourceGeneration: 1,
      onProgress: (sample) {
        emitted.add(sample);
        if (sample.position.inMicroseconds == 1) finished.complete();
      },
    );
    try {
      coalescer.add(_sample(0));
      coalescer.add(_sample(1));
      await finished.future.timeout(const Duration(seconds: 5));
      expect(emitted, [_sample(0), _sample(1)]);
    } finally {
      coalescer.close();
    }
  });
}

PlaybackProgress _sample(
  int position, {
  int content = 1,
  int source = 1,
  int duration = 9000000,
  int buffered = 8000000,
}) =>
    PlaybackProgress(
      contentGeneration: content,
      sourceGeneration: source,
      position: Duration(microseconds: position),
      duration: Duration(microseconds: duration),
      bufferedEnd: Duration(microseconds: buffered),
    );

/// A deterministic monotonic clock with an explicitly serviced timer queue.
class _Scheduler {
  Duration now = Duration.zero;
  final tasks = <_Task>[];

  int get activeCount =>
      tasks.where((task) => !task.cancelled && !task.fired).length;

  PlaybackProgressCancel schedule(Duration delay, void Function() callback) {
    final task = _Task(now + delay, callback);
    tasks.add(task);
    return () => task.cancelled = true;
  }

  void elapse(Duration elapsed) {
    final target = now + elapsed;
    while (true) {
      final next = _nextDue(target);
      if (next == null) break;
      if (next.due > now) now = next.due;
      fire(next);
    }
    now = target;
  }

  void runDue() {
    while (true) {
      final next = _nextDue(now);
      if (next == null) return;
      fire(next);
    }
  }

  _Task? _nextDue(Duration until) {
    final due = tasks
        .where((task) => !task.cancelled && !task.fired && task.due <= until)
        .toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    return due.isEmpty ? null : due.first;
  }

  // Explicitly allows delivery after cancellation to exercise the race guard.
  void fire(_Task task) {
    expect(task.fired, isFalse);
    task.fired = true;
    task.callback();
  }
}

class _Task {
  _Task(this.due, this.callback);

  final Duration due;
  final void Function() callback;
  bool cancelled = false;
  bool fired = false;
}
