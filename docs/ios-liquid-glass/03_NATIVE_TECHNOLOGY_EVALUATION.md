# Native technology evaluation

| Option | Authenticity | NOVA fit | Decision |
|---|---|---|---|
| Flutter adaptive/Cupertino only | No native iOS 26 material guarantee | Simple fallback for iOS 15–25 and Android isolation | Fallback only |
| External Liquid Glass package | Depends on actual Swift/UIKit implementation and composition | Unknown lifecycle, RTL, minimum iOS, player layering and maintenance until source/device audit | No dependency in Stage 0 |
| Broad custom SwiftUI/UIKit bridge | Genuine material possible | Too many views/channels and duplicate navigation risk | Reject |
| Hybrid Flutter content + narrow native chrome | Genuine on verified Apple controls | Matches `MainShell` ownership; bounded channel traffic | Recommended, runtime proof pending |

Package listings such as [native_liquid_glass_flutter](https://pub.dev/packages/native_liquid_glass_flutter) claim iOS 13 fallback and native SwiftUI/UITabBar, while [liquid_glass_native](https://pub.dev/packages/liquid_glass_native) advertises iOS 14 minimum and many platform views. These are **maintainer claims**, not NOVA validation. Neither package was installed or source-audited; current versions, issues, RTL, VoiceOver, texture interaction and compositing remain unverified. A package would have to demonstrably outperform a small project-local bridge before reconsideration.

## Embedding comparison for the first iPhone tab proof

1. **Standalone UIKit bar as a sibling overlay in the existing iOS scene:** preferred experiment. Avoids a Flutter `UiKitView` and keeps one `FlutterViewController`; native bar taps are intents only. Must prove Flutter backdrop sampling, safe-area clearance, view ordering, hit testing and lifecycle. No claim that it works yet.
2. **`UiKitView`/`FlutterPlatformView` inside Flutter:** supported by Flutter but incurs hybrid-composition constraints; possible native view ordering and backdrop limitations. Use only if the first approach fails and a measured isolated comparison justifies it.
3. **`UITabBarController` or SwiftUI `TabView` owning multiple pages:** avoid; NOVA's visited pages, Kids gate and routes are Flutter-owned. A second stack or duplicate Flutter view controllers would break the approved architecture.

This was the Stage 0 selection. Stages 2–4 subsequently implemented the standalone scene sibling overlay for capable iOS 26 phones, with `GlassDock` retained as fallback. Composition and appearance remain **IOS RUNTIME PENDING**. No PlatformView was introduced; the current source inventory is in `18_STAGE_7.md`.
