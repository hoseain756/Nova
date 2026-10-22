import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nova_mobile/core/api/noor_api.dart';
import 'package:nova_mobile/features/player/engine/external_subtitle_loader.dart';

const _providerUrl =
    'https://subdl.strem.top/subtitle/mal:21:1156/example/1512724-982981.srt';

class _SubtitleAdapter implements HttpClientAdapter {
  _SubtitleAdapter(this.status, this.body);

  final int status;
  final String body;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests++;
    expect(options.uri.toString(), _providerUrl);
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: ['text/plain; charset=UTF-8'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('SubDL HTTP 500 diagnostic is rejected before native selection',
      () async {
    final adapter = _SubtitleAdapter(500,
        '1\n00:00:00,000 --> 02:30:00,000\nNo supported subtitle file found in the subtitle archive');
    final api = NoorApi(dio: Dio()..httpClientAdapter = adapter);
    await expectLater(
      loadExternalSubtitleTrack(api, SubtitleTrack.uri(_providerUrl)),
      throwsA(isA<ExternalSubtitleException>()
          .having(
              (e) => e.reason, 'reason', ExternalSubtitleFailure.providerNoFile)
          .having((e) => e.statusCode, 'statusCode', 500)),
    );
    expect(adapter.requests, 1);
    expect(
      externalSubtitleErrorMessageKey(const ExternalSubtitleException(
          ExternalSubtitleFailure.providerNoFile,
          statusCode: 500)),
      'subtitleProviderNoFile',
    );
  });

  test('valid SRT becomes a data track and never passes the URL to mpv',
      () async {
    final adapter =
        _SubtitleAdapter(200, '1\n00:00:01,000 --> 00:00:02,000\nمرحبا\n');
    final api = NoorApi(dio: Dio()..httpClientAdapter = adapter);
    final track = await loadExternalSubtitleTrack(
        api, SubtitleTrack.uri(_providerUrl, title: 'Arabic'));
    expect(track.data, isTrue);
    expect(track.uri, isFalse);
    expect(track.id, contains('مرحبا'));
    expect(track.id, isNot(contains(_providerUrl)));
    expect(track.title, 'Arabic');
  });

  test('HTTP 200 provider error disguised as SRT is rejected', () async {
    final api = NoorApi(
        dio: Dio()
          ..httpClientAdapter = _SubtitleAdapter(200,
              '1\n00:00:00,000 --> 02:30:00,000\nNo supported subtitle file found in the subtitle archive'));
    await expectLater(
      loadExternalSubtitleTrack(api, SubtitleTrack.uri(_providerUrl)),
      throwsA(isA<ExternalSubtitleException>().having(
          (e) => e.reason, 'reason', ExternalSubtitleFailure.providerNoFile)),
    );
  });

  test('HTML and unsupported bytes are rejected', () async {
    for (final body in ['<html>failed</html>', 'PK\x03\x04archive']) {
      final api =
          NoorApi(dio: Dio()..httpClientAdapter = _SubtitleAdapter(200, body));
      await expectLater(
        loadExternalSubtitleTrack(api, SubtitleTrack.uri(_providerUrl)),
        throwsA(isA<ExternalSubtitleException>().having(
            (e) => e.reason, 'reason', ExternalSubtitleFailure.invalidContent)),
      );
    }
  });

  test('other HTTP errors retain the status in their localized message', () {
    expect(
      externalSubtitleErrorMessageKey(const ExternalSubtitleException(
          ExternalSubtitleFailure.http,
          statusCode: 403)),
      'subtitleProviderHttpError',
    );
    expect(externalSubtitleErrorMessageKey(StateError('native failure')),
        'subtitleLoadFailed');
  });
}
