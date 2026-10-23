# Stage 6 — adaptive navigation and native chrome audit

Source snapshot: `feature/player-reengineering`, HEAD `2ec313bfd18dc72de3281c999ab5207c3cd23d38`, 2026-10-23. The working tree already contained unrelated modifications and untracked files. This stage makes no commit, push, player migration, dependency change, or Codemagic run. Findings below are **SOURCE VERIFIED** unless explicitly marked pending. **IOS BUILD PENDING CODEMAGIC**; **IOS RUNTIME PENDING**.

## iPad Audit

`MainShell` owns `_selected`, `_visited`, page construction, Flutter `Navigator` routes, and the Kids gate. At a window width of at least 840 logical pixels it lays out `_TabletNavigation` beside an `Expanded` content area in a `Row`; below 840 it uses the existing Flutter phone dock. At 1200 or wider the rail is 240 pixels with icon and label; from 840 to 1199 it is 84 pixels with icons and tooltips. These are window constraints, not an iPad model or orientation check. Portrait and landscape use the same width rules. A compact iPad Split View, Slide Over where available, or Stage Manager window can therefore show the Flutter dock; widening restores the rail. There is no user-controlled rail collapse, expansion, or hide gesture. Rail content scrolls in a `SafeArea`/`ListView`; the page receives the remaining Row width. The rail's width is an actual layout allocation, not a native overlay inset.

The rail presents the same five primary tab IDs as the phone dock, Home search (except in Kids), and nine secondary destinations. Primary taps call `_selectTab`; `_mayLeaveKids` and `NovaParentalGate.ensureConfigured` authorize transitions, then `AppState.setKidsSession` and `_selected` are updated. `_visited` preserves lazily created tab pages. Secondary taps call `_openSecondary`, leave Kids only after its gate, then push a Flutter `MaterialPageRoute`. Child/back navigation and modal sheets remain Flutter-owned. Scroll-based chrome hiding is explicitly disabled on the tablet layout; the rail remains visible. `noorDockTabsFor(rtl: ...)` and translated `AppState.tr` labels follow the current app language. Width thresholds, SafeArea, labels and scrolling still need iPad runtime checks under text enlargement and window resizing.

Stage 6 also removes a phone-width ambiguity: `getCapabilities` now reports the UIKit phone idiom even on iOS 15–25. A known iPhone keeps the phone navigation path when landscape width exceeds 840; this is independent of whether native chrome is available. iPad native chrome remains unavailable in `SceneDelegate`, and iPad window width still chooses only between the Flutter rail and Flutter dock. Android keeps its prior width behavior.

## iPad Decision

**KEEP FLUTTER RAIL** (LG-21). Apple describes a standard iPad sidebar as part of `UITabBarController`, whose tabs select associated view controllers; sidebar groups can manage a navigation hierarchy. NOVA's primary and secondary destinations are already rendered and routed inside one Flutter view, with a Flutter Kids gate. Replacing the rail with that controller would require native content-controller ownership or a second synchronization model for the nine secondary Flutter routes and compact-window transitions. A free-standing custom native sidebar would not gain the standard controller's adaptive behavior and would add overlay/inset/focus complexity. No native iPad sidebar, second stack, second engine, or PlatformView is introduced. Flutter remains the sole navigation owner. The fallback is the current rail at wide widths and Flutter dock in compact iPad windows. This is an architecture decision from current source; portrait, landscape, Split View, Slide Over, Stage Manager and accessibility acceptance remain **IOS RUNTIME PENDING**.

