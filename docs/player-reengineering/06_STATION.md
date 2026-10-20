# Station 06 — Stremio Kai and supplementary MPV investigation

- Status: COMPLETE (STATIC-ONLY, exact upstream snapshots inspected)
- Verification status: STATIC-ONLY
- Checklist: 11/11 tasks complete; exact upstream snapshots and authorized supplemental reference agent used
- Evidence: GitHub read-only source access at exact commits for Stremio Kai and mpv-qol-scripts; no source copied or changed.

- [x] Record Stremio Kai exact upstream repo, SHA, branch and license; no local checkout was present.
- [x] Verify the desktop player integration from source/config evidence.
- [x] Trace source-visible MPV buffer, renderer, reconnect and skip configuration; no runtime behavior inferred.
- [x] Inspect subtitle/audio profile and skip state paths in bundled configuration/integration.
- [x] Inspect resume and episode behavior from project documentation/code where present; unverified details remain UNKNOWN.
- [x] Assess streaming-heavy setup and phone/tablet applicability limits.
- [x] Inspect `mpv-qol-scripts` independently at its exact SHA, including skip and track-selection tooling.
- [x] Classify its Stremio Kai relationship and direct-vendoring evidence separately.
- [x] Maintain clean-room descriptions and NOVA applicability limits.
- [x] Record unknowns below.
- [x] Commit the Station 06 report on the feature branch.
- [x] Use one authorized `reference_researcher` invocation for the separate `mpv-qol-scripts` repository; immediately check Git status (no agent-created files). Stremio Kai itself has no local checkout and the agent cannot use network access.

## Findings and evidence

### Repository and method

- Stremio Kai: [allecsc/Stremio-Kai](https://github.com/allecsc/Stremio-Kai), `main`, SHA [`a5a2a37e818fb5e9406caf65af374fa7fe7700af`](https://github.com/allecsc/Stremio-Kai/tree/a5a2a37e818fb5e9406caf65af374fa7fe7700af), GPL-3.0 (`LICENSE.md`). No local checkout; read-only GitHub source used.
- Supplement: [allecsc/mpv-qol-scripts](https://github.com/allecsc/mpv-qol-scripts), `main`, SHA [`e0b04926f00ce3d482120d5bf15ebc0e32f7d94a`](https://github.com/allecsc/mpv-qol-scripts/tree/e0b04926f00ce3d482120d5bf15ebc0e32f7d94a), GPL-3.0 (`LICENSE`). Separately inspected; no files copied.

### Findings (STATIC-ONLY)

| Topic | Finding | Evidence |
|---|---|---|
| Integration and engine | Stremio Kai is a desktop Stremio build whose README identifies integrated MPV and says the project inherits MPV integration from `stremio-community-v5`; it is not a Flutter/mobile player. | `README.md` MPV and acknowledgements sections; `portable_config/mpv.conf`. |
| Rendering/buffer config | This snapshot enables MPV cache, 900-second cache window, 180-second demuxer readahead, large demuxer/stream buffers, seekable cache, `gpu-next`, and high-quality profile. These are configured values only; they do not establish actual cache occupancy or playback smoothness. | `portable_config/mpv.conf:27-38`, `:74-79`. |
| Network recovery | Config passes reconnect options for streamed FFmpeg inputs. Runtime retry outcome and source behavior remain UNKNOWN. | `portable_config/mpv.conf:36-38`. |
| Track/subtitles/profile control | Subtitle appearance is configured through MPV options; the WebView2 bridge sends metadata-derived profiles and track preferences to MPV scripts through messages. | `portable_config/mpv.conf:39-52`; `portable_config/webmods/Metadata/Services/mpv-bridge.js:55-72`, `:123-189`, `:214-276`. |
| Skip/episode flow | Project documentation describes intro/outro notifications and automated profiles; bundled `notify_skip` files exist. No mobile design or measured transition timing is evidenced. | `README.md` skip section; `portable_config/scripts/notify_skip/`. |
| MPV QoL scripts | The separate GPL-3 repo is an MPV Lua extension collection. It offers chapter/black-frame/silence skip detection with notification-first defaults and optional auto-skip; track selection considers language/keywords and re-evaluates late subtitle tracks; a separate script temporarily bypasses video filters during seeks and restores them after a debounced interval. | mpv-qol `README.md:13,54`; `scripts/notify_skip/main.lua:60-71,246-255,606-607,817-824`; `scripts/smart_track_selector.lua:198-228,356-405,422-453,530-563,649-663`; `scripts/reactive_vf_bypass_keyword.lua:109-133,311-372`; `script-opts/vf_bypass.conf:8-11`. |
| Relationship status | **VERIFIED** that mpv-qol scripts state they originated in Stremio Kai (`README.md:13`). **UNKNOWN** whether the exact current Stremio Kai snapshot vendors or runs this exact scripts checkout: Kai contains its own `portable_config/scripts/notify_skip` and no direct dependency/submodule to this repo was found in the inspected tree. |
| Pacing/recovery measurements | No device performance, rendered-frame statistics, UI jank, decoder counters, or repeatable startup results were available from source/config alone. | No runtime evidence. |

### NOVA applicability and unknowns

NOVA can later consider separating source/profile selection from player commands, explicitly modeling buffering versus playback state, and offering skip suggestions. Desktop MPV cache values are workload specific; do not port them into a mobile app or media_kit without measurements. No conclusions about stutter, decoder choice, fallback success, or phone/tablet UX follow from these configs. No architecture decision is made here.

## Blockers / unknowns

Stremio Kai itself had no local clone, so its source was inspected through exact-revision GitHub read-only access; one authorized agent audited the local mpv-qol-scripts checkout at the expected SHA. Kai is desktop-oriented; no phone/tablet UX was verified. Runtime MPV overrides, inherited Stremio code paths, and companion script linkage remain UNKNOWN.

## Commit / LKG

Included in the Station 07 session checkpoint. Production LKG remains `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; no production code changed.
