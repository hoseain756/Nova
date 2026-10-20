# Player reengineering — Session 1 handoff

## Checkpoint

- Scope completed: Stations 00–07. Station 08 was not started.
- Branch: `feature/player-reengineering`.
- Safety tag: `pre-player-reengineering-baseline` → `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`.
- Current last-known-good production commit: `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`. All session commits are documentation-only; production player code was not changed.
- Current documentation checkpoints: Station 02 `e257689`; Station 03 `8a56c5e`; Station 04 `8349e27`; Station 05 `6c9776d`; Station 06 `aa6f8ca`; Station 06A `c11dcae`; Station 06B `1b4924d`; Station 07/session handoff commit is the final commit containing this file.
- Agent invocations: 3 total, max concurrency 1 — NOVA player audit, Jellyfin Android audit, MPV QoL audit. After each final result, `git status --short` showed no agent-created files.

## Station status

| Station | Status | Evidence / blocker |
|---|---|---|
| 00 | COMPLETE | Preflight, safety branch/tag, persistent plan, tracking files. |
| 01 | COMPLETE | Repository/platform inventory, license and ownership notes; Flutter suite baseline 452 tests passed. No analyze/build was claimed. |
| 02 | COMPLETE — STATIC-ONLY | Player lifecycle, event listeners, rebuild scope and overlays audited. Rebuild/jank observations are hypotheses, not measured causes. |
| 03 | NOT MEASURED (not device-BLOCKED) | Physical phone connected. No stream was attached or configured, no Profile build/install or playback run occurred, and the required debug/profile timing helper could not be added within this documentation-only session. All runtime cells have zero runs. See `BASELINE.md`. |
| 04 | COMPLETE — STATIC-ONLY | Harbor exact snapshot `9b811556d13f6eb2ba7c524a5bb0d561c88fae94`; GitHub read-only source fallback because no local clone. MIT. |
| 05 | COMPLETE — STATIC-ONLY | Nuvio exact snapshot `324afcffb962f1f7df45c5fa951131acec5a15a7`; GitHub read-only source fallback. GPL-3.0; clean-room paraphrase only. |
| 06 | COMPLETE — STATIC-ONLY | Stremio Kai exact snapshot `a5a2a37e818fb5e9406caf65af374fa7fe7700af`; supplemental MPV QoL snapshot `e0b04926f00ce3d482120d5bf15ebc0e32f7d94a`. Kai repo had no local checkout. QoL agent found its local checkout at expected SHA. Direct runtime linkage of the exact companion checkout to Kai remains UNKNOWN. Both GPL-3.0. |
| 06A | COMPLETE — STATIC-ONLY | Jellyfin Android local checkout verified at `3e660a84bde87281adee8f092b8af48719734916`; Media3 ExoPlayer integrated/default, optional external players separate. GPL-2.0. |
| 06B | COMPLETE — STATIC-ONLY | Jellyfin iOS Expo AV snapshot `ceca8eb14ef79e2c0d7bde99d95213c7d69d131d`; Swiftfin native proxy snapshot `f9842d500f2b1c3178bebbcbf67d6b82d21d47ec`. No Mac/Xcode/iOS device. MPL-2.0. |
| 07 | COMPLETE — STATIC-ONLY | Cross-project engineering comparison and bounded NOVA recommendations in `07_STATION.md`; no engine/architecture decision. |
| 08–20 | PLANNED — NOT ENTERED | Explicitly recorded in each station file. |

## Device facts and limits

Physical USB device `RF8NA2NNVNY`: Samsung SM-A217F, Android 12/API 31, Exynos 850, arm64-v8a, 3,799,732 kB MemTotal, 720×1600 and only a 60.000004 Hz supported display mode (16.67 ms budget). The preflight snapshot showed thermal status 0, battery 35% and USB powered, low-power mode off, developer options off, animation scales 1. These are preflight observations, not sustained run conditions. H.264/HEVC vendor decoder declarations were found, but active runtime decoder selection was not measured. Full caveats: `evidence/PHYSICAL_DEVICE_PREFLIGHT.md`.

No emulator was started. No iOS build/runtime was attempted. No user or NOVA playable test stream was available. No measurement values were fabricated.

## Files produced or updated

- `00_MASTER_PLAN.md`, `00_STATION.md`–`20_STATION.md`, `STATION_06A.md`, `STATION_06B.md`.
- `BASELINE.md` (zero-run matrix; all unavailable values explicitly NOT MEASURED).
- `02_STATION.md`–`07_STATION.md` (audit, reference investigations, and comparison).
- `LICENSE_NOTES.md`, `OWNERSHIP.md`, `evidence/INITIAL_GIT_STATUS.txt`, `evidence/PHYSICAL_DEVICE_PREFLIGHT.md`, `evidence/STATION_01_TEST_BASELINE.txt`, and `evidence/STATION_01_TEST_SANDBOX_ERROR.txt` were created during the earlier checkpoints and remain the evidence record.
- This `SESSION_1_HANDOFF.md`.

Root `NOVA_PLAYER_PROMPT_V2_1.md`, its backup, the older docs copy, `codex-agents/`, and all pre-existing unrelated user changes were excluded from commits and left untouched by this work.

## Exact next step

Before any production player change or confident root-cause/design decision, finish Station 03 on `RF8NA2NNVNY`: provide or configure a NOVA-playable test stream, add the required debug/profile-only timing diagnostics in a session that authorizes that instrumentation, then run the Section 0.9 Profile-mode scenarios with at least three repetitions and record Flutter frame timings separately from decoder drops. After that, resume at Station 08 and keep every unmeasured hypothesis labeled accordingly. No implementation starts until the required review gates are satisfied.
