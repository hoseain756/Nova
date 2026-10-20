# Station 03 — NOVA performance baseline

- Status: NOT MEASURED (physical device is present; valid performance run not completed)
- Verification status: NOT MEASURED
- Checklist: 3/10 tasks complete
- Evidence: `evidence/PHYSICAL_DEVICE_PREFLIGHT.md`; detailed limits and cell-by-cell outcomes in `BASELINE.md`.

- [ ] Build/install the exact legacy player in Profile mode; not attempted because no stream is configured and the required diagnostic helper is prohibited by the documentation-only constraint.
- [x] Recorded available device preflight conditions; stream, network, brightness, charging/cooldown throughout runs are not recorded because no run occurred.
- [ ] Measure at least three runs per scenario with time-to-first-frame and steady-state separated.
- [ ] Capture UI frame timings and separate engine decoder/drop counters when available.
- [ ] Measure startup, continuous playback, controls show/hide, settings windows, seeks, subtitle/audio/speed/source switches.
- [ ] Measure background/foreground and rotation behavior on the same device where safe.
- [ ] Capture event/rebuild frequency and PSS/native/graphics memory and CPU trend over time.
- [x] Store the evidence boundary and unavailable metrics in `BASELINE.md`; no fabricated values or run logs were created.
- [x] Create `BASELINE.md` and report metrics unavailable from the actual engine.
- [x] No device settings were altered and no emulator was started.

## Findings and evidence

No valid playback performance measurements were collected. The only current device information is the static preflight snapshot in `evidence/PHYSICAL_DEVICE_PREFLIGHT.md`. See `BASELINE.md` for the full missing-input list and exact next-step prerequisite.

## Blockers / unknowns

The handset is physically connected, so the station is NOT MEASURED, not device-BLOCKED. No test stream is attached or configured for NOVA. Section 0.9 also requires Profile-mode Flutter timing diagnostics and an engine-side drop counter; user constraints limit this session to documentation/evidence and prohibit all production player changes, so no diagnostics helper can be added. The baseline remains mandatory before any future production player change.

## Commit / LKG

Station 03 documentation checkpoint: `8a56c5e` (`player: station 03 performance baseline`). No production code change occurred; last-known-good production commit remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`. Baseline capture is deferred until a valid stream and diagnostics path are available under an authorized implementation session.
