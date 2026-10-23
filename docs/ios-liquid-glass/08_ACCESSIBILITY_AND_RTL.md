# Accessibility, localization and RTL contract

NOVA switches Arabic/English in `AppState`; `NovaApp` sets Flutter locale and theme. `MainShell` derives dock order from language and explicitly checks `MediaQuery.accessibleNavigationOf`. `GlassSearchButton` checks `MediaQuery.highContrastOf` and NOVA's `reduceTransparency`; `NovaApp` combines OS and app reduced-motion preferences. These Flutter values do not automatically configure a separate UIKit sibling view.

The native presentation snapshot must carry localized labels, stable tab IDs, selected/disabled state, locale and layout direction. UIKit accessibility labels and traits must be set on every icon/tab; native layout direction must be explicitly synchronized when NOVA's in-app language changes, including when device language differs. Native labels are sourced from the existing Arabic/English localization, not a second hard-coded translation table. Retain NOVA's explicit player timeline direction convention separately.

On actual iOS runtimes test VoiceOver reading/selection order, Dynamic Type, Reduce Motion, Reduce Transparency, Increase Contrast, light/dark, iPhone/iPad portrait/landscape, hardware keyboard, and modal focus return. Standard Apple controls should adapt to system settings; app-specific motion/transparency preferences must also be reflected in the bridge. Never force translucent chrome when the user requests reduced transparency. Apple references: [accessibility testing](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app), [UIKit setting](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducetransparencyenabled), [SwiftUI direction](https://developer.apple.com/documentation/swiftui/layoutdirection).

All native accessibility outcomes remain **NOT VERIFIED** until tested with Apple tooling.

## Stage 2 source implementation (2026-10-23)

The iPhone path now uses a scene-scoped standalone UIKit `UITabBar` over the single `FlutterViewController` on iOS 26+, selected by a capability handshake. `MainShell` remains the sole selected-tab and Kids-gate authority. Stable IDs are `home`, `anime`, `kids`, `library`, `settings`; Flutter supplies Arabic/English labels, direction, visibility and confirmed selection. UIKit SF Symbols are `house`, `sparkles`, `figure.child`, `books.vertical`, `gearshape`. Native taps send intent and restore the previously confirmed selection until Flutter publishes a new snapshot. Reselect preserves the existing chrome-reveal behavior; custom dock scrub is absent on the native path per LG-03. A Navigator observer hides chrome for pushed routes and sheets; scroll sends visibility changes. The existing Flutter content clearance remains, pending iOS visual proof. iOS 15–25 and Android keep GlassDock; tablet keeps its rail. Swift compilation, native composition, safe-area and accessibility runtime checks remain IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING. Stage 3 source work is described below.

## Stage 3 source decision (2026-10-23)

Stage 3 sends the native search button's label from Flutter's current Arabic/English localization, positions it at the logical trailing edge using the RTL snapshot, and follows the current light/dark appearance. The standard UIKit glass button supplies system focus/VoiceOver behavior at source level; VoiceOver, Dynamic Type, Increase Contrast, Reduce Motion and Reduce Transparency still require iOS 26 device checks. Older iOS, Android and iPad retain the existing Flutter button. Search-sheet focus and dismissal remain Flutter-owned.

## Stage 4 detail controls (2026-10-23)

The detail page sends localized Arabic/English back, share, More and menu labels in the existing snapshot. UIKit's explicit semantic direction drives leading/trailing safe-area anchors; native buttons are 48 points and use standard glass/menu behavior. Disabled share and menu actions derive from Flutter state. VoiceOver ordering, directional back symbol, Dynamic Type menu labels, contrast, motion and transparency behavior remain **IOS RUNTIME PENDING**. The Flutter content and all fallback controls retain their existing accessibility behavior.

## Stage 5 player protection (2026-10-23)

No native player control was added, so existing Flutter player semantics and the explicit Arabic-left/English-right timeline convention remain in place. On player entry, source/state tests require all native shell hit targets to be hidden; runtime checks must still verify VoiceOver focus, enlarged text, landscape safe areas, Reduce Motion, Reduce Transparency, Increase Contrast and touch access after rotation. These outcomes are **IOS RUNTIME PENDING**.

## Stage 6 source audit (2026-10-23)

`17_STAGE_6.md` audits the native tab, search, detail buttons and menu individually. UIKit tab items receive translated titles, enabled state and confirmed selection; standard UIKit provides their VoiceOver roles. Icon-only buttons receive Flutter-localized labels and 48-point areas. Menu titles and disabled flags come from Flutter. No fixed native text font, custom animation, custom glass tint or redundant accessibility trait is applied. The app's Reduce Transparency preference now hides native controls and shows Flutter fallback; OS Reduce Transparency, Reduce Motion and Increase Contrast still need actual iOS observation. The native search button now anchors to the logical safe-area side as direction changes. The back symbol remains `chevron.backward`; other symbols are not manually flipped. Arabic/English focus order, actual symbol rendering, Dynamic Type, appearance and contrast are **IOS RUNTIME PENDING**.
