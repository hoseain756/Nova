# Station 04 — Harbor investigation

- Status: COMPLETE (STATIC-ONLY, exact upstream snapshot inspected)
- Verification status: STATIC-ONLY
- Checklist: 10/10 tasks complete; local checkout and read-only reference agent unavailable, exact-SHA GitHub fallback used
- Evidence: GitHub read-only file access at commit `9b811556d13f6eb2ba7c524a5bb0d561c88fae94`; no reference source was copied or modified.

- [x] Record upstream path, exact SHA, branch/tag and license. No local checkout was present; upstream is `https://github.com/Harborofficial/Harbor`, branch `beta-branch`, SHA above, MIT.
- [x] Verify actual player engine and integration from source. Harbor is a Tauri 2 desktop application with a Rust `libmpv` player; it is not Flutter/native bridge integration.
- [x] Trace initialization, source open, render integration, hardware-decoder configuration, cache observations, seeking and recovery from source.
- [x] Inspect session/controller/state separation and lifecycle/disposal.
- [x] Inspect subtitle, audio, speed, source-switch behavior from available player source and project documentation; note unverified details below.
- [x] Inspect resume, skip segments, episode transition and controls from exact-snapshot README and player/session source.
- [x] Assess pacing/rebuild/player-recreation evidence without claiming measured performance.
- [x] Capture exact source paths, revision links, and evidence labels using clean-room paraphrase.
- [x] Record unknowns and NOVA applicability limits.
- [x] Commit only Station 04 report/docs on the feature branch.

## Findings and evidence

### Repository and method

- Upstream: [Harborofficial/Harbor](https://github.com/Harborofficial/Harbor), branch `beta-branch`, inspected commit [`9b811556d13f6eb2ba7c524a5bb0d561c88fae94`](https://github.com/Harborofficial/Harbor/tree/9b811556d13f6eb2ba7c524a5bb0d561c88fae94), MIT (per `LICENSE`). No local checkout existed; read-only GitHub source files were fetched at the pinned commit. No code copied; no REA or runtime measurement was available.

### Findings (STATIC-ONLY)

| Topic | Finding | Evidence |
|---|---|---|
| Engine | Harbor embeds `libmpv` inside the Rust/Tauri shell; the React UI runs in a WebView. Not a Flutter player or Flutter-to-native integration. | `src-tauri/src/mpv.rs` imports `libmpv2::{Mpv, MpvInitializer}`; `mpv_probe` creates an embedded libmpv instance. `README.md`, architecture/build sections. |
| Session ownership | `MpvState` holds one optional `MpvSession` behind a mutex. On supported desktop targets the render target can be moved without opening another player session; comments explicitly say a second session would re-open and seek. | `src-tauri/src/mpv.rs`, `MpvState`, `ctx_addr`, `MpvSession`. |
| Events/state | The Rust bridge observes position, duration, pause, end, tracks, volume, chapter, subtitle, dimensions, demuxer cache and paused-for-cache properties. | `src-tauri/src/mpv.rs`, `OBSERVED_PROPS`. |
| Hardware/rendering | Initialization sets target-specific `hwdec` choices and rendering integration, including `auto-safe` on Linux and VideoToolbox copy mode for embedded macOS. Other target settings depend on compile-time/platform options. These are configured choices, not proof of runtime hardware decoder use. | `src-tauri/src/mpv.rs`, `apply_pre_init`; `src-tauri/src/mpv_render_linux.rs`, `src-tauri/src/mpv_render_mac.rs`. |
| Buffer/cache/seek | The bridge exposes demuxer cache duration/state; project configuration describes libmpv, HLS/MPEG-TS paths and stream recovery. Actual buffering thresholds and playback quality are not performance-verified here. | `src-tauri/src/mpv.rs`, `OBSERVED_PROPS`; exact-snapshot `README.md`. |
| Tracks/subtitles | Native engine receives track/subtitle properties and project documentation describes embedded and external subtitle controls and styling. Exact source-specific details are not independently verified for every platform branch. | `src-tauri/src/mpv.rs`, `OBSERVED_PROPS`; `README.md`, player feature section. |
| Lifecycle/recovery | Session state is centralized and render retargeting seeks to avoid session recreation. README describes retry/advance behavior, but retry success and recovery timing are UNKNOWN without runtime evidence. | `src-tauri/src/mpv.rs`; exact-snapshot `README.md`. |
| UI/performance | Desktop React UI is separated from the native Rust/libmpv session, which avoids making Flutter widget rebuilds own decode state by architecture. No frame pacing, surface contention, or resource measurements were published in inspected files. | `README.md` architecture; `src-tauri/src/mpv.rs`. |

### NOVA applicability and unknowns

Useful design evidence: keep rendering/decode session ownership independent from frequently changing Flutter UI state; distinguish position/cache/state events; reuse a live decoder session when only the host rendering target changes. Harbor's desktop libmpv/Tauri/WebView stack does not prove the same pattern will reduce jank with NOVA's media_kit Flutter surface. Platform decoder choices, user sources, runtime event cadence, memory, startup, and frame pacing remain UNKNOWN. No architecture decision is made in Station 04.

## Blockers / unknowns

No local clone was available, and no device/runtime evidence exists. Exact-snapshot GitHub source was used as fallback. Performance outcomes, actual selected decoder, source-specific caching, detailed external subtitle handling, and episode-transition success remain unknown.

## Commit / LKG

Station 04 documentation checkpoint: `8349e27` (`player: station 04 Harbor investigation`). Production LKG remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; no production code changed.
