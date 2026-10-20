# NOVA Work Log

Updated: 20 October 2026. This log groups completed work by major milestone and sub-milestone. Detailed source findings and command evidence remain in the linked audit and acceptance documents.

## Major Milestone 1 — Audit, identity, and design system

### 1.1 Repository and experience audit

- Mapped existing screens, settings, integrations, compatibility keys, performance risks, and incomplete flows before changing the interface.
- Recorded baseline issues and preservation constraints in [`01-audit.md`](01-audit.md).

### 1.2 NOVA visual foundation

- Applied the supplied identity assets and palette, designed Light and Dark themes, and paired Poppins with IBM Plex Sans Arabic.
- Added shared tokens, components, localized copy, live language direction, and accessibility/motion rules in [`02-design-system.md`](02-design-system.md) and [`05-motion-accessibility.md`](05-motion-accessibility.md).

### 1.3 Product architecture

- Documented navigation, user flows, responsive layouts, and specifications for browsing, cinematic details, settings, and playback in [`03-information-architecture.md`](03-information-architecture.md) and the page specifications.

## Major Milestone 2 — Product-wide redesign

### 2.1 Home, Details, and discovery

- Rebuilt the Home rails and Details hierarchy around full-width cinematic artwork, opaque scrolling content, cast/production metadata, episodes, and stream selection.
- Put fixed hero layers beneath scrollable content and covered them with theme surfaces as the page scrolls.

### 2.2 Navigation, settings, and integrations

- Added adaptive navigation, the episode list/grid control, and persisted Classic, Compact icons, and Mini navigation options with a live preview.
- Reorganized settings and implemented add-on management and dedicated service settings while preserving existing identifiers and behavior.

### 2.3 Remaining feature surfaces

- Redesigned Kids, library/lists, search/catalog, downloads, anime/calendar, live TV, onboarding, auth, player controls, dialogs, and sheets using the shared NOVA system.
- Kept parental PIN gates, localized status/empty/error feedback, and Arabic/English RTL/LTR behavior in the applicable flows.

## Major Milestone 3 — Functional and accessibility hardening

### 3.1 Playback and preference behavior

- Connected resume choices, safe seeking, track-language preferences, custom speeds, fit, source details, and source density to their runtime controls.
- Protected watch history while resume decisions are pending and improved exit handling when progress cannot be saved.

### 3.2 Startup and visual quality

- Added the localized, one-shot NOVA splash animation, including reduced-motion behavior and compact-screen handling.
- Corrected tested Light-theme contrast pairs, mixed-direction torrent metrics, localized screen-reader labels, and compact player touch targets.

### 3.3 Performance safeguards

- Preserved lazy tab mounting, bounded caches/image decoding, cached catalog refresh, inactive animation muting, and reduced repeated blur work.
- No numerical frame-rate or low-end-device performance claim is made without a profile trace.

## Major Milestone 4 — Automated verification and build evidence

### 4.1 Automated checks

- The full serial Flutter suite passed **384 tests**; the focused final playback/direction/contrast checks passed **25 tests**.
- Full Flutter analysis reported **No issues found**. Localization key and placeholder parity checks pass for Arabic and English.

### 4.2 Artifact and visual review

- Built and inspected Android arm64 Release APK version `1.2.56+60`; its recorded SHA-256 is `AB7D52775551DE8A284704B0833D823360A9BBCFB52AC1E792087A513278B28A`.
- Reviewed headless splash frames and a composed Arabic player view at 200% text scale. These fixtures do not verify native playback or device rendering.
- Exact evidence and limits are in [`requirements-status.md`](requirements-status.md) and [`08-completion-audit.md`](08-completion-audit.md).

## Major Milestone 5 — Repository plan and contributor map (19 October 2026)

### 5.1 Ongoing plan

- Added [`10-project-plan.md`](10-project-plan.md) with completed milestones and pending physical-device, provider, iOS, performance, and accessibility acceptance.

