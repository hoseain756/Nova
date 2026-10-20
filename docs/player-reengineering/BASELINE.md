# NOVA legacy player performance baseline

## Status

**NOT MEASURED.** This file is the required baseline record, but contains no playback performance values. A physical USB device is available; no performance run or profile build/install was performed in this documentation-only session.

## Device and protocol facts available

- Device: `RF8NA2NNVNY`, Samsung SM-A217F, Android 12/API 31, Exynos 850, arm64-v8a; device preflight in [`evidence/PHYSICAL_DEVICE_PREFLIGHT.md`](evidence/PHYSICAL_DEVICE_PREFLIGHT.md).
- Display: only a 720×1600, 60.000004 Hz supported mode was listed at preflight; nominal frame budget is 16.67 ms. This is a budget reference, not a measured frame time.
- Preflight snapshot reported battery 35%, USB powered, low-power mode off, thermal status 0, developer options off, and animation scales 1. These values were not monitored during playback runs.
- Legacy production code baseline: `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; this mission made no production player changes.
- No stream from the user or NOVA was available. No stream URL was opened on the device. No build, install, or playback run occurred.
- Flutter debug/profile frame-timing helper location: **none**. Adding the Section 0.9 diagnostics helper requires code changes; user constrained this session to investigation, documentation, measurements, and plan files only. It is not safe to infer event frequency or jank from source alone.
- Active decoder, decoder drop counters, actual rendered-frame counters, first-frame latency, Flutter frame timings, and source buffering statistics: NOT MEASURED.

## Required scenarios and status

All cells have 0 runs; therefore median and min/max are unavailable. A physical device is present; these cells are NOT MEASURED due to missing valid playback input and profile diagnostics, not because the device is absent.

| Scenario | Runs | Time-to-first-frame | Steady-state / metric | Status and reason |
|---|---:|---|---|---|
| Startup / first rendered frame | 0 | NOT MEASURED | NOT MEASURED | No stream/run. |
| 10-minute continuous playback, controls hidden | 0 | NOT MEASURED | NOT MEASURED | No stream/run; no frame timing or decoder-drop instrumentation. |
| Repeated controls show/hide | 0 | NOT MEASURED | NOT MEASURED | No stream/run. |
| Open/close each settings panel | 0 | NOT MEASURED | NOT MEASURED | No playback session/run. |
| 10+ seeks | 0 | NOT MEASURED | NOT MEASURED | No stream/run. |
| Subtitle track switch | 0 | NOT MEASURED | NOT MEASURED | No stream with multiple tracks. |
| Audio track switch | 0 | NOT MEASURED | NOT MEASURED | No stream with multiple tracks. |
| Playback speed change | 0 | NOT MEASURED | NOT MEASURED | No stream/run. |
| Source switch | 0 | NOT MEASURED | NOT MEASURED | No two sources configured. |
| Background / foreground | 0 | NOT MEASURED | NOT MEASURED | No active playback session. |
| Rotation | 0 | NOT MEASURED | NOT MEASURED | No active playback session. |
| Event/rebuild frequency | 0 | NOT MEASURED | NOT MEASURED | Source audit only; runtime cadence requires instrumentation. |
| Memory (PSS/native/graphics) and CPU trend | 0 | NOT MEASURED | NOT MEASURED | No playback; no time series or forced-GC sample. |
| Decoder / video frame drops | 0 | NOT MEASURED | NOT MEASURED | Engine runtime counters not obtained. |

No raw measurement logs exist because no measurement run took place. `evidence/PHYSICAL_DEVICE_PREFLIGHT.md` is an environmental snapshot, not baseline performance evidence. No median, min, max, or estimate is reported.

## Exact next step

Before any production player change: provide or configure a NOVA-playable test stream (or authorize/use a public sample allowed by Section 0.7), and in an implementation-enabled session add the debug/profile-only diagnostics helper required by Section 0.9. Then build/install the exact legacy revision on `RF8NA2NNVNY`, establish the specified charging/cooldown/network/brightness conditions, run at least three Profile-mode repetitions per scenario, capture Flutter frame timings separately from decoder drops, and append real raw evidence here. Do not treat this baseline as complete or let unmeasured hypotheses become confirmed causes.
