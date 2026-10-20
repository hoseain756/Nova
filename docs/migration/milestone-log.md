# NOVA and Flutter migration milestone log

Updated: 2026-10-19

## Scope and history

Milestones 1–14 are retained historical records from the earlier Horse monorepo migration; paths, branches, and remotes inside those entries describe that past workspace. Milestones 15 onward document the NOVA app in the current repository. For the concise project-focused chronology, see [`docs/nova/11-work-log.md`](../nova/11-work-log.md).

Completed milestones and their evidence are recorded here as work progresses.
The log records repository state separately from implementation and verification
results so existing local work remains attributable.

## Milestone 1 — Repository synchronization and baseline audit

Status: complete.

- Working repository: `C:/Users/hosea/OneDrive/Desktop/app/Horse`.
- Flutter delivery directory: `mobile_app/`.
- GitHub remote: `https://github.com/hoseain756/Horse.git`.
- Latest fetched mobile branch: `origin/flutter-mobile` at `72409ed` (`v1.0.0`).
- Local delivery branch: `flutter-mobile` at `9e604a6`, eight commits ahead of
  `origin/flutter-mobile`; the remote commit is an ancestor of the local head.
  No upstream mobile commits were missing, so no merge or reset was needed.
- Website source branch: `origin/main` at `428d4f4`; it is part of the same
  repository and is the source audited for the feature matrix.
- Existing user changes were preserved: modified Dart files, root `.vscode/`,
  root `docs/1.png`–`4.png`, and `mobile_app/docs/` references remain untouched.
- Environment: Flutter `3.44.0-0.2.pre` (beta), Dart `3.12.0`.
- Baseline `flutter analyze lib --no-pub`: passed, “No issues found” (126.5 s).
- Baseline `flutter build apk --release`: passed in 661.8 s; Flutter reported a
  56.0 MB `build/app/outputs/flutter-apk/app-release.apk`. Gradle logged Kotlin
  daemon connection retries and then completed the build. The existing Android
  setup also warns that its Kotlin Gradle Plugin integration will need migration
  in a future Flutter release. Artifact package/signature inspection is pending.

## Milestone 2 — Website feature inventory and reference review

Status: source inventory and screenshot review complete; parity gaps are listed.

- Website shell routes and cross-cutting actions are recorded in
  `feature-parity-matrix.md` against `origin/main`.
- The eight supplied screenshots are summarized in `design-reference.md`.
- Backend paths were traced to the existing `src/app/api/` handlers, including
  sync, TMDB, IPTV proxy and device pairing. Provider flows were not called
  with credentials during this work.
- The matrix separates code presence, automated test evidence and real device
  or service verification. Remaining parity gaps are enumerated at its end.

## Milestone 3 — Mobile migration and responsive navigation

Status: implementation pass complete; remaining parity gaps documented.

- Added native Discover, Movies, Shows and add-on Catalog browser surfaces;
  the phone bottom dock remains in place and tablet secondary navigation is
  collapsed by default.
- Added Live TV M3U playlists, group/search filters, optional XMLTV guide and
  channel playback. Playlist URLs are migrated from plaintext preferences to
  secure storage and excluded from backups/cloud sync because they may contain
  provider credentials.
- Added a native weekly schedule from tracked Cinemeta series episodes and the
  website's AniList airing query through `/api/anilist`; airing titles are
  resolved to playable Cinemeta IDs before opening details. The separate
  Cinemeta new-release discovery rail remains open.
- Added TMDB rating/recommendation rails with native title resolution, secure
  TMDB key validation/storage, custom lists with sync/share/import flows, and
  short-code device pairing for saved TMDB/Debrid keys.
- Added parser, custom-list, responsive-layout and tablet-navigation tests.
  Responsive testing found and fixed narrow-phone overflows in the poster grid,
  list creation dialog and library tab labels.
- Full Wrapped achievements, global keyboard/TV navigation, complete
  per-setting parity, and live service/device acceptance remain outstanding;
  see the parity matrix.

## Milestone 4 — Final analysis, tests, APK and platform report

Status: source checks, final APK verification and emulator launch smoke passed;
physical-device and iOS acceptance unavailable.

- Latest `flutter analyze lib --no-pub`: passed, “No issues found” (15.4 s).
- Latest `flutter test --reporter compact`: all 134 tests passed (about 40 s).
- A focused responsive suite passed for home, anime, kids and library screens
  across phone, tablet and desktop widths in RTL and LTR.
- `git diff --check` reported no whitespace errors; Git only warned that its
  configured checkout may normalize LF line endings to CRLF.
- Final `flutter build apk --release`: passed in 182.5 s. APK path:
  `build/app/outputs/flutter-apk/app-release.apk`, 59,791,932 bytes
  (57.0 MiB); SHA-256 is
  `1F93BC24EC77CA60F7A404AF00C5240635A00D8294838CF2C61969E50D26D407`.
- `aapt dump badging`: package `app.horse.mobile`, version `1.0.0` (code 1),
  minimum SDK 24, target SDK 36, application label `Horse`.
- Final APK `apksigner verify`: signature verified with the v2 scheme. The
  certificate is Android Debug, as documented in `README.md`; this is an
  installable development artifact and is not ready for store publication.
