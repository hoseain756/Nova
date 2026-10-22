import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/models/playback_resume_policy.dart';

void main() {
  test('start and prompt choices preserve the existing 30-second boundary', () {
    const settings = {'resumePlayback': true, 'resumePrompt': true};
    expect(PlaybackResumePolicy.action(settings, null),
        ResumePlaybackAction.startOver);
    expect(PlaybackResumePolicy.action(settings, 30000),
        ResumePlaybackAction.resume);
    expect(PlaybackResumePolicy.action(settings, 30001),
        ResumePlaybackAction.prompt);
    expect(
        PlaybackResumePolicy.action(
            {'resumePlayback': false, 'resumePrompt': true}, 30001),
        ResumePlaybackAction.startOver);
    expect(PlaybackResumePolicy.canRecord(awaitingResumeChoice: true), isFalse);
    expect(PlaybackResumePolicy.canRecord(awaitingResumeChoice: false), isTrue);
  });

  test('restore seeks keep the existing five-second end margin', () {
    expect(PlaybackResumePolicy.safePositionMs(10000, 0), 0);
    expect(PlaybackResumePolicy.safePositionMs(10000, 4500), 0);
    expect(PlaybackResumePolicy.safePositionMs(600000, 600000), 595000);
    expect(PlaybackResumePolicy.safePositionMs(-1, 600000), 0);
  });

  test('pause, completion and frame cleanup share the exact boundary', () {
    const duration = 600000;
    expect(PlaybackResumePolicy.isBeforeCompletion(479999, duration), isTrue);
    expect(PlaybackResumePolicy.canCaptureFrame(479999, duration), isTrue);
    expect(PlaybackResumePolicy.isComplete(479999, duration), isFalse);
    expect(PlaybackResumePolicy.isBeforeCompletion(480000, duration), isFalse);
    expect(PlaybackResumePolicy.canCaptureFrame(480000, duration), isFalse);
    expect(PlaybackResumePolicy.isComplete(480000, duration), isTrue);
    expect(PlaybackResumePolicy.canCaptureFrame(0, duration), isFalse);
    expect(PlaybackResumePolicy.isComplete(600000, 0), isFalse);
    // Preserve the existing short-media rule; changing it needs a data review.
    expect(PlaybackResumePolicy.isComplete(0, 60000), isTrue);
  });
}
