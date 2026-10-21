# Station 08 — Root-cause analysis

## Status

- Status: COMPLETE — bounded static diagnosis and Gate A packet; STOPPED AT GATE A awaiting user decision. Gate A has not passed; performance causes are not verified.
- Verification status: STATIC-ONLY.
- Checklist: 8/8 tasks complete (documentation/review/stop tasks only; no baseline or runtime task marked complete).
- Date: 2026-10-21, Asia/Riyadh.
- Official baseline: NOT MEASURED. Station 03 is EXPLORATORY SAMPLE only, explicitly accepted by the user; this is not a written baseline waiver.

## Objective / scope / prerequisites

Explain candidate mechanisms, their evidence and limitations, then STOP at Gate A. No architecture design, engine selection, production/instrumentation changes, builds, installs, device commands, emulator or network investigation in this continuation.

Read completely from disk: root `NOVA_PLAYER_PROMPT_V2_1.md` (all 3,626 lines; Section 0 authoritative), `00_MASTER_PLAN.md`, `BASELINE.md`, `03_STATION.md`, and `SESSION_1_HANDOFF.md`. The master plan is under `docs/player-reengineering/`, not at root. The current user request supersedes historical Session 1/2 stop instructions only to allow Station 08 and Gate A preparation.

## Tasks

- [x] Reconcile Station 02 static findings against Station 03 baseline and reference comparison. Evidence: E1–E7.
- [x] Write each cause with observed behavior, evidence, layer, root cause, verification status and confidence. Evidence: RC1–RC8.
- [x] Separate measured facts from STRONGLY INFERRED and UNKNOWN claims. Evidence: ledger and performance limits.
- [x] Map each cause to likely contributing mechanisms and rule out unsupported single-cause claims. Evidence: prioritization/exclusions.
- [x] List any unmeasured symptoms and their measurement needed. Evidence: verification methods and exclusion table.
- [x] Prepare Gate A review; baseline required or user written waiver. Evidence: `GATE_A_REVIEW.md`; gate not passed and waiver not assumed.
- [x] Run authorized gate reviewer once and verify no file changes after run. Evidence: `GATE_A_REVIEWER.md`; immediate status and 487-file content comparison unchanged.
- [x] Stop for Gate A user decision. Evidence: current status and `GATE_A_REVIEW.md`; Station 09 unentered, no baseline waiver inferred.

## Evidence required / ledger

VERIFIED applies only to explicitly cited source facts or saved-log counts, never their causal interpretation. Each RC has separate evidence confidence and NOVA verification status. All performance attribution is STRONGLY INFERRED or UNKNOWN. Reading a historical device capture does not make this investigation VERIFIED-ON-DEVICE.

| ID | Evidence | Supported fact and limits |
|---|---|---|
| E1 | `02_STATION.md`, `07_STATION.md` | STATIC-ONLY audit/comparison, not performance rankings. Old line references precede instrumentation; current locations are used below. References were not benchmarked here. |
| E2 | `BASELINE.md`, `03_STATION.md`, `SESSION_1_HANDOFF.md` | Zero official runs per scenario, one exploratory user-played sample. Reported 171 seeds and estimated 15–30 visible stalls/minute are manual observations, not verified rates or throughput. Historical device presence does not establish current availability. |
| E3 | `evidence/ST03_startup_runs.txt:1`, `:115`–`:226` | Profile marker at line 1; pre-run checkpoint at line 115. The 110 summaries after it span 09:30:17.915–09:48:36.889 and total 49,689 reported Flutter frames, 5,597 build-over-budget and 107 raster-over-budget counts. Independently re-summed now. Unbounded window, no tap/start/stop markers, no valid scenario denominator; the first summary can straddle the checkpoint. Not official Run 1 values. Build/raster sets may overlap. |
| E4 | Same capture, summary lines 116–226 | Counts sum to 3,919 position callbacks, 765 buffer callbacks, 4,705 engine notifications, 5,260 page builds, 5,244 surface-widget builds, one engine creation and one open. Not playback-only rates, causal pairing, rendered video frames, or settings/rotation recreation counts. |
| E5 | Same capture `:118`; `engine/playback_engine.dart:273`–`:286` | Saved codec field is empty and decoder label is `software`. Code substitutes this label for an empty hardware-decoder property. Actual software/hardware decoding and active codec UNKNOWN. |
| E6 | `player_diagnostics.dart:13`–`:124`; engine `:432`–`:436` | Helper collects app-wide Flutter timings after start, fixed 60 Hz threshold, at most 600 build/raster samples for percentiles, and no stop hook on player disposal. Buffering counts callbacks before equality guard without state values. First-frame/decoder-snapshot helpers have no external call sites. No explicit true transition, first-frame timing or decoder-drop snapshot in capture. Missing records do not mean zero events. |
| E7 | Current source and read-only Git comparison | Requested repository/branch, docs-checkpoint HEAD equality, production-LKG ancestry and matching safety tag verified. Docs checkpoint changes four docs/evidence files only. Production-to-HEAD diff also includes pre-existing engine/page diagnostic hooks and diagnostic helper: historical “all intervening commits docs-only” is stale. Exact installed capture binary revision is not established by mode/version label. No production change in this continuation. |

