# Physical Android device preflight

Captured 2026-10-21 from the physical USB device `RF8NA2NNVNY`. This file records environment facts only, not player performance.

| Fact | Observed | Source / caveat |
|---|---|---|
| ADB | 1.0.41; platform-tools 37.0.0-14910828 | `adb version` |
| ADB state | `RF8NA2NNVNY` state `device`; product `a21snnxx`; transport_id 2 | `adb devices -l`; USB physical handset |
| Manufacturer / model | Samsung / SM-A217F | `getprop ro.product.manufacturer`, `ro.product.model` |
| Android / API | 12 / 31 | `getprop ro.build.version.release`, `ro.build.version.sdk` |
| SoC / ABI | Exynos 850 / arm64-v8a | `getprop ro.soc.model`, `ro.product.cpu.abi` |
| RAM | MemTotal 3,799,732 kB (~3.62 GiB as reported) | `/proc/meminfo`; no separate marketed-RAM verification |
| Display | 720 × 1600 physical pixels; current mode 60.000004 Hz; only mode listed is 720 × 1600 at 60.000004 Hz | `wm size`, `dumpsys display`; no other supported modes listed |
| Density | `wm density`: physical 280 dpi, override 320 dpi; `dumpsys display` reports 280 dpi for base device info | Recorded as device-reported values; do not infer app logical scale from one field |
| Cutout | Top cutout reported as 68 px by `dumpsys display` | Static system descriptor, not visual UI verification |
| Battery / power | 35%; USB powered; not AC/wireless; `settings global low_power=0` | `dumpsys battery`, `settings`; phone was charging over USB during this snapshot |
| Thermal | Thermal status 0 (none); AP 34.7 C, battery 33.3 C, other reported zones 32.7–33.5 C | Single `dumpsys thermalservice` sample; not sustained-load evidence |
| Developer options | `development_settings_enabled=0` | `settings get global`; disabled at capture |
| Animation scales | window=1, transition=1, animator=1 | `settings get global`; unchanged |
| Video decoder declarations | `/vendor/etc/media_codecs.xml` lists `OMX.Exynos.avc.dec` (H.264) and `OMX.Exynos.hevc.dec` (HEVC); `/vendor/etc/media_codecs_performance.xml` also lists Exynos entries | Vendor decoder names imply vendor/hardware path but no runtime playback has been observed |
| VP9 | `c2.android.vp9.decoder` appears in `/vendor/etc/media_codecs_performance.xml`; generic Android decoder entry is software-class. No Exynos VP9 decoder entry was found in searched vendor codec lists. | Config-file evidence only; exact runtime enumeration unavailable |
| AV1 | No AV1 entry found in the searched vendor codec XML files | NOT MEASURED at runtime; not a claim that no other vendor path exists |
| Codec service query | `dumpsys media.codec` => `Can't find service: media.codec` | Android build does not expose that service through this shell command |
| Refresh timing setup | Display service reports active mode 1 and peak-range metadata that includes 120 Hz, but supported mode list contains only one 60 Hz mode | Use measured supported mode 60 Hz for later frame budget; do not treat policy range as a mode |

Flutter preflight: `flutter doctor -v` reports Flutter beta 3.49.0-0.2.pre, Dart 3.14.0, Android SDK 36.1.0; Android licenses are not accepted. `flutter devices` lists this physical device plus Windows, Chrome, and Edge. No emulator was started or used.

Status: preflight facts are STATIC-ONLY/NOT-MEASURED as appropriate; Station 03 performance baseline remains pending and must run Profile mode on the legacy player before any production player changes.