- Started the configured Pixel 5 Android emulator after the initial device
  inventory, installed the final APK with ADB, and resolved `app.horse.mobile`
  to `MainActivity`. The app process was running and its activity was resumed;
  the captured home screen rendered the featured title and phone navigation,
  with no fatal exception in the inspected logcat window. Physical-phone
  playback and provider flows remain unverified.
- iOS could not be built because this host is Windows and has no Xcode
  toolchain.
- The release build warns that the app and current Android plugins use Kotlin
  Gradle Plugin integration scheduled for a future Flutter migration. The
  warning did not block this build.
- Final `git diff --check`: passed. Existing local changes were preserved;
  no commit, push, pull request or release was created.

## Milestone 5 — Home hero and bottom dock repair

Status: implementation and automated verification complete; device preview
omitted per user instruction.

- Resized the featured hero and its loading placeholder together to about 64%
  of viewport height, capped at 640 px and constrained by available safe space.
  This keeps the artwork, call to action and page indicators in the first view
  without letting the hero occupy nearly the whole page.
- Anchored the four-icon glass dock to the shell's bottom edge with safe-area
  clearance, matching the supplied reference's Settings, Kids, Anime and Home
  visual order. Reduced unused end-of-home scroll padding from 132 to 24 px.
- Kept Library reachable through a new Library shortcut in Settings after
  matching the reference's four-destination dock.
- Geometry tests cover phone, tablet and desktop widths in RTL and LTR, check
  hero height and dock placement, and verify all four tab names remain exposed
  to accessibility semantics. Verification for this milestone passed all 134
  Flutter tests; `flutter analyze lib --no-pub` reported no issues.
- `flutter build apk --release` succeeded; the current APK is
  `build/app/outputs/flutter-apk/app-release.apk` (59,791,984 bytes, 57.0 MiB).
- Per the user's instruction, no emulator-based app check or screenshot was
  performed. A startup attempt began just before the instruction arrived and
  was interrupted; no APK was installed or inspected on the emulator.
- Existing local work remains uncommitted and preserved.

## Milestone 6 — Home hero, floating navigation and responsive rails

Status: implementation, analyzer and Android release build complete; no
emulator used, per user instruction.

- Matched the Flutter hero's slide pool to the web homepage: the first three
  entries from Trending Movies, In Theaters and Trending Series, capped at
  eight slides. Kept Top 10 as its own separately ranked catalog.
- Enriched hero slides with localized TMDB transparent logos and textless
  artwork, with catalog artwork fallbacks. Removed the title text fallback as
  requested. Reduced the details action, added six-second automatic rotation,
  swipe navigation and tappable page indicators, and respected reduced motion,
  app lifecycle and the selected tab.
- Changed the phone dock to overlay the full-height page content with safe-area
  clearance. Added local scroll-end insets so the floating dock does not cover
  the last content on Home, Anime, Kids, Library or Settings.
- Matched the Top 10 outline rank baseline and bottom offset to the web poster
  strip so the number appears behind the card. Made poster-rail and section
  spacing respond to viewport width; removing poster titles also removes their
  gap and reserved text height.
- Updated `design-reference.md` to describe the logo-led hero and its controls.
- `dart format` completed for the changed Dart sources. `flutter analyze lib
  --no-pub` passed with no issues. `git diff --check` passed; Git reported only
  its existing LF-to-CRLF normalization notices.
- `flutter build apk --release` passed in 317.8 seconds. APK:
  `build/app/outputs/flutter-apk/app-release.apk` (59,841,080 bytes / 57.1 MiB),
  SHA-256 `89A84127125395D8889FCEBEE1EC917AA777F4D4B034F58667CC70025E980184`.
- No tests were run, and no emulator or device preview was used. Existing local
  changes were preserved; no commit or push was created.

## Milestone 7 — Environment-backed service connections

Status: mobile integration status is connected to Horse server APIs; Flutter
analysis, Android release build, and the changed route's lint check passed.

- Matched the environment variables in the supplied reference to existing
  Horse server routes and documented which settings belong on the server and
  which per-user credentials stay in device secure storage.
- Added a status panel to Settings → Connected services. It reads database
  health/RLS, TMDB, Trakt, Simkl, Resend, OMDb, MDBList, and torrent-engine
  readiness from the Horse API. The panel displays statuses only and does not
  expose keys, connection strings, internal engine addresses, or raw errors.
- Extended `/api/integrations/status` with a boolean Resend readiness value so
  the mobile client can show password-recovery email configuration.
- The Supabase Postgres URLs remain server-only: runtime API connections use
  the transaction pooler, while the migration URL is reserved for deployment
  migrations. The Flutter app does not connect directly to Postgres.
- `flutter analyze lib --no-pub`: passed, “No issues found”. Targeted ESLint for
  `/api/integrations/status`: passed. `git diff --check`: passed (Git printed
  only its configured LF-to-CRLF normalization notices).
- `flutter build apk --release`: passed in 231.7 seconds. APK:
  `build/app/outputs/flutter-apk/app-release.apk` (59,841,556 bytes / 57.1 MiB),
  SHA-256 `73D2413486D97630C607EBE1151AA69AF64588FDCE3AA967C5191B464DFE3241`.
