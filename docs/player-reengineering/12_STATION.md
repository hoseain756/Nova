# Station 12 — Subtitles, audio, speed and sources

- Status: IN PROGRESS — player UI candidate implemented; physical playback and station acceptance pending
- Verification status: STATIC/TEST VERIFIED for the UI candidate; runtime source and track behavior NOT-VERIFIED for this station
- Checklist: 0/9 tasks complete
- Evidence:

- [ ] Implement embedded/external subtitle discovery and switching.
- [ ] Implement audio track discovery and switching.
- [ ] Implement playback speed state and engine application.
- [ ] Implement source change preserving position/play state and resetting/reselecting tracks deliberately.
- [ ] Prevent overlapping player sessions and double-open operations.
- [ ] Test loading/error transitions and track state reset/reselection.
- [ ] Verify real device behavior on available streams and mark missing formats NOT MEASURED.
- [ ] Run LKG validations and record evidence.
- [ ] Commit only Station 12 paths/docs.

## Findings and evidence

### Player UI follow-up — 2026-10-22

Both player routes now place subtitle, audio and source navigation beside the side-panel close action. The shared panel adapts its header, content padding and speed/fit choices to constrained widths. Subtitle font size uses 2 px steps through 64 in the player sheet, app settings and renderer. Subtitle style controls use `[- value +]`; position alone keeps a slider, the top/middle/bottom shortcuts were removed, and style choices were compacted. The border-color picker previews a colored outline over stable text fill. A shared center-value gesture adjusts audio and subtitle delay by 10 ms per vertical step while retaining integer millisecond persistence. The app settings page exposes audio delay and subtitle position under their existing keys; no existing storage key was renamed.

`PlayerEpisodesSheet` presents a season selector and directional episode cards with artwork, `S00E00`, rating, title and play action. A new episodes rail action sits below lock in both routes. Episode play opens the existing source picker by default. The `autoSelectEpisodeSource` setting is opt-in (`false` by default) and uses the existing playable-source filter and resolution path when enabled; a transition latch prevents duplicate automatic opens. Episode metadata is already supplied by `MediaItem.videos`, so the sheet's in-panel spinner is reserved for a real asynchronous load and is not shown artificially.

On the first installed candidate, the user clarified that the **refresh button and subtitle-style button** should align with the search field in the source/subtitle panels. They now sit in that search row, while panel navigation and close remain in the header. A focused 320 dp widget test verifies the row and taps in RTL/LTR. The corrected default-route Profile APK built (112.5 s), SHA-256 `4847451687D79FAE02AA1C1C10E5AAAC526A3327AC7F5F2ECA43C2024E70ECD1`, 172,848,455 bytes; ADB reinstall on `RF8NA2NNVNY` returned `Success`. The user confirmed that this arrangement is correct on the phone.

Validation for this working-tree UI candidate: full `flutter analyze --no-pub` PASS/no issues; full `flutter test --no-pub --reporter compact` PASS (547 tests) before the final app-settings audio-delay row was added; subsequent scoped analysis PASS and relevant settings/panel/episode tests PASS (25 tests). Focused subtitle, sheet, settings-panel and episode tests earlier PASS (46 tests); episode widget tests cover RTL/LTR, season selection, loading state, a narrow viewport and 200% Arabic text. `git diff --check` PASS. The default-route Profile APK build PASS (144.8 s), SHA-256 `8436E59C423407276A72A48F4F27DE7BE64CF112A57856577E0B89DA882C5B05`, 172,848,455 bytes; ADB install on `RF8NA2NNVNY` returned `Success`. The user has been asked to select a source and check picture/audio plus panels; no playback result has been received yet. Native frame performance, Core-route device behavior, iOS and this station's LKG remain unverified. The original Station 12 checklist above remains open until its broader track/source and physical-device evidence is audited.

## Blockers / unknowns

User-led playback checks for the installed default route, a separate Core-route build/device check, and representative subtitle/audio/source switching remain outstanding. Performance baseline remains waived/NOT MEASURED; no improvement claim is made.

The user reported missing One Piece subtitles from the enabled SubDL Subtitles and SubSource Subtitles add-ons, and identified `S23E1`. The public AniZip mapping for IMDb `tt0388629` identifies that exact season/episode as absolute `1156` (air date `2026-04-05`), rechecked live on 2026-10-22. A subtitle-only fallback now queries AniZip after empty primary add-on results, verifies the series identity, episode coordinates and date, then asks enabled compatible add-ons with alternate anime IDs and deduplicates results. It does not alter the playing video/source ID. Four resolver/repository tests passed, including exact match, ambiguity/date/identity rejection, empty-primary fallback and primary-result precedence. Full `flutter test --no-pub --reporter compact` passed (555 tests), scoped analyzer passed and `git diff --check` passed. The default-route Profile APK built (124.7 s), SHA-256 `1E0AB899E5EE26C224EBF238FF431E3304D7DBF9BAADC46074B5DBE28D526E91`, 188,981,903 bytes; ADB reinstall on `RF8NA2NNVNY` returned `Success`. **The user physically confirmed that subtitles appeared for S23E1 and that picture and audio were healthy.** The exact add-on that supplied the subtitle was not identified, and the other anime numbering cases remain untested. A Core-route Profile APK also built earlier (118.0 s), SHA-256 `A6F769FB478AAA9826710B6801FEEDC51D7D1141E9756BD7C524E172AF30496F`, 189,047,439 bytes, but it predates this fix and must be rebuilt before Core-route device testing.

The user also confirmed on the installed default route that changing subtitle/audio tracks and source succeeds, playback continues and watch position is retained. Availability of a second embedded audio track was not described separately; this confirmation is user-reported behavior, not an instrumented trace.

### External subtitle URL failure follow-up — 2026-10-22

After the successful anime fallback check, the user reported that selecting a SubDL result showed `Can not open external file https://subdl.strem.top/...` while audio continued. Both player routes previously passed the provider URL directly to libmpv. They now fetch subtitle text through NOVA's app HTTP client and select it using media_kit's data-backed subtitle track; unusable HTML/empty responses produce a localized snackbar instead of sending the remote URL to libmpv. Scoped `flutter analyze --no-pub` passed and `git diff --check` passed. A new default-route Profile APK built (106.3 s), SHA-256 `5E46F1727A7D7F9CABADC62308AC438A77550A0FEC8DC27D4C9F59F44CA51ACA`, 188,981,903 bytes; ADB install on `RF8NA2NNVNY` returned `Success`. **The user retried on the phone and reports the same error persists; this fix is not accepted and Station 12 remains in progress.** REA tools were not connected in this session; the requested pinned CLI invocation failed before launching because npm reported a missing cached `package.json`, so no REA evidence is claimed.

## Commit / LKG

Pending station completion.

## Session 1 scope
Not entered in this session. The user checkpoint ends after Station 07; this station remains PLANNED.
