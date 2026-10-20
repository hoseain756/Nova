# Station 01 — Environment and repository discovery

- Status: COMPLETE ✓
- Verification status: STATIC-ONLY for repository/config findings; the existing Flutter test suite passed (452 tests), but no analyze/build was run at Station 01.
- Checklist: 13/13 tasks complete
- Evidence: `evidence/PHYSICAL_DEVICE_PREFLIGHT.md`, `evidence/INITIAL_GIT_STATUS.txt`, `LICENSE_NOTES.md`, `OWNERSHIP.md`, and `evidence/STATION_01_TEST_BASELINE.txt`.

- [x] Record NOVA root, branch, safety tag, original status, Flutter/Dart/dependency versions. Evidence: repository root `C:\Users\hosea\projects\app\Nova`; feature branch, baseline tag and original status in Station 00 evidence; Flutter 3.49.0-0.2.pre / Dart 3.14.0; app `nova_mobile` version `1.0.3+66`; locked `media_kit` 1.2.6, `media_kit_video` 2.0.1, Android video libs 1.3.8, iOS video libs 1.1.4, provider 6.1.5+1, shared_preferences 2.5.6.
- [x] Map app architecture, state management, UI/responsive system, current video dependencies and player tests. Evidence: repository `AGENTS.md` map; `lib/main.dart` bootstraps `MediaKit.ensureInitialized`, `NovaApp`, `AppState`, catalog repository and torrent services; feature code is under `lib/features/player/`; provider is state-management dependency. Player-related test files listed below.
- [x] Inventory Android/iOS configuration, Info.plist, Podfile, AppDelegate, deployment targets, and codemagic.yaml. Evidence: Android Kotlin DSL, AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14; Android namespace `app.noor.mobile`, application ID `app.nova.mobile`, SDK values use Flutter defaults; iOS deployment target 13.0, Swift 5.0; `ios/Podfile` absent; `codemagic.yaml` absent; `ios/Runner/Info.plist` allows portrait/landscape on iPhone and all orientations on iPad, has no `UIBackgroundModes` key or usage-description keys; `AppDelegate.swift` registers Flutter plugins through implicit engine callback; CI is `.github/workflows/release.yml` (analyze, tests, Android release APK).
- [x] Record the completed Section 0.3 device preflight and use the exact device ID consistently. Evidence: Station 00 device report; only `RF8NA2NNVNY` is selected; no emulator used.
- [x] Verify the three local reference repos, their branch/SHA/tags, language/framework, engine/dependencies, and upstream cross-check. Result: all three requested local paths are absent (`Test-Path` false), so local commit/tag/framework cannot be observed. Upstream repositories and current default refs were verified through read-only GitHub API; see version table. This is not represented as local-clone evidence.
- [x] Attempt read-only access to Jellyfin Android/iOS and mpv-qol-scripts; record revision or explicit access blocker. GitHub API and exact default-branch commit metadata/file contents are accessible. Shallow clone attempts followed Section 0.7 but `git -C` on the external clone paths returned `Permission denied`; source inspection uses GitHub API at recorded SHAs.
- [x] Determine Jellyfin iOS playback stack; decide whether Swiftfin is needed based on source evidence. `package.json` at the recorded iOS SHA depends on Expo AV; `components/VideoPlayer.js:10-13` imports Expo AV `Video`/`Audio`; `assets/js/plugins/NativeVideoPlayer.staticjs:8-13` identifies the bridge as ExpoVideoPlayer. The project wraps a cross-platform Expo module and does not contain its native AVPlayer implementation, so Swiftfin is included as an additional native iOS reference. Swiftfin source at `Shared/Objects/MediaPlayerManager/MediaPlayerProxy/MediaPlayerProxy+AVPlayer.swift:10-30` directly instantiates an `AVPlayer`; it also contains distinct MPV/VLC proxies, so engine selection must be checked in Station 06B.
- [x] Record REA availability and clean-room fallback. No REA tool is available in this session; use direct source inspection and label unsupported inferences appropriately.
- [x] Create LICENSE_NOTES.md for each named reference and classify license state. See file; all exact license headers and refs recorded.
- [x] Create OWNERSHIP.md matching Section 54 ownership; no agent writes. See file; Section 54A read-only policy supersedes older output-file suggestions.
- [x] Inventory existing test streams and compare to Section 49 matrix without inventing availability. No user-supplied stream was attached; no playable sample media is stored in NOVA. App sources are provider/torrent-derived and not deterministic public fixtures. Placeholder example URLs in unit tests are synthetic, not playable. Section 49 cells HLS/direct HTTP, 720/1080/4K, H.264/HEVC, embedded/external subtitles, multiple audio, lifecycle and interactions remain NOT MEASURED until a valid stream is selected.
- [x] Run the existing player-related test subset once as baseline and save exact command/result. The full suite passed: 452 tests, exit code 0. Logical command: `flutter test --no-pub`. The `flutter.bat` wrapper stalled before launching Dart in the sandbox; the Flutter tool snapshot ran with its normal package configuration outside the sandbox after the SDK cache lockfile access failure. Full raw output: `evidence/STATION_01_TEST_BASELINE.txt`; initial launcher error: `evidence/STATION_01_TEST_SANDBOX_ERROR.txt`.
- [x] Update repository map/evidence and acceptance state. Files and evidence are listed above; Station 01 checkpoint is committed separately.