- Read-only status check of the configured production server found TMDB,
  Trakt, and Simkl configured; OMDb and MDBList absent; torrent mode `none`;
  database authentication rejected and zero public tables reported. The live
  endpoint predates the new Resend status field, so email readiness is unknown
  until this route is deployed. Correcting Vercel credentials/deploying is
  outside this code change; no production variables were changed.
- A direct metadata-only connection check using the supplied database URLs was
  blocked by Node Postgres certificate validation (`SELF_SIGNED_CERT_IN_CHAIN`).
  Certificate checks were not disabled, so those local values remain unverified.
- No tests or emulator were used. Existing local changes were preserved; no
  commit, push, or deployment was created.

## Milestone 8 — Compact fixed-content Home hero

Status: implementation, Flutter analysis and Android release build complete;
no tests or emulator used.

- Reduced the phone hero to about 45% of viewport height (320–440 px when
  available), with a proportional 48% layout on wider screens. Removed the
  optional synopsis from the hero to keep the next home rows closer to view.
- Separated the changing cover from the fixed hero layout. Only the background
  crossfades every six seconds; the logo, year, localized genre, media type,
  details button and indicators keep their positions. Swipes and indicator
  taps still change the active title, and the details action follows it.
- Kept the foreground and loading skeleton dimensions aligned, and let the
  metadata row grow with system text scaling while truncating long genres.
- `dart format lib/features/home/home_page.dart`: passed (no formatting changes
  required). `flutter analyze lib --no-pub`: passed, “No issues found”.
- `flutter build apk --release`: passed in 175.0 seconds. APK:
  `build/app/outputs/flutter-apk/app-release.apk` (59,825,172 bytes / 57.1 MiB),
  SHA-256 `63C14DA55841F2D3D22B8F6D10384736AED2E714949EDAF5CE267BF5D929FAAF`.
- `git diff --check`: passed; Git printed only its configured LF-to-CRLF
  normalization notices. No emulator/device preview or tests were run, per the
  user's instruction and current task scope. Existing local changes were
  preserved; no commit or push was created.

## Milestone 9 — Immersive Flutter video player

Status: player implementation, responsive timeline tests, Flutter analysis and
Android release build complete. Native device playback and iOS build were not
verified in this Windows session.

- Evaluated the existing `video_player` path against upstream mpv/libmpv
  documentation. Kept `video_player ^2.11.1`, which already wraps the native
  Android and iOS playback backends and preserves signed sources, resume/history,
  external subtitles and episode flow. The evidence and platform caveats are in
  `player-engine-decision.md`.
- Reworked the player surface around the video with safe-area-aware top, center
  and bottom control groups, light fades, reduced-motion-aware control fading,
  landscape/fullscreen behavior, buffering feedback, and compact/capped layouts.
- Connected play/pause, configurable seek steps, double-tap and horizontal drag
  seeking, mute/volume, speed, video fit, subtitles, and fullscreen to the
  existing controller/settings. The timeline previews before seeking, renders
  the controller's buffered ranges, keeps time and progress left-to-right in
  Arabic RTL, and remains keyboard/semantics accessible through its Slider.
- Added previous/next episode controls and an episode picker when catalog data
  permits. Stream resolution and signing use the existing app path; playback
  progress and scrobbling continue to honor `recordProgress`, including across
  automatic episode replacement. Lifecycle pause/resume and orientation cleanup
  are handled by the player route.
- Added `test/player_timeline_test.dart`. It passed at 360, 390, 480, 768, 834,
  1024 and 1280 logical pixels in both RTL and LTR; drag preview/commit also
  passed. `flutter analyze lib --no-pub`: passed, no issues.
- Full `flutter test --reporter compact`: 134 passed, 3 failed. Failures are in
  the unrelated Home/Top 10 responsive test in RTL and LTR (existing card/hero
  layout overflow, followed by its PageView assertion) and the shell auto-hide
  test (a pending 150 ms Home artwork timer). The focused player timeline test
  passed after the final code changes.
- `flutter build apk --release`: passed. APK:
  `build/app/outputs/flutter-apk/app-release.apk` (59,940,640 bytes / 57.2 MiB),
  SHA-256 `A1C6EF3328691E42136FF123777E020718C9BF20BDC3325FA73FE7A42C18EFAF`.
  Gradle warned that the app and Android plugins still use Kotlin Gradle Plugin
  integration scheduled for future Flutter migration; this did not block the
  build.
- `git diff --check`: passed; only configured LF-to-CRLF notices appeared.
  No iOS build was available because this Windows host has no `xcodebuild`.
  Per the user's instruction, no emulator was used; no physical device playback
  or screenshots were claimed. Existing local work was preserved; no commit,
  push or dependency change was made.


## Milestone 10 — Full-width Home hero artwork

Status: implementation, Flutter analysis and Android release build complete.

- Fixed the narrow portrait strip in the Home hero. `AnimatedSwitcher` could lay
  out the background image at its intrinsic size, leaving black space at both
  sides. The artwork now expands to the full hero bounds and `BoxFit.cover`
  crops it to the viewport; logo, metadata, details action and slide indicators
  keep their existing layout.
