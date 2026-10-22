# Station 10 — Playback core stabilization

## Current core candidate — Gate C HOLD, 2026-10-22

**Station INCOMPLETE — implementation candidate, physical acceptance pending.** User accepted C10-1–C10-5 with **تم الاعتماد**; Station-10 baseline waiver remains explicit. Full legacy baseline/performance BEFORE is NOT MEASURED. No smoothness, native runtime, first-frame, LKG or Gate C approval claimed.

Implemented the accepted contracts in `session/playback_state.dart`, `session/playback_session.dart`, `session/playback_checkpoint.dart`, additive paused-open/seekable/awaitable-close engine APIs, `playback_entry_page.dart`, independent `core_video_player_page.dart`, and `widgets/player_session_surface.dart`. All five external entry routes now select once before allocation; default is legacy, opt-in define `NOVA_PLAYER_CORE=true`. Core internal episode/source transitions stay core. Existing progress wiring/legacy changes from the previous continuation are preserved; no native/dependency/signing/version/schema/sync-key changes.

Session commands serialize; stale generation/owner commands cancel; unknown failures do not auto-retry. Positive retry evidence permits at most one safe retry per operation/attempt; native adapter currently supplies none. Readiness waits for paused open, capability query and continuity restore; metadata/duration alone cannot authorize checkpoints, seek/resume success or first-frame claims. Session projections separate exact progress, 100 ms display and change-only transport. The page evaluates exact feature boundaries without position-driven surface rebuilds; a cached video child persists behind overlays and changes only for engine identity/fit. Panel/dialog/lifecycle intents cannot autoplay after a later user/system pause. Core reuses existing NOVA chrome/subtitles/preferences/segments rather than redesigning them in Station 10.

Immutable checkpoints preserve item/video/season/episode/exact milliseconds/eligibility and local-only frame rules. A shared writer orders core handoffs, coalesces only pending periodic snapshots for the same owner/content, and never overtakes forced writes. Existing AppState/provider storage paths retain ownership/semantics. Closing invalidates ingress, cancels progress/periodic work, drains commands, attempts capture/final save with bounded persistence waits, awaits native close and only then releases the torrent. Failed/hanging native close blocks another native owner. Non-cancellable resolver work also drains before competing native acquisition.

Source-resolution finding: existing `TorrentService.prepare` deactivates its prior server/torrent. Core therefore awaits native retirement before taking that path when replacing an owned torrent. Deliberate retirement keeps only the resolver transaction token; exit cancels it. Once teardown occurs, old playback is not claimed to survive cancellation; explicit retry re-resolves/prepares the source. Manual decoder/error retry otherwise keeps its current torrent lease through native replacement. Semantic track intent is rematched; unavailable tracks/nonseekable continuity return unsupported/paused. No software-decoder guessing or automatic source substitution.

Final post-review validation: full suite PASS **525 tests**, full analysis PASS/no issues (66.2 s), opt-in debug APK PASS (158.4 s), and scoped formatting/whitespace PASS. The one Gate C reviewer returned FAIL on four races; primary corrected all four with regressions (24/24 focused session tests). Original verdict/disposition are preserved in `GATE_C_REVIEWER.md`; no repeated independent review or independent PASS claimed. Startup settings are applied within the open generation before play; late unsupported results cannot undo closing; explicit acquired/retiring lease ownership prevents release on failed retirement; handoff play-intent tokens plus new-route lifecycle suppress stale autoplay. Save failures produce one sanitized UI warning. Final artifact checksum and exact commands are in `GATE_C_REVIEW.md`. Total agent invocations 8, no implementation delegation in this continuation.

Physical discovery only: `RF8NA2NNVNY` / Samsung SM_A217F is connected in `device` state. No install, launch, source selection or playback. iOS NOT-VERIFIED. Hardware, network/account, codec/track timing, full-page integration and profile/release performance remain NOT-VERIFIED / NOT MEASURED. Native library license still unclear/personal-use only. Packet and checklist: `GATE_C_REVIEW.md`.

Original implementation tasks 7/10 at scoped checkpoint/stop: four implementation/testing tasks, rollback-scope rule N/A, scoped commit and Gate C stop. Device/LKG/installation/real-playback and human Gate C acceptance remain unchecked. Mission checked count 123/216. No Station 11, release/push, safety-tag move or LKG promotion.

## Contract approval and implementation continuation — 2026-10-22

