# NOVA Player Reengineering — Master Plan

## Mission state

- Authoritative specification: `C:\Users\hosea\projects\app\Nova\NOVA_PLAYER_PROMPT_V2_1.md`, SHA-256 `105C6368ACE6B92CC2D793FA8CE61FB519026B56D202FA73CD26584B378F3F50`. The root copy contains Section 54A and takes precedence as the user directed. All root/docs specification copies and backups remain untouched.
- Feature branch: `feature/player-reengineering`.
- Safety tag: `pre-player-reengineering-baseline` → `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
- Current continuation: record Gate B approval and commit ONLY the six Gate B documentation/plan files listed in `GATE_B_REVIEW.md`, after showing `git diff --cached --name-only`. No production/instrumentation/config/dependency edits, build, install or device commands. No push or tag; stop after commit. Existing unrelated changes excluded.
- Documentation commit PENDING: `git add` could not create protected `.git/index.lock` (Permission denied); the required escalated Git-index write request was rejected by the user. No files staged or committed. Do not bypass that rejection. Gate B human approval remains valid; Station 10 remains unentered awaiting explicit go-ahead.
- Last-known-good production commit: `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
- Current HEAD at Station 09 entry: `d19224bc3a59dbfe9db1c43126842159820ff33f` (`player: station 08 root-cause analysis gate a`). Pre-existing instrumentation is in its ancestry; no new code LKG.
- Current station: 09 — planning checkpoint COMPLETE, STATIC-ONLY, 9/9 tasks; Gate B APPROVED WITH CONDITIONS for Option A (retain media_kit, structural decoupling only). Session/progress/rendering/recovery/persistence interface contracts remain DRAFT for finalization in Station 10. Stations 10–20 unentered; Station 10 requires explicit user go-ahead.
- Gate B conditions (2026-10-21): performance benefit remains UNKNOWN, no performance claim without valid before/after measurement; personal-use scope/no planned distribution, native-library classification stays unclear and license review must reopen before any distribution; interface contracts DRAFT; no production/build/install/device work until explicitly starting Station 10; scoped docs commit only, no push/tag, then stop. Full verbatim reply: `GATE_B_REVIEW.md`.
- Gate B revision requested before approval: purpose is structural decoupling only; **performance benefit UNKNOWN because no valid before/after measurement exists**. Each option A–D now maps RC1 rebuild coupling / RC3 recovery / RC4 source continuity with structural evidence labels. Section 0.8 classifications: media_kit stack wrapper LICENSE files permissive (MIT), exact bundled native artifact classification unclear pending inventory. Details in Station 09, Gate B draft and license notes. No new agent invocation, production/runtime work, staging or commit.
- User decision (2026-10-21): accept STATIC-ONLY diagnosis and explicitly waive the valid legacy baseline, for Station 09 planning only. Verbatim decision in `GATE_A_REVIEW.md` addendum and `GATE_B_REVIEW.md-draft`. `BASELINE.md` remains INCOMPLETE; every BEFORE NOT MEASURED. All performance claims STRONGLY INFERRED or UNKNOWN; baseline-dependent targets absolute-only. Historical no-waiver/stop-at-A instructions are superseded for this scope.
- Historical physical device: `RF8NA2NNVNY`, Samsung SM-A217F, Android 12/API 31, Exynos 850, arm64-v8a; saved facts/limits in `evidence/PHYSICAL_DEVICE_PREFLIGHT.md`. Current availability UNKNOWN.
- Performance frame budget reference: 60.000004 Hz supported mode → 16.67 ms. No valid official baseline metrics were collected; the single exploratory capture is unbounded and excluded.
- iOS: STATIC-ONLY; no Mac/Xcode, Codemagic result, or iOS device was used.
- Agent use after Gate B draft review: 6 total read-only invocations (NOVA auditor 1/1, reference researcher 2/5, perf-log analyst 1/3, gate reviewer 2/5, once each A/B). Maximum observed concurrency 1. Gate A historical review remains in `GATE_A_REVIEWER.md`; user has now supplied waiver. Gate B review/disposition/content-scope verification in `GATE_B_REVIEWER.md`; no repeat invocation.
- Current device availability: UNKNOWN, not queried. Device facts above are historical saved preflight, not current connection/run-condition verification.
- Repository state verified: requested root/branch, HEAD equals supplied documentation checkpoint, supplied production LKG is ancestor, safety tag matches it, initial index empty. Initial `git status --short` contained 32 pre-existing entries, none a tracked player path; all are excluded from this documentation checkpoint.
- Historical correction: production-to-current-HEAD diff includes pre-existing engine/page diagnostic hooks and `player_diagnostics.dart`. The documentation checkpoint itself changes four docs/evidence files only. Session 1's docs-only description must not be generalized across that instrumentation checkpoint. No new code LKG is claimed.

