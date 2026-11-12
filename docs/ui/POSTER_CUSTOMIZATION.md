# Poster card customization

Implemented 2026-11-11. Open Settings → Display or Appearance → Card customization.

## Reference investigation

The user supplied the local `player-refereences/harbor` and
`player-refereences/NuvioMobile` source trees. Neither is a Git checkout, so
file hashes identify this inspection rather than an invented revision.

Harbor was inspected with the connected REA MCP server using
`analyze_javascript_application` (directory, selected sources, summary).
Six sources parsed with zero parse failures: `poster-card-section.tsx`,
`poster-options.tsx`, `settings/types.ts`, `settings/defaults.ts`, `row.tsx`
and `tv-card.tsx`. Paths are under `src/`; settings UI files are under
`views/settings/theme-panel/display/`, settings data under `lib/`, and row/TV
presenters under `components/`.

- Parent REA evidence: `ev_d4564651e0fd9257a2e5ab4387fc32f1130bf86bc1c72e89c3673e6964ee255c`.
- Recorded tree digest: `6b29ce445588057761a282757cbc049ab29d673f161d804145a6eac9582dd9a1`.
- Local complete evidence export: `.codex/poster-customization-rea-evidence.json`
  (about 94 MB; local analysis output, not an application asset).
- The graph is explicitly partial: 5,298 unselected files, unresolved dynamic
  behavior and static inference remain outside proof. The additional literal
  `posterScale` feature trace returned no graph match; it does not establish
  absence. The findings below come from the selected source bytes and their
  explicit controls/formulas, not that empty trace or runtime observation.

NuvioMobile is Kotlin/Compose source. No built APK/IPA was supplied in that tree.
Its Kotlin files were read directly; REA's JavaScript analyzer was not presented
as a Kotlin decompiler. No installation, app execution or emulator was needed.

| Capability | Harbor source | NuvioMobile source | NOVA |
| --- | --- | --- | --- |
| Live preview | `PosterCardSection` | `PosterCustomizationSettingsPage` | Actual shared `PosterCard` |
| Size | Six scale presets: .8, .9, 1, 1.15, 1.3, 1.5 | Width presets: 104, 112, 120, 126, 134, 140 dp; proportional height | Six scale presets plus 80–150% slider |
| Corners | 0–40 px, presets 0/6/12/18/28 | Presets 0/4/8/12/16 dp | 0–40 logical pixels with Harbor presets |
| Wide cards | Poster/TV; wide artwork and logo | Catalog landscape option | Portrait or 16:9; background with poster fallback |
| Labels/logo | Three logical logo positions | Hide labels, always-show landscape logo | Hide labels; optional landscape logo and logical start/center/end |
| Reset | Other settings controls | `resetToDefaults` | Resets only six card appearance keys |

Relevant Nuvio files are under
`composeApp/src/commonMain/kotlin/com/nuvio/app/`:
`core/ui/PosterCardStyleRepository.kt`,
`features/settings/PosterCustomizationSettingsPage.kt` (poster controls near
lines 735–790), and `core/ui/ShelfComponents.kt` (width/shape consumption).
`setWidthDp` derives height as width × 3 / 2. The default is 126×189, radius 12.
NOVA retains its existing default width/portrait ratio rather than changing all
existing poster geometry just to match those numbers.

Source SHA-256:

| Source | SHA-256 |
| --- | --- |
| Harbor poster options | `e31b423cfae9029a59c996ebe1f023d3ea5fc5bb6c1e40181c92680f772fdbb4` |
| Harbor poster section | `f50822f3cd5e2144f4b1ad74154b431245ffe7409b0f2017996dd18e3b960282` |
| Nuvio repository | `3044ba5515a88abe2c40acdc13320dd66785bce66fb36f3a205fcca71ba017c4` |
| Nuvio customization page | `1df53573d13a8090669446f893b69397a374438ae0d4aa46e61827d0e2b45cd9` |

Behavior was independently implemented in Dart using NOVA components and theme
roles. Reference source code and assets are not bundled.

## Ownership and persistence

- `lib/core/models/poster_card_style.dart` validates the existing `posterScale`,
  `posterRadius`, `hidePosterTitles` keys plus `posterShape`, `showPosterLogo`,
  `posterLogoPosition` and `posterArtworkQuality`. Invalid/nonfinite numbers fall back or clamp safely.
- Card and hero quality use `posterArtworkQuality` and `heroArtworkQuality` in
  the existing `AppState.setSetting` persistence/sync path. Cards default to
  balanced and heroes to high. Low/balanced/high select bounded decoded image
  sizes; TMDB artwork also uses a matching source size, with high requesting
  the original. Add-on image URLs remain unchanged.
  No storage keys, backend schema, account/profile scope or provider secrets change.
- `poster_card_settings_page.dart` keeps slider drafts local for immediate preview
  and saves on release. Presets and toggles save immediately. Appearance and
  Display open the same page; Display search keywords include card shape/size.
- `PosterCard` chooses artwork, ratio, corners, labels and logo. Hidden labels
  preserve the accessible title and existing tap/long-press actions.
- `poster_layout.dart` measures localized label fonts at the active text scale.
  Rails, Top 10, loading placeholders and every `PosterCard` grid use shared
  geometry. Owning widgets subscribe to style before `SliverLayoutBuilder` runs;
  layout callbacks receive that immutable style rather than calling Provider
  `select` during sliver layout.
- Catalogs, Home/Anime/Kids rails, Kids grids, both searches, watchlist and custom
  list grids update without reloading catalog data. Kids retains its existing
  size preference as the base grid density. A wide/large card can use one column.
- The card quality selector affects media browsing cards and title logos. The
  hero quality selector affects Home, Anime, Kids and detail artwork. Continue
  Watching, episode thumbnails and compact inline list thumbnails retain their
  own image sizing.

## Verification boundary

`test/poster_customization_test.dart` covers legacy/invalid preferences,
phone/tablet constraints, Arabic/English, both themes, 200% text, portrait/wide
rails and grids, settings layout, preview-before-save, reset scope, wide artwork
and logo selection, hidden-label semantics, live catalog sliver relayout and
settings persistence across AppState reconstruction. Existing settings, browse,
Kids, cinematic layout and rating-badge suites provide regression coverage.

This is Flutter static/widget evidence. Physical Android/iPhone appearance,
real artwork/logo availability and multi-device settings sync are not verified
by these checks. No native/iOS build or player acceptance gate is implied.

Validation on 2026-11-11:

- `flutter analyze --no-pub`: no issues.
- Seven related test files (customization, rating badges, settings, cinematic
  layouts, browse, Kids and Top 10): 90 tests passed.
- After the final Top 10 tap-preservation change and added live-catalog test,
  customization plus Top 10: 31 tests passed (overlaps the preceding run).
- `dart format --output=none --set-exit-if-changed` on the 18 changed/new Dart
  UI/model/test files: no changes; `git diff --check`: passed.
- Local logs: `.codex/poster-analysis.log`, `.codex/poster-regression-tests.log`,
  `.codex/poster-final-tests.log`.
