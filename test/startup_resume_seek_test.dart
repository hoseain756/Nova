import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/engine/startup_resume_seek.dart';

void main() {
  test('automatic resume waits for duration and positive seek capability',
      () async {
    var probe = 0;
    var waits = 0;
    Duration? applied;
    final resumed = await applyStartupResumeSeek(
      target: const Duration(minutes: 9),
      duration: () => waits == 0 ? Duration.zero : const Duration(minutes: 24),
      seekable: () async => ++probe >= 2,
      seekTo: (target) async {
        applied = target;
      },
      isActive: () => true,
      wait: (_) async {
        waits++;
      },
    );

    expect(resumed, isTrue);
    expect(waits, 2);
    expect(applied, const Duration(minutes: 9));
  });

  test('unsupported seek does not silently start at zero', () async {
    var seekCalls = 0;
    final resumed = await applyStartupResumeSeek(
      target: const Duration(minutes: 9),
      duration: () => const Duration(minutes: 24),
      seekable: () async => false,
      seekTo: (_) async {
        seekCalls++;
      },
      isActive: () => true,
      wait: (_) async {},
      attempts: 3,
    );

    expect(resumed, isFalse);
    expect(seekCalls, 0);
  });

  test('retired engine cannot apply a pending resume seek', () async {
    var active = true;
    var seekCalls = 0;
    final resumed = await applyStartupResumeSeek(
      target: const Duration(minutes: 9),
      duration: () => Duration.zero,
      seekable: () async => true,
      seekTo: (_) async {
        seekCalls++;
      },
      isActive: () => active,
      wait: (_) async {
        active = false;
      },
    );

    expect(resumed, isFalse);
    expect(seekCalls, 0);
  });

  test('playing fallback confirms a seek when paused capability stayed false',
      () async {
    var playing = false;
    var seekCalls = 0;
    var waits = 0;
    var position = Duration.zero;
    final resumed = await applyPlayingStartupResumeSeek(
      target: const Duration(minutes: 9),
      duration: () => const Duration(minutes: 24),
      position: () => position,
      play: () async => playing = true,
      pause: () async => playing = false,
      seekTo: (target) async {
        expect(playing, isTrue);
        seekCalls++;
      },
      isActive: () => true,
      wait: (_) async {
        if (++waits == 2) position = const Duration(minutes: 9);
      },
    );

    expect(resumed, isTrue);
    expect(playing, isTrue);
    expect(seekCalls, 1);
  });

  test('playing fallback pauses and fails when seek never changes position',
      () async {
    var playing = false;
    var seekCalls = 0;
    final resumed = await applyPlayingStartupResumeSeek(
      target: const Duration(minutes: 9),
      duration: () => const Duration(minutes: 24),
      position: () => Duration.zero,
      play: () async => playing = true,
      pause: () async => playing = false,
      seekTo: (_) async => seekCalls++,
      isActive: () => true,
      wait: (_) async {},
      positionAttempts: 2,
    );

    expect(resumed, isFalse);
    expect(playing, isFalse);
    expect(seekCalls, 2);
  });
}