## Task counts and status

Station 03 has six checked tasks; official baseline remains NOT MEASURED / INCOMPLETE, not a newly verified device-blocker. Station 08 bounded STATIC-ONLY diagnosis accepted at Gate A with written baseline waiver. Station 09 has nine completed planning/approval tasks; engine and structural direction accepted, interface contracts DRAFT for Station 10. Aggregate task count corrected from inherited 212 to 216 by summing all 23 station rows; no tasks added or removed.

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
| 08 | Root-cause analysis | 8 | 8 | COMPLETE — STATIC-ONLY; Gate A accepted with explicit baseline waiver |
| 09 | Final architecture | 9 | 9 | COMPLETE planning — STATIC-ONLY; Gate B Option A approved with conditions; interface contracts DRAFT |
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
| **Total** |  | **216** | **116** |  |

Station tracking files: `00_STATION.md`–`20_STATION.md`, plus `STATION_06A.md` and `STATION_06B.md`. Station 09 only entered in this continuation; Stations 10–20 unentered. `SESSION_1_HANDOFF.md`, unchanged Station 08 report and old gate-pending text are historical; current waiver/scope above controls resumption.

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
| Station 08 + Gate A | `d19224bc3a59dbfe9db1c43126842159820ff33f` | Seven scoped docs; STATIC-ONLY. Gate A subsequently accepted with waiver. |
| Station 09 + Gate B approval | PENDING — protected Git-index write request rejected; intended subject `player: station 09 gate b approval` | Six scoped documentation/plan files saved but unstaged/uncommitted; no new production LKG. Prior Gate A/baseline/ownership working changes excluded. |

## License and clean-room status

Gate B accepts personal-use scope only; no distribution planned. The media_kit wrapper/package LICENSE files are permissive MIT, while exact bundled native-library classification remains unclear (UNKNOWN / NOT-VERIFIED). Keep the artifact verification plan in `LICENSE_NOTES.md` / `GATE_B_REVIEW.md`. Reopen license review BEFORE any future distribution; approval is not distribution clearance.

Exact licenses, upstream refs, and clean-room rules are in `LICENSE_NOTES.md`. Reference snapshots: Harbor MIT; Nuvio GPL-3.0; Stremio Kai GPL-3.0; Jellyfin Android GPL-2.0; Jellyfin iOS MPL-2.0; Swiftfin MPL-2.0; mpv-qol-scripts GPL-3.0. No code snippets or distinctive identifiers were copied. Harbor/Nuvio/Stremio local checkouts were absent and exact-SHA GitHub read-only files were used. The two required reference-agent audits used local Jellyfin Android and MPV-QoL checkouts; agents changed no files.

## Architecture decision log

**ADR-P001 engine/direction ACCEPTED at Gate B; remaining detailed contracts/ADRs DRAFT for Station 10.** All technical verification remains STATIC-ONLY; approval is not implementation or runtime evidence. Full alternatives/contracts/evidence ledger S1–S8 in `09_STATION.md`. Purpose is structural decoupling only; structural suitability may be STRONGLY INFERRED, but performance benefit is UNKNOWN without valid before/after measurement. No Section 51A absolute target relaxed.

