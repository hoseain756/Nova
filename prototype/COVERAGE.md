# Screen and interaction map

Routes below are hash paths. Direct opening creates a fixture session. In normal navigation, the route stack, originating destination and account context determine the return path. Product-state scenarios are selected from the separate review page.

| Flutter surface | Prototype entry or interaction | Data, actions and scope |
|---|---|---|
| OnboardingPage, AccountGate | `#onboarding` → `#welcome` | Interface language and theme, guest or credentials, mandatory first profile |
| Account welcome, sign-in, sign-up, password recovery and email verification | `#auth/signin`, `signup`, `reset`, `password`, `verify`, `username`, `upgrade` under the same auth prefix | Sample fields, validation, simulated verification, offline retry with draft preservation, guest upgrade |
| Profile picker, editor, management and PIN | `#profiles`, `#profiles/manage`, `#profiles/new`, `#profiles/edit/mira` | Create up to five, set avatar color/name/default/PIN, select, edit, remove with confirmation |
| MainShell, search entry, dock and rail | `#home`, `#discover/search`, `#account` | Five stable destinations, active state, account menu, platform frame, focus on search |
| FeaturedHero and ContinueWatchingRail | Home; choose a slide or progress card | Saved status, exact sample episode, watch progress, new-profile empty state and fallback to Discover |
| Add-on catalog and grid pages | Home rows → Discover | Filter by type, search, sort by popularity, rating, year or name, open details, return to search context |
| Anime index, search and tracker | `#anime` → title/track | Anime-only results, saved subset, episode progress, tracker state, sample personal score and status |
| CalendarPage | `#calendar` | Previous/next week, select day and content type, empty day, retry, open episode title |
| LiveTvPage and playlist dialog | `#live` | Search/filter channels, add sample M3U and optional EPG, remove playlist, simulated live player |
| KidsPage and parental gate | `#kids` | Family-only results/details, profile/search/back/deep-link exit protection, first-use setup, wrong PIN, cancel and successful exit |
| MediaDetailPage, episode list and episode actions | `#title/tide` | Facts and synopsis, seasons, progress, watch/continue, episode action menu, mark episode or range, download, save and share |
| Detail discussions and tracking | Title → review / track / More like this | Spoiler reveal, full review, recommendations, sample tracker connections, status and personal rating |
| Source picker and torrent preparation | `#sources/tide/3` or `#sources/sand/1/download` | In-page load/search/refresh, empty matches, retry, quality selection, unsupported P2P, cancellable preparation |
| Core and Legacy presentation | `#player/tide/3` | Simulated play/pause/seek, resume, lock, optional exit confirmation, fit, gesture feedback, skip and next episode |
| Player audio/subtitle/episode/source/settings panels | Player tools | Audio/volume/delay, subtitle selection and file picker, styling, speed, brightness, source change, episode choice |
| LibraryPage, history, custom lists and pickers | `#library`, `#new-list`, details → collection picker | Search/sort, saved/history/collections tabs, create personal or shared collections, rename, item add/remove/note |
| Shared collection detail, control and invitations | `#collection/weekend`, `#join` | Owner/member states, member grants, token rotation/copy, add by invite, remove/leave, version conflict and retry |
| Magnet opener and file picker | Library → Magnet → `#magnet-files` | Sample link, format validation, file selection and player handoff |
| DownloadsPage and storage | `#downloads`, `#settings/downloads` | Queue, cancel, retry, ready/missing file, play, remove, sample cache reset |
| Account, privacy and statistics | `#settings/account`, `privacy`, `stats` under settings | Profile management, switch/sign out, guest upgrade, legacy import, sample data export/restore, clear actions, activity counts |
| Playback and subtitle preferences | `#settings/playback`, `#settings/subtitles` | 34 extracted controls, engine/platform state, picture preset, font selection/import, colors and exact delay values |
| Appearance, display, language and navigation | `#settings/appearance`, `display`, `language`, `icon`, `dock` under settings | Dark/light/system/OLED, motion/transparency, language controls, visual presentation and icon choices |
| Catalog management, Kids settings and notifications | `#settings/catalogs`, `kids`, `notifications` under settings | Row ordering and visibility, child card density, change parent PIN, notification permission information |
| Installed add-ons and details | `#settings/addons` → `#addon/Cinemeta` | Sample installation, resource information and removal |
| Linked services | `#settings/services` → `#service/{provider}` | Trakt, Simkl, AniList, MyAnimeList, MDBList, Letterboxd, TMDB, Debrid, AniSkip, IntroDB, TheIntroDB. Provider-specific preferences, sample authorizations, connect/disconnect, sync and key states |
| About and update | `#settings/about` | Brand, local build information, Android sample update check |

The map describes the sample UI and its interactions. OAuth exchanges, server-side conflict detection and member enforcement, OS permissions, video decoding, local subtitle rendering and real download jobs require the corresponding Flutter and native acceptance tests. The prototype uses illustrative media and simulated clocks for these journeys.
