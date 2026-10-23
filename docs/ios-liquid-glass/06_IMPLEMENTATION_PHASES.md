# Incremental phases and gates

**Current authorization covers Stage 7 source audit only.** Stages 1–6 are source-complete; `18_STAGE_7.md` records the final inventory and regression pass. Stage 8 Codemagic execution requires separate approval. Native compilation is IOS BUILD PENDING CODEMAGIC.

| Phase | Change | Exit gate |
|---|---|---|
| Stage 0A, completed | Source/toolchain audit, Apple/Flutter research, docs and message contract | Documents and unchanged app source; native status honestly open |
| Stage 0B, pending Mac | Isolated native system-tab experiment beside a Flutter view, no real dock replacement | iOS 15 fallback run and iOS 26 authentic appearance/composition/interaction evidence; comparison against PlatformView only if needed |
| Stage 1, source complete | iOS-only capability and presentation adapter; unsigned Codemagic workflow | Dart contract tests; Swift/iOS compile PENDING CODEMAGIC VALIDATION; Android unchanged |
| Stage 1.5, source complete | Raise Runner and RunnerTests minimum to iOS 15; align migration and CI preparation | Windows static checks; iOS build remains pending Codemagic |
| Stage 2 | iOS 26 phone tab bar | Existing Flutter route/Kids semantics, native accessibility and safe areas pass |
| Stage 3 | Selected page chrome and controls | Light/dark, AR/EN, accessibility and form state pass |
| Stage 4 | Detail actions and simple presentations | Source/episode workflows pass |
| Stage 5 | Player measurement; only then consider tiny isolated controls | No video, seek, touch, subtitle or route regression |
| Stage 6 | iPad/sidebar investigation and polish | Resizing, rotation, single route owner; retain Flutter rail if not proven |
| Stage 7 | Final source audit, regression and Codemagic readiness review | Windows source/tests documented in `18_STAGE_7.md`; iOS build/runtime remain open |
| Stage 8 | Pinned Codemagic unsigned iOS build, only after separate approval | Swift/UIKit, availability, plugin linking and `.app` artifact evidence; device runtime remains a later gate |

Stage 1.5 resolves the source-level deployment-target mismatch using [Apple's Xcode requirements](https://developer.apple.com/xcode/system-requirements). Stage 1 source completion does not close Stage 0B's native visual proof; Codemagic must still compile the project. A failed native experiment is removed/disabled and the existing dock stays operational; no simulated glass substitution.

## Stage 2 source implementation (2026-10-23)

The iPhone path now uses a scene-scoped standalone UIKit `UITabBar` over the single `FlutterViewController` on iOS 26+, selected by a capability handshake. `MainShell` remains the sole selected-tab and Kids-gate authority. Stable IDs are `home`, `anime`, `kids`, `library`, `settings`; Flutter supplies Arabic/English labels, direction, visibility and confirmed selection. UIKit SF Symbols are `house`, `sparkles`, `figure.child`, `books.vertical`, `gearshape`. Native taps send intent and restore the previously confirmed selection until Flutter publishes a new snapshot. Reselect preserves the existing chrome-reveal behavior; custom dock scrub is absent on the native path per LG-03. A Navigator observer hides chrome for pushed routes and sheets; scroll sends visibility changes. The existing Flutter content clearance remains, pending iOS visual proof. iOS 15–25 and Android keep GlassDock; tablet keeps its rail. Swift compilation, native composition, safe-area and accessibility runtime checks remain IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING. Stage 3 source work is described below.

## Stage 3 source decision (2026-10-23)

Stage 3 source work adds the iOS 26 phone Home native search entry within the Stage 2 overlay and completes the secondary-chrome audit in `14_STAGE_3.md`. Existing Flutter route bars and the Flutter search sheet stay authoritative. Detail action migration remains Stage 4; this stage does not authorize it. Source completion does not close the native build/runtime gate.

## Stage 4 source implementation (2026-10-23)

`15_STAGE_4.md` records the media-detail audit and the bounded iOS 26 phone back/share/More presentation. Flutter retains route, action, player and complex sheet ownership. The shared scene snapshot and revision synchronize detail with tabs and Home search. iOS compilation and runtime acceptance remain pending.

## Stage 5 source protection (2026-10-23)

`16_STAGE_5.md` audits current Core/Legacy ownership, preserves all player surfaces in Flutter/media_kit, strengthens hidden-tab intent rejection and defines future iOS measurements. No native player control or Codemagic configuration was added. Its Stage 5 handoff left Stage 6 for separate authorization.

## Stage 6 source decision (2026-10-23)

`17_STAGE_6.md` records **KEEP FLUTTER RAIL** for wide iPad windows, retaining the existing Flutter dock in compact windows. Flutter remains the only navigation/Kids/route owner. Source hardening covers phone idiom at wide widths, Reduce Transparency fallback, safe-area search anchoring, stale publication handling and duplicate-snapshot suppression. Stage 7's source audit is in `18_STAGE_7.md`. **IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING**.
