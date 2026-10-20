# NOVA requirements and acceptance tracker

Updated: 20 October 2026. The redesign implementation and ordered design documents are in place. This records what has actually been checked; it is not a release certification.


## Latest implementation update — Update discovery test release 1.0.3+66 (20 October 2026)

- The app version, build constants, and public update manifest are synchronized at `1.0.3+66`; `min_build` and download metadata are preserved.
- The exact installed baseline `1.0.2+65` passes an updater regression test against a GitHub-style `text/plain` manifest and detects build 66. Focused tests (7), full analysis, and the Release APK build passed. APK metadata is versionName 1.0.3/versionCode 66.
- Publishing the updated `version.json` on `main` enables discovery. The user will upload the matching-signed APK to the v1.0.3 GitHub Release before using the in-app installer. Physical-phone confirmation is pending; no emulator was launched.
## Latest implementation update — Moved project reconciliation (19 October 2026)

- Compared the confirmed C:\Users\hosea\projects\app\Nova project against the earlier working copy. Restored missing device-local resume snapshots and retention, Simkl paused playback, episode long-press actions, grouped provider sync, bilingual strings, tests, and milestone documentation while keeping the destination's anime filter and seek-step parsing.
- Home now places local resume cards and all connected-provider cards in one horizontal Continue Watching rail. Details shows the matching Trakt, Simkl, AniList, and MyAnimeList records in one horizontal row. Episode progress remains on the thumbnail; the watched indicator is a checkmark only and mirrors in RTL/LTR.
- **38 focused Flutter unit/widget tests passed** across episode progress/actions, the Home rail, provider parsing, details, settings, and snapshot retention. Scoped Dart analysis of all changed source and test files reported no issues; full flutter analyze --no-pub did not return a final result before interruption. No emulator was launched; linked-account and physical-device acceptance remains pending.
## Verification record

- English and Arabic ARBs each contain **919 localized message keys** with exact key parity. Automated key and named-placeholder parity checks pass; the generated localization file was regenerated from the ARBs.
- Full `flutter analyze --no-pub` completed with **No issues found** (76.7 seconds).
- After the final bidi change, `dart analyze lib/features/player/video_player_page.dart` also completed with **No issues found**. The preceding scoped Flutter invocations reported no source issues but emitted a Flutter analytics/stream-shutdown exception; the direct Dart invocation avoids that tooling failure.
- Full serial `flutter test --no-pub --concurrency=1 --reporter=compact` completed with **434 passing tests and no failures** before the anime-canvas fix. The new focused anime-canvas suite then passed **2 tests** (Light and Dark); focused analysis of the changed files reported **No issues found**.
- Added coverage includes saved resume decisions and safe seek bounds, track-language preference precedence, custom speeds, composed player controls at 200% text, source density with preserved selection, poster badges, theme text-role AA contrast, real SharedPreferences restoration into a fresh AppState, and splash lifecycle/reduced-motion/layout.
- Headless frames were visually inspected using bundled fonts: English/Dark and Arabic/Light splash end states, plus composed Arabic player controls at 844 by 390 dp and 200% text with IBM Plex Arabic and Lucide. These frames use fixture content; they do not execute a native media engine.
- After the anime-canvas and poster-fit changes, a fresh Android Release APK built successfully in **102.5 seconds**: **138,576,147 bytes**, version **1.2.56+60**, SHA-256 **F7909C9498D7C10D083B5C8CC945EEA375768593AB1E64A0A10013E0F4CBF46C**. It was installed on the available physical Android phone (no emulator). In Arabic/Dark, background samples stayed at palette ink RGB `(20, 20, 23)` through catalog scrolling; the portrait feature poster fills more of its frame after a restrained zoom. Device logs showed no fatal, Flutter, or overflow errors. Existing future-support warnings remain for Gradle 8.14, AGP 8.11.1 and Kotlin 2.2.20.
- Changed Dart files pass formatting and focused analysis; **4 focused widget tests** passed after these changes. The full-suite 434 count predates them. iOS build validation requires macOS/Xcode.
- Linked tracking progress milestone, rechecked in the moved project after final Home rail deduplication and Anime-provider filtering: focused tracker/episode/detail tests previously passed (**22**); the final full serial suite passed (**437**), changed-source analysis reported **No issues found**, and Android arm64 Release APK built (**138,756,467 bytes**, SHA-256 `C5C224249A5733CD6E5B79E73E6A8A6664184187E4E5B3FEC27D232EE46EBE46`). `adb.exe` was unavailable in this session, so no physical install or linked-service account validation was performed. No emulator was launched.

The current completion findings and preservation decisions are in [08-completion-audit.md](08-completion-audit.md). Earlier 325/333/351 test totals describe previous milestones, not this review.

## Requirement matrix

