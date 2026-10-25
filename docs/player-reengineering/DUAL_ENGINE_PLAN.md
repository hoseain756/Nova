# Android Media3 + libmpv implementation

Requested 2026-10-24: investigate NuvioMobile using REA, document the design,
and implement both engines in NOVA. This is new authorization for implementation;
historical station completion and device/performance claims are not advanced.

## Work plan

- [x] Record existing changes and inspect the current player contract.
- [x] Inspect NuvioMobile source, license, and packaged ExoPlayer AAR using REA.
- [x] Add an independent Media3 adapter with a Flutter texture and bounded events.
- [x] Integrate both engines with the serialized Core session and retirement barrier.
- [x] Add Android engine selection to Playback settings; retain libmpv elsewhere.
- [x] Keep torrent sources in Downloads and hand transfers to an Android background
  service with NOVA progress/completion notifications (additional user request).
- [x] Verify state/ownership/fallback contracts, targeted analyzer, and Android compilation.
- [ ] Record real device performance separately (NOT MEASURED).

## Decisions

Use official Media3 dependencies, not NuvioMobile's modified AARs or GPL code.
The initial bridge pins official 1.8.0 modules together, matching the inspected
API generation. The current upstream release listed during research is newer;
this pin is a compatibility decision, not a claim to use the latest release.
Keep Flutter navigation, controls, subtitles, persistence, source resolution and
torrent ownership. Media3 owns only native decoding, transport, tracks and output.
Use SurfaceProducer callbacks to detach/rebind output across surface loss.
Publish native progress at 250 ms; retain Core's coalesced progress and separate
transport projection. Do not rebuild the texture for position updates.
Release native output before another backend or torrent is created/stopped.
Automatic fallback is bounded to one compatibility fallback per route; network,
HTTP authorization, DRM and cancellation failures must not cause engine churn.
No speculative preloading, giant native memory arenas, or duplicate caches.

## Integration and compatibility

Core is the default route; explicit `NOVA_PLAYER_CORE=false` keeps Legacy.
The existing settings store persists `playbackBackend` (auto/media3/mpv) without
changing storage or sync identifiers. Android defaults to Auto, other platforms
resolve to mpv even if settings synchronize a Media3 choice from Android.
Nonzero audio/subtitle offsets use libmpv because the stock Media3 bridge does not
provide native timing offsets. Starting with an existing offset selects mpv;
changing an offset during playback retires Media3 and restores continuity before
applying it. This also applies to explicit Media3 selection and is stated in UI.

Media3 supports native audio focus, seek/rate/volume, track selection, HLS/DASH/SS/
RTSP, request headers on HTTP sources, textual embedded and data-backed external
subtitles, and optional PixelCopy resume frames. The video texture has independent
geometry updates and SurfaceProducer lifecycle callbacks. Rotation correction
uses producer capability and video-format metadata. Subtitles retain the shared
NOVA overlay. Adding an external subtitle currently re-prepares the MediaItem at
the same position; buffer preservation for that operation is NOT VERIFIED.
Bitmap subtitles and exact ASS typography are not established by this text overlay.
DRM license handling, HDR output fidelity and codec coverage require separate proof.

Native sample buffering targets 24 MiB on low-RAM devices or 48 MiB otherwise,
with no back buffer; this is not a bound on total decoder/GPU/process memory.
Media3 diagnostic snapshots carry first-frame latency and decoder dropped frames.
Flutter diagnostics use the display refresh rate (60 Hz fallback if unknown).
These counters must be collected over bounded scenarios before performance claims.
Agent invocations used for this implementation: 0.

## Initial workspace

Branch: main. Existing changes at start: AGENTS.md, DESIGN.md,
anime_tracker_sheet.dart, catalog_browser_page.dart, home_page.dart,
media_detail_page.dart, player_chrome.dart, player_sheets.dart,
settings_display_page.dart, settings_preferences_page.dart, settings_tiles.dart,
main_shell.dart, search_sheet.dart, ios_chrome_bridge_test.dart.
Existing untracked artifacts: .codex/nova-gatec-screen.png,
.codex/nova-installed-base.apk, Nova.ipa, Runner.app.zip.
Preserve all of them; no commit or push is part of this work. The user subsequently
authorized a data-preserving test APK installation and comparison on a connected
physical Android phone. Device results below must still identify the actual scope.

## Performance acceptance

Performance is NOT MEASURED. Compare Profile/Release on the same physical Android
device, same local or stable stream, same start point and refresh rate, at least
three bounded runs per engine. Record first frame, buffering, decoder drops,
Flutter frame times, memory after GC, CPU/thermal conditions, seeks, subtitles,
source handoff and background/foreground. Report median/min/max, never infer a
speedup from compilation or architecture. iOS stays on existing libmpv and requires
Apple-host/device evidence for runtime claims.

## Verification ledger

- Targeted Flutter analyzer: no issues on the player, touched settings/detail UI,
  and associated tests. Full-workspace analyzer was stopped after slow progress;
  no full-workspace clean claim is made.
- Native Android debug Kotlin compilation: BUILD-VERIFIED (`:app:compileDebugKotlin`,
  with the Flutter build task excluded; this alone is not a new APK).
- 42 session tests: passed, including retirement-before-fallback, no fallback for
  network failures, close during switching, single runtime fallback, continuity,
  nonzero offsets and rapid offset updates sharing a single switch.
- 3 Media3 channel tests and 2 backend-policy tests: passed.
- 1 route/rollback test, 8 rendering-isolation tests, 20 progress tests,
  7 progress-binding tests and 4 checkpoint tests: passed.
- 12 settings tests: passed, including Android selection persistence, iOS exclusion,
  Arabic/English, dark/light, phone/tablet and 200% text constraints. Initial new
  platform-override test cleanup was corrected to use Flutter's platform variants;
  the existing retention test now waits for scrolling layout before tapping.
- 22 download/source tests: passed, including native torrent queue handoff, no
  duplicate Dart transfer, restoration after Flutter manager disposal, serialized
  cancellation/retry/removal, and rejection of incomplete native completion.
- The final broad targeted analysis reported two style findings confined to the
  download test file. Both were corrected; re-analysis of that file passed.
- Background torrent design and its verification limits are documented in
  `TORRENT_DOWNLOADS.md`. No foreground-only torrent implementation was installed.
- `git diff --check`: passed; pre-existing user edits remain present.
- Final Profile APK (`1.0.4+67`, SHA-256
  `3AA034FC1FCA66FCE5DC1474FA6AA9FA4680543768DACEB2850EFDA71F89D826`)
  compiled successfully, passed apksigner verification, and was installed with
  data-preserving `adb install -r` on the authorized SM-A217F / Android 12.
  NOVA launched successfully. See `evidence/dual-engine/2026-10-24/installation.json`.
- Background torrent transfer continued with no NOVA Activity/task present:
  saved device samples progressed from 35% to 43%, then a live observation reached
  64%. After USB disconnection the user reported completion and the NOVA
  notification. See `TORRENT_DOWNLOADS.md`.
- Both Media3 and libmpv playback, and downloading, were subsequently confirmed
  working by the user on the phone (USER-REPORTED). The exact local-file scenario
  was not specified. Quantitative Android performance remains NOT MEASURED;
  iOS native build/runtime remains NOT VERIFIED.
  Media3's first-frame counter measures its native rendering callback, not proof
  of display presentation or a full Flutter frame. Counters are not benchmark results.
