# NOVA legacy player performance baseline

## Status

**INCOMPLETE — OFFICIAL BASELINE NOT CAPTURED.** One user-played exploratory sample was accepted, but it does not satisfy Section 0.9's three-run, run-bounded protocol. Official baseline scenario counts remain zero; no median/min/max is valid.

## Device and protocol facts available

- Device: `RF8NA2NNVNY`, Samsung SM-A217F, Android 12/API 31, Exynos 850, arm64-v8a; device preflight in [`evidence/PHYSICAL_DEVICE_PREFLIGHT.md`](evidence/PHYSICAL_DEVICE_PREFLIGHT.md).
- Display: only a 720×1600, 60.000004 Hz supported mode was listed at preflight; nominal frame budget is 16.67 ms. This is a budget reference, not a measured frame time.
- Preflight snapshot reported battery 35%, USB powered, low-power mode off, thermal status 0, developer options off, and animation scales 1. These values were not monitored during playback runs.
- Legacy production code baseline: `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; this mission made no production player changes.
- User provided one source for this session: One Piece S23E01 / absolute episode 1153, Torrentio release “1080p CR [AnoZu] WEB-DL Dual-Audio DDP 2.0 H.264”. No URL, info hash, token, or key is recorded.
- The already-installed Profile APK was not rebuilt or reinstalled. `NOVA_DIAG enabled mode=profile` appears in the saved capture, confirming the diagnostic process ran in Profile mode. Package check returned `versionName=1.0.3`.
- A diagnostics helper already exists at `lib/features/player/player_diagnostics.dart`; no instrumentation was added. The helper does not emit `buffering=true` values, and the first-frame and decoder-snapshot helpers have no call sites.
- Decoder drops, actual run-bounded first-frame latency, and explicit buffering transitions: NOT MEASURED.

| Codec | Source exercised | Hardware/software decoder result |
|---|---|---|
| H.264 | One Piece source supplied for this session | NOT MEASURED; the saved decoder-path line did not identify a codec. |
| AV1 | No AV1 source used (only the supplied H.264 source was allowed) | NOT MEASURED. |

## Run 1 — exploratory sample only

**Classification: EXPLORATORY SAMPLE — MANUAL-ESTIMATE; invalid for the official baseline.** The user reported 171 seeds and estimated 15–30 visible stalls per minute. First-frame elapsed time and the buffering-spinner yes/no/count were left unknown. These are user observations, not verified measurements.

The filtered capture is `evidence/ST03_startup_runs.txt`. It contains pre-run logcat ring-buffer entries; the pre-run checkpoint was line 115. Post-checkpoint diagnostics span `09:30:17.915`–`09:48:36.889`, with no tap/start/stop markers. The exact tap timestamp and which parts of that continuous window belong to playback cannot be established. The window therefore does not qualify as a bounded Run 1 measurement. Two URL-like fragments were replaced with `[REDACTED_URL]`; the file contains no URL, info hash, token, or key.

The one-time `perf_log_analyst` pass found 110 post-checkpoint frame summaries reporting 49,689 frames, 5,597 build-over-budget frames, and 107 raster-over-budget frames. These totals describe the unbounded capture window only and must not be attributed to Run 1. There were no explicit `buffering=true` records; the true-transition count is unavailable. `buffer` callback updates were excluded. No decoder-drop snapshot was captured.

Run 1 does not count toward the official three runs. Runs 2 and 3 were not performed, per the user's instruction. No official median, min/max, seeder-series, first-frame latency, buffering-event rate, or decoder-drop rate can be reported.

## Required scenarios and status

All cells have 0 runs; therefore median and min/max are unavailable. A physical device is present; these cells are NOT MEASURED due to missing valid playback input and profile diagnostics, not because the device is absent.

| Scenario | Runs | Time-to-first-frame | Steady-state / metric | Status and reason |
|---|---:|---|---|---|
| Startup / first rendered frame | 0 official (1 exploratory) | NOT MEASURED | NOT MEASURED | Exploratory Run 1 has no verified tap/first-frame timing and is excluded. |
| 10-minute continuous playback, controls hidden | 0 official | NOT MEASURED | NOT MEASURED | No bounded official run or separate 10-minute scenario. |
| Repeated controls show/hide | 0 official | NOT MEASURED | NOT MEASURED | Not performed. |
| Open/close each settings panel | 0 official | NOT MEASURED | NOT MEASURED | Not performed. |
| 10+ seeks | 0 official | NOT MEASURED | NOT MEASURED | Not performed. |
| Subtitle track switch | 0 official | NOT MEASURED | NOT MEASURED | Arabic was requested, but no valid switch scenario was completed. |
| Audio track switch | 0 official | NOT MEASURED | NOT MEASURED | Two tracks were identified in the source description; switching was not measured. |
| Playback speed change | 0 official | NOT MEASURED | NOT MEASURED | Not performed. |
| Source switch | 0 official | NOT MEASURED | NOT MEASURED | Only one source was allowed for this session. |
| Background / foreground | 0 official | NOT MEASURED | NOT MEASURED | Not performed. |
| Rotation | 0 official | NOT MEASURED | NOT MEASURED | Not performed. |
| Event/rebuild frequency | 0 official | NOT MEASURED | NOT MEASURED | Exploratory diagnostics lack run boundaries and are not attributable. |
| Memory (PSS/native/graphics) and CPU trend | 0 official | NOT MEASURED | NOT MEASURED | No time series or forced-GC sample. |
| Decoder / video frame drops | 0 official | NOT MEASURED | NOT MEASURED | No decoder-drop snapshot was captured. |

No official-valid measurement logs exist. The saved filtered capture is exploratory only; `evidence/PHYSICAL_DEVICE_PREFLIGHT.md` remains an environmental snapshot. No official median, min, or max is reported.

## Station status and deferred work

Station 03 is **INCOMPLETE for the official baseline** and was stopped here at the user's direction. Do not treat this exploratory sample as a baseline or start later stations from it. If the user resumes baseline work, establish run start/stop timestamps, capture at least three Profile-mode repetitions per scenario, record only explicit buffering-state transitions, and keep Flutter UI frame timings separate from decoder drops. No production code was changed in this Station 03 session.
