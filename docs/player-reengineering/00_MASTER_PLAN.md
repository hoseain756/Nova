# NOVA Player Reengineering — Master Plan

## Active continuation — Station 12 UI candidate, 2026-10-22

The user restated the remaining player UI requirements after Station 11. Commit `1bd6d24` records the UI implementation: panel navigation/sizing, subtitle styling and precise delay, compact speed/fit controls, season/episode presentation and opt-in automatic episode source selection. The six requested UI implementation items are checked complete in `12_STATION.md`; Station 12 itself remains IN PROGRESS because selecting the tested SubDL external subtitle still fails, external track recovery/reset checks and LKG validations remain open, and broad source/format coverage is incomplete. Station 11 remains complete. Legacy is still the default route, and the performance baseline is waived/NOT MEASURED. Earlier Station 12 "not entered" wording below is historical.

## Active continuation — Gate C APPROVED; Station 11 COMPLETE, 2026-10-22

The user's explicit **«نعم انتقل وأكمل إلى المحطة التالية»** approved Gate C and entry to Station 11 only. The preceding Gate C HOLD statements below are historical. Station 11's control/gesture changes are complete in both routes: full analysis PASS, 539/539 tests PASS, both Profile APKs built/installed on `RF8NA2NNVNY`, and the user manually selected a source for each route and reported both functional checklists **«نجح الفحص»**. This verifies the current working-tree candidate on one phone and one source per route, not measured performance. All BEFORE/AFTER performance remains NOT MEASURED and benefit UNKNOWN. The legacy route remains default; iOS is NOT-VERIFIED. Station 11 code commits `2931cb6` and `ebb825e` passed full analysis and all 539 tests on the exact corrected staged snapshot. They deliberately exclude the pre-existing confirmed-exit fixes in the same page files, so they were not installed on-device and are not promoted to production LKG. The recorded production LKG/safety tag remains `c9257c0`. Station 12 and subsequent gates require their own explicit user decisions.

## Current core candidate — Gate C HOLD, 2026-10-22

The user confirmed drag/tap seeking with uninterrupted video/audio, then confirmed the requested direction on the installed build: Arabic starts on the physical left and English on the right. Full `flutter pub get`, `flutter analyze --no-pub` and `flutter test --no-pub` passed (532 tests); opt-in Profile APK SHA-256 `0926A76A36DE69A1E8D4B3AD68CDB96C5FF51FD10CF06A2504E9E8C1E2434D57` built/installed, launched and user-tested on `RF8NA2NNVNY`. One user-selected source only; performance remains NOT MEASURED per waiver. Gate C decision is pending; later UI stations have not begun.

### User-requested UI backlog and close fix — 2026-10-22

Gate C remains HOLD. The user's requested player UI work is explicitly **NOT IMPLEMENTED** and queued behind Gate C; Station 11 and later UI stations must not begin until Gate C approval. The checklist and detailed acceptance criteria are in `10_STATION.md`: panel actions/sizing; subtitle styling and outline preview; synchronized player/app settings; 0.01-second audio/subtitle delay adjustment; hold-to-2×; compact speed/fit settings; and responsive episodes/season cards plus opt-in automatic source selection.

The reported black-screen-on-confirmed-exit defect was fixed in both player implementations. `flutter analyze --no-pub`, all 532 `flutter test --no-pub` tests, scoped `git diff --check`, and `flutter build apk --release --no-pub` passed. The generated APK was not installed because `adb` was unavailable; the user later confirmed the exit issue is resolved. This targeted fix does not count as Gate C approval or completion of any queued UI item.

Prior seek report: the opt-in Core Profile candidate showed smooth video, but its timeline could not be controlled. A bounded seek-capability recheck was implemented after duration appeared, with source invalidation, 36/36 focused tests and scoped analysis passing. The resulting opt-in Profile APK was installed and the user confirmed drag/tap seeking; the later direction request is recorded above. The requested panel, subtitle, gesture, settings and episode redesign belongs to later stations and is recorded in `10_STATION.md`. The baseline waiver remains, so performance benefit is UNKNOWN.