## Player-related automated tests found

`test/playback_segments_test.dart`, `test/player_settings_panel_test.dart`, `test/player_sheet_host_test.dart`, `test/nova_player_direction_test.dart`, `test/nova_playback_preferences_test.dart`, `test/nova_completion_player_semantics_test.dart`, `test/gesture_math_test.dart`, `test/subtitle_style_test.dart`, `test/subtitle_settings_sync_test.dart`, `test/subtitle_overlay_widget_test.dart`, `test/resume_snapshot_store_test.dart`, `test/stream_server_creation_wait_test.dart`, `test/torrent_stream_hints_test.dart`, `test/torrent_source_helpers_test.dart`, and `test/app_state_tracking_progress_test.dart`. These are file-name inventory only; tests are not considered passed until the baseline process completes.

## Reference snapshot

| Repository | Local path | Upstream inspected ref | SHA | Framework / initial stack evidence |
|---|---|---|---|---|
| Harbor | `C:\Users\hosea\projects\app\player-references\harbor` absent | `Harborofficial/Harbor`, `beta-branch` | `9b811556d13f6eb2ba7c524a5bb0d561c88fae94` | Repository metadata identifies MIT; upstream project page describes Tauri/React with native libmpv plus WebView2 / HLS.js / MPEG-TS.js selectable paths. Exact stack audit belongs to Station 04. |
| NuvioMobile | `C:\Users\hosea\projects\app\player-references\NuvioMobile` absent | `NuvioMedia/NuvioMobile`, `cmp-rewrite` | `324afcffb962f1f7df45c5fa951131acec5a15a7` | Kotlin Multiplatform / Compose; root tree includes Android ExoPlayer engine modules, MPVKit and platform-specific playback. Confirm selected/default engines in Station 05. |
| Stremio-Kai | `C:\Users\hosea\projects\app\player-references\Stremio-Kai` absent | `allecsc/Stremio-Kai`, `main` | `a5a2a37e818fb5e9406caf65af374fa7fe7700af` | GPL-3 fork distributed as preconfigured Stremio/MPV; inspected tree includes portable MPV configuration. Detailed engine behavior in Station 06. |
| Jellyfin Android | No local repo; shallow clone path unreadable to Git in sandbox | `jellyfin/jellyfin-android`, `master` | `3e660a84bde87281adee8f092b8af48719734916` | Kotlin app; `PlayerViewModel.kt:15-25` imports Media3 ExoPlayer APIs; exact optional engines/detail in 06A. |
| Jellyfin iOS | No local repo; shallow clone path unreadable to Git in sandbox | `jellyfin/jellyfin-ios`, `master` | `ceca8eb14ef79e2c0d7bde99d95213c7d69d131d` | React Native/Expo AV wrapper; backend implementation outside this repo, so supplemental Swiftfin reference selected. |
| Swiftfin | No local repo | `jellyfin/Swiftfin`, `main` | `f9842d500f2b1c3178bebbcbf67d6b82d21d47ec` | Native SwiftUI app; AVPlayer and MPV/VLC proxy files present. |
| mpv-qol-scripts | No local repo; shallow clone path unreadable to Git in sandbox | `allecsc/mpv-qol-scripts`, `main` | `e0b04926f00ce3d482120d5bf15ebc0e32f7d94a` | MPV Lua scripts/config; supplementary only. |

Exact licenses and source URLs are in `LICENSE_NOTES.md`. The API source refs are version snapshots from 2026-10-21; local repositories were not available for equivalence checks.

## Baseline test attempt status

Result: exit code 0; all 452 tests passed (1:19 test-run duration in Flutter output). The `flutter.bat` wrapper stalled before reaching the Dart test process in the sandbox, and a direct sandbox run reported an inaccessible Flutter SDK cache lockfile. Running Flutter's own `flutter_tools.snapshot test --no-pub` entry point with the SDK package configuration and approved elevated access completed successfully. Raw output is `evidence/STATION_01_TEST_BASELINE.txt`; failed direct sandbox attempt details are `evidence/STATION_01_TEST_SANDBOX_ERROR.txt`.

## Blockers / unknowns

- No deterministic user-supplied playable test streams. Baseline stream coverage cannot be established until a real valid stream is chosen.
- Local Harbor, NuvioMobile, and Stremio-Kai clones are unavailable. Comparison uses specified upstream GitHub snapshots; upstream may differ from the user's local intended versions.
- External clone checkout folders cannot be read through `git -C` under this sandbox. GitHub API source reads work at exact recorded commit refs.
- Android codec service was unavailable; preflight codec classification is based on device vendor XML and is not runtime decoder selection proof.
- No iOS build/runtime verification is possible here; `codemagic.yaml` is absent and Station 18 owns any later changes.

## Commit / LKG

Station 01 documentation checkpoint pending commit. Production code is unchanged; last-known-good production tree remains the initial baseline `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