### 5.2 Repository guidance

- Updated the root contributor guide with the current source, feature, shared-widget, asset, test, tool, and documentation map.
- Added its final rule requiring future contributors to update the guide whenever project structure or practices change.

### 5.3 History alignment

- Clarified that early migration milestones refer to the earlier Horse repository, while later entries refer to NOVA.
- Linked the plan and work log from the design index.

## Remaining Acceptance

Physical-device UI and playback, real provider credentials, iOS/Xcode, measured performance, and assistive-technology checks remain pending. Track them in [`requirements-status.md`](requirements-status.md) and the project plan. No emulator was launched.

## Milestone 6 — Anime catalog background stability

### 6.1 Canvas fix

- Added a theme-colored page canvas around the anime catalog so transparent scroll content cannot reveal the black platform window during loading, catalog updates, or scrolling.

### 6.2 Verification

- Dark and Light deferred-catalog widget tests pass; changed-file analysis reports no issues.
- Built and installed a new Release APK on the physical Android phone. Arabic/Dark canvas samples stayed at RGB `(20, 20, 23)` before and during scroll, with no fatal, Flutter, or overflow log entries. No emulator was launched.

## Milestone 7 — Poster image fit and restrained zoom

### 7.1 Image geometry

- Explicitly expanded animated poster images to the card frame and set their decode image dimensions to the available width/height, preventing intrinsic image size from leaving unused side gutters.
- In the anime feature, portrait poster artwork now receives a restrained 10% center zoom; landscape backdrops retain cover-fit with only a 3% crop.

### 7.2 Verification

- Focused widget tests for poster cards and dark/light anime canvas: **4 passed**. Targeted analysis: **No issues found**.
- Built and installed the updated Release APK on the physical phone; visually confirmed the featured poster fills more of its frame without escaping the rounded clip. No emulator was launched.

## Milestone 8 — Linked tracker watch progress (19 October 2026)

### 8.1 Shared provider data

- Home and Anime refresh Trakt paused playback, AniList CURRENT entries, and MyAnimeList watching entries through the concurrency-guarded linked-content cache.
- Linked progress uses the Continue Watching card style, with service attribution, episode identity/count, provider artwork, and a completion bar. Trakt artwork is filled from catalog metadata when possible.
- Provider rows stay separate from local playback history; local resume data is preserved.

### 8.2 Episode and detail progress

- Details combines local history with linked paused-episode and anime watched-count data so watched and in-progress episodes render in the season list.
- Episode cards expose a 48 dp localized watched action. It records local history and mirrors the updated episode number to reachable anime trackers through existing sync settings.
- Anime shows the tracker-backed progress rail. Details shows available linked completion and opens the next known episode, or seeks to Trakt's paused percentage when the episode runtime is available.

### 8.3 Verification and limits

- Focused tracker, episode-state, episode-view, and detail smoke tests: **22 passed**. The final serial Flutter suite after Home deduplication and Anime-provider filtering: **437 passed**. Final changed-source/test analysis: **No issues found** (84.4 seconds).
- Final Android arm64 Release build passed in **121 seconds**. APK size: **138,756,467 bytes**. SHA-256: `C5C224249A5733CD6E5B79E73E6A8A6664184187E4E5B3FEC27D232EE46EBE46`.
- Physical-device install was not performed because `adb.exe` is unavailable in this moved-project session. No emulator was launched. Real provider authorization and sync remain unverified.
- Provider history does not include source-video frames. Cards use poster/backdrop art plus progress; exact paused-frame capture requires selecting, fetching, and decoding a media source.

## Milestone 9 — Device-local resume-frame previews (19 October 2026)

