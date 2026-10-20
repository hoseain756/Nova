# Station 07 — Cross-project engineering comparison

- Status: COMPLETE (STATIC-ONLY comparison; no architecture decision)
- Verification status: STATIC-ONLY
- Checklist: 8/8 tasks complete
- Evidence: Stations 02–06B; exact source references and confidence limits retained in each station report.

- [x] Build the required matrix for NOVA and all requested reference applications.
- [x] Compare engines, integration, renderers, hardware decoder policy, buffering and frame-pacing evidence; distinguish configured and measured evidence.
- [x] Compare startup, seek, state/events, tracks, speed and source handling.
- [x] Compare resume, skip, next episode, lifecycle/recovery and cleanup.
- [x] Compare phone/tablet UX; label evidence by platform and runtime status.
- [x] Incorporate MPV scripts as supplemental evidence and classify their relationship to Stremio Kai.
- [x] Tie recommendations to source evidence and state tradeoffs/unknowns.
- [x] Stop at Station 07; no Station 08 work performed. Commit Station 07 documentation checkpoint on the feature branch.

## Findings and evidence

## Cross-project comparison (static evidence only)

`VERIFIED` below means the named source/configuration demonstrates the described implementation choice. It does not mean that performance was verified. All playback-quality metrics are NOT MEASURED unless explicitly indicated.

| Area | NOVA current | Harbor | NuvioMobile | Stremio Kai | Jellyfin Android | Jellyfin iOS / Swiftfin | NOVA implication for later evidence/design |
|---|---|---|---|---|---|---|---|
| Player engine | `media_kit`/libmpv Flutter integration (`lib/features/player/playback_engine.dart`, `pubspec.yaml`); static only | Native libmpv embedded in Rust/Tauri; desktop | Android default Media3 ExoPlayer, optional libmpv fallback | Desktop MPV integration; inherited from Stremio Community | Integrated Media3 ExoPlayer; external apps optional | Jellyfin iOS Expo AV wrapper; Swiftfin has AVPlayer, MPV, VLC proxies | Compare the actual NOVA path to source/lifecycle traits; do not select an engine by another project's platform features. |
| UI/native integration | Flutter page + engine/controller; subscriptions feed page state | React WebView UI separated from Rust native playback | Kotlin Multiplatform/Compose with Android platform player surface | Desktop WebView2 bridge to MPV scripts | Native Android ViewModel + PlayerView | React Native/Expo wrapper; Swiftfin native SwiftUI/proxy manager | UI/player state ownership is a testable design area; Harbor/Nuvio/Jellyfin architectures do not directly map to Flutter. |
| Rendering/surface | media_kit VideoController/surface; exact runtime texture path and composition effect NOT MEASURED | libmpv platform rendering; render-target retargeting can preserve session | Android Media3 PlayerView or optional MPV surface | MPV `gpu-next` profile | Media3 PlayerView; default surface inferred from layout | Expo AV internals external; Swiftfin AVPlayerLayer for AV proxy | Measure Flutter/raster timing separately from decoder drops and inspect texture/surface lifecycle before changes. |
| Hardware decode | Stall/retry and software retry code exists; active runtime decoder UNKNOWN | Platform-specific libmpv `hwdec` configuration; not runtime-confirmed | Decoder settings/retry and libmpv option exist; selected runtime path varies | MPV config sets render profile, does not prove decoder selection | Media3 filters hardware/software decoder list; selection observable in source | Expo internals unknown; AVPlayer native selection not characterized in source | Add runtime decoder evidence to the diagnosis; do not treat codec declarations or source options as proof of active hardware decode. |
| Buffering/cache | runtime buffer policy and results NOT MEASURED in Station 02/03 | Exposes MPV cache state; exact runtime results unknown | Configurable Media3 load control, optional VOD cache, adaptive sources bypass wrapper | Large MPV cache/readahead values (desktop configuration) | Default or user-selected larger load control; server source fallback | No buffer policy characterized for Expo; Swiftfin uses native player behavior | Avoid transplanting desktop cache sizes; baseline NOVA on repeatable sources first. |
| Frame pacing / dropped frames | NOT MEASURED; position events can rebuild page (hypothesis) | No measurements | Diagnostics and events exist in source, no comparable run | No comparable measurements | Decoder type and analytics available in source; no comparable run | No comparable iOS measurement | Cannot rank smoothness across projects from source or marketing statements. |
| Startup / first frame | NOT MEASURED | Embedded engine setup/source open exists; no latency data | Logs prepare/state/first-frame elapsed in Android; no measured values here | No timing evidence | Source prepare and state events; no measured values | Expo onReadyForDisplay event; no measured values | Establish a real NOVA TTFF baseline with ≥3 Profile runs before modifying player code. |
| Seek/source recovery | NOVA retry/rebuild paths statically audited; runtime outcomes unknown | Session reuse and render retarget; README describes fallback/advance | Retains start position on decoder retry; MIME probe and MPV fallback in Auto | MPV reconnect configured; runtime unknown | Bounded source retries from current position and altered delivery profiles | Expo reloads URI from saved position; Swiftfin may replace item for new playback | Separate source failure, decoder failure, and surface/lifecycle recovery; measure latency and success. |
| Events/state | Engine streams include position/duration/buffer/state/tracks/errors; unguarded position notify reaches page `setState` | Rust observes explicit MPV properties | Media3 listener snapshots and structured diagnostic logs | WebView-to-MPV messages, script configuration; cadence unknown | Player.Listener, ViewModel LiveData, queue/session state | Expo status callback; Swiftfin 1-second progress observer | Profile event/rebuild counts and bound high-frequency updates to minimal UI regions only if measurements support it. |
| Subtitles/audio/speed | Existing media_kit track controls; details in Station 02; runtime switching NOT MEASURED | MPV track/property control and styling | Media3 tracks, sidecar subtitles, language preferences and retry; optional libass | MPV settings plus smart track selector scripts | Media3 track selector; encoded formats may restart | Expo AV status/controls; Swiftfin stream selection | Preserve track selection over source retry and test external/embedded subtitle transitions on NOVA. |
| Resume/skip/next episode | Page owns resume/skip/next flows; runtime behavior NOT MEASURED | Resume, skip segments, next/previous features documented | Resume/skip/next modules and server progress integration | MPV skip notifications and profile bridge | Start position/server reporting, chapter/segment skips, queue autoplay | Expo restores stored position; Swiftfin manager owns playback item/progress | Keep progress/segment/episode ownership explicit and avoid duplicate state; validate transitions on real content. |
| Lifecycle/cleanup | Page/engine dispose listeners, Player, torrent/timers; runtime lifecycle unverified | Single session state; platform retarget may avoid restart | Compose effects unregister listeners, lifecycle-aware pause and explicit release | Desktop app/config only; mobile lifecycle not applicable | Lifecycle observer, MediaSession/player release, fragment detachment | Expo player unload on dismiss; Swiftfin stops and removes observers | Measure background/foreground and surface recreation on NOVA, then ensure deterministic cleanup. |
| Phone/tablet UX | Flutter phone app, no tablet device tested | Desktop UX only | Android/Compose with phone-oriented controls; reference source only | Desktop only | Android phone/TV app; device layout static only | iOS Expo declares tablet support; Swiftfin is native Apple-platform app | NOVA device coverage is NOT MEASURED for player UX; do not generalize from reference platforms. |
| License | NOVA project license governs | MIT | GPL-3.0, strong copyleft | GPL-3.0, strong copyleft | GPL-2.0, strong copyleft | MPL-2.0, weak copyleft; Swiftfin MPL-2.0 | Clean-room notes in `LICENSE_NOTES.md`; no snippets or distinctive identifiers reused. |

