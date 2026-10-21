**BASELINE EXPLORATORY ONLY — user accepted**

# Gate A — Station 08 diagnosis review

- Status: AWAITING USER DECISION — Gate A not passed.
- Verification status: STATIC-ONLY. Date: 2026-10-21, Asia/Riyadh.
- Analysis: `08_STATION.md`. Rules: root specification Sections 0.4, 0.4A and 54A, with current user instruction authorizing Station 08 only and replacing the missing-device banner.

## What was completed

Station 08 reconciles the NOVA static audit, cross-project comparison, exploratory capture and current source. Eight candidate mechanisms/evidence gaps each include problem, behavior, source, layer, confidence, severity, remedy direction, expected impact and verification method. Station 09 architecture and engine decision remain unentered.

Strongest candidates: broad notifications reach page/surface-widget builds (RC1, STRONGLY INFERRED build overhead); startup watchdog conflates possible network/decoder/texture failure (RC3, STRONGLY INFERRED recovery risk); same-title source replacement omits running-position/pause transfer (RC4, STRONGLY INFERRED continuity risk). Their contribution to visible stalls remains UNKNOWN. No P0 performance cause is confirmed.

Secondary candidates cover repeated episode sorting, deliberate settings pause/command ordering, subtitle layout and overlapping lifecycle persistence. Measurement gaps prevent causal attribution. Widget rebuild is not proof of decoder/native surface recreation.

## Evidence / measured numbers and limits

Official baseline is **NOT MEASURED**, zero qualifying runs in every scenario. User accepted only the exploratory sample, not a written waiver. Current device availability is UNKNOWN; no device command was run.

| Saved item | Value | Evidence / limit |
|---|---|---|
| User observation | 171 seeds; estimated 15–30 visible stalls/minute | `BASELINE.md`, `03_STATION.md`; manual report, not measured rate, network health or cause. |
| Diagnostic mode | Profile marker, capture line 1 | `evidence/ST03_startup_runs.txt`; does not establish exact binary revision or controlled conditions. |
| Post-checkpoint summaries | 110 summaries; 49,689 reported Flutter frames; 5,597 build-over-budget; 107 raster-over-budget | Capture lines 116–226, checkpoint line 115; independently re-summed. Unbounded 09:30:17.915–09:48:36.889 window, no tap/start/stop markers, first summary can straddle checkpoint. Not Run 1 metrics or official jank rates; build/raster sets can overlap. |
| Event/build counters | 3,919 position callbacks; 4,705 engine notifications; 5,260 page builds; 5,244 surface-widget builds | Same summaries; app-wide diagnostic lifetime, no playback-only denominator/causal pairing. Does not prove UI updates/second exceed target. |
| Decoder path | Empty codec; label `software` | Capture line 118; code maps empty decoder property to this label. Actual hardware/software path UNKNOWN. |
| TTFF, buffering transitions, engine drops, seeks/switches, CPU/memory trends | NOT MEASURED | No bounded first-frame timing, explicit buffering=true record or drop snapshot. Missing records do not mean zero events. |

Every unmeasured performance conclusion is STRONGLY INFERRED or UNKNOWN. No new VERIFIED-ON-DEVICE claim. Full limits/source references in Station 08 E1–E7. No before/after gain or measured reference-project smoothness ranking supported.

## What the diagnosis can / cannot claim

Can identify source-level state coupling, handoff/recovery/ownership risks and measurement deficiencies; capture corroborates build pressure somewhere in an exploratory app-wide window.

Cannot identify which subsystem caused the stalls, attribute decoder drops to UI, prove software decoding/network starvation/leak, certify settings/rotation behavior, rank engines or establish Android/iOS/tablet acceptance. iOS code review STATIC-ONLY; iOS runtime/tablet playback NOT-VERIFIED.

## Decisions requested / recommended option

1. Accept or correct the bounded Station 08 diagnosis/priorities. No final architecture/engine replacement approval is requested.
2. Resolve the missing official baseline before passing Gate A:
   - **Recommended: authorize a future Station 03 legacy-player baseline.** Provide a playable real source and authorize needed instrumentation/runtime scope then. Follow Section 0.9, at least three Profile/Release runs per scenario, then re-check Station 08. This session stays stopped without device commands. A future “device connected” reply follows Section 0.4A; valid input and capture scope remain necessary.
   - **Alternative: explicitly reply “waive baseline”.** Only that written waiver authorizes reduced-confidence design without an official baseline. Exploratory acceptance or plain “continue” is insufficient while baseline condition is unresolved.

If waived: final BEFORE fields NOT MEASURED, Gate B reduced-confidence disclosure, baseline-dependent targets absolute-only. Other acceptance targets/verification/gates remain. No target weakened now.

## Risks / reasons

Recommend keeping Gate A pending until valid legacy baseline exists. RC1 is a useful first measurement priority; optimizing it without controls could miss decoder/network causes. RC3/RC4 merit correctness verification independent of frame pacing. No evidence supports engine replacement or broad decoder/cache/effects changes now.

References stay scoped to their original snapshots/platforms; restrictions in `LICENSE_NOTES.md` remain. No code copied/dependency added. Waiver would not approve engine/dependency or stored-data changes; conditional gates still apply.

## Repository safety / checkpoint

Verified requested repository, `feature/player-reengineering`, HEAD equality with supplied docs checkpoint, supplied production-LKG ancestry and matching safety tag. Initial index empty; 32 pre-existing status entries preserved/excluded, including settings/Android config/docs/assets/skills and untracked local files. No dirty tracked player path overlaps this docs work.

Historical correction: production-LKG-to-HEAD diff also has pre-existing engine/page diagnostic hooks and helper; not every intervening commit is docs-only. The supplied docs checkpoint itself changes only docs/evidence. This continuation makes no production/instrumentation change, claims no new code LKG, and leaves specifications/handoff untouched. Existing revision values stay recorded in the master plan; this review includes no source locator, stream identifier, credential or digest.

Checkpoint reference: the commit containing this packet, subject `player: station 08 root-cause analysis gate a`. Exact seven-file scope: `GATE_A_REVIEW.md`, `GATE_A_REVIEWER.md`, `08_STATION.md`, `00_MASTER_PLAN.md`, `03_STATION.md`, `BASELINE.md`, `OWNERSHIP.md`, all under `docs/player-reengineering/`. Only these Gate A/plan updates may be staged/committed. No push, code edit, analyzer, Flutter test, build, install, device command, emulator or iOS runtime. Scoped documentation whitespace/evidence checks passed; final commit path inspection must match this scope.

## Independent review / next step

One read-only `gate_reviewer` invocation completed (Gate A 1/5; total agents 5, maximum concurrency 1). Verdict: **FAIL for passing Gate A** because official baseline/explicit waiver is missing. Packet substantively ready for human decision after documentation corrections. Source-range/method-name corrections, historical-device wording and mandatory NOT-VERIFIED spelling were fixed. No unsupported causal attribution was found; saved totals independently matched. Original findings and primary disposition: `GATE_A_REVIEWER.md`.

Immediate post-review status and full content comparison of 487 present indexed/nonignored files matched the pre-review snapshot. Reviewer created/changed no files. No repeat invocation; primary verified corrections and documentation whitespace.

**STOP AT GATE A.** Await both decisions. Do not enter Station 09/implementation. Future baseline can amend diagnosis; explicit waiver must be recorded verbatim and carried into Gate B restrictions.
