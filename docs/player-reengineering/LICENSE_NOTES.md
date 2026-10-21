# Reference license notes

This records repository license files at the inspected upstream refs. It is engineering diligence, not legal advice. No reference code or distinctive implementation structure has been copied into NOVA in this session.

| Reference | License file / inspected ref | Classification | Clean-room rule |
|---|---|---|---|
| Harbor | `LICENSE` at `Harborofficial/Harbor` `beta-branch` `9b811556d13f6eb2ba7c524a5bb0d561c88fae94`; header identifies MIT License | Permissive | No code reused. Describe only independently observed behavior and cite source paths. |
| NuvioMobile | `LICENSE` at `NuvioMedia/NuvioMobile` `cmp-rewrite` `324afcffb962f1f7df45c5fa951131acec5a15a7`; GNU GPL version 3 | Strong copyleft | No code, structure, or distinctive identifiers copied. Behavioral notes only in original wording. |
| Stremio-Kai | `LICENSE.md` at `allecsc/Stremio-Kai` `main` `a5a2a37e818fb5e9406caf65af374fa7fe7700af`; GNU GPL version 3 | Strong copyleft | No code, structure, or distinctive identifiers copied. Behavioral notes only in original wording. |
| Jellyfin Android | `LICENSE.md` at `jellyfin/jellyfin-android` `master` `3e660a84bde87281adee8f092b8af48719734916`; GNU GPL version 2 | Strong copyleft | No code, structure, or distinctive identifiers copied. Behavioral notes only in original wording. |
| Jellyfin iOS | `LICENSE` at `jellyfin/jellyfin-ios` `master` `ceca8eb14ef79e2c0d7bde99d95213c7d69d131d`; Mozilla Public License 2.0 | Weak copyleft | No code reused. Behavioral notes only in original wording. |
| Swiftfin (additional native iOS reference) | `LICENSE.md` at `jellyfin/Swiftfin` `main` `f9842d500f2b1c3178bebbcbf67d6b82d21d47ec`; Mozilla Public License 2.0 | Weak copyleft | No code reused. Behavioral notes only in original wording. |
| mpv-qol-scripts | `LICENSE` at `allecsc/mpv-qol-scripts` `main` `e0b04926f00ce3d482120d5bf15ebc0e32f7d94a`; GNU GPL version 3 | Strong copyleft | No scripts or distinctive identifiers copied. Behavioral notes only in original wording. |

Reference URLs:

- <https://github.com/Harborofficial/Harbor/blob/9b811556d13f6eb2ba7c524a5bb0d561c88fae94/LICENSE>
- <https://github.com/NuvioMedia/NuvioMobile/blob/324afcffb962f1f7df45c5fa951131acec5a15a7/LICENSE>
- <https://github.com/allecsc/Stremio-Kai/blob/a5a2a37e818fb5e9406caf65af374fa7fe7700af/LICENSE.md>
- <https://github.com/jellyfin/jellyfin-android/blob/3e660a84bde87281adee8f092b8af48719734916/LICENSE.md>
- <https://github.com/jellyfin/jellyfin-ios/blob/ceca8eb14ef79e2c0d7bde99d95213c7d69d131d/LICENSE>
- <https://github.com/jellyfin/Swiftfin/blob/f9842d500f2b1c3178bebbcbf67d6b82d21d47ec/LICENSE.md>
- <https://github.com/allecsc/mpv-qol-scripts/blob/e0b04926f00ce3d482120d5bf15ebc0e32f7d94a/LICENSE>

At Station 01 existing dependency licenses were not re-audited. Station 09 performs the limited review below; no new dependency is added. Full distribution compliance is not established.

## Station 09 dependency review — STATIC-ONLY, 2026-10-21

**Gate B approved scope:** personal use only; no distribution planned. Bundled native-library classification remains **unclear** (UNKNOWN / NOT-VERIFIED), with the exact-artifact LICENSE/NOTICE/build/linkage/source-obligation verification plan below retained. If distribution is ever planned, reopen license review before that step. Approval does not clear distribution or upgrade native license evidence. Option A retains existing dependencies; interface contracts remain DRAFT for Station 10.

Evidence: `pubspec.lock`, `.dart_tool/package_config.json` and resolved package files under `C:/Users/hosea/AppData/Local/Pub/Cache/hosted/pub.dev/`. No resolution, download, script execution or native build. VERIFIED here means an observed license/configuration fact, not approved distribution or runtime compatibility.

### Section 0.8 classification — media_kit stack

The following four LICENSE files were read completely from disk for the requested Gate B revision. **VERIFIED** applies to the observed text/classification; review verification is **STATIC-ONLY**. Each MIT file requires preservation of its copyright and permission notice. No code/snippet is reused by this documentation revision.

