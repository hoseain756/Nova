# NOVA Cinema platform foundation

The shared theme uses warm parchment and ink surfaces, vermilion action colors, Poppins and IBM Plex Sans Arabic. Arabic has no additional letter spacing. Android 12+ supplies the system accent through `nova/appearance` / `palette`; Flutter derives tonal container colors from that seed while retaining NOVA's action and readable text colors. Other systems retain the neutral palette. OLED mode keeps its black base surfaces.

The shell keeps navigation visible when scrolling. A floating dock remains available in compact windows, while windows at least 840 logical pixels wide use a labeled sidebar at logical start. A known iPhone retains its compact navigation in landscape. The sidebar takes layout width rather than covering page content; the existing dock clearance remains responsible for compact layouts. Flutter still makes all routing, Kids gate, and selected-state decisions.

On supported iOS 26 devices, the existing scene overlay presents UIKit controls. Wide iPad windows use a `UIVisualEffectView` with `UIGlassEffect` and a scrollable group of native navigation buttons; compact windows use the native tab bar. Button intents go through the same revision and enabled-tab checks before Flutter changes routes. Secondary destinations remain available through Settings. Pre-26, unsupported scenes, the in-app reduce-transparency setting, or a system Reduce Transparency setting at capability detection use the Flutter dock/sidebar. Native overlays are hidden for player and unrelated routes. A native system Reduce Transparency notification immediately removes the overlay and asks Flutter to refresh capabilities; capabilities are also refreshed on resume. Flutter can restore native chrome if the setting permits it again. These transitions still require native device validation.

The environment snapshot on `nova/appearance` / `environment` contains `wifi`, `lowPower`, and `dataSaver` booleans. Unknown network state is conservative. iOS uses an asynchronously updated `NWPathMonitor`, so an early snapshot may be conservative; consumers should refresh on resume and before starting network-intensive work. Android reports the OS background restriction; iOS reports Low Data Mode. Metered or expensive networks are not treated as data saver by themselves.

The shell refreshes iOS capabilities on resume and on UIKit's Reduce Transparency
change notification. UIKit removes the overlay immediately when the setting is
enabled and rejects stale queued presentations. The bridge invalidates its
intent authority while retiring, retains monotonic revisions, and can recover
without disposing its channel. This also permits a previously unavailable scene
to opt into native chrome on a later refresh. Bridge/shell tests exercise the
transitions with a mocked host; actual native notification behavior needs a device.

Apple describes `UIGlassEffect` and `UIVisualEffectView` in [UIGlassEffect](https://developer.apple.com/documentation/uikit/uiglasseffect) and [Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/). The iOS implementation requires an Xcode 26 build and has not been compiled or validated on an iPad or iPhone in this workspace. Dynamic color, system accessibility changes, network policy snapshots, window resizing, focus, and native safe-area behavior also need real-device validation. Flutter tests cannot establish native presentation or visual acceptance.