- `dart format lib/features/home/home_page.dart`: passed (no changes needed).
  `flutter analyze lib --no-pub`: passed, “No issues found”.
- `flutter build apk --release`: passed in 79 seconds. APK:
  `build/app/outputs/flutter-apk/app-release.apk` (59,940,640 bytes / 57.2 MiB),
  SHA-256 `E5F9CDE20A40FF3BD008EAB4C55D7F30A86DD7A5E6EABE9DA5E72CA88E026141`.
- `git diff --check`: passed; Git printed only configured LF-to-CRLF notices.
  No emulator or tests were used, per the user's instruction and current task
  scope. A physical-device screenshot was not captured.

## Milestone 11 — Publish only the Flutter mobile app

Status: GitHub `Noor/main` now publishes only the `mobile_app/` directory.

- Replaced the previous whole-repository snapshot on `Noor/main` with an
  independent snapshot whose repository root contains only `mobile_app/`.
  This removes the web app, root documentation and previous broad snapshot from
  the branch's visible history.
- Kept the complete local Horse checkout intact; this change affects the remote
  `Noor` repository only.

## Milestone 12 — Flatten repository layout (app at root)

Status: GitHub `Noor/main` root IS the Flutter project.

- All previously `mobile_app/`-nested files (lib/, android/, ios/, docs/,
  pubspec.yaml, analysis_options.yaml, README.md, .gitignore, .metadata) now
  live at the repository root; the `mobile_app/` directory is gone.
- Historical documents in `docs/migration/` keep their original
  `mobile_app/...` paths as written at the time; paths are pre-restructure.
- Build instructions: clone, `flutter pub get`, `flutter run` from the root.

## Milestone 13 — Torrent playback buffer and piece read-ahead

Status: implementation and Android arm64 release build complete; physical
playback still to be verified.

- Compared Noor's loopback torrent-to-mpv path with Nuvio Mobile at commit
  `229c083cf3db7bab6fda284484f87439eb4e0eb0`. Nuvio combines a torrent engine
  with bounded read-ahead and playback buffering; Noor already had the same
  loopback shape, but only prioritized a 16 MiB window and closed an idle read
  after 45 seconds.
- Increased Noor's rolling high-priority piece window to 48 MiB (bounded by
  piece count), raised the mpv cache horizon to 45 seconds while retaining a
  3-second initial/rebuffer wait, and enlarged its demuxer limit to 192 MiB.
- The local stream now checks for newly completed pieces twice as often,
  transfers 512 KiB chunks, and keeps a stalled response open for up to two
  minutes so temporary peer gaps do not truncate playback.
- Bumped the app to `1.2.55+59`. `flutter build apk --release --no-pub
  --target-platform android-arm64` passed; no test suite was run. The Android
  device was not connected to ADB during this turn, so physical playback
  remains unverified.

## Milestone 14 — Torrent player handoff and open recovery

Status: targeted Dart analysis and Android arm64 release build passed; the new
APK was installed and launched on the connected SM-A217F. Torrentio playback
and smoothness still need an actual stream run on the device.

- Removed the wait for the torrent's first pieces before handing a prepared
  local URL to the player. This prevents out-of-order piece downloads from
  trapping the user on the preparation dialog; the loopback server waits for
  each requested piece and MPV performs its own initial buffering.
- Added one retry of MPV's initial loopback open for torrent sources, keeping
  the torrent and its local server alive between attempts.
- Extended the rolling piece-priority runway to 96 MiB (bounded to 2–96
  pieces), retained the 45-second cache horizon and 3-second startup threshold,
  and capped MPV's demuxer at 64 MiB forward / 16 MiB backward to reduce memory
  pressure on lower-memory Android phones.
- Compared the flow with the supplied NuvioMobile commit and its playback-aware
  torrent engine; Noor now transfers to playback as soon as its local range
  endpoint is ready instead of waiting on a whole-torrent progress threshold.
- `dart analyze` on the five changed Dart files: passed, no issues found.
  `flutter build apk --release --no-pub --target-platform android-arm64`:
  passed. The Kotlin daemon was unreachable, so Gradle used its fallback
  compiler path. APK: `build/app/outputs/flutter-apk/app-release.apk`
  (92,793,299 bytes), version `1.2.56+60`, SHA-256
  `8B214AF7D0E55BFFCAED25E88C06132DDF0AA85DC9B1983F9C1987418348BC96`.
- ADB confirmed version `1.2.56` / code `60` installed and the app launched on
  `SM-A217F`. No Torrentio stream was started during this verification, so
  actual decoding, buffering and audio/video smoothness remain unconfirmed.

## Milestone 15 — NOVA brand and product-wide Flutter redesign

Status: implementation, ordered design documentation, full regression,
analysis and Android Release build are verified. iOS, provider, device-visual,
accessibility-hardware and profile-mode acceptance remain open.

- Rebranded visible app surfaces, startup identity, About and native Android /
  iOS display names to NOVA while preserving storage, package and OAuth
  compatibility identifiers.
- Applied the supplied brand assets and palette to complete Light and Dark
  themes; added Poppins + IBM Plex Sans Arabic, live English/Arabic direction,
  localized copy and shared NOVA components.
