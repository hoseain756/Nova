# NOVA Cinema redesign — integration QA

Review date: 2026-11-04. This report distinguishes source coverage, automated
Flutter checks, rendered fixtures, Android compilation and native-device
acceptance. It does not equate a shared theme change with an individual screen
being visually accepted on every platform.

## Implemented coverage

| Family | Presentation work | Verification boundary |
|---|---|---|
| Theme and shell | Warm ink/paper palettes, bilingual typography, Android seeded tonal surfaces, persistent floating M3 dock, labeled logical-start sidebar, native iOS26 iPad glass sidebar | Flutter theme/contrast/navigation/route tests; Android build; Swift source review only |
| Launch and account | Flowing splash/onboarding, adaptive credential spread, wrapping portrait profiles, multiline helpers, readable account actions | Existing account/security/recovery/profile/splash tests and responsive fixtures |
| Home | Artwork/copy feature spread, scrollable actions, trailer preview policy/lifecycle, separated Continue Watching metadata, preference-aware rails/ranking | Home/Detail captures, visibility/scroll tests, artwork-role and preview-policy tests; provider playback unverified |
| Anime and Kids | Shared feature spread, flatter prompts/headings, single-scroll search/tracker, exact shared card geometry | Browse/Kids/tracker/geometry tests; no live tracker account acceptance |
| Discover and Search | Shared responsive grids, readable hierarchy, one scroll owner, keyboard-aware heading | Browse tests, EN/AR screenshots, short keyboard viewport at 200% text |
| Library and lists | Responsive library index, flat list ledger, finite horizontal cards, shared picker scrolling | History/list/collection tests and explicit horizontal watchlist regressions |
| Shared collections | Editorial collection header, natural artwork rows, readable owner/member ledger, bounded forms | Permission/service tests and EN/AR enlarged-text row tests; live Realtime remains separate |
| Downloads, Calendar, Live TV | Flat transfer groups and actions, date-led episodes, natural channel/program layouts | Existing download/browse/layout tests; no OS background-transfer or live-stream acceptance |
| Media and sources | Wide overview/actions layout, correct artwork quality, bounded menus, flexible source filters | Detail captures, viewport tests, existing source/episode tests |
| Player | Shared theme, bounded sheets, wrapping panel navigation | Existing playback/session/episode/panel tests; video transport composition and engine ownership retained |
| Settings | Flat shared page/section/tile components, searchable hub, split wide layout, revised integrations/forms, inline OAuth errors | Settings, auth recovery, service and fixture checks |
| Personalization | Live card size/orientation/radius/reset, independent quality settings, trailer policy, actual Android dock preview, Kids inheritance | Persistence/CDN/geometry/navigation tests and EN/AR fixture matrix |
| Data, privacy, About, icons, catalog controls | Redesigned shared settings primitives and theme; unclipped privacy explanations | Existing behavior tests and selected settings fixtures; native icon switching and update installation remain device checks |
| Torrent and shared overlays | Lazy file slivers, bounded anchored menus, readable state messages and color preview | Exact file-index/lazy-build and overlay/layout tests; native torrent runtime unchanged |

The source inventory in [audit.md](audit.md) includes all known pages and
secondary surfaces. Some retain their established composition and receive the
new shared components/materials: confirmation dialogs, parental PIN and toast
surfaces, episode lists, Core/Legacy transport chrome, several service preference
bodies, and About/update surfaces. They are not claimed as individually
recomposed or exhaustively photographed. See [screen-families.md](screen-families.md)
and [media-player.md](media-player.md) for the exact boundary.

## Executed checks

| Check | Result |
|---|---|
| Baseline Home/Detail fixture suite before edits | 18 passed |
| Integrated regression run after geometry/navigation fixes | 180 passed |
| Search field wholly above keyboard at 200%, EN/AR | 2 passed |
| Full integration suite | **1,009 passed**, zero failures — `build/redesign-final-tests.log` |
| Final iOS capability/bridge/shell and trailer-policy follow-up | **25 passed**, including the two later capability-transition tests — `build/redesign-platform-final-tests.log` |
| Final notification-copy captures | **8 passed** — `build/redesign-notification-captures.log` |
| Flutter analysis | **No issues** in full analysis and the later targeted check of 10 changed files — `build/redesign-final-analyze.log`, `build/redesign-final-targeted-analyze.log` |
| Android debug APK | **Built successfully** after final production edits — `build/app/outputs/flutter-apk/app-debug.apk`; log `build/redesign-android-build.log` |
| Formatting, UTF-8 and diff whitespace | 86 authored Dart files pass formatting; localization follows the repository generator output; UTF-8 valid, 1,423 matching bilingual keys, `git diff --check` passed |
| iOS compilation / iPhone / iPad runtime | NOT VERIFIED — no Mac/Xcode or physical-device run |

