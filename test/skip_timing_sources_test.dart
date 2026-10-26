import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/models/media_item.dart';
import 'package:nova_mobile/features/player/segments/playback_segments.dart';
import 'package:nova_mobile/features/player/segments/skip_segment.dart';
import 'package:nova_mobile/features/player/segments/skip_timing_sources.dart';

void main() {
  const duration = 24 * 60 * 1000;

  test('AniSkip requires matching file length and valid episode intervals', () {
    final segments = SkipTimingSources.parseAniSkip({
      'found': true,
      'results': [
        {
          'skipType': 'op',
          'episodeLength': 1440,
          'interval': {'startTime': 75.25, 'endTime': 165.5},
        },
        {
          'skipType': 'ed',
          'episodeLength': 1500,
          'interval': {'startTime': 1350, 'endTime': 1430},
        },
        {
          'skipType': 'recap',
          'episodeLength': 1440,
          'interval': {'startTime': 100, 'endTime': 1500},
        },
      ],
    }, duration);
    expect(segments, hasLength(1));
    expect(segments.single.type, SkipSegmentType.opening);
    expect(segments.single.startMs, 75250);
    expect(segments.single.endMs, 165500);
  });

  test('named file chapters use the next boundary and preserve content', () {
    final chapters = SkipTimingSources.parseChapterList('''
      [
        {"title":"Opening","time":75},
        {"title":"Episode","time":165},
        {"title":"Credits","time":1350}
      ]
    ''', duration);
    expect(chapters, hasLength(2));
    expect(chapters.first.type, SkipSegmentType.opening);
    expect(chapters.first.startMs, 75000);
    expect(chapters.first.endMs, 165000);
    expect(chapters.last.type, SkipSegmentType.credits);
    expect(chapters.last.endMs, duration);
    final unnamedBoundary = SkipTimingSources.parseChapterList('''
      [{"title":"Opening","time":75},{"time":150},
       {"title":"Episode","time":165}]
    ''', duration);
    expect(unnamedBoundary.single.endMs, 150000);
    expect(SkipTimingSources.parseChapterList('[invalid', duration), isEmpty);
  });

  test('IntroDB and TheIntroDB parse only safe, matched windows', () {
    final introDb = SkipTimingSources.parseIntroDb({
      'intro': {
        'start_ms': 30000,
        'end_ms': 110000,
        'confidence': 0.92,
      },
      'outro': {
        'start_ms': 1300000,
        'end_ms': 1450000,
        'confidence': 0.4,
      },
      'post_credits': {
        'start_ms': 1400000,
        'end_ms': 1430000,
      },
    }, duration);
    expect(introDb.map((row) => row.type), [SkipSegmentType.intro]);

    final theIntroDb = SkipTimingSources.parseTheIntroDb({
      'kind': 'media',
      'groupDurationMs': duration,
      'intro': [
        {'start_ms': null, 'end_ms': 120000},
      ],
      'credits': [
        {'start_ms': 1350000, 'end_ms': null},
      ],
      'preview': [
        {'start_ms': 1250000, 'end_ms': 1300000},
      ],
    }, duration);
    expect(theIntroDb, hasLength(2));
    expect(theIntroDb.first.startMs, 0);
    expect(theIntroDb.last.endMs, duration);
    expect(
      SkipTimingSources.parseTheIntroDb({
        'groupDurationMs': duration + 60000,
        'intro': [
          {'start_ms': 0, 'end_ms': 120000},
        ],
      }, duration),
      isEmpty,
    );
  });

  test('provider disagreement suppresses the type; stream marker wins', () {
    const fromTheIntroDb = SkipSegment(
      type: SkipSegmentType.intro,
      startMs: 10000,
      endMs: 90000,
      source: 'theintrodb',
    );
    const fromIntroDb = SkipSegment(
      type: SkipSegmentType.intro,
      startMs: 40000,
      endMs: 120000,
      source: 'introdb',
    );
    expect(
      SkipTimingSources.chooseExternalSegments(
        [fromTheIntroDb, fromIntroDb],
        duration,
      ),
      isEmpty,
    );
    final local = PlaybackSegmentsResolver.resolve(stream: {
      'introStart': 20,
      'introEnd': 100,
      'nextEpisodeAt': 1300,
    });
    final merged = local.withExternal([fromTheIntroDb]);
    expect(merged.introStartMs, local.introStartMs);
    expect(merged.introEndMs, local.introEndMs);
    expect(merged.nextEpisodeAtMs, local.nextEpisodeAtMs);
  });

  test('partial local marker never mixes with an external interval', () {
    const local = PlaybackSegments(introStartMs: 10000);
    final merged = local.withExternal(const [
      SkipSegment(
        type: SkipSegmentType.intro,
        startMs: 20000,
        endMs: 80000,
        source: 'introdb',
      ),
    ]);
    expect(merged.introStartMs, 20000);
    expect(merged.introEndMs, 80000);
    final externalOnly = PlaybackSegments.empty.withExternal(const [
      SkipSegment(
        type: SkipSegmentType.intro,
        startMs: 20000,
        endMs: 80000,
        source: 'introdb',
      ),
    ]);
    expect(externalOnly.introStartMs, 20000);
    expect(externalOnly.introEndMs, 80000);
  });

  test('one episode lookup queries all three public sources independently',
      () async {
    final requested = <Uri>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requested.add(options.uri);
      final data = switch (options.uri.host) {
        'api.aniskip.com' => {
            'found': true,
            'results': [
              {
                'skipType': 'op',
                'episodeLength': 1440,
                'interval': {'startTime': 75, 'endTime': 165},
              },
            ],
          },
        'api.introdb.app' => {
            'recap': {'start_ms': 10000, 'end_ms': 40000},
          },
        _ => {
            'credits': [
              {'start_ms': 1350000, 'end_ms': null},
            ],
          },
      };
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: data,
      ));
    }));
    final found = await SkipTimingSources(client: dio).fetch(
      item: const MediaItem(
        id: 'tt1234567',
        type: 'series',
        name: 'Example',
      ),
      season: 2,
      episode: 3,
      exactMalId: 12345,
      exactAnimeEpisode: 54,
      durationMs: duration,
    );
    expect(requested.map((uri) => uri.host).toSet(), {
      'api.aniskip.com',
      'api.introdb.app',
      'api.theintrodb.org',
    });
    expect(
        requested.any((uri) => uri.path == '/v2/skip-times/12345/54'), isTrue);
    expect(found.map((row) => row.type).toSet(), {
      SkipSegmentType.opening,
      SkipSegmentType.recap,
      SkipSegmentType.outro,
    });
  });

  test('optional key is sent only to TheIntroDB without redirects', () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: const <String, dynamic>{},
      ));
    }));
    await SkipTimingSources(client: dio).fetch(
      item: const MediaItem(
        id: 'tt1234567',
        type: 'series',
        name: 'Example',
      ),
      season: 2,
      episode: 3,
      durationMs: duration,
      theIntroDbKey: 'sample-user-key',
    );
    final protected = requests.singleWhere(
      (request) => request.uri.host == 'api.theintrodb.org',
    );
    expect(protected.headers['Authorization'], 'Bearer sample-user-key');
    expect(protected.followRedirects, isFalse);
    for (final request in requests.where(
      (request) => request.uri.host != 'api.theintrodb.org',
    )) {
      expect(request.headers.containsKey('Authorization'), isFalse);
    }
  });
}
