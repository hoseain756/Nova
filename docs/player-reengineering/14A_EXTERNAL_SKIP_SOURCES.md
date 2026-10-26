# Station 14A — External skip timing sources

Status: STATIC-ONLY candidate integrated; live provider coverage and physical marker acceptance remain open.

## Plan

1. Keep the selected stream and episode marker fields as the first authority for the exact playback file. Read explicitly named media-file chapters next when libmpv exposes them; use each next chapter start as its end.
2. Resolve exact episode identity. IMDb plus season/episode addresses IntroDB and TheIntroDB; a confirmed MAL ID and exact anime episode number address AniSkip. Use the existing AniZip exact episode mapping to recover both MAL ID and episode number for IMDb-sourced anime. Do not infer an absolute anime episode from a season number.
3. Read the three public timing APIs with bounded requests, no embedded API credentials, and independent failure handling. Normalize each result to NOVA's half-open millisecond `SkipSegment` contract and retain provenance.
4. Validate every interval against the real player duration. Use provider duration/version information when available; reject conflicting external timings for the same segment type. Never change autoplay or the next-episode countdown from these services.
5. Merge accepted external segments into both Core and Legacy after the engine reports duration. Ignore a late response after the route closes or changes; cache by episode and duration to avoid repeat calls.
6. Add focused parser, identity, merge and failure tests; run scoped analysis and tests. Keep phone acceptance, long playback and LKG blocked until the user chooses to test on a physical device.

## Sources checked 2026-10-24

- AniSkip v2: `https://api.aniskip.com/v2/skip-times/{malId}/{episode}` with `types` and `episodeLength`. Its published client documents MAL and episode identity: https://github.com/aniskip/aniskip-extension/blob/main/src/api/aniskip-http-client/aniskip-http-client.ts
- IntroDB: `GET https://api.introdb.app/segments` with IMDb ID and TV season/episode: https://introdb.app/docs/api
- TheIntroDB v4: `GET https://api.theintrodb.org/v4/media`; IMDb identity, season/episode, `duration_ms` and `details` are supported: https://theintrodb.github.io/theintrodb-npm/getting-started.html

`IntroDB` and `TheIntroDB` are separate services. An API's availability does not prove coverage for Black Clover S2:E3 or that any timing matches the chosen Torrentio file.

The linked-services screen now lists AniSkip, IntroDB and TheIntroDB. Public timing reads need no key. AniSkip offers no user key for reads. IntroDB's optional user key is stored for its submission API only; NOVA does not submit timings, so this key is not sent during playback. TheIntroDB's optional current-user key is stored in device secure storage and sent as a Bearer header only to `https://api.theintrodb.org/v4/media` without redirects, allowing the service to include the user's pending submissions. A rejected key falls back to a public read. Neither key is stored in synced settings, logged or bundled with the app.

## Verification and limits

Main checkout transfer (2026-10-26): the source lookups, secure key settings, and Core/Legacy wiring were adapted to the local `main` player model. Scoped analysis of 14 implementation files found no issues; 14 parser/identity/key-routing tests and four Up-Next layout/action tests passed. The earlier test results below came from the feature worktree; neither run establishes physical-device behavior on `main`.

- Focused parsing, file chapters, AniZip identity, three-service request, conflict, native precedence, existing segment and playback-session tests: **74/74 passed**. Scoped analyzer over all changed Dart implementation and test files: **no issues**. The tests use fixtures and an intercepted HTTP client; no physical playback was used.
- API results only supply manual skip prompts. TheIntroDB `preview` and IntroDB `post_credits` remain content and are not treated as safe skip ranges. No source can set the next-episode countdown.
- When AniZip cannot confirm both MAL identity and episode number, the AniSkip request is omitted. IMDb-backed services can still supply independently valid timing. This is a coverage limit, not a season-number guess.
- The external timing request starts only after a positive player duration. An absent duration, provider failure or conflict leaves the current source markers and playback untouched. Station 14 device/UI and LKG tasks remain unchecked.
- Chapter extraction calls libmpv's optional `chapter-list` property once per engine with a two-second bound. Some media_kit users report an empty list despite embedded chapters ([upstream issue](https://github.com/media-kit/media-kit/issues/1319)); chapter availability remains unverified on the user's file and device.

### Public lookup for the user's Black Clover S2:E3 example — 2026-10-24

Read-only API queries for IMDb `tt7441658`, season 2, episode 3 returned IntroDB intro **216000–290000 ms** (confidence 1, one submission) and outro **1340000–1429000 ms** (one submission). TheIntroDB v4 returned a release group of **1429000 ms** with an intro **212000–301000 ms**, but its confidence was about **0.536**, below NOVA's 0.6 acceptance threshold. The selected player's previously observed duration was 23:49 (1429000 ms), but these public records have not been compared with the actual frames. The AniZip IMDb query currently points to an OVA with no matching S2:E3 row, so the AniSkip anime-episode identity cannot be confirmed from that record and its lookup is withheld for this title path. Public API response availability is **STATIC-ONLY** evidence, not device acceptance.
