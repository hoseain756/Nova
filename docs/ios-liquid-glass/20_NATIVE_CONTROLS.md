# Native UIKit controls across iPhone and iPad

This extension follows the earlier chrome migration without changing Flutter's ownership of routes, content, settings, playback state or the iPad rail. `NovaNativeControls.swift` registers a second, low-frequency `nova/ios_controls` channel and a `nova/ios_switch` platform-view factory on the existing implicit Flutter engine. The original `nova/ios_chrome/v1` contract remains separate.

| Surface | iOS source path | Other platforms |
|---|---|---|
| Simple confirmation | `UIAlertController` alert | Existing Flutter alert |
| Settings choices, dropdowns, overflow actions, episode and Continue Watching menus | `UIAlertController` action sheet, with iPad source rectangle where the opening widget supplies one | Flutter dropdown, popup or sheet |
| Settings/profile/collection/watch-party/subtitle switches | Native `UISwitch` embedded in the existing Flutter row | `Switch.adaptive` / `SwitchListTile.adaptive` |
| Complex forms, multi-select dialogs and content sheets | Flutter-owned content and validation | Same Flutter content |
| Main navigation and video/timeline | Existing phone scene chrome / Flutter iPad rail and player | Existing Flutter controls |

UIKit standard components adopt the current iOS appearance when rebuilt with the matching SDK. Apple describes Liquid Glass as a control/navigation layer, and advises using standard UIKit controls rather than applying glass to content cards. The app's cinematic content remains Flutter-rendered. Sources: [Apple UIKit design session](https://developer.apple.com/videos/play/wwdc2025/284/), [Apple materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials), [Flutter iOS platform views](https://docs.flutter.dev/platform-integration/ios/platform-views).

Native choices return only a selected index; Dart applies every setting, route, permission and destructive action. The bridge does not receive credentials, URLs, playback frames or application state. Native presentation uses the foreground scene and a source rectangle for iPad popovers. It honors current light/dark and RTL appearance. Dismissal returns `null`; missing/busy native hosts fall back to Flutter. The switch receives value/enabled updates and sends boolean change intents to its owning Flutter widget.

Windows Dart analysis and widget tests verify the Flutter side only. **The new Swift file, Xcode project entry, iOS 18 fallback appearance, iOS 26 Liquid Glass rendering, VoiceOver, scene dismissal, popup anchoring and player composition still require a Codemagic/Xcode build and physical iPhone/iPad acceptance.** A source change or unsigned IPA alone does not prove those results. Keep the existing Flutter fallback until that evidence is recorded.
