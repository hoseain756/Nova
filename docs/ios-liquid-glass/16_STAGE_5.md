# Stage 5 — player protection and iOS measurement plan

Source snapshot: `feature/player-reengineering` at `2ec313bfd18dc72de3281c999ab5207c3cd23d38` before Stage 5, 2026-10-23. The worktree already contained unrelated modified and untracked work; no commit or push was made. This is **SOURCE VERIFIED** only. **IOS BUILD PENDING CODEMAGIC** and **IOS RUNTIME PENDING**.

Apple's current [Liquid Glass adoption guidance](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass) places the material in the functional controls/navigation layer, advises restraint with custom effects, and calls for testing transparency, motion and contrast settings. The player decision below follows that scope; it does not claim a native runtime result.

## Current player architecture

`lib/features/media/media_detail_page.dart` pushes a Flutter `MaterialPageRoute` containing `PlaybackEntryPage`. `playback_entry_page.dart` selects Core by default (`NOVA_PLAYER_CORE=true`); `--dart-define=NOVA_PLAYER_CORE=false` selects Legacy before engine allocation. Core lives in `core_video_player_page.dart` and `session/playback_session.dart`; Legacy lives in `video_player_page.dart`. Both use `MediaKitEngine` (`engine/playback_engine.dart`), a media_kit/libmpv `Player` and `VideoController`, and the media_kit `Video` widget inside `PlayerVideoSurface`. `PlaybackSessionSurface` caches that child across ordinary overlay rebuilds. `SubtitleOverlay` is Flutter-drawn above video. Core and Legacy retain distinct engine retirement paths; neither was changed in Stage 5.

Both routes build a Flutter `Scaffold` with a full-screen `GestureDetector` and `Stack`. `player_chrome.dart` supplies top, center, side and bottom controls, including timeline and up-next layout. `player_side_panel.dart`, `player_sheets.dart`, and `player_episodes_sheet.dart` own source, audio, subtitle, settings and episode choices. `segments/playback_segments.dart` and `widgets/player_skip_segment_pill.dart` keep skip logic and actions in Flutter. `PopScope` and `_requestClose` own close, including player shutdown; the top-bar button invokes that same path. Both pages request landscape/immersive system UI and restore normal UI on exit. Lifecycle, route replacement, source switching and native retirement remain under their existing Dart/session owners. The source search found no implemented player PiP or AirPlay/Cast control or state machine; the localized word “Cast” alone is not a player feature.

## Surface matrix

| Surface | Current owner | Classification | Stage 5 decision |
|---|---|---|---|
| Video surface | media_kit `Video` via `PlayerVideoSurface` | DO NOT MIGRATE | Keep engine/video composition unchanged. |
| Play/pause | Flutter `PlayerCenterTransport` and engine/session | KEEP FLUTTER | Keep exact command path. |
| Seek backward | Flutter transport/gesture and engine/session | KEEP FLUTTER | Keep exact seek path. |
| Seek forward | Flutter transport/gesture and engine/session | KEEP FLUTTER | Keep exact seek path. |
| Timeline | Flutter `PlayerBottomCluster` | DO NOT MIGRATE | Keep scrub and direction convention in Flutter. |
| Current time/duration | Flutter timeline from engine/session | KEEP FLUTTER | No bridge ticks. |
| Subtitle toggle | Flutter panels and engine track selection | KEEP FLUTTER | Keep existing selection. |
| Audio track button | Flutter side panel/sheets | KEEP FLUTTER | Keep async track workflow. |
| Source button | Flutter side panel/sheets | KEEP FLUTTER | Keep resolver and native retirement rules. |
| Episode button | Flutter side rail/sheet | KEEP FLUTTER | Keep episode/source picker flow. |
| Settings button | Flutter speed/settings panel | DEFER | Overlay and state coupling make native entry unproven. |
| Close/back button | Flutter top bar, `PopScope`, `_requestClose` | DEFER | Low frequency, but integrated with lock, overlay and shutdown; keep Flutter. |
| PiP button | No player feature found | DEFER | No control or state machine to present. |
| Cast/AirPlay button | No player feature found | DEFER | No route picker or cast workflow to present. |
| Full-screen/orientation control | Flutter side rail and `SystemChrome` | KEEP FLUTTER | Keep current landscape/full-screen handling. |
| Volume HUD/slider | Flutter HUD/chrome; existing volume plugin/engine | KEEP FLUTTER | No drag values on chrome bridge. |
| Brightness HUD | Flutter HUD and `screen_brightness` | KEEP FLUTTER | No drag values on chrome bridge. |
| Gesture overlays | Flutter `GestureDetector`/HUD | DO NOT MIGRATE | No competing native recognizer. |
| Skip Intro/recap/opening | Dart segments and Flutter pill | KEEP FLUTTER | Keep exact timing and action. |
| Skip Outro/credits | Dart segments and Flutter pill | KEEP FLUTTER | Keep exact timing and action. |
| Next Episode card/countdown | Flutter up-next placement/actions | KEEP FLUTTER | Keep countdown and picker in Flutter. |
| Loading/buffering indicator | Flutter player `Stack` | KEEP FLUTTER | Keep engine-driven state local. |
| Error/retry state | Flutter error panel and session | KEEP FLUTTER | Keep retry/retirement handling. |

