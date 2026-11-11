# NOVA v1.0.7 (build 70)

Both Android and iOS use `1.0.7+70` from pubspec.yaml. Tag: `v1.0.7`.

## Changes

- Join the exact room episode directly through the local source picker.
- Correct playback synchronization, native command rejection and startup alignment.
- Shared playback controls by default; existing rooms retain their chosen mode.
- Separate room/chat tabs, pinned composer, accessible Arabic/English layouts.
- Retire the previous native player before changing the room title.

## Build and upload

- Android: the tag triggers `.github/workflows/release.yml`. It runs analysis,
  tests and APK build, then saves `nova-android-v1.0.7` as a workflow artifact.
  This workflow does not publish release assets. Its debug signing fallback is
  unsuitable for upgrading installs signed with another key. Build/sign with
  the installed app's original signing key before uploading `app-release.apk`
  to the GitHub Release for this tag.
- iOS: select tag `v1.0.7` and YAML workflow `nova-ios-validation` in Codemagic
  (`NOVA iOS Release IPA (iLoader)`). Download `Nova-release-unsigned.ipa` and
  sign it with the existing iLoader process. The YAML does not automatically
  start on tags; native compilation and updated two-phone acceptance remain
  pending. The IPA is unsigned and is not an App Store submission artifact.
- The Android manifest points to this tag's `app-release.apk`; that link becomes
  usable only after the matching asset is uploaded and the release is published.
  iOS update notices remain disabled until a real installation destination is
  available; the Android build number does not trigger iOS notices.

The prior local APK was `1.0.6+69`; rebuild from this tag for build 70.

## Validation

Before the version-only release preparation: 925 Flutter tests, full analysis,
Android arm64-targeted Release build and rollback-SQL checks passed. The version
preparation additionally checks version pinning, the root release manifest,
previous-build update detection and plain-text JSON decoding. These checks do
not establish corrected synchronization on physical Android/iPhone devices.
