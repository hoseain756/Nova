# Streaming video freeze investigation — 2026-10-29

Status: source fixes and regression validation; device cause and smoothness are
**NOT MEASURED**. This is a scoped bug investigation, not acceptance of a player
station or replacement of the existing device/LKG gates.

## Report and scope

The user's corrected report is **video freezes for seconds while audio continues,
without a loading indicator**, on both iPhone and Android. Android's setting is
Auto. Downloads played through DownloadsPage are reported smooth. The earlier
description that audio also stopped is superseded.

Baseline source: `9fa7ec71c8945a216cbccb474c7c71086fc273f7` on `main`.
Existing local APK, ZIP, screenshots and reference evidence were preserved.
No app was installed, launched, or made to play. ADB device discovery succeeded
on this host on continuation but listed no connected devices. There is no Apple
host/device runtime measurement in this investigation.

## What the current source establishes

| Finding | Evidence and implication |
|---|---|
| Download playback disables progress recording. | `lib/features/downloads/downloads_page.dart`, `_play`, passes `recordProgress: false`. This is a workload difference as well as a transport difference. |
| Streaming progress is checkpointed every five seconds. | `session/playback_session.dart`, `periodicInterval` / `checkpoint`; Legacy has its own five-second save timer. Periodic Core saves do not capture screenshots or deliberately pause playback. |
| Each checkpoint previously rewrote five collections. | `AppState.recordPlayback` requests history + library, but `_persistAndSync` discarded that scope for local `_persist`. Addons, lists and watchlist were serialized/written despite not changing. |
| Home invalidation included every history timestamp. | `home_page.dart`, `didChangeDependencies`: a checkpoint changed `watchedAt`, triggering `_load`, replacing core/hero/recommendation futures and clearing lazy addon futures. |
| Hidden Home hero work could continue. | `featured_hero.dart`: the periodic slide timer was tied to selected tab/app lifecycle, without route visibility. It could advance and predecode posters behind a pushed route. |
| A stable video surface is already used. | `PlaybackSessionSurface` caches the child by engine identity and fit. Core readiness is the session's prepared state, so a temporary backend buffering event does not unmount the surface. No repeated surface creation specific to network sources was found. |
| Ordinary history notifications do not resend subtitle commands. | Both player pages diff subtitle/audio settings before applying offsets or native file styling. |
| Auto does not identify the active backend. | Core can select libmpv for nonzero audio/subtitle offsets or native file styling, or fall back after a Media3 compatibility error. The active engine and hardware decoder need runtime evidence. |

The first three workload defects are independently actionable. Their correction
does **not** prove that any one caused the reported video freeze. Video output,
decoder starvation, raster contention and provider/container behavior remain
unresolved without a paired run of the same media.

## Reference comparison

All three supplied folders were inspected independently as source snapshots.
None contains Git metadata, so their commit identities are unknown. No reference
code or binaries were copied into NOVA. The existing license boundaries in
`LICENSE_NOTES.md` apply.

| Snapshot | Relevant source observations | Limit of transfer |
|---|---|---|
| Harbor 0.9.127, MIT | `src-tauri/src/mpv.rs:904–981` separates startup/read-ahead/rebuffer behavior and excludes `reconnect_streamed` from VOD; `src/lib/player/mpv.ts:728–729` reads real cache state; `src-tauri/src/torrent_engine/stream_route.rs:187–281` streams range data asynchronously. | Desktop buffer sizes are not mobile defaults. Its HLS retry comment is not a reproduced NOVA measurement. NOVA's inspected library does not configure that reconnect option. |
| NuvioMobile, GPLv3 | `NuvioExoPlayerPerformanceHelper.kt:82–99` sets Media3 load control; `PlayerEngine.android.kt:1400–1430` sets mpv byte limits; `MPVPlayerBridge.swift:509–546,974–987` uses VideoToolbox and observes cache pauses. | iOS setup has no explicit demuxer-cache tuning. Its custom Media3 allocator and renderer do not establish a fix for NOVA. |
| Stremio-Kai, GPLv3 | `portable_config/mpv.conf:28–37` has explicit cache/readahead and separate forward/backward limits; `profile-manager.lua:267–276` resets content-specific decoder/filter settings. | Windows/SVP configuration, not an Android/iOS implementation; its large budgets and filters are not imported. |

Snapshot SHA-256 anchors:

- Harbor `src-tauri/src/mpv.rs`: `996ec9357eaf84b257c986ee56d63fdf93cec9c303e58a97b4e85b2c2618440f`
- Nuvio `NuvioExoPlayerPerformanceHelper.kt`: `567362c7ba86b3848550d8c4295ed330510116cba68d9a29019b6c0798dda0ff`
- Nuvio `PlayerEngine.android.kt`: `17056e8bfa751f684976fc8ba7b79e368d311ad6375b61b3fa970b23032f3556`
- Nuvio `MPVPlayerBridge.swift`: `bbaa3ff1b4d6b97e56b69c86922b758173c997769316672d0b8fa2634caae83f`
- Stremio-Kai `portable_config/mpv.conf`: `5bd08c730082c0ec92bdb8abcccea42637e616067fe98ad8fbc0364672e6d1884`

