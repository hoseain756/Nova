# Station 05 — Nuvio investigation

- Status: COMPLETE (STATIC-ONLY, exact upstream snapshot inspected)
- Verification status: STATIC-ONLY
- Checklist: 10/10 tasks complete; local checkout and read-only reference agent unavailable, exact-SHA GitHub fallback used
- Evidence: GitHub read-only file access at commit `324afcffb962f1f7df45c5fa951131acec5a15a7`; no reference source was copied or modified.

- [x] Record upstream path, SHA, branch and license. No local checkout was present; upstream `NuvioMedia/NuvioMobile`, branch `cmp-rewrite`, inspected SHA above, GPL-3.0.
- [x] Verify actual engine/backend from dependencies and platform code.
- [x] Trace Android engine selection, rendering, buffering, decoding, lifecycle, seek and recovery.
- [x] Inspect session/state ownership, subscriptions, disposal and source transitions.
- [x] Inspect subtitle/audio selection, speed and source-related engine behavior.
- [x] Inspect resume position, skip and next-episode state paths from source inventory/player modules.
- [x] Compare evidence independently with Harbor and current NOVA; keep platform differences explicit.
- [x] Capture exact source paths and VERIFIED / STRONGLY INFERRED / UNKNOWN labels.
- [x] Record non-transferable details and unknowns; no implementation copied.
- [x] Commit only Station 05 report/docs on the feature branch.

## Findings and evidence

### Repository and method

- Upstream: [NuvioMedia/NuvioMobile](https://github.com/NuvioMedia/NuvioMobile), branch `cmp-rewrite`, inspected commit [`324afcffb962f1f7df45c5fa951131acec5a15a7`](https://github.com/NuvioMedia/NuvioMobile/tree/324afcffb962f1f7df45c5fa951131acec5a15a7), GPL-3.0 (`LICENSE`). No local checkout existed; GitHub read-only source at the pinned commit was used. No source copied.

### Findings (STATIC-ONLY)

| Topic | Finding | Evidence |
|---|---|---|
| Platform/engine | This is a Kotlin Multiplatform/Compose application, not Flutter. Android engine setting supports `Auto`, `ExoPlayer`, and `Libmpv`; Auto resolves to ExoPlayer and falls back to libmpv on an ExoPlayer error. | `composeApp/src/androidMain/kotlin/com/nuvio/app/features/player/PlayerEngine.android.kt:125-207`; `composeApp/build.gradle.kts` and MPVKit modules. |
| Session/rendering | Android ExoPlayer is surfaced through Media3 `PlayerView` via Compose interop. The source key includes URI, audio URL, normalized headers/type, chunking, and resume request; engine state is remembered against source/engine. | `PlayerEngine.android.kt:125-207`, `:263-270`, `:442-470`. |
| Buffer/cache | Configurable buffer durations and size feed the Media3 load-control path. VOD cache wraps eligible non-adaptive/non-chunked streams, while HLS/DASH/SmoothStreaming and chunked YouTube avoid that cache wrapper. This is source behavior, not measured cache performance. | `PlayerEngine.android.kt` data-source factory path; `PlaybackBufferSettings`; `VodCache` module. |
| Events/diagnostics | Playback logs include prepare attempts, elapsed time, state, position, buffered position, duration, errors, and first-frame events. Existence of diagnostics is not a result for NOVA or a performance measurement. | `PlayerEngine.android.kt:95-98`, `:507-513`, `:603-688`. |
| Recovery | Auto mode can switch from ExoPlayer to libmpv. Decoder failure paths can retain current position and retry with app decoder priority; source errors can trigger MIME probe and retry. | `PlayerEngine.android.kt:150-177`, `:603-650`. |
| Lifecycle/resource cleanup | `DisposableEffect` removes listeners and sidecar subtitle work; lifecycle observer pauses on stop except PiP/active now-playing cases. Disposal removes the observer, releases the player/ASS layer, and evicts cached session state. | `PlayerEngine.android.kt:690-745`. |
| Tracks/features | Track changes are observed and pending audio/subtitle selections restored/applied when tracks arrive. Playback controller exposes seek, speed, and track operations. | `PlayerEngine.android.kt:690-745`, `:780-850`; common player feature modules. |
| UX/state | Project separates common Compose player surface/control/state modules from Android engine implementation; this resembles a platform adapter split, not Flutter's widget/provider lifecycle. Resume and skip/episode modules exist; detailed persistence semantics are outside the inspected lines and need further review. | `composeApp/src/commonMain/kotlin/com/nuvio/app/features/player/`; Android `PlayerEngine.android.kt`. |

### NOVA applicability and unknowns

The strongest transferable observation is explicit source-keyed engine ownership, platform engine adapter separation, and actionable startup/error telemetry. Nuvio's Android default is Media3 ExoPlayer, with libmpv selectable; NOVA currently uses media_kit/libmpv through Flutter. No measured performance comparison is available. Nuvio-specific Kotlin/Compose, Android cache, subtitle, decoder, and service code cannot be assumed transferable to NOVA or iOS. No architecture decision is made here.

## Blockers / unknowns

No local checkout or reference researcher run was available for this repo; direct GitHub exact-revision source was used. Android playback configuration and diagnostic logging were inspected; runtime engine selection per user setting, actual decoder, startup, drop counters, memory, and resume/episode correctness remain UNKNOWN. Source line coverage is selective, not a full code audit.

## Commit / LKG

Included in Station 07 session checkpoint. Production LKG remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; no production code changed.
