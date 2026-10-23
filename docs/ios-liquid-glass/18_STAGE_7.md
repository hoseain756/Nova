# Final Source-Level Migration Audit

Stage 7 source snapshot: `feature/player-reengineering`, starting HEAD `2ec313bfd18dc72de3281c999ab5207c3cd23d38`, 2026-10-23. The worktree already contained unrelated modified and untracked files; no reset, stash, commit, push or Codemagic build was performed. Findings marked **SOURCE VERIFIED** describe inspected code and Windows tests only. Swift compilation is **IOS BUILD PENDING CODEMAGIC** and native behavior is **IOS RUNTIME PENDING**.

## Implementation Inventory

| File | Introduced / role | Platform impact | Verification |
|---|---|---|---|
| `lib/core/platform/ios_chrome_bridge.dart` | Stage 1 MethodChannel capability, finite snapshot, revision and intent gate; Stages 3–4 action fields; Stage 6 phone idiom | iOS channel; unsupported elsewhere | Dart tests and source review; native peer pending build |
| `lib/app/noor_app.dart` | Stage 2 `ShellChromeRouteObserver` on the existing `MaterialApp` navigator | Shared Dart route observation | Source and widget tests |
| `lib/features/shell/main_shell.dart` | Stage 2 tab snapshot/Flutter selection; Stage 3 search intent; Stage 4 detail projection; Stage 5 route suppression; Stage 6 phone idiom and Reduce Transparency | iOS native on capable phones, Flutter fallback on all other tiers | Dart source and tests; iOS presentation pending runtime |
| `lib/features/media/detail_chrome_registry.dart` | Stage 4 route-keyed detail presentation and Flutter handlers | iOS presentation data only | Dart tests and source review |
| `lib/features/media/media_detail_page.dart` | Stage 4 native detail registration, stable action handlers, fallback control visibility | Capable iOS 26 iPhone only; Flutter actions remain shared | Dart source and detail/bridge tests |
| `lib/features/media/detail_hero.dart` | Stage 4 hides duplicate Flutter top share/More when native detail is confirmed | Capable iOS 26 iPhone only | Detail/widget tests and source review |
| `ios/Runner/AppDelegate.swift` | Stage 1 channel registration on existing implicit engine; Stages 2–4 capability/snapshot dispatch; Stage 6 phone idiom | iOS host only | Swift source review; compile pending |
| `ios/Runner/SceneDelegate.swift` | Stage 2 scene sibling `UITabBar`; Stage 3 glass Home search; Stage 4 detail buttons/menu; Stage 6 scene/safe-area hardening | iOS 26 phone scene only | Swift source review; compile/runtime pending |
| `ios/Runner.xcodeproj/project.pbxproj` | Stage 1.5 Runner and RunnerTests minimum iOS 15.0 | iOS build target | Six settings source checked; compiler pending |
| `codemagic.yaml` | Stage 1.5 pinned unsigned build workflow | CI only | YAML/source checked; workflow unrun |
| `test/ios_chrome_bridge_test.dart` | Stages 1–6 capability, revision, route, action and fallback tests; Stage 7 intent-method regression | Windows Flutter tests | See validation ledger below |

`ios/Runner/Info.plist` already registered the Flutter scene and single-scene policy; `ios/Runner.xcworkspace` already references the Runner project. Neither is a newly added native navigation owner. `test/noor_dock_tabs_test.dart`, `test/shell_edge_to_edge_test.dart`, `test/navigation_bar_style_test.dart`, `test/detail_page_smoke_test.dart`, Kids tests and the selected player tests supply regression evidence, although their production features predate this migration. The Stage 5 audit changed no player production file. Other dirty player, catalog, settings and localization files belong to concurrent work and were left intact.

## Platform Matrix

| Surface | iOS 15–17 | iOS 18–25 | iOS 26 iPhone | iOS 26 iPad | Android |
|---|---|---|---|---|---|
| Main navigation | Flutter dock/rail by window | Same Flutter path | UIKit tab bar when capability and app preference allow; Flutter fallback | Flutter rail at 840+ logical pixels, dock in compact window | Flutter dock/rail by width |
| Home search entry | Flutter button | Flutter button | UIKit glass button on visible Home; Flutter fallback | Flutter search in rail/dock layout | Flutter button |
| Detail back/share/More | Flutter controls | Flutter controls | UIKit buttons and bounded menu on current detail; Flutter fallback | Flutter controls | Flutter controls |
| Search sheet/results | Flutter | Flutter | Flutter | Flutter | Flutter |
| Tablet navigation | Flutter rail/dock by width | Same | Phone idiom retains phone path even in wide landscape | Flutter rail/dock by width; no native sidebar | Flutter rail/dock by width |
| Player | Flutter/media_kit | Flutter/media_kit | Flutter/media_kit; native shell chrome hidden on route | Flutter/media_kit | Flutter/media_kit |
| Settings | Flutter | Flutter | Flutter; no native settings surface | Flutter | Flutter |
| Modals and pushed routes | Flutter | Flutter | Flutter; native shell/detail snapshot suppressed while a higher route is current | Flutter | Flutter |
| Accessibility fallback | Existing Flutter semantics and preferences | Same | App Reduce Transparency selects Flutter controls; UIKit system behavior needs runtime proof | Existing Flutter semantics | Existing Flutter semantics |