Prior physical follow-up: user reported Core audio-only output on SM-A217F while legacy had shown video. Core now delays mounting the native surface until session readiness; targeted rendering tests and analysis passed, and the revised opt-in Profile APK was installed. The user subsequently reported visible, smooth video on this build; the causal attribution to the surface change remains a hypothesis. Details/checksum in `10_STATION.md`.

Accepted C10-1–C10-5 implemented as an opt-in route-owned core candidate: frozen request/outcomes, ordered session/resolver ownership, independent projections, shared immutable checkpoint writer, awaitable native retirement, stable surface child, independent core page and once-per-route legacy/core selector. All five player entry routes preserve launch inputs; legacy stays default (`NOVA_PLAYER_CORE=true` enables core). New small surface-host module and localized save-error copy/generator are recorded scope additions. No engine replacement, dependency/native/signing/storage schema/key change. Personal-use/native-license conditions unchanged.

Station 10 remains at the Gate C stop, **9/10** original tasks recorded complete; the remaining item is explicit user Gate C/LKG disposition. Final full suite **532 PASS**, full analysis clean, opt-in Android Profile build PASS and installed/user-tested on the physical device. One user-selected source only; broader codecs/sources remain unverified. The independent earlier Gate C review returned FAIL on four integration blockers; those were corrected with regressions, without claiming an independent PASS. All performance BEFORE/AFTER remain NOT MEASURED under the explicit waiver. Exact artifact and user evidence are recorded in `10_STATION.md` and `GATE_C_REVIEW.md`.

All BEFORE/AFTER performance NOT MEASURED under the explicit Station-10 waiver; performance benefit UNKNOWN. Production LKG/tag remains c9257c0. User confirmed the revised Core Profile shows smooth visible playback and working drag/tap seeking, then confirmed the Arabic-left/English-right timeline convention on RF8NA2NNVNY using one manually selected source. No Gate C approval or LKG promotion yet; no push/tag/release or legacy removal. Candidate BUILD-VERIFIED on Android with the stated one-source functional evidence; broader runtime and iOS remain NOT-VERIFIED. Previous pending-check/proposed/unwired descriptions below are historical. Unrelated working-tree edits remain preserved separately.

## Latest decision — contracts accepted, 2026-10-22

User **تم الاعتماد** explicitly accepts C10-1–C10-5 and continuing the rest of Station 10. Separate contract-approval boundary below is satisfied. Implementation is authorized on the proposed session/adapter/selector/core-page/routing/test paths, plus required documentation/localization as needed. Retain legacy default, existing identifiers/storage semantics, scoped waiver (all BEFORE NOT MEASURED), and no performance/LKG claim. Primary implements alone; stop at Gate C for user device judgment before Station 11. Existing progress-slice dirty changes and unrelated work must be preserved.


## Current continuation — 2026-10-22

User requested continuing the plan, auditing prior completed tasks and the two actual reference roots, REA where available, and stopping after each station. Explicit follow-up **`waive baseline للمحطة 10`** extends the previous Station-09-only waiver to Station 10. Every BEFORE remains NOT MEASURED; performance benefit UNKNOWN; Gate B media_kit/personal-use/native-license conditions preserved. Earlier stop/design-only instructions below are historical for this implemented progress slice, not current scope. Detailed C10-1–C10-5 remain PROPOSED pending separate acceptance; no Gate C or LKG promotion.

Implemented default-off `NOVA_COALESCED_PROGRESS` wiring: sampled bottom-cluster display through new `session/playback_progress_binding.dart`, exact timeline readers and interaction tokens, detach/reset on engine retirement, current-duration drag commits and stale-generation cancellation. Existing helper behavior unchanged; stale unwired doc comment updated. Raw page notifier, persistence/feature authority and video surface remain as before; this is not full core stabilization or rendering isolation. Five production/test implementation paths plus the helper doc comment and required docs; no engine/dependency/native/storage changes. Prior dirty work preserved. Entry/current HEAD `a909f2d`, branch `feature/player-reengineering`, production LKG/tag `c9257c0`, index empty; no commit/push/tag.

