# Station 06B — Jellyfin iOS / Swiftfin investigation

- Status: COMPLETE (STATIC-ONLY, exact upstream snapshots inspected)
- Verification status: STATIC-ONLY
- Checklist: 9/9 tasks complete; source review completed through exact-SHA GitHub fallback
- Evidence: Read-only GitHub sources at exact commits; no source copied or modified.

- [x] Record exact Jellyfin iOS source SHA/branch/license.
- [x] Verify actual iOS stack from Expo dependency and player source.
- [x] Since it is not a native AVPlayer pipeline, use Swiftfin as a read-only native iOS reference and record its SHA/license.
- [x] Inspect evidenced audio mode, fullscreen, and app config; label unexposed lifecycle behavior UNKNOWN.
- [x] Inspect AVPlayer session/item reuse, seek, tracks and stop cleanup in Swiftfin.
- [x] Record differences from NOVA Flutter/media_kit and iOS static-only limit.
- [x] Cite exact paths and classify evidence.
- [x] Review reference-agent applicability: no local iOS/Swiftfin checkout was available and agent policy prohibits network; exact-SHA GitHub source was used instead.
- [x] Commit only Station 06B report/docs on the feature branch.

## Findings and evidence

### Repository and method

- Jellyfin iOS: [jellyfin/jellyfin-ios](https://github.com/jellyfin/jellyfin-ios), `master`, SHA [`ceca8eb14ef79e2c0d7bde99d95213c7d69d131d`](https://github.com/jellyfin/jellyfin-ios/tree/ceca8eb14ef79e2c0d7bde99d95213c7d69d131d), MPL-2.0 (`LICENSE`).
- Native iOS supplement: [jellyfin/Swiftfin](https://github.com/jellyfin/Swiftfin), `main`, SHA [`f9842d500f2b1c3178bebbcbf67d6b82d21d47ec`](https://github.com/jellyfin/Swiftfin/tree/f9842d500f2b1c3178bebbcbf67d6b82d21d47ec), MPL-2.0 (`LICENSE.md`). No local copies were present for either; exact-SHA read-only GitHub files used. No Mac/Xcode or iOS device was used.

### Findings (STATIC-ONLY)

| Topic | Finding | Evidence |
|---|---|---|
| Jellyfin iOS actual stack | React Native/Expo app using `expo-av` `Video` and `Audio`; repository-owned source does not prove direct AVPlayer implementation. The native adapter is named `ExpoVideoPlayer`; its native internals are external. | `package.json:54-58`; `components/VideoPlayer.js:9-11,87-95`; `assets/js/plugins/NativeVideoPlayer.staticjs:8-17`. |
| Session/audio/fullscreen | Effects set Expo audio mode to do-not-mix and load URI plus saved position when media changes. Component uses native controls, opens fullscreen when display-ready, reports playback status, and calls `unloadAsync()` on fullscreen dismissal. | `components/VideoPlayer.js:25-33,35-45,87-125`. |
| Background modes | iOS metadata declares audio and fetch background modes, but this alone does not prove actual background-video behavior or interruption recovery. | `app.json`, `ios.infoPlist.UIBackgroundModes`. |
| Native iOS supplement | Swiftfin has an actual `AVMediaPlayerProxy` that constructs `AVPlayer` and `AVPlayerLayer`; sibling MPV and VLC proxies also exist. | `Shared/Objects/MediaPlayerManager/MediaPlayerProxy/MediaPlayerProxy+AVPlayer.swift:16-33`; sibling `MediaPlayerProxy+MPV.swift`, `MediaPlayerProxy+VLC.swift`; `MediaPlayerManager.swift`. |
| Swiftfin reuse/cleanup | `playNew(item:)` makes an `AVPlayerItem` and replaces current item. A one-second main-queue time observer updates manager progress; stop pauses and removes periodic/item observers. | `MediaPlayerProxy+AVPlayer.swift:275-360`. |
| Swiftfin tracks | AV proxy supports seek/rate/audio/subtitle actions; manager routes track changes in place or rebuilds playback item when required by stream constraints. | `MediaPlayerProxy+AVPlayer.swift:88-152`; `MediaPlayerManager.swift:390-430`. |
| Performance / platform | Static architecture only; no iOS build/runtime, dropped frames, CPU/memory, background behavior, or interruption result. | No Mac/Xcode/device evidence. |

### NOVA applicability

Swiftfin is the native iOS comparison for proxy abstraction and explicit AVPlayer item lifecycle; its SwiftUI/native stack differs from NOVA's Flutter media_kit plugin. Do not call Jellyfin iOS AVPlayer evidence. No architecture decision is made.

## Blockers / unknowns

No Codemagic run, Mac/Xcode, or iOS device evidence. Expo native internals remain external; Swiftfin AVPlayer facts are static. Reference agents could not inspect missing local clones under their no-network policy.

## Commit / LKG

Station 06B documentation checkpoint: `1b4924d` (`player: station 06B Jellyfin iOS investigation`). Production LKG remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; no production code changed.
