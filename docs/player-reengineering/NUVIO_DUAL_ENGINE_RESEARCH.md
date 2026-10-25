# NuvioMobile investigation — 2026-10-24

Scope: local `C:/Users/hosea/projects/app/player-refereences/NuvioMobile` source
and its bundled `composeApp/libs/lib-exoplayer-release.aar`. No execution of the
reference application. The directory has no Git repository; source revision is
UNKNOWN. LICENSE identifies GNU GPL version 3 (strong copyleft). Findings below
describe behavior in original words; no reference code or binary is incorporated.

## Evidence ledger

| Finding | Evidence | Status |
|---|---|---|
| Android Auto starts ExoPlayer and changes to libmpv after an error. Manual choices exist. | PlayerEngine.android.kt:135,159,201; PlayerModels.kt:86; PlayerSettingsRepository.kt:56 | VERIFIED in source; runtime unverified |
| Media3 version catalog says 1.8.0, but Gradle excludes several official modules and uses local AARs. The player is customized, not just stock Media3. | gradle/libs.versions.toml:28; composeApp/build.gradle.kts:552; NuvioExoPlayerPerformanceHelper.kt:6,28 | VERIFIED in source |
| Memory policy distinguishes standard allocator and custom native arena allocation, with device-memory budgets. Those values are not performance evidence for NOVA. | NuvioExoPlayerPerformanceHelper.kt:90,151 | VERIFIED in source |
| Android progress polling is 250 ms; lifecycle effects release native resources. | PlayerEngine.android.kt:500,1027,1113 | VERIFIED in source |
| iOS creates libmpv, chooses gpu-next/MoltenVK and VideoToolbox. | iosApp/iosApp/Player/MPVPlayerBridge.swift:509 | VERIFIED in source; iOS runtime unverified |
| ExoPlayer AAR identity and ZIP inventory were examined through REA. | Evidence identifiers below | VERIFIED artifact inventory; no decompilation/runtime claim |

REA target SHA-256: `d8c5a4357c4672c289164597d0eb1a5088daffdb1b1bdb94fcf5899fc4ad4a95`.
Inspection: `ev_1e586eeba20c35440255213984fda2121fd29f25eceae1bf809db49716ab86b1`.
Inventory: `ev_06eed9391b1d6d7f83c6d43587c27aee69e186376644c5006838bc89e9d10751`.
Summary: `ev_944a80c4da19a2d8610831d2efbedd73f6db063cfdc7462f4221d4a6ccbb9a92`.
Export: `.codex/nuvio-media3-rea-evidence.json` (3 records, 408563 bytes).
Inventory reports 179 occurrences, 92 files, 87 directories, zero integrity
contradictions. ZIP inventory covers entries, not all non-entry bytes. It cannot
establish allocator behavior or frame pacing. REA session was closed after export.

## Application to NOVA

Retain the useful dual-engine selection and bounded event frequency. Add explicit
error classification before fallback, serialized retirement, source identity guards,
and reuse NOVA's session/surface isolation. Use modest bounded standard buffering
until measurements justify changes; a custom allocator is not justified by source
inspection. Reuse existing media_kit/libmpv instead of importing a second mpv build.

Official implementation references consulted:
- https://developer.android.com/jetpack/androidx/releases/media3 (1.11.1 listed stable)
- https://docs.flutter.dev/release/breaking-changes/android-surface-plugins
- https://api.flutter.dev/javadoc/io/flutter/view/TextureRegistry.SurfaceProducer.Callback.html
- https://api.flutter.dev/javadoc/io/flutter/view/TextureRegistry.SurfaceProducer.html
- https://raw.githubusercontent.com/flutter/packages/main/packages/video_player/video_player_android/android/src/main/java/io/flutter/plugins/videoplayer/texture/TextureExoPlayerEventListener.java (rotation behavior; independently implemented)

Media3 uses Apache-2.0. Existing media_kit wrappers and bundled native dependencies
retain their existing license review in LICENSE_NOTES.md. No reference GPL source
or bundled AAR is added to NOVA.
