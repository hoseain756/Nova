# Station 02 — Deep NOVA player audit

- Status: COMPLETE
- Verification status: STATIC-ONLY
- Checklist: 12/12 tasks complete
- Evidence: Read-only audit by the authorized `nova_player_auditor`; findings below include exact source references. Audit did not measure runtime rates or device performance.

- [x] Trace user source selection through source resolution, controller creation, decoder readiness, first rendered frame, and UI sync (runtime first frame remains unmeasured).
- [x] Map player entry points, widgets, controllers, services, models, state providers, wrappers, and native bridges.
- [x] Identify actual engine/package/backend, renderer and surface/texture path from dependencies and source.
- [x] Trace create/open/play/pause/seek/background/foreground/orientation/source/episode/fullscreen/dispose lifecycle.
- [x] Map position, duration, buffer, state, track and subtitle event rates and listeners; runtime rates not measured.
- [x] Assess static rebuild scope: video surface versus controls, providers, setState, timers and animation listeners.
- [x] Inspect overlay order, clips, transformations, blur/backdrop filters and compositing around the surface.
- [x] Audit codec fallback, buffering/cache, track selection and source/recovery behavior from implementation.
- [x] Map resume, skip markers, completion thresholds and next-episode logic for duplication/ownership.
- [x] Classify relevant components KEEP / REFACTOR / REPLACE / INVESTIGATE FURTHER with STATIC-ONLY status.
- [x] Record disposal/subscription risks and likely hypotheses separately from measured causes.
- [x] Use the authorized read-only `nova_player_auditor` once; immediately run `git status --short`. Status contained only pre-existing user changes and no player-audit output files.

## Findings and evidence

### Evidence boundary

All findings in this station are STATIC-ONLY from source inspection. They are not device measurements, confirmed performance causes, or proof of runtime decoder selection. Agent invocation 1 of the allowed 1 for this station; the agent changed no files. No REA tool was available, so direct source inspection is the evidence method.

### Player flow and ownership

- `lib/features/player/video_player_page.dart` is the user-facing player page. `initState` initializes the playback engine (`:203-238`); engine recreation paths include hardware-decoder-stall recovery (`:448-455`), failed-playback retry (`:529-557`), software-decoder retry, and error-panel retry (`:1866-1876`).
- `lib/features/player/engine/playback_engine.dart` creates media_kit `Player` and `VideoController` (`:96-127`). `lib/main.dart` calls `MediaKit.ensureInitialized()`. Package/build inventory in Station 01 identifies `media_kit` and platform libraries; runtime backend and active decoder were not measured.
- Source selection/resolution and `Player.open` are owned by the page/engine path; the audit did not observe a real source reaching decoder readiness or a rendered frame. Stream-specific startup behavior is therefore NOT MEASURED.
- Engine subscriptions cover playing, completed, buffering, position, duration, buffer, rate, volume, tracks, selected track, and errors (`engine/playback_engine.dart:96-127`). The page also listens for torrent status (`video_player_page.dart:282-288`).
- Position updates change engine state and notify listeners without a value equality guard (`engine/playback_engine.dart:428-431`, `:473-476`). The page listener calls `setState` (`video_player_page.dart:460-490`, `:1782-1815`), rebuilding the page Stack. Event cadence is not established by source and is NOT MEASURED.
- Playing, position, duration, buffer, and track updates notify; some other event handlers have equality guards (`engine/playback_engine.dart:406-470`). Subtitle overlay maintains a separate state listener (`widgets/subtitle_overlay.dart:212-224`, `:244-247`).
- Engine disposal cancels subscriptions and disposes its player (`engine/playback_engine.dart:478-487`). Page disposal removes the listener, disposes engine/timers/torrent subscription, and stops torrent handling (`video_player_page.dart:1752-1771`, `:451-454`, `:536-557`). No leak has been measured; lifecycle behavior across real playback remains INVESTIGATE FURTHER.

### Rendering, controls, and feature ownership

- The playback surface and subtitle overlay are siblings in an inner Stack (`playback_engine.dart:508-529`); the page builds this within an outer Stack (`video_player_page.dart:1854-1890`). The audit found no RepaintBoundary around these paths.
- `ClipRect` contains transformed video; HUD/chrome uses `AnimatedOpacity` with stacked overlays (`video_player_page.dart:1878-1890`, `:1903-1919`, `:1935-1944`). No BackdropFilter was found in the audited paths. This describes widget structure only; raster/compositing cost is NOT MEASURED.
- Settings panels pause/resume playback as needed and do not inherently recreate the engine (`video_player_page.dart:1029-1084`; `player_sheets.dart:125`). Resume, intro/outro skip, and next-episode logic live in page methods (`video_player_page.dart:203-215`, `:564-580`, `:1472-1494`). Ownership overlap and user behavior require runtime/product review.
- Hardware/software decoder retry, source recovery, cache/buffering policy, track selection, and failure paths are implemented in player code, but this static audit does not establish codec support, selected decoder, buffer effectiveness, seek latency, or recovery success on a device.

### Triage (not an architecture decision)

| Component / question | Preliminary classification | Reason / evidence boundary |
|---|---|---|
| Engine creation/disposal and stream cancellation | KEEP, then verify | Explicit lifecycle and cancellation paths exist; no leak or runtime lifecycle result measured. |
| Per-position page-wide `setState` scope | REFACTOR candidate | Position notifications are unguarded and page listener calls `setState`; impact on video/UI pacing is only a hypothesis pending Station 03 instrumentation. |
| Surface/overlay Stack and animated chrome | INVESTIGATE FURTHER | Structure identified; actual GPU/raster or texture synchronization cost unknown. |
| Decoder stall/retry and software fallback | INVESTIGATE FURTHER | Recovery code exists; no device stream, decoder counter, or success rate observed. |
| Resume/skip/next-episode behavior | KEEP provisionally, verify ownership | Logic is present in page methods; no duplicate-state or transition behavior established. |

### Testable hypotheses for Station 03 / later root-cause work

1. Position notifications may cause avoidable page-wide rebuild work; compare Flutter frame timings and rebuild counts with controls shown/hidden.
2. The layered surface, subtitle, transformed clip, and animated chrome may add composition work; inspect profile timeline and engine counters separately.
3. Torrent status updates may trigger extra page rebuilds during torrent playback; compare torrent versus direct HTTP only when both real sources are available.
4. Decoder-recreation retries may interrupt playback; observe player recreation counts and first-frame/recovery behavior.

These are hypotheses only, not attributed causes. Runtime event rates, frame timings, decoder drops, CPU/GPU, memory trends, source-switch timings, and first-frame timings remain NOT MEASURED.

## Blockers / unknowns

No runtime stream was observed during Station 02. The precise end-to-end source/decoder/first-frame path, event rates, active decoder, renderer behavior, and lifecycle under playback remain unverified. Station 03 will record any stream/device limitations and may use the prompt-authorized public test stream only if it can be safely played through NOVA.

## Commit / LKG

Station 02 documentation checkpoint: `e257689` (`player: station 02 deep nova player audit`). Last-known-good production commit remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; production player code is untouched.