User replied **تم الاعتماد** to the explicit request to approve C10-1–C10-5 and continue the remainder of Station 10. All five contracts below are now ACCEPTED for implementation; earlier PROPOSED/awaiting-acceptance descriptions are historical. Station-10 baseline waiver remains in force, BEFORE stays NOT MEASURED, no performance claim or Gate C acceptance follows. Primary agent implements alone under root Section 54A, preserves the existing dirty progress slice and unrelated work, retains the independent legacy default, and stops at Gate C before Station 11.


## Current continuation — 2026-10-22 — optional progress wiring implemented

**Station INCOMPLETE.** This heading supersedes historical design-only/STOP/unwired descriptions below for the current slice. User explicitly requested continuation, then answered **`waive baseline للمحطة 10`**. The earlier Station-09-only waiver now extends to Station 10, while all BEFORE values remain NOT MEASURED and performance benefit UNKNOWN. C10-1–C10-5 remain PROPOSED pending separate acceptance for the broader core; no Gate C or LKG promotion.

Prior work, reference paths/revisions, prompt-copy differences, safety and REA fallback are reconciled in `evidence/CONTINUATION_2026-10-22.md`. Fresh helper checks confirmed 20/20 passing, including rejection of backward clocks; the historical rolled-back clamp/equal-input follow-up text below is not current code. Initial tracked player/test paths clean; unrelated dirty work preserved. Entry HEAD `a909f2d`, feature branch unchanged, production LKG/tag `c9257c0` unchanged, empty index. No commit/push/tag.

### Completed wiring substep (separate from the full station checklist)

- [x] Reconcile prior completion, helper implementation and baseline/gate limits.
- [x] Locate actual read-only references; distinguish snapshots without Git metadata from pinned upstream clones.
- [x] Record explicit Station 10 waiver; preserve NOT MEASURED performance values.
- [x] Add default-off `NOVA_COALESCED_PROGRESS` selection in `video_player_page.dart`.
- [x] Implement route-local `PlaybackProgressBinding` with seeded display samples, generation/interaction identity, detach/reset/close and late-callback protection.
- [x] Connect the optional bottom display at engine creation and invalidate before every current retirement/retry/dispose site.
- [x] Separate timeline display from exact tap/drag/accessibility authority; cancel invalidated drags and use current duration at commit.
- [x] Add deterministic projection/lifecycle tests and timeline interaction regressions, including LTR/RTL and light/dark themes.

Production paths: `video_player_page.dart`, `widgets/player_chrome.dart`, new `session/playback_progress_binding.dart`. Tests: new `test/playback_progress_binding_test.dart` and `test/player_timeline_progress_test.dart`. Existing `session/playback_progress.dart` behavior and its tests unchanged; only its stale unwired doc comment updated. A separate small binding module was chosen for fake-engine lifecycle testing instead of embedding untestable native engine ownership into page-private callbacks. It owns no engine/disposal; new page routes naturally create a new content owner.

Flag false allocates no binding/coalescer/listener; optional readers fall back to existing widget fields. Flag true only samples position/duration/buffer display. Raw save/resume/completion/skip/next-episode paths and `_onEngineTick` remain unchanged. Exact reader and commit closures capture engine plus interaction token; stale closures cannot command a replacement. Timeline drag stores fraction and re-reads duration at release; identity changes cancel instead of restarting an old gesture. Legacy-default path retained; no storage/native/dependency/engine configuration change.

### Verification for this continuation

- Initial helper-only tests: PASS 20/20; initial helper/test scoped analysis: PASS.
- Production-file scoped analysis: PASS, no issues (119.0 s).
- Seven relevant player test files: PASS 62/62, including 16 new binding/timeline tests. Initial accessibility test harness incorrectly targeted the ancestor semantics node, then left its semantics handle alive; both test harness issues corrected. These were not runtime product failures.
- Subsequent test-only use of `node.owner` replaces deprecated pipeline owner access; focused accessibility rerun PASS 1/1. Final analysis initially found four protected-member uses in the fake-engine test; replaced external `hasListeners` access with a fake-owned public getter. Final six-file scoped analysis PASS, no issues (14.9 s), and both new test files rerun PASS 16/16. Final formatting and whitespace checks PASS. No full repository test suite or full-repository analysis run in this continuation.
- `flutter build apk --debug --no-pub --dart-define=NOVA_COALESCED_PROGRESS=true`: PASS (283.5 s), `build/app/outputs/flutter-apk/app-debug.apk`, 245,718,090 bytes, SHA-256 `4542FC753F40DF68D640C4320EF32B0497A3F2E90C01D987B9A14FCB7808D6F1`. Kotlin daemon connection errors fell back to compilation and did not prevent the build; existing Gradle/AGP/Kotlin/Java compatibility warnings retained, no native config edits. Opt-in Android wiring status BUILD-VERIFIED, runtime NOT-VERIFIED. Debug output is compilation evidence only, never performance evidence or a distribution/update artifact.
- No install, device command, app launch, playback, emulator or iOS build. Android runtime NOT-VERIFIED, iOS NOT-VERIFIED. Exact engine callback attribution/native cleanup and full rendering isolation remain NOT-VERIFIED. No new performance measurements.