The iOS 18–25 fallback is the current NOVA Flutter UI; earlier plans for a separate Cupertino/adaptive replacement were not implemented. This matrix is **SOURCE VERIFIED** only, not a device result.

## Bridge Contract

`nova/ios_chrome/v1` uses `getCapabilities`, `setPresentation`, `dispose`, and native-to-Dart `selectIntent` / `actionIntent`. Capability fields are `osMajor`, `systemGlassAvailable`, `nativeChromeAvailable`, `phoneIdiom`; unknown/missing values decode to unsupported defaults. Android/web bypass the channel. Dart requires native availability, system glass and OS major 26 before publishing. Swift requires iOS 26, phone idiom and a Flutter root view controller before scene presentation.

The finite snapshot fields are `revision`, `selectedId`, `tabs[{id,label,enabled}]`, `visible`, `locale`, `rtl`, `dark`, `active`, `searchVisible`, `searchLabel`, and optional `detail{backLabel,shareLabel,moreLabel,shareEnabled,menu[{id,label,enabled}]}`. Flutter supplies localized labels, direction and appearance; Swift applies direction and appearance. `locale` is validated and carried as contract metadata, while native visible text comes from the localized labels; it is not separately applied to a UIKit locale property. There are no tab badges or inset measurements. No progress ticks, animation frames, gesture data, video frames, subtitle frames or search queries cross this channel.

The shell compares a snapshot signature to skip identical publications and increments a single presentation revision for changes. Dart accepts intents only at its latest revision and only for currently visible/enabled surfaces. Stage 7 also requires `actionIntent` for search/detail IDs and `selectIntent` for tabs; cross-method IDs are rejected. `MainShell` validates known tab IDs and applies the Kids gate; the detail registry validates current route and enabled actions. Swift rejects unknown menu IDs and older snapshots. A failed publication restores Flutter fallback; scene disconnect/dispose removes the overlay. The bridge holds no navigation stack or second Flutter engine. One current caveat remains for Stage 8: scene reconnect and native modal ordering are source-designed but unobserved on iOS.

Stage 7 corrected two narrow source defects: the Dart bridge previously let a `selectIntent` carrying `search` or a detail ID reach the action handler, and its tab gate did not independently reject IDs absent from the current enabled snapshot. The shell also now requires all four positive phone/system/native/version capability fields before switching away from Flutter controls. No wire field or native action was added.

## Native Action IDs

The five stable selection IDs are `home`, `anime`, `kids`, `library`, `settings`. Stable action IDs are `search`, `detail.back`, `detail.share`, `detail.sources`, `detail.list`, `detail.track`. `detail.more` is a native accessibility identifier for the menu button, not a sent action. Labels are presentation text, never identity. Swift maps only known IDs to SF Symbols; Flutter owns the search sheet, pop, share and detail workflows. Unknown, disabled, hidden, wrong-method and stale-revision actions are rejected at the Dart contract/owner boundary. The native tab delegate restores Flutter's confirmed selected item while a Kids decision is pending.

## Navigation Ownership

`MaterialApp` has one Flutter `Navigator` and route observer. `MainShell` owns `_selected`, lazy `_visited`, repeated tab selection and the Kids gate. Primary destinations and secondary pages remain Flutter widgets; details and player use Flutter routes, and deep links remain on the existing `noor/links` path. Search uses a Flutter bottom sheet. Native UIKit emits intents and draws controls; it does not push/pop routes or create a `UITabBarController`, `UINavigationController`, PlatformView or second Flutter engine. The route projection selects one of root tabs/Home search, current detail controls, or no native shell chrome for a player, modal or other pushed route. Home → detail → player → detail → Home and Home → search → Home are covered at source/state level; Kids acceptance/rejection remains in `_selectTab`. iOS route timing and hit regions still need device observation.

## Fallback Audit

AppDelegate reports native chrome unavailable before iOS 26 and on iPad. The Dart bridge also rejects pre-26 capability reports, missing channels and platform errors. `MainShell` requires a confirmed phone idiom, system glass, native availability and OS major 26 before hiding Flutter phone chrome; malformed/missing capability fields leave fallback visible. `MediaDetailPage` hides Flutter detail controls only after a successful native publication identifies its route. App Reduce Transparency returns to Flutter chrome. Known iPhones keep phone layout at wide landscape widths; iPad keeps Flutter width rules. iOS 15–25 code never constructs the scene overlay through a successful capability path; the iOS 26 `glass()` calls are guarded. Flutter fallback and plugin linking still need Stage 8/real runtime proof.

