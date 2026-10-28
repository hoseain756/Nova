import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/player_diagnostics.dart';

void main() {
  testWidgets('mpv samples only at the interval and stops on retirement',
      (tester) async {
    final requested = <String>[];
    final output = <String>[];
    final probe = MpvPlaybackDiagnostics(
      readProperty: (property) async {
        requested.add(property);
        return _values[property]!;
      },
      emit: output.add,
    );
    addTearDown(probe.stop);
    probe.start();
    await tester.pump(const Duration(seconds: 4));
    expect(requested, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(requested.toSet(), _values.keys.toSet());
    expect(output, hasLength(1));
    expect(output.single, contains('codec=h264 hwdec=videotoolbox'));
    expect(output.single, contains('videoPts=12.5 avsync=0.04'));
    expect(output.single, contains('pausedForCache=false cacheSeconds=8.5'));
    expect(output.single, contains('outputDrops=2 decoderDrops=3'));
    probe.stop();
    await tester.pump(const Duration(seconds: 20));
    expect(output, hasLength(1));
    expect(requested, hasLength(8));
  });

  testWidgets('reopen suppresses old samples and never overlaps native reads',
      (tester) async {
    final pending = Completer<void>();
    var reads = 0;
    final output = <String>[];
    final probe = MpvPlaybackDiagnostics(
      interval: const Duration(seconds: 1),
      readTimeout: const Duration(seconds: 10),
      readProperty: (property) async {
        reads++;
        await pending.future;
        return _values[property]!;
      },
      emit: output.add,
    );
    addTearDown(probe.stop);
    probe.start();
    await tester.pump(const Duration(seconds: 1));
    expect(reads, 8);
    probe.start();
    await tester.pump(const Duration(seconds: 1));
    expect(reads, 8);
    pending.complete();
    await tester.pump();
    expect(output, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(reads, 16);
    expect(output, hasLength(1));
    probe.stop();
  });

  testWidgets('timeout reports once without accumulating stuck native reads',
      (tester) async {
    final pending = Completer<void>();
    var reads = 0;
    final output = <String>[];
    final probe = MpvPlaybackDiagnostics(
      interval: const Duration(seconds: 1),
      readTimeout: const Duration(seconds: 2),
      readProperty: (property) async {
        reads++;
        await pending.future;
        return _values[property]!;
      },
      emit: output.add,
    );
    addTearDown(probe.stop);
    probe.start();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(output, ['NOVA_DIAG engine=mpv sample=timeout']);
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 8);
    expect(output, hasLength(1));
    probe.stop();
    pending.complete();
    await tester.pump();
    expect(output, hasLength(1));
  });

  testWidgets('closing discards pending reads and their later results',
      (tester) async {
    final pending = Completer<String>();
    final output = <String>[];
    final probe = MpvPlaybackDiagnostics(
      readProperty: (_) => pending.future,
      emit: output.add,
    );
    probe.start();
    await tester.pump(const Duration(seconds: 5));
    probe.stop();
    pending.complete('1');
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(output, isEmpty);
  });

  testWidgets('unsupported properties and unsafe values never leak content',
      (tester) async {
    final output = <String>[];
    final probe = MpvPlaybackDiagnostics(
      readProperty: (property) async => switch (property) {
        'video-codec' => 'https://private.invalid/video?token=secret',
        'hwdec-current' => 'videotoolbox\nAuthorization: secret',
        'video-pts' => 'NaN',
        'avsync' => 'Infinity',
        'paused-for-cache' => 'yes',
        'demuxer-cache-duration' => 'https://private.invalid',
        'frame-drop-count' => '3',
        _ => throw StateError('provider secret'),
      },
      emit: output.add,
    );
    addTearDown(probe.stop);
    probe.start();
    await tester.pump(const Duration(seconds: 5));
    expect(output, hasLength(1));
    expect(output.single, contains('codec=unknown hwdec=unknown'));
    expect(output.single, contains('videoPts=unknown avsync=unknown'));
    expect(output.single, contains('pausedForCache=true cacheSeconds=unknown'));
    expect(output.single, contains('outputDrops=3 decoderDrops=unknown'));
    for (final secret in ['private', 'secret', 'Authorization', '\n']) {
      expect(output.single, isNot(contains(secret)));
    }
    probe.stop();
  });

  testWidgets('buffering initial state and actual transitions are distinct',
      (tester) async {
    final output = <String>[];
    final previousPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) output.add(message);
    };
    addTearDown(() => debugPrint = previousPrint);
    final diagnostics = PlayerDiagnostics.instance;
    diagnostics.recordBufferingState(
        media3: false, previous: null, current: false);
    diagnostics.recordBufferingState(
        media3: false, previous: false, current: false);
    diagnostics.record('buffer');
    diagnostics.recordBufferingState(
        media3: false, previous: false, current: true);
    diagnostics.recordBufferingState(
        media3: false, previous: true, current: true);
    diagnostics.recordBufferingState(
        media3: false, previous: true, current: false);
    expect(output.where((line) => line.contains('buffering')), [
      'NOVA_DIAG engine=mpv bufferingInitial=false',
      'NOVA_DIAG engine=mpv buffering=true',
      'NOVA_DIAG engine=mpv buffering=false',
    ]);
    debugPrint = previousPrint;
  });

  test('numeric diagnostics emit only finite normalized numbers', () {
    expect(diagnosticNumber(23), '23');
    expect(diagnosticNumber(' 0.125 '), '0.125');
    expect(diagnosticNumber(double.nan), 'unknown');
    expect(diagnosticNumber(double.infinity), 'unknown');
    expect(diagnosticNumber('https://private.invalid'), 'unknown');
    expect(diagnosticNumber(null), 'unknown');
  });
}

const _values = {
  'video-codec': 'h264 (H.264 / AVC)',
  'hwdec-current': 'videotoolbox',
  'video-pts': '12.5',
  'avsync': '0.04',
  'paused-for-cache': 'no',
  'demuxer-cache-duration': '8.5',
  'frame-drop-count': '2',
  'decoder-frame-drop-count': '3',
};