| Requirement | Implementation evidence | Acceptance status |
|---|---|---|
| NOVA brand and supplied assets | NOVA wordmark, palette, SVG/native assets, bounded animated Flutter launch screen, About copy, Android label and iOS display name; compatibility IDs remain stable. | Source-checked. Legacy internal class names, callback schemes and storage identifiers are intentionally retained. Native launch screens still need visual device checks. |
| Palette-only Light/Dark and AA | `nova_theme.dart` builds both complete color schemes from supplied palette roles. Contrast calculations are in `02-design-system.md`; glass and pressed states use alpha derivatives. | Key text pairs meet documented AA ratios. Every artwork overlay, disabled state and rendered screen still needs inspection. |
| Arabic/English and instant direction change | 919 localized ARB keys with Arabic/English parity, generated `NovaStrings`, live `AppState` locale updates, logical geometry, language controls in onboarding and Settings, Poppins + IBM Plex Sans Arabic. | Settings, browse, detail and player tests exercise both directions; a full every-route/device-language matrix remains pending. |
| Responsive layouts and text scaling | Adaptive phone/tablet shell, settings master/detail, constraint-derived poster grids, wrapping controls, enlarged Arabic line height and scrollable sheets. | Widget coverage includes narrow/large layouts and 200% text for key browse, detail, settings and player paths. Native largest-text and landscape screenshot checks remain pending. |
| Home and details | Pinned cinematic cover behavior, cached hero imagery, cast/crew circles, production logos, conditional fact table before Similar Suggestions, season/episode progress and source selection. | Layout and metadata widget tests pass. Real provider data and on-device scroll/animation quality remain unverified. |
| Kids safety | Explicit certificate allowlist, distinct visual shell, saved card-size preference, local secure PIN, locked-session restoration and gates for navigation/deep-link exits. | Safety logic and responsive browse cases have widget/source coverage. Provider certificate accuracy and cold-start/external-intent device tests remain required. |
| Settings and integrations | Searchable groups, dedicated subpages, add-on URL install/enable/reorder/remove, supported provider controls, storage/download surfaces, reduced-motion and reduced-transparency consumers. | Core search, live language, enlarged-text, add-on interactions and fresh-AppState preference restoration tests pass. Playback preferences and source density now have runtime consumers. External OAuth, key validation, sync and disconnect need real accounts. MDBList remains ratings-only; no personal-list connection is fabricated. |
| Linked watch progress | Home combines local and Trakt/Simkl/AniList/MyAnimeList cards in one horizontal rail. Details shows matching provider progress in one horizontal row, merges watched episodes locally, and applies provider sync preferences. | 38 focused tests passed in the confirmed project path. Scoped Dart analysis reported no issues; full analysis did not return a result in this session. Live provider sync/device interaction remains unverified. AniList/MAL expose episode counts, not in-episode positions. |
| Local resume-frame snapshots | MediaKit captures the real decoded frame on pause, player exit, and app background; the Home local Continue Watching card prefers it. Compressed files and metadata remain local, expire in 30/20/10/7 days (default 30), and are capped at 120 entries. | 9 focused storage/retention and settings tests pass; changed-file analysis and Android Release build pass. Physical-player capture and native rendering still require an Android device; linked-service cards remain provider-artwork only. |
| Remaining screens, sheets and dialogs | Browse, library, lists, calendar, live TV, anime tracker, onboarding, auth/provider flows, source/download selection, player panels, privacy/storage and error/empty/loading states use the shared system. | Anime catalog canvas verified on a physical phone in Arabic/Dark. Other route/state and language/theme combinations remain open. |
| Performance | First-visit shell mounting, inactive ticker muting, lazy slivers, bounded stale cache with refresh subscriptions, isolate parsing, bounded image decoding/cache, hero precache, skeletons, and static glass surfaces replacing repeated blur. Stream-server close now awaits in-flight handlers. | Targeted cache, layout and stream tests cover behavior; profile-mode frame time, image memory and weak-device scroll performance are unmeasured. |
| Accessibility | Lucide-only general UI icons, semantic labels, keyboard activation, 44 dp compact-nav and 48 dp standard control targets, reduced motion/transparency and text scaling. Tab semantics no longer duplicate visible labels. | Selected semantics/layout tests, including composed player controls at 200% text, pass; TalkBack/VoiceOver, switch control, focus traversal and high-contrast visual review need device acceptance. |

## Known scope limits

- MDBList currently contributes ratings only; the inspected application has no personal MDBList account/list sync backend.
- Notifications are foreground application feedback, not push or scheduled local delivery.
- Direct downloads support standalone HTTP(S) video files in the foreground; OS background scheduling, ranged resume, HLS/DASH packaging and DRM offline downloads are not claimed.
- The inspected app has no first-party account backend. Device identity and provider-specific authorization remain the actual account flows.
- No measured 60 fps claim is made. The static-glass change removes recurring blur work from shared navigation/search/detail chrome, but only a profile trace can quantify the gain.

## Remaining release acceptance

| Area | Required check |
|---|---|
| Build | Android analysis and the Release APK built with the arm64 Flutter target are verified. Run an iOS build on macOS/Xcode and perform an on-device install/launch check. |
| Update checker | Fixed JSON text parsing for GitHub text/plain response. The 1.0.2+65 phone baseline detects the published 1.0.3+66 manifest in automated coverage; confirm the notice on the physical phone. The user must attach the matching-signed APK to the v1.0.3 release before in-app download. |
| Regression | The full serial suite last passed all 434 tests before the anime-canvas change; its two focused regressions pass afterward. Rerun the full suite after future broader changes. |
| Visual | Anime catalog verified on phone portrait in Arabic/Dark. Capture Home, Details, Settings, Kids, Library, Search, Downloads and player at phone/tablet portrait/landscape in Arabic/English and Light/Dark. |
| Providers | Exercise each supported OAuth/device/key flow, expired token, sync toggle, manual sync and disconnect with real or provider sandbox accounts. |
| Safety/playback | Verify Kids PIN failures, restored session, back/tab/deep-link exits, then test direct, Debrid and torrent playback, resume, subtitles and next episode. |
| Performance/accessibility | Profile warm/cold launches, hero/rail scrolling and image memory on lower-end Android hardware; test TalkBack/VoiceOver, keyboard/controller and 200% native text. |
