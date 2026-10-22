# Gate C — playback core candidate, approved for Station 11

## Decision — APPROVED, 2026-10-22

The user replied **«نعم انتقل وأكمل إلى المحطة التالية»** to the explicit Gate C decision request. This approves proceeding to Station 11 on the recorded one-source functional evidence. It does not convert unmeasured performance into a gain, approve a release or LKG promotion, or approve Gates D/E. The earlier HOLD language below is historical. The legacy player remains the default and the opt-in Core remains selectable.

## Latest phone report and seek follow-up — 2026-10-22

The user confirmed the seek-fix build supports both dragging and tapping the timeline with continuing video/audio, and confirmed the requested direction on the updated phone build: Arabic starts on the physical left; English starts on the right. The shared progress row sets this from the app-language flag. Full `flutter pub get`, full analysis (no issues), full test suite (532 PASS), Profile APK build and ADB install/launch all PASS. The user tested playback and confirmed the direction is correct on `RF8NA2NNVNY`. Artifact SHA-256: `0926A76A36DE69A1E8D4B3AD68CDB96C5FF51FD10CF06A2504E9E8C1E2434D57`. Gate C awaits the user's explicit decision to approve this functional evidence and proceed; performance remains NOT MEASURED under the accepted waiver.

Prior phone report: the surface-adjusted opt-in Profile build showed smooth video on the Samsung SM-A217F, but its progress bar could not be controlled. The Core session had cached a paused-open `seekable` result; a bounded post-duration recheck and startup-resume wait require positive native seek capability without permanently disabling a late-seekable source. Focused tests PASS 36/36, scoped analysis PASS, opt-in Profile APK build and ADB install PASS. Installed test artifact SHA-256: `72E1706347A9029A1B13B7D3CF77ACDA832B7A486A549FB88B050D7FEFB0537F`. The user's successful drag/tap follow-up is recorded above. The user's additional window, subtitle, 2× hold, settings and episodes requests are recorded in `10_STATION.md` for subsequent UI stations after this gate. Performance remains NOT MEASURED under the Station-10 waiver.

**AWAITING USER GATE C DECISION.** One user-selected Android source is confirmed for visible video, smooth playback, drag/tap seeking and the requested language direction. Broader source/codec/runtime behavior and performance remain NOT-VERIFIED / NOT MEASURED.

## User decisions already recorded

- Gate B: retain locked media_kit, structural decoupling, personal use; native artifact licensing still unclear, no distribution clearance.
- Station 10 baseline waiver: **`waive baseline للمحطة 10`**. Every BEFORE remains NOT MEASURED; no relative improvement claim.
- Core contract approval: **`تم الاعتماد`**, in reply to accepting C10-1–C10-5 and continuing the remaining Station 10 work.

## Implemented candidate

- A once-per-route `PlaybackEntryPage` selects the independent legacy page by default, or the core with `NOVA_PLAYER_CORE=true`. All five external player launch routes preserve the existing arguments. Core episode/source navigation remains core and awaits retirement. No live engine toggle.
- Route-local session owns one backend, ordered commands, typed applied/cancelled/unsupported/failed results, generation checks and change-only transport projections. Exact progress is separate from the 100 ms display projection. Feature windows evaluate exact values and only changed visible predicates/countdown reach the page.
- Stable surface child retained through progress, panels and transport overlays; fit/engine identity changes are explicit boundaries. Existing subtitle renderer/style, chrome, preferences, gestures and feature semantics reused. Core UI is independently composed from the current NOVA page to keep legacy selectable; consolidation/removal waits for later acceptance/Gate E.
- Source transitions capture exact position/play intent/rate and semantic audio/subtitle selection, preserve explicit subtitle-off/external selection, open paused, restore supported intent and seek, then play only if current. Unknown/nonseekable capability and unavailable requested tracks return unsupported/paused rather than claim continuity. No blind automatic software-decoder recreation or alternate-source selection. Only positively asserted safe operation failures can retry once per operation/source attempt; the native adapter currently asserts none.
- Close is idempotent and awaited; it invalidates old ingress, cancels timers/listeners, drains native work, attempts an immutable final checkpoint/capture with bounded storage wait, then retires native before releasing the torrent. Failure/hang in native retirement blocks competing engine creation. An uncancellable old resolver drains before new native acquisition.
- Existing `TorrentService.prepare` deactivates the active torrent. Core therefore retires native before invoking it when replacing its torrent. Once this teardown happens, cancellation cannot pretend the old source survived; retry explicitly resolves/prepares it again.
- Shared checkpoint writer coalesces only pending periodic snapshots belonging to the same owner/content; forced saves and other content remain ordered. Existing `AppState.recordPlayback`, provider enablement, keys, completion thresholds, resume-choice suppression and last-120000-ms frame/Continue Watching semantics remain. Frames are serialized through the same writer but remain in existing local-only storage.

## Verification and artifact

Initial core-focused run: 27 tests passed. Expanded session run: 18 tests passed, including resolver draining and torrent lease ordering. An earlier full suite passed 515 tests before the last small core guards/additional tests. Full final suite, analysis, build and artifact checksum are recorded in the final validation addendum below after completion. No test constructs the native media_kit backend; fake-backend and widget tests do not establish native runtime behavior.

Device discovery: physical Samsung `RF8NA2NNVNY` (`SM_A217F`) in `device` state on 2026-10-22. **Discovery only.** No install, app launch, source selection or playback was performed. Prior user-controlled playback confirmation remains required. iOS NOT-VERIFIED: no macOS/Xcode/Codemagic build/device.

Candidate build command: `flutter build apk --debug --no-pub --dart-define=NOVA_PLAYER_CORE=true`. This is a local functional-test APK, not an update/release/distribution artifact. Debug cannot supply performance evidence. Source default remains legacy; compile without the define for the original path. Existing native signing/build configuration was not edited.

Build provenance: the APK and whole-repository checks use the shared working tree, which already contains unrelated settings/native-build/docs changes. Those files are preserved and excluded from the scoped player checkpoint. The APK is therefore not claimed to be reproducible from that commit alone, nor a clean release/LKG artifact.

## Measured numbers and remaining checks

| Area | Evidence / status |
|---|---|
| Ordered commands, cancellation, close barriers, write ordering | Fake-backend/unit tests; BUILD-VERIFIED when final build passes |
| Position-only session notifications | Unit flood test: 200 exact updates, 0 transport notifications; not device UI jank evidence |
| Surface retention | Host-widget tests, LTR/RTL, light/dark, 844×390 and 1180×820; 1 initial child build across 20 progress/panel parent rebuilds, 1 deliberate extra build on fit change; not native renderer/decoder evidence |
| Native controller recreations during controls/panels/rotation | NOT MEASURED |
| UI jank, decoder drops, startup/first frame, seek latency | NOT MEASURED |
| CPU, memory, 30-minute playback, leaks/ANR/A-V drift | NOT MEASURED |
| Real resume/skip/next/source/track flows | NOT-VERIFIED on device |
| iOS behavior/build | NOT-VERIFIED |

## Risks / limits for review

- The exact native event order, `seekable` property, track availability after paused open, surface retirement/mounting and plugin lifecycle require real Android playback. Backend diagnostic categories are sanitized hints, not proven causes. A duration/ready signal is not first rendered frame.
- Requested semantic tracks that are not yet available fail conservatively; no assumption that IDs survive a source switch. Delayed native track discovery still needs device coverage.
- Resolver cancellation drains work that cannot be cancelled and disposes unused prepared candidates. Torrent preparation elsewhere in the existing app remains outside the session API; rapid exit plus a separate external preparation still needs device/account testing. No shared TorrentService behavior was changed.
- Tests cover the session and surface host, not a native full-core-page playback run. Full production integration, audio focus/lockscreen, lifecycle, source-account/network behavior, frame retention and enlarged-text controls require device acceptance.
- Native close failures intentionally block another engine; a native hang can therefore require app restart. Storage failure is reported separately and does not hold native cleanup indefinitely; a permanently stalled writer still blocks later writes to preserve ordering.
- No decoder/cache tuning, native dependency upgrade, schema migration, release/version change, signing change, distribution, or legacy removal. No new performance/LKG claim.