Fresh initial helper tests 20/20; seven relevant player test files 62/62 passing. Final six-file analysis clean; final new-test rerun 16/16; opt-in Android debug APK built successfully (283.5 s). Detailed commands, artifact hash and build warnings in `10_STATION.md`. Wiring BUILD-VERIFIED on Android; no device/iOS/runtime/performance verification. Reference reconciliation and invocation accounting: `evidence/CONTINUATION_2026-10-22.md` (one read-only review after immediate correction of an implementation delegation; no agent edits; cumulative 7). REA unavailable, Section 0.7 direct-source fallback. Original station totals remain 216/116; Station 10 incomplete (0/10 broad original tasks), wiring substep complete; Stations 11–20 unentered. Next required decision: separate acceptance of existing proposed contracts before broad session/recovery/persistence replacement.

## Current continuation — Station 10 wiring design only, 2026-10-21

User authorized a short wiring design only, recorded in `10_STATION.md` under **Progress wiring design — 2026-10-21 — PROPOSED / STATIC-ONLY**. This supersedes earlier continuation/stop text solely for this two-document task. Read root Section 0, master, Gate B and station; inspected player/chrome/helper without editing production. Proposed future scope: flagged page-local progress projection in `video_player_page.dart` and optional exact interaction readers in `widgets/player_chrome.dart`; default legacy path retained per 0.6.7. Raw seek/persistence/resume/skip/next-episode decisions stay exact; the broad raw listener remains, so this is not full rendering isolation. No implementation approval, contract promotion or gate advancement.

Current Git: branch `feature/player-reengineering`, HEAD `a909f2d3e59a23b32d39bc2c2a189bef7fd898d0` (`player: station 10 progress coalescer (unwired)`), matching requested `a909f2d`; production LKG and unchanged safety tag `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`, ancestor of HEAD. Initial index empty; unrelated dirty paths preserved. Helper/tests are now tracked in HEAD; historical untracked/260e811 notes below are not current Git state. This design edits only `10_STATION.md` and `00_MASTER_PLAN.md`. No build/test/analyzer/formatter, install, device command, staging/commit, external access request or agent. Documentation verification STATIC-ONLY; proposed runtime NOT-VERIFIED; performance benefit UNKNOWN, all BEFORE/AFTER NOT MEASURED. Original Station 10 implementation tasks remain 0/10; mission 216/116; Stations 11–20 unentered. STOP after the summary; separate authorization required for wiring or device work.

## Current stop / rollback instruction — 2026-10-21

User halted implementation and directed rollback of **only the latest action** in `lib/features/player/session/playback_progress.dart` and `test/playback_progress_test.dart`, preserving earlier/user changes. Latest equal-input/clock-clamping/test edits reverted with explicit reverse hunks; pre-existing unwired helper/test additions remain untracked. No other application source/test edited, no reset/restore/clean, no executable checks or device work, no staging/commit. Incident recorded at the start of `10_STATION.md`; verification STATIC-ONLY. Earlier implementation authorizations/results below are historical and do not permit continuation.

Disk station is 10 after recorded Gate B documentation checkpoints; Session 1/2 boundaries named in the user's stop instruction require read-only reconciliation with earlier handoff/Gate A records. Do not invent a session assignment or overwrite approvals. Before any continuation, report current branch/status/rollback scope and proposed next documentation task to the user, then STOP. Branch `feature/player-reengineering`, HEAD `260e811d5f459979e166492a203fbad1fdd2ea20`, production LKG `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; no promotion or commit. Detailed contracts remain PROPOSED.

## Historical continuation — Station 10 isolated progress slice, 2026-10-21

User accepted only the smallest-edit plan. Contracts C10-1–C10-5 remain **PROPOSED until separately accepted**. Authorized code paths: new `lib/features/player/session/playback_progress.dart` and new `test/playback_progress_test.dart`, unwired. Required AGENTS/master/Station 10/ownership documentation may track this slice. Latest follow-up: retain pending trailing publication on equal input, clamp backward clock readings, add regression tests and show the diff. **Do not rerun tests or analysis; user will run the test file themselves.** No device commands, APK builds, installs, other production edits, staging or commits. This supersedes earlier computer-check authorization for this follow-up.

