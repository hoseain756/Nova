# Station 03 — NOVA performance baseline

- Status: INCOMPLETE — official baseline not captured (physical device is present; one exploratory sample only)
- Verification status: NOT VERIFIED for official baseline; Profile marker observed in the saved capture
- Checklist: 5/12 tasks complete
- Evidence: `evidence/PHYSICAL_DEVICE_PREFLIGHT.md`, `evidence/ST03_startup_runs.txt`, and `BASELINE.md`.

- [ ] Build/install the exact legacy player in Profile mode; the already-installed Profile build was reused as instructed, and rebuilding/reinstalling was prohibited.
- [x] Recorded available device preflight conditions; run-time network, brightness, charging/cooldown were not fully recorded for the exploratory sample.
- [ ] Measure at least three runs per scenario with time-to-first-frame and steady-state separated.
- [ ] Capture UI frame timings and separate engine decoder/drop counters when available.
- [ ] Measure startup, continuous playback, controls show/hide, settings windows, seeks, subtitle/audio/speed/source switches.
- [ ] Measure background/foreground and rotation behavior on the same device where safe.
- [ ] Capture event/rebuild frequency and PSS/native/graphics memory and CPU trend over time.
- [x] Store the official-baseline boundary and unavailable metrics in `BASELINE.md`; retain only the sanitized exploratory capture, with no fabricated values.
- [x] Create `BASELINE.md` and report metrics unavailable from the actual engine.
- [x] No device settings were altered and no emulator was started.
- [x] Confirmed the already-installed Profile build from `NOVA_DIAG enabled mode=profile`; no rebuild or reinstall.
- [x] Saved the filtered exploratory capture and ran `perf_log_analyst` once; results are not a valid official baseline.

## Findings and evidence

Run 1 was accepted as an exploratory manual estimate only: 171 seeds and an estimated 15–30 visible stalls/minute; first-frame time and spinner count are unknown. The saved log window has no tap/start/stop markers and cannot be aligned to the run. No explicit `buffering=true` state was logged; callback updates were excluded. See `BASELINE.md` for the official-baseline limitations and aggregate capture analysis.

## Blockers / unknowns

The handset is physically connected, so this is INCOMPLETE, not device-BLOCKED. By user instruction, runs 2 and 3 and the remaining scenarios were not performed. The capture has no exact user tap time or first-frame measurement; the current diagnostics do not expose explicit buffering=true states or decoder-drop snapshots. AV1 is NOT MEASURED because only the H.264 source was allowed. The official baseline remains mandatory before later implementation stations.

## Commit / LKG

Current code HEAD before this documentation checkpoint: `1676671` (`player: baseline instrumentation`). No production code or instrumentation change occurred in this Station 03 session. Last-known-good production commit remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`. Station 03 is INCOMPLETE for the official baseline; do not start Station 04 or later.