## Findings

### RC1 — Broad event notifications rebuild unrelated player UI

- Problem: candidate P1 Flutter build overhead.
- Observed behavior: position/duration/buffer callbacks use a common notifier; the normal page listener calls page-wide `setState`, even with controls hidden. E4 records page/surface-widget builds in the exploratory window.
- Evidence: `lib/features/player/engine/playback_engine.dart:439`–`:454`, `:492`–`:495`, `:529`–`:548`; `lib/features/player/video_player_page.dart:462`–`:492`, `:1784`–`:1892`; torrent status also calls `setState` at `:284`–`:289`.
- Layer: Dart events and Flutter build scope.
- Root-cause candidate: unrelated UI and surface widget configuration share broad updates without equality/UI cadence guards for position/duration/buffer. Notifications can coalesce; widget rebuild does not prove texture/controller/decoder recreation.
- Confidence: STRONGLY INFERRED avoidable build work; contribution to visible stalls/decoder drops UNKNOWN. Verification status: STATIC-ONLY.
- Severity: P1 candidate; first measurement priority, not measured share of stutter.
- Recommended fix: after Gate A/B evaluate scoped progress updates and stable surface ownership, preserving precise internal state. This is a remediation direction, not Station 09 architecture approval.
- Expected impact: STRONGLY INFERRED fewer unrelated builds; playback benefit/magnitude UNKNOWN.
- Verification method: future bounded Profile runs with hidden/visible controls, event/build counters and timeline under matched conditions; measure UI timing separately from engine drops and native recreations. Evaluate Section 51A targets without equating widget builds with engine recreation.

### RC2 — Repeated episode derivation in the broad build path

- Problem: candidate P2 CPU/allocation work amplified by RC1 for series.
- Observed behavior: `_episodes` filters, allocates and sorts on every access; index/neighbor lookup invokes it repeatedly while `build` derives previous/next episodes.
- Evidence: `video_player_page.dart:586`–`:609`, `:1816`–`:1821`; source fact VERIFIED, cost not measured.
- Layer: UI-isolate data derivation.
- Root-cause candidate: stable catalog data is repeatedly derived in a frequently invalidated build. Cost depends on list size and series usage.
- Confidence: STRONGLY INFERRED avoidable work; material frame-budget impact UNKNOWN. Verification status: STATIC-ONLY.
- Severity: P2 candidate; no evidence of severe stutter attribution.
- Recommended fix: evaluate deriving sorted episode/index data when inputs change, preserving ordering/navigation.
- Expected impact: STRONGLY INFERRED fewer sorts/allocations; milliseconds/smoothness gain UNKNOWN.
- Verification method: later CPU/allocation stacks on the same list plus ordering, neighbor-navigation and invalidation tests.

### RC3 — Startup watchdog does not discriminate the failing layer

- Problem: candidate P1 recovery reliability and unnecessary software fallback.
- Observed behavior: buffering plus zero position after a configured 45-second readiness interval disposes the engine and creates a software-decoding engine. `ready` means known duration, not rendered video. Separate codec retry matches error substrings.
- Evidence: `video_player_page.dart:415`–`:459`, `:495`–`:559`; engine `:164`, `:273`–`:286`; E5. The threshold is configuration, not startup measurement.
- Layer: source readiness, recovery and decoder policy.
- Root-cause candidate: network starvation, decoder initialization and texture output are indistinguishable in the watchdog predicate. Comments about GPU/device faults are not runtime proof.
- Confidence: STRONGLY INFERRED misclassification risk; any actual fallback during reported stalls UNKNOWN. Verification status: STATIC-ONLY.
- Severity: P1 candidate; playback-breaking P0 occurrence is not established.
- Recommended fix: evaluate classified failures/first-frame diagnostics and bounded recovery before changing decoder settings. Do not globally disable hardware acceleration or replace engine from E5.
- Expected impact: STRONGLY INFERRED clearer recovery attribution; avoided stalls/decoder performance benefit UNKNOWN.
- Verification method: future controlled slow-source versus decoder-error cases with first-frame, actual decoder properties, generation/open counters and position/termination checks. No runtime fault injection now.