The helper retains exact immutable samples, equality-filters latest UI publication at 100 ms minimum spacing, retains a pending callback across equal input, clamps backward clock readings, and cancels pending work on generation reset/close with stale-callback guards. Default timing uses Stopwatch/Timer; tests inject deterministic time/scheduling. It owns no engine, UI or persistence. Current fixes are **STATIC-ONLY; updated tests NOT-VERIFIED** until the user runs them. Historical prior-version checks: formatting passed, targeted tests 20/20, analysis no issues, full suite 472 passed; these do not verify the changed revision. No playback/performance claim, integration authorization, general baseline waiver or LKG promotion follows. Production LKG remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; HEAD `260e811d5f459979e166492a203fbad1fdd2ea20`. Original implementation checklist 0/10, mission totals 216/116, agent count 6. **STOP after showing the diff; no commit.**

## Historical continuation — Station 10 planning only, 2026-10-21

User explicitly started Station 10 **planning only**: read the root specification (Section 0 overrides), this plan, Gate B, BASELINE and Station 09; verify expected HEAD/status; write the session/progress/rendering/recovery/persistence DRAFT-to-FINAL proposal, exact future paths and smallest reversible first edit; commit nothing and stop with a summary of at most 10 lines. No production/instrumentation edits, build/install or device commands. Device connected per user, intentionally unused and not queried. This scope supersedes older commit/continuation instructions below and in historical Gate B/Station 09/ownership text.

Proposal: `10_STATION.md`, C10-1 through C10-5. Design verification STATIC-ONLY; proposed runtime behavior NOT-VERIFIED. Proposed FINAL wording awaits user acceptance; no detailed ADR promoted. Recommended first later slice: unwired `session/playback_progress.dart` plus `test/playback_progress_test.dart`, with required documentation, deterministic time tests and file-scoped rollback. Exact subsequent integration paths and legacy-default selector are listed in Station 10. Implementation authorization and the Station-09-only baseline waiver boundary must be resolved before production edits; this planning instruction does not extend the waiver.

Current read-only Git verification: branch `feature/player-reengineering`, HEAD `260e811d5f459979e166492a203fbad1fdd2ea20`; prior Gate B docs commit `6de10d0` exists. Initial index empty; 32 initial short-status entries, no tracked player changes. Production LKG `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5` is an ancestor and matches the existing safety tag. Existing unrelated edits remain untouched. No commit/tag/push or LKG promotion in this continuation.

Station 10 planning checklist 4/4 is tracked separately from its original implementation checklist 0/10. Original mission counts remain 216 tasks / 116 checked. Station 10 implementation incomplete; Stations 11–20 unentered. All BEFORE/AFTER metrics NOT MEASURED; performance benefit UNKNOWN; native-library license classification unclear, personal-use scope retained. Agent invocations unchanged at 6; no new reviewer/gate/agent. **STOP at the proposal; await the user's next instruction.**

## Mission state

- Authoritative specification: `C:\Users\hosea\projects\app\Nova\NOVA_PLAYER_PROMPT_V2_1.md`, SHA-256 `105C6368ACE6B92CC2D793FA8CE61FB519026B56D202FA73CD26584B378F3F50`. The root copy contains Section 54A and takes precedence as the user directed. All root/docs specification copies and backups remain untouched.
- Feature branch: `feature/player-reengineering`.
- Safety tag: `pre-player-reengineering-baseline` → `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
- Historical Gate B continuation: six documentation/plan files only; actual Git now records `6de10d0` and follow-up status commit `260e811`. Current authorization is the Station 10 planning-only addendum above; no further commit authorized.
- Earlier Git-index write failure/rejected escalation was historical. Read-only log verification establishes the subsequent documentation commits exist; no index write, retry or permission bypass was attempted in this continuation.
- Last-known-good production commit: `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
- Current HEAD at Station 09 entry: `d19224bc3a59dbfe9db1c43126842159820ff33f` (`player: station 08 root-cause analysis gate a`). Pre-existing instrumentation is in its ancestry; no new code LKG.
- Current station: 10 — wiring design documented, PROPOSED / STATIC-ONLY, then STOP. Helper/tests tracked at `a909f2d`, still unwired; C10-1–C10-5 remain PROPOSED. Original full-core tasks 0/10; Stations 11–20 unentered. Historical incident/session notes and Gate A/B approvals are preserved; no new runtime authorization or LKG.
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
| 10 | Playback core stabilization | 10 | 7 | INCOMPLETE — BUILD-VERIFIED candidate; Gate C/device/LKG pending |
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
| **Total** |  | **216** | **123** |  |