### Next boundary

This substep is complete; full Station 10 remains 0/10 original tasks, mission 216/116. Before implementing the proposed route-owned session/command lane, recovery and persistence replacement, retain the prior explicit requirement for separate acceptance of C10-1–C10-5. Their complete reviewable contracts are below under **Decisions — DRAFT-to-FINAL interface proposal**. Do not interpret this progress slice as acceptance of those contracts, Gate C, zero surface rebuilds, smooth playback or a new LKG. After the user's next instruction, continue Station 10 and stop at Gate C for actual user playback judgment before Station 11.

## Current stop / implementation-gate incident — 2026-10-21

The user stopped implementation and reported an implementation change before the applicable implementation gate. Correction scope: **revert only changes introduced in the latest action**, preserve all earlier/user content, inspect Git before/after, record the incident, then report before continuing. No implementation, tests/analyzer/formatter, device commands, build/install, staging or commit authorized now.

Reverted the latest equal-sample/clock-clamping follow-up and its regression-test edits using exact reverse hunks in `lib/features/player/session/playback_progress.dart` and `test/playback_progress_test.dart`. This restores their pre-latest-action behavior/text: equal input cancels pending work, clock regression raises StateError, and the previous tests are restored. The extra intervening-equal-sample regression test was removed. No restore/reset/clean or whole-file deletion was used. Earlier helper/test additions existed before the latest action and remain untracked; this correction does **not** claim all earlier implementation additions were removed. No other application source/test file modified.

Both paths were untracked before correction: ordinary staged/unstaged `git diff` was empty. Direct source inspection and no-index inspection were therefore used as well. Post-correction source checks confirm all latest-action implementation/test hunks are gone; original 190-line helper and 405-line test remain. Existing unrelated edits/deletions/untracked files are preserved. HEAD remains `260e811d5f459979e166492a203fbad1fdd2ea20`, branch `feature/player-reengineering`; index empty.

Incident classification: implementation change reverted before the applicable implementation gate, as directed by the user. Verification STATIC-ONLY; no fresh executable checks. AGENTS/module description is restored to the earlier behavior; current master/ownership addenda halt implementation. Historical checks and the superseded implementation notes below must not be read as current authorization.

Session reconciliation: disk records this continuation as Station 10 after Gate B documentation commits `6de10d0` / `260e811`; Session 1 handoff and Station 08/Gate A are earlier recorded checkpoints. Do not invent a Session 1/2 identity, rewrite those approvals, repeat a gate reviewer, or advance any station. Exact next task after the correction report: read-only reconcile the user's Session 1/2 stop boundary with those disk checkpoints; investigation/documentation only, with no execution before the user has reviewed this report. **STOP NOW, no commit.**

## Status

- Status: STOPPED at user direction — latest-action implementation changes reverted; earlier unwired additions preserved.
- Verification status: STATIC-ONLY for rollback inspection. No executable checks in this correction. Player integration/runtime: NOT-VERIFIED.
- Date: 2026-10-21, Asia/Riyadh.
- Original implementation checklist: 0/10 complete. Planning checklist below is separate; mission task totals remain 216/116.
- Current authorization: latest-action-only rollback, incident documentation and status report, then STOP; all former implementation/test instructions below are superseded.
- The user says the device is connected. It was not queried or used; no current device verification is claimed.

## Objective

Turn the five Gate B DRAFT interfaces into an explicit DRAFT-to-FINAL proposal for review, name the exact later edit paths, and propose one independently reversible first edit. Retain Option A and the locked media_kit stack. Purpose: structural decoupling only; performance benefit UNKNOWN without valid before/after measurement.

## Scope / prerequisites / inputs

Read the root `NOVA_PLAYER_PROMPT_V2_1.md` completely from disk (Section 0 overrides; Section 54A forbids implementation delegation), `00_MASTER_PLAN.md`, `GATE_B_REVIEW.md`, `BASELINE.md`, `09_STATION.md`, repository `AGENTS.md`, the existing Station 10 placeholder and ownership ledger. Read current engine, selected page/persistence/widget code and exact player-entry searches to ground the file list. No agents used; invocation total stays 6.