### RC4 — Source replacement omits explicit running-session state transfer

- Problem: candidate P1 same-title source-switch continuity failure.
- Observed behavior: `_switchToStream` saves history, then resolver pushes a new player page without `initialPositionMs` or pause/play state. Creation opens from the new resume field and engine `open` calls play. Preferences can be reapplied, but do not explicitly transfer the current manual track selection.
- Evidence: `video_player_page.dart:40`–`:81`, `:205`–`:217`, `:384`–`:411`, `:1295`–`:1321`, `:1362`–`:1403`; engine `:256`–`:267`.
- Layer: route/source/session handoff.
- Root-cause candidate: same-title switching shares fresh-page episode flow without explicit continuity inputs. Saving history alone does not supply omitted constructor arguments. A different episode may appropriately start independently.
- Confidence: STRONGLY INFERRED continuity defect on this path; actual user occurrence/lost time/latency UNKNOWN. Verification status: STATIC-ONLY.
- Severity: P1 reliability candidate, not a steady-state-stall explanation.
- Recommended fix: later define same-title position/pause/tracks/speed semantics separately from episode transitions; preserve existing history keys and source resolution.
- Expected impact: STRONGLY INFERRED continuity benefit; latency/native lifetime overlap impact UNKNOWN.
- Verification method: future known-position switches playing/paused plus new-episode flows; record before/after state and generation/disposal counters, including torrent cleanup. No assertion that settings recreate engine.

### RC5 — Settings deliberately pause; asynchronous ordering is unverified

- Problem: interruptions around settings may include a functional pause component.
- Observed behavior: panel open pauses a playing engine, close conditionally resumes the same engine; calls are unawaited. Panel opening does not construct an engine. Sheet pause/resume uses awaited calls and identity guards.
- Evidence: `video_player_page.dart:955`–`:980`, `:1028`–`:1074`; engine track/rate methods `:353`–`:387` operate on existing player.
- Layer: interaction policy and asynchronous command ordering.
- Root-cause candidate: intentional pause can explain panel-only stopped playback, independently of decode cost; rapid-command race occurrence UNKNOWN.
- Confidence: STRONGLY INFERRED explanation if a panel-only pause is observed; race/freeze UNKNOWN. Verification status: STATIC-ONLY.
- Severity: P2 UX/ordering candidate, not verified P0/P1.
- Recommended fix: later confirm intended pause contract and command ordering, preserving user-paused state and engine guards.
- Expected impact: clearer semantics STRONGLY INFERRED; performance gain UNKNOWN.
- Verification method: later rapid open/close/panel handoffs from playing/paused states with command completion, identity, audible-gap and resumed-frame evidence. Separate intentional paused time from switch freezes.

### RC6 — Subtitle layout work may repeat; impact is unknown

- Problem: candidate P2 subtitle-specific overhead/styling concerns.
- Observed behavior: every subtitle emission sets local state; style builder trims/joins text; outline renders stroke/fill layers. Engine swap reseeds/resubscribes; disposal cancels subscription.
- Evidence: `widgets/subtitle_overlay.dart:211`–`:246`, `:250`–`:333`; engine surface overlay `:529`–`:548`.
- Layer: Flutter subtitle text/state.
- Root-cause candidate: equal repeated lines could cause avoidable layout; RC1 can also reach overlay. Emission frequency, subtitle-enabled capture portions and text-layout duration UNKNOWN. Outline layers alone are not a defect.
- Confidence: STRONGLY INFERRED opportunity only if redundant emissions occur; subtitle-caused stutter UNKNOWN. Verification status: STATIC-ONLY.
- Severity: P2 candidate, below RC1/RC3/RC4.
- Recommended fix: profile disabled/embedded/external tracks before deduplication/layout changes; preserve Arabic shaping, timing, styles and resubscription.
- Expected impact: UNKNOWN until subtitle-specific measurements.
- Verification method: future matched-source subtitle scenarios and text-layout/event counters; later tests for repeated lines, RTL/LTR, styles and engine/track swap.

