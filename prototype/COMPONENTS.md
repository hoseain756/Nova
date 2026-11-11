# NOVA components and presentation

| Component | Usage and behavior |
|---|---|
| Application shell | Logical tab order Home, Discover, Anime, My Library, Kids. A single dock on compact windows. An icon rail at 840 CSS px and above. The iPhone phone fixture keeps its dock in landscape. Profile and search shortcuts sit in the shell header. A pushed route owns its own header. |
| Featured title and title details | On phones a full-width still sits above the title and controls. At 700 CSS px the caption sits beside the artwork, mirrored for Arabic. Featured titles have a manual thumbnail picker when several are available. Returning from details restores the selection. The detail header includes the synopsis, score and existing watch, save, collection and download actions, subject to Kids mode. |
| Continue Watching | Landscape stills with a progress bar, episode identity and remaining runtime. Selecting a card opens sources for the selected episode. Completed entries leave this row and remain in History. |
| Poster | Vertical crop, score, saved marker, name, genre and year. The same control appears in Discover, Library and collection details. Display preferences control title, badge and corner radius. |
| Source row | Quality, provider, format, size and protocol. Search filters the local source list. Selection resolves the existing watch/download intent. A disabled source includes its reason. |
| Settings | Searchable destination groups and labeled native browser controls. Wide settings subpages share a persistent section selector. Playback and subtitle definitions use the labels and option keys from Flutter. |
| Dialog and panel | Native HTML dialog provides modal focus containment, Escape and focus return. The close control is always reachable. Confirmation, errors and recovery appear next to the action. |
| Player | Independent full-viewport surface with play/pause, lock, seek and panel controls. Timestamp and seek directions follow the existing player convention. Horizontal drag seeks, vertical drag adjusts brightness or simulated volume, and press-and-hold temporarily doubles playback rate. |
| App state | Profile-specific watchlist, history, episode ranges, personal collections and ratings. Shared collections belong to the sample account. Normal back navigation restores route context. A tab reload resets sample state. |

## Design values

Use Ink `#141417`, surface `#232329`, elevated surface `#2E2E35` and primary action `#D13B47`. Light mode uses `#F6F6F7` and white surfaces. OLED uses a pure black base. Use Poppins for English and IBM Plex Sans Arabic for Arabic. Lucide icons identify standard controls and the supplied artwork identifies NOVA.

Compact layouts start with 16px gutters. Cards use the existing poster radius, controls use 12px, and dialogs use 24px. Actions target 48px or more. Use logical alignment, visible keyboard focus and translated accessible names. Text scaling, contrast, page overflow, dock clearance and modal scrolling are review concerns on every screen.

## Flutter implementation boundaries

The featured-title and title-detail hero design is approved. Flutter uses the same layout in Home, Anime, Kids and media details with the active catalog and profile.

The approved Player layout is implemented in Flutter Core and Legacy. Both routes share the title and lock controls, central transport, timeline, tool row and centered dialogs, using the active player for commands and selections.

Map the existing shell’s destination IDs to the five approved IDs, including `discover`. Map search to focused Discover. Route Kids exits through the existing parental gate. Update the capable iPhone presentation bridge with its revision and action checks. The iPad rail and unsupported system configurations use Flutter controls.

Translate the approved components into existing Flutter primitives and theme tokens in batches. Use existing AppState, catalog, authorization, source and download services. Preserve user data scopes, provider permissions, source choice, native playback ownership and Legacy rollback. Native builds and physical playback acceptance follow the production changes.
