import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/temporary_speed_hold.dart';

void main() {
  test('release waits for 2x and restores the exact prior rate once', () async {
    final gate = Completer<void>();
    final applied = <double>[];
    final hold = TemporarySpeedHold();
    expect(
      hold.begin(
        previousRate: 1.25,
        setRate: (rate) async {
          applied.add(rate);
          if (rate == 2) await gate.future;
        },
        ownsSource: () => true,
      ),
      isTrue,
    );
    expect(hold.active, isTrue);
    expect(
      hold.begin(
        previousRate: 1,
        setRate: (_) async {},
        ownsSource: () => true,
      ),
      isFalse,
    );
    await Future<void>.delayed(Duration.zero);
    expect(applied, [2]);
    final firstRelease = hold.end();
    final secondRelease = hold.end();
    expect(applied, [2]);
    gate.complete();
    await Future.wait([firstRelease, secondRelease]);
    expect(applied, [2, 1.25]);
    expect(hold.active, isFalse);
  });

  test('retired source never receives a late restore', () async {
    final gate = Completer<void>();
    final applied = <double>[];
    var current = true;
    final hold = TemporarySpeedHold();
    expect(
      hold.begin(
        previousRate: 1.5,
        setRate: (rate) async {
          applied.add(rate);
          if (rate == 2) await gate.future;
        },
        ownsSource: () => current,
      ),
      isTrue,
    );
    await Future<void>.delayed(Duration.zero);
    final release = hold.end();
    current = false;
    hold.invalidate();
    gate.complete();
    await release;
    expect(applied, [2]);
  });

  test('can begin again after a completed release', () async {
    final applied = <double>[];
    final hold = TemporarySpeedHold();
    for (final rate in [1.0, 1.75]) {
      expect(
        hold.begin(
          previousRate: rate,
          setRate: (value) async => applied.add(value),
          ownsSource: () => true,
        ),
        isTrue,
      );
      await hold.end();
    }
    expect(applied, [2, 1.0, 2, 1.75]);
  });

  for (final direction in TextDirection.values) {
    for (final brightness in Brightness.values) {
      testWidgets('long press wins over scale on video $direction $brightness',
          (tester) async {
        var presses = 0;
        var releases = 0;
        var scaleStarts = 0;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) => presses++,
                onLongPressEnd: (_) => releases++,
                onScaleStart: (_) => scaleStarts++,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ));
        final gesture = await tester.startGesture(const Offset(200, 180));
        await tester.pump(const Duration(milliseconds: 600));
        expect(presses, 1);
        expect(scaleStarts, 0);
        await gesture.up();
        await tester.pump();
        expect(releases, 1);
      });
    }
  }
}
