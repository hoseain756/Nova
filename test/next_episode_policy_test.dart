import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/segments/next_episode_policy.dart';
import 'package:nova_mobile/features/player/segments/playback_segments.dart';

void main() {
  const segments = PlaybackSegments(
    nextEpisodeAtMs: 80000,
    autoAdvanceCountdownMs: 10000,
  );

  bool shouldAdvance({
    PlaybackSegments timing = segments,
    int? previous = 89000,
    int position = 90000,
    int duration = 100000,
    bool playing = true,
    bool seekInProgress = false,
    bool panelOpen = false,
    bool hasNextEpisode = true,
    bool dismissed = false,
    bool transitionBusy = false,
    bool alreadyFired = false,
  }) =>
      NextEpisodePolicy.shouldAutoAdvance(
        segments: timing,
        previousPositionMs: previous,
        positionMs: position,
        durationMs: duration,
        ready: true,
        playing: playing,
        failed: false,
        closing: false,
        seekInProgress: seekInProgress,
        resumeResolved: true,
        locked: false,
        panelOpen: panelOpen,
        hasNextEpisode: hasNextEpisode,
        autoPlayEnabled: true,
        dismissed: dismissed,
        completed: false,
        transitionBusy: transitionBusy,
        alreadyFired: alreadyFired,
      );

  test('short forward playback crossing starts one available next episode', () {
    expect(shouldAdvance(), isTrue);
    expect(shouldAdvance(alreadyFired: true), isFalse);
    expect(shouldAdvance(transitionBusy: true), isFalse);
    expect(shouldAdvance(hasNextEpisode: false), isFalse);
  });

  test('pause and open panel prevent automatic transition', () {
    expect(shouldAdvance(playing: false), isFalse);
    expect(shouldAdvance(seekInProgress: true), isFalse);
    expect(shouldAdvance(panelOpen: true), isFalse);
    expect(shouldAdvance(dismissed: true), isFalse);
  });

  test('manual jump past deadline does not start next episode', () {
    expect(shouldAdvance(previous: 30000, position: 91000), isFalse);
    expect(shouldAdvance(previous: 91000, position: 92000), isFalse);
    expect(shouldAdvance(previous: null), isFalse);
  });

  test('data countdown cannot auto-advance before resume is complete', () {
    const early = PlaybackSegments(
      nextEpisodeAtMs: 200000,
      autoAdvanceCountdownMs: 10000,
    );
    expect(
      shouldAdvance(
        timing: early,
        previous: 209000,
        position: 210000,
        duration: 600000,
      ),
      isFalse,
    );
  });

  test('absent countdown keeps existing card manual', () {
    expect(shouldAdvance(timing: PlaybackSegments.empty), isFalse);
    expect(
      NextEpisodePolicy.cardVisible(
        segments: PlaybackSegments.empty,
        positionMs: 95000,
        durationMs: 100000,
        ready: true,
        failed: false,
        locked: false,
        temporarySpeedActive: false,
        panelOpen: false,
        hasNextEpisode: true,
        endingSegmentVisible: false,
        dismissed: false,
        completed: false,
      ),
      isTrue,
    );
  });

  test('card stays away under panel, ending marker and dismissal', () {
    bool visible({
      bool panelOpen = false,
      bool ending = false,
      bool dismissed = false,
    }) =>
        NextEpisodePolicy.cardVisible(
          segments: segments,
          positionMs: 85000,
          durationMs: 100000,
          ready: true,
          failed: false,
          locked: false,
          temporarySpeedActive: false,
          panelOpen: panelOpen,
          hasNextEpisode: true,
          endingSegmentVisible: ending,
          dismissed: dismissed,
          completed: false,
        );
    expect(visible(), isTrue);
    expect(visible(panelOpen: true), isFalse);
    expect(visible(ending: true), isFalse);
    expect(visible(dismissed: true), isFalse);
  });

  test('countdown follows provided deadline and clamps at zero', () {
    expect(
      NextEpisodePolicy.countdownSeconds(
        segments: segments,
        positionMs: 85500,
        durationMs: 100000,
      ),
      5,
    );
    expect(
      NextEpisodePolicy.countdownSeconds(
        segments: segments,
        positionMs: 95000,
        durationMs: 100000,
      ),
      0,
    );
  });
}
