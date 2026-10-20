# NOVA Project Plan

Updated: 20 October 2026
Purpose: a living plan for the NOVA Flutter redesign and its remaining acceptance work. Detailed design decisions and verification evidence are linked from [`README.md`](README.md).

## Major Milestone 1 — Audit, identity, and design foundation

**Status: Complete in source; documented.**

### Sub-milestones

- [x] Inventory the existing screens, integrations, storage contracts, and performance risks.
- [x] Apply the supplied NOVA brand assets and palette; define Light/Dark tokens and Arabic/Latin typography.
- [x] Document information architecture, page behavior, accessibility, localization, and motion.

## Major Milestone 2 — Product surfaces and navigation

**Status: Implemented and covered by automated regression tests.**

### Sub-milestones

- [x] Redesign Home, Details, discovery, library, downloads, Kids, settings, integrations, onboarding, and player surfaces.
- [x] Put cinematic Home/Details heroes behind opaque scrolling content; retain accessible hero controls.
- [x] Add episode list/grid switching and persisted Classic, Compact icons, and Mini navigation styles with a live preview.
- [x] Keep tablet side-rail navigation, direction-aware layouts, localized strings, and saved settings behavior.

## Major Milestone 3 — Functional completion and hardening

**Status: Source changes and automated checks complete.**

### Sub-milestones

- [x] Connect playback preferences to player behavior, including resume decisions, track selection, video fit, speed, and source density.
- [x] Add the localized, reduced-motion-aware NOVA launch animation and preserve startup error/retry flows.
- [x] Repair contrast, mixed-direction torrent metrics, touch targets, and settings restoration regressions.

## Major Milestone 4 — Automated verification and build evidence

**Status: Complete for the recorded build; repeat after source changes.**

### Sub-milestones

- [x] Full Flutter analysis reported no issues.
- [x] Full serial Flutter suite passed 434 tests before the anime-canvas fix; focused anime-canvas tests also pass in both themes.
- [x] Android arm64 Release APK built and inspected; evidence is in [`requirements-status.md`](requirements-status.md).
- [x] Headless splash and large-text Arabic player frames were reviewed.

## Major Milestone 5 — External acceptance still required

**Status: Pending real hardware, service credentials, or macOS/Xcode. Do not report these as complete until performed.**

### Sub-milestones

- [ ] On a physical Android phone and tablet, review core routes in Arabic/English, Light/Dark, portrait/landscape, and enlarged system text. Never use an emulator.
- [ ] Exercise real provider authorization, expired credentials, sync, disconnect, and recovery for each supported service.
- [ ] Verify native playback, resume, subtitles/audio selection, downloads, and Kids exit gates with real media on hardware.
- [ ] Profile warm/cold startup, scrolling, image memory, and frame timing on lower-end hardware; record measurements rather than claiming 60 fps without them.
- [ ] Build and smoke-test iOS on macOS/Xcode; test TalkBack/VoiceOver and hardware focus traversal.
- [ ] Update `requirements-status.md` and this plan with each result, including failures and remaining gaps.

## Working Rules

Preserve existing functionality and compatibility keys. Keep all user-facing copy in both ARB files and keep [`AGENTS.md`](../../AGENTS.md) aligned with the real repository map. Do not launch an emulator.

## Major Milestone 6 — Anime catalog canvas stability

**Status: Complete; focused automated and physical-phone verification passed.**

### Sub-milestones

- [x] Give the anime catalog an explicit canvas painted from the active theme surface through loading and content states.
- [x] Add dark- and light-theme widget regression coverage; both cases pass.
- [x] Analyze the changed page and test with no issues.
- [x] Rebuild and install on the physical Android phone; confirm the canvas remains stable while scrolling. No emulator.

## Major Milestone 7 — Poster artwork fills its display frame

**Status: Complete; analysis, focused widget tests, Release build, and physical-phone review passed.**

### Sub-milestones

- [x] Constrain animated network artwork to the full poster/feature frame so intrinsic image dimensions cannot leave unintended side gutters.
- [x] Apply a restrained 10% zoom to portrait posters used in the wide feature frame, while preserving the poster composition.
- [x] Verify the anime feature and poster rails on the physical Android phone; run focused card and theme tests and build the Release APK.

## Major Milestone 8 — Linked watch progress across Home, Details, and Anime

**Status: Final source, focused analysis, all 437 tests, and Android Release build passed in the moved project. Real linked-account and device acceptance remains pending.**

