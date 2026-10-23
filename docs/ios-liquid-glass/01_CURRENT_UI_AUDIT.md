# Current NOVA UI and toolchain audit

Historical Stage 0 baseline, inspected on 2026-10-23 at `2ec313bfd18dc72de3281c999ab5207c3cd23d38` on `feature/player-reengineering`. The checkout contained unrelated modified and untracked files before Stage 0; those edits were preserved. The deployment target, native UI and migration classifications below describe that initial snapshot; use `18_STAGE_7.md` for the current implementation.

## Toolchain and platform

| Item | Source-level observation |
|---|---|
| Flutter/Dart | Installed Flutter `3.49.0-0.2.pre` beta; Dart `3.14.0-211.1.beta` on `windows_x64`; `pubspec.yaml` allows Dart `>=3.5.0 <4.0.0`. |
| Xcode project | `ios/Runner.xcodeproj/project.pbxproj` specifies `IPHONEOS_DEPLOYMENT_TARGET = 13.0`, `SWIFT_VERSION = 5.0`, iPhone+iPad `TARGETED_DEVICE_FAMILY = "1,2"`. No `ios/Podfile` exists in this checkout. |
| iOS host | `ios/Runner/AppDelegate.swift` is a `FlutterAppDelegate` and `FlutterImplicitEngineDelegate`; `SceneDelegate.swift` extends `FlutterSceneDelegate` and registers the `noor/links` EventChannel through the `FlutterViewController` messenger. `Info.plist` enables one scene and portrait/landscape orientations. |
| Native UI | UIKit is used for the host; no NOVA SwiftUI views, UI `PlatformView` registration, native tab bar, or native glass integration was found. Generated Objective-C plugin registration is not application UI. |
| Available validation | Windows Flutter/Dart source checks; no Xcode, Swift compiler, iOS SDK, simulator or iOS device on this host. Native compilation/runtime/appearance are **NOT VERIFIED**. |

## Application architecture

`lib/app/noor_app.dart` builds a `MaterialApp` with Arabic/English locale, theme selection, `ChangeNotifierProvider<AppState>` and launch gate. `lib/core/theme/nova_theme.dart` defines semantic palette, motion and Material component themes. `MainShell` in `lib/features/shell/main_shell.dart` owns five tabs, lazy visited pages, scroll chrome, search, and Kids gate. Secondary pages use Flutter `Navigator` / `MaterialPageRoute`. Responsive behavior uses `MediaQuery` and layout constraints: a phone dock below 840 dp and a rail above it. `lib/l10n` supplies bilingual copy. `reduceMotion` and `reduceTransparency` are existing app settings; Flutter also reads `MediaQuery` accessibility flags in some chrome.

## Surface inventory

All entries below are currently Flutter UI unless marked host-only. “Glass” in a class name is a NOVA style, **not** Apple-native Liquid Glass.

| Group | Actual files/widgets | Current form | Stage classification |
|---|---|---|---|
| Shell phone | `shell/main_shell.dart` `MainShell`; `shell/glass_dock.dart` `GlassDock`; `shared/widgets/glass_navigation.dart` `GlassSearchButton` | Custom Flutter Material/painted dock, scrub gesture, three styles, scroll hide; search button | NATIVE candidate for iOS 26; fallback retained |
| Shell tablet | `MainShell._TabletNavigation` | Flutter rail and secondary destinations | INVESTIGATE native sidebar; KEEP meanwhile |
| Search | `shell/search_sheet.dart` `SearchSheet` | Flutter modal bottom sheet, text/results | ADAPT entry/presentation; KEEP results |
| Browse | `home/home_page.dart`, `home/widgets/featured_hero.dart`, `anime/anime_page.dart`, `kids/kids_page.dart`, `library/library_page.dart`, `shared/widgets/{poster_card,media_rail,nova_network_image}.dart` | Content, cards, rails, loading/error states | KEEP content |
| Other destinations | `catalog/{catalog_browser_page,catalog_grid_page}.dart`, `calendar/calendar_page.dart`, `live_tv/live_tv_page.dart`, `downloads/downloads_page.dart`, `settings/stats_page.dart` | Material `Scaffold`/`AppBar`, lists, grids, actions | ADAPT chrome; KEEP content |
| Media detail | `media/media_detail_page.dart`, `detail_hero.dart`, `detail_glass.dart`, `episode_views.dart`, `sources_page.dart` | Flutter hero, back/action pills, custom anchored menu, episode/source controls | ADAPT chrome; KEEP artwork and source workflow |
| Settings | `settings/settings_page.dart`, `settings_display_page.dart`, `settings_preferences_page.dart`, `integrations_page.dart`, `addons_page.dart`, `catalog_settings_page.dart`, `settings_data_page.dart`, `widgets/settings_tiles.dart` | Material switches, sliders, dropdowns, forms, dialogs and sheets | ADAPT selected controls; KEEP data/forms |
| Lists/modals | `library/custom_lists_page.dart`, `custom_list_picker.dart`, `anime/anime_search_sheet.dart`, `anime_tracker_sheet.dart`, `shared/widgets/color_picker_dialog.dart` | Flutter dialogs and bottom sheets | INVESTIGATE simple native presentations only |
| Player | `player/{core_video_player_page,video_player_page}.dart`, `player/widgets/{player_chrome,player_side_panel,player_sheets,player_episodes_sheet,subtitle_overlay,player_skip_segment_pill}.dart` | Flutter overlay controls above media_kit video | KEEP and protect |
| Launch/feedback | `splash/nova_splash.dart`, `onboarding/onboarding_page.dart`, `shared/widgets/{shimmer_box,app_state_message,noor_toast}.dart` | Flutter status and content UI | KEEP |

`GlassDock` and `detail_glass.dart` deliberately retired live `BackdropFilter` work for scrolling performance. `GlassSearchButton` uses a static tinted Material surface. Preserve those performance decisions for all fallbacks. Existing tests cover portions of layout, shell, settings and player; they do not validate iOS-native material.