The earlier broad runs found and led to fixes for an OAuth error toast covering
Finish, obsolete geometry assertions, Stats semantics expecting a numeric
progress value, and lazy-fixture setup. The final result below supersedes those
intermediate logs; tests were not removed or skipped to conceal failures.
The 25-test follow-up covers the native-capability changes made after the full
integration run; the full-suite count is not inflated by adding overlapping
focused tests. The Android build reports existing toolchain/deprecation notices
but completed successfully; it is a Debug build, not a signed release proof.

Reproduce the main checks from the repository root:

```powershell
flutter analyze --no-pub
flutter test --no-pub --concurrency=4 --dart-define=NOVA_WRITE_ACCEPTANCE=true --reporter expanded
flutter build apk --debug --no-pub
git diff --check
```

No emulator was started. No backend migration, production write, commit or push
is part of this redesign work.

## Rendered evidence

`test/redesign_surface_matrix_test.dart` covers 18 selected pages × English/Arabic
× light/dark × 390×844 phone/1024×768 tablet = 144 normal-layout captures.
Eight additional captures stress Search with keyboard, Welcome, Card Customization
and Privacy at 200% text. Two additional dock tests check physical RTL/LTR order
and route callbacks. Fonts are loaded from bundled Poppins, IBM Plex Sans Arabic,
Lucide and Material assets.

`test/nova_visual_acceptance_test.dart` supplies 36 Home/Detail initial/scrolled
captures, including narrow 320×640 and 200% Home cases. Artwork is deliberately
generated test-fixture content, not live provider data. Captures live in
`build/nova-review/redesign/` and `build/nova-review/acceptance/`; the baseline is
in `build/nova-review/before/acceptance/`. The final total is **188 images**.

Individual capture review includes Home tablet RTL/light, Welcome tablet
LTR/dark, Cards phone RTL/light, Downloads phone LTR/light, Settings tablet
LTR/dark, Navigation phone RTL/light, and the keyboard/text stress cases.
Twelve contact sheets were inspected for consistency across all 18 captured
families on phone/tablet layouts. A compact overview is saved in
[`screenshots/overview.png`](screenshots/overview.png).
Screenshot success is not a claim that every screen, transient state, focus
sequence, permission dialog and device category has been manually exercised.

## Remaining platform acceptance

- Build on Xcode26/Codemagic and exercise the native iOS26 phone tabs and iPad
  glass sidebar in both directions, split-window sizes and orientations. Verify
  refraction, safe areas, dynamic type, VoiceOver and system transparency changes.
- On Android phone/tablet, verify actual system palette changes, TalkBack,
  keyboard behavior, touch feedback, rotation and performance. The debug APK
  establishes compilation, not measured frame pacing or memory.
- Exercise real Hero provider embeds: missing/blocked metadata, initial loading,
  mute/unmute/stop, the three autoplay modes, network transitions, power/data
  saver, route coverage, scroll visibility and lifecycle retirement. Only
  supported YouTube trailers/promos are embedded; other providers retain posters.
- Confirm perceived artwork quality and bandwidth on devices. Recognized TMDB
  URLs use valid role-specific sizes; other/signed provider URLs stay intact.
  Original source quality still has a bounded decoded texture. A separate
  cellular artwork-quality switch was considered but is not exposed app-wide.
- Exercise authenticated services, account recovery, real collection revisions,
  OS downloads, icon switching, update installation and native media playback.
  These flows retain their functional contracts; fixture tests do not prove
  remote-service or OS behavior.

Lead conclusion: the known source inventory and the reported automated matrix
have been reviewed. A blanket “no page or detail missed in every platform and
state” certification is not supported by the available device evidence. Native
acceptance and exhaustive screen-by-screen runtime review remain open.