The [mpv cache documentation](https://mpv.io/manual/stable/#cache) distinguishes
read-ahead, rebuffering and disk packet storage. With disk caching enabled, the
demuxer byte caps refer to in-memory metadata rather than total cached media.
Increasing these values is not evidence of a video-freeze remedy. No speculative
decoder forcing, cache-budget increase or reconnect flags are part of this fix.

## REA evidence

REA 6.7.0 was available during the initial investigation. It performed static
artifact inspection without executing the targets:

- Local `Runner.app.zip`, SHA-256
  `4c0d07716c849079cc80d084068bcb3686f29de70446db606d96ca6024157c85`:
  inspection `ev_bcb2969b7458008ab0d81dd95748a2ccd06ca72c92f88fb2f6b14a0639479a27`,
  inventory `ev_f8e4a7f1c57c1fc21c993f39ddf01be00e6dd21acf383d4bf1ff09a98e5faeeb`;
  219 occurrences, 155 files, 64 directories, no inventory integrity
  contradictions. This does not identify the user's installed iPhone build.
- Local `.codex/nova-installed-base.apk`, SHA-256
  `5e0b2dec2fb94691eafdbf6f8ae2254c18859b5c35c577d2ade6da7f9ad1eabd`:
  Flutter build inspection
  `ev_325f996b9d85ad66029938acbfddbd0421620c65bd4642929073a2ee438c43d1`.
  It found `libflutter.so` for three ABIs but no `libapp.so`; the tool's AOT
  identification coverage is partial. This local artifact is not proof of the
  currently installed build or decoder.
- Complete local export: `.codex/streaming-stutter-rea-evidence.json`, four
  records, 518141 bytes. The export remains a local investigation artifact.

Ordinary source inspections above are not presented as REA decompilation or
runtime evidence. Android decompilation prerequisites were unavailable in the
initial REA session; complete native source was already present. On continuation
REA MCP tools were no longer advertised, so no further MCP operation is claimed.

## Validation and remaining device work

The fixes keep existing persistence keys, checkpoint cadence, sync scheduling,
resume and subtitle behavior. Home still refreshes when its recommendation seed
or completed-title filter changes. Covered-route handling suspends hero slide
rotation and speculative image precaching; already-started artwork enrichment
requests are not cancelled by this change.

Debug/Profile now include a five-second mpv probe. An instrumented Release build
can opt in with `--dart-define=NOVA_PLAYER_DIAGNOSTICS=true`. Ordinary Release
does not run it. The probe samples only fixed properties, normalizes numeric
values, suppresses retired/source-stale results, and does not queue additional
samples while an earlier read remains pending. Its asynchronous timeout cannot
preempt a synchronous native FFI call; these are diagnostic observations, not a
zero-overhead performance benchmark. Media3 uses the counters already emitted
by the native plugin; it does not report decoder identity or a per-frame output
heartbeat. A five-second sample can miss an isolated short freeze.

Validation:

- Persistence, fresh-state resume, catalog invalidation and hero visibility:
  14 tests passed.
- Native diagnostic sampling/cancellation/sanitization: 7 tests passed.
- Existing Media3, player surface, session and checkpoint checks: 59 passed.
- `flutter analyze --no-pub`: passed, no issues.
- Initial full suite: 733 passed, two source-picker failures. The untouched
  source-picker test supplied `abc123`, although its existing tap gate requires
  a 40-hex or 32-base32 torrent hash. Both failures reproduced independently.
  The fixture now uses a valid hash, and an additional test asserts that an
  invalid hash stays visible but cannot be picked. Production torrent validation
  is unchanged.
- Final full suite, `flutter test --no-pub --concurrency=2 --reporter expanded`:
  **736 passed**. Local log: `.codex/streaming-freeze-tests-final.log`.
- Android instrumented Release: `flutter build apk --release --no-pub
  --dart-define=NOVA_PLAYER_DIAGNOSTICS=true` passed with exit code 0;
  Gradle reported 651.5 seconds. Kotlin daemon connection retries and
  deprecation warnings occurred, but did not prevent the completed build.
  Local log: `.codex/streaming-freeze-build.log`.

The resulting test APK is
`build/app/outputs/flutter-apk/Nova-streaming-test-2026-10-29.apk`,
147126601 bytes, SHA-256
`6c470059b45a40ed98d2abdf14370caec43eaff6ac81de7b7fcf93810b07c412`.
Archive inspection found AOT `libapp.so` for arm64-v8a, armeabi-v7a and x86_64;
no `kernel_blob.bin`, `isolate_snapshot_data` or `vm_snapshot_data` was present.
This is a local diagnostic build, not a published update; it was not installed
or launched. No new iOS binary was built on this Windows host.

A meaningful paired device check uses the **same source/file, video/audio tracks,
subtitle style, picture preset, speed and time range** streamed and downloaded.
Use Profile or Release, first record the actual backend, then correlate the
reported freeze with decoder/output drops, video PTS versus audio time, buffer
state and Flutter build/raster timings. Cover Android Auto (including its actual
selected backend) and iOS independently. A test pass or archive inventory is not
decoder, provider, frame-pacing or physical-device acceptance.
