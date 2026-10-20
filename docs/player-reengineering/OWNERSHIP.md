# Investigation ownership

| Role | Authorized scope | Write access for this mission |
|---|---|---|
| Primary agent | Master plan, all NOVA/player analysis, architecture, decision log, integrations, verification, final reporting | `docs/player-reengineering/` mission reports and plan files only during Stations 00–07; no production player code under this session's explicit user constraint |
| `nova_player_auditor` | One read-only static audit for Station 02 | None; may read NOVA player source and return findings only |
| `reference_researcher` | One named reference repo per invocation at Stations 04, 05, 06, 06A, 06B (max five total) | None; reference source read-only, no network/build/device; final response only |
| `perf_log_analyst` | Saved measurements after Stations 03, 10, 19 | None; saved logs only |
| `ios_static_reviewer` | Station 18 or per user-supplied Codemagic log | None; static review only |
| `gate_reviewer` | Once at each specified gate A–E | None; read-only checklist review only |

All agents are read-only and must not spawn agents, run `adb`, install/run builds, alter device state, commit, or edit any repository files. Default one agent at a time; hard cap three, with three in parallel permitted only for the Station 04/05/06 trio. After every agent run, the primary agent will immediately run `git status --short` and confirm no files changed. A file change by an agent halts the mission for user notification. The agent invocation count is tracked in the master plan.