## iOS 26 API Audit

| Call or control | File | Guard and fallback | Expected behavior / pending proof |
|---|---|---|---|
| `UIButton.Configuration.glass()` for Home search | `ios/Runner/SceneDelegate.swift` | Local `#available(iOS 26.0, *)`; overlay creation also requires iOS 26 phone capability | System glass search button; Swift compile and visual behavior pending |
| `UIButton.Configuration.glass()` for detail back/share/More | `ios/Runner/SceneDelegate.swift` | Local `#available(iOS 26.0, *)`; same scene gate | System glass detail controls; compile, placement and menu behavior pending |
| iOS 26 native capability branch | `ios/Runner/AppDelegate.swift` and `SceneDelegate.swift` | Explicit `#available(iOS 26.0, *)`; false otherwise | Gates all native presentation; older runtime proof pending |
| Standalone `UITabBar`, `UIMenu` / `UIAction`, `safeAreaLayoutGuide` | `ios/Runner/SceneDelegate.swift` | Existing UIKit APIs used only inside the capable phone overlay; Flutter controls are fallback | Tab, menu, safe-area composition and touch behavior pending |

No iOS 18-only API call was found in the migration host files. Xcode 26.2 must still compile every Swift symbol and availability branch; a source inspection cannot establish SDK compatibility.

## Accessibility Status

| Item | SOURCE VERIFIED | IOS RUNTIME PENDING |
|---|---|---|
| VoiceOver, tab/button/menu semantics | Localized tab titles and icon-button labels, UIKit standard controls, 48-point top buttons, bounded menu | Spoken order, focus return, rotor/hit behavior, menu dismissal |
| Selected and disabled state | Confirmed `selectedId`, `UITabBarItem.isEnabled`, share `isEnabled`, disabled `UIAction` attributes | Actual announcements and stale focus after route changes |
| Dynamic Type | System tab/menu text; no custom native font size | Clipping and touch reachability at enlarged sizes |
| RTL | Snapshot `rtl`, translated labels, semantic direction, logical safe-area search anchor, directional back symbol | Glyph mirroring, tab/menu focus order and Arabic truncation |
| Reduce Transparency | App preference suppresses native controls and restores Flutter controls | OS setting and visual material response |
| Reduce Motion / Increase Contrast | No custom native animation/tint; Flutter motion handling remains | UIKit adaptation, contrast and animation on device |

## Layout/Safe Area Status

**SOURCE VERIFIED:** the scene overlay autoresizes with the Flutter root; top buttons constrain to `safeAreaLayoutGuide`; search switches leading/trailing anchor with RTL; the system tab bar uses `sizeThatFits` and sits at the overlay bottom. Hit testing passes through transparent overlay space. Flutter keeps existing content clearance, modal routes and keyboard flows; the route snapshot hides native chrome for those routes. Player stays full-screen Flutter and hides shell chrome. No hard-coded device notch or home-indicator offset was added.

**IOS RUNTIME PENDING:** portrait/landscape, Dynamic Island/notch, bottom home indicator, tab bar/content overlap or doubled inset, details over artwork, native menu/share sheet above Flutter, keyboard and modal focus/order, fast push/pop visibility, scene disconnect/reconnect, and reduced-transparency transitions. A bottom-bar inset issue cannot be ruled out from source alone.

## Player Protection

Core-default and Legacy-fallback remain selected by `NOVA_PLAYER_CORE` before engine allocation. Stage 1–7 migration code does not move media_kit video, playback commands, timeline, subtitles, gestures, audio/source/episode panels, skip segments or next episode onto the native bridge. The shell's top-route projection hides tabs/search/detail on either player route, and the bridge rejects hidden/stale intents. See `16_STAGE_5.md` for the complete player surface and measurement plan. Windows tests cover source contracts only; playback, video composition, touch latency and dropped frames on iOS are **IOS RUNTIME PENDING / NOT MEASURED**.

## Android Regression

The bridge exits before channel use on Android. The shell's native flag remains false, so Android retains Flutter navigation, search and detail controls, player and width-based responsive layout. Shared Dart route observation and detail widgets were inspected and included in the regression suite. This is source/test evidence; no Android device was launched in Stage 7.

## Codemagic Readiness

