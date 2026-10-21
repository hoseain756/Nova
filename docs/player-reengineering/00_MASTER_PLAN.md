# NOVA Player Reengineering — Master Plan

## Mission state

- Authoritative specification: `C:\Users\hosea\projects\app\Nova\NOVA_PLAYER_PROMPT_V2_1.md`, SHA-256 `105C6368ACE6B92CC2D793FA8CE61FB519026B56D202FA73CD26584B378F3F50`. The root copy contains Section 54A and takes precedence as the user directed. All root/docs specification copies and backups remain untouched.
- Feature branch: `feature/player-reengineering`.
- Safety tag: `pre-player-reengineering-baseline` → `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
- Production player code: unchanged throughout this session.
- Last-known-good production commit: `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
- Current HEAD before the Station 03 documentation checkpoint: `1676671` (`player: baseline instrumentation`). The instrumentation commit is pre-existing and unchanged in this session.
- Session 2 scope: Station 03 only. Station 03 remains INCOMPLETE for the official baseline; Station 04 and later were not started. Run 1 is retained as an exploratory sample only.
- Physical device: `RF8NA2NNVNY`, Samsung SM-A217F, Android 12/API 31, Exynos 850, arm64-v8a; full facts/limits in `evidence/PHYSICAL_DEVICE_PREFLIGHT.md`.
- Performance frame budget reference: 60.000004 Hz supported mode → 16.67 ms. No valid official baseline metrics were collected; the single exploratory capture is unbounded and excluded.
- iOS: STATIC-ONLY; no Mac/Xcode, Codemagic result, or iOS device was used.
- Agent use: 4 total read-only invocations (NOVA audit once, Jellyfin Android audit once, MPV QoL audit once, and `perf_log_analyst` once for this capture); maximum concurrent count was 1. No agent-created files were produced.

## Task counts and status

Station 03 adds two tasks to track the pre-existing Profile verification and one-time exploratory log analysis. Its official baseline remains INCOMPLETE, not device-BLOCKED.

| Station | Name | Tasks | Done | Status |
|---|---|---:|---:|---|
| 00 | Persistent planning bootstrap | 11 | 11 | COMPLETE |
| 01 | Environment and repository discovery | 13 | 13 | COMPLETE |
| 02 | Deep NOVA player audit | 12 | 12 | COMPLETE — STATIC-ONLY |
| 03 | NOVA performance baseline | 12 | 5 | INCOMPLETE — exploratory sample only; official baseline not captured |
| 04 | Harbor investigation | 10 | 10 | COMPLETE — STATIC-ONLY |
| 05 | Nuvio investigation | 10 | 10 | COMPLETE — STATIC-ONLY |
| 06 | Stremio Kai and supplementary MPV investigation | 11 | 11 | COMPLETE — STATIC-ONLY |
| 06A | Jellyfin Android investigation | 9 | 9 | COMPLETE — STATIC-ONLY |
| 06B | Jellyfin iOS / Swiftfin investigation | 9 | 9 | COMPLETE — STATIC-ONLY |
| 07 | Cross-project engineering comparison | 8 | 8 | COMPLETE — STATIC-ONLY |
| 08 | Root-cause analysis | 8 | 0 | PLANNED — not entered |
| 09 | Final architecture | 9 | 0 | PLANNED — not entered |
| 10 | Playback core stabilization | 10 | 0 | PLANNED — not entered |
| 11 | Player controls and gestures | 8 | 0 | PLANNED — not entered |
| 12 | Subtitles, audio, speed, sources | 9 | 0 | PLANNED — not entered |
| 13 | Resume playback | 7 | 0 | PLANNED — not entered |
| 14 | Generalized skip segment system | 8 | 0 | PLANNED — not entered |
| 15 | Next episode system | 7 | 0 | PLANNED — not entered |
| 16 | NOVA player UI and Liquid Glass | 9 | 0 | PLANNED — not entered |
| 17 | Android platform verification | 8 | 0 | PLANNED — not entered |
| 18 | iOS platform verification | 9 | 0 | PLANNED — not entered |
| 19 | Performance regression and long playback | 9 | 0 | PLANNED — not entered |
| 20 | Final full audit | 10 | 0 | PLANNED — not entered |
| **Total** |  | **212** | **98** |  |

Station tracking files: `00_STATION.md`–`20_STATION.md`, plus `STATION_06A.md` and `STATION_06B.md`. Each station file has been updated for this session; Stations 08–20 explicitly record that they were not entered.

## Last-known-good and documentation commits

The production LKG remains the safety baseline because every session commit listed below changes documentation only.

| Checkpoint | Commit | Production code state |
|---|---|---|
| Safety baseline tag | `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5` | Baseline; existing user changes excluded from commits |
| Station 00 | `7536cf2` | Docs only |
| Station 01 | `a5f5b37` | Docs only; full Flutter suite baseline 452 tests passed |
| Station 02 | `e257689` | Docs only; STATIC-ONLY audit |
| Station 03 | `8a56c5e` | Docs only; performance cells NOT MEASURED |
| Station 04 | `8349e27` | Docs only; exact-SHA Harbor source review |
| Station 05 | `6c9776d` | Docs only; exact-SHA Nuvio source review |
| Station 06 | `aa6f8ca` | Docs only; Stremio and MPV supplement |
| Station 06A | `c11dcae` | Docs only; Jellyfin Android source audit |
| Station 06B | `1b4924d` | Docs only; Jellyfin iOS and Swiftfin source review |
| Station 07 + Session 1 handoff | Pending final checkpoint commit | Docs only |

## License and clean-room status

Exact licenses, upstream refs, and clean-room rules are in `LICENSE_NOTES.md`. Reference snapshots: Harbor MIT; Nuvio GPL-3.0; Stremio Kai GPL-3.0; Jellyfin Android GPL-2.0; Jellyfin iOS MPL-2.0; Swiftfin MPL-2.0; mpv-qol-scripts GPL-3.0. No code snippets or distinctive identifiers were copied. Harbor/Nuvio/Stremio local checkouts were absent and exact-SHA GitHub read-only files were used. The two required reference-agent audits used local Jellyfin Android and MPV-QoL checkouts; agents changed no files.

## Architecture decision log

No architecture or engine decision has been made. Station 03 performance values are absent, so the Station 02 rebuild observations remain hypotheses. No Gate A/B review was reached.

## Session 2 stop condition

Station 03 was stopped at the user's direction after one exploratory Profile capture. The capture has no exact tap/start/stop markers, so no valid official startup timing or per-run performance metrics can be claimed. The official baseline remains INCOMPLETE; Station 04 or later must not be started in this checkpoint. The last-known-good production commit remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