| Package / version | Exact LICENSE file | Section 0.8 classification |
|---|---|---|
| media_kit 1.2.6 | `C:/Users/hosea/AppData/Local/Pub/Cache/hosted/pub.dev/media_kit-1.2.6/LICENSE` | **Permissive — MIT** |
| media_kit_video 2.0.1 | `C:/Users/hosea/AppData/Local/Pub/Cache/hosted/pub.dev/media_kit_video-2.0.1/LICENSE` | **Permissive — MIT** |
| media_kit_libs_android_video 1.3.8 wrapper/package source | `C:/Users/hosea/AppData/Local/Pub/Cache/hosted/pub.dev/media_kit_libs_android_video-1.3.8/LICENSE` | **Permissive — MIT** |
| media_kit_libs_ios_video 1.1.4 wrapper/package source | `C:/Users/hosea/AppData/Local/Pub/Cache/hosted/pub.dev/media_kit_libs_ios_video-1.1.4/LICENSE` | **Permissive — MIT** |
| Exact bundled native libmpv/FFmpeg/transitive artifacts | Complete artifact LICENSE/NOTICE/build/linkage inventory not established | **Unclear**; evidence **UNKNOWN**, verification **NOT-VERIFIED**. Wrapper LICENSE classification does not cover every binary. |

Native distribution compatibility remains unestablished. The known upstream GPL/LGPL build possibilities below are context, not a resolved classification of the shipped artifacts. No additional package or binary was downloaded/installed to make this revision.

### Dependency decisions and remaining review

| Dependency / version | License evidence | Decision / remaining work |
|---|---|---|
| media_kit 1.2.6 | Package `LICENSE`: MIT | Retain existing adapter; preserve copyright/license notice. Native dependencies have separate terms. |
| media_kit_video 2.0.1 | Package `LICENSE`: MIT | Retain renderer; plugin build metadata observed, not build-tested. |
| media_kit_libs_android_video 1.3.8 | Package `LICENSE`: MIT wrapper; `android/build.gradle:60–64` chooses libmpv Android video build v1.1.7 default ABI jars | Wrapper license VERIFIED. Actual binary/transitive licenses/linkage/build flags UNKNOWN. Inventory exact packaged libraries/notices/source obligations before distribution reliance. |
| media_kit_libs_ios_video 1.1.4 | Package `LICENSE`: MIT wrapper; `ios/Makefile:3–15` selects Darwin v0.6.0 ios-universal-video-default archive; podspec vendors XCFrameworks and runs make | No make/pod/build executed. Binary/transitive terms UNKNOWN; package version and native artifact version differ. iOS linkage/source/relink requirements need exact artifact review. |
| provider 6.1.5+1, screen_brightness 2.1.11, volume_controller 3.7.1 | Resolved package LICENSE headers: MIT | Existing packages retained; no new state/gesture dependency. Their complete federated/native/transitive closure not audited. |
| video_player alternative (not installed/pinned) | [Publisher package/license](https://pub.dev/packages/video_player/license): BSD-3-Clause; [current API](https://pub.dev/documentation/video_player/latest/video_player/VideoPlayerController-class.html) | Option only. Before adoption: choose exact release/transitive versions, audit notices/minimum SDKs/size/capability parity/maintenance and gate approval. Current API includes audio-track selection with platform capability check. |
| Media3 for native-bridge alternative | [Upstream LICENSE](https://raw.githubusercontent.com/androidx/media/release/LICENSE): Apache-2.0 | Option only; retain LICENSE/NOTICE and review optional extensions/transitives. Apple framework use/SDK terms need separate review; no native bridge dependency approved. |

The [mpv Copyright document](https://raw.githubusercontent.com/mpv-player/mpv/master/Copyright) describes default GPLv2+ and conditional LGPLv2.1+ builds excluding GPL-only files; a flag alone is not a blanket grant. [Darwin build README](https://raw.githubusercontent.com/media-kit/libmpv-darwin-build/main/README.md) distinguishes build variants. These upstream facts do not prove the exact v1.1.7/v0.6.0 artifacts' entire license closure. Native libmpv/FFmpeg and included components must be checked against actual build recipes/artifact notices and linkage, including applicable corresponding source/relink obligations. Do not label bundled native binaries MIT because the Flutter wrapper is MIT. Upstream Android build README fetch failed; no license inferred from the artifact name `default`.

Option A adds/upgrades no dependency. Packaging size, upstream responsiveness/security support, codec fidelity and performance benefits remain UNKNOWN / NOT-VERIFIED where unmeasured. Exact App Store/Play Store compatibility remains NOT-VERIFIED; no distribution approval requested in this planning draft. A license issue may require a new architecture/dependency decision rather than silent substitution.

Clean-room discipline is unchanged: GPL references and MPL references are behavioral investigation only; no code/structure/distinctive identifiers/scripts copied. Harbor's MIT terms are recorded but no snippet reused. Gate B explicitly lists copyleft references for user review. New dependencies, native replacement, deployment/signing/major-toolchain changes remain conditional gates. No legal-policy change is made by this engineering note.