### RC7 — Lifecycle/persistence checkpoints can overlap asynchronously

- Problem: candidate P1 lifecycle reliability; persistence-induced stutter and memory pressure UNKNOWN.
- Observed behavior: inactive/paused/hidden/detached each start unawaited pause/save/frame work; progress timer also saves every configured five seconds. Snapshot capture has an in-flight guard; progress saves have no page-level in-flight guard. Cleanup cancels timers/subscriptions and starts native disposal asynchronously.
- Evidence: `video_player_page.dart:225`–`:230`, `:712`–`:779`, `:1754`–`:1773`; engine `:498`–`:507`; `lib/core/state/app_state.dart:1136`–`:1185` awaits persistence/sync. Five seconds is configuration, not measured I/O cadence.
- Layer: lifecycle, async persistence and native ownership.
- Root-cause candidate: lifecycle/timer entries can overlap; backend ordering/contention UNKNOWN. Explicit cleanup/guards argue against asserting a leak from source. No evidence of synchronous disk writes on each position event.
- Confidence: STRONGLY INFERRED overlap risk; actual stalls/data loss/leak/post-GC growth UNKNOWN. Verification status: STATIC-ONLY.
- Severity: P1 correctness candidate pending reproduction.
- Recommended fix: later evaluate serialized/checkpoint-safe saves and deterministic teardown while preserving sync/storage semantics and snapshot retention; data-semantic changes retain the conditional gate.
- Expected impact: STRONGLY INFERRED simpler checkpoint ordering; CPU/memory/latency benefit UNKNOWN.
- Verification method: future lifecycle/source stress, operation/generation traces, saved resume checks, PSS/native/graphics and CPU trends after GC excluding legitimate cache. No hardware/account behavior verified now.

### RC8 — Observability cannot support causal attribution

- Problem: P1 evidence gap: first-frame, buffering transitions, decoder drops and run boundaries absent.
- Observed behavior: one unbounded sample; callback counts omit state values; first-frame/decoder snapshot helpers unused; frame callback lifetime is app-wide. Profile marker alone does not prove exact binary provenance or controlled conditions.
- Evidence: E2–E6; helper repository search found no external call sites (recorder is called only inside unused snapshot capture).
- Layer: measurement/observability, distinct from playback implementation.
- Root cause of uncertainty: insufficient instrumentation/use protocol to distinguish UI/decoder/network/lifecycle. Gap is a VERIFIED source/document fact, not a playback-stutter cause.
- Confidence: UNKNOWN for underlying performance attribution. Verification status: STATIC-ONLY.
- Severity: P1 evidence gap; prevents passing Gate A without baseline or explicit written waiver.
- Recommended fix: future legacy baseline with bounded runs, tap/first-render markers, actual decoder/drop samples and explicit buffering states, under newly authorized instrumentation/runtime scope. No instrumentation edits now.
- Expected impact: STRONGLY INFERRED improved diagnostic confidence; no playback gain claimed.
- Verification method: Section 0.9, at least three Profile/Release runs per scenario, recorded conditions, startup/steady-state separated, median/min/max and independent UI/decoder counters. Unsupported metrics stay NOT MEASURED.

## Prioritization and unsupported explanations

No P0 performance cause is confirmed. RC1 is the strongest build-overhead hypothesis, RC3 a recovery-classification risk, RC4 a continuity risk. None establishes the cause of severe visible stalls. RC2/RC6 are secondary; RC5 must respect intended UX; RC7 requires stress verification; RC8 limits all attribution.