Gate B approved engine/direction, not these detailed interfaces. The user accepted the smallest-edit plan only and explicitly requires all five contracts to remain **PROPOSED until separately accepted**. This instruction authorizes the isolated unwired progress slice and computer-only checks, superseding the earlier planning-only stop for this slice. ADR-P001 remains accepted; no other ADR or contract is promoted. No Gate C or new gate verdict is claimed.

## Evidence required / repository findings

Source/Git facts below are VERIFIED as text/metadata, with technical verification STATIC-ONLY:

- Root `C:/Users/hosea/projects/app/Nova`; branch `feature/player-reengineering`.
- HEAD `260e811d5f459979e166492a203fbad1fdd2ea20`, as expected. Recent commits: `260e811 docs: record gate b decision status`, `6de10d0 docs: station 09 gate b decision`.
- Production LKG `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5` resolves, is an ancestor of HEAD (merge-base check exit 0), and matches existing `pre-player-reengineering-baseline`. No LKG promotion.
- Initial `git status --short`: 32 entries, including existing settings/AGENTS/Gradle/docs edits, deleted artwork/skill files, and untracked skills/agents/spec copies. Initial index empty. `git diff --name-only HEAD -- lib/features/player` empty. All pre-existing changes preserved.
- Root specification SHA-256 `105C6368ACE6B92CC2D793FA8CE61FB519026B56D202FA73CD26584B378F3F50` matches the master plan. Specification copies/backups unchanged.
- The master/Gate B/Station 09 still contain historical commit-pending text. Actual Git has both documentation commits; this entry and the master-plan current addendum supersede those stale continuation instructions without rewriting the historical approval.
- `engine/playback_engine.dart`: `open()` opens paused internally but ends with play; public API cannot request a paused result. `dispose()` starts subscription cancellation/native disposal without awaiting. Position/buffer handlers publish the common notifier. `PlayerVideoSurface` is defined in that same file and takes `MediaKitEngine`.
- `video_player_page.dart`: owns five-second saves, watchdog/software fallback, source resolution, lifecycle, route replacement and broad `setState`. `_switchToStream` replaces the same episode without forwarding current position/play/track intent. Widget dispose starts torrent stop before confirmed native disposal. These are structural facts, not proven causes of measured stutter.
- `AppState.recordPlayback` mutates existing history/Continue Watching, persists/syncs existing buckets, removes local resume frames in the last 120000 ms and mirrors linked progress. Its returned Future is not proof all fire-and-forget remote provider operations have completed.
- `BASELINE.md` stays INCOMPLETE: zero official bounded runs, all BEFORE values NOT MEASURED. Historical diagnostic hooks are already in HEAD ancestry and are not a newly validated production LKG.

## Decisions — DRAFT-to-FINAL interface proposal

### C10-1 Session / ownership — ACCEPTED 2026-10-22

| Interface | Required contract |
|---|---|
| Inputs | Immutable playback request preserving every current `VideoPlayerPage` argument: item, URL, streamName, videoId, initialPositionMs, season, episode, streams/index, headers, filename, PreparedTorrent and recordProgress. Freeze mutable maps/lists at the boundary. Content identity uses item/type/videoId/season/episode; source-attempt identity is separate and never persisted. |
| Owner | Exactly one route-owned `PlaybackSession`, one engine/controller pair and one command lane. Session owns resolver transaction, subscriptions, timers, recovery, lifecycle intent and the acquired torrent lease. Existing shared services remain injected/reused, not rewritten. |
| Commands / results | `open`, `replaceSource`, `seekTo`, `setPlaying`, `selectAudio`, `selectSubtitle`, `setRate` and delay/volume intents return Futures with applied, cancelled, unsupported or typed failed outcomes. A failed lane item cannot poison later commands. UI never mutates native state directly. |
| Ordering | Open/seek/track/rate/play operations serialize. Every operation captures content generation and source-attempt generation and rechecks after every await. Replacement/exit invalidates superseded intent immediately; cancel what is cancellable, drain non-cancellable native work before opening again. Do not stamp late untagged backend events as a new source: detach old source listeners, drain/reset and establish the new subscription boundary before accepting new-source events. Unprovable attribution remains UNKNOWN and blocks unsafe handoff. |
| State | idle -> resolving -> opening -> prepared -> playing/paused, plus failed, closing, closed. Buffering is a separate transport flag; seeking is an operation. Known duration/prepared is not a first rendered frame. Live/non-seekable readiness must not depend on positive duration alone; unsupported/unknown capabilities cannot be assumed. |
| Lifecycle / panels | Rotation/panels keep the session. Coalesce inactive/hidden/paused events into one pause/checkpoint transaction; no foreground autoplay. Panel pause uses an ownership token plus generation/intent revision: only its still-valid token may restore previous play intent, never after a later user/system pause or error. |
| Close | `close()` returns the same terminal Future to every caller. Invalidate ingress and cancel timers/listeners immediately; capture immutable final identity/exact progress while engine is readable, pause/capture an eligible local frame, then attempt the serialized final save. Native close and lease release execute in finally even if persistence fails. Await native relinquishment before torrent release or competing engine creation. Disposal errors/hangs block new ownership; never create a second player on timeout. Widget `dispose()` initiates this Future without reading context; explicit exit/handoff awaits it and reports failure. A stalled save must not indefinitely delay native cleanup; report incomplete persistence separately. |

