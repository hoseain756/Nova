# Station 11 — Player controls and gestures

- Status: COMPLETE — Station 11 functional checks passed on the physical Android phone for the current working-tree candidate
- Verification status: working-tree candidate VERIFIED-ON-DEVICE for the user-reported Core and legacy playback/gesture checklists on one Android phone and one user-selected source per route; scoped committed tree BUILD-VERIFIED by full analysis and tests on the exact staged snapshot; performance NOT MEASURED
- Checklist: 8/8 tasks complete
- Evidence:

- [x] Implement NOVA-consistent control visibility and priority model.
- [x] Implement seek/volume/brightness gesture behavior with settings modal interaction rules.
- [x] Constrain high-frequency rebuilds to control state; keep video surface stable.
- [x] Add tests for gesture boundaries, orientation and RTL/LTR behavior.
- [x] Verify accessible targets, text scaling, safe areas and phone/tablet layouts in widget tests/static layout checks.
- [x] Run LKG validations on physical device.
- [x] Record measured UI event/rebuild behavior where available.
- [x] Commit only Station 11 paths/docs; verify the staged diff excludes pre-existing exit fixes and unrelated work before committing.

## Findings and evidence — 2026-10-22

Gate C was explicitly approved for entry to this station. The existing horizontal seek, vertical brightness/volume, double tap and pinch controls were retained. Both routes now gate those video gestures while a panel/sheet, leave dialog, lock or temporary speed hold is active, so modal work cannot accidentally seek or alter device controls. The long press accepts only ready, playing video; it hides the chrome, Up-Next/skip actions and gesture hints, requests 2×, and restores the exact previous rate and prior chrome visibility on release/cancel. Lock, panel entry, background and source replacement end or invalidate the hold. The shared `TemporarySpeedHold` waits for an in-flight 2× command before restoring and checks source ownership so a stale release cannot change the next source. The existing exit-fix hunks in both player pages were preserved unchanged.

Seek and brightness/volume HUD updates now publish through route-local `ValueNotifier`s instead of rebuilding the page per update. The legacy page uses the existing `PlaybackSessionSurface` cache as the Core page already does, keeping its video child stable until engine identity or fit changes. Pinch zoom still rebuilds its transform as needed. This is structural UI isolation, not measured frame pacing or decoder improvement. The locked control's touch box is 48×48 dp in both routes. No new theme colors, localization strings, storage keys, dependencies or native configuration.

Changed Station 11 paths: `lib/features/player/temporary_speed_hold.dart`, `video_player_page.dart`, `core_video_player_page.dart`, `test/temporary_speed_hold_test.dart`, and this station's required plan/project-map documentation. The source files already had uncommitted confirmed-exit fixes on entry; those remain in the working tree and must not be swept into a Station 11 commit.

Verification performed: `flutter pub get` PASS; final full `flutter analyze --no-pub` PASS (no issues, 29s); final full `flutter test --no-pub --reporter compact` PASS **539/539** (1m32s); focused gesture/hold/surface run PASS **25/25**; `dart format --output=none --set-exit-if-changed` PASS for four production/test Dart paths; scoped `git diff --check` PASS. `flutter build apk --profile --no-pub --dart-define=NOVA_PLAYER_CORE=true` PASS (73.4s). That Core APK was 189,047,439 bytes, SHA-256 `A096E3A8576DFA2FE4258C6E824135B07EA1DF0E0A430D9378614AE6F023C2AD`; `adb -s RF8NA2NNVNY install -r` returned `Success`. The user then opened NOVA, manually selected a source and answered **«نجح الفحص»** to a checklist covering visible/audio playback, hold-to-2×, exact speed/chrome restoration, lock, panel, exit and return. This is a user-reported one-device/one-source functional check, not captured frame metrics. A second `flutter build apk --profile --no-pub` for the default legacy route PASS (111.9s); its APK was 172,848,455 bytes, SHA-256 `5482E6BC85021C0F28EF7D25C2FAA2AAC44186DFD968C5D55BB25633BB3D1194`, and `adb install -r` returned `Success`. The user then answered **«نجح الفحص»** to the legacy manual playback/temporary-speed/lock/exit checklist. New tests cover rate-command ordering, exact-rate restoration, source invalidation and long-press competition with scale recognition in Arabic/English and dark/light. Existing `gesture_math_test.dart` covers axis scaling/clamps; `playback_rendering_contract_test.dart` covers 844×390 and 1180×820 in RTL/LTR and both themes with **1** surface child build across 20 progress/panel parent updates, then **1** additional child build on deliberate fit change. Existing player settings layout tests exercise 320px/200% text. These widget results do not measure native controller recreations or live UI event rate. Physical jank, decoder drops, memory and CPU remain **NOT MEASURED**.

## Blockers / unknowns

Physical Android device `RF8NA2NNVNY` (SM-A217F, Android 12) is visible in `adb`. Core Profile was installed and the user answered **«نجح الفحص»** after opening NOVA, selecting a source and trying playback, temporary 2×, release, lock, panel, exit and return. The default legacy Profile APK was then installed and the user answered **«نجح الفحص»** after opening NOVA, selecting a source and trying visible/audio playback, temporary 2×, release, lock and exit. These are user-reported functional results on one phone, not an agent-run interaction trace or measurements of jank, CPU, memory or decoder drops. iOS remains NOT-VERIFIED; there is no Mac/Codemagic result. No app/source launch was performed by the agent.

## Commit / LKG

Station 11 commits are `2931cb6` (`player: station 11 controls and gestures`) and corrective page-integration commit `ebb825e` (`fix(player): correct station 11 page integration`). The exact corrected staged tree passed `flutter analyze --no-pub` and `flutter test --no-pub --reporter compact` (539/539); both player routes were installed and user-checked from the working tree. The pre-existing confirmed-exit fixes on the same page files and all unrelated local changes remain uncommitted and untouched, so the commit tree was not installed on-device and is not promoted to production LKG. The recorded production LKG/safety tag remains `c9257c0`. No push/tag/release; no performance or iOS claim.

## Session 1 scope
Historical note from the initial planning checkpoint; superseded by the active Station 11 continuation above.
