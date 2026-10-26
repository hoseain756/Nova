# Station 14 — Generalized skip segment system

- Status: IMPLEMENTED — STATIC-ONLY; device and LKG gates remain open
- Verification status: 6/8 checklist items complete; no physical-device acceptance claimed
- Evidence: focused Flutter tests passed for segment normalization, validation, overlap handling, seek re-arming, completion boundaries, and skip-pill layout; targeted `flutter analyze` reported no issues.

## Checklist

- [x] Define segment types and normalized boundaries for recap/intro/opening/outro/credits.
- [x] Handle seeking into/out of a segment and avoid repeated prompts.
- [x] Coordinate segment actions with resume/completion state.
- [x] Add tests for boundary, overlap and seeking cases.
- [ ] Verify NOVA UI, RTL and long episode behavior on a physical device where inputs permit.
- [x] Record unsupported sources and unavailable timing as unknown; do not infer markers.
- [ ] Run LKG checks and commit only Station 14 paths/docs.
- [x] Keep legacy implementation selectable.

## Findings and evidence

- `lib/features/player/segments/playback_segments.dart` normalizes five segment types, validates known duration boundaries, and resolves stream, episode, and external timing with defined precedence.
- `lib/features/player/segments/skip_segment.dart` coordinates active windows, overlap suppression, dismissal, seek re-arming and completion.
- Both Core and Legacy player routes share the segment model and `PlayerSkipSegmentPill`; completion-aware ending skips preserve the existing episode transition boundary.
- Public AniSkip, IntroDB and TheIntroDB timing plus exact-file chapters are integrated through `skip_timing_sources.dart`. AniSkip depends on exact AniZip episode identity. User keys are stored in platform secure storage and are not synced.
- Tests: `test/playback_segments_test.dart`, `test/player_skip_segment_pill_test.dart`, and `test/skip_timing_sources_test.dart` passed in the focused run (the run included 51 tests across six files).
- Physical marker acceptance and saved LKG/commit evidence are still missing. Unsupported provider responses and formats remain unverified.

## Blockers / unknowns

- No physical-device check was performed in this continuation; marker accuracy and playback behavior on device are not verified.
- Provider and media-format coverage beyond the focused tests is unknown.

## Commit / LKG

Pending. No commit was created.
