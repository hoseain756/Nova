# Station 15 — Next episode system

- Status: IMPLEMENTED — STATIC-ONLY; device and LKG gates remain open
- Verification status: 5/7 checklist items complete; no physical-device acceptance claimed
- Evidence: focused Flutter tests passed for transition policy and Up Next layout/actions; targeted `flutter analyze` reported no issues.

## Checklist

- [x] Centralize next-episode availability, countdown and cancellation rules.
- [x] Coordinate completion threshold with resume cleanup.
- [x] Prevent conflict with source picker, errors and settings overlays.
- [x] Add state-transition tests for pause, manual seek and episode changes.
- [ ] Verify episode transition and playback on an actual available source.
- [x] Record device/account gaps honestly.
- [ ] Run LKG checks and commit only Station 15 paths/docs.

## Findings and evidence

- `lib/features/player/segments/next_episode_policy.dart` centralizes Up Next visibility, countdown and data-driven auto-advance decisions for Core and Legacy.
- Auto-advance requires a short forward playback crossing at the data-provided deadline, a ready and playing route, resolved resume, and a valid next episode; seek guards and panel/lock/closing/error/dismissal/completion checks suppress conflicting transitions.
- The normal Up Next action remains a source-picker flow. The existing autoplay preference controls only data-provided automatic transition.
- Tests: `test/next_episode_policy_test.dart`, `test/playback_entry_page_test.dart`, and `test/player_up_next_placement_test.dart` passed in the focused 51-test run.
- Core/Legacy selection is persisted in `playerImplementation`; `NOVA_PLAYER_CORE=false` continues to force Legacy.
- Physical source transition and playback were not checked in this continuation. No LKG commit was created.

## Blockers / unknowns

- Actual stream availability, provider behavior and playback of the next episode remain unverified on device.

## Commit / LKG

Pending. No commit was created.
