# Platform presentation architecture and message contract

The Stage 1 transport exists in `lib/core/platform/ios_chrome_bridge.dart` and `ios/Runner/AppDelegate.swift`. Stages 2–4 wired it to `MainShell` and the scene-owned tab, Home search and detail presentation. `MainShell` remains authoritative; no native controller selects a destination or opens a route directly. The Stage 7 current contract is inventoried in `18_STAGE_7.md`.

## Historical Stage 1 contract, extended in Stages 2–4

Channel namespace: `nova/ios_chrome/v1` (new, separate from `noor/links`). `getCapabilities` reports OS major, whether iOS 26 system material is available, and `nativeChromeAvailable=false` until Stage 2 creates actual chrome. Flutter can send `setPresentation` with `revision`, stable tab IDs (`home`, `anime`, `kids`, `library`, `settings`), `selectedId`, per-tab localized `label` and `enabled`, `visible`, `locale` (`ar`/`en`), `rtl`, `dark` and `active`. There are no current tab badges, so the transport has no speculative badge field. `dispose` clears the future presentation lifecycle. Stage 1 validated snapshots without a view; Stage 2 now renders a standalone scene-scoped UITabBar. The Dart side can receive a future `selectIntent` with tab ID and matching revision; Stage 2 emits it from UIKit. `MainShell` validates ID and Kids policy, calls existing `_selectTab`, and publishes confirmed selection. Denied intents must leave the previous selection highlighted.

Safe-area handling remains in Flutter `MediaQuery` for Stage 1; no native inset event is needed before a native view exists. Stage 2 must validate scene safe-area changes before choosing any event shape. Native must neither invent scroll coordinates nor continuously publish inset values. Flutter keeps search and deep-link decisions. No playback, video, gesture delta or animation frame crosses the channel. All UIKit mutations execute on the main thread.

## Ownership and lifecycle

The MethodChannel is registered through the existing `FlutterImplicitEngineDelegate` plugin registry; no second engine, controller or PlatformView was added. Dart ignores duplicate/older outbound revisions and stale inbound intent revisions, treats missing/failed channels as unsupported, and refuses snapshot/intent setup unless capability discovery reports native chrome available. The Stage 1 native host reports `false`, so the bridge is dormant and the Flutter dock remains visible. Stage 2 must add a scene-scoped presenter and detach it on engine/scene disposal; the current `SceneDelegate` link forwarder must keep working. Native modal presentation, if later approved, requires its own dismissal acknowledgement and Flutter route synchronization.

## Availability and current fallback

iOS 15–17 and iOS 18–25 currently use the existing Flutter dock, search and detail controls; no distinct Cupertino replacement was implemented. Capable iOS 26 iPhones select source-level native presentation through a capability handshake, but compiler/runtime, composition, accessibility and rollback checks remain pending. Swift iOS 26 symbols are guarded. Flutter never infers native capability solely from OS version.

## Stage 2 source implementation (2026-10-23)

The iPhone path now uses a scene-scoped standalone UIKit `UITabBar` over the single `FlutterViewController` on iOS 26+, selected by a capability handshake. `MainShell` remains the sole selected-tab and Kids-gate authority. Stable IDs are `home`, `anime`, `kids`, `library`, `settings`; Flutter supplies Arabic/English labels, direction, visibility and confirmed selection. UIKit SF Symbols are `house`, `sparkles`, `figure.child`, `books.vertical`, `gearshape`. Native taps send intent and restore the previously confirmed selection until Flutter publishes a new snapshot. Reselect preserves the existing chrome-reveal behavior; custom dock scrub is absent on the native path per LG-03. A Navigator observer hides chrome for pushed routes and sheets; scroll sends visibility changes. The existing Flutter content clearance remains, pending iOS visual proof. iOS 15–25 and Android keep GlassDock; tablet keeps its rail. Swift compilation, native composition, safe-area and accessibility runtime checks remain IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING. Stage 3 source work is described below.

## Stage 3 source decision (2026-10-23)

Stage 3 extends the existing low-frequency presentation with `searchVisible` and localized `searchLabel`. The same iOS 26 phone scene overlay places a system glass `UIButton` at the logical trailing top edge. It emits `actionIntent` with stable `search` ID and presentation revision; Dart rejects stale/unknown actions and `MainShell` opens the Flutter `SearchSheet`. There is no search-query traffic. Flutter `Navigator` remains the only route owner. Native `UINavigationBar`/`UINavigationController` is not added for Flutter-owned secondary routes; see `14_STAGE_3.md`.

## Stage 4 detail extension (2026-10-23)

The same snapshot now carries an optional typed `detail` presentation. `DetailChromeRegistry` stores route-specific Flutter handlers, and the shell uses the top `Navigator` route to choose either detail chrome or tab/Home search chrome. One revision rejects stale native taps, including taps from a replaced detail. The scene overlay renders only iOS 26 phone system buttons and a bounded native menu; all resulting behavior is handled by the detail page in Flutter. Top controls use UIKit safe-area anchors and explicit RTL/appearance state. Flutter controls remain until native publication succeeds and return on failure. Backgrounding marks presentation inactive. See `15_STAGE_4.md`; no PlatformView or second navigation owner was added.

Stage 6 keeps iPad navigation in Flutter: `_TabletNavigation` at widths of at least 840 logical pixels, with the existing Flutter dock in compact iPad windows. UIKit reports phone idiom separately from glass capability so a wide iPhone landscape window stays on the phone path. The app's Reduce Transparency preference suppresses native shell/detail controls and exposes Flutter fallback; system accessibility settings continue to use standard UIKit adaptation. The scene owns its overlay and `AppDelegate` no longer caches presentation state. The channel skips identical snapshots and retains the one-revision intent gate. See `17_STAGE_6.md`; iOS compile/runtime remain pending.

## Stage 5 player route boundary (2026-10-23)

The shell resolves one presentation from the current Flutter top route: root tabs/Home search, registered detail chrome, or no native chrome for a pushed player. On the player route the snapshot has hidden tabs/search and no detail object. The bridge rejects tab intents while tabs are hidden, as it already rejects stale revisions and hidden search/detail actions. No player state, timeline sample, gesture delta or video data was added to `nova/ios_chrome/v1`; see `16_STAGE_5.md`. Swift scene composition and iOS runtime behavior remain unverified.