## Decision requested and recommended next step

**Recommended: HOLD at Gate C and perform the user's physical-device functional review.** Do not advance to Station 11 simply from a successful build/test suite. The code checkpoint is a candidate, not acceptance that playback is smooth.

On the provided core APK, review: first open/play/pause; controls shown/hidden/locked; rapid seek and resume/decline/start-over; subtitles/audio/rate; same-episode source change with position/pause preserved; manual retry; source-picker cancellation; next/previous episode through existing sources; background/foreground and rotate; rapid exit/reopen; five-second/pause/exit saves and local pause frame. Observe loading/error/panels and Arabic/English on the physical phone; tablet runtime remains unverified unless a tablet is connected. Debug is functional only; later performance work requires profile/release and the recorded measurement protocol.

Record the user's exact test result and Gate C decision here. If the user wants the agent to observe/capture the device run, wait for explicit playback confirmation before starting or selecting a source. A plain continuation approves only the recommended HOLD-and-test step, not fabricated runtime acceptance. Fix any reported regression before calling this station complete or promoting LKG.

## Final validation / checkpoint addendum

One independent read-only Gate C review returned **FAIL** on four integration races. The primary corrected startup settings ordering, late unsupported cancellation, explicit retiring-lease ownership and source-handoff play-intent/lifecycle revalidation. All four have regressions; focused session tests PASS 24/24. Original verdict and primary disposition are retained in `GATE_C_REVIEWER.md`; no second reviewer invocation and no independent PASS claimed. Final post-correction full checks/build all PASS as recorded below. Gate C remains HOLD; no human acceptance or LKG promotion.


### Final post-correction validation — 2026-10-22

| Check | Actual result |
|---|---|
| `flutter test --no-pub` | PASS, all 525 tests (1m56s final run); includes 24 session tests and all existing regression suites |
| `flutter analyze --no-pub` | PASS, no issues (66.2 s final run) |
| `flutter build apk --debug --no-pub --dart-define=NOVA_PLAYER_CORE=true` | PASS, 158.4 s final run; existing Gradle/AGP/Kotlin support warnings, no native configuration changes |
| Formatting / `git diff --check` | PASS; scoped player/route/test formatting, no whitespace errors |
| Device | Discovery only RF8NA2NNVNY / SM_A217F; no installation, launch or playback |

Artifact: `C:\Users\hosea\projects\app\Nova\build\app\outputs\flutter-apk\nova-station10-core-debug.apk`, **284,614,103 bytes**, SHA-256 **`5E0B2DEC2FB94691EAFDBF6F8AE2254C18859B5C35C577D2ADE6DA7F9AD1EABD`**. Core define is enabled in this APK. Kept a stable named copy of the final build; earlier candidate APK checksums are historical.

Android core candidate BUILD-VERIFIED; Android runtime NOT-VERIFIED. iOS NOT-VERIFIED. All before/after performance NOT MEASURED. The APK includes the preserved shared working-tree settings/native build changes as described under provenance. Local testing only; no distribution/release/update publication.

Scoped checkpoint subject: `feat(player): add opt-in serialized playback core`, on `feature/player-reengineering`. Stage only the 25 player/route/localization/test paths and 8 required documentation files; exclude all unrelated native/settings/brand/image/skill/root-prompt changes. AGENTS/master/Station10/milestone index versions contain only this continuation's documentation hunks, leaving unrelated historical/investigation changes in the working tree. No push, new tag, legacy removal or LKG promotion. Gate C remains HOLD for the user; Station 10 original checklist 7/10, with device/LKG/real playback acceptance still pending. Stop here, no Station 11.