- Added capture through MediaKit's decoded-frame screenshot API when the viewer pauses playback, leaves the player, or the app goes into the background. Frame files and metadata remain separate from cloud-synced watch history.
- Compressed captured JPEGs in an isolate to a maximum 960-pixel width, stored them under the app support directory, capped the local cache at 120 entries, and prune on startup or retention-setting changes.
- Home's local Continue Watching cards prefer the saved frame and fall back to catalog artwork. Linked Trakt/AniList/MyAnimeList rows remain unchanged.
- Added Playback retention choices of 30, 20, 10 days, and one week; the default is 30 days. Arabic and English ARBs include the title, explanation, and values.
- Verification: **9 focused tests passed** (storage/retention and settings), changed-file analysis reported **No issues found**, and Android Release built successfully in **146.3 seconds**. APK size: **142,361,459 bytes**; SHA-256: `039F89AFCF2435FF2D6AA884C2A03291E72175E8B99938EBC12FF60A29F870DB`. English/Arabic ARBs each contain 917 keys with exact key parity.
- Physical-device capture/render verification remains pending because `adb.exe` is unavailable in this session; no emulator was launched.

## Milestone 10 — Episode actions and unified linked progress (19 October 2026)

- Kept episode playback progress on the thumbnail and changed the watched overlay to a checkmark only, anchored at logical `start` (Arabic bottom-right, English bottom-left). Removed the extra inline watched button.
- Long-pressing an episode now opens a localized bottom sheet with download, mark-watched, and mark-through-this-episode actions. Mark-through records prior episodes in one local write and sends one grouped history update to Trakt/Simkl when enabled; AniList/MAL counters use the existing progress-sync preferences.
- Simkl paused sessions are now loaded from its playback endpoint and normalized into the same linked-progress list as Trakt, AniList, and MyAnimeList. Details displays matching provider progress in a single horizontal row; Home already renders all provider entries in one horizontal integration rail.
- Added Arabic/English labels and focused Simkl parsing plus episode long-press callback coverage.
- `dart analyze` reported **No issues found** for the changed source and test files, then exited nonzero because the sandbox denied its telemetry timestamp update. Flutter widget tests could not start: the Flutter SDK cache lockfile is inaccessible from the moved-project permissions. No emulator was launched; provider-account sync and device UI remain unverified.

## Confirmed-project reconciliation — 19 October 2026

- Audited C:\Users\hosea\projects\app\Nova against the earlier working copy before continuing. The destination had lost the local resume-frame store/retention setting, Simkl playback ingestion, episode long-press actions, multi-provider episode history syncing, matching ARB strings, tests, and milestone records.
- Restored those implementations and docs from the verified working copy; kept destination-specific Anime filtering, cached image sizing, Home catalog order, and seek-step setting parsing.
- Combined local and linked progress cards into one horizontal Home Continue Watching rail. Details presents matching linked provider cards in one horizontal row. The watched marker is now a semantic check only, positioned at logical start; progress stays over the episode image.
- Verification: focused Flutter test runs passed **38 tests** across episode_progress_overlay_test.dart, linked_progress_rail_test.dart, app_state_tracking_progress_test.dart, integration_cw_test.dart, episode_view_toggle_test.dart, detail_page_smoke_test.dart, nova_settings_test.dart, and resume_snapshot_store_test.dart. Dart formatting completed on the changed source and tests.
- Scoped dart analyze on all changed source files and tests completed with No issues found. Full flutter analyze --no-pub produced no final result after more than two minutes and was interrupted. No emulator was launched. Real linked-account synchronization and physical-device UI/playback remain unverified.

## Milestone 11 — In-app update delivery

The About page now checks the public root version.json using installed package version/build metadata. Android downloads the direct latest-release APK URL into the app cache, reports receive progress, removes a stale APK first, and opens Android's package installer through the app FileProvider. After app initialization, an asynchronous check routes unsupported builds into the locked About update screen. Its required-update dialog blocks barrier/back dismissal when the installed build is below min_build. iOS can use the manifest's ios_url; Android never launches a browser.