## Native candidates and protected surfaces

No native player controls were introduced because the audit did not establish a safe candidate. Close/back is a possible later low-frequency candidate, but current `PopScope`, lock and animated overlay behavior need device evidence before presentation can move. PiP and AirPlay/Cast are absent. Stage 5 adds no `player.*` action IDs, no UIKit player view, no PlatformView, no second media engine and no Swift changes.

The video surface, timeline, progress, subtitle text/rendering, gesture recognition, seek/volume/brightness feedback, source/audio/subtitle/episode panels, full-screen sheets, buffering/error state, skip timing and next-episode countdown stay in Flutter and the current engine/session. Both player routes remain available. Android, iPad and iOS 15–25 retain their current Flutter player. iOS 26+ also retains it.

## Shell coordination and bridge traffic

`ShellChromeRouteObserver` records the top Flutter route. `MainShell.resolveShellChromeRoute` publishes tab visibility only for the root shell and detail data only when its registered route is current. A pushed player therefore publishes `visible=false`, `searchVisible=false`, `detail=null`; popping it restores the registered detail snapshot, and popping detail restores shell tabs/Home search as appropriate. The existing revision rejects old detail/search actions. Stage 5 additionally rejects tab intents when native tabs are hidden, including during player presentation. Flutter remains the sole route/action owner. `SceneDelegate` already hides the tab, search and detail views from that snapshot; its revision check ignores older snapshots. These are source/state findings, not a runtime overlay observation.

Allowed bridge traffic remains capability lookup, discrete localized presentation snapshots, tab/search/detail intents, and disposal. Stage 5 adds **no messages**. Prohibited on `nova/ios_chrome/v1`: playback position/duration, buffering percentage, animation or video frames, timeline scrubs, gesture deltas, brightness or volume drags, subtitle frames and next-episode countdown. The separate existing torrent/plugin channels are outside this presentation contract.

## iOS runtime measurement baseline plan

Existing `lib/features/player/player_diagnostics.dart` already registers a Flutter `FrameTiming` callback in Debug/Profile and logs periodic build/raster distributions and event counts; both player pages start it, and the engine records open/playing/position/buffering events. This is the available source-level instrumentation for future iOS Profile runs. Its fixed 16.67 ms budget assumes 60 Hz, its summary is not route-scoped, and `recordFirstFrame`/decoder snapshot helpers are not wired into a scheduled capture. Do not present these logs as video dropped-frame data or an iOS performance baseline. Stage 5 adds no runtime sampling or player event bridge.

Before any later native player-control experiment, use the same iPhone/iOS build, source and route sequence for Core and the Legacy rollback build; record device model, OS, build, network/source, media codec/resolution, thermal/battery state, and repetitions. Capture Flutter frame timing (UI/raster frame distributions and jank), dropped video frames if the available player/device tooling exposes a valid counter, overlay open/close jank, touch-to-action and touch-to-seek latency, seek completion/position confirmation, startup-to-first-frame, orientation transition time, source-switch latency, sheet open/close time, subtitle synchronization observations, memory growth/peak and native overlay impact. Compare player entry with the existing shell overlay enabled versus a controlled fallback build only when both are compilable and observable. Keep raw samples and method; never infer a dropped-frame count from UI frame timing. All numerical values: **IOS RUNTIME PENDING**.

## Runtime acceptance still required

- On iOS 26 iPhone: enter player from Home/detail and a nested detail, rotate, background/foreground, replace source/episode, close and reopen. Confirm native tabs/search/detail controls never cover player or steal gesture touches, and the correct prior chrome returns.
- Exercise Core and Legacy: play/pause, back/forward seek, timeline scrubbing in Arabic and English, right volume/left brightness gestures, double tap, lock, subtitle/audio/source/episode panels, skip Intro/Outro, next episode, loading/error/retry and disposal.
- Check portrait-to-landscape and landscape-to-portrait safe areas, notch/Dynamic Island, VoiceOver focus, enlarged text, Reduce Motion, Reduce Transparency, Increase Contrast, dark/light appearance, and no stale native hit regions after rotation or scene reconnect.
- Confirm iOS 15–17 and 18–25 Flutter fallback, iPad rail/player, and Android behavior on real runtimes. PiP/AirPlay/Cast require a separate feature proposal if ever added.

## Validation and status

Focused Dart tests exercise top-route hiding/restoration, unsupported native capability, player snapshots, strict snapshot fields, hidden/stale intent rejection and bridge disposal. Source inspection covers UIKit iOS 26 guards and scene presentation. The final full-project analyzer and selected tests passed; exact Windows checks are recorded in `09_TESTING_STRATEGY.md`. **IOS BUILD PENDING CODEMAGIC**; `codemagic.yaml` and `13_CODEMAGIC_READINESS.md` are unchanged because Stage 5 adds no native build requirement. **IOS RUNTIME PENDING**. Stage 6 has not started.
