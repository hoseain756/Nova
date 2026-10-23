# Stage 0 acceptance and final migration criteria

The Stage 0–6 gates below are historical source-stage records. Stage 7's source gate and the separate Stage 8 build entry are in `18_STAGE_7.md`. Open iOS compiler, simulator and device checks remain unchecked here.

## Stage 0 gate

- [x] Repository, UI and toolchain audited; historical iOS 13 target recorded, then raised to iOS 15 in Stage 1.5.
- [x] Official Apple/Flutter references and a minimal presentation contract documented.
- [x] Existing player and working-tree changes preserved.
- [ ] Native tab-bar experiment compiled with iOS 15 deployment and current SDK on macOS.
- [ ] Genuine Apple material and response to Flutter content shown on iOS 26+ with evidence.
- [ ] Older runtime fallback, Flutter navigation/Kids gate, modal/keyboard order, safe area, RTL and VoiceOver verified.
- [ ] Performance comparison and player exclusion verified on iOS hardware.

Stage 0 source audit was accepted by the user for Stage 1 authorization. Its native composition proof remains open and cannot be counted as evidence for Stage 2. This is an environment limitation, not a finding that Liquid Glass is impossible.

## Stage 1 source gate

- [x] Isolated Dart presentation adapter, iOS-only capability query and safe fallback exist.
- [x] Existing implicit-engine iOS host registers a presentation-only MethodChannel.
- [x] No native tab bar, second navigation owner, PlatformView, player overlay or Android UI change was introduced.
- [x] No third-party Liquid Glass dependency was added.
- [x] Dedicated unsigned Codemagic workflow is configured with pinned Flutter revision and Xcode 26.2 selector.
- [x] Stage 1.5 aligns Runner and RunnerTests source deployment settings to iOS 15.0; Codemagic checks those settings before build.
- [ ] Swift/iOS compilation and Codemagic workflow execution: **PENDING CODEMAGIC VALIDATION**.
- [ ] Absent-Podfile dependency preparation and iOS compilation resolved by actual Codemagic build evidence.

Stage 1 code can be reviewed on Windows; these open native checks prevent a claim of iOS build readiness or permission to start Stage 2.

## Final migration gate

The final project must show genuine Apple effects only on appropriate iOS 26+ native controls; safe iOS 15–25 paths; unchanged Android; shared business state; stable single-owner navigation; working RTL/localization, VoiceOver/Dynamic Type/motion/transparency/contrast and dark/light themes; no player-performance or tablet regression; no unavailable-API crashes; justified dependencies only. Every claim needs a corresponding compile/runtime/device record. Do not count Flutter blur or package marketing as native validation.

## Stage 2 source implementation (2026-10-23)

The iPhone path now uses a scene-scoped standalone UIKit `UITabBar` over the single `FlutterViewController` on iOS 26+, selected by a capability handshake. `MainShell` remains the sole selected-tab and Kids-gate authority. Stable IDs are `home`, `anime`, `kids`, `library`, `settings`; Flutter supplies Arabic/English labels, direction, visibility and confirmed selection. UIKit SF Symbols are `house`, `sparkles`, `figure.child`, `books.vertical`, `gearshape`. Native taps send intent and restore the previously confirmed selection until Flutter publishes a new snapshot. Reselect preserves the existing chrome-reveal behavior; custom dock scrub is absent on the native path per LG-03. A Navigator observer hides chrome for pushed routes and sheets; scroll sends visibility changes. The existing Flutter content clearance remains, pending iOS visual proof. iOS 15–25 and Android keep GlassDock; tablet keeps its rail. Swift compilation, native composition, safe-area and accessibility runtime checks remain IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING. Stage 3 source work is described below.

## Stage 3 source decision (2026-10-23)

Stage 3 source gate: exact candidates and NATIVE / KEEP / DEFER decisions are in `14_STAGE_3.md`; the sole native addition is the iOS 26 phone Home search entry with stable `search` intent. Flutter owns search, back navigation, page routes, menus and content. Android, older iOS and iPad retain their existing entry. Windows analysis/tests/static checks are recorded in `09_TESTING_STRATEGY.md`. iOS compilation is IOS BUILD PENDING CODEMAGIC; iOS presentation is IOS RUNTIME PENDING. This gate does not authorize Stage 4.

## Stage 4 source gate (2026-10-23)

`15_STAGE_4.md` records the audit, action IDs and fallbacks. Source-level implementation keeps Flutter as sole navigation/business owner and limits native presentation to detail back/share/More on capable iOS 26 phones. Flutter fallback is retained for iOS 15–25, Android and iPad, plus native publication failure. Source checks and tests are recorded in `09_TESTING_STRATEGY.md`. The acceptance gate remains open for Codemagic compilation and iOS runtime/device proof.

## Stage 5 source gate (2026-10-23)

`16_STAGE_5.md` records the actual Core/Legacy player audit, every major surface classification, protected bridge boundary, shell route coordination and the future iOS measurement protocol. No player engine, video view, subtitle renderer, gesture path, timeline, native player control or PlatformView changed. Source/state tests cover player entry/exit and hidden/stale intents. Final Windows check results belong in `09_TESTING_STRATEGY.md`; iOS compilation and runtime acceptance remain open. Its Stage 5 handoff left Stage 6 for separate approval.

## Stage 6 source gate

`17_STAGE_6.md` records the existing iPad rail behavior, **KEEP FLUTTER RAIL** decision and native Stage 2–4 accessibility/RTL/adaptive/scene/bridge audit. Flutter remains the single route and Kids authority. Phone native chrome remains idiom-gated; iPad compact windows keep the Flutter dock. No player migration, PlatformView, second engine, native iPad navigation controller, new dependency or Android source change was made. Windows check results are recorded in `09_TESTING_STRATEGY.md`. This source gate does not close the above iOS build/runtime acceptance criteria and does not authorize Stage 7.