Apple authority: [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass), [iPad tab bar and sidebar](https://developer.apple.com/documentation/uikit/elevating-your-ipad-app-with-a-tab-bar-and-sidebar), [UITabBarController](https://developer.apple.com/documentation/uikit/uitabbarcontroller), [multitasking](https://developer.apple.com/documentation/uikit/multitasking-on-ipad-mac-and-apple-vision-pro), and [trait collections](https://developer.apple.com/documentation/uikit/uitraitcollection).

## Accessibility Audit

| Native surface | Source support | Runtime proof still needed |
|---|---|---|
| Stage 2 `UITabBar` | System tab items receive Flutter-localized titles, enabled flags, confirmed selection, and explicit semantic direction. UIKit supplies standard button/tab/selected VoiceOver semantics; no redundant traits are forced. | VoiceOver order and selected/disabled announcements, Dynamic Type label fit, tab reachability in landscape and increased contrast. |
| Stage 3 Home search | System `UIButton` has a localized accessibility label, stable identifier, standard button trait, 48-point hit area, and safe-area placement. It hides for non-Home routes and Flutter sheets. | Focus order, keyboard/search-sheet transition, notch and landscape reachability. |
| Stage 4 back/share/More | Three system buttons have Flutter-localized labels and 48-point areas. Share uses `isEnabled`; More is enabled only if a menu action is enabled. Detail controls hide when a higher Flutter route/modal is topmost. | Back/Share/More reading order, disabled announcement, focus return after sheet/menu, nested detail transitions. |
| Stage 4 `UIMenu` | Flutter supplies translated action titles and enabled flags; UIKit `UIAction` renders menu semantics. Action IDs remain stable and are never matched by translated text. | VoiceOver menu order, disabled items, enlarged text and dismissal on route change. |

Native visible text is limited to system tab-item and menu titles. No custom font size or custom text renderer is set. UIKit standard controls provide their own text behavior; actual Dynamic Type clipping and menu layout remain **IOS RUNTIME PENDING**. Apple documents default [tab bar accessibility](https://developer.apple.com/documentation/uikit/uitabbar), [button accessibility](https://developer.apple.com/documentation/uikit/uibutton), [VoiceOver reading order](https://developer.apple.com/documentation/uikit/supporting-voiceover-in-your-app), and [Dynamic Type](https://developer.apple.com/documentation/uikit/scaling-fonts-automatically).

The app's `reduceTransparency` preference now suppresses all native shell controls and restores the Flutter dock, search entry and detail controls. The OS Reduce Transparency, Reduce Motion and Increase Contrast settings are left to standard UIKit glass/tab/menu behavior; there are no custom native animations, opaque colors or translucent tints to override system adaptation. The Flutter shell already uses its app/MediaQuery reduced-motion handling. These system responses and visual contrast must be checked on-device; [Apple's Liquid Glass guidance](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass) explicitly calls for this.

## RTL Audit

`AppState.english` is the translation source; `NovaApp` sets Flutter locale, while `MainShell` sends `locale`, `rtl`, translated tab/search/detail/menu labels and dark appearance in a discrete snapshot. UIKit sets `semanticContentAttribute` on the overlay, tab bar, search and detail buttons. Flutter tab ordering comes from `noorDockTabsFor(rtl: ...)`; the menu follows the bounded Flutter action array. Back is the directional SF Symbol `chevron.backward`, while `search`, `square.and.arrow.up`, `ellipsis`, `square.stack`, `list.bullet`, `chart.line.uptrend.xyaxis` and the five tab symbols are semantic objects rather than manually mirrored arrows. No blanket image flip is applied. Back's stable action remains `detail.back` in both directions. Search uses opposite safe-area anchors in Arabic and English, rather than absolute screen-edge arithmetic. Exact glyph mirroring, visual/focus order and Arabic truncation remain **IOS RUNTIME PENDING**. See Apple's [semantic content attribute](https://developer.apple.com/documentation/uikit/uiview/semanticcontentattribute) guidance.

## Adaptive Layout

For iOS 26 iPhone portrait and landscape, the phone idiom keeps the native tab/search/detail path; tab bar height follows UIKit `sizeThatFits` and the top buttons anchor to the overlay safe area. iOS 15–25 iPhones keep Flutter controls, including at wide landscape widths. For iPad portrait/landscape and resizable windows, the 840/1200 Flutter width rules above apply; no native phone tab is allowed. Android remains on its prior width-based Flutter path. Safe-area, Dynamic Island/notch, home-indicator, landscape tab-bar frame, keyboard and modal visual composition require real iOS runs. The top search button now has safe-area Auto Layout constraints that follow direction and window/safe-area changes. The tab bar remains a standard UIKit bar sized by UIKit at the overlay bottom; whether its actual iOS 26 frame and Flutter content clearance are correct is **IOS RUNTIME PENDING**. No keyboard observer is added: Flutter owns the search sheet and forms, and the top-route snapshot hides native chrome while their modal route is active.

## Scene Lifecycle

`Info.plist` currently disables multiple scenes. `SceneDelegate` owns and removes its own `NovaChromeOverlay` on disconnect, and its phone/Flutter-root capability gate prevents iPad overlay creation. `AppDelegate` owns the MethodChannel only; Stage 6 removed its unused global presentation copy. Flutter publishes inactive chrome on background and a fresh snapshot on resume. Route and app-language/theme changes republish the scene presentation; identical builds are deduplicated. Multi-scene support would need a separate explicit channel-to-scene routing contract if the plist setting changes. Connection, foreground restoration, native modal stacking, appearance changes and focus disposal are **IOS RUNTIME PENDING**.

## Bridge Review

The existing `nova/ios_chrome/v1` contract still carries a finite localized shell/detail snapshot and stable `selectIntent`/`actionIntent` IDs. Stage 6 adds one low-frequency capability field, `phoneIdiom`; no presentation field or action ID is added or removed. The unused AppDelegate presentation cache was removed. A failed older asynchronous publication no longer clears the newer revision's intent gate. MainShell skips identical snapshots, preserving revision checks while avoiding a platform call for an unchanged rebuild. Flutter validates tab IDs, selected state, Kids authorization, current route, enabled detail actions and presentation revisions. Swift validates known symbols and ignores older snapshots. Disposal clears the native overlay and Dart handler. No playback ticks, video frames, gestures, scroll offsets, animation frames, timeline values or other high-frequency data cross this channel.

## Runtime Acceptance Matrix

| Scenario | Source result | Required Apple-toolchain/runtime evidence |
|---|---|---|
| iPhone iOS 26, portrait/landscape | Phone idiom gate, native controls, safe-area constraints and modal route hiding are present. | Compile, inspect glass/material, VoiceOver, Dynamic Type, reduced transparency/motion, contrast, RTL, light/dark, keyboard, notch/home indicator and rotation. |
| iPhone iOS 15–25 | Native gate off; Flutter dock/search/detail fallback. | Launch on representative supported versions and rotate. |
| iPad full screen / compact / Stage Manager / Split View / Slide Over | Width-adaptive Flutter rail/dock; no native sidebar. | Resize/rotate, inspect rail scroll/focus/Kids gate, routes and content clearance. |
| Player above shell/detail | Route snapshot hides all native shell chrome; player UI remains Flutter. | Open Core and Legacy player, rotate, seek, show panels and return; check no overlay touch/focus leak. |
| Scene disconnect/reconnect and appearance/locale changes | Scene overlay removal and Flutter snapshot path are present. | Reconnect/background/foreground, switch Arabic/English and light/dark, verify fresh controls and no stale intent. |
| Android | No Android source changed. | Regression run if final acceptance needs hardware proof. |

## Codemagic

**IOS BUILD PENDING CODEMAGIC.** `codemagic.yaml` is unchanged; Stage 6 adds no new SDK or dependency requirement. Swift syntax, API availability and UIKit behavior are source-inspected only on Windows.

## Runtime

**IOS RUNTIME PENDING.** No simulator or physical iOS device was used. Stage 7 may review the full regression evidence only after separate authorization; this document does not start it.
