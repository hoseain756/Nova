# Testing and evidence strategy

The Stage 0–6 ledgers below are historical. Stage 7's final Windows results and Stage 8 entry conditions are recorded in `18_STAGE_7.md`; no iOS build or runtime evidence exists yet.

## Evidence levels

| Level | What it establishes | Current status |
|---|---|---|
| Source inspection | Existing architecture, target, candidate contract | Completed |
| Flutter static/unit/widget | Dart compatibility and Flutter behavior | Run only if changed Dart needs verification; no Dart changed in Stage 0 |
| Swift/iOS compile | Availability and deployment compatibility | Not possible on this Windows host |
| iOS simulator | Basic layout, scene/lifecycle and older-version checks | Not possible here; cannot substitute for material/device proof |
| Physical iOS device | Actual glass response, VoiceOver, touch, rendering/performance | Not possible here; required before GO |

## Stage 0B proof matrix on a Mac

Build against a current iOS SDK with deployment target **15.0**. Compile and launch on iOS 15–17 where available, iOS 18, latest available pre-26 release, and iOS 26+. Compare iPhone portrait/landscape and iPad portrait/landscape; test light/dark and Arabic/English. Capture screen recording/stills showing content moving beneath the native bar, idle/selection/scroll response and reduced-transparency appearance. Record SDK/Xcode, device/runtime, commit, flags, and file hashes with each artifact.

Test selected tab synchronization, rejected Kids entry, returning from Kids, deep links, repeated taps, scene background/foreground, orientation, keyboard, Flutter route push/pop, Flutter sheet/dialog above the bar, native tap hit region, touches outside the bar, safe-area clearance, VoiceOver/focus, Dynamic Type, Reduce Motion, Reduce Transparency and Increase Contrast. Verify that the native bar is not visible over the protected player and that the Flutter fallback appears if native setup fails. Measure raster/UI frame times and route/input latency versus the same device/build without the experimental native bar; report raw run conditions rather than an unsupported percentage claim.

Future stages add Flutter contract/state/widget tests, Swift availability/lifecycle tests, visual comparisons, Android regression tests and a separate player matrix. No native test was run in this Stage 0 checkout.

## Checks actually run in this Windows Stage 0 session

- `flutter --version` and `dart --version`: returned the versions recorded in `01_CURRENT_UI_AUDIT.md`.
- `rg -n 'IPHONEOS_DEPLOYMENT_TARGET|SWIFT_VERSION|TARGETED_DEVICE_FAMILY' ios/Runner.xcodeproj/project.pbxproj`: confirmed target and Swift settings.
- `Get-Command xcodebuild,swift -ErrorAction SilentlyContinue`: returned no Apple compiler/build command.
- `git branch --show-current`, `git rev-parse HEAD`, `git status --short`: captured branch, commit and pre-existing dirty worktree.
- `rg`/`Get-Content` reads of `AGENTS.md`, README, product/design docs, shell, theme, player, iOS host and relevant UI files: source audit only.
- `git diff --check`: exited successfully; Git printed existing line-ending conversion warnings. It does not include new untracked documentation files.

No Flutter analysis/tests were run because Stage 0 changed no Dart or Swift source. No iOS build, simulator, device, screenshot, or performance check was run.

## Stage 1 verification

`test/ios_chrome_bridge_test.dart` covers Android/unsupported no-op behavior, capability decoding, low-frequency snapshot publishing when enabled, duplicate revision suppression, disposal, missing-channel fallback and iOS 15's disabled native chrome. Focused `flutter analyze --no-pub lib/core/platform/ios_chrome_bridge.dart test/ios_chrome_bridge_test.dart` passed after the final capability guard. Full-project `flutter analyze --no-pub` passed with no issues (183.8 s) before that final guard; the final change was covered by focused analysis. An initial concurrent Flutter-test attempt collided in Flutter's local test cache (`PathExistsException`); after the orphan compiler was stopped, serial reruns passed, most recently 4/4. The Codemagic YAML parsed with Python PyYAML, the changed Dart files passed a formatting check, and `git diff --check` exited 0 with line-ending warnings on pre-existing dirty files. No broader Flutter tests were run because this is an unwired transport change.