dio, path_provider, and url_launcher were already dependencies; open_filex and direct package_info_plus dependencies were added. The existing 1.2.56+60 app version seeded version.json because no prior manifest existed. The release workflow was absent from this checkout and was not changed; release signing files were absent, so the existing debug signing configuration stayed unchanged.

Validation: flutter test --no-pub test/app_update_service_test.dart passed 3 tests; flutter analyze --no-pub reported no issues; flutter build apk --release --no-pub built the 135.9 MB APK after Kotlin daemon connection retries. Manifest and FileProvider XML parsed. No emulator or device install was used.

## Milestone 12 — Release pipeline and local signing setup (20 October 2026)

- Added an Android GitHub Actions workflow to resolve dependencies, analyze, run tests, build a release APK on version tags or manual dispatch, and retain the APK as a workflow artifact.
- Added an optional Gradle upload-signing configuration and a blank android/key.properties.example; the ignored local android/key.properties references the provided keystore without storing passwords, alias, or key material.
- Preserved debug signing as the fallback when the local credentials are incomplete. CI runners do not receive the local keystore, so their APK artifact is debug-signed and the workflow does not publish GitHub Release assets.
- Added docs/nova/release-signing.md to document how to complete signing locally and why a CI artifact must not be used as an in-app update unless signed with the installed app's key. Validation: flutter analyze --no-pub reported no issues (104.4s); flutter build apk --release --no-pub succeeded (135.9 MB); PyYAML parsed the workflow. The full Flutter test suite and GitHub-hosted workflow were not rerun.

## Milestone 13 — Version 1.0.0 and updater error handling (20 October 2026)

- Set the user-facing version to 1.0.0 and advanced the Android build number to 63 so it remains installable over build 62. Updated version.json, the synchronous version constants, and Simkl API version headers; kept the existing minimum supported build and the direct GitHub APK URL.
- The updater now reports distinct localized causes for offline/timeout checks, unavailable release metadata or APK assets, malformed manifest or APK data, storage failures, Android install permission, missing package installer, incompatible or differently signed APKs, unavailable iOS links, and unsupported platforms. Manual no-update checks clearly say NOVA is already current; startup background checks stay silent on network errors.
- Reject non-APK download responses by checking the ZIP signature before launching the installer. Forced-update failures remain visible over the locked update screen so the user can close the message and retry.
- Verification passed: focused updater/version tests (5 tests), full Flutter test suite (451 tests), and flutter analyze --no-pub (no issues, 231.9s). flutter build apk --release --no-pub succeeded; the APK is 142,520,135 bytes with versionName 1.0.0 and versionCode 63. Local Android release signing credentials were complete and the configured keystore was used. No emulator was launched.

## Milestone 14 — Update discovery release 1.0.1+64 (20 October 2026)

- Bumped the user-facing version and Android build to **1.0.1+64** consistently in `pubspec.yaml`, `lib/core/version.dart`, and root `version.json`. Retained `min_build: 60`, the Arabic message, iOS fallback, and GitHub latest-release APK URL.
- Updated updater regression coverage: a device at **1.0.0+63** reports an optional update; **1.0.1+64** reports that it is current. Updated `AGENTS.md` release guidance to require synchronized version metadata and monotonic Android builds.
- Verification: **5 focused tests passed** (`app_update_service_test.dart`, `version_pin_test.dart`); `flutter analyze --no-pub` found no issues (114.6s); `flutter build apk --release --no-pub` succeeded. APK: **142,520,135 bytes**, SHA-256 `77B36508F708A53DD5FDFD40EF6CFC1FC294736CE39A627216C02B13F764CE58`; Gradle APK metadata reports versionName `1.0.1`, versionCode `64`.
- The update check fetches the public `main/version.json` with `Cache-Control: no-cache` and compares installed build numbers, so publishing this manifest makes build 63 eligible. The app download/install path still needs a signed `app-release.apk` attached to the v1.0.1 GitHub Release. Physical-phone check remains pending; no emulator was launched.