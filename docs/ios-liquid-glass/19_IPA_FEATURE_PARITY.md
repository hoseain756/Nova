# iPhone IPA and Android feature parity — 2026-10-26

## Evidence boundary

An IPA is an installation container, not a feature-parity certificate. Shared Dart
code and passing unit/widget tests do not establish iPhone playback, provider
accounts, background execution, or installation through iLoader. Runtime acceptance
must record the device model, exact iOS version, source commit, and result.

## Correct Codemagic configuration

The Codemagic app was using **Workflow Editor / Default Workflow**, configured for
Flutter stable, Debug, and the latest Xcode. Build
`6adf16a04a72334e32e5432f` used source commit `7ddedf2` but did not execute the
repository YAML. Its `Runner.app.zip` contains `kernel_blob.bin`,
`vm_snapshot_data`, and `isolate_snapshot_data`; it is a Debug app.

The hosted app configuration was changed to **codemagic.yaml** on 2026-10-26.
The workflow ID remains `nova-ios-validation`; its display name is
**NOVA iOS Release IPA (iLoader)**. It runs analysis and the complete Flutter test
suite, builds with `--release --no-codesign`, rejects Debug assets, and packages
`Payload/Runner.app` as `Nova-release-unsigned.ipa`. The IPA is the app artifact;
iLoader must sign it during installation. Repacking the old Debug ZIP cannot
convert it into a Release build.

The first YAML attempt, build `6adf1af94a72334e32e54496` on commit `7ddedf2`,
passed analysis but failed two of the 694 tests on macOS. Both failures were in
download metadata reload: raw `/var/...` paths did not match the canonical
`/private/var/...` root. The fix compares canonical existing parents while keeping
UUID/file-name checks, outside-root rejection, and root/leaf symlink rejection.
The added regressions cover an ancestor alias with both present and missing files,
and a leaf symlink to an external file.

Build `6adf1d484a72334e32e5455c` on `a61be1e` then passed analysis and all
**696/696** Flutter tests on Mac. The dependency-preparation step failed because
the fresh pinned SDK did not contain `bin/cache/artifacts/engine/ios/Flutter.xcframework`.
Flutter dependency resolution had generated `ios/Podfile`; its manual CocoaPods
post-install hook requires `flutter precache --ios` first. The workflow now
downloads those engine artifacts immediately after pinning the SDK.

