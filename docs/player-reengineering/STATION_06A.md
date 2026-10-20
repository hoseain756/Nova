# Station 06A — Jellyfin Android investigation

- Status: COMPLETE (STATIC-ONLY, exact local upstream checkout inspected)
- Verification status: STATIC-ONLY
- Checklist: 9/9 tasks complete
- Evidence: One authorized `reference_researcher` invocation (Station 06A only); immediate Git status confirmed no agent-created files.

- [x] Inspect read-only upstream checkout at master HEAD `3e660a84bde87281adee8f092b8af48719734916`, license GPL-2.0 (strong copyleft).
- [x] Verify actual integrated/default/optional playback engines from modules and settings.
- [x] Inspect decoder selection, MediaCodec scope, PlayerView, buffering, seek and recovery.
- [x] Inspect audio focus, lifecycle, orientation/fullscreen, and cleanup; frame-rate policy not established by this audit.
- [x] Inspect resume/session replacement and track retention across source/episode changes.
- [x] Record engine-specific lessons and differences from NOVA.
- [x] Cite exact paths/lines with clean-room paraphrase and explicit unknowns.
- [x] Use the one allowed reference researcher invocation; immediate `git status --short` matched pre-existing user changes and showed no agent files.
- [x] Commit only station documentation in the final session checkpoint.

## Findings and evidence

### Findings (STATIC-ONLY)

Agent invocation: 2 total in the session, within roster. No reference source was copied. Jellyfin Android is GPL-2.0 strong copyleft; clean-room paraphrase only.

| Topic | Finding | Evidence status / exact paths |
|---|---|---|
| Actual engine | Integrated/default playback is Media3 ExoPlayer. Web player and optional external apps exist; MPV/mpvKt are external choices, not the integrated engine. | VERIFIED — `app/src/main/java/org/jellyfin/mobile/settings/SettingsFragment.kt:107-123,199-243`; `app/build.gradle.kts:172`; `gradle/libs.versions.toml:132-141,185-192`. |
| Decoder behavior | Media3 renderer builder supports hardware/software filtering, tracks selected decoder type, enables decoder initialization fallback, and retries decoder failures with extension renderers preferred. | VERIFIED — `PlayerViewModel.kt:245-278,779-788`. |
| Surface and subtitles | Uses Media3 `PlayerView`; surface type is not set in the inspected layout and therefore comes from Media3 defaults (inference). Optional ASS subtitle rendering can be attached. | VERIFIED/STRONGLY INFERRED — `fragment_player.xml:9-14`; `PlayerFragment.kt:217-220`; `PlayerViewModel.kt:278-289`. |
| Buffer/source/recovery | Default load control unless user chooses larger presets. Remote source types map to Media3 sources; external subtitles can be attached. Source errors cause bounded retries from current position while progressively relaxing server playback constraints. | VERIFIED — `PlayerViewModel.kt:233-243,789-798`; `QueueManager.kt:214-254,330-401,411-422`. |
| Track handling | Initial tracks are selected when ready. Embedded tracks switch in place; certain transcoded audio/encoded subtitle changes restart from current position. | VERIFIED — `PlayerViewModel.kt:723-730`; `TrackSelectionHelper.kt:22-29,37-48,95-109,149-175`; `QueueManager.kt:443-468,477-498`. |
| Seek/skip/queue | Relative seek, chapter/queue navigation and media-segment skip flows are present. Prompted skip seeks past the marker; autoplay advances queue at end. | VERIFIED — `PlayerViewModel.kt:550-560,645-655,759-767`. |
| Lifecycle/audio/resource cleanup | Process lifecycle observer pauses on stop unless background audio is allowed. Player applies focus handling and noisy-output response; ViewModel releases listener/player/media session on clear. Fragment detaches and restores orientation on destroy. | VERIFIED — `PlayerLifecycleObserver.kt:7-15`; `PlayerViewModel.kt:279-305,807-810`; `MediaExtensions.kt:81-89`; `PlayerFragment.kt:429-452`. |
| Resume/session | Source start time, server progress reporting, and position preservation during retries/restarts are implemented. Process-death resume semantics were not established by this audit. | VERIFIED / UNKNOWN — `PlayerViewModel.kt:307-322,331-338,476-505`; `QueueManager.kt:244-254,443-464`. |
| Performance | Design supports explicit decoder observability, bounded retry, and position/track preservation. No device tests or measurements were performed in this reference review. | UNKNOWN — no runtime data in scope. |

### NOVA applicability

NOVA uses media_kit/libmpv in Flutter. Jellyfin's Media3 buffer presets, MediaCodec filtering, SurfaceView defaults, Compose/ViewModel lifecycle, and Jellyfin server transcoding recovery cannot be transferred directly. Clean-room ideas for later evaluation: keep decoder and source failures distinct, preserve position and selected tracks during retries, bind cleanup to session lifecycle, and expose retry/decoder telemetry.

## Blockers / unknowns

No device performance evidence in this station. Render surface defaults are inferred; process-death resume and actual device decoder selection remain unverified. All Jellyfin references are GPL-2.0, so do not reuse code or distinctive identifiers.

## Commit / LKG

Included in Station 07 session checkpoint. Production LKG remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; production code untouched.
