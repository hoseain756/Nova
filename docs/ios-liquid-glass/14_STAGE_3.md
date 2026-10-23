# Stage 3 — secondary chrome source audit and decision

Source snapshot: `feature/player-reengineering` at `2ec313bfd18dc72de3281c999ab5207c3cd23d38` before edits, 2026-10-23. The working tree already contained Stage 1/2 and unrelated uncommitted work. This stage makes no commit. Classifications describe the Stage 3 choice, not native runtime proof.

| Surface | Current implementation and file | Class | Stage 3 result | Action ID / platform / remaining proof |
|---|---|---|---|---|
| Home search entry | `main_shell.dart` `GlassSearchButton` opens `SearchSheet` | NATIVE | iOS 26 phone uses a scene-scoped system `UIButton.Configuration.glass()` in the existing sibling overlay. Flutter still opens the same sheet. | `search`; iOS 15–25, Android and iPad keep Flutter button; verify safe area, touch, appearance and VoiceOver on device. |
| Home top actions | `home_page.dart` and `featured_hero.dart` content actions | KEEP | No other shell toolbar exists. Hero/card actions stay with their content. | None; check no duplicate search entry on iOS 26. |
| Search presentation/results | `search_sheet.dart` owns controller, debounce, filters, results, keyboard and dismissal | KEEP | Search intent calls `_openSearch`; sheet and logic stay in Flutter. Native `UISearchController` requires a navigation interface/results owner that this shell does not have. | `search`; test query/focus/dismissal on device. |
| Detail back and top actions | `detail_hero.dart` `DetailBackPill`, share/download/overflow; `media_detail_page.dart` owns callbacks | DEFER | Existing Flutter back and actions stay. Detail action migration is Stage 4; no native route stack is added. | Existing menu values `sources`, `list`, `track`; verify Flutter pop and modal order. |
| Catalog browser | `catalog_browser_page.dart` `AppBar` refresh and in-body query field | KEEP | Route bar and search field stay Flutter; moving the field would split query/focus ownership. | Existing refresh callback; verify route back. |
| Catalog grid | `catalog_grid_page.dart` `AppBar` filter/action | KEEP | Route bar stays Flutter with grid/filter state. | Existing callback; verify route back and filter. |
| Calendar | `calendar_page.dart` `AppBar` refresh and in-body week controls | KEEP | Route bar and stateful controls stay Flutter. | Existing callback; verify week state and back. |
| Live TV | `live_tv_page.dart` `AppBar` add playlist; search/group controls in content | KEEP | Form and content state stay Flutter. | Existing callback; verify dialog/keyboard. |
| Downloads | `downloads_page.dart` title-only `AppBar` | KEEP | Flutter route bar remains. Polling/list actions stay Flutter. | None; verify back and list state. |
| Stats | `settings/stats_page.dart` title-only `AppBar` | KEEP | Flutter route bar remains. | None; verify back. |
| Settings root | `settings_page.dart` title bar and local settings search | KEEP | In-tab search and forms stay Flutter. | None; verify tab/route semantics. |
| Account/integrations | `integrations_page.dart`, `addons_page.dart` route bars and forms | KEEP | Flutter route bars and account/add-on flows remain. | None; verify back and forms. |
| Other settings pages | `settings_data_page.dart`, `settings_display_page.dart`, `settings_preferences_page.dart`, `catalog_settings_page.dart` | KEEP | Route bars and controls stay Flutter. | None; verify state on pop. |
| Content/context menus | `detail_hero.dart` small overflow; episode sheets and other content actions | DEFER | No native menu in Stage 3 because each menu is anchored to Flutter content or belongs to Stage 4. Stable existing values remain. | `sources`, `list`, `track`; verify action state in Stage 4. |
| Source/player controls | `sources_page.dart`, `player/` | DEFER | Outside Stage 3. | No new native chrome; verify player remains obscured by neither search nor tab. |

## Architecture

The Stage 2 sibling overlay gains one iOS 26 glass-configured `UIButton` for the Home search entry. It is shown only for a visible Home route and receives a localized label, RTL placement and current appearance from Flutter's low-frequency presentation snapshot. Taps send `actionIntent` with stable ID `search` and the snapshot revision. Dart rejects stale revisions and unknown IDs, then the shell opens its existing Flutter sheet. No search query, keyboard event, result, form state or route tree crosses the bridge. There is no PlatformView, second Flutter engine or native navigation controller. Pushed routes and modals hide the native entry through the existing route observer. The iOS 15–25, Android and iPad entry remains `GlassSearchButton`.

Page-level native `UINavigationBar` was considered and rejected for this stage: Apple integrates it with `UINavigationController` and navigation items, while NOVA's secondary routes are `MaterialPageRoute`s owned by Flutter. Placing a disconnected native bar above those routes would duplicate back, transition, safe-area and modal state. Their existing Flutter bars remain the adaptive route-safe choice. The bounded detail overflow is intentionally deferred to Stage 4, matching `06_IMPLEMENTATION_PHASES.md`.

Official Apple references: [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass), [glass button configuration](https://developer.apple.com/documentation/uikit/uibutton/configuration-swift.struct/glass%28%29), [navigation bar integration](https://developer.apple.com/documentation/uikit/uinavigationcontroller), [search controller integration](https://developer.apple.com/documentation/uikit/uinavigationitem/searchcontroller). The button configuration is guarded by `#available(iOS 26.0, *)`; the overlay is created only on capable iOS 26 phones. Swift compilation is **IOS BUILD PENDING CODEMAGIC** and native behavior is **IOS RUNTIME PENDING**.

## Verification ledger

Final Windows commands and results are recorded in `09_TESTING_STRATEGY.md`. Device acceptance still needs iOS 26 light/dark, Arabic/English, increased text/contrast, reduced motion/transparency, VoiceOver, safe-area, sheet/keyboard layering and scene reconnection checks. iOS 15–25 and iPad require fallback runs. Stage 4 has not started.