Station tracking files: `00_STATION.md`–`20_STATION.md`, plus `STATION_06A.md` and `STATION_06B.md`. Station 10 isolated helper/tests only; player integration and Stations 11–20 unentered. `SESSION_1_HANDOFF.md`, unchanged Station 08 report and old gate-pending text are historical; current smallest-edit scope above controls resumption.

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
| Station 09 + Gate B approval | `6de10d0 docs: station 09 gate b decision`; `260e811 docs: record gate b decision status` | Documentation checkpoints verified in current log; no new production LKG. Earlier pending/index-rejection notes are historical. |

## License and clean-room status

Gate B accepts personal-use scope only; no distribution planned. The media_kit wrapper/package LICENSE files are permissive MIT, while exact bundled native-library classification remains unclear (UNKNOWN / NOT-VERIFIED). Keep the artifact verification plan in `LICENSE_NOTES.md` / `GATE_B_REVIEW.md`. Reopen license review BEFORE any future distribution; approval is not distribution clearance.

Exact licenses, upstream refs, and clean-room rules are in `LICENSE_NOTES.md`. Reference snapshots: Harbor MIT; Nuvio GPL-3.0; Stremio Kai GPL-3.0; Jellyfin Android GPL-2.0; Jellyfin iOS MPL-2.0; Swiftfin MPL-2.0; mpv-qol-scripts GPL-3.0. No code snippets or distinctive identifiers were copied. Harbor/Nuvio/Stremio local checkouts were absent and exact-SHA GitHub read-only files were used. The two required reference-agent audits used local Jellyfin Android and MPV-QoL checkouts; agents changed no files.

## Architecture decision log

**ADR-P001 engine/direction ACCEPTED at Gate B; detailed C10-1–C10-5 contracts remain PROPOSED until user acceptance.** Only the isolated unwired progress helper/test slice is authorized and implemented; no other ADR or contract is silently accepted. Broader design remains STATIC-ONLY; player runtime NOT-VERIFIED. Full alternatives/contracts/evidence ledger S1–S8 in `09_STATION.md`. Purpose is structural decoupling only; structural suitability may be STRONGLY INFERRED, but performance benefit is UNKNOWN without valid before/after measurement. No Section 51A absolute target relaxed.

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

Authoritative engine approval: `GATE_B_REVIEW.md`; historical options: `GATE_B_REVIEW.md-draft`; independent historical review/correction: `GATE_B_REVIEWER.md`. Gate B APPROVED WITH CONDITIONS. Current user instruction starts Station 10 planning only and forbids commits/production/build/install/device work. Stop after the proposal, see the current-continuation addendum and `10_STATION.md`. No push/tag. Production LKG remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; no current analyzer/tests/build/runtime proof.

The earlier uncommitted Gate A/baseline/ownership addenda are excluded from this commit. Current Gate A waiver and Gate B conditions are recorded in the committed Gate B packet; their decisions supersede historical pending/no-waiver text in earlier station/baseline documents without marking Station 03 complete.

## Historical Session 2 stop condition (superseded by current Station 09 planning waiver)

Station 03 was stopped at the user's direction after one exploratory Profile capture. The capture has no exact tap/start/stop markers, so no valid official startup timing or per-run performance metrics can be claimed. The official baseline remains INCOMPLETE; Station 04 or later must not be started in this checkpoint. The last-known-good production commit remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