- Reworked browsing, Home, Details, Kids, Library, Search, Downloads, Settings,
  integrations, source selection, player panels and supporting sheets/dialogs.
  Added pinned cinematic covers, responsive tablet navigation, Kids PIN gates,
  conditional metadata, catalog refresh subscriptions and bounded image/cache
  handling. Removed recurring blur from shared glass controls and fixed a
  player stream-server shutdown race.
- Added ordered audit, design tokens/contrast calculations, information
  architecture, page specs, motion/accessibility rules, rationale and an
  acceptance tracker under `docs/nova/`.
- Localization parity check: 886 English / 886 Arabic messages, zero key or
  placeholder mismatches. An earlier full serial Flutter run had 317 passes
  and 8 failures from stale dock, lazy-page, subtitle-palette and Top 10 test
  expectations. Updated those contracts, corrected the shell widget-test
  viewport and reveal-transition timing, then reran the full serial suite:
  **325 tests passed with no failures**. Focused browse, perf/page lifecycle,
  subtitle style, Top 10 and shell edge-to-edge suites also pass.
  Final `flutter analyze --no-pub` completed with `No issues found` in 205.8s.
  Built a fresh Android arm64 Release APK (`1.2.56+60`, 95,320,261 bytes),
  confirmed the `NOVA` application label with `aapt`, and verified the APK
  signature (v2). SHA-256:
  `694E850B3326E3CF8F1F0F6F27705E64951A4775692EA6C7DEBCBBBF6DAE7D13`.
  Gradle completed through its fallback Kotlin compiler after daemon
  connection retries. Flutter warned that the current Gradle 8.14, AGP 8.11.1
  and Kotlin 2.2.20 versions will need upgrades for future Flutter support.
  No Android device was attached (`adb devices -l` returned no devices).
  iOS/Xcode, visual-device review, live provider flows,
  accessibility hardware and profile-mode performance remain unverified.
- Follow-up cinematic layering fix: the fixed hero had lived as the first
  transformed sliver in the same `CustomScrollView` as the content, where
  pinned-sliver paint order could leave it above later content. Home and
  Details now use a fixed bottom hero layer and a top scroll view with a clear
  hero-height spacer and an opaque, rounded theme-surface sliver. Hero copy
  and actions fade with scroll progress and stop hit-testing as scrolling
  begins; the layer host keeps hero controls tappable at the top while routing
  scroll gestures to the scroll view. Added small-phone/tablet, Arabic/English,
  Light/Dark layout coverage and hit-test/paint-order assertions. The final
  serial Flutter suite passed: **333 tests, no failures**; targeted analysis
  of the changed Dart files reported no issues. Device screenshots remain
  unverified because ADB reports no attached device.
- Episode display control: replaced the paired list/grid segments with one
  48px icon button. Its icon tracks the current layout; pressing it switches
  between list and grid, with a localized tooltip describing the destination.
  Kept automatic phone/tablet defaults and saved preference behavior. Widget
  coverage passed for Arabic/English and Light/Dark on phone/tablet; targeted
  analysis passed. No emulator was launched.
- Navigation bar appearance: added Classic, Compact icons, and Mini choices
  under Settings > Appearance, with an interactive preview using the real
  tabs. The selection persists through the existing settings store and applies
  immediately; tablet navigation keeps its side rail for all three choices.
  Added Arabic/English copy, responsive RTL/theme/text-scale widget coverage,
  and updated navigation/settings specs. Targeted tests and analysis passed;
  no emulator was launched.
- Device screenshots, real provider authorization, accessibility hardware
  checks and profile-mode performance traces remain pending.

## Milestone 16 — Animated NOVA startup splash

Status: complete in source and headless widget validation.

- Replaced the static launch loading mark with a one-shot Flutter animation
  derived from the supplied NOVA splash reference. It uses the supplied red
  icon SVG and the exact four supplied wordmark vector paths: the symbol fades
  and scales in, slides left, and the letters draw in sequence over a restrained
  brand-red glow.
- Startup initialization still begins immediately in `_LaunchGate.initState`.
  The 3.4-second visible intro and initialization run in parallel; handoff
  occurs when both have completed. Slow initialization holds the final lockup,
  while reduced motion snaps to that final lockup and releases the intro gate
  without a decorative delay. Theme, locale and settings rebuilds do not replay
  the controller.
- Dark mode uses NOVA Ink with the white wordmark. Light mode uses the supplied
  light background with the Ink wordmark. The artwork has fixed LTR geometry in
  Arabic so the universal brand is never mirrored. Compact landscape and small
  portrait layouts scale from available space, and the whole launch surface can
  scroll when a 200% text-scale error footer needs more height.
- Existing localized loading, retry and startup-error behavior remains in the
  gate. The Material app title and splash semantics now resolve the existing
  localized `appName` string.
- `flutter test test/nova_splash_test.dart`: **4 tests passed**. Coverage checks
  one-shot completion and rebuild stability, reduced motion with no remaining
  ticker, light/dark and RTL geometry, compact portrait/landscape bounds, and a
  scrollable Arabic 200% text-scale error state.
