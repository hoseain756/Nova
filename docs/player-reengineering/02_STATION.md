# Station 02 — Deep NOVA player audit

- Status: PLANNED
- Verification status: NOT-VERIFIED (station work not yet completed)
- Checklist: 0/12 tasks complete
- Evidence:

- [ ] Trace user source selection through source resolution, controller creation, decoder readiness, first rendered frame, and UI sync.
- [ ] Map player entry points, widgets, controllers, services, models, state providers, wrappers, and native bridges.
- [ ] Identify actual engine/package/backend, renderer and surface/texture path from dependencies and source.
- [ ] Trace create/open/play/pause/seek/background/foreground/orientation/source/episode/fullscreen/dispose lifecycle.
- [ ] Map position, duration, buffer, state, track and subtitle event rates and listeners.
- [ ] Measure static rebuild scope: video surface versus controls, providers, setState, timers and animation listeners.
- [ ] Inspect overlay order, clips, transformations, blur/backdrop filters and compositing around the surface.
- [ ] Audit codec fallback, buffering/cache, track selection and source/recovery behavior from implementation.
- [ ] Map resume, skip markers, completion thresholds and next-episode logic for duplication/ownership.
- [ ] Classify relevant components KEEP / REFACTOR / REPLACE / INVESTIGATE FURTHER with STATIC-ONLY status.
- [ ] Record disposal/subscription risks and likely hypotheses separately from measured causes.
- [ ] Use the authorized read-only nova_player_auditor once; run git status --short immediately after and verify no files changed.

## Findings and evidence

No findings recorded yet.

## Blockers / unknowns

None recorded yet.

## Commit / LKG

Pending station completion.
