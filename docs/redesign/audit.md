# Existing UI inventory and issue ledger

Audited from source on 2026-11-04. Risks below are distinguished from observed
test failures. No emulator or physical-device evidence is implied.

## Problems and redesign treatment

| ID | Existing evidence / problem | Treatment |
|---|---|---|
| A01 | `detail_glass.dart`: anchor top clamped independently of menu height; width unbounded | Safe viewport geometry, flip above anchor and scroll within available height |
| A02 | Color picker outline preview uses theme-dependent dark ink on fixed dark canvas | Fixed light foreground for the fixed media canvas |
| A03 | Search has fixed 94% height, keyboard padding and non-scrolling header | Header, fields, filters and results share a bounded scroll surface |
| A04 | Anime tracker fixed 88% height and non-scrolling heading | Safe-area/keyboard-aware scrollable contents |
| A05 | Stats reserves 80px date and 24px count | Flexible/stacked history rows |
| A06 | Inconsistent control/sheet/content shapes and flat type hierarchy | Shared platform theme roles and grouped editorial page layouts |
| A07 | Titles truncate in posters, history and collections | Explicit max lines, full semantic labels, retained detail/quick-look actions |
| A08 | Anime prompt hardcodes translucent white decoration in light mode | Semantic theme roles |
| A09 | Hero has still-image carousel only | Delayed, muted, visibility/power/network-gated OS WebView trailer preview |
| A10 | Card size and orientation distributed through fixed rail/grid geometry | Shared immutable card preferences and dimensions used by consumers |
| A11 | One image decode policy; no separate Hero/card choice | Independent Auto/Low/Medium/High/Original CDN/decode budgets |
| A12 | Continue Watching labels compete with busy images | Separate artwork and readable progress/title/provider area |
| A13 | iPad uses a small icon-only Flutter rail | Adaptive labeled sidebar; native iOS26 glass overlay with Flutter route ownership |
| A14 | Decorative zoom continues through Hero artwork | Static artwork, bounded transitions, reduced-motion-aware preview and slide policy |
| A15 | OAuth retry error toast could cover Finish on a short form | Error becomes an inline, wrapping field message; retry remains reachable |
| A16 | Narrow player panels crowd title, close and navigation in one row | Title/close row followed by wrapping navigation; tap callbacks retained |
| A17 | Android navigation style preview showed Flutter glass after the shell moved to M3 | Preview uses the real Material dock; compact/mini geometry is distinct; platform scope is explained |
| A18 | A poster used as Hero/CW fallback could be resized with the backdrop CDN ladder | Carry the actual artwork role through loading and precaching; regression tests cover poster-only titles |
| A19 | Kids' legacy default size masked the global size and could diverge from grid geometry | Default inherits global size; explicit Kids overrides pass the same preferences into grid and card |
| A20 | Watchlist passed infinite width into horizontal card height calculation | Grid passes its finite cell width; EN/AR 200% text regression cases |
| A21 | Long credential/profile helper messages could be softly truncated | Allow multiline helper copy in account/profile forms |
| A22 | Collection ListTile constrained its requested 88px poster to a 56px leading area | Natural row owns artwork height and wraps metadata/actions |
| A23 | Torrent season-pack file selection built every row eagerly inside a shrink-wrapped list | Use lazy file slivers in the same scroll owner |
| A24 | Privacy action descriptions were capped at two lines | Natural-height explanations retain restore/clear context at larger text sizes |
| A25 | A 200% Arabic search heading could push the input behind a short keyboard viewport despite no overflow | Use a smaller heading role in constrained viewports; assert the entire field remains visible |
| A26 | A bottom poster scrim remained after labels moved outside artwork | Remove the unused scrim, including from no-artwork placeholders |
| A27 | Native capability detection could stay stale after a system accessibility change | Refresh on resume and Reduce Transparency notifications, immediately retire overlays and invalidate old intents |
| A28 | Notifications help referred only to Android despite the iOS download path | Platform-neutral bilingual help describes device download notifications |

The integration review also corrected new trailer lifecycle hazards before
delivery: undersized previews now retire, stale generations cannot restart a
controller, loading is included in the lifetime cap, missing metadata is
retryable, and carousel touch/preview state does not keep a replaced slide alive.

## Complete surface inventory

Paths are relative to `lib/`. Each family includes its loading, empty, error,
selected, disabled, focus and press states where meaningful. A shared-theme
change does not, by itself, establish a screen-specific visual review.