Native Swift compilation, unsigned iOS linking, iOS 15 runtime compatibility, Apple-glass appearance, and Codemagic workflow execution are **IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING**. The workflow prepares `flutter build ios --release --no-codesign --no-pub`; it is not a signed distribution build.

## Stage 1.5 Windows verification

`flutter analyze --no-pub` passed with no issues (411.5 s). `flutter test --no-pub test/ios_chrome_bridge_test.dart` passed 4/4. The two bridge Dart files passed `dart format --output=none --set-exit-if-changed` with no changes. Python PyYAML parsed `codemagic.yaml`. Repository search found six `IPHONEOS_DEPLOYMENT_TARGET = 15.0` declarations (Runner project plus Runner and RunnerTests configurations), no build-authoritative iOS 13 declaration, and no `MinimumOSVersion` or Podfile. The remaining iOS 13 text is historical Stage 0 audit/decision, an external package claim, or documentation of the version transition. `git diff --check` exited 0 with line-ending warnings on pre-existing modified files. No iOS build or runtime check was run.

## Stage 2 source implementation (2026-10-23)

The iPhone path now uses a scene-scoped standalone UIKit `UITabBar` over the single `FlutterViewController` on iOS 26+, selected by a capability handshake. `MainShell` remains the sole selected-tab and Kids-gate authority. Stable IDs are `home`, `anime`, `kids`, `library`, `settings`; Flutter supplies Arabic/English labels, direction, visibility and confirmed selection. UIKit SF Symbols are `house`, `sparkles`, `figure.child`, `books.vertical`, `gearshape`. Native taps send intent and restore the previously confirmed selection until Flutter publishes a new snapshot. Reselect preserves the existing chrome-reveal behavior; custom dock scrub is absent on the native path per LG-03. A Navigator observer hides chrome for pushed routes and sheets; scroll sends visibility changes. The existing Flutter content clearance remains, pending iOS visual proof. iOS 15–25 and Android keep GlassDock; tablet keeps its rail. Swift compilation, native composition, safe-area and accessibility runtime checks remain IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING. Stage 3 is not started.

## Stage 3 Windows verification (2026-10-23)

`14_STAGE_3.md` records source candidates and platform decisions. The focused bridge suite covers unsupported platform, iOS 15/18 fallback, iOS 26 snapshot/intent, stale and unknown action rejection, disposal, pushed routes and modal visibility. The iOS 26 snapshot carries translated label, RTL and appearance state. Swift source inspection checks the iOS 26 availability guard around `.glass()`, the stable `search` ID and the single scene overlay; this is not Swift compilation. No Codemagic or iOS device run was authorized. **IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING**.

Final Stage 3 Windows results after the last Dart source edit: full `flutter analyze --no-pub` **PASS**, no issues (101.2 s); `flutter test --no-pub test/ios_chrome_bridge_test.dart` **PASS, 8/8**; `dart format --output=none --set-exit-if-changed` on the three changed Dart files **PASS, 0 changes**. `git diff --check` **PASS**; Git emitted line-ending notices for pre-existing dirty files. Swift source review found `.glass()` inside `#available(iOS 26.0, *)`, with iOS 26 phone capability gating and stable `search` ID; no Swift compiler was available on Windows. Stage 3 untracked/new source and documents were separately scanned for trailing whitespace and passed. No Codemagic, simulator or physical iOS run occurred.

## Stage 4 Windows verification (2026-10-23)

After the final Stage 4 Dart edits, full-project `flutter analyze --no-pub` **PASS**, no issues (58.2 s). `flutter test --no-pub test/ios_chrome_bridge_test.dart` **PASS, 12/12**. The focused suite covers unsupported Android transport, iOS 15/18/25 fallback, iOS 26 detail serialization, stable back/share/menu intents, stale revision and disabled-state rejection, route/modal visibility, route-keyed Flutter dispatch, localized/RTL snapshot updates and the Flutter action-row fallback. `dart format --output=none --set-exit-if-changed` on the six Stage 4 Dart/test files **PASS, 0 changes**. `git diff --check` **PASS**; Git printed line-ending notices for pre-existing dirty files. New and edited Stage 4 documentation/source files were separately scanned for trailing whitespace and passed.

