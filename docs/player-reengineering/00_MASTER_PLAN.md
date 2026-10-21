# NOVA Player Reengineering — Master Plan

## Mission state

- Authoritative specification: `C:\Users\hosea\projects\app\Nova\NOVA_PLAYER_PROMPT_V2_1.md`, SHA-256 `105C6368ACE6B92CC2D793FA8CE61FB519026B56D202FA73CD26584B378F3F50`. The root copy contains Section 54A and takes precedence as the user directed. All root/docs specification copies and backups remain untouched.
- Feature branch: `feature/player-reengineering`.
- Safety tag: `pre-player-reengineering-baseline` → `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
- Current continuation: Station 08 and Gate A documentation only; no production/instrumentation edits, build, install, device commands, emulator, or push. Existing unrelated user changes remain excluded.
- Last-known-good production commit: `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
- Current HEAD at entry: equals the supplied documentation checkpoint (verified locally); pre-existing instrumentation is already in its ancestry.
- Current station: 08 — static root-cause analysis; next action STOP AT GATE A, awaiting user decision. Station 09–20 remain unentered.
- User decision (2026-10-21): accept Station 03 as EXPLORATORY SAMPLE only. Official baseline NOT MEASURED. Acceptance is not an explicit baseline waiver. Historical Session 1/2 stop instructions are superseded only to authorize this Station 08 continuation.
- Historical physical device: `RF8NA2NNVNY`, Samsung SM-A217F, Android 12/API 31, Exynos 850, arm64-v8a; saved facts/limits in `evidence/PHYSICAL_DEVICE_PREFLIGHT.md`. Current availability UNKNOWN.
- Performance frame budget reference: 60.000004 Hz supported mode → 16.67 ms. No valid official baseline metrics were collected; the single exploratory capture is unbounded and excluded.
- iOS: STATIC-ONLY; no Mac/Xcode, Codemagic result, or iOS device was used.
- Agent use after Gate A review: 5 total read-only invocations (NOVA auditor 1/1, reference researcher 2/5, perf-log analyst 1/3, gate reviewer 1/5, Gate A once). Maximum observed concurrency 1. Immediate status plus 487-file content comparison confirmed no reviewer-created/changed files. Reviewer verdict FAIL for passing Gate A without baseline/waiver; documentation corrections applied, no second invocation. Report: `GATE_A_REVIEWER.md`.
- Current device availability: UNKNOWN, not queried. Device facts above are historical saved preflight, not current connection/run-condition verification.
- Repository state verified: requested root/branch, HEAD equals supplied documentation checkpoint, supplied production LKG is ancestor, safety tag matches it, initial index empty. Initial `git status --short` contained 32 pre-existing entries, none a tracked player path; all are excluded from this documentation checkpoint.
- Historical correction: production-to-current-HEAD diff includes pre-existing engine/page diagnostic hooks and `player_diagnostics.dart`. The documentation checkpoint itself changes four docs/evidence files only. Session 1's docs-only description must not be generalized across that instrumentation checkpoint. No new code LKG is claimed.

## Task counts and status

Station 03 has six checked tasks (previous header/dashboard incorrectly said five). Official baseline remains NOT MEASURED / INCOMPLETE, not a currently verified device-blocker. Station 08 is completed only as bounded static analysis; passing Gate A still requires a baseline or explicit waiver.

| Station | Name | Tasks | Done | Status |
|---|---|---:|---:|---|
| 00 | Persistent planning bootstrap | 11 | 11 | COMPLETE |
| 01 | Environment and repository discovery | 13 | 13 | COMPLETE |
| 02 | Deep NOVA player audit | 12 | 12 | COMPLETE — STATIC-ONLY |
| 03 | NOVA performance baseline | 12 | 6 | INCOMPLETE — EXPLORATORY SAMPLE accepted only; official baseline NOT MEASURED |
| 04 | Harbor investigation | 10 | 10 | COMPLETE — STATIC-ONLY |
| 05 | Nuvio investigation | 10 | 10 | COMPLETE — STATIC-ONLY |
| 06 | Stremio Kai and supplementary MPV investigation | 11 | 11 | COMPLETE — STATIC-ONLY |
| 06A | Jellyfin Android investigation | 9 | 9 | COMPLETE — STATIC-ONLY |
| 06B | Jellyfin iOS / Swiftfin investigation | 9 | 9 | COMPLETE — STATIC-ONLY |
| 07 | Cross-project engineering comparison | 8 | 8 | COMPLETE — STATIC-ONLY |
| 08 | Root-cause analysis | 8 | 8 | COMPLETE — STATIC-ONLY bounded diagnosis; STOPPED AT GATE A, awaiting user |
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
| **Total** |  | **212** | **107** |  |

