# NOVA Player Reengineering — Master Plan

## Mission state

- Specification: `C:\Users\hosea\projects\app\Nova\NOVA_PLAYER_PROMPT_V2_1.md` (root copy, SHA-256 `105C6368ACE6B92CC2D793FA8CE61FB5` prefix; full hash recorded in Station 00). The same-named copy under this directory and root backup are older identical copies that omit Section 54A; root copy is authoritative per the user's explicit Section 54A instruction.
- Current branch: `feature/player-reengineering`
- Safety tag: `pre-player-reengineering-baseline` at `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`
- Last-known-good production commit: `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5` (initial tree; no production changes in this mission). Latest documentation checkpoint: see git log.
- Project status: IN PROGRESS — Stations 00–07 in scope for this session; stop after Station 07.
- Production player code: untouched by this run.
- Device: `RF8NA2NNVNY` (physical USB Samsung SM-A217F, Android 12/API 31); preflight available. Full facts and limits: `STATION_00.md`.
- iOS: STATIC-ONLY in this environment; no Mac/Xcode/device per specification.
- Agent budget: see Section 54A in the root specification; default one agent at a time, maximum three, trio parallelism only for Stations 04/05/06. Post-run Git status check required after every agent.

## Task counts and station status

Counts below are initial concrete checklist counts. Only checked tasks have evidence in the station file.

| Station | Name | Tasks | Done | Status |
|---|---|---:|---:|---|
| 00 | Persistent planning bootstrap | 11 | 11 | COMPLETE |
| 01 | Environment and repository discovery | 13 | 13 | COMPLETE |
| 02 | Deep NOVA player audit | 12 | 0 | PLANNED |
| 03 | NOVA performance baseline | 10 | 0 | PLANNED |
| 04 | Harbor investigation | 10 | 0 | PLANNED |
| 05 | Nuvio investigation | 10 | 0 | PLANNED |
| 06 | Stremio Kai and supplementary MPV investigation | 11 | 0 | PLANNED |
| 06A | Jellyfin Android investigation | 9 | 0 | PLANNED |
| 06B | Jellyfin iOS / Swiftfin investigation | 9 | 0 | PLANNED |
| 07 | Cross-project engineering comparison | 8 | 0 | PLANNED |
| 08 | Root-cause analysis | 8 | 0 | PLANNED |
| 09 | Final architecture | 9 | 0 | PLANNED |
| 10 | Playback core stabilization | 10 | 0 | PLANNED |
| 11 | Player controls and gestures | 8 | 0 | PLANNED |
| 12 | Subtitles, audio, speed, sources | 9 | 0 | PLANNED |
| 13 | Resume playback | 7 | 0 | PLANNED |
| 14 | Generalized skip segment system | 8 | 0 | PLANNED |
| 15 | Next episode system | 7 | 0 | PLANNED |
| 16 | NOVA player UI and Liquid Glass | 9 | 0 | PLANNED |
| 17 | Android platform verification | 8 | 0 | PLANNED |
| 18 | iOS platform verification | 9 | 0 | PLANNED |
| 19 | Performance regression and long playback | 9 | 0 | PLANNED |
| 20 | Final full audit | 10 | 0 | PLANNED |
| **Total** |  | **210** | **8** |  |

Station-specific checklists are `STATION_00.md` through `STATION_20.md`, plus `STATION_06A.md` and `STATION_06B.md`. Counts are revised only with a note when evidence changes the applicable work.

## Last-known-good record

| Checkpoint | Commit | Production code state | Evidence |
|---|---|---|---|
| Safety baseline | `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5` | Untouched by this task | `pre-player-reengineering-baseline`; pre-existing user modifications were present and are excluded from this branch's commits |
| Station 00 docs | `7536cf2` | Docs only; production tree unchanged | 452-test baseline was run at Station 01 |

## Architecture Decision Log

No architecture decisions have been made. Decisions will be logged after evidence collection and user Gate A/B as required.

## Session scope and stop condition

Proceed sequentially through Stations 00–07 only. Do not begin Station 08 or any implementation station. Before stopping, update this file and every station file, create `SESSION_1_HANDOFF.md`, and commit only this documentation checkpoint on the feature branch. Do not commit root prompt/backup, `codex-agents/`, or any pre-existing user changes.