Build [`6adf1f0d4a72334e32e545f2`](https://codemagic.io/app/6adbc1f069a10a5bbaeee762/build/6adf1f0d4a72334e32e545f2)
on commit `ffdee0e9053438860289ec631f39b5d7343b2ee1` passed analysis,
**696/696** Flutter tests, CocoaPods, the iOS Release compiler/linker and IPA
packaging. The downloaded IPA is 19,847,214 bytes and passed archive validation;
SHA-256 `09E75AC51E18090FF65CE9C1A5B16BAEEBDD455E5FC98E1FD379E8E12F64C121`.
It contains `Payload/Runner.app` and `App.framework/App` without the Flutter
Debug kernel or snapshot assets. The user reports opening it on iOS 26.6. Direct
sources appeared; torrent add-on results were absent. The reported missing
episode button was on a movie, where the button is intentionally not shown.
The user requested that the NOVA logo be centered across the About page
without a card around the logo and version; that shared Flutter header has
been updated after this build. The icon-only iPad rail is present in the
compiled source, but no physical iPad result has been supplied. Both changes
need a new IPA/device review before runtime acceptance.

## Source-level feature inventory

| Feature | iOS implementation / difference | Acceptance evidence still needed |
| --- | --- | --- |
| Home, catalogs, anime, Discover, search, details and episodes | Shared Flutter features and repository data layer. The player episode button is intentionally shown for series, not movies | Arabic/English, series episode/season switching, navigation, network errors and real add-ons on device |
| Kids and parental gate | Shared Flutter authorization, including route handling | Gate persistence and all entry paths on device |
| Library, history, Continue Watching and resume | Shared AppState/storage/checkpoint code | App relaunch, actual video seek and linked-provider reconciliation |
| Direct HTTP(S) video and live sources | media_kit/libmpv on iOS | Real files, streams, codecs, headers and seek capabilities |
| Media3 backend selection | Android Core offers Auto (default), Media3 ExoPlayer and libmpv; Legacy uses libmpv. iOS selects libmpv and the Playback settings page shows that fact without offering an unusable Media3 choice | Rebuild and confirm Android option selection and iOS read-only engine label; verify equivalent controls and playback through libmpv on device |
| Subtitles, imported files/fonts, appearance and delays | Shared controls plus iOS file-picker/storage plugins and libmpv | Native file picker, font import, embedded/external tracks and file-styled libass rendering |
| Skip markers, external timing and Up Next | Shared Core/Legacy implementations | Timing against real frames, source/episode continuity and automatic advance |
| OLED, themes, accessibility and language | Shared Flutter preferences; guarded UIKit presentation on supported phones | VoiceOver, Dynamic Type, Reduce Transparency, rotation and keyboard |
| About page and tablet rail | About page uses the shared Flutter `SettingsAboutPage` on Android/iOS, with platform-specific update action. The About logo is centered without its former enclosing card in the next build. A 72-point icon-only Flutter rail is selected for windows at least 840 points wide when the device is not a phone; compact iPads use the dock | Rebuild, compare About on the iPhone and Android, then verify rail, labels and navigation on a physical iPad |
| OAuth/tracking/sync | Shared services; `noor` and `app.noor.mobile` callback schemes registered in Info.plist | Real provider accounts and cold/warm callback return |
| Sharing | `share_plus` plugin included for iOS | Native share sheet and correct shared item |
| Direct-file offline downloads | In-process Dio worker on iOS; shared queue, cancel/retry, validation, persistence and local playback UI | Completion/cancel/retry/open/remove on a real iPhone |
| Background direct-file downloads | **NOT IMPLEMENTED as an iOS background transfer service**; Dart worker cannot promise continuation while suspended | Implement a persisted background URLSession adapter, then test lifecycle and completion |
| On-device torrent playback / magnet flow | **NOT IMPLEMENTED on iOS**; no `noor/torrent` native handler. `TorrentService.isSupported` returns false. An iOS 26.6 user report confirmed that the source picker hid torrent results without Debrid; a follow-up source change keeps them visible but disabled with a reason | Requires a native iOS torrent engine and lifecycle integration; packaging cannot provide it. Rebuild and retest the visibility change |
| On-device torrent offline download | **ANDROID ONLY**; `enqueueTorrent` rejects non-Android native capability | Requires an iOS transfer implementation; cannot reuse Android's service |
| Debrid-backed torrent sources | Existing resolver can supply HTTP(S) URLs without local P2P | Real linked Debrid account, source resolution and download/playback |
| Android download notifications/service | Android-specific implementation; no equivalent iOS completion-notification implementation here | Native iOS implementation and permission/device checks |
| External magnet links | Android registers `magnet`; iOS currently registers only the two OAuth schemes and has no local torrent backend | Do not advertise external magnet/P2P parity on iOS |
| In-app updates | Android APK manifest/install mechanism; iOS is protected from Android build-number enforcement | iOS distribution remains iLoader or a separately configured Apple distribution path |

Sources inspected: `lib/core/downloads/download_manager.dart`,
`lib/core/torrent/torrent_service.dart`, `lib/features/torrent/magnet_opener.dart`,
`lib/features/media/media_detail_page.dart`,
`lib/features/player/engine/playback_backend_preference.dart`,
`lib/features/player/engine/playback_engine.dart`,
`lib/core/update/app_update_service.dart`, `ios/Runner/Info.plist`,
`ios/Runner/AppDelegate.swift`, and `ios/Runner/SceneDelegate.swift`.

Existing relevant regression coverage includes `nova_download_manager_test.dart`,
`download_source_filter_test.dart`, `media3_policy_test.dart`,
`subtitle_iphone_compat_test.dart`, `subtitle_local_import_ui_test.dart`,
`ios_chrome_bridge_test.dart`, and the player/session/settings suites. These are
unit/widget tests, not physical-iPhone acceptance.

## Runtime checklist

Run on an iPhone with iOS 18 and an iPhone with the newest iOS version actually
available on the user's devices. Record each exact version instead of inferring
it from the deployment target or build SDK.

- Install the Release IPA through iLoader and launch it from the Home Screen
  without attaching a Flutter debugger.
- Exercise browse/search/details/Kids/library/settings in Arabic and English.
- Play a direct movie and episode, seek, pause/resume, rotate, leave/re-enter the
  app, restore progress and change source/episode.
- Select embedded/external/local subtitles, import a font, change appearance,
  test file styles and audio/subtitle offsets.
- Download a direct video, cancel/retry it, complete/open it offline and remove it.
  Treat background continuation as an open implementation gap.
- Link each used provider, complete its callback, and verify synced progress.
- Check iOS 18 Flutter chrome and newer iPhone native chrome independently.

Full Android/iOS feature parity remains **NOT ACHIEVED** while the native torrent
and background-download gaps above remain open. A successful Release build must
not change that status.

## Platform references

- [Apple: downloading files in the background](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background)
  describes a background URLSession implementation; it is not present in NOVA's
  current iOS host.
- [Apple: background session configuration](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/background(withidentifier:))
  distinguishes system termination from user force-quit. Even a future iOS
  background-download implementation must respect those lifecycle rules.
- [Codemagic YAML configuration](https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/)
  defines the repository workflow selected for the Release build.
- [iLoader](https://github.com/nab138/iloader) supports importing an IPA. Actual
  signing/install/launch on the user's device remains a separate result.
