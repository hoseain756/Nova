# Letterboxd via Stremboxd

NOVA uses the community Stremboxd bridge for Letterboxd catalogs and film
details. This is separate from the existing MDBList Letterboxd rating source.
It does not use Letterboxd's official OAuth or API credentials. The official
[API access page](https://letterboxd.com/api-beta/access/) and
[API documentation](https://api-docs.letterboxd.com/) describe a restricted
third-party application process; NOVA has no approved Letterboxd API grant.

## Harbor reference and REA evidence

The implementation was mapped from
`C:\Users\hosea\projects\app\player-refereences\harbor` using the
`rea-agents@6.7.0` `analyze-javascript-application` CLI over
`src/lib/stremboxd`. REA parsed nine TypeScript files (6,660 AST nodes),
reported 131 findings and zero parse failures. The evidence ID is
`ev_bde816986b2346ff3343b885130e7183fff08e7fec6a7ddf2b67202537dd10d0`.
The review also inspected Harbor's Letterboxd settings panel and
detail/library/profile views. This is source and static analysis, not a live
Harbor login or runtime trace.

| Harbor control | NOVA location and behavior |
| --- | --- |
| Enable, Public/Full mode, username, password, optional TOTP | Linked Services → Letterboxd → Connection. Public mode can show Popular and Top 250 without a username. Full mode sends credentials to Stremboxd only when Connect is pressed. |
| Seven catalogs | Catalog switches in the Letterboxd page. Diary, Friends and Recommended require Full mode. |
| Public custom lists | Add a Letterboxd list URL; Stremboxd resolves its ID and metadata. |
| Hide, reorder, refresh | Home Rows and Refresh in the Letterboxd page. |
| Rating on posters, review blur | On Screen in the Letterboxd page. |
| Catalogs and film actions | Home rails and movie detail. Full mode exposes Stremboxd action links through an external browser. |

The public config follows Harbor's base64url UTF-8 JSON format with `u`,
`c`, `l` and `r` fields. The bridge base is `https://api.stremboxd.com`.
`lib/core/letterboxd/` owns the settings model, public config and HTTP client.
`lib/features/settings/letterboxd_settings_page.dart` owns the controls.
`AppState` stores nonsecret choices in the existing settings bucket and loads
catalog rows independently from the five linked tracker imports.

Full mode receives a Stremboxd session token. `NoorApi` saves that token only
in account-keyed device secure storage. The password and TOTP are never
persisted. Switching NOVA accounts clears the in-memory token before loading
the new account's token. Catalog fetches are bounded to four concurrent
requests; a failed row keeps its prior in-memory result until a later refresh.
Rows are presentation data and do not modify NOVA watch history or watchlist.

Film actions use only HTTPS links returned by Stremboxd for the configured
bridge host, and open outside NOVA. The detail section accepts Letterboxd
review links only from bridge metadata and displays short text previews with
the user's blur preference. It does not scrape Letterboxd pages. There is no
automatic sync of Letterboxd watched state or ratings into NOVA playback data.

## Acceptance boundary

- Static analysis and focused Flutter tests cover config encoding, response
  parsing, account storage, settings controls, catalog ordering and detail UI.
- The public Stremboxd manifest and Popular catalog responded to an anonymous
  read-only probe on 2026-11-04. The probe did not use user credentials.
- Full-mode login, TOTP, account-specific catalogs, signed film actions,
  service longevity and device behavior need a real account and device check.
- Stremboxd is a third-party service. Its availability and data contracts can
  change independently of NOVA.