| Family | Pages and secondary surfaces | Owning source |
|---|---|---|
| Launch | Splash, init/error, onboarding, required update | `app/noor_app.dart`, `features/splash/`, `features/onboarding/` |
| Account gate | Sign-in, verification, recovery, guest upgrade, username, first/default profile unlock | `app/account_gate.dart` |
| Credentials | Welcome, sign-in, sign-up, reset, verification, username, new password, guest upgrade | `features/account/auth_pages.dart` |
| Profiles | Picker, editor, management, avatar grid, PIN and deletion dialogs | `features/account/profile_pages.dart` |
| Account settings | Session/profile information and confirmation dialogs | `app/account_settings_section.dart` |
| Shell | Five destinations, Kids gate, search entry, floating dock, sidebar, native chrome | `features/shell/main_shell.dart`, dock files, native bridge |
| Search | Search sheet, filters, results, Discover/Live TV/Calendar/Downloads/Stats/Add-ons shortcuts | `features/shell/search_sheet.dart` |
| Home | Hero, carousel, trailer, categories, local/linked Continue Watching, Top 10, all catalog rails | `features/home/` |
| Anime | Browse, linked-library prompt, search and tracker sheets, tracker removal | `features/anime/` |
| Kids | Protected browse, filters, family metadata, detail entry | `features/kids/` |
| Discover | Unified catalog browser, standalone catalog grid, sorting/type filters | `features/catalog/` |
| Calendar | Days, upcoming episodes, empty/loading | `features/calendar/` |
| Live TV | Playlists, channels, add/remove playlist dialogs | `features/live_tv/` |
| Library | Watchlist, history, empty library, actions | `features/library/library_page.dart` |
| Custom lists | Panel, detail, picker, create/edit/import/delete dialogs | `features/library/custom_*` |
| Shared collections | Panel, picker, join/create, detail, item forms, owner/member grants, invitation, leave/delete | `features/shared_collections/` |
| Downloads | Active/ready/failed/cancelled groups, posters, progress, actions, removal dialog | `features/downloads/` |
| Details | Hero, metadata, facts, synopsis, ratings, service progress, comments, Letterboxd, people/production/recommendations | `features/media/` |
| Episodes | Seasons, sort/view controls, list/grid, watched progress, long-press actions | `features/media/episode_views.dart`, detail page |
| Sources | Source filters/list, unavailable state, selection and preparation dialog | `features/media/sources_page.dart` |
| Torrent | Magnet input, resolution, file choice, preparation and incoming-link state | `features/torrent/` |
| Core and Legacy | Entry, video, transport, timeline, gesture HUDs, lock, error, torrent HUD, exit | `features/player/*video_player_page.dart` and `widgets/player_chrome.dart` |
| Player panels | Sources/audio/subtitles/settings, delays, font picker/import, episodes, skip, Up Next | `features/player/widgets/` |
| Settings hub | Search, grouped destinations, wide detail pane | `features/settings/settings_page.dart` |
| Appearance | Theme, OLED, language, card preview/size/orientation/radius/reset, quality, trailer policy, icons, navigation style | personalization/display/icon/navigation pages |
| Playback | Engine/implementation, picture, resume, gestures, subtitle appearance/font/delay | preferences page and shared preference dialogs |
| Content | Catalog ordering/hiding, Kids controls, Add-ons/details | catalog/display/addons pages |
| Integrations | Trakt, Simkl, AniList, MAL, MDBList, TMDB, Debrid, skip services, Letterboxd | integrations/Letterboxd/service cards |
| Data | Account sync, torrent downloads, import/backup/restore/cache, storage/privacy | data page and restore/cache sheets |
| About | Branding/version, update availability/download/progress/errors | data page About and update dialogs |
| Statistics | Metrics/history/date ranges | stats page |
| Shared overlays | Quick look, color picker, parental PIN, toast, anchored menu, confirmation dialogs | `shared/widgets/`, `features/media/detail_glass.dart` |

## Existing evidence reused

`nova_visual_acceptance_test.dart` renders fixture Home/Detail in EN/AR,
light/dark, phone/tablet, with bundled fonts and generated local artwork.
Baseline: 18 tests passed before redesign; captures copied to
`build/nova-review/before/acceptance/`. Additional account, source, player,
settings, storage, collections and shell tests exercise their own flow/layout
contracts. See the final QA report for actual executed results, not inferred coverage.
