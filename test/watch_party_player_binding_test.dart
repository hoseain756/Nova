import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/watch_party/watch_party_controller.dart';
import 'package:nova_mobile/core/watch_party/watch_party_models.dart';
import 'package:nova_mobile/features/player/engine/playback_engine.dart';
import 'package:nova_mobile/features/player/watch_party_player_binding.dart';
import 'support/watch_party_fixture.dart';

class _Engine extends PlaybackEngine {
  final calls = <String>[];
  Completer<void>? seekGate;
  @override
  bool ready = true;
  @override
  bool playing = false;
  @override
  bool buffering = false;
  @override
  bool failed = false;
  @override
  bool completed = false;
  @override
  Duration position = Duration.zero;
  @override
  Duration duration = const Duration(hours: 1);
  @override
  double rate = 1;
  @override
  Future<void> play() async {
    if (interceptsWatchParty && await routeWatchPartyCommand('play')) return;
    calls.add('play');
    playing = true;
  }

  @override
  Future<void> pause() async {
    if (interceptsWatchParty && await routeWatchPartyCommand('pause')) return;
    calls.add('pause');
    playing = false;
  }

  @override
  Future<void> seekTo(Duration target) async {
    if (interceptsWatchParty &&
        await routeWatchPartyCommand(
            'seek', target.inMilliseconds.toDouble())) {
      return;
    }
    calls.add('seek');
    await seekGate?.future;
    position = target;
  }

  @override
  Future<void> setRate(double value) async {
    if (interceptsWatchParty && await routeWatchPartyCommand('rate', value)) {
      return;
    }
    calls.add('rate');
    rate = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('paused-open buffering can accept room play intent',
      (tester) async {
    final g = FakeWatchPartyGateway()..data = partyData(playing: true);
    final c = WatchPartyController(g,
        deviceId: partyDeviceId, clock: WatchPartyClock(monotonicMs: () => 0));
    c.bindIdentity('a', partyProfileId);
    await c.join('ABCDEFGH');
    final e = _Engine()..buffering = true;
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    expect(e.playing, isTrue);
    e.buffering = false;
    await tester.pump(const Duration(milliseconds: 250));
    expect(e.position, const Duration(seconds: 10));
    binding.dispose();
    c.dispose();
    e.dispose();
  });
  testWidgets('host completion stops the shared clock instead of replaying EOF',
      (tester) async {
    final g = FakeWatchPartyGateway()
      ..data = partyData(selfId: partyHostId, playing: true);
    final c = WatchPartyController(g, deviceId: partyDeviceId);
    c.bindIdentity('a', partyProfileId);
    await c.join('ABCDEFGH');
    final e = _Engine()..completed = true;
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.snapshot!.playing, isFalse);
    final commands =
        g.requests.where((p) => p['p_action'] == 'command').toList();
    expect(commands.length, 1);
    expect((commands.single['p_payload'] as Map)['command'], 'pause');
    expect(e.calls.where((s) => s == 'play'), isEmpty);
    binding.dispose();
    c.dispose();
    e.dispose();
  });
  Future<WatchPartyController> controller(FakeWatchPartyGateway g,
      {WatchPartyClock? clock}) async {
    final c = WatchPartyController(g, deviceId: partyDeviceId, clock: clock);
    c.bindIdentity('a', partyProfileId);
    await Future<void>.value();
    await c.join('ABCDEFGH');
    return c;
  }

  testWidgets('locked guest cannot issue native play or room commands',
      (tester) async {
    final g = FakeWatchPartyGateway();
    final c = await controller(g);
    final e = _Engine();
    final errors = <String>[];
    final binding = WatchPartyPlayerBinding(
        controller: c,
        engine: e,
        media: partyMedia,
        isActive: () => true,
        onError: errors.add);
    await tester.pump();
    e.calls.clear();
    await e.play();
    await tester.pump();
    expect(e.calls, isEmpty);
    expect(errors, ['partyHostRequired']);
    expect(g.requests.where((p) => p['p_action'] == 'command'), isEmpty);
    binding.dispose();
    c.dispose();
    e.dispose();
  });
  testWidgets('group seek goes through authority and applies without an echo',
      (tester) async {
    var mono = 0;
    final g = FakeWatchPartyGateway()..data = partyData(hostOnly: false);
    final c =
        await controller(g, clock: WatchPartyClock(monotonicMs: () => mono));
    final e = _Engine();
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    await e.seekTo(const Duration(seconds: 40));
    mono = 1000;
    await tester.pump(const Duration(milliseconds: 500));
    expect(e.position, const Duration(seconds: 40));
    expect(g.requests.where((p) => p['p_action'] == 'command').length, 1);
    binding.dispose();
    c.dispose();
    e.dispose();
  });
  testWidgets('rate nudge is local and returns to base when the room is left',
      (tester) async {
    var mono = 0;
    final g = FakeWatchPartyGateway()..data = partyData(playing: true);
    final c =
        await controller(g, clock: WatchPartyClock(monotonicMs: () => mono));
    final e = _Engine();
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    mono = 1000;
    await tester.pump(const Duration(milliseconds: 250));
    expect(e.rate, closeTo(1.05, 0.001));
    expect(g.requests.where((p) => p['p_action'] == 'command'), isEmpty);
    await c.leave();
    await tester.pump();
    expect(e.rate, 1);
    binding.dispose();
    c.dispose();
    e.dispose();
  });
  testWidgets('disposal during a seek cannot apply late play or speed changes',
      (tester) async {
    final g = FakeWatchPartyGateway()..data = partyData(playing: true);
    final c = await controller(g);
    final e = _Engine()..seekGate = Completer<void>();
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    expect(e.calls, ['seek']);
    binding.dispose();
    e.seekGate!.complete();
    await tester.pump();
    expect(e.calls, ['seek']);
    expect(e.watchPartyCommand, isNull);
    c.dispose();
    e.dispose();
  });
  testWidgets(
      'background pauses stay local and resume reconciles with the room',
      (tester) async {
    final g = FakeWatchPartyGateway()..data = partyData(playing: true);
    final c = await controller(g);
    final e = _Engine();
    final binding = WatchPartyPlayerBinding(
        controller: c, engine: e, media: partyMedia, isActive: () => true);
    await tester.pump();
    binding.setForeground(false);
    await e.pause();
    await tester.pump(const Duration(seconds: 1));
    expect(e.playing, isFalse);
    expect(g.requests.where((p) => p['p_action'] == 'command'), isEmpty);
    binding.setForeground(true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(e.playing, isTrue);
    binding.dispose();
    c.dispose();
    e.dispose();
  });
  testWidgets('a different video version cannot drive the room timeline',
      (tester) async {
    final g = FakeWatchPartyGateway();
    final c = await controller(g);
    final e = _Engine()..duration = const Duration(minutes: 40);
    final errors = <String>[];
    final binding = WatchPartyPlayerBinding(
        controller: c,
        engine: e,
        media: partyMedia,
        isActive: () => true,
        onError: errors.add);
    await tester.pump();
    expect(e.calls, isEmpty);
    expect(errors, ['partyDifferentVersion']);
    binding.dispose();
    c.dispose();
    e.dispose();
  });
}