## NOVA-specific evidence-backed recommendations (not decisions)

1. Capture Profile-mode Flutter frame timings, event/rebuild counts, PSS/CPU, and engine decoder/drop statistics before attribution. Section 03 currently has zero runs; source inspection alone cannot tell whether UI rebuilds cause the reported stutter.
2. In later design review, evaluate whether high-frequency position updates can target a small progress/control region while keeping the video surface and decoder session stable. Evidence: NOVA `engine/playback_engine.dart:428-431,473-476` and `video_player_page.dart:460-490,1782-1815`; tradeoff: an overly split state model can add synchronization complexity.
3. Preserve selected tracks and resume position across decoder/source retries. Evidence: Nuvio `PlayerEngine.android.kt:603-650,690-745`; Jellyfin Android `PlayerViewModel.kt:789-798`, `QueueManager.kt:244-254,443-468`. Transfer the behavior only after mapping NOVA source and user preference semantics.
4. Distinguish decoder failure, source/network failure, and render/lifecycle failure in diagnostic records and recovery policy. Evidence: Nuvio error-path classification, Jellyfin retry paths, and Harbor's separate MPV session/cache state. Tradeoff: more telemetry/state must remain debug/profile-only and low overhead.
5. Avoid copying Stremio Kai's desktop cache sizes into NOVA. They are static config values, not measurements, and may consume excessive memory on NOVA's 3.8 GB handset.
6. Keep external-source clean-room discipline. Harbor is MIT; Nuvio and Stremio Kai are GPL; Jellyfin Android is GPL; Jellyfin iOS/Swiftfin are MPL. No reference implementation code was copied.

## Limits and decisions

- This is a comparison of implementation evidence, not a benchmark. Flutter jank, decoder drops, buffering, TTFF, CPU, memory, real-source switching, or user-perceived smoothness were not measured.
- Harbor, Nuvio and Stremio Kai were inspected through read-only GitHub files at pinned exact SHAs; local clones for them were not present. Jellyfin Android used its exact local clone and one allowed read-only reference agent. Jellyfin iOS/Swiftfin used pinned exact-SHA GitHub files.
- The companion MPV scripts' README says the collection originated for Stremio Kai, but direct linkage/version match to the inspected Stremio Kai snapshot is UNKNOWN.
- iOS remains static-only; no Mac, Xcode, Codemagic build log, or device evidence.
- Station 07 makes no engine/architecture choice and does not enter Station 08.

## Blockers / unknowns

Station 03 remains NOT MEASURED despite connected physical phone. No implementation or architecture gate was reached. Copyleft reference repositories were paraphrased only.

## Commit / LKG

Documentation checkpoint pending. Production LKG remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; code unchanged.
