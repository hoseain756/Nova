import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/playback_preferences.dart';
import 'package:nova_mobile/features/player/widgets/player_chrome.dart';

void main() {
  group('resume policy', () {
    test('disabled resume always starts from zero', () {
      expect(
        NovaPlaybackPreferences.resumeAction(
          <String, dynamic>{
            'resumePlayback': false,
            'resumePrompt': true,
          },
          180000,
        ),
        ResumePlaybackAction.startOver,
      );
    });

    test('enabled resume asks or resumes according to prompt setting', () {
      expect(
        NovaPlaybackPreferences.resumeAction(
          <String, dynamic>{
            'resumePlayback': true,
            'resumePrompt': true,
          },
          180000,
        ),
        ResumePlaybackAction.prompt,
      );
      expect(
        NovaPlaybackPreferences.resumeAction(
          <String, dynamic>{
            'resumePlayback': true,
            'resumePrompt': false,
          },
          180000,
        ),
        ResumePlaybackAction.resume,
      );
      expect(
        NovaPlaybackPreferences.resumeAction(
          <String, dynamic>{
            'resumePlayback': true,
            'resumePrompt': true,
          },
          15000,
        ),
        ResumePlaybackAction.resume,
      );
    });

    test('resume seek remains valid for zero and very short media', () {
      expect(NovaPlaybackPreferences.safeResumePositionMs(4000, 0), 0);
      expect(NovaPlaybackPreferences.safeResumePositionMs(4000, 4500), 0);
      expect(
          NovaPlaybackPreferences.safeResumePositionMs(120000, 180000), 120000);
      expect(
          NovaPlaybackPreferences.safeResumePositionMs(179000, 180000), 175000);
    });

    test('progress remains protected while the resume prompt is pending', () {
      expect(
        NovaPlaybackPreferences.canRecordProgress(
          awaitingResumeChoice: true,
        ),
        isFalse,
      );
      expect(
        NovaPlaybackPreferences.canRecordProgress(
          awaitingResumeChoice: false,
        ),
        isTrue,
      );
    });
  });

  group('video and speed choices', () {
    test('maps fit and legacy zoom values to supported rendering fits', () {
      expect(NovaPlaybackPreferences.videoFit('fit'), BoxFit.contain);
      expect(NovaPlaybackPreferences.videoFit('fill'), BoxFit.cover);
      expect(NovaPlaybackPreferences.videoFit('zoom'), BoxFit.cover);
    });

    test('sanitizes custom speeds, sorts them, and includes current speed', () {
      expect(
        NovaPlaybackPreferences.playbackSpeeds(
          <Object>[2, '1.25', 1.25, -1, 8, double.nan, 'bad'],
          1.1,
        ),
        <double>[1.1, 1.25, 2.0],
      );
      expect(
        NovaPlaybackPreferences.playbackSpeeds(const <double>[], 1.75),
        <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
      );
    });
  });

  group('embedded track preferences', () {
    const tracks = <PlaybackTrackLanguage>[
      PlaybackTrackLanguage(language: 'eng', title: 'English stereo'),
      PlaybackTrackLanguage(language: 'ar-SA', title: 'Arabic 5.1'),
      PlaybackTrackLanguage(language: 'jpn', title: 'Original'),
    ];

    test('matches ISO-639 aliases and leaves source audio automatic', () {
      expect(NovaPlaybackPreferences.preferredAudioTrack(tracks, 'ar'), 1);
      expect(NovaPlaybackPreferences.preferredAudioTrack(tracks, 'ja-JP'), 2);
      expect(NovaPlaybackPreferences.preferredAudioTrack(tracks, 'source'),
          isNull);
      expect(NovaPlaybackPreferences.preferredAudioTrack(tracks, 'original'),
          isNull);
    });

    test('uses explicit subtitle language then ranked fallback', () {
      expect(
        NovaPlaybackPreferences.preferredSubtitleTrack(
          tracks,
          explicitLanguage: 'fr',
          rankedLanguages: const <String>['Arabic', 'English'],
        ),
        1,
      );
      expect(
        NovaPlaybackPreferences.preferredSubtitleTrack(
          tracks,
          explicitLanguage: 'en',
          rankedLanguages: const <String>['Arabic'],
        ),
        0,
      );
    });

    test('subtitles-off preference dominates language selection', () {
      expect(
        NovaPlaybackPreferences.subtitlesDisabled(
          <String, dynamic>{
            'subtitlesOffByDefault': true,
            'subtitleTranslationLanguage': 'ar',
            'preferredSubLangs': <String>['English'],
          },
        ),
        isTrue,
      );
    });

    test('manual choices remain authoritative across engine retries', () {
      final session = PlaybackPreferenceSession();
      expect(session.canApplyAudio, isTrue);
      expect(session.canApplySubtitle, isTrue);

      session.markAudioSelectedManually();
      session.markSubtitleSelectedManually();
      session.resetForEngine();

      expect(session.canApplyAudio, isFalse);
      expect(session.canApplySubtitle, isFalse);
    });
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      'series top bar reserves non-overlapping source info at 200% $direction',
      (tester) async {
        tester.view.physicalSize = const Size(844, 390);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const title = 'A very long series title that must remain bounded';
        const source = 'Torrentio 2160p HDR10+ · HEVC Main10 · BluRay REMUX';
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(844, 390),
                textScaler: TextScaler.linear(2),
              ),
              child: Directionality(
                textDirection: direction,
                child: Scaffold(
                  body: Stack(
                    children: [
                      PlayerTopBar(
                        title: title,
                        episodeTag: 'S01E12',
                        streamInfo: source,
                        streamInfoSemanticLabel: 'Quality: $source',
                        statusInfo: const DecoratedBox(
                          decoration: BoxDecoration(color: Color(0xD9000000)),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              'Downloading · 4.2 MB/s · P:12 S:8 · 42.5%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        onClose: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final titleRect = tester.getRect(find.text(title));
        final sourceRect = tester.getRect(find.text(source));
        final statusRect = tester.getRect(find.text(
          'Downloading · 4.2 MB/s · P:12 S:8 · 42.5%',
        ));
        final closeRect = tester.getRect(find.byType(PlayerBackButton));
        expect(titleRect.overlaps(closeRect), isFalse);
        expect(sourceRect.overlaps(closeRect), isFalse);
        expect(statusRect.overlaps(closeRect), isFalse);
        expect(sourceRect.top, greaterThan(titleRect.bottom));
        expect(statusRect.top, greaterThan(titleRect.bottom));
        expect(statusRect.overlaps(sourceRect), isFalse);
        expect(tester.getBottomRight(find.byType(PlayerTopBar)).dy,
            lessThanOrEqualTo(160));
      },
    );

    testWidgets(
      'full chrome controls stay disjoint at 200% $direction',
      (tester) async {
        tester.view.physicalSize = const Size(844, 390);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var speedTaps = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(844, 390),
                textScaler: TextScaler.linear(2),
              ),
              child: Directionality(
                textDirection: direction,
                child: Scaffold(
                  body: Stack(
                    children: [
                      PlayerTopBar(
                        key: const ValueKey('header'),
                        title: 'A very long series title that remains bounded',
                        episodeTag: 'S01E12',
                        streamInfo: 'Torrentio 2160p HDR10+ · HEVC Main10',
                        streamInfoSemanticLabel: 'Quality: Torrentio 2160p',
                        statusInfo: const Text(
                          'Downloading · 4.2 MB/s · P:12 S:8 · 42.5%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white),
                        ),
                        onClose: () {},
                      ),
                      PlayerSideRail(
                        side: AxisSide.left,
                        topInset: 144,
                        children: [
                          PlayerRailButton(
                            key: const ValueKey('lock'),
                            icon: Icons.lock,
                            semanticLabel: 'Lock controls',
                            onTap: () {},
                          ),
                          PlayerSpeedPill(
                            key: const ValueKey('speed'),
                            label: '1.0X',
                            semanticLabel: 'Playback speed',
                            onTap: () => speedTaps++,
                          ),
                        ],
                      ),
                      PlayerCenterTransport(
                        isPlaying: false,
                        backStepSec: 10,
                        forwardStepSec: 10,
                        scale: 1,
                        wide: false,
                        onPlayPause: () {},
                        onSkip: (_) {},
                      ),
                      PlayerBottomCluster(
                        key: const ValueKey('footer'),
                        durationMs: 7200000,
                        positionMs: 1800000,
                        bufferedMs: 2400000,
                        showRemaining: false,
                        volume: .8,
                        muted: false,
                        fullscreen: true,
                        canPrev: true,
                        canNext: true,
                        scale: 1,
                        wide: false,
                        english: direction == TextDirection.ltr,
                        onPrev: () {},
                        onNext: () {},
                        onVolumeChanged: (_) {},
                        onVolumeDragEnd: () {},
                        onMuteToggle: () {},
                        onToggleFullscreen: () {},
                        onOpenStreams: () {},
                        onOpenSubtitles: () {},
                        onOpenAudio: () {},
                        onToggleRemaining: () {},
                        onScrubStart: () {},
                        onScrubUpdate: (_) {},
                        onScrubEnd: (_) {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final header = tester.getRect(find.byKey(const ValueKey('header')));
        final lock = tester.getRect(find.byKey(const ValueKey('lock')));
        final speed = tester.getRect(find.byKey(const ValueKey('speed')));
        final play = tester.getRect(
          find
              .descendant(
                of: find.byType(PlayerCenterTransport),
                matching: find.byType(GestureDetector),
              )
              .at(1),
        );
        final footer = tester.getRect(find.byKey(const ValueKey('footer')));
        expect(header.bottom, lessThanOrEqualTo(lock.top));
        expect(header.bottom, lessThan(play.top));
        expect(speed.bottom, lessThanOrEqualTo(footer.top));
        expect(play.bottom, lessThan(footer.top));
        expect(speed.height, greaterThanOrEqualTo(44));

        await tester.tap(find.byKey(const ValueKey('speed')));
        expect(speedTaps, 1);
      },
    );
  }
}