| ID / problem | Options / recommended selection | Evidence / reason / tradeoffs / affected stations |
|---|---|---|
| ADR-P001 Engine — ACCEPTED | Retain locked media_kit, Option A, structural decoupling only. Alternatives B/C/D not selected. | User Gate B approval, S2/S3/S6/S8; no measured engine defect/replacement gain. Performance benefit UNKNOWN. Native license unclear, personal use only; reopen before distribution. No production execution authorized yet. Stations 10/12/17–19. |
| ADR-P002 State/ownership | Recommended one route-owned session + scoped projections; alternatives notifier-only patch or broad rewrite. | RC1/RC2/RC7, S3/S4; reduce shared build/async ownership scope. More boundaries require careful synchronization. Stations 10–16. |
| ADR-P003 Renderer | Recommended retain VideoController/Video as stable child; alternate native/view replacement deferred. | RC1, S3/S7; no evidence of texture/decoder recreation from builds. Native geometry/output still needs measurement. Stations 10/16–19. |
| ADR-P004 Frequency | Recommended precise internal state, coalesced ≤10/s progress UI, change-only feature/transport/subtitle updates; alternative broad notifier rejected for draft. | RC1/RC2/RC6, Section 46/51A. At most 100 ms progress granularity; exact seeks/final checkpoints read internal state. Stations 10–15/19. |
| ADR-P005 Source/recovery | Recommended generation-guarded serialized handoff, semantic track rematch, one classified automatic retry per operation/source generation; alternatives route-only replacement/blind decoder fallback. | RC3/RC4, S3/S4/S6; preserve continuity and avoid double-open. Bounded retry can require explicit user recovery. Stations 10/12/15/17–19. |
| ADR-P006 Persistence/completion | Recommended existing keys/providers/threshold semantics, serialized immutable checkpoints and equivalent shared predicates; alternative schema/threshold migration deferred. | RC7, S5; preserve history/sync/snapshot behavior. Final saves/sync can fail; need diagnostics. Changed data semantics trigger conditional gate. Stations 10/13–15/19. |
| ADR-P007 Tracks/overlays/lifecycle | Recommended existing Flutter subtitle styling, engine timing, guarded settings pause, no automatic foreground play; alternatives new parser/native subtitle/continuous-play settings deferred. | RC5/RC6/RC7, S3/S5; preserve behavior, reduce command races. Subtitle fidelity and interruption behavior UNKNOWN. Stations 11/12/16–19. |
| ADR-P008 Migration/platform/dependency | Recommended legacy selectable before rerouting, no new package, plugin/Dart first, no new AirPlay/PiP/background-audio feature; alternative immediate native/dual-stack rewrite deferred. | Section 0.5/0.6/0.8, S2/S7; lower uncompiled-native scope. Selector not implemented yet; iOS build/runtime NOT-VERIFIED. Legacy removal only Gate E. Stations 10–20. |

RC mapping: RC1→P002/P003/P004; RC2→P002/P004; RC3→P005; RC4→P005/P006; RC5→P007; RC6→P004/P007; RC7→P002/P005/P006/P007; RC8→session-bounded observability/absolute acceptance protocol in Station 09 and P008 migration checks. These map candidate risks to design hypotheses, not measured causes.

Dependency proposal A adds/upgrades nothing. Existing wrappers MIT; exact native binary/transitive distribution terms UNKNOWN, see `LICENSE_NOTES.md` addendum. Any new engine/dependency, stored-data semantic change or native deployment/signing/major-toolchain change still triggers conditional gate.

## Evidence and current stop condition

Station 08 independently re-summed saved capture lines 116–226: 110 summaries, 49,689 reported Flutter frames, 5,597 build-over-budget, 107 raster-over-budget. These are unbounded exploratory-window totals only, not scenario rates, valid baseline or causal evidence. Diagnostics are app-wide; first interval can straddle checkpoint; build/raster sets can overlap. First-frame, explicit buffering transitions, decoder drops, CPU/memory trends and actual decoder selection remain NOT MEASURED/UNKNOWN.

Current user written waiver resolves Gate A for Station 09 planning only. Final BEFORE fields remain NOT MEASURED; reduced-confidence Gate B draft and absolute-only baseline-dependent evaluation in `09_STATION.md`. Relative TTFF/seek/gap/drift clauses cannot be evaluated, are not assumed passed and get no invented thresholds.

Current authoritative approval: `GATE_B_REVIEW.md`; historical options: `GATE_B_REVIEW.md-draft`; independent historical review/correction: `GATE_B_REVIEWER.md`. Gate B APPROVED WITH CONDITIONS. Commit only the six authorized documentation/plan files after displaying staged paths, then STOP. Station 10 requires explicit user go-ahead; no production/build/install/device work. No push/tag. Current production LKG remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; no current analyzer/tests/build/runtime proof.

The earlier uncommitted Gate A/baseline/ownership addenda are excluded from this commit. Current Gate A waiver and Gate B conditions are recorded in the committed Gate B packet; their decisions supersede historical pending/no-waiver text in earlier station/baseline documents without marking Station 03 complete.

## Historical Session 2 stop condition (superseded by current Station 09 planning waiver)

Station 03 was stopped at the user's direction after one exploratory Profile capture. The capture has no exact tap/start/stop markers, so no valid official startup timing or per-run performance metrics can be claimed. The official baseline remains INCOMPLETE; Station 04 or later must not be started in this checkpoint. The last-known-good production commit remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
