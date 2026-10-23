# Risks and fallback decisions

| Risk | Evidence now | Mitigation / fallback |
|---|---|---|
| Native material fails to sample Flutter pixels | Unknown; Apple API existence and Flutter hybrid composition do not prove it | Stage 0B visual/device proof; retain Flutter dock and mark native shell NO-GO if it fails |
| Overlay covers Flutter dialogs or keyboard | Unknown | Test scene and route layering; hide native bar for conflicting routes; never leave dual bars |
| `UiKitView` increases composition cost | Flutter documents performance tradeoffs | Prefer sibling UIKit view; use PlatformView only after measured necessity |
| Native selection bypasses Kids gate | Existing gate is in `MainShell._selectTab` | Native sends intent; Flutter decides; snapshot confirms selection |
| Language/direction drift | Flutter app language can differ from iOS language | Send locale, direction and labels on every relevant state change |
| iOS 18/26 symbols break iOS 15 | Target is 15.0; Mac compilation not available | Xcode compile and supported older-runtime test with availability branches |
| Player overlay/frame regression | Video and subtitles share Flutter surface; no iOS metrics | No native view over video; hide chrome on player; gather baseline before future changes |
| Dirty working tree contaminates results | Many unrelated changes predate Stage 0 | Record HEAD/status and test against a traceable snapshot; do not reset user work |

No risk has been resolved through an iOS runtime test in this environment.

## Stage 1 additions

- Stage 2 wires the bridge to `MainShell` on capable iOS 26 iPhones. Capability remains false on unsupported runtimes and tablet; native composition and rollback require Codemagic and runtime proof.
- [Apple's Xcode requirements](https://developer.apple.com/xcode/system-requirements) list iOS 15 as Xcode 26.2's lowest deployment target; Stage 1.5 aligns NOVA's source configuration to 15.0. Plugin linking and the actual unsigned build remain IOS BUILD PENDING CODEMAGIC. See `13_CODEMAGIC_READINESS.md`.
- Missing `ios/Podfile` with native iOS plugins can block CI dependency preparation. The workflow detects the absence and lets Flutter's build report the true need. No Podfile/SPM migration was made.
- Swift registration was inspected against Flutter's local `FlutterImplicitEngineBridge`/plugin-registry headers, but only a Mac compiler can establish source compatibility.

## Stage 2 source implementation (2026-10-23)

The iPhone path now uses a scene-scoped standalone UIKit `UITabBar` over the single `FlutterViewController` on iOS 26+, selected by a capability handshake. `MainShell` remains the sole selected-tab and Kids-gate authority. Stable IDs are `home`, `anime`, `kids`, `library`, `settings`; Flutter supplies Arabic/English labels, direction, visibility and confirmed selection. UIKit SF Symbols are `house`, `sparkles`, `figure.child`, `books.vertical`, `gearshape`. Native taps send intent and restore the previously confirmed selection until Flutter publishes a new snapshot. Reselect preserves the existing chrome-reveal behavior; custom dock scrub is absent on the native path per LG-03. A Navigator observer hides chrome for pushed routes and sheets; scroll sends visibility changes. The existing Flutter content clearance remains, pending iOS visual proof. iOS 15–25 and Android keep GlassDock; tablet keeps its rail. Swift compilation, native composition, safe-area and accessibility runtime checks remain IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING. Stage 3 source work is described below.

## Stage 3 source decision (2026-10-23)

Stage 3 risk: the native top search button could overlap Flutter status/content, survive a modal, or sample the wrong background. The scene overlay hit-tests only the button and tab bar; Flutter publishes route/visibility, label, RTL and appearance snapshots. If the capability/publish path fails, the Flutter button remains the source-level fallback. The actual layering, contrast, VoiceOver and lifecycle behavior remain IOS RUNTIME PENDING. No second navigation bar was created because its state could drift from Flutter `Navigator`; see `14_STAGE_3.md`.

## Stage 4 detail risks (2026-10-23)

Native top buttons may collide with the full-bleed hero or system inset in landscape; safe-area constraints are source-level mitigation, not visual proof. A menu could outlive a detail route or open a Flutter sheet after a route change; the current top-route check, action whitelist, enabled-state check and shared revision reject stale intents. A native publish failure restores the Flutter detail controls. Share-sheet layering, menu dismissal, VoiceOver order, scene reconnect, RTL icon direction and older-platform fallback remain runtime checks. See `15_STAGE_4.md`.

Stage 6 keeps the iPad rail because a standard UIKit tab/sidebar controller would manage associated content controllers while NOVA already owns primary and secondary routes in Flutter. Compact iPad windows continue using the Flutter dock. iPhone idiom now prevents a wide landscape phone from becoming the tablet rail. Search uses safe-area constraints and app Reduce Transparency restores Flutter controls. Remaining risk is visual and behavioral: standalone tab-bar frame/content clearance, VoiceOver focus, actual reduced-transparency/contrast rendering, modal/share layering and scene reconnect require iOS runtime proof. See `17_STAGE_6.md`.

## Stage 5 player risks (2026-10-23)

Player overlay latency, gesture competition and video composition remain unmeasured on iOS. Stage 5 adds no native player view/control or high-frequency bridge traffic. The shell publishes hidden tabs/search/detail while a player is topmost and rejects hidden-tab intents, but actual overlay disappearance, touch pass-through, rotation and restoration need device proof. The fallback remains the existing Flutter player on every platform; see `16_STAGE_5.md`.
