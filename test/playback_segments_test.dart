import 'package:flutter_test/flutter_test.dart';

import 'package:nova_mobile/features/player/segments/playback_segments.dart';
import 'package:nova_mobile/features/player/segments/skip_segment.dart';

void main() {
  group('PlaybackSegmentsResolver — absence means unknown', () {
    test('no data → every field null and every feature inactive', () {
      final s = PlaybackSegmentsResolver.resolve();
      expect(s.introStartMs, isNull);
      expect(s.introEndMs, isNull);
      expect(s.outroStartMs, isNull);
      expect(s.outroEndMs, isNull);
      expect(s.nextEpisodeAtMs, isNull);
      expect(s.autoAdvanceCountdownMs, isNull);
      expect(s.hasIntro, isFalse);
      expect(s.hasOutro, isFalse);
      expect(
        SegmentWindows.introVisible(
            segments: s, positionMs: 1000, durationMs: 100000),
        isFalse,
      );
    });
  });

  group('PlaybackSegmentsResolver — seconds fields', () {
    test('introStart/introEnd in seconds normalize to ms', () {
      final s = PlaybackSegmentsResolver.resolve(
        stream: const {'introStart': 10, 'introEnd': 90},
      );
      expect(s.introStartMs, 10000);
      expect(s.introEndMs, 90000);
      expect(s.hasIntro, isTrue);
    });

    test('…Ms variants pass through unchanged', () {
      final s = PlaybackSegmentsResolver.resolve(
        video: const {'outroStartMs': 500000, 'outroEndMs': 700000},
      );
      expect(s.outroStartMs, 500000);
      expect(s.outroEndMs, 700000);
      expect(s.hasOutro, isTrue);
    });

    test('creditsStart/creditsEnd feed the outro window', () {
      final s = PlaybackSegmentsResolver.resolve(
        stream: const {'creditsStart': 1200, 'creditsEnd': 1400},
      );
      expect(s.outroStartMs, 1200000);
      expect(s.outroEndMs, 1400000);
    });
  });

  group('PlaybackSegmentsResolver — map & list forms', () {
    test('skipIntro {start, end} map (seconds)', () {
      final s = PlaybackSegmentsResolver.resolve(
        stream: const {
          'skipIntro': {'start': 5, 'end': 45}
        },
      );
      expect(s.introStartMs, 5000);
      expect(s.introEndMs, 45000);
    });

    test('{startMs, endMs} map keeps milliseconds', () {
      final s = PlaybackSegmentsResolver.resolve(
        video: const {
          'intro': {'startMs': 2500, 'endMs': 32500}
        },
      );
      expect(s.introStartMs, 2500);
      expect(s.introEndMs, 32500);
    });

    test('credits [start, end] list form', () {
      final s = PlaybackSegmentsResolver.resolve(
        stream: const {
          'credits': [100, 130]
        },
      );
      expect(s.outroStartMs, 100000);
      expect(s.outroEndMs, 130000);
    });

    test('behaviorHints sub-map is consulted', () {
      final s = PlaybackSegmentsResolver.resolve(
        stream: const {
          'url': 'https://example.com/a.mkv',
          'behaviorHints': {
            'introStart': 8,
            'introEnd': 72,
          },
        },
      );
      expect(s.introStartMs, 8000);
      expect(s.introEndMs, 72000);
    });
  });

  group('PlaybackSegmentsResolver — validation & malformed tolerance', () {
    test('start >= end is rejected', () {
      final s = PlaybackSegmentsResolver.resolve(
        stream: const {'introStart': 90, 'introEnd': 10},
      );
      expect(s.hasIntro, isFalse);
    });

    test('negative and non-numeric values are treated as absent', () {
      final s = PlaybackSegmentsResolver.resolve(
        stream: const {
          'introStart': -5,
          'introEnd': 30,
          'nextEpisodeAt': 'soon',
          'autoAdvanceCountdown': null,
        },
      );
      expect(s.hasIntro, isFalse);
      expect(s.nextEpisodeAtMs, isNull);
      expect(s.autoAdvanceCountdownMs, isNull);
    });

    test('window running past the known media duration is rejected', () {
      final s = PlaybackSegmentsResolver.resolve(
        stream: const {'introStart': 10, 'introEnd': 3600},
        mediaDurationMs: 1200000,
      );
      expect(s.hasIntro, isFalse);
    });

    test('absolute trigger beyond the duration is rejected', () {
      final s = PlaybackSegmentsResolver.resolve(
        video: const {'nextEpisodeAtMs': 5000000},
        mediaDurationMs: 1200000,
      );
      expect(s.nextEpisodeAtMs, isNull);
    });
  });

  group('SegmentWindows', () {
    const segments = PlaybackSegments(
      introStartMs: 10000,
      introEndMs: 90000,
      outroStartMs: 700000,
      outroEndMs: 800000,
    );

    test('intro pill visible strictly inside the window', () {
      expect(
        SegmentWindows.introVisible(
            segments: segments, positionMs: 10000, durationMs: 900000),
        isTrue,
      );
      expect(
        SegmentWindows.introVisible(
            segments: segments, positionMs: 89999, durationMs: 900000),
        isTrue,
      );
      expect(
        SegmentWindows.introVisible(
            segments: segments, positionMs: 90000, durationMs: 900000),
        isFalse,
      );
      expect(
        SegmentWindows.introVisible(
            segments: segments, positionMs: 9999, durationMs: 900000),
        isFalse,
      );
    });

    test('window past the media duration never shows', () {
      expect(
        SegmentWindows.introVisible(
            segments: segments, positionMs: 50000, durationMs: 80000),
        isFalse,
      );
    });

    test('cardAppearAt: data trigger wins when valid', () {
      final s = PlaybackSegmentsResolver.resolve(
        video: const {'nextEpisodeAtMs': 850000},
      );
      expect(
        SegmentWindows.cardAppearAtMs(segments: s, durationMs: 900000),
        850000,
      );
    });

    test('cardAppearAt fallback reproduces the shipped nearEnd rule', () {
      // The original rule was `remaining ≤ 30 s OR ≥95% elapsed` → the card
      // appears at the EARLIER (min) of the two thresholds.
      // 900 s media: 95% (855 s) beats 30s-window (870 s).
      expect(
        SegmentWindows.cardAppearAtMs(
            segments: PlaybackSegments.empty, durationMs: 900000),
        855000,
      );
      // 100 s media: 30s-window (70 s) beats 95% (95 s).
      expect(
        SegmentWindows.cardAppearAtMs(
            segments: PlaybackSegments.empty, durationMs: 100000),
        70000,
      );
      // Unknown duration → never.
      expect(
        SegmentWindows.cardAppearAtMs(
            segments: PlaybackSegments.empty, durationMs: 0),
        -1,
      );
    });

    test('autoAdvanceAtMs: null without a data-provided countdown', () {
      expect(
        SegmentWindows.autoAdvanceAtMs(
            segments: PlaybackSegments.empty, durationMs: 900000),
        isNull,
      );
    });

    test('autoAdvanceAtMs: appear + countdown, clamped to the end', () {
      final s = PlaybackSegmentsResolver.resolve(
        video: const {
          'nextEpisodeAtMs': 850000,
          'autoAdvanceCountdownMs': 20000
        },
      );
      expect(
        SegmentWindows.autoAdvanceAtMs(segments: s, durationMs: 900000),
        870000,
      );
      // Countdown running past the end clamps to the end.
      final s2 = PlaybackSegmentsResolver.resolve(
        video: const {
          'nextEpisodeAtMs': 890000,
          'autoAdvanceCountdownMs': 60000
        },
      );
      expect(
        SegmentWindows.autoAdvanceAtMs(segments: s2, durationMs: 900000),
        900000,
      );
    });
  });

  group('Station 14 generalized segments', () {
    test('normalizes all five types without inventing missing markers', () {
      final segments = PlaybackSegmentsResolver.resolve(stream: const {
        'recapStart': 0,
        'recapEnd': 20,
        'introStartMs': 20000,
        'introEndMs': 45000,
        'opening': {'start': 45, 'end': 70},
        'outroStart': 1200,
        'outroEnd': 1240,
        'creditsStartMs': 1240000,
        'creditsEndMs': 1290000,
      });
      expect(segments.skipSegments.map((s) => s.type).toList(),
          SkipSegmentType.values);
      expect(segments.skipSegments[0].startMs, 0);
      expect(segments.skipSegments[2].endMs, 70000);
      expect(segments.skipSegments.last.endMs, 1290000);
      expect(segments.skipSegments.every((s) => s.source == 'stream'), isTrue);
    });

    test('typed list carries provenance and confidence; stream wins per type',
        () {
      final segments = PlaybackSegmentsResolver.resolve(
        stream: const {
          'skipSegments': [
            {'type': 'recap', 'startMs': 0, 'endMs': 25000, 'confidence': .9},
            {'type': 'recap', 'start': 40, 'end': 50},
            {'type': 'credits', 'start': -2, 'end': 60},
          ],
        },
        video: const {
          'recapStart': 1,
          'recapEnd': 10,
          'creditsStart': 90,
          'creditsEnd': 110
        },
      );
      expect(
          segments.skipSegments
              .where((s) => s.type == SkipSegmentType.recap)
              .length,
          2);
      expect(segments.skipSegments.first.confidence, .9);
      expect(segments.skipSegments.first.source, 'stream');
      expect(segments.skipSegments.last.type, SkipSegmentType.credits);
      expect(segments.skipSegments.last.source, 'episode');
    });

    test('known duration rejects invalid marker; boundaries are half-open', () {
      final segments = PlaybackSegmentsResolver.resolve(
        stream: const {
          'openingStart': 10,
          'openingEnd': 150,
          'recapStartMs': 0,
          'recapEndMs': 10000,
        },
        mediaDurationMs: 120000,
      );
      expect(segments.skipSegments.length, 1);
      final recap = segments.skipSegments.single;
      expect(recap.contains(0, 120000), isTrue);
      expect(recap.contains(9999, 120000), isTrue);
      expect(recap.contains(10000, 120000), isFalse);
    });

    test(
        'overlap chooses latest start, then earliest end, independent of order',
        () {
      const short = SkipSegment(
          type: SkipSegmentType.intro,
          startMs: 10000,
          endMs: 30000,
          source: 'test');
      const long = SkipSegment(
          type: SkipSegmentType.opening,
          startMs: 15000,
          endMs: 45000,
          source: 'test');
      const sameEnd = SkipSegment(
          type: SkipSegmentType.recap,
          startMs: 17000,
          endMs: 45000,
          source: 'test');
      final tracker = SkipSegmentController();
      expect(
          tracker.active([short, long, sameEnd],
              positionMs: 20000, durationMs: 100000),
          sameEnd);
      expect(
          tracker.active([sameEnd, long, short],
              positionMs: 20000, durationMs: 100000),
          sameEnd);
      const earlierEnd = SkipSegment(
          type: SkipSegmentType.intro,
          startMs: 17000,
          endMs: 35000,
          source: 'test');
      expect(
          tracker.active([sameEnd, earlierEnd, long],
              positionMs: 20000, durationMs: 100000),
          earlierEnd);
      expect(tracker.begin(earlierEnd, [sameEnd, earlierEnd, long]), isTrue);
      tracker.finish(applied: true);
      expect(
          tracker.active([sameEnd, earlierEnd, long],
              positionMs: 35000, durationMs: 100000),
          isNull); // The outer marker must not re-prompt after the seek.
    });

    test('tap suppresses repeat ticks; seek away/back rearms; failure restores',
        () {
      const intro = SkipSegment(
          type: SkipSegmentType.intro,
          startMs: 10000,
          endMs: 30000,
          source: 'test');
      final tracker = SkipSegmentController();
      expect(tracker.active([intro], positionMs: 10000, durationMs: 100000),
          intro);
      expect(tracker.begin(intro, [intro]), isTrue);
      expect(tracker.begin(intro, [intro]), isFalse);
      expect(tracker.active([intro], positionMs: 12000, durationMs: 100000),
          isNull);
      expect(tracker.active([intro], positionMs: 35000, durationMs: 100000),
          isNull); // No prompt while the native command is pending.
      tracker.finish(applied: true);
      expect(tracker.active([intro], positionMs: 29000, durationMs: 100000),
          isNull);
      expect(tracker.active([intro], positionMs: 30000, durationMs: 100000),
          isNull);
      expect(tracker.active([intro], positionMs: 15000, durationMs: 100000),
          intro);
      expect(tracker.begin(intro, [intro]), isTrue);
      tracker.finish(applied: false);
      expect(tracker.active([intro], positionMs: 15000, durationMs: 100000),
          intro);
    });

    test('ending window includes credits and obeys known duration', () {
      const segments = PlaybackSegments(skipSegments: [
        SkipSegment(
            type: SkipSegmentType.credits,
            startMs: 500000,
            endMs: 600000,
            source: 'test'),
      ]);
      expect(
          SegmentWindows.endingVisible(
              segments: segments, positionMs: 550000, durationMs: 600000),
          isTrue);
      expect(
          SegmentWindows.endingVisible(
              segments: segments, positionMs: 600000, durationMs: 600000),
          isFalse);
      expect(
          SegmentWindows.endingVisible(
              segments: segments, positionMs: 550000, durationMs: 580000),
          isFalse);
    });

    test('ending skip preserves completion and next-episode boundaries', () {
      const credits = SkipSegment(
          type: SkipSegmentType.credits,
          startMs: 1500000,
          endMs: 1800000,
          source: 'test');
      bool opens(int position, {bool hasNext = true}) =>
          SegmentWindows.opensNextEpisodeAfterSkip(
            segment: credits,
            positionMs: position,
            durationMs: 1800000,
            hasNextEpisode: hasNext,
          );
      expect(opens(1679999), isFalse);
      expect(opens(1680000), isTrue); // Shared last-two-minute rule.
      expect(opens(1680000, hasNext: false), isFalse);
      const intro = SkipSegment(
          type: SkipSegmentType.intro,
          startMs: 0,
          endMs: 60000,
          source: 'test');
      expect(
          SegmentWindows.opensNextEpisodeAfterSkip(
              segment: intro,
              positionMs: 1790000,
              durationMs: 1800000,
              hasNextEpisode: true),
          isFalse);
    });

    test('long episode markers remain exact without a guessed duration', () {
      final segments = PlaybackSegmentsResolver.resolve(stream: const {
        'openingStartMs': 180000,
        'openingEndMs': 240000,
        'creditsStartMs': 10300000,
        'creditsEndMs': 10700000,
      }, mediaDurationMs: 10800000);
      expect(segments.skipSegments.length, 2);
      expect(
          SkipSegmentController()
              .active(segments.skipSegments,
                  positionMs: 10300000, durationMs: 10800000)
              ?.type,
          SkipSegmentType.credits);
    });
  });
}
