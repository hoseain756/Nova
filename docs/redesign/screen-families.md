# Account and secondary screen families

Source review and presentation changes on 2026-11-04. This file records the
assigned families, separate from shared theme changes and from root QA results.
No emulator was launched. No physical-device, native iOS, provider-account,
multi-device Realtime, or screen-reader runtime acceptance is claimed here.

## Direct presentation changes

| Source | Recomposition and retained behavior |
|---|---|
| `lib/features/account/auth_pages.dart` | Shared credential layout becomes a wide editorial introduction/form spread and a natural phone scroll. Welcome, sign-in, sign-up, recovery, verification, username completion, new password, and guest upgrade retain their validators, secure field flags, callbacks, busy/error/success states, autofill, and route behavior. |
| `lib/features/account/profile_pages.dart` | Portrait-led, wrapping profile choices replace settings rows; avatar editor uses a constraint-based gallery; profile artwork is larger; PIN dialog can scroll. Mandatory first profile, five-profile limit, URL preview checks, PIN verification, protected edit/delete/default actions, and default-profile behavior are preserved. |
| `lib/app/account_settings_section.dart` | Session identity becomes an editorial account heading above flat action rows. Switching, sign-out, upgrade, recovery, legacy import confirmation, and failure restoration use the existing methods. |
| `lib/features/library/library_page.dart` | A responsive watchlist/history/collection index replaces chip navigation. History has larger titles and readable artwork. Watchlist grid consumes shared card preferences; remove/undo, torrent resume, query/sort, downloads, and magnet entry remain wired. |
| `lib/features/library/custom_lists_page.dart` | Private list panel is a flat artwork ledger; detail grid consumes card size/orientation; empty state uses a directional rule; import dialog scrolls. Create/edit/share/import/delete and item remove/undo keep existing calls. |
| `lib/features/library/custom_list_picker.dart` | Title, list choices, empty content, create action, and shared-collection action now share one lazy scroll owner. Already-added rows remain disabled. |
| `lib/features/shared_collections/shared_collections_panel.dart` | Editorial collection heading/actions, larger flat rows, scrollable join form, and less restrictive form width. Service loads, Realtime generations, retry, invite parsing, and membership routing are unchanged. |
| `lib/features/shared_collections/shared_collection_picker.dart` | Single scrolling heading/choices/empty state; keeps the original server-membership filtering for writable collections and unchanged item identity. |
| `lib/features/shared_collections/shared_collection_detail_page.dart` | Collection title/member count/actions move into a full editorial header; item rows build lazily, with larger artwork and titles. Owner/member permission checks, optimistic versions, conflict handling, manual-item forms, leave/delete/edit confirmations, and media routes are preserved. |
| `lib/features/shared_collections/shared_collection_control_page.dart` | Collection identity leads a wider flat control ledger with clearer member rows. Owner immutability, self/delegated grants, normalized View permissions, invite copy/share/rotation/disabling, and destructive confirmations remain unchanged. |
| `lib/features/downloads/downloads_view.dart` | Artwork-led flat transfer rows, title/summary header, visible section counts, larger posters, readable status and failure messages, and wrapping actions. Active/queued/ready/failed/cancelled, byte progress, indeterminate progress, storage errors, and accessibility action labels remain present. |
| `lib/features/downloads/downloads_page.dart` | Wider tablet content bound. Transfer initialization, polling, removal confirmation, retry/cancel/remove, and local playback ownership are unchanged. |
| `lib/features/anime/anime_page.dart` | Receives the shared artwork/copy spread and editorial heading; AniList invitation becomes a flat directional rule with theme-aware decoration. Filters, linked progress/rails, add-on rows, resolver identity, retry/empty/loading behavior are retained. |
| `lib/features/anime/anime_search_sheet.dart` | Search heading, field, provider choice, loading/error/empty content, and preference-aware results become one sliver scroll. Debounce, provider search, resolution, and media routes are preserved. |
| `lib/features/anime/anime_tracker_sheet.dart` | A natural single-scroll tracking ledger replaces the fixed-height header/body/footer. Status choices, progress nudges, score, retry, save/remove and per-provider outcomes retain their existing methods. Counter and score content can wrap at enlarged text. |
| `lib/features/kids/kids_page.dart` | Editorial safety heading replaces the solid promotional block. Shared feature spread and grid preferences retain the Kids card-size override. Certification/metadata filtering, family catalog selection, retry/loading/empty, and `kidsMode` detail entry are unchanged. |
| `lib/features/calendar/calendar_page.dart` | Episode cards become flat time/artwork/copy entries; wide layouts use a time gutter, phones flow naturally. Week/day filtering, cached loads, time formatting, retry, and exact episode routes are preserved. |
| `lib/features/live_tv/live_tv_page.dart` | Fixed-height channel cards become lazy, natural-height channel/program spreads; large windows place channel and guide side by side. Search/group/playlist filters, URL checks, add/remove forms, EPG progress, unavailable protocols, and playback callbacks remain intact. |
| `lib/features/onboarding/onboarding_page.dart` | Decorative icon cards and segmented controls become an editorial introduction and full-width language/appearance choices. All choices and completion retain existing settings keys/callbacks. Phone, tablet and large text use natural scrolling. |
| `lib/features/splash/nova_splash.dart` | Logo and footer share natural scroll flow, removing the tall-window footer overlay; diffusion is quieter. Existing brand geometry, completion timing, one-shot lifecycle, reduced motion and footer content remain intact. |
| `lib/features/torrent/magnet_opener.dart` | Single-scroll magnet workflow with flowing numbered steps, flat metadata and file selection, readable filename/size columns, and no nested file-list scroll. Input/resolve/choose/prepare callbacks, cancellation, native ownership, and playback behavior are preserved. |
| `lib/features/shell/search_sheet.dart` | Keyboard-safe single sliver scroll includes heading, field, filters, shortcut index, state messages and preference-aware results. Existing query debounce/generation/cache, retry, filter, close, and destination routes remain wired. |
| `lib/features/shell/nova_browse_widgets.dart` | Shared editorial header/rule, wide artwork/copy feature spread, flat shortcut entries, and reusable sheet/heading. Feature copy no longer competes with a fixed image overlay. Whole-feature semantics retain title/action and an explicit tap action. |
| `lib/features/settings/integrations_page.dart` | Linked-service index adapts to two columns; connection forms are flat sections; manual OAuth fields/actions stack; service headings are clearer. OAuth/device-code/PKCE/cancel/unlink, tracker switches, avatar checks, API keys, Debrid, provider status, sync and failures retain existing logic. |
| `lib/features/settings/addons_page.dart` | Installed add-ons use flat reorderable rows with clearer section separation and titles. Install field honors busy state; install, suggestions, drag/button reorder, enable, configure, copy, details, and removal confirmation remain functional. |
| `lib/features/settings/letterboxd_settings_page.dart` | Connection mode uses wrapping choices, session information/actions flow vertically, and forms/rows have flatter spacing in a wider layout. Public/Full/TOTP, bridge disclosure, secure session, custom lists, catalogs, ratings/review blur, Home order/hide and refresh retain their existing callbacks and restrictions. |
| `lib/features/settings/stats_page.dart` | Metrics become flat sections. Each activity date/count flows above its progress bar, eliminating fixed 80/24-pixel columns. Localized dates, metric values, history and clear-history confirmation remain unchanged. |
| `lib/features/settings/widgets/skip_timing_service_card.dart` | Flat service detail section with stronger title and busy-disabled secret field. Public/key status, secure key save/remove, error feedback, remove confirmation and external website actions remain unchanged. |