Preserve legacy engine entry defaults while adding paused-open intent and awaitable close for the opt-in path. Do not suppress the legacy common notifier until the legacy implementation no longer depends on it.

### C10-2 Progress / projections — ACCEPTED 2026-10-22

- `PlaybackProgress` is immutable: content/source generation, exact latest backend position, duration, bufferedEnd. The session retains unsampled backend values for seek/resume/checkpoints/feature decisions; the UI projection is never persistence authority.
- `PlaybackProgressCoalescer` accepts samples and an injected monotonic clock/scheduler, equality-filters, and publishes the latest changed sample no sooner than 100 ms after the previous progress emission. At most one pending trailing callback; no unchanged periodic emissions. No catch-up burst after delayed callbacks. Cancel pending work on reset/close.
- On source/content generation reset, invalidate pending old samples immediately, clear the visible progress binding and start a new-generation projection. Generation resets are explicit structural transitions; do not use them to bypass the 100 ms cap for ordinary seeks/duration/buffer updates. Such updates publish within the next window when the scheduler is serviced. Hidden progress widgets need no active UI ticker.
- Transport/buffering boolean, tracks/selection/rate/error and feature-state projections notify only on meaningful change. Subtitles publish changed lines/style/source generation independently of the progress cap; engine remains timing authority. Countdown is at most once/second; segment decisions evaluate precise input and notify only on changed active state.
- Separate listenables/streams use existing Dart/Flutter primitives. No second mutable player truth, global notifier, new state package or UI notification for every native event.

### C10-3 Rendering — ACCEPTED 2026-10-22

- Retain `VideoController` / `Video` / `PlayerVideoSurface`; one stable video child per engine identity. Progress/buffer/transport/panels/HUD/subtitle/countdown listeners live outside that child's build boundary. Preserve an element/widget child across ordinary parent updates; a stable key alone is insufficient.
- Keep the video mounted behind loading/error/control overlays while owned. Only intentional source teardown/terminal close may remove it. Fit/zoom/layout/orientation may change geometry without creating a player/controller; log those transitions separately from progress rebuilds.
- Subtitle overlay has its own line/style subscription and preserves existing Arabic shaping, font, offsets and pinch geometry. No parser/native renderer switch; ASS/bitmap fidelity stays UNKNOWN.
- Reuse present chrome/panels, themes, RTL/logical directions and safe areas. No visual redesign. Test surface build count and fake engine creation count under progress/control/panel changes, with phone/tablet, LTR/RTL and light/dark layout coverage. These tests establish widget behavior only; native surface/decoder recreation requires later device evidence.

### C10-4 Recovery / continuity — ACCEPTED 2026-10-22

- Typed failure contains category, failed operation, content/source attempt, recoverability evidence and a sanitized diagnostic code. Categories: HTTP/auth/source, network/buffering, decode/format, output/lifecycle, subtitle/track/seek, cancelled, unknown. No raw exception/URL/header/token/hash in user copy or logs. Ambiguous buffering plus zero position never proves decoder failure.
- Automatic recovery is disabled for auth/unsupported format, cancellation, unknown or unproven recoverability. A proven recoverable operation gets at most ONE automatic retry per operation/source attempt. Automatic reopen consumes the same attempt budget and cannot reset it; successful playback does not replenish it. Explicit manual retry or an explicit source change creates a new attempt. No loop, automatic alternate-source choice or software-decoder recreation.
- Same-content source switch captures exact position/duration, play intent, speed, audio/subtitle semantic selection (including explicit off), external-subtitle intent and delays before awaiting. Pause/checkpoint old source; resolve candidate; drain old native work; open candidate ONCE paused; revalidate capabilities/duration, rematch tracks by language/role/title (IDs are source-local), restore speed/delays, seek a valid target once, then restore still-current play intent. If resume choice is unresolved, keep paused and writes blocked. Non-seekable sources return unsupported rather than pretend continuity.
- Resolve cancellation retains the old paused source only while still valid/owned; replay requires explicit user intent. Once old media was replaced, recovery cannot claim rollback without reopening it. New episode/title checkpoints old identity, clears position/segments/countdown/dismissal/track IDs, then applies that content's own resume/preferences.
- Only the opt-in new session replaces the ambiguous legacy watchdog. The retained default legacy path stays available. Decoder/cache tuning, fallback recreation or new backend needs evidence and the applicable approval; none is proposed for this first edit.