Root workflow `nova-ios-validation` (“NOVA iOS unsigned validation”) requests `mac_mini_m2`, Xcode `26.2` and default CocoaPods. [Codemagic's Xcode 26.2 image](https://docs.codemagic.io/specs-macos/xcode-26-2/) currently lists macOS `26.2 (25C56)`, Xcode `26.2 (17C52)` and CocoaPods `1.16.2`; the actual job must print its toolchain before treating these as build facts. It clones Flutter beta and asserts framework revision `38ec981bad973156ad05bdef0aa8e82d1a58905b` (locally Flutter `3.49.0-0.2.pre`, Dart `3.14.0-211.1.beta`), runs `flutter pub get`, full `flutter analyze --no-pub`, the bridge test, six iOS 15.0 deployment assertions, conditional `pod install`, then `flutter build ios --release --no-codesign --no-pub`. Build artifacts are `build/ios/iphoneos/*.app` and `/tmp/xcodebuild_logs/*.log`. Signing remains automatic in the project but the command requests an unsigned app and no signing secret or distribution step is configured. The iOS 26 glass buttons use the SDK already requested; Stages 2–6 added no other dependency or compiler setting.

`pubspec.yaml`/lockfile contain no third-party Liquid Glass package. Native iOS plugins are listed in `.flutter-plugins-dependencies`; Flutter-generated registration remains in the existing implicit engine. No `ios/Podfile` or `Podfile.lock` is checked in, and the generated plugin metadata says iOS SPM is disabled. The conditional `pod install` step will skip absent Podfile, leaving Flutter's build to expose the actual dependency result. This is the principal unresolved CI risk. The proposed build command is still appropriate for unsigned source compilation/linking after `pub get`; do not change dependency strategy without Stage 8 build evidence. No Mac/Xcode or Codemagic execution happened in Stage 7.

## Validation Ledger

The final command results are recorded here after all Stage 7 source edits. The 20 selected Windows test files cover bridge, shell/navigation, Kids, detail, and Core/Legacy player contracts. An initial broad run found the cross-method/unknown-tab intent defect and failed 1 of 171 tests; after the narrow fix, a focused 16-test bridge rerun and the final 171-test broad rerun passed. These tests cannot validate Swift, native view layering or a physical player run.

| Check | Final Stage 7 result |
|---|---|
| Full `flutter analyze --no-pub` | **PASS, no issues** after final Stage 7 Dart edits (300.1 s). |
| Selected migration and player tests | `flutter test --no-pub` on 20 named migration/player files: **PASS, 171/171** after final source edits. Bridge-only rerun: **PASS, 16/16**. |
| Dart formatting check | Changed Stage 7 Dart files: **PASS, 0 changes**. Repository-wide `dart format --output=none --set-exit-if-changed lib test`: **FAIL** solely on pre-existing modified generated `lib/l10n/nova_messages.g.dart`; left untouched per repository rule. |
| Swift source / iOS 26 availability / stable ID / bridge traffic audit | SOURCE VERIFIED as described above; no Swift compiler |
| Deployment target | Six `15.0` settings source checked; native build pending |
| Codemagic YAML parse and file/path sanity | **PASS** with PyYAML; 7 workflow scripts and 2 artifact patterns parsed; all 19 migration Markdown files have resolvable local links. |
| `git diff --check` and new-file whitespace scan | **PASS** for unstaged/cached diffs and Stage 7 files; Git emitted line-ending notices on existing dirty files. |
| Secret/signing-key scan | **CLEAR** for the changed migration code, Swift host, workflow and Stage 7 record; no new credential or signing artifact. |

## Remaining Native Verification

Stage 8 must run the pinned workflow and collect its exact Flutter/Dart/Xcode/macOS image versions, dependency resolution output, analyzer/test results, Swift/UIKit/availability/plugin linking result and unsigned `.app` artifact. A successful build does not establish native appearance or behavior. Later iOS runtime work must launch supported iOS 15–25 fallbacks, iOS 26 iPhone and iPad; verify scene reconnection, deep links, navigation/Kids, Home/search/detail/player transitions, safe areas, keyboard/modals/share, VoiceOver, Dynamic Type, RTL, appearance and system accessibility settings. Player composition and performance remain unmeasured until controlled device evidence exists.

## Stage 8 Entry Criteria

Stage 7 may hand off the exact working-tree snapshot once full Windows analysis and the checks above are recorded with results. The repository-wide formatting exception in the pre-existing generated localization file is disclosed; the changed Stage 7 Dart files pass. Stage 8 requires explicit user approval and a Codemagic connection/build. Carry the absent Podfile/native-plugin integration as an explicit condition, not as a presumed success. Do not publish or sign the unsigned artifact as an app release. If Stage 8 cannot compile, use its actual logs to make the smallest iOS build fix before any runtime claim.

## Stage Decision

**READY FOR STAGE 8 WITH CONDITIONS.** The source and selected Windows regression gate passed. The conditions are the existing generated-file formatting exception, the unresolved Podfile/native-plugin build path, and truthful preservation of **IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING** until actual Apple-toolchain and device evidence. Stage 8 was not started.
