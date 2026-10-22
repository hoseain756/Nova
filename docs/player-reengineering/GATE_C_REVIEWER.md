# Gate C — independent read-only review and primary disposition

2026-10-22. First/only Gate C `gate_reviewer` invocation; cumulative agents 8, maximum concurrent child agents this continuation 1. Primary implemented all code. Reviewer reported no file edits, test/build/device commands or agent spawning. Post-review Git status contained only expected primary-owned additions/edits plus preserved pre-existing work.

## Independent verdict — FAIL, HOLD before phone handoff

The reviewer identified four concrete blockers in the inspected candidate:

1. Core `_createEngine` submitted startup delay/subtitle-off commands before `open` advanced the source generation, cancelling the settings and potentially marking preferences applied too early.
2. `_command`'s `UnsupportedError` branch lacked the terminal/stale-generation guard; a late unsupported result could change closing to failed. `_restoreContinuity` also needed a final post-await generation check before assigning resume eligibility.
3. `replaceSource` reassigned the request and stopped the old torrent even if retirement of its still-reading native engine failed; request-only lease ownership could lose the old resource.
4. Core route handoff forwarded a stale `playing=true` continuity snapshot after async resolution, permitting autoplay despite a subsequent background/user pause.

Reviewer found the packet honest about baseline waiver, unverified runtime/performance, retained legacy default and absence of emulator/iOS claims. Final checks/checkpoint were pending during review. This verdict is retained; it has not been rewritten as a pass.

## Primary corrections and regression evidence

1. Added immutable `PlaybackStartupSettings` applied inside the new open transaction before initial play, with continuity taking precedence. Core only applies later preferred-track policy after session readiness. Removed pre-open settings submission. Regression: **startup settings apply inside open before first play**.
2. Late unsupported errors now return cancelled without mutating closing/current-generation state; final continuity eligibility assignment has a generation/closing guard. Regression: **late unsupported cannot undo terminal close**, including attempted retry while native close is blocked.
3. Session now holds an explicit identity set of all acquired/current/retiring leases. Old leases release only after successful old-native retirement; terminal cleanup releases held leases only after successful native close. Regression: **failed replacement retirement retains old and candidate leases**, checking zero stop callbacks and no second backend creation after close failure.
4. Added resolution-bound play-intent revision tokens. Core captures its handoff token synchronously after its own pause intent, revalidates it when building the next route, and suppresses stale saved play. New sessions inherit the current background state and reject play until foreground plus explicit intent. Regressions: **background during delayed resolution revokes handoff autoplay** and **a route born in background cannot autoplay saved intent**.

Focused session suite after corrections: **24/24 PASS**. Final whole-repository tests PASS 525/525, analysis PASS/no issues, opt-in Android debug build PASS. Exact final commands/artifact hash are recorded in `GATE_C_REVIEW.md`.

**Primary disposition:** the four code blockers are corrected and regression-tested; there was no second independent review (one invocation per gate). Gate C remains **HOLD**, human decision pending, runtime NOT-VERIFIED. These fixes do not establish native reliability, smoothness, performance improvement or LKG. Do not advance to Station 11 until the required user/device acceptance.