### C10-5 Persistence — ACCEPTED 2026-10-22

- Immutable checkpoint: content identity and MediaItem snapshot, positionMs/durationMs from exact backend state, in-memory monotonic sequence, cause and recordProgress/resume-choice eligibility. Sequence/generation are process-local, not new stored fields. Freeze before awaiting or changing source; never read widget/context after dispose.
- Keep current five-second periodic policy. Single in-flight save plus at most the latest pending periodic snapshot for the same identity; a forced pause/source/exit checkpoint supersedes older pending periodic work and is awaited. Never coalesce across different episodes/content or discard a forced final checkpoint. No older queued snapshot may run after a newer final checkpoint for that identity.
- Serialize calls through one route-handoff checkpoint writer, delegated to existing `AppState.recordPlayback`; the next route must drain the prior writer before starting its writes. No replacement AppState database, sync buckets, keys, schema or new durable retry queue. Provider enablement/scrobble behavior and ownership stay on existing paths; do not double-send from session and page. Serialization covers local call order, not remote acknowledgement guarantees.
- Preserve recordProgress=false, unresolved-resume write suppression, current prompt/start-over behavior, existing progress validation and the exact last-120000-ms Continue Watching/snapshot semantics, including current short-content behavior. Existing near-end/next-episode predicates remain distinct and characterized; do not silently unify thresholds now. Any semantic/data change triggers the conditional gate.
- Frames stay compressed, expiring, device-only and separate from synced history with existing retention. Frame completion checks captured generation/identity before saving, so a stale capture cannot replace the new episode's frame under a title key. Capture failure never blocks native cleanup. Save failures are surfaced/sanitized, writer recovers for later calls, and no success is fabricated.

## Exact files for a later authorized edit

All paths below are repository-relative and are a proposed allowlist, **not current authorization**. Stage later work in the listed slices; expanding the list requires a recorded scope revision. No production files have been changed now.

| Slice | Exact paths | Purpose |
|---|---|---|
| First isolated edit | `lib/features/player/session/playback_progress.dart` (new); `test/playback_progress_test.dart` (new) | Immutable sample + pure coalescer and deterministic boundary/cancellation tests. Unwired; no engine, UI or storage import. |
| Session and adapter | `lib/features/player/session/playback_state.dart` (new); `lib/features/player/session/playback_session.dart` (new); `lib/features/player/session/playback_checkpoint.dart` (new); `lib/features/player/engine/playback_engine.dart` | Request/identity/typed outcomes/projections, ordered ownership/recovery, serialized checkpoint writer, additive paused-open/awaitable-close APIs and stable existing surface boundary. Existing defaults retained. |
| Opt-in composition | `lib/features/player/playback_entry_page.dart` (new); `lib/features/player/core_video_player_page.dart` (new) | Nonpersistent runtime legacy/core choice, legacy default; core reuses existing chrome/panels/subtitle/preferences/segments and routes intents to session. Choose before allocating native resources. No live toggle between running engines. |
| Route through selector | `lib/features/media/media_detail_page.dart`; `lib/features/downloads/downloads_page.dart`; `lib/features/library/library_page.dart`; `lib/features/live_tv/live_tv_page.dart`; `lib/features/torrent/magnet_opener.dart` | Replace only player import/constructor with compatible entry wrapper, preserving every argument/navigation result. Legacy internal episode/source navigation continues directly to legacy; new core navigation retains selected mode and awaits handoff. |
| Focused verification | `test/playback_session_test.dart` (new); `test/playback_checkpoint_test.dart` (new); `test/playback_rendering_contract_test.dart` (new); `test/playback_entry_page_test.dart` (new) | Fake-engine command races/close/source continuity/retry budgets; blocked/failed/coalesced writes and exact identity; stable video subtree; legacy default/one-engine selection and argument parity. |
| Later observability | `lib/features/player/player_diagnostics.dart`; `test/player_diagnostics_test.dart` (new) | Bounded session/run counters, refresh-aware union jank, explicit buffering transitions and available decoder/first-render evidence; release guards. No synthetic first frame from duration/ready. |
| Required documentation with those slices | `AGENTS.md`; `docs/player-reengineering/00_MASTER_PLAN.md`; `docs/player-reengineering/10_STATION.md`; `docs/player-reengineering/OWNERSHIP.md` | Document new implemented paths/contracts/commands and actual validation; keep pre-existing user AGENTS changes. Update AGENTS once first module is actually added. |