Station tracking files: `00_STATION.md`–`20_STATION.md`, plus `STATION_06A.md` and `STATION_06B.md`. Only Station 08 is entered in this continuation; earlier investigations are retained and Stations 09–20 remain unentered. `SESSION_1_HANDOFF.md` is historical, not the latest resume instruction.

## Last-known-good and documentation commits

The production LKG remains the supplied safety baseline. Historical documentation checkpoints below do not validate the intervening pre-existing instrumentation; current production-to-HEAD differences are acknowledged above. No new LKG runtime verification is claimed.

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
| Station 07 + Session 1 handoff | Historical checkpoint present in current history | Docs only; historical next-step instruction superseded |
| Latest Station 03 exploratory checkpoint | Requested documentation checkpoint verified as HEAD at entry | Docs/evidence only; official baseline NOT MEASURED |
| Station 08 + Gate A | Commit containing this packet: `player: station 08 root-cause analysis gate a` | Seven scoped docs only; STATIC-ONLY analysis; gate not passed |

## License and clean-room status

Exact licenses, upstream refs, and clean-room rules are in `LICENSE_NOTES.md`. Reference snapshots: Harbor MIT; Nuvio GPL-3.0; Stremio Kai GPL-3.0; Jellyfin Android GPL-2.0; Jellyfin iOS MPL-2.0; Swiftfin MPL-2.0; mpv-qol-scripts GPL-3.0. No code snippets or distinctive identifiers were copied. Harbor/Nuvio/Stremio local checkouts were absent and exact-SHA GitHub read-only files were used. The two required reference-agent audits used local Jellyfin Android and MPV-QoL checkouts; agents changed no files.

## Architecture decision log

No architecture or engine decision has been made. Gate A packet complete; Gate A has not passed and Gate B is not reached. RC1 broad build coupling, RC3 recovery classification and RC4 source continuity are STRONGLY INFERRED candidates; their contribution to stalls is UNKNOWN. Other candidates and unknowns are in `08_STATION.md`. Defaults in Section 51A unchanged.

## Evidence and current stop condition

Station 08 independently re-summed saved capture lines 116–226: 110 summaries, 49,689 reported Flutter frames, 5,597 build-over-budget, 107 raster-over-budget. These are unbounded exploratory-window totals only, not scenario rates, valid baseline or causal evidence. Diagnostics are app-wide; first interval can straddle checkpoint; build/raster sets can overlap. First-frame, explicit buffering transitions, decoder drops, CPU/memory trends and actual decoder selection remain NOT MEASURED/UNKNOWN.

Current user acceptance of EXPLORATORY SAMPLE permits Station 08 documentation only; it does not waive baseline. Recommend accepting bounded diagnosis then authorizing future valid legacy baseline before Station 09. Explicit alternative “waive baseline” must be supplied by user: final BEFORE NOT MEASURED, Gate B reduced confidence, baseline-dependent targets absolute-only. A plain “continue” cannot override this unresolved condition.

Gate A review: `GATE_A_REVIEW.md`; independent result/corrections: `GATE_A_REVIEWER.md`. No Station 09 design/implementation until gate decision and baseline/waiver condition satisfied. STOPPED AT GATE A. Scoped documentation whitespace and evidence checks passed; no current analyzer/tests/build/runtime checks performed.

## Historical Session 2 stop condition (superseded for Station 08 only)

Station 03 was stopped at the user's direction after one exploratory Profile capture. The capture has no exact tap/start/stop markers, so no valid official startup timing or per-run performance metrics can be claimed. The official baseline remains INCOMPLETE; Station 04 or later must not be started in this checkpoint. The last-known-good production commit remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
