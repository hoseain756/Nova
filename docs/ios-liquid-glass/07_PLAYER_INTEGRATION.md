# Protected player baseline

Current `PlaybackEntryPage` selects Core by default and Legacy with `NOVA_PLAYER_CORE=false`. Both pages use `MediaKitEngine` and the `PlayerVideoSurface` in `lib/features/player/engine/playback_engine.dart`. The `Video` widget provides the media surface; the app draws `SubtitleOverlay` in the same Flutter `Stack` for zoom/timing compatibility. `PlaybackSessionSurface` retains the video child across ordinary overlay rebuilds.

Stage 5 re-audited these paths and kept all player controls in Flutter. The full surface matrix, shell-route tests and future iOS performance baseline are in `16_STAGE_5.md`. No native player action or high-frequency bridge traffic was added. The iOS player measurements remain **IOS RUNTIME PENDING**.

The shared `player_chrome.dart` owns transport, timeline, speed, volume, HUD and up-next layout. `player_side_panel.dart`, `player_sheets.dart` and `player_episodes_sheet.dart` own tracks, subtitles, sources, settings and episodes. `player_skip_segment_pill.dart` presents skip actions. Both routes set landscape orientations and immersive system UI, and restore edge-to-edge UI on exit. Exact engine position remains authoritative for seeks and progress decisions. No AirPlay/Cast or PiP capability was established by this Stage 0 source audit; do not assert it works.

## Stage 0 exclusion and future baseline

No native bar, PlatformView, glass effect or channel is inserted over the video. The phone shell bar must hide on player routes and avoid changing the video view hierarchy. On a compatible Mac/iOS device, record baseline frame times, dropped frames where available, input-to-seek response, source switch and subtitle behavior before any later player-control experiment. Exercise Core and Legacy, playback/pause/seek, long playback, panels, gestures, rotation, RTL timeline direction, skip and next episode. This Windows host yields source-level findings only: frame rate and touch latency are **NOT MEASURED**.