- Targeted `flutter analyze --no-pub` for the launch gate, splash widget and
  splash tests passed with `No issues found`. Headless end-state review frames
  were rendered at `build/nova-review/nova-splash-dark.png` and
  `build/nova-review/nova-splash-light.png`. No emulator or physical device was
  launched; native transition timing and on-device visual review remain
  unverified.


## Milestone 17 — Completion audit and functional preference repair (18 October 2026)

- Audited the current implementation against the interrupted NOVA redesign rather than treating its progress messages as completion evidence. Used an Astra architecture review, Sol builders and an independent Sol reviewer (Terra was unavailable).
- Connected saved resume/prompt/exit confirmation, initial video fit, audio/subtitle preferences, custom speeds, source information and source density to actual consumers. Protected saved history while a resume decision is pending; bounded seeks for short/unknown durations and kept failed saves from blocking exit.
- Moved active torrent metadata into the player header flow; preserved pre-ready feedback. Localized player semantics, isolated mixed-direction torrent metrics and enlarged the speed hit target to 52 by 44 dp. Composed controls pass non-overlap checks at 844 by 390 dp, 200% text, LTR and RTL.
- Corrected Light-mode poster badge contrast and small accent text/surface combinations using only derivatives of supplied palette colors. Added AA text-pair and ARB key/placeholder parity checks.
- Added real SharedPreferences restoration coverage for language, navigation style and source density, plus source-selection and splash lifecycle/layout regressions.
- Full serial suite: **384 passed**. Full analysis: **No issues found** (76.7s). After the final bidi text isolation, the focused player/direction/contrast suite passed **25 tests**. APK evidence and the final scoped analysis are recorded in `docs/nova/requirements-status.md`.
- Visually reviewed headless splash end states with the real English/Arabic fonts and a composed Arabic player at 200% text with the Lucide font. No emulator, physical-device installation, native media playback, external provider authorization or performance trace was performed.
- Updated design/player/settings/navigation specifications and added `docs/nova/08-completion-audit.md`; the acceptance tracker distinguishes implementation and automated evidence from remaining device/provider/iOS checks.

## Milestone 18 — Plan, repository map, and milestone documentation (19 October 2026)

Status: documentation changes complete. No application source or runtime behavior changed.

### 18.1 Living project plan

- Added `docs/nova/10-project-plan.md` with completed design, implementation, and automated verification stages, plus the remaining physical-device, provider, performance, accessibility, and iOS acceptance work.
- Kept unperformed checks explicitly pending; the plan prohibits emulator use in line with the user instruction.

### 18.2 Contributor guide and source map

- Updated root `AGENTS.md` to reflect the actual `lib/core`, `lib/features`, `lib/shared`, localization, asset, platform, test, tool, and documentation layout.
- Added an explicit final requirement to keep `AGENTS.md` current when project structure, architecture, commands, or development practices change.

### 18.3 Milestone structure and history

- Added `docs/nova/11-work-log.md` with major headings and nested sub-milestones documenting completed work and verification evidence.
- Clarified that milestones 1–14 in this file refer to the historical Horse monorepo; milestones 15 onward record NOVA work.
- Linked the plan and work log from `docs/nova/README.md`.

- Validation: checked the documentation links and heading hierarchy against the repository tree. No Flutter test, build, or emulator was run because this milestone only changes Markdown documentation.

## Milestone 19 — Stable anime catalog background (19 October 2026)

Status: complete. The source fix, automated regression checks, updated Release APK, and physical-phone visual check all passed.

### 19.1 Canvas behavior

- The Anime tab now paints a full-page canvas from the active theme's scaffold surface while its catalog loads and while its slivers scroll.
- This prevents transparent scroll content from exposing the platform window's pure-black fallback between catalog states. Light and dark themes retain their own palette surfaces.

### 19.2 Verification

- Added a deferred-catalog widget test for both light and dark themes; the test verifies the page canvas before and after the catalog resolves.
- Focused tests: **2 passed**. Focused Dart analysis: **No issues found**.
- Release APK build completed in 170 seconds (132.2 MB); SHA-256: `6DACBD1222E854E078D03D411380CA0D40DFB4F74C6D48C602CDE992EED6A4A3`.
- Installed the updated build on the physical Android phone. In Arabic/Dark, sampled canvas pixels stayed at RGB `(20, 20, 23)` before and during scrolling; no Flutter, fatal, or overflow errors appeared in the device log. No emulator was launched.

## Milestone 20 — Poster frame fill and gentle zoom (19 October 2026)

Status: complete in source, focused regression checks, Release build, and physical-phone visual review.

### 20.1 Image sizing

- Animated poster images now receive explicit full-frame constraints in poster cards, so the `BoxFit.cover` crop uses the card's actual bounds instead of the image's intrinsic dimensions.
- The Anime feature distinguishes portrait poster art from landscape backdrop art. Poster fallbacks use contain-fit plus a centered **1.10×** scale to gently reduce side space without aggressively cropping the source; actual landscape artwork remains cover-fit with a subtle **1.03×** crop.

### 20.2 Verification

