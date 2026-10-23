# Official Apple research — 2026-10-23

Primary authority: [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass). Apple's browser page requires JavaScript; its search-indexed official content and linked official pages were reviewed. Recheck SDK symbol availability in Xcode before writing Swift.

## Applicable findings

- Liquid Glass is a functional layer for navigation and controls above content. Standard bars, sheets, popovers and controls adopt it with current Apple SDKs. Avoid custom backgrounds that cover system effects. [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass?changes=_2_11); [Materials HIG](https://developer.apple.com/design/human-interface-guidelines/materials).
- Prefer a system `UITabBar`/standard control to hand-built effects. Apple documents standalone `UITabBar` use, but its composition above Flutter has **not** been proven for NOVA. [UITabBar](https://developer.apple.com/documentation/uikit/uitabbar); [UIKit design session](https://developer.apple.com/videos/play/wwdc2025/284/).
- SwiftUI custom-view APIs include `glassEffect(_:in:)`, `GlassEffectContainer`, and glass button styles. UIKit custom glass uses `UIGlassEffect`/`UIGlassContainerEffect` with `UIVisualEffectView`; these are later-OS candidates and must be gated. Standard controls take precedence. [Custom SwiftUI glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views); [UIKit session](https://developer.apple.com/videos/play/wwdc2025/284/).
- Apple's guidance warns against putting Liquid Glass throughout content or overcrowding controls. Keep artwork, grids, prose and video as content. [Materials HIG](https://developer.apple.com/design/human-interface-guidelines/materials).
- System components respond to appearance/accessibility settings. Native custom surfaces must also be checked for Reduce Motion, Reduce Transparency, Increase Contrast, VoiceOver and readable color. [Apple accessibility testing](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app); [UIAccessibility](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducetransparencyenabled).
- A native view's direction and Dynamic Type are native environment/trait concerns; Flutter's locale is not automatically a contract for separately hosted native chrome. [SwiftUI layout direction](https://developer.apple.com/documentation/swiftui/layoutdirection); [Dynamic Type](https://developer.apple.com/documentation/swiftui/environmentvalues/dynamictypesize).

## Availability and compatibility rule

Target iOS 15 per LG-08 and [Apple's Xcode requirements](https://developer.apple.com/xcode/system-requirements): Xcode 26.2 includes the iOS 26.2 SDK and supports iOS 15–26.2 deployment. Put iOS 18/26-only symbols behind appropriate availability checks and provide lower-version paths. Apple documents `UIDesignRequiresCompatibility` for retaining old SDK appearance; it is not the adoption path selected for NOVA. Symbol-level compiler confirmation is IOS BUILD PENDING CODEMAGIC.

## Flutter interoperability sources

[Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels) support discrete asynchronous messages and require correct platform threading. [Flutter iOS platform views](https://docs.flutter.dev/platform-integration/ios/platform-views) use hybrid composition and carry performance/composition limitations. [Flutter adaptive controls](https://docs.flutter.dev/ui/adaptive-responsive/platform-adaptations) are fallback UI, not proof of native Liquid Glass.