Anime/Kids feature artwork explicitly follows Hero image quality. Library
history and shared collection item thumbnails follow Card image quality, with
bounded decode widths. Download/private-list thumbnails received the same
Card-quality wiring from the personalization owner. Unknown provider URLs keep
their original paths through the shared image helper.

Follow-up compatibility fixes: Kids now offers an explicit **Use app card size**
choice. The old preseeded `kidsCardSize: medium` cannot be distinguished from an
old explicit Medium selection, so it inherits app-wide size; stored Small/Large
choices remain Kids overrides. New explicit Medium selections use
`mediumOverride` in the existing setting. `PosterCard.preferencesOverride`
keeps the Kids grid and actual card on identical dimensions. Watchlist cards
receive finite cell widths for horizontal orientation. Password, avatar URL,
and profile PIN helpers wrap through up to eight lines.

Shared collection item rows use natural Rows so their 64×88 artwork is not
limited by ListTile's leading-icon constraints. Magnet file choices are actual
SliverList children: large packs retain lazy rendering and the existing native
file indices, selection callback, and play action.

## Reviewed compatibility files

`lib/features/account/account_pages.dart` remains the export barrel with no
independent presentation. `lib/features/torrent/magnet_link_handler.dart`
remains the incoming-link/event wrapper; its auth, pending invite and tracker
completion behavior was preserved. Neither requires a cosmetic rewrite.
The account gate belongs to the integration owner and is not edited here.

## Validation handoff

All changed Dart files have passed parsing through `dart format`. New focused
tests in `test/nova_screen_families_layout_test.dart` cover the artwork/copy
spread at phone/tablet widths in EN/AR, light/dark and 200% text; a 320×300 sheet
with a 120-pixel keyboard inset; and portrait profile selection with long names.
They are handed to the root validation queue; this document does not claim they
have run. Root QA also owns the existing account/profile security-flow tests,
shared collection permission tests, downloads/onboarding matrix, anime/Kids
tests, Letterboxd tests, splash tests and visual fixture captures.

The Kids inherit choice uses the new `kidsCardSizeInherit` localization supplied
in both languages by the integration owner. No new packages, backend queries,
migrations, service API signatures, persisted keys, or native changes were
added by this worker. Remaining device/provider/runtime and screenshot coverage
is reported in `qa.md` by the integration owner, not inferred from these source
edits.

Additional regression files are `test/nova_card_geometry_regression_test.dart`
(Kids compatibility, exact card override sizing, and horizontal watchlist at
200% text in EN/AR phone/tablet) and
`test/nova_secondary_rows_regression_test.dart` (shared portrait geometry and
edit-only permissions in EN/AR at 200%, plus a lazy 1,000-file torrent pack).
Their execution remains owned by the root validation queue.
