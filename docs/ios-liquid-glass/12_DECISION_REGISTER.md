# Architecture decision register

Status values: APPROVED by user, PROPOSED, or PENDING EVIDENCE. Approval of the architecture does not authorize Stage 1.

| ID | Question / options | Evidence and recommendation | Tradeoff / risk | Status |
|---|---|---|---|---|
| LG-01 | iOS 13 or raise minimum | Stage 0 chose 13.0; superseded by LG-08 in Stage 1.5 | Historical decision, no longer current | SUPERSEDED |
| LG-02 | Flutter-only, package, broad bridge, hybrid | Apple-native material needs Apple views; keep Flutter content/state and narrow native chrome | Cross-layer composition unproven | APPROVED; feasibility pending |
| LG-03 | Native tab behavior or exact NOVA dock gestures | iOS 26 standard tab behavior preferred by user | Custom scrub/size behavior may differ on iOS 26 | APPROVED |
| LG-04 | Flutter or native navigation owner | `MainShell` owns Kids gate, visited tabs and routes; keep Flutter sole owner | Requires intent/snapshot protocol | APPROVED |
| LG-05 | Native player controls or Flutter overlays | media_kit video/subtitles/gestures are performance sensitive; keep primary overlays Flutter | Less native player appearance | APPROVED |
| LG-06 | Native iPad sidebar or current rail | Historical gated investigation; LG-21 resolves it to KEEP FLUTTER RAIL | Superseded by the Stage 6 decision | SUPERSEDED by LG-21 |
| LG-07 | External dependency or project-local bridge | Package claims unverified against current iOS 15 minimum, lifecycle and video; prefer small local adapter | Native maintenance stays in NOVA | APPROVED |
| LG-08 | Minimum iOS deployment target | Raise minimum from iOS 13 to iOS 15: [Apple Xcode system requirements](https://developer.apple.com/xcode/system-requirements) list Xcode 26.2/iOS 26.2 SDK with iOS 15–26.2 deployment | iOS 13/14 devices lose support; Xcode 26 compatibility enables later Liquid Glass work; iOS 18/26 APIs still need availability guards | APPROVED |
| LG-12 | Sibling UIKit bar or `UiKitView` (formerly LG-08 in Stage 0 draft) | Prefer sibling overlay to avoid PlatformView; Flutter docs list hybrid-composition costs | Backdrop sampling and modal order unknown | PENDING EVIDENCE in Stage 0B |
| LG-09 | Stage 1 go/no-go | User separately authorized Stage 1; Dart/Swift bridge source added, native compilation pending | No native appearance claim | Stage 1 authorized; Stage 2 source implemented; build/runtime pending |
| LG-10 | iOS bridge traffic | Discrete MethodChannel snapshot/intent vs event stream | Channel added, no EventChannel needed; Flutter owns selection | Stage 2 must wire authorization and lifecycle | IMPLEMENTED source; native compile pending |
| LG-11 | Codemagic SDK and deployment conflict | Xcode 26.2 provides iOS 26.2 SDK and Apple lists iOS 15+ deployment; LG-08 aligns NOVA to 15.0 | Source-level conflict resolved; actual dependency/linking result unknown | IOS BUILD PENDING CODEMAGIC |

## Stage 2 source implementation (2026-10-23)

The iPhone path now uses a scene-scoped standalone UIKit `UITabBar` over the single `FlutterViewController` on iOS 26+, selected by a capability handshake. `MainShell` remains the sole selected-tab and Kids-gate authority. Stable IDs are `home`, `anime`, `kids`, `library`, `settings`; Flutter supplies Arabic/English labels, direction, visibility and confirmed selection. UIKit SF Symbols are `house`, `sparkles`, `figure.child`, `books.vertical`, `gearshape`. Native taps send intent and restore the previously confirmed selection until Flutter publishes a new snapshot. Reselect preserves the existing chrome-reveal behavior; custom dock scrub is absent on the native path per LG-03. A Navigator observer hides chrome for pushed routes and sheets; scroll sends visibility changes. The existing Flutter content clearance remains, pending iOS visual proof. iOS 15–25 and Android keep GlassDock; tablet keeps its rail. Swift compilation, native composition, safe-area and accessibility runtime checks remain IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING. Stage 3 source work is described below.

## Stage 3 source decision (2026-10-23)

| ID | Question / options | Evidence and recommendation | Tradeoff / risk | Status |
|---|---|---|---|---|
| LG-13 | Stage 3 native Home search entry vs full native search | A glass-configured iOS 26 `UIButton` sends stable `search` intent; Flutter keeps `SearchSheet`, query, filters and results | Native entry needs iOS safe-area, material, VoiceOver and modal proof | IMPLEMENTED source; IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING |
| LG-14 | Secondary native navigation bar vs Flutter route bars | `UINavigationBar` normally derives its items/back behavior from `UINavigationController`; NOVA uses Flutter `MaterialPageRoute` and `Navigator` | Flutter bars remain for this stage; visual convergence is limited but route ownership stays singular | KEEP; revisit only with an explicit route-safe design and approval |

## Stage 4 decisions (2026-10-23)

| ID | Question / options | Evidence and decision | Tradeoff / risk | Status |
|---|---|---|---|---|
| LG-15 | Detail back/share as native controls or Flutter-only | iOS 26 phone uses standard glass buttons and stable intents; Flutter keeps `Navigator.maybePop` and `_share` | Native placement and share layering need device proof | IMPLEMENTED source; IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING |
| LG-16 | Detail More menu vs complex native workflows | Native `UIMenu` shows only existing `sources`, `list`, conditional `track`; Flutter opens all subsequent flows | Menu dismissal, modal order and disabled state need device proof | IMPLEMENTED source; IOS RUNTIME PENDING |
| LG-17 | Detail route state ownership | Route-keyed Flutter registry and the existing shell snapshot/revision choose one scene overlay state | Nested route and lifecycle behavior need runtime proof | IMPLEMENTED source; IOS RUNTIME PENDING |

## Stage 5 player decisions (2026-10-23)

| ID | Question / options | Evidence and decision | Tradeoff / risk | Status |
|---|---|---|---|---|
| LG-18 | Isolated native player close vs Flutter close | Both player pages couple top-bar close with `PopScope`, lock/overlay state and `_requestClose`; no device proof of a safe native overlay | Retains Flutter appearance on iOS 26 player | DEFER; no native player action |
| LG-19 | Player bridge traffic | Keep `nova/ios_chrome/v1` limited to discrete shell snapshots/intents; hide all shell chrome on player and reject hidden-tab intents | Route-transition timing needs device proof | SOURCE VERIFIED; IOS RUNTIME PENDING |
| LG-20 | PiP or AirPlay/Cast presentation | Current source has no player capability/control for either | No new feature from a presentation-only stage | DEFER; absent in current player |

## Stage 6 iPad decision (2026-10-23)

| ID | Question / options | Evidence and decision | Tradeoff / risk | Status |
|---|---|---|---|---|
| LG-21 | NATIVE SIDEBAR / KEEP FLUTTER RAIL / DEFER | **KEEP FLUTTER RAIL**. `_TabletNavigation` owns five primary and nine secondary entries within Flutter's single `MainShell`/`Navigator`, including Kids authorization. Apple's standard iPad `UITabBarController` sidebar selects associated view controllers and can own group navigation; introducing it here would duplicate page ownership or require a new compact-window synchronization layer. The current rail adapts at 840/1200 logical pixels and the compact iPad fallback is the existing Flutter dock. | No native Liquid Glass sidebar on iPad; rail sizing, focus, RTL, safe areas and window resizing need runtime proof. Fallback remains the current Flutter rail/dock. | SOURCE VERIFIED decision; IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING |
