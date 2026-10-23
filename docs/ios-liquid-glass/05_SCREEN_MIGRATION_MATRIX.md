# Screen migration matrix

The table below is the Stage 0 target matrix: KEEP content; ADAPT platform presentation; NATIVE possible native control; INVESTIGATE gated proof. It is retained for planning history. Stages 2–6 resolved the actual native scope below; `18_STAGE_7.md` is the current five-tier behavior matrix. iOS 15–25 currently uses Flutter fallback, and no iOS native rendering has runtime proof.

| Surface / current file | Current implementation | iOS 26+ target | Complexity/risk | Dependencies and acceptance |
|---|---|---|---|---|
| Phone dock `lib/features/shell/{main_shell,glass_dock}.dart` | Flutter custom scrub dock, scroll hide and size preferences | NATIVE system tab bar if composition passes | High/high | Flutter-selected tab, Kids gate, five IDs, safe areas, RTL, VoiceOver, modal order |
| Tablet rail `main_shell.dart` | Flutter rail and secondary links | KEEP FLUTTER RAIL (Stage 6); compact iPad uses existing Flutter dock | High/high | One Flutter navigation owner; iPad resizing/landscape runtime proof pending |
| Search `shell/search_sheet.dart`, `shared/widgets/glass_navigation.dart` | Flutter search button and sheet | ADAPT entry/presentation; KEEP results | Medium/medium | Keyboard, focus, Arabic, dismissal |
| Home `home/home_page.dart`, `home/widgets/*` | Hero, rails, cards, loading/error | KEEP content | Low/medium | Scroll frame time, artwork and large text |
| Anime/Kids/Library `features/{anime,kids,library}/*` | Catalogs, protected Kids, lists/history | KEEP; ADAPT chrome only | Medium/high | Kids lock, route state, linked progress |
| Catalog `catalog/{catalog_browser_page,catalog_grid_page}.dart` | Material bars, filters, grid | ADAPT bars/filter control; KEEP content | Medium/medium | Filters and large grid scrolling |
| Calendar/Live TV/Downloads/Stats `features/{calendar,live_tv,downloads,settings/stats_page}.dart` | Material pages/actions | ADAPT chrome; KEEP lists/data | Medium/medium | Actions, errors, navigation |
| Detail `media/{media_detail_page,detail_hero,detail_glass,episode_views}.dart` | Flutter hero, pills, anchored menu, episode UI | ADAPT back/actions/menu; KEEP artwork/episodes | Medium/high | Source picker, artwork contrast, RTL |
| Sources `media/sources_page.dart` | Flutter list and preparation flow | KEEP list; ADAPT small chrome only | Medium/high | Source selection, cancellation, errors |
| Settings `settings/{settings_page,settings_display_page,settings_preferences_page,settings_data_page,integrations_page,addons_page,catalog_settings_page}.dart`; `settings/widgets/settings_tiles.dart` | Material forms, switches, sliders, dropdowns and dialogs | ADAPT selected controls; KEEP dense forms | Medium/medium | Persisted settings, text scale, keyboard, access labels |
| Library/Anime modal flows `library/{custom_lists_page,custom_list_picker}.dart`, `anime/{anime_search_sheet,anime_tracker_sheet}.dart` | Flutter dialogs/sheets | INVESTIGATE bounded native choices; KEEP complex forms | Medium/high | Async result/dismissal and RTL |
| Player `player/{core_video_player_page,video_player_page}.dart`, `player/widgets/*` | media_kit video with Flutter controls/panels | KEEP in Stage 0 and initial migration | High/high | Frame time, gestures, subtitles, source continuity, landscape |
| Splash/onboarding/shared feedback `splash/`, `onboarding/`, `shared/widgets/` | Flutter status and content | KEEP | Low/low | Accessibility and state recovery |

No content card, poster, full-screen video, grid or text-heavy setting is a Liquid Glass target. See `01_CURRENT_UI_AUDIT.md` for widget-level evidence and `07_PLAYER_INTEGRATION.md` for player exclusion.

## Stage 2 source implementation (2026-10-23)

The iPhone path now uses a scene-scoped standalone UIKit `UITabBar` over the single `FlutterViewController` on iOS 26+, selected by a capability handshake. `MainShell` remains the sole selected-tab and Kids-gate authority. Stable IDs are `home`, `anime`, `kids`, `library`, `settings`; Flutter supplies Arabic/English labels, direction, visibility and confirmed selection. UIKit SF Symbols are `house`, `sparkles`, `figure.child`, `books.vertical`, `gearshape`. Native taps send intent and restore the previously confirmed selection until Flutter publishes a new snapshot. Reselect preserves the existing chrome-reveal behavior; custom dock scrub is absent on the native path per LG-03. A Navigator observer hides chrome for pushed routes and sheets; scroll sends visibility changes. The existing Flutter content clearance remains, pending iOS visual proof. iOS 15–25 and Android keep GlassDock; tablet keeps its rail. Swift compilation, native composition, safe-area and accessibility runtime checks remain IOS BUILD PENDING CODEMAGIC / IOS RUNTIME PENDING. Stage 3 source work is described below.

## Stage 3 source decision (2026-10-23)

Stage 3's exact per-surface NATIVE / KEEP / DEFER decisions and source files are in `14_STAGE_3.md`. The Home search **entry** is NATIVE on iOS 26 phones; the search sheet/results and Flutter-owned route bars remain KEEP. Detail overflow and source/player controls are DEFER. Earlier matrix targets are proposals, not a claim that every row received native UI.

## Stage 4 source decision (2026-10-23)

`15_STAGE_4.md` supersedes the earlier detail proposal: back, share and the bounded More menu are NATIVE on capable iOS 26 phones; their actions remain Flutter-owned. Watchlist, play/resume, download, artwork, episodes, source/list/tracker workflows and player remain KEEP. Episode long-press and other complex presentations are DEFER. iOS 15–25, Android and iPad keep the existing Flutter detail chrome. Native build and runtime remain pending.

`17_STAGE_6.md` closes the iPad sidebar investigation at source level: the rail and its nine secondary Flutter routes retain one Flutter navigation owner. iPad compact windows use the existing dock; native phone chrome is gated by UIKit phone idiom even when a phone window is wider than the old 840-pixel threshold. Accessibility, RTL, safe areas, and modal composition remain runtime acceptance items.

## Stage 5 player decision (2026-10-23)

The player row is resolved by the complete surface matrix in `16_STAGE_5.md`: video and timeline are DO NOT MIGRATE; transport, subtitles, gestures, panels, skip and up-next remain KEEP FLUTTER. Close/settings are DEFER while their overlay and route coupling is unproven; PiP and Cast/AirPlay are absent. No native player control was introduced. Shell chrome is hidden for the player route at source/state level; iOS runtime verification remains pending.