- Poster-card contrast and anime canvas Light/Dark focused tests: **4 passed**. Focused analysis and formatting passed.
- Built and installed a new Release APK on the physical Android phone; inspected the Arabic/Dark Anime feature and poster rails. No emulator was launched.
- APK SHA-256: `F7909C9498D7C10D083B5C8CC945EEA375768593AB1E64A0A10013E0F4CBF46C`.

## Milestone 21 — Linked viewing progress on Home, Details, and Anime (19 October 2026)

Status: source, analysis, full tests, and Android Release build passed. Real provider accounts and physical-device acceptance remain pending.

### 21.1 Provider progress

- Fetch Trakt paused playback, AniList CURRENT entries, and MyAnimeList watching entries through the existing linked-content refresh path; retain provider records separately from local watch history.
- Reuse Continue Watching artwork cards with source label, episode/count context, and progress percentage. Resolve missing Trakt poster/backdrop art from installed catalogs where possible.
- Show linked progress on Home and Anime. Open paused Trakt episodes at their provider percentage when runtime metadata is available; open tracker anime at its next known episode.

### 21.2 Details and episode state

- Combine linked and local episode progress on Details, display linked completion, and add an accessible mark-watched action to each episode.
- Mark-watched stores local history and mirrors episode progress through the existing AniList/MyAnimeList sync preferences.
- Add regression coverage for provider progress conversion and linked Anime episode-state merging.

### 21.3 Verification and limits

- Final focused Flutter analysis after Home deduplication and Anime-provider filtering: **No issues found** (84.4s). The final serial suite passed **437 tests**; focused integration/detail suites previously passed **22 tests**.
- Final Android arm64 Release APK built in **121s**, size **138,756,467 bytes**, SHA-256 `C5C224249A5733CD6E5B79E73E6A8A6664184187E4E5B3FEC27D232EE46EBE46`.
- `adb.exe` was unavailable in the moved-project session; physical install and linked-account checks were not possible. No emulator was launched.
- Linked providers do not return a paused source-video frame; cards use available artwork and progress. AniList/MAL provide watched episode counts rather than a paused timestamp.

## Milestone 22 — Local resume-frame previews and expiry (19 October 2026)

- Use MediaKit's decoded video-frame screenshot API on pause, player exit, and app background; keep frame files and metadata in app-local storage, separate from cloud-synced history.
- Compress frames off the UI thread to at most 960 pixels wide, cap the cache at 120 entries, show local frames on local Home Continue Watching cards, and retain catalog artwork for linked-service cards.
- Add Playback retention options of 30, 20, 10 days, and one week (30-day default), with pruning on startup and when the option changes.
- 9 focused storage/retention and settings tests passed; changed-file Flutter analysis reported **No issues found**; Android arm64 Release built in **146.3s**, size **142,361,459 bytes**, SHA-256 `039F89AFCF2435FF2D6AA884C2A03291E72175E8B99938EBC12FF60A29F870DB`.
- Physical-phone frame capture/render verification remains pending because `adb.exe` is unavailable. Never launch an emulator.

## Milestone 23 — Episode progress actions and unified linked rows (19 October 2026)

- Added long-press episode actions for download, mark watched, and mark through the selected episode. Kept playback progress over each thumbnail; watched state is a checkmark only, at logical `start` (Arabic bottom-right, English bottom-left).
- Range completion persists prior released episodes locally in one write and batches Trakt/Simkl history when their existing sync toggles are enabled. AniList/MyAnimeList counters follow their existing progress-sync preferences. Playing another episode preserves earlier watched episode records.
- Added Simkl paused-playback loading alongside Trakt, AniList, and MyAnimeList. Home keeps linked integrations in one horizontal rail, and Details shows matching integrations in one horizontal row.
- Added Arabic/English strings and regression-test cases. Dart analysis reported **No issues found** but exited nonzero on a sandbox telemetry permission error. Flutter widget/unit tests could not run because the moved checkout cannot open the Flutter SDK cache lock. No emulator was launched; real-service and physical-device checks remain pending.

## Milestone 24 — Reconcile the moved NOVA project (19 October 2026)

- Verified the project at C:\Users\hosea\projects\app\Nova against the previous working copy. Restored missing resume snapshots and expiry, Simkl paused playback, episode actions, provider history sync, localization, tests, and milestone records; retained destination-specific Anime filtering and setting parsing.
- Home now uses one horizontal Continue Watching rail for local playback and all connected providers. Details shows matching provider progress in one horizontal row. Episode thumbnails keep their own progress bars and show only an accessible directional checkmark when watched.
- **38 focused Flutter tests passed** for episode overlays/actions, Home progress layout, provider parsing, Details, Settings, and resume snapshots. Scoped Dart analysis on all changed source and test files reported no issues; full Flutter analysis did not return a final result. No emulator was launched; physical-device and linked-account acceptance remains pending.

## Milestone 25 — In-app Android APK updates (20 October 2026)