### Sub-milestones

- [x] Load active Trakt playback, AniList CURRENT entries, and MyAnimeList watching entries through the existing linked-service refresh path.
- [x] Reuse the Home continue-watching card design for linked progress, including provider attribution, available artwork, episode position, and a progress indicator; surface the same progress rail on Anime.
- [x] Merge linked episode progress with local history on Details, display the linked completion percentage, and add an accessible per-episode watched action that uses existing local history and tracker sync.
- [x] Run full Flutter analysis, all tests, and an arm64 Android Release build after implementation.
- [x] Re-run after final Home rail deduplication and Anime tracker filtering: analyzer passed, **437 tests passed**, and Release APK built (138,756,467 bytes; SHA-256 `C5C224249A5733CD6E5B79E73E6A8A6664184187E4E5B3FEC27D232EE46EBE46`).
- [ ] Verify resume and progress updates with real Trakt, AniList, and MyAnimeList accounts on the physical Android device; never launch an emulator.
- [ ] Record provider-specific failures, and verify the media-specific episode numbering against actual addon data.

### Known provider limits

- Trakt returns a paused percentage and episode identity, but not a frame from the source video. NOVA uses available poster/backdrop art with a progress bar; extracting an exact paused frame requires fetching and decoding the selected stream.
- AniList/MyAnimeList expose watched episode counts, not in-episode playback time. Their next episode can be opened, while exact position resumes only when the provider exposes a paused point.

## Major Milestone 9 — Local resume-frame previews and retention

**Status: Implementation, focused automated checks, analysis, and Android Release build passed; native frame capture still needs a physical-device check.**

- [x] Capture the decoded MediaKit frame when playback is paused, exits, or enters the background; also save the current playback position.
- [x] Compress the image off the UI thread and keep frame files and their metadata local to this device, separate from cloud-synced watch history.
- [x] Display a saved local frame on its Home Continue Watching card; linked-service rows continue using provider artwork.
- [x] Add a playback setting for 30, 20, 10, or 7 days, defaulting to 30 days, and remove expired images when the app starts or the setting changes.
- [x] Run snapshot storage/retention and settings tests, analyze changed files, and build Android Release.
- [ ] Validate capture timing, file cleanup, and card rendering on a physical Android device; never launch an emulator.

## Major Milestone 10 — Episode progress actions and multi-service rows

**Status: Implemented in the confirmed project path; 38 focused Flutter tests passed. Scoped Dart analysis of all changed source and test files found no issues; full Flutter analysis did not return a result. Provider/device acceptance remains pending.**

- [x] Keep the episode progress bar on its thumbnail and replace watched text with a direction-aware checkmark only.
- [x] Add a long-press sheet for downloading, marking the selected episode watched, and marking all earlier episodes through the selected one.
- [x] Store watched ranges in one local history update and batch sync to enabled Trakt/Simkl services; preserve existing AniList/MAL counter-sync switches.
- [x] Load Simkl paused playback sessions and show matching Trakt, Simkl, AniList, and MyAnimeList progress together in a single horizontal row on Home and Details.
- [x] Add Arabic/English copy and focused parser/long-press callback tests.
- [x] Run 38 focused Flutter unit/widget tests covering progress rails, RTL/LTR checkmarks, episode actions, provider parsers, settings, details, and snapshot retention.
- [ ] Complete static analysis and verify provider/device behavior on a physical device; never launch an emulator.

## Major Milestone 11 — Update discovery release 1.0.1+64

**Status: Source, focused regression checks, full analysis, and Android Release APK complete. Phone discovery check remains for the user.**

- [x] Advance the app metadata to 1.0.1+64 in `pubspec.yaml`, `lib/core/version.dart`, and `version.json`; keep `min_build` at 60 and retain the direct latest-release APK URL.
- [x] Cover the installed 1.0.0+63 case as an available optional update, and 1.0.1+64 as current.
- [x] Pass focused updater/version tests, full Flutter analysis, and build a Release APK whose Gradle metadata reports versionName 1.0.1 and versionCode 64.
- [x] Publish the updated manifest on `main` and create tag `v1.0.1` so installed clients can fetch the new metadata.
- [ ] Verify the update notice on the physical phone running 1.0.0+63. To download/install from the app, attach the matching-signed APK as `app-release.apk` to the GitHub v1.0.1 release; no APK asset is uploaded by this task.
- [ ] Never launch an emulator.