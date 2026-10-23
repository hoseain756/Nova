# NOVA iOS Liquid Glass — master plan

Status: **Stages 1–6 source work complete; Stage 7 final source audit in `18_STAGE_7.md`; IOS BUILD PENDING CODEMAGIC; IOS RUNTIME PENDING** (2026-10-23). No iOS build, simulator run or device run has occurred in this Windows environment.

## Objective and boundaries

Keep Flutter as owner of routes, selected destination, Kids authorization, search, deep links, state and playback. Use genuine Apple system presentation on iOS 26+ only where appropriate. The minimum target is iOS 15: iOS 15–17 keeps the existing compatible interface; iOS 18–25 may gain adaptive controls but is not genuine Liquid Glass. Android remains unchanged. The player video and primary overlays stay Flutter.

## Stage 0 result

Source inspection supports a narrow UIKit chrome adapter and a discrete Flutter ↔ iOS intent channel. It does **not** prove that a native tab bar can sample or respond to Flutter-rendered content. A Mac with an iOS 26 SDK and an iOS 26 test runtime is required for that proof. Stage 0 created documentation only; no native prototype or production migration was added.

## Historical Stage 0 advancement gate

On a Mac, build an isolated native tab-bar experiment that leaves `GlassDock` as the operational fallback. Verify composition, interaction, fallback builds/runs, routing/Kids semantics, accessibility, and frame-time impact using `09_TESTING_STRATEGY.md`. Record evidence in this directory and obtain a separate Stage 1 approval. Failure to demonstrate authentic native material is a **NO-GO** for replacing the dock; a Flutter-drawn approximation cannot satisfy the objective.

See the [decision register](12_DECISION_REGISTER.md), [architecture](04_PLATFORM_ARCHITECTURE.md), and [acceptance criteria](11_ACCEPTANCE_CRITERIA.md).

## Historical Stage 1 result

`lib/core/platform/ios_chrome_bridge.dart` supplies an iOS-only, fallback-safe capability and presentation contract. `ios/Runner/AppDelegate.swift` registers its presentation-only MethodChannel in the existing implicit engine. No screen consumes the bridge, and no native chrome is created; `GlassDock` remains the visible phone navigation. `codemagic.yaml` prepares an unsigned iOS compile workflow; [Codemagic readiness](13_CODEMAGIC_READINESS.md) records the unrun workflow. Stage 1.5 aligns the iOS deployment target with Xcode 26.2. The protected player and Android files were not changed by this migration.

## Required Stage 0 answers

| Question | Answer and evidence level |
|---|---|
| Q1: authentic native chrome above Flutter? | **NOT POSSIBLE IN CURRENT ENVIRONMENT to verify.** Apple documents native controls and Flutter documents embedding, but no Mac/Xcode/iOS runtime is available here. |
| Q2: responds to Flutter pixels beneath? | **NOT VERIFIED.** No compositing screenshot, screen recording, or device observation exists. This is the primary Stage 0B gate. |
| Q3: Flutter sole navigation authority? | **Architecturally feasible at source level, runtime unverified.** Native emits tab intent; `MainShell._selectTab` applies Kids policy; Flutter sends confirmed selected ID back. |
| Q4: minimum iOS version? | **SOURCE VERIFIED; IOS BUILD PENDING CODEMAGIC.** LG-08 supersedes the earlier iOS 13 decision: target 15.0 and guard iOS 18/26 symbols with availability checks, then compile/run supported runtimes on Mac. |
| Q5: PlatformViews required? | **NO for the preferred sibling-UIKit design**, subject to composition proof. `UiKitView` is a gated alternative, not a default. |
| Q6: performance impact? | **UNKNOWN / NOT MEASURED.** One native chrome surface and low-frequency channel are expected to cost less than many PlatformViews, but this is an inference, not a benchmark. |
| Q7: player risk? | A scene-level bar could cover player routes or affect overlay ordering; the contract hides it on player routes and changes no media surface. Runtime risk remains unmeasured. |
| Q8: proceed to Stage 1? | At Stage 0 handoff the recommendation was **NO-GO pending Stage 0B native evidence**. The user later separately authorized Stages 1–7 source work. The native proof remains open for Stage 8 and later device acceptance. |

## Stage 2 source implementation (2026-10-23)

The iPhone path now uses a scene-scoped standalone UIKit `UITabBar` over the single `FlutterViewController` on iOS 26+, selected by a capability handshake. `MainShell` remains the sole selected-tab and Kids-gate authority. Stable IDs are `home`, `anime`, `kids`, `library`, `settings`; Flutter supplies Arabic/English labels, direction, visibility and confirmed selection. UIKit SF Symbols are `house`, `sparkles`, `figure.child`, `books.vertical`, `gearshape`. Native taps send intent and restore the previously confirmed selection until Flutter publishes a new snapshot. Reselect preserves the existing chrome-reveal behavior; custom dock scrub is absent on the native path per LG-03. A Navigator observer hides chrome for pushed routes and sheets; scroll sends visibility changes. The existing Flutter content clearance remains, pending iOS visual proof. iOS 15–25 and Android keep GlassDock; tablet keeps its rail. Swift compilation, native composition, safe-area and accessibility runtime checks remain IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING. Stage 3 source work is described below.

## Stage 3 source decision (2026-10-23)

Stage 3 authorization and source decision: the iOS 26 phone Home search entry now uses the existing scene overlay with a native glass-configured system button and a revision-checked `search` intent. Flutter retains the sheet, results and all routes. Other secondary route bars stay Flutter-owned after a source audit; detail actions remain Stage 4 work. See `14_STAGE_3.md`. Native compilation and runtime remain pending; Stage 4 is not authorized by this work.

## Stage 4 source decision (2026-10-23)

The user separately authorized Stage 4. `15_STAGE_4.md` records the audit and source implementation: capable iOS 26 phones use native detail back/share buttons and a bounded More menu in the existing scene overlay, while Flutter remains the sole route and action owner. The Home search entry and tab bar hide on detail, and older iOS/Android/iPad keep their Flutter controls. Swift/iOS compilation and native behavior are **IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING**.

## Stage 5 player protection (2026-10-23)

`16_STAGE_5.md` audits both Core-default and Legacy player routes and records the surface decisions and future iOS measurement plan. No native player control was selected. The shell route projection and bridge now reject hidden-tab intents while the player is on top; all player rendering, controls, gestures and high-frequency state remain in Flutter/current media_kit ownership. Native build and runtime proof remain pending.

## Stage 6 adaptive decision

`17_STAGE_6.md` records the full tablet rail, accessibility, RTL, safe-area, scene and bridge audit. The iPad decision is **KEEP FLUTTER RAIL** at wide widths and the existing Flutter dock in compact windows; native iPhone chrome remains phone-idiom gated. Known iPhones keep phone navigation in wide landscape windows. The app's Reduce Transparency preference now restores Flutter shell/detail controls, the search button uses directional safe-area constraints, and identical bridge snapshots are skipped. This is **SOURCE VERIFIED** only. **IOS BUILD PENDING CODEMAGIC** and **IOS RUNTIME PENDING**.

## Stage 7 source audit

`18_STAGE_7.md` is the current implementation inventory, platform matrix, bridge/action audit, regression ledger and Stage 8 handoff. The Stage 0–6 sections above remain historical records; their earlier authorization and implementation statements do not describe the current gate. Stage 7 does not run Codemagic or establish iOS runtime acceptance.