- Added root version.json metadata using the checked-in app version/build (1.2.56+60); set android_url to the GitHub latest-release APK endpoint and min_build to the current build because no prior update manifest existed.
- Added an About-screen update check with Arabic/English status, a download-progress dialog, cache cleanup before download, and OpenFilex installer launch. An asynchronous startup check routes builds below min_build to a non-dismissible required-update screen/dialog. iOS retains an ios_url fallback through url_launcher.
- Added open_filex and direct package_info_plus dependencies; existing dio, path_provider, and url_launcher dependencies were reused. Configured the app-scoped Android FileProvider for cache files and retained the existing signing configuration. Added ignore rules for key.properties and *.jks.
- Verification: update-manifest tests 3 passed; flutter analyze --no-pub reported No issues found; local release APK built successfully at build/app/outputs/flutter-apk/app-release.apk (135.9 MB). No emulator or physical-device install was used. The initial Kotlin daemon connection warning required the in-process compiler retry.

## Milestone 26 — Android release scaffolding (20 October 2026)

- Added .github/workflows/release.yml for Android analysis, tests, release APK build, and artifact retention on v* tags or manual dispatch.
- Added optional local upload-key signing in Gradle, a blank signing template, and an ignored local properties file that points to the user-provided keystore. No alias, password, or key bytes were written.
- The workflow has no keystore and does not publish release assets; its artifact remains debug-signed until secure CI signing is configured. It must not replace a published update signed with another certificate.
- Added docs/nova/release-signing.md and updated the repository map. Validation: flutter analyze --no-pub found no issues; flutter build apk --release --no-pub succeeded; PyYAML parsed the workflow file. The workflow itself and full test suite were not rerun.

## Milestone 13 — Version 1.0.0 and updater error handling (20 October 2026)

- Updated the app display version and release manifest to 1.0.0; advanced build number to 63 to preserve Android upgrade compatibility with build 62. Kept the minimum required build at 60 and the existing direct release APK endpoint.
- Centralized the version used in Simkl request metadata. Added localized Arabic and English explanations for current-version checks, connectivity and manifest failures, missing release APKs, storage and download problems, invalid APKs, and installer permission/availability/signature failures.
- The updater now validates the downloaded APK container signature before handing it to Android. Forced-update errors display over the required-update prompt with a retry path.
- Verification passed: focused updater/version tests (5 tests), full Flutter test suite (451 tests), and flutter analyze --no-pub (no issues, 231.9s). flutter build apk --release --no-pub produced a 142,520,135-byte APK reporting versionName 1.0.0 and versionCode 63. The configured local Android release signing key was used. No emulator was started.

## Milestone 27 — Update discovery release 1.0.1+64 (20 October 2026)

- Synchronized app version/build as `1.0.1+64` across Flutter metadata, the synchronous version constants, and the root public update manifest. Kept the forced-update threshold at build 60 and preserved the latest-release APK endpoint.
- Regression tests prove that the phone's installed `1.0.0+63` build sees the published build 64 as an optional update, while build 64 is current. The public manifest is fetched from `main/version.json` with a no-cache request.
- Focused updater/version tests: **5 passed**. Full `flutter analyze --no-pub`: **No issues found** (114.6s). Android Release APK built successfully; Gradle metadata reports versionName `1.0.1`, versionCode `64`; size **142,520,135 bytes**; SHA-256 `77B36508F708A53DD5FDFD40EF6CFC1FC294736CE39A627216C02B13F764CE58`.
- Physical-phone update notice remains to be checked. Download/install requires the user to attach the matching-signed APK as `app-release.apk` to the v1.0.1 GitHub Release. No emulator was launched.
## Milestone 28 — GitHub update-manifest parsing fix (20 October 2026)

- Confirmed `raw.githubusercontent.com` serves the JSON manifest as `text/plain; charset=utf-8`, so Dio returns a string and the prior app rejected it as an incomplete manifest. The updater now decodes text JSON before applying the existing field and URL validation.
- Added regression coverage for the exact text/plain response. Bumped the app and manifest to `1.0.2+65`; kept `min_build` 60. Six focused updater/version tests passed and full Flutter analysis found no issues (190.9s).
- Android Release build passed; metadata: versionName `1.0.2`, versionCode `65`; APK size **142,520,135 bytes**; SHA-256 `94292644ADE2F66F4280D70B12C605A4A1D802E8D079584767B58D4207234053`.
- Installed builds 63 and 64 cannot parse the current server response and require one manual install of this fixed APK. The new app will check correctly; its download button requires a matching-signed `app-release.apk` asset on the v1.0.2 GitHub Release. No emulator was launched.
## Milestone 29 — Update discovery test release 1.0.3+66 (20 October 2026)

- Advanced the app and update manifest to `1.0.3+66`, keeping `min_build: 60` and the existing update message and URLs.
- Added coverage that installed `1.0.2+65` detects build 66 when GitHub serves the manifest as `text/plain`; build 66 is correctly considered current.
- Focused updater/version tests passed (**7 tests**); full `flutter analyze --no-pub` found no issues (171.1s).
- Android Release APK metadata: versionName `1.0.3`, versionCode `66`, applicationId `app.nova.mobile`. APK size **142,520,139 bytes**, SHA-256 `6610E286EA182BBBFDBE140787E119E3453282D946F259BC9E83EE9D192F6757`.
- The manifest is published with tag `v1.0.3` for update discovery. The user attaches the matching-signed APK to the GitHub release; no APK was uploaded by this task. Phone confirmation remains pending; no emulator was launched.
