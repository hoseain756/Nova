# Station 00 — Persistent planning bootstrap

- Status: IN PROGRESS
- Verification status: NOT-VERIFIED (station work not yet completed)
- Checklist: 10/11 tasks complete
- Evidence:

- [x] Verify repository resolves to the authoritative NOVA root and identify the root specification copy. Evidence: working root and full spec read/hash recorded below.
- [x] Record pre-change Git status, create safety branch and baseline tag at current HEAD. Evidence: `evidence/INITIAL_GIT_STATUS.txt`; tag and branch resolve to baseline commit.
- [x] Run adb version/devices and Flutter doctor/devices; capture physical USB device identity. Evidence: `evidence/PHYSICAL_DEVICE_PREFLIGHT.md`.
- [x] Capture required device facts: hardware, display modes, codecs, power, thermal, developer settings. Evidence: `evidence/PHYSICAL_DEVICE_PREFLIGHT.md`; codec service unavailable, so config-level limits are explicitly recorded.
- [x] Verify local reference repository paths and record source/upstream availability and revisions. The three local paths do not exist; GitHub API upstream metadata and SHAs are recorded below.
- [x] Check Jellyfin Android, Jellyfin iOS, Swiftfin, and MPV reference access/fallback path. API metadata/source access works; clone paths created but Git read was denied, so use direct GitHub API evidence.
- [x] Check REA tool availability and record fallback if absent. No REA tool is enabled; direct source inspection fallback applies.
- [x] Request/inventory available test streams and Section 49 coverage gaps. No streams were attached/provided with the request; NOVA source inventory is Station 01; missing matrix entries remain NOT MEASURED.
- [x] Create master plan and concrete station files with task totals before investigation.
- [x] Record untouched production-code boundary and existing user work exclusions.
- [ ] Verify Station 00 artifacts and commit only these docs on the feature branch.

## Findings and evidence

- Full authoritative spec read from root, 98,269 characters; SHA-256 `105C6368ACE6B92CC2D793FA8CE61FB519026B56D202FA73CD26584B378F3F50`. The root file contains Section 54A. Root backup and `docs/player-reengineering/NOVA_PLAYER_PROMPT_V2_1.md` share older SHA-256 `215382A4F4839A4FDBE70D180BB7F9F254D6655C48139AAB8874915CE4E02240` and omit Section 54A. All three user-owned prompt files were left unchanged; root copy governs this task as directed.
- Current checkout resolves to `C:\Users\hosea\projects\app\Nova`; initial HEAD `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`. Existing worktree changes preserved in `evidence/INITIAL_GIT_STATUS.txt`.
- Physical device facts and exact command results/caveats: `evidence/PHYSICAL_DEVICE_PREFLIGHT.md`.
- Existing local reference paths `player-references\harbor`, `NuvioMobile`, and `Stremio-Kai` are absent; upstream metadata and revisions were queried through the connected read-only GitHub API. No original reference repository was modified.
- Upstream default refs verified: Harbor `beta-branch` @ `9b811556d13f6eb2ba7c524a5bb0d561c88fae94`; NuvioMobile `cmp-rewrite` @ `324afcffb962f1f7df45c5fa951131acec5a15a7`; Stremio-Kai `main` @ `a5a2a37e818fb5e9406caf65af374fa7fe7700af`; Jellyfin Android `master` @ `3e660a84bde87281adee8f092b8af48719734916`; Jellyfin iOS `master` @ `ceca8eb14ef79e2c0d7bde99d95213c7d69d131d`; Swiftfin `main` @ `f9842d500f2b1c3178bebbcbf67d6b82d21d47ec`; mpv-qol-scripts `main` @ `e0b04926f00ce3d482120d5bf15ebc0e32f7d94a`.
- A shallow clone attempt was authorized for Jellyfin Android/iOS and mpv-qol-scripts. Its console showed clones completing/starting, but the resulting external paths were unreadable to the sandboxed Git process (`Permission denied`); direct read-only GitHub API/source access will be the evidence fallback unless permissions are repaired without changing originals.
- GitHub metadata and page access succeeded for all named upstream repositories. These current online refs do not establish the state of missing local clones; comparison will use the exact API SHA refs above.
- REA is unavailable; clean-room source inspection is the specified fallback. No device performance measurement has been attempted.

- Authoritative root spec verified by full read (`NOVA_PLAYER_PROMPT_V2_1.md`, 98,269 characters). Root copy includes Section 54A; the 96,544-byte docs copy and backup are byte-identical older copies without 54A. No prompt files were edited.
- Pre-change `git status --short --branch` was recorded in chat/tool output before checkout; existing modifications/deletions/user files are preserved and excluded from commits.
- Safety branch `feature/player-reengineering` and tag `pre-player-reengineering-baseline` created at HEAD `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`; current branch is feature branch.
- `adb version`: 1.0.41, platform-tools 37.0.0-14910828. `adb devices -l`: physical USB `RF8NA2NNVNY` state `device`, product `a21snnxx`, model `SM_A217F`; Flutter reports Android 12/API 31, arm64.
- `flutter doctor -v`: Flutter beta 3.49.0-0.2.pre, Dart 3.14.0; Android toolchain present, Android licenses not accepted. Windows, Chrome, Edge also listed but excluded from mobile playback evidence. `flutter devices`: same physical device plus desktop/browser targets; no emulator launched.
- Initial properties: manufacturer Samsung; model SM-A217F; Android 12/API 31; SoC Exynos 850; ABI arm64-v8a; `/proc/meminfo` total 3,799,732 kB (reported by OS; marketed RAM not independently checked).
- Developer settings enabled=0; window/transition/animator scales each 1; global low_power=0. Thermal service reported AP 34.7 C, battery 33.3 C and no indicated thermal throttling, sampled once. Battery saver off per `settings get global low_power`; device charging/brightness/refresh-mode details still need focused capture before performance runs.
- ADB `dumpsys media.codec` returned `Can't find service: media.codec`; decoder inventory and hardware/software classification remain NOT MEASURED until another source can expose them.
- REA tool was not available in enabled tool inventory; fallback is direct repository inspection, and REA-dependent conclusions will remain STRONGLY INFERRED/UNKNOWN.
- `C:\Users\hosea\projects\app\player-references` yielded no subdirectories at initial check; confirm each expected path individually in Station 01. No upstream clones created.
- User did not supply stream inputs in this request. Station 01 will inventory the app's own sources and mark matrix gaps NOT MEASURED.

## Blockers / unknowns

None recorded yet.

## Commit / LKG

Pending completion; initial LKG is `c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5` (no production code changed).


