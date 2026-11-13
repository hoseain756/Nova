import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/watch_party/watch_party_models.dart';
import 'package:nova_mobile/features/player/watch_party_audio.dart';
import 'package:nova_mobile/features/player/engine/playback_engine.dart';

void main() {
  test(
      'source fingerprints keep opaque resources distinct without sharing secrets',
      () {
    final first = WatchPartySource.fromStream({
      'url': 'https://example.test/stream?id=A&token=secret',
      'title': 'https://user:password@example.test/secret',
      'behaviorHints': {
        'proxyHeaders': {
          'request': {'Authorization': 'secret'}
        }
      }
    })!;
    final second = WatchPartySource.fromStream(
        {'url': 'https://example.test/stream?id=B&token=secret'})!;
    expect(first.key, isNot(second.key));
    final shared = jsonEncode(first.toJson());
    expect(shared, isNot(contains('secret')));
    expect(shared, isNot(contains('password')));
    expect(shared, isNot(contains('example.test')));
    expect(shared, isNot(contains('Authorization')));
    expect(WatchPartySource.tryParse(first.toJson())!.key, first.key);
    expect(WatchPartySource.fromStream({'url': 'http://127.0.0.1:8080/video'}),
        isNull);
    expect(
        WatchPartySource.fromStream(
            {'url': 'https://user:password@example.test/video'}),
        isNull);
  });

  test('original torrent identity survives local and debrid resolution', () {
    const hash = '0123456789012345678901234567890123456789';
    final first = WatchPartySource.fromStream(
        {'infoHash': hash.toUpperCase(), 'fileIdx': 2, 'name': 'A'})!;
    final second = WatchPartySource.fromStream(
        {'infoHash': hash, 'fileIdx': 2, 'name': 'B'})!;
    expect(first.key, second.key);
    expect(
        first.key,
        isNot(WatchPartySource.fromStream({'infoHash': hash, 'fileIdx': 3})!
            .key));
    expect(WatchPartySource.fromStream({'infoHash': hash}), isNull);
    final namedFirst = WatchPartySource.fromStream({
      'infoHash': hash,
      'behaviorHints': {'filename': 'Show.S01E01.mkv'}
    })!;
    final namedSecond = WatchPartySource.fromStream({
      'infoHash': hash,
      'behaviorHints': {'filename': 'Show.S01E02.mkv'}
    })!;
    expect(namedFirst.key, isNot(namedSecond.key));
    expect(namedFirst.key, startsWith('stream:'));
    expect(namedFirst.infoHash, isNull);
  });

  test(
      'audio matches languages across engines, never ambiguous or foreign ordinals',
      () {
    const tracks = [
      AudioTrack('media3:9', 'Original', 'ja'),
      AudioTrack('media3:4', 'Original', 'en'),
      AudioTrack('media3:7', 'Commentary', 'eng')
    ];
    expect(
        matchWatchPartyAudio(
                const WatchPartyAudioSelection(mode: 'track', language: 'ja'),
                tracks,
                null)!
            .id,
        'media3:9');
    expect(
        matchWatchPartyAudio(
            const WatchPartyAudioSelection(mode: 'track', language: 'en'),
            tracks,
            null),
        isNull);
    expect(
        matchWatchPartyAudio(
                const WatchPartyAudioSelection(
                    mode: 'track', language: 'en', title: 'Commentary'),
                tracks,
                null)!
            .id,
        'media3:7');
    final source =
        WatchPartySource.fromStream({'url': 'https://example.test/a'})!;
    expect(
        matchWatchPartyAudio(
            const WatchPartyAudioSelection(
                mode: 'track', index: 0, sourceKey: 'other'),
            tracks,
            source),
        isNull);
    expect(
        matchWatchPartyAudio(
                WatchPartyAudioSelection(
                    mode: 'track', index: 0, sourceKey: source.key),
                tracks,
                source)!
            .id,
        'media3:9');
    expect(
        matchWatchPartyAudio(
                const WatchPartyAudioSelection(mode: 'off'), tracks, source)!
            .id,
        'no');
    expect(
        matchWatchPartyAudio(
                const WatchPartyAudioSelection(mode: 'auto'), tracks, source)!
            .id,
        'auto');
  });
}