The existing `lib/features/player/video_player_page.dart` remains the independent legacy implementation; no planned edit to it. Existing subtitle/chrome/sheets/preferences/segments, AppState/storage/torrent services, dependency/localization/native/signing/CI files are reused without edits in this proposal. New user copy or an unexpected required edit needs the exact path list revised first. Gate C review files/evidence are a later authorized review step, not part of the first edit.

## Smallest reversible first edit

Recommend the two-file isolated progress slice above, plus its AGENTS/master/station/ownership documentation. It must remain unimported by app code. Implement only C10-2 sample/coalescer logic with injected time and scheduling. No selector, route migration, engine mutation, persistence or device work in that slice.

Originally proposed checks for this slice: targeted `flutter test --no-pub test/playback_progress_test.dart`, `flutter analyze --no-pub`, formatting and scoped `git diff --check`; these have now run, with results below. Cases: a high-rate burst emits only latest at 100 ms boundaries; no duplicate unchanged/trailing emissions; a delayed scheduler never bursts; seek/duration/buffer coalesce; source reset cancels old generation; close suppresses callbacks; clock is monotonic; exact input sample is preserved independently of UI publication.

Rollback before wiring: remove only the two newly added owned files and reverse only this slice's exact documentation hunks after comparing current changes. No stored data/native state/route effect to undo. Never restore the user's whole AGENTS file. This first edit is reviewable structural groundwork, not a playback fix or completed Station 10.

The user has now explicitly authorized only this unwired module and unit tests, plus computer-only analysis/tests. This does not authorize player integration or extend the legacy-baseline waiver to runtime changes. Resolve that boundary before any later player integration/behavior edit; connected hardware by itself grants no command permission.

## Isolated slice implementation — 2026-10-21

Added the exact two authorized code files. `PlaybackProgress` retains immutable generation/position/duration/buffer samples with value equality and no timing rounding/clamping. `PlaybackProgressCoalescer` publishes the first generation sample immediately, then changed latest samples at least 100 ms apart. It retains exact unsampled `latest` separately from `published`, schedules at most one trailing callback and stops scheduling while unchanged/idle.

Default clock/scheduler are Stopwatch/Timer; both can be injected. Early callbacks reschedule the remaining interval; late callbacks emit once and anchor the next window to actual execution time. Reset clears snapshots, cancels/invalidates old callbacks and rejects old-generation samples; repeating the current pair is a no-op. Close is idempotent, freezes snapshots and rejects future input/reset. Reentrant consumer calls observe already-updated publication state. Follow-up: backward clock readings clamp to the previous reading, and equal input skips new scheduling while retaining any existing pending callback. No engine, Flutter UI, persistence or native import; no app import of this module.

Follow-up regression coverage: an equal sample retains the original pending timer without a duplicate publication; a later differing sample still publishes at the original 100 ms deadline; backward clock readings during add and callback delivery do not throw or publish early. These updated tests have not been run by the agent, as requested. Prior checkbox/check results below describe the earlier revision.

- [x] Add only the unwired helper and its deterministic unit tests in the authorized paths.
- [x] Keep C10-1–C10-5 PROPOSED; update AGENTS/master/ownership without replacing pre-existing edits.
- [x] Format both files and pass the targeted unit test file (20 tests).
- [x] Finish computer-only repository analyze/full test checks and record actual results.
- [x] Show final diff statistics/new-file list and stop without committing or integrating.

## Tasks

Planning deliverables (separate from the original 10 implementation tasks):

- [x] Verify disk specifications, expected HEAD, index, dirty paths and production LKG metadata.
- [x] Write all five DRAFT-to-FINAL contract proposals with ownership, ordering and compatibility constraints.
- [x] Name exact future edit paths, minimal first slice, validation and rollback.
- [x] Synchronize current master-plan scope/status; stop after the proposal summary.

Original implementation checklist — 7/10 at checkpoint/Gate C stop; physical acceptance pending:

