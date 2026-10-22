# Investigation ownership

## Accepted core implementation — 2026-10-22

User **تم الاعتماد** accepts C10-1–C10-5 and authorizes the remainder of Station 10. Primary implements session/state/checkpoint modules, entry selector, independent core page, stable-surface host, additive engine APIs, the five entry routes, Arabic/English failure copy + generated localization, tests and documentation. This adds the small `widgets/player_session_surface.dart` path to the earlier proposed allowlist for independently testable surface retention. Legacy remains intact/default. Existing progress-slice changes are preserved; unrelated native/settings/brand/history changes are excluded from the checkpoint. No implementation delegated.

Session owns the sole native backend and its command/resolve lanes, exact state, sampled display, periodic checkpoint timer, panel/lifecycle intent and torrent lease. AppState retains storage/provider ownership; the shared checkpoint writer serializes local writes and frame persistence across core handoffs. Existing torrent preparation is reused without edits; because it deactivates the previous lease, core retires native first when that preparation path is needed. Snapshot metadata remains device-only and independent of synced history.

Gate C reviewer is read-only and checks the packet/source/test evidence; it never touches the device or writes files. Stop at Gate C; no Station 11, publication, legacy removal or LKG promotion. Current device discovery alone is not playback evidence.

## Current Station 10 progress slice — 2026-10-22

Primary agent alone implements `lib/features/player/video_player_page.dart`, `widgets/player_chrome.dart`, new `session/playback_progress_binding.dart`, the two new regression test files and required documentation. Existing exact progress helper, engine, storage, dependencies, native files and unrelated dirty paths preserved. Binding owns only its projection/listener/coalescer; the page still owns native lifecycle. Full C10 session/recovery/persistence contracts remain PROPOSED.

User explicitly waived baseline for Station 10; BEFORE remains NOT MEASURED. One supplemental timeline review invocation returned only reader/identity/gesture pitfalls. Its initial implementation assignment was immediately corrected under root Section 54A before any agent edits; agent confirmed no mutations. Primary made all implementation/test edits. Cumulative agent invocations 7; no Gate C reviewer/verdict, install, playback or device commands. Historical scope table below is retained for prior investigations, not current continuation authority.

| Role | Authorized scope | Write access for this mission |
|---|---|---|
| Primary agent | Current continuation: Station 08 analysis and Gate A packet only | Explicit Gate A review/report and mission-plan/status documents under `docs/player-reengineering/`; no production/instrumentation/config changes, no build/install/device commands; stage/commit only these scoped docs, never unrelated files |
| `nova_player_auditor` | One read-only static audit for Station 02 | None; may read NOVA player source and return findings only |
| `reference_researcher` | One named reference repo per invocation at Stations 04, 05, 06, 06A, 06B (max five total) | None; reference source read-only, no network/build/device; final response only |
| `perf_log_analyst` | Saved measurements after Stations 03, 10, 19 | None; saved logs only |
| `ios_static_reviewer` | Station 18 or per user-supplied Codemagic log | None; static review only |
| `gate_reviewer` | Once at each specified gate A–E | None; read-only checklist review only |

All agents are read-only and must not spawn agents, run `adb`, install/run builds, alter device state, commit, or edit any repository files. Default one agent at a time; hard cap three, with three in parallel permitted only for the Station 04/05/06 trio. After every agent run, the primary agent will immediately run `git status --short` and confirm no files changed. A file change by an agent halts the mission for user notification. The agent invocation count is tracked in the master plan.