| Explanation | Confidence / verification | Evidence needed |
|---|---|---|
| UI build overhead | STRONGLY INFERRED / STATIC-ONLY | Bounded correlation of player builds and UI timing. E3 indicates build pressure only in an unbounded app window. |
| Decoder/software fallback/unsupported codec, HDR/Dolby Vision | UNKNOWN / NOT-VERIFIED | Active codec/profile/decoder and engine drop samples. E5 ambiguous; no AV1/HEVC/HDR/Dolby Vision playback evidence. |
| Torrent/network starvation or source/server quality | UNKNOWN / NOT-VERIFIED | Explicit buffering transitions, playable-buffer/throughput/peer series, errors, controlled source comparison. Seeds are not throughput; buffer callbacks are not rebuffer events. |
| Texture synchronization/native surface recreation | UNKNOWN / NOT-VERIFIED | Native identity/first-frame/graphics evidence; widget-build counters cannot establish this. |
| Display/content cadence or A/V mismatch | UNKNOWN / NOT-VERIFIED | Actual content/display cadence and measured drift; historical 60 Hz is only a budget reference. |
| Glass/GPU/shaders/compositing | UNKNOWN / STATIC-ONLY | No BackdropFilter found in audited player paths. Clip/transform/opacity cost requires timeline; do not blame glass from appearance. |
| Memory leak/CPU saturation/persistence cost | UNKNOWN / NOT-VERIFIED | Time series, after-GC analysis and storage spans. Device RAM/cache caps are not pressure measurements. |
| iOS/tablet performance or behavior | UNKNOWN / NOT-VERIFIED | No NOVA iOS compile/device or tablet runtime evidence; reference platforms do not validate NOVA. |

## Decisions / performance evidence

- Current user decision accepts EXPLORATORY SAMPLE only. Official baseline remains NOT MEASURED; no valid before/after percentages, rates, median/min/max, TTFF, seek, drop or leak claims.
- No engine defect or measurable replacement benefit demonstrated. No engine/renderer/dependency/architecture decision now. Section 51A defaults unchanged; no evidence supports relaxing targets.
- Recommend accepting this bounded diagnosis, then authorizing a future valid legacy baseline before Station 09. Alternative needs explicit “waive baseline”; exploratory acceptance is insufficient.
- If explicitly waived: final BEFORE fields NOT MEASURED, Gate B reduced-confidence disclosure, baseline-dependent targets absolute-only. Waiver validates no hypothesis or production change.

## Files inspected / modified

Inspected: mandatory inputs, `AGENTS.md`, Station 01 inventory excerpts, full Station 02/07/ownership/reviewer rules, saved capture (sanitized count extraction), current page excerpts, full engine/diagnostic helper, subtitle overlay implementation, `AppState.recordPlayback`, Git state and production-to-HEAD instrumentation diff. No reference repo changed/re-investigated.

This continuation writes only Gate A review/report and mission-plan/status documents. Source specifications and historical handoff untouched.

## Tests / verification

Read-only Git verified path/branch/checkpoint/ancestry/tag, empty initial index, no dirty tracked player path and 32 pre-existing status entries. Existing settings/Android config/docs/assets/skill changes and untracked local files are excluded. Saved-log arithmetic independently re-summed with PowerShell. No new performance run, analyzer, Flutter tests, build, install, device command, emulator or iOS runtime. Historical tests are not current validation.

Scoped `git diff --check` passed. Required Gate A first-line banner and absence of URLs/revision-like identifiers in the new analysis/review were checked. Independent reviewer confirmed saved sums and evidence limits. Its documentation corrections were applied by the primary without a second invocation. Immediate post-review `git status --short` and content comparison of all 487 present indexed/nonignored files matched the pre-review snapshot; reviewer changed no files. Checkpoint reference: the commit containing this packet, subject `player: station 08 root-cause analysis gate a`, limited to the seven documents named in Gate A review.

## Blockers / acceptance criteria

Analysis acceptance: traceable hypotheses, severity, remediation directions, verification methods and explicit unknowns. Official baseline missing prevents passing Gate A, not completing this expressly authorized static investigation. Current device availability UNKNOWN; no query made. Station 09 and implementation unentered pending user gate reply and baseline/waiver condition.

## Station completion review / next station / LKG

Five total read-only agent invocations: NOVA auditor 1/1, reference researcher 2/5, perf-log analyst 1/3, gate reviewer 1/5 (Gate A once); observed maximum concurrency 1. Reviewer verdict FAIL for passing Gate A due to missing baseline/waiver; packet substantively ready after corrections. Report/corrections in `GATE_A_REVIEWER.md`. No second reviewer invocation.

STOPPED AT GATE A. Next action belongs to user: accept/correct diagnosis and authorize valid legacy baseline or explicitly waive it. Station 09 unentered. Production LKG remains supplied value in `00_MASTER_PLAN.md`; no new code LKG claimed.