Swift source inspection found `.glass()` within `#available(iOS 26.0, *)`, the existing phone capability gate, `safeAreaLayoutGuide` anchors, a bounded `UIMenu`/`UIAction` ID map and no PlatformView or second navigation owner. The Xcode project still declares iOS 15.0. Apple API documentation for [glass button configuration](https://developer.apple.com/documentation/uikit/uibuttonconfiguration), [UIAction](https://developer.apple.com/documentation/uikit/uiaction), [menu attachment](https://developer.apple.com/documentation/uikit/uicontrol/showsmenuasprimaryaction), and [safe-area layout](https://developer.apple.com/documentation/uikit/uiview/safearealayoutguide) was reviewed. This inspection does not compile Swift. `codemagic.yaml` was not changed or run. **IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING**; no simulator, physical iOS device, native screenshot or performance test was run.

## Stage 5 Windows verification (2026-10-23)

After the final Dart change, full-project `flutter analyze --no-pub` **PASS, no issues** (152.7 s). The previous run reported one `curly_braces_in_flow_control_structures` info in the new shell guard; it was fixed before this final full rerun. The focused bridge suite `flutter test --no-pub test/ios_chrome_bridge_test.dart` **PASS, 14/14**. The selected bridge/player command covering `ios_chrome_bridge_test.dart`, `playback_entry_page_test.dart`, `playback_session_test.dart`, `playback_segments_test.dart`, `player_skip_segment_pill_test.dart`, `player_timeline_progress_test.dart`, `player_episodes_sheet_test.dart`, `player_sheet_host_test.dart` and `player_settings_panel_test.dart` **PASS, 114/114**. The bridge rerun includes the final Home-search restoration assertion; production semantics were unchanged between the selected suite and rerun.

`dart format --output=none --set-exit-if-changed` on Stage 5 Dart/test files **PASS, 0 changes**. `git diff --check` **PASS** (Git emitted line-ending warnings for pre-existing dirty files). A separate trailing-whitespace scan of the new/untracked Stage 5 document and bridge/test source found no matches. Swift source inspection found existing `#available(iOS 26.0, *)` guards around `.glass()`, scene phone gating, revision comparison, and visibility/hit-test rules; no Swift file or iOS build setting changed. A repository search found no `UiKitView`/`FlutterPlatformView` or `player.*` native action ID in the player/bridge/shell source. The Dart snapshot test asserts the finite bridge field set and no playback, timeline, gesture, subtitle-frame or video-frame data. These are source/state checks only: **IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING**. `codemagic.yaml` was neither changed nor run.

## Stage 6 Windows verification (2026-10-23)

After the final Stage 6 Dart edits, full `flutter analyze --no-pub` **PASS, no issues** (378.7 s). `flutter test --no-pub` on `ios_chrome_bridge_test.dart`, `noor_dock_tabs_test.dart`, `shell_edge_to_edge_test.dart`, `playback_entry_page_test.dart`, `playback_session_test.dart`, `playback_segments_test.dart`, `player_skip_segment_pill_test.dart`, `player_timeline_progress_test.dart`, `player_episodes_sheet_test.dart`, `player_sheet_host_test.dart`, and `player_settings_panel_test.dart` **PASS, 121/121**. An earlier focused four-file bridge/shell run passed 22/22. The final broad run includes the updated detail-modal, iPad-width, stale-publish and Reduce Transparency state assertions. `dart format --output=none --set-exit-if-changed` on the three Stage 6 Dart/test files **PASS, 0 changes**. `git diff --check` and cached diff check **PASS**; Git emitted line-ending notices for pre-existing dirty files. A separate trailing-whitespace scan of Stage 6 untracked/new sources and document returned no matches.

Swift source inspection found the iOS 26 availability guards around `.glass()`, phone-idiom capability, `safeAreaLayoutGuide` anchors for top controls, translated labels, explicit semantic direction, standard enabled/menu state, scene-owned overlay removal and no global presentation copy. The Xcode project still targets iOS 15.0. The finite bridge payload and action search found no player, gesture, timeline, scroll-offset, frame or animation traffic, no native iPad sidebar, second engine, PlatformView or new third-party glass dependency. These are **SOURCE VERIFIED** checks, not Swift compilation or UI observation. `codemagic.yaml` and `13_CODEMAGIC_READINESS.md` were unchanged. **IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING**.