- [x] Implement approved core session architecture and preserve legacy selector.
- [x] Stabilize controller lifecycle, event subscriptions, cancellation and disposal.
- [x] Implement error classification/retry/fallback contracts without loops.
- [x] Add focused state/session tests for lifecycle and transitions.
- [ ] Run analyze/tests and physical-device functional LKG checks; performance only in Profile/Release.
- [ ] Record installation, app launch, real playback evidence and source stream.
- [ ] Meet user Gate C review requirement and record LKG.
- [x] Clean only station-owned paths if rollback becomes necessary. N/A: no rollback triggered; unrelated work preserved.
- [x] Commit only Station 10 paths/docs. Scoped core checkpoint; unrelated hunks excluded.
- [x] Stop at Gate C for user playback judgment. HOLD; no Station 11.

## Files inspected / modified

Planning inspection: the five requested documents, AGENTS/Station 10/OWNERSHIP, complete engine source, targeted current player/lifecycle/source/save/render code, AppState progress path, diagnostics, chrome/subtitle snippets and all `VideoPlayerPage` call-site paths. Current slice also checked package/analyzer configuration, existing test conventions, Git state and source import boundaries.

Added: `lib/features/player/session/playback_progress.dart`, `test/playback_progress_test.dart`. Documentation updated: `AGENTS.md`, `docs/player-reengineering/00_MASTER_PLAN.md`, `docs/player-reengineering/10_STATION.md`, `docs/player-reengineering/OWNERSHIP.md`. No other production/config/dependency/localization/native file edited; historical gates/Station 09/baseline/root specification unchanged. Existing user AGENTS changes preserved.

## Tests / verification

Planning-only Git/source/hash checks above remain historical. **The following successful executable checks are for the prior revision, before the requested equal-input/clock fixes; they do not validate the current code.** Current follow-up verification is source/diff/whitespace review only; no tests, analysis or formatter run.

| Command / check | Result |
|---|---|
| `dart format lib/features/player/session/playback_progress.dart test/playback_progress_test.dart` | PASS, both formatted; test file adjusted. |
| `flutter test --no-pub test/playback_progress_test.dart` | PASS, all 20 new unit tests. |
| `flutter analyze --no-pub` | PASS, no issues found (279.1 s). |
| `flutter test --no-pub` | PASS, all 472 unit/widget tests on the computer. Existing sync widget tests printed MissingPluginException diagnostics; the suite still exited 0. |
| Scoped tracked `git diff --check` plus `git diff --no-index --check -- NUL <each new file>` | PASS, no whitespace errors; line-ending conversion warnings only. |
| Source import search | Only `test/playback_progress_test.dart` imports the helper; no production integration. |
| Final Git metadata | HEAD unchanged, index empty; only the two named new code files plus the four allowed documentation files were edited in this slice. Existing unrelated work preserved. |

No build APK/install/adb/Flutter device command or playback measurement. Prior revision was BUILD-VERIFIED under Section 0.2; current fixes are STATIC-ONLY until user validation. The earlier 190-line helper / 405-line test statistics belong to the previous revision. Both code paths remain untracked and unwired. No native/mobile playback or production LKG claim.

Initial sandboxed Dart/Flutter launchers waited silently for their SDK cache lock under `C:/src/flutter`; those two sessions were interrupted. Formatting/tests were rerun with the required external-cache permission; no alternate SDK/permission bypass or device command. The targeted run passed as above; final repository checks recorded when complete.

## Performance evidence / blockers

All BEFORE/AFTER metrics NOT MEASURED. Performance benefit UNKNOWN. Android runtime and iOS build/runtime NOT-VERIFIED; broader design STATIC-ONLY. Bundled native-library classification stays unclear; personal use only, reopen license review before any planned distribution. Baseline/integration authorization and later on-device Gate C acceptance remain unresolved. The isolated helper/test slice is complete; Station 10 implementation is not complete and no technical blocker is inferred from the intentionally unused connected device.

## Acceptance criteria / station completion review

Planning acceptance: five concrete contracts, exact future paths, reversible first slice and scope limits recorded. User accepted only the smallest-edit plan; all five contracts remain PROPOSED until separately accepted. The isolated helper does not complete any original full-core task. Station acceptance still requires original tasks, applicable Section 51A evidence and human Gate C. No new LKG, no commit and no agent invocation.

## Next station / stop condition

STOP after showing this follow-up diff. The user will run `flutter test --no-pub test/playback_progress_test.dart` themselves; do not rerun it or analysis. Do not wire the module into the player, enter Station 11, use the device, build APKs, install, stage or commit. Await separate authorization for integration; contracts remain PROPOSED. Production LKG stays `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; HEAD stays `260e811d5f459979e166492a203fbad1fdd2ea20`.
