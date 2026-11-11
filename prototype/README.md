# NOVA interactive design prototype

The prototype runs locally with React, TypeScript and Vite. It opens in Arabic with a populated profile. The six fictional titles use original generated artwork. The wordmark, logo and fonts are copied from NOVA’s assets. Profile libraries, shared collections and preferences live in the preview tab’s memory.

## Run

From the `prototype` directory:

```sh
npm ci
npm run dev -- --port 4173
```

Open [NOVA](http://127.0.0.1:4173/) for the app and [Design review](http://127.0.0.1:4173/review.html) for the phone/tablet frame, language, platform presentation, theme, text size, reduced motion, reduced transparency and scenario controls. Use **Open full size** to test the selected design in the whole browser. Rotation in the review frame preserves the session. Changing fixtures or resetting the frame starts a fresh session.

The demo parent PIN is **1234**, Mira’s profile PIN is **2468**, and **NOVA-FRIENDS** opens an example invitation. A newly created guest or account creates its first profile and configures its own Kids PIN. Enter fictitious credentials on the sample sign-in screens.

## Review journeys

| Start | Try | Expected result |
|---|---|---|
| Home | Open the featured title, choose Watch, select 1080p, seek, then leave | The source picker opens before playback. The new position appears in Continue Watching. |
| Discover | Search “Last Light”, open its details, return | Search text, filters and result context survive. |
| Series details | Choose an episode’s options, mark watched through it | Every episode in the chosen range displays its watched state. |
| Library | Create a shared collection, add a title, switch to Mira | Mira has her own watchlist and history and can still open the account’s shared collection. |
| Library | Join with NOVA-FRIENDS | The member can add an item and leave the collection. Owner management controls belong to the owner. |
| Kids | Try Profile, another tab, or an adult title hash. Cancel, enter a wrong PIN, then the correct one | Adult content appears only after the exit gate succeeds. |
| Review | Select Source picker with Provider failure, then Retry | A recoverable error becomes a source list. |
| Review | Select Shared collection with Version conflict, edit its name, reload and retry | The original collection remains until the retry saves the revised name. |
| Review | Open Download sources on iOS | Direct media can be queued. Offline torrent sources show their unavailable status. |
| Settings | Open Services, authorize a sample tracker, change preferences, disconnect | The account’s temporary service status changes. |
| Onboarding | Select a language and appearance, register or continue as guest | The account flow reaches the mandatory first profile. |

Production integrations are represented by local fixtures. Player time advances on a shortened clock. The OS permission, account authorization, torrent preparation, file transfer and platform presentation steps simulate their visible states. Browser verification covers this design artifact. Native and service acceptance belongs to the subsequent Flutter implementation.

## Build and check

```sh
npm run build
npm test
```

The build type-checks the project and produces both entry points in `dist/`. The browser tests start their own loopback Vite server. They use installed Google Chrome or Edge on Windows. Set `NOVA_BROWSER` to a Chromium executable on another desktop or install Playwright Chromium. Home screenshots from the tests are saved under `test-results/`.

The [screen and interaction map](COVERAGE.md) links the existing Flutter surfaces to their review paths. The [component specification](COMPONENTS.md) records shared layout and behavior for the Flutter handoff. To refresh the playback and subtitle setting definitions after a Flutter change, run `node scripts/preferences.mjs` and inspect the generated diff.
