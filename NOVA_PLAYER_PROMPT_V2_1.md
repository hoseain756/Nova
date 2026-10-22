> **V2 NOTE:** This version adds Section 0 (real execution environment, human review gates, safety net, fallbacks, licensing),
> plus V2 additions inside Stations 01, 03, 17, 18, Sections 49 / 51A / 54 and the final START NOW list.
> **If any text anywhere in this document conflicts with Section 0, Section 0 wins.**
>
> **V2.1 NOTE:** fixes execution conflicts only: (1) missing-device handling now defers Station 03 instead of hard-stopping the whole mission, and Gate A cannot pass without a baseline or my written waiver (0.3, 0.4A); (2) rollback is now scope-checked and non-destructive (0.6); (3) Debug vs Profile/Release usage is stated unambiguously (0.6.4, 0.9); (4) legacy-player removal now waits for Gate E, not Gate D (0.6.7, Section 71 addendum); (5) Jellyfin investigations must verify the real playback engine first (Stations 06A/06B). No engineering detail was removed.

# NOVA PLAYER — COMPLETE REVERSE ENGINEERING, PERFORMANCE REBUILD & EXECUTION SYSTEM

You are the primary engineering agent responsible for re-engineering the video playback system of my existing Flutter application:

# NOVA

You are operating from inside the NOVA repository.

The authoritative local NOVA project path is:

```text
C:\Users\hosea\projects\app\Nova
```

Before doing any work, verify that the current working repository resolves to this NOVA project path (or the same repository through an equivalent resolved path).

Your mission is to deeply investigate NOVA's existing player, investigate five reference applications/projects (three local repositories plus Jellyfin Android and Jellyfin iOS from their upstream repositories) and one supplementary MPV scripts repository, use **REA — Reverse Engineer Anything** where it provides useful evidence, identify the actual causes of NOVA's playback problems, design the correct architecture, implement the new player system, test it, profile it, verify it, and complete the entire execution plan.

The final result must be a production-grade Flutter video player for:

- Android phones
- iPhones
- Android tablets
- iPads

The player must prioritize:

**Correctness → Playback Stability → Performance → Reliability → Maintainability → UX → Visual Effects**

This is NOT:

- a UI-copying task
- a blind code-porting task
- a simple refactor
- a dependency-upgrade task
- a task to copy one reference project's player
- a task to immediately replace the playback engine

This is a complete engineering investigation and rebuild.

The mandatory workflow is:

**Plan → Inspect → Measure → Investigate → Compare → Diagnose → Design → Implement → Test → Profile → Verify → Audit → Report**

---

# 0. EXECUTION ENVIRONMENT, REVIEW GATES & SAFETY NET (AUTHORITATIVE)

Everything in this section is a fact about my real setup or a rule that overrides conflicting text elsewhere.

## 0.1 Real environment

- Development machine: **Windows**. NOVA path and reference paths are as given above.
- **Android testing = ONE OR MORE PHYSICAL DEVICES CONNECTED OVER USB (adb) ONLY.**
  - NO emulators. NO AVDs. NO cloud device farms.
  - Never create, download, or start an Android emulator, even if no device is connected.
- **iOS: there is NO Mac, NO Xcode, NO iOS Simulator, and NO iPhone/iPad attached to this machine.**
  - iOS builds will be produced LATER through **Codemagic** (CI on macOS).
  - Therefore you can NOT run, profile, or visually verify anything on iOS.
  - iOS work in this mission = careful static engineering + a CI build configuration + a manual test checklist for me. See 0.5.
- **Tablets:** physical tablet verification exists only if I connect a physical Android tablet. Otherwise tablet UX is verified through widget tests at tablet logical sizes (layout logic only, never performance). iPad = same limits as iOS.
- Flutter Windows desktop / Chrome targets must NOT be used as evidence of mobile playback performance. They may be used only for compilation or unit/widget tests.

## 0.2 Verification status vocabulary (mandatory)

Every feature and every platform claim in the plan files, findings, and reports must carry exactly one of:

```text
VERIFIED-ON-DEVICE   Executed on a physical device, with recorded evidence (logs/metrics/notes).
BUILD-VERIFIED       Compiles; analyze + tests pass (and/or Codemagic build passes). Never run.
STATIC-ONLY          Code review / reasoning only.
NOT-VERIFIED         Not checked at all.
BLOCKED              Cannot be checked; reason and unblock requirement recorded.
```

Rules:

- iOS runtime behavior can never be rated above `BUILD-VERIFIED` unless I give you real on-device results.
- Anything done on emulator/desktop/web is NOT `VERIFIED-ON-DEVICE`.
- This vocabulary applies on top of the VERIFIED / STRONGLY INFERRED / UNKNOWN evidence standard in Section 5 (that one classifies reference-project findings; this one classifies NOVA's own work).

## 0.3 Preflight (do this at the very start of Station 00, before Station 01)

1. `adb version` and `adb devices -l`.
   - At least one device must be in state `device` (not `unauthorized`, not `offline`).
   - Run `flutter doctor -v` and `flutter devices`, and record the exact device id used for all runs.
2. Record device facts (these define what every measurement means):
   - manufacturer, model, Android version, API level, SoC/ABI, RAM
   - display size, density, current refresh rate and all supported display modes
   - hardware video decoders available (H.264 / HEVC / VP9 / AV1) and whether each is hardware or software
   - battery saver state, thermal state, developer options state, animation scale
3. If NO device is connected (or it is `unauthorized`/`offline`):
   - Mark Station 03 `Status: BLOCKED` (reason: no usable physical device) in its station file and in `00_MASTER_PLAN.md`. This is a DEFERRAL, not a mission stop.
   - Continue every station that needs no device: 01, 02, 04–08 and any other read-only investigation. Do not start any implementation station (10 onward).
   - Do NOT change any production player code while the baseline is missing. The baseline must always be captured on the legacy player BEFORE the first production player change, whenever the device becomes available.
   - At Gate A (0.4A) tell me exactly what to do: connect and unlock the phone, accept the RSA prompt, enable USB debugging, keep the screen awake. Do NOT substitute an emulator.
4. Create the safety branch/tag described in 0.6 BEFORE touching any NOVA file.
5. Request the test inputs described in 0.7 (test streams). If they are missing, proceed with what exists and mark gaps as `NOT MEASURED`.

## 0.4 HUMAN REVIEW GATES (these OVERRIDE every "do not stop" / "do not ask for approval" statement)

Between gates, continue autonomously station by station. At each gate you MUST stop and wait for my reply.

| Gate | When | Why it exists |
|---|---|---|
| **GATE A** | After Station 08 (Root-Cause Analysis) | Confirm the diagnosis and the measured baseline before any design work builds on them. The baseline must exist, or I must have explicitly waived it (see 0.4A). |
| **GATE B** | After Station 09 (Final Architecture + engine decision) | Approve the architecture and engine decision BEFORE any production player code is changed. This is the most important gate. |
| **GATE C** | After Station 10 (Playback Core Stabilization) | I play the build on my own device and judge whether playback actually feels smooth, before UI/features are layered on top. |
| **GATE D** | After Station 16 (features + UI complete) | Device acceptance test by me; also the moment I run the Codemagic iOS build. |
| **GATE E** | After Station 20 (Final Audit) | Final report review AND my decision on removing the legacy player (see 0.6.7). |

Conditional gates (stop immediately when any occurs, even between scheduled gates):

- a new dependency or a native-engine replacement is needed
- a change could migrate or break stored user data (resume positions, watch history, settings)
- unrelated uncommitted changes overlap player files
- a change touches Android signing, iOS signing, deployment targets, Podfile platform versions, or Gradle/AGP major versions
- a Station is BLOCKED and the blocker invalidates later architecture
- the last-known-good rule in 0.6 triggers a revert

Gate procedure:

1. Write `docs/player-reengineering/GATE_<letter>_REVIEW.md` containing: what was done, evidence, measured numbers, decisions requested, your recommended option with reasons, risks, and what happens next.
2. Commit the checkpoint on the feature branch (see 0.6).
3. Send me a SHORT chat message: gate name, 5-10 line summary, the exact decision(s) needed, path to the review file.
4. STOP. Resume only after I reply. If I reply "continue" without changes, proceed with your recommended option.

Do NOT send chat updates between gates (Section 60 still applies). The Markdown plan files remain the progress tracker.

## 0.4A GATE A WHEN THE BASELINE IS MISSING

Gate A cannot be passed silently without a Station 03 baseline.

1. If Station 03 is `BLOCKED` at Gate A, the Gate A review file must start with a bold line: `BASELINE MISSING — DEVICE NOT AVAILABLE` and list what the diagnosis in Station 08 can and cannot claim without measurements (everything unmeasured is `STRONGLY INFERRED` or `UNKNOWN`).
2. You stop and wait. My reply is one of:
   - **"device connected"** → run Station 03 on the legacy player per 0.9, update `BASELINE.md`, re-check the Station 08 diagnosis against the numbers, and amend the Gate A file. Stop AGAIN only if the numbers contradict the diagnosis or change the likely engine decision; otherwise continue to Station 09.
   - **"waive baseline"** (explicit written waiver from me) → continue, but every BEFORE value in the final BEFORE/AFTER table is `NOT MEASURED`, the Gate B review file must state that the architecture decision has reduced confidence, and Section 51A targets that depend on a baseline are measured as absolute values only.
   - Anything else → ask once, briefly, for one of the two options above. Do not guess.
3. The mission never proceeds past Gate A with neither a baseline nor a written waiver.

---

## 0.5 iOS WITHOUT A MAC (Codemagic) — rules

Goal: maximize the chance that the iOS build compiles and behaves correctly on the first CI run, and give me everything I need to test it.

1. **Prefer Dart-level and plugin-level solutions.** Minimize hand-written Swift/Objective-C/Podfile/Info.plist/AppDelegate changes, because you cannot compile them locally.
2. Every native iOS change MUST be logged in `docs/player-reengineering/ios/IOS_UNCOMPILED_CHANGES.md` with: file, reason, risk, and how it should be verified on first CI/device run. Mark each `BUILD-VERIFIED` only after a Codemagic build passes.
3. Static iOS configuration review (Station 18), at minimum:
   - Info.plist: `UIBackgroundModes` (audio, if background audio is intended), orientation keys for iPhone and iPad (`UISupportedInterfaceOrientations` and `~ipad`), required usage descriptions
   - Podfile: platform version vs. what the player/plugin dependencies require; frameworks/linkage settings
   - AVAudioSession category/mode/options and interruption handling (calls, Siri, headphones unplugged)
   - app lifecycle: background/foreground, lock screen, now-playing/remote-command behavior if used
   - safe areas, Dynamic Island, home indicator, orientation lock and rotation behavior
   - fullscreen behavior on iPhone vs. iPad, split view / Stage Manager risks on iPad
   - AirPlay / PiP: decide in/out of scope and document it
4. **CI configuration:** inspect NOVA's root for `codemagic.yaml`.
   - If missing, create one (this is a NOVA change) with a macOS workflow: `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build ios --release --no-codesign` (unsigned compile check). Add a clearly commented, optional signed-IPA section for me to complete.
   - NEVER invent bundle identifiers, team IDs, certificates, provisioning profiles, or secrets. Use clearly marked placeholders and list in the gate file exactly what I must configure in Codemagic.
   - Never commit secrets.
5. Create `docs/player-reengineering/ios/IOS_MANUAL_TEST_CHECKLIST.md` — a step-by-step checklist I can run on a real iPhone and iPad with pass/fail columns and "what to report if it fails". It must cover at least: first-frame/start, seeking, subtitle switching (embedded + external), audio-track switching, playback speed, background/foreground (with and without background audio), screen lock, orientation changes, safe areas/notch/Dynamic Island, incoming call or Siri interruption, headphone unplug, AirPlay (if in scope), resume, skip intro/recap/outro, next-episode countdown, repeated source switching, and 10+ minute playback.
6. After Gate D I will run the Codemagic build and may paste build logs back to you. Fix compile/config errors iteratively. Even with a green CI build, iOS stays `BUILD-VERIFIED`, never `VERIFIED-ON-DEVICE`.
7. The final report must contain an explicit iOS status table using the 0.2 vocabulary.

## 0.6 SAFETY NET — Git, last-known-good, rollback

1. Before the first change: run `git status`, record it. Create branch `feature/player-reengineering` from the current HEAD and a lightweight tag `pre-player-reengineering-baseline` at HEAD.
2. Never stash, reset, clean, or commit MY unrelated uncommitted changes. If they overlap player files → conditional gate.
3. Commit policy:
   - After each station passes its station gate, commit ONLY the NOVA files that station touched, on the feature branch, message `player: station NN <name>`.
   - Documentation under `docs/player-reengineering/` may be committed with it.
   - NEVER push. NEVER force-push. NEVER `reset --hard`, `clean -fd`, or `checkout -- .` on files you did not change.
4. **Last-known-good (LKG) rule.** At the end of every station that changes code, all of these must pass:
   - `flutter pub get`, `flutter analyze`, `flutter test`
   - a profile or debug APK builds and installs on the physical device and the app launches and plays a video
   - **Debug builds are allowed ONLY for these functional/LKG checks and for ordinary development.** Any performance claim (jank, dropped frames, startup, seek, memory, CPU) requires Profile or Release mode (0.9).
5. If the LKG checks fail and 3 focused fix attempts do not repair them, roll back ONLY after a scope check:
   1. Run `git status`, `git log --oneline` since the last LKG commit, and `git show --stat` for each commit of the failing station. Write the list of files changed by the station.
   2. Compare that list with (a) any later commits and (b) my uncommitted changes. If NO file overlaps, undo the station with `git revert` (one revert commit per station commit, newest first). Never use `reset --hard`, `clean`, or wildcard checkout/restore.
   3. If uncommitted work of the failing station was never committed, restore ONLY those exact file paths that you yourself changed (`git restore <explicit paths>`), after listing them.
   4. If ANY overlap with later commits or my changes exists, do NOT revert automatically. Create a non-destructive recovery branch `recovery/station-NN` from the last LKG commit, continue the diagnosis there, and trigger a conditional gate describing the overlap.
   5. In every case mark the station `BLOCKED`, document why, and record the resulting LKG commit hash. Never leave the active branch in a non-building state.
6. Record the current LKG commit hash in `00_MASTER_PLAN.md` after every station.
7. **Keep the legacy player selectable** (debug flag or settings switch) until the whole evidence chain is complete: Gate D passed, Station 19 long-playback/regression results recorded, Station 20 final audit done, and **Gate E approved by me**. Only then, and only if I approve in my Gate E reply, remove the legacy player in a SEPARATE final commit (`player: remove legacy player`) after creating the tag `pre-legacy-removal`. If I do not approve, or if any 51A target is unmet or unmeasured, keep it behind the flag and document why. Early removal is allowed only with a documented engineering necessity approved at a conditional gate. The rest of Section 71 cleanup (instrumentation, duplicate controllers, debug prints) is unaffected, see the Section 71 addendum.
8. On the device: touch ONLY NOVA. Never uninstall other apps, never factory reset, never run `pm clear` on NOVA without recording it first (it deletes app data). Restore any system setting you change for testing (rotation lock, animation scales, brightness, etc.).

## 0.7 FALLBACKS (so a missing tool never silently derails the mission)

- **REA unavailable:** record it in Station 01 and continue with direct source inspection. Conclusions that would have needed REA are classified STRONGLY INFERRED or UNKNOWN. This is NOT a blocker.
- **Reference repos / GitHub unavailable:**
  1. For Jellyfin Android, Jellyfin iOS, and mpv-qol-scripts first try a shallow clone into a NEW directory `C:\Users\hosea\projects\app\player-references-upstream\<repo-name>` (this does not touch the three existing reference repos). Record the commit SHA. These clones are read-only afterwards.
  2. If cloning is impossible, use web fetch/search on the upstream repository.
  3. If both fail, mark that reference station `BLOCKED`, continue the others, and ask me at Gate A/B to provide a local clone. Gate B documentation must state which evidence is missing.
- **jellyfin-ios note:** record what that repository's playback actually is. If playback is not a native AVPlayer/AVFoundation pipeline (for example it is cross-platform or web-based), say so and ALSO inspect Jellyfin's native iOS client `https://github.com/jellyfin/Swiftfin` as an additional read-only iOS reference, so the iOS comparison is based on a real native player.
- **Test streams:** use the streams/sources I provide or NOVA's own real sources first. If the matrix in Section 49 has gaps, you may use well-known public test streams (for example Big Buck Bunny files or Apple's public HLS samples), recording each URL, and clearly noting they do not replicate my real sources. Never fabricate results for streams you could not play.
- **Second device / tablet:** if I have not connected one, record `NOT MEASURED` for that device class. Do not extrapolate numbers from one device to others.

## 0.8 LICENSING & CLEAN-ROOM DISCIPLINE

This strengthens Section 6. At Station 01 create `docs/player-reengineering/LICENSE_NOTES.md`:

- For every reference repo (Harbor, NuvioMobile, Stremio-Kai, Jellyfin Android, Jellyfin iOS/Swiftfin if used, mpv-qol-scripts): record the LICENSE file and classify as permissive / weak copyleft / strong copyleft (GPL/AGPL) / no license / unclear.
- For copyleft, no-license, or unclear repos: do NOT copy code, structure, or distinctive identifiers. Record behavior and design ideas in your own words, then implement independently for NOVA.
- For permissive repos: still do not copy wholesale; if any snippet is reused, record file, license, and attribution requirements.
- Any NEW dependency must have its license recorded and checked for compatibility with NOVA's distribution (App Store / Play Store).
- If a reference is copyleft or has no license, mention it in the Gate B review file so I can decide. (This is engineering diligence, not legal advice.)

## 0.9 MEASUREMENT PROTOCOL (used by Stations 03, 10, 19)

All performance evidence must follow these rules, otherwise it is invalid:

1. **Profile or release mode only for performance evidence.** Debug builds are permitted solely for functional checks (0.6.4) and development; debug-mode numbers are never performance evidence (Flutter debug mode is much slower and misleading).
2. Same device, same stream, same network, same brightness, battery saver off, device charged, and cooled down between runs. Record all of this.
3. At least 3 runs per scenario; report median and min/max. Discard the first ~30 s of each run for steady-state numbers, but still report time-to-first-frame separately.
4. Use a refresh-rate-aware frame budget: `1000 / refresh_rate_hz` ms (16.7 ms at 60 Hz, 8.3 ms at 120 Hz).
5. **Flutter UI jank sources** (primary): Flutter's own frame timings (`SchedulerBinding.addTimingsCallback`, DevTools performance/timeline captured from `flutter run --profile`). Use `adb shell dumpsys gfxinfo <package> framestats` and SurfaceFlinger latency only as cross-checks where they return meaningful data for a Flutter app — do not trust them blindly.
6. **Decoder/video drops:** use the playback engine's own statistics if exposed (for example dropped-frame / decoder-drop counters, estimated vsync, rendered-frame counters). Keep decoder drops strictly separate from Flutter UI jank.
7. **Memory/CPU:** `adb shell dumpsys meminfo <package>` (PSS, native heap, graphics) sampled over time; `adb shell top` / `dumpsys cpuinfo` for CPU. Memory growth must be judged after a forced GC and excluding legitimate buffer/cache.
8. Create a **debug/profile-only** diagnostics helper (for example `PlayerDiagnostics`) that logs frame-timing summaries, rebuild counters, player-event rates, and recreation counters to logcat or a file. It must be compiled out of release builds, and any leftover temporary instrumentation is removed during the Section 71 cleanup (before Station 20).
9. Anything not measurable is `NOT MEASURED` with a reason. Never fabricate numbers.

---

# 1. KNOWN NOVA PLAYER PROBLEMS

NOVA's current player has multiple serious problems.

The most important known issues are:

- playback stuttering
- video that does not feel smooth
- dropped frames
- inconsistent frame pacing
- unreliable playback behavior
- player UI that may negatively affect playback
- problems around subtitle settings
- problems around audio settings
- problems around playback-speed settings
- source switching behavior
- resume playback experience
- intro/recap/outro skipping
- next-episode flow
- player overlays and controls
- phone landscape experience
- tablet player experience

Do NOT assume the cause.

Dropped frames may originate from different layers.

You must distinguish between:

1. Flutter UI jank
2. decoder/video dropped frames
3. network buffering
4. stream quality/server problems
5. texture/surface rendering problems
6. player state architecture problems
7. excessive Flutter rebuilds
8. event flooding
9. subtitle rendering
10. incorrect lifecycle management
11. decoder configuration
12. hardware acceleration
13. frame-rate/display mismatch
14. memory/resource problems

Do not call all of these simply "lag".

Find the actual causes.

---

# 2. REFERENCE PROJECTS

I have already downloaded three complete reference projects from GitHub.

Their parent directory is:

```text
C:\Users\hosea\projects\app\player-references
```

The exact local directories are:

```text
C:\Users\hosea\projects\app\player-references\
├── harbor\
├── NuvioMobile\
└── Stremio-Kai\
```

Map them as:

## Harbor

Local path:

```text
C:\Users\hosea\projects\app\player-references\harbor
```

Upstream repository:

```text
https://github.com/Harborofficial/Harbor
```

## Nuvio

Local path:

```text
C:\Users\hosea\projects\app\player-references\NuvioMobile
```

Upstream repository:

```text
https://github.com/NuvioMedia/NuvioMobile
```

## Stremio Kai

Local path:

```text
C:\Users\hosea\projects\app\player-references\Stremio-Kai
```

Upstream repository:

```text
https://github.com/allecsc/Stremio-Kai
```

## Jellyfin Android

Upstream repository:

```text
https://github.com/jellyfin/jellyfin-android.git
```

Use Jellyfin Android as a primary read-only Android playback reference.

Investigate it specifically for:

- Android-native playback architecture
- player engine/backend selection
- Media3 / ExoPlayer usage where applicable
- MediaCodec / hardware decoding behavior
- Surface / Texture / rendering decisions
- buffering and seeking behavior
- subtitle handling
- audio-track handling
- playback-speed behavior
- resume / playback progress
- lifecycle and audio-focus handling
- Android TV/mobile differences where relevant
- frame pacing / refresh-rate behavior where relevant
- error recovery and source/session management

Do not assume its architecture is directly transferable to Flutter. Extract engineering lessons and independently adapt only what is appropriate for NOVA.

## Jellyfin iOS

Upstream repository:

```text
https://github.com/jellyfin/jellyfin-ios.git
```

Use Jellyfin iOS as a primary read-only iOS playback reference.

Investigate it specifically for:

- iOS-native playback architecture
- AVFoundation / AVPlayer usage where applicable
- hardware decoding
- rendering pipeline
- subtitle handling
- audio-track handling
- playback-speed behavior
- seeking
- buffering
- resume / playback progress
- AVAudioSession behavior
- application lifecycle
- background / foreground transitions
- orientation / fullscreen behavior
- AirPlay / external playback considerations where relevant
- error recovery and session management

Do not assume its architecture is directly transferable to Flutter. Extract engineering lessons and independently adapt only what is appropriate for NOVA.

## Supplementary MPV reference — mpv-qol-scripts

Upstream repository:

```text
https://github.com/allecsc/mpv-qol-scripts
```

No local path has been provided for `mpv-qol-scripts`.

Treat it as a supplementary read-only engineering reference, especially when investigating Stremio Kai's MPV behavior, scripts, playback quality-of-life logic, player configuration, track behavior, seeking, playback controls, or other MPV-specific techniques.

If direct GitHub access is available, inspect it from the upstream repository. Do NOT modify it.

If later a local copy is discovered inside the provided reference tree, record its exact path before using it. Do not invent a local path.

The three local application repositories are reference material.

The supplementary `mpv-qol-scripts` repository is also reference material.

None of these repositories are part of NOVA.

---

# 3. REFERENCE PROJECT SAFETY RULES

Treat all three local reference repositories, Jellyfin Android, Jellyfin iOS, and the supplementary `mpv-qol-scripts` repository as:

# READ ONLY

You MUST NOT:

- modify them
- format their files
- delete anything inside them
- rename files
- move files
- commit changes
- run automated code modifications
- add NOVA code to them
- treat them as writable workspaces
- modify dependency files
- alter their Git state unnecessarily

NOVA is the only writable production application.

Conceptually:

```text
NOVA
↓
READ + WRITE


Harbor
Nuvio
Stremio Kai
Jellyfin Android
Jellyfin iOS
mpv-qol-scripts
↓
READ ONLY
```

Before executing commands that modify files, verify that the target belongs to NOVA.

All implementation must happen inside NOVA.

All planning documents must be created inside:

```text
NOVA/docs/player-reengineering/
```

Never place NOVA planning documents inside the reference repositories.

---

# 4. REFERENCE SOURCE PRIORITY

Because complete source repositories are available locally, use this investigation priority:

1. direct source-code inspection
2. dependency inspection
3. configuration inspection
4. architecture tracing
5. Git metadata/history/tags where useful
6. REA-assisted investigation
7. runtime investigation where available
8. compiled binary/APK analysis only where it provides additional evidence

Do not unnecessarily reverse engineer behavior that is already clearly visible and verifiable in the source.

REA must complement source investigation rather than replace it.

However, use REA wherever it helps reveal:

- compiled behavior
- native integrations
- hidden playback behavior
- package/native boundaries
- runtime architecture
- player implementation details not obvious from source alone

---

# 5. EVIDENCE STANDARD

Every important engineering conclusion must be classified as one of:

## VERIFIED

Directly supported by source/runtime/tool evidence.

## STRONGLY INFERRED

Supported by multiple pieces of evidence but not directly observable.

## UNKNOWN

Insufficient evidence.

Never convert UNKNOWN into a fact.

When recording important findings include:

- project
- file/component
- exact relative path where applicable
- discovered behavior
- evidence
- confidence level
- relevance to NOVA

Example:

```text
Project: Harbor
Path: <relative path>
Finding: ...
Evidence: ...
Confidence: VERIFIED
Relevance to NOVA: ...
```

---

# 6. COPYRIGHT / IMPLEMENTATION BOUNDARY

The reference projects exist to teach us engineering approaches.

Do NOT blindly copy:

- proprietary source code
- copyrighted assets
- branding
- application-specific UI
- project identity
- entire implementations

Understand:

- architecture
- control flow
- player lifecycle
- performance techniques
- state model
- track management
- buffering strategy
- interaction design

Then independently implement the correct solution for NOVA.

Respect repository licenses.

---

# 7. MANDATORY PERSISTENT EXECUTION SYSTEM

Before modifying NOVA production code, create:

```text
docs/player-reengineering/
```

This directory becomes the authoritative source of truth for the entire mission.

Do not rely on conversation memory.

The project may continue across multiple Codex sessions.

Another agent must be able to open the documentation and immediately understand:

- what was completed
- what remains
- current station
- current task
- findings
- architectural decisions
- tests already performed
- failures
- blockers
- what should happen next

---

# 8. CREATE MASTER PLAN BEFORE IMPLEMENTATION

The FIRST persistent file must be:

```text
docs/player-reengineering/00_MASTER_PLAN.md
```

It must include:

- mission
- known NOVA issues
- reference projects
- reference paths
- repository constraints
- investigation strategy
- execution rules
- station order
- station dependencies
- current station
- progress
- findings
- architectural decisions
- risks
- blockers
- global acceptance criteria
- final completion state

Create a station dashboard.

At minimum:

| # | Station | Status | Tasks | Completed | Blocked |
|---|---|---|---:|---:|---:|
| 01 | Environment & Repository Discovery | ☐ | 0 | 0 | 0 |
| 02 | NOVA Current Player Audit | ☐ | 0 | 0 | 0 |
| 03 | NOVA Performance Baseline | ☐ | 0 | 0 | 0 |
| 04 | Harbor Investigation | ☐ | 0 | 0 | 0 |
| 05 | Nuvio Investigation | ☐ | 0 | 0 | 0 |
| 06 | Stremio Kai Investigation | ☐ | 0 | 0 | 0 |
| 06A | Jellyfin Android Investigation | ☐ | 0 | 0 | 0 |
| 06B | Jellyfin iOS Investigation | ☐ | 0 | 0 | 0 |
| 07 | Cross-Project Comparison | ☐ | 0 | 0 | 0 |
| 08 | Root-Cause Analysis | ☐ | 0 | 0 | 0 |
| 09 | NOVA Player Architecture | ☐ | 0 | 0 | 0 |
| 10 | Playback Core Stabilization | ☐ | 0 | 0 | 0 |
| 11 | Controls & Gestures | ☐ | 0 | 0 | 0 |
| 12 | Tracks, Settings & Sources | ☐ | 0 | 0 | 0 |
| 13 | Resume Playback | ☐ | 0 | 0 | 0 |
| 14 | Skip Segments | ☐ | 0 | 0 | 0 |
| 15 | Next Episode | ☐ | 0 | 0 | 0 |
| 16 | NOVA Player UI / Liquid Glass | ☐ | 0 | 0 | 0 |
| 17 | Android Verification | ☐ | 0 | 0 | 0 |
| 18 | iOS Verification | ☐ | 0 | 0 | 0 |
| 19 | Performance Regression & Long Playback | ☐ | 0 | 0 | 0 |
| 20 | Final Audit & Completion Report | ☐ | 0 | 0 | 0 |

You may add or split stations when repository evidence proves it necessary.

Do not remove important work simply to reduce the plan.

---

# 9. CREATE ONE FILE FOR EVERY STATION

Create:

```text
docs/player-reengineering/
├── 00_MASTER_PLAN.md
├── 01_ENVIRONMENT_DISCOVERY.md
├── 02_NOVA_PLAYER_AUDIT.md
├── 03_PERFORMANCE_BASELINE.md
├── 04_HARBOR_INVESTIGATION.md
├── 05_NUVIO_INVESTIGATION.md
├── 06_STREMIO_KAI_INVESTIGATION.md
├── 06A_JELLYFIN_ANDROID_INVESTIGATION.md
├── 06B_JELLYFIN_IOS_INVESTIGATION.md
├── 07_CROSS_PROJECT_COMPARISON.md
├── 08_ROOT_CAUSE_ANALYSIS.md
├── 09_NOVA_PLAYER_ARCHITECTURE.md
├── 10_PLAYBACK_CORE_STABILIZATION.md
├── 11_CONTROLS_AND_GESTURES.md
├── 12_TRACKS_SETTINGS_SOURCES.md
├── 13_RESUME_PLAYBACK.md
├── 14_SKIP_SEGMENTS.md
├── 15_NEXT_EPISODE.md
├── 16_NOVA_PLAYER_UI.md
├── 17_ANDROID_VERIFICATION.md
├── 18_IOS_VERIFICATION.md
├── 19_PERFORMANCE_REGRESSION.md
├── 20_FINAL_AUDIT.md
└── FINAL_REPORT.md
```

Do not create `FINAL_REPORT.md` as a fake completed report at the beginning.

Create/populate it when final auditing is actually reached.

---

# 10. REQUIRED STATION DOCUMENT STRUCTURE

Every station file must contain:

```text
# Station XX — Name

## Status

## Objective

## Scope

## Prerequisites

## Inputs

## Tasks

## Evidence Required

## Findings

## Decisions

## Files Inspected

## Files Modified

## Tests / Verification

## Performance Evidence

## Blockers

## Acceptance Criteria

## Station Completion Review

## Next Station
```

Adapt where appropriate.

These are working execution files, not generic essays.

---

# 11. CHECKBOX EXECUTION SYSTEM

Every executable task must exist as a Markdown checkbox.

Unfinished:

```text
- [ ] Task
```

Completed AND verified:

```text
- [x] Task
```

A task is NOT complete just because code was written.

Only mark `[x]` after its verification succeeds.

Example:

```text
- [ ] Locate NOVA player entry point
- [ ] Identify playback engine
- [ ] Trace controller lifecycle
- [ ] Trace renderer/video surface
- [ ] Trace position-event pipeline
- [ ] Measure Widget rebuild frequency
- [ ] Inspect subtitle rendering
- [ ] Inspect buffering configuration
- [ ] Inspect hardware decoding
- [ ] Record findings
- [ ] Verify findings
```

Update checkboxes DURING execution.

Do not reconstruct them from memory afterward.

---

# 12. STRICT STATION GATE

Stations execute sequentially unless documented evidence justifies a dependency-safe exception.

Before moving from Station N to Station N+1:

1. reopen the station document
2. inspect all tasks
3. verify completed work
4. execute required tests
5. record findings
6. record decisions
7. record failures
8. record unresolved issues
9. evaluate acceptance criteria
10. update checkboxes
11. update master plan
12. mark station status

Only when verified should the station become:

```text
Status: COMPLETE ✓
```

Then move to the next station.

Do not mark a station complete merely because implementation exists.

---

# 13. BLOCKED TASK POLICY

Never fake completion.

If a task cannot be completed because of:

- unavailable physical device
- missing service
- missing credentials
- missing binary
- unsupported environment
- operating-system limitation
- unavailable platform
- external dependency
- tooling failure outside NOVA

mark it as:

```text
Status: BLOCKED
```

Document:

- blocked task
- reason
- evidence
- impact
- requirement to unblock
- whether other work may safely continue

Blocked tasks remain unchecked.

Never convert a blocker into `[x]`.

If a blocker invalidates later architectural work, stop at the relevant gate rather than guessing.

---

# 14. CONTINUOUS MASTER PLAN SYNCHRONIZATION

After every station:

Update:

```text
docs/player-reengineering/00_MASTER_PLAN.md
```

Update at least:

- station status
- number of tasks
- completed tasks
- blocked tasks
- current station
- next station
- new findings
- new risks
- architecture decisions
- dependency decisions

The master plan must reflect actual repository state at all times.

---

# 15. SESSION RESUMABILITY

Assume work may span multiple sessions.

Whenever starting or resuming:

1. read `00_MASTER_PLAN.md`
2. identify current station
3. read the station file
4. inspect actual repository state
5. compare repository state with documentation
6. resume at the first incomplete task

Never depend on conversational memory for critical execution state.

If documentation and source disagree:

**source/repository reality wins.**

Correct the plan accordingly.

---

# 16. STATION 01 — ENVIRONMENT & REPOSITORY DISCOVERY

Before implementation discover and document:

## NOVA

- project root
- Flutter version
- Dart version
- dependency versions
- Android configuration
- iOS configuration
- app architecture
- state-management approach
- current video dependencies
- testing infrastructure
- existing player tests
- current NOVA UI architecture
- responsive architecture
- existing Liquid Glass system/skill usage

## NOVA path verification

Verify that the writable production project is:

```text
C:\Users\hosea\projects\app\Nova
```

## References

Verify the three local read-only reference repositories:

```text
C:\Users\hosea\projects\app\player-references\harbor
C:\Users\hosea\projects\app\player-references\NuvioMobile
C:\Users\hosea\projects\app\player-references\Stremio-Kai
```

Record and cross-check their upstream repositories:

```text
Harbor      → https://github.com/Harborofficial/Harbor
Nuvio       → https://github.com/NuvioMedia/NuvioMobile
Stremio Kai → https://github.com/allecsc/Stremio-Kai
```

Also verify read-only access to the two Jellyfin upstream repositories:

```text
Jellyfin Android → https://github.com/jellyfin/jellyfin-android.git
Jellyfin iOS     → https://github.com/jellyfin/jellyfin-ios.git
```

Also verify access, where available, to the supplementary read-only MPV reference:

```text
https://github.com/allecsc/mpv-qol-scripts
```

For each local reference repository determine:

- Git repository availability
- current branch
- commit SHA if available
- tags/version
- primary framework/language
- player location
- playback dependencies
- native player dependencies
- platform-specific player code
- relevant build configuration

Record exact states used for comparison.

For Jellyfin Android and Jellyfin iOS, record at minimum:

- repository URL
- default/current branch inspected
- commit SHA or tag when available
- player-related modules
- playback dependencies
- platform-native player stack
- relevant lifecycle/rendering/audio/session configuration

If a local clone of either Jellyfin repository is later provided, record its exact local path and treat it as read-only.

If any referenced source is unavailable, document the blocker rather than assuming its contents.

---

## V2 additions to Station 01

In addition to everything above, Station 01 MUST also complete:

- [ ] Section 0.3 preflight results recorded (device facts, `flutter doctor -v`, `flutter devices`)
- [ ] Git state recorded; `feature/player-reengineering` branch and `pre-player-reengineering-baseline` tag created (0.6)
- [ ] `docs/player-reengineering/LICENSE_NOTES.md` created for every reference (0.8)
- [ ] REA availability recorded, with fallback decision (0.7)
- [ ] Reference repos' availability recorded; clones into `player-references-upstream` attempted where needed (0.7)
- [ ] jellyfin-ios playback nature recorded; Swiftfin decision recorded (0.7)
- [ ] Existing `codemagic.yaml` / CI configuration discovered and recorded (0.5)
- [ ] Existing iOS native configuration inventory started (Info.plist, Podfile, AppDelegate, deployment target)
- [ ] Existing automated tests for the player inventoried and run once to establish a test baseline
- [ ] List of test streams/sources available (mine or NOVA's) recorded, with gaps against the Section 49 matrix

---

# 17. STATION 02 — DEEP NOVA PLAYER AUDIT

Inspect NOVA's current player without prematurely rewriting it.

Determine:

## Architecture

- player entry points
- screens
- Widgets
- controllers
- services
- repositories
- models
- state management
- native bridges
- player wrappers

## Playback engine

Identify:

- actual engine
- Flutter package
- native backend
- platform differences
- renderer
- surface/texture architecture

## Initialization

Trace:

```text
User chooses stream
→ source resolved
→ player created/opened
→ decoder initialized
→ rendering begins
→ UI synchronizes
```

Document the complete pipeline.

## Playback lifecycle

Trace:

- creation
- open
- play
- pause
- seek
- background
- foreground
- orientation change
- source change
- episode change
- fullscreen
- dispose

Determine whether the player/controller is unnecessarily recreated.

## Events

Investigate:

- position events
- duration events
- buffering events
- state events
- track updates
- subtitle events
- timer usage
- event frequency

Determine whether event flooding exists.

## Rendering

Investigate:

- Texture
- PlatformView
- native Surface
- video surface recreation
- clipping
- transformations
- overlays
- compositing

## Rebuilds

Determine:

- which Widgets rebuild with position
- whether the video Widget rebuilds
- whether the entire player tree rebuilds
- expensive layout work
- expensive effects
- unnecessary `setState`
- broad provider/listener updates

## Decoder

Investigate:

- hardware decoding
- fallback decoding
- codec behavior
- unsupported profiles
- high resolution
- high bitrate
- HDR
- Dolby Vision where relevant

## Buffering

Inspect:

- network buffering
- cache behavior
- preloading
- demuxer buffering
- player thresholds
- stream startup

## Tracks

Inspect:

- subtitle discovery
- external subtitle handling
- subtitle switching
- subtitle styling
- audio track discovery
- audio switching
- playback speed

## UX

Inspect:

- player controls
- settings
- modals
- gestures
- fullscreen
- orientation
- resume dialog
- skip controls
- next episode

Classify relevant existing components as:

```text
KEEP
REFACTOR
REPLACE
INVESTIGATE FURTHER
```

Do not rewrite production player code during this station except minimal documented instrumentation when necessary.

---

# 18. STATION 03 — NOVA PERFORMANCE BASELINE

Before optimization, create a baseline.

Do not rely only on visual impressions.

Measure where technically possible:

- player startup time
- time to first frame
- rendered video frames
- decoder dropped frames
- Flutter UI dropped frames
- Flutter build times
- Flutter raster times
- buffering events
- buffer duration
- rebuffer count
- seek latency
- source-switch latency
- audio-track-switch latency
- subtitle-switch latency
- event frequency
- player-tree rebuild frequency
- memory behavior
- CPU behavior
- resource creation/disposal

If a metric cannot be obtained, state that clearly.

Do not fabricate numbers.

Use debug instrumentation where necessary.

Do not permanently leave expensive instrumentation enabled in production builds.

---

## V2 additions to Station 03 (baseline on the physical device)

- The baseline MUST follow the Section 0.9 measurement protocol, on the physical USB device, in profile mode.
- If no usable device exists, Station 03 is `BLOCKED` and DEFERRED per 0.3; other investigation stations continue; Gate A handles the missing baseline per 0.4A. Baseline capture on the legacy player must still happen before the first production player change.
- Build and install the CURRENT (legacy) player first and measure it BEFORE changing any player code. Record the exact commit/tag used.
- Scenarios to baseline at minimum: startup/first frame; 10 minutes of continuous playback with controls hidden; same with controls repeatedly shown/hidden; opening/closing each settings window; 10+ seeks; subtitle switch; audio switch; speed change; source switch; background/foreground; rotation.
- Create `docs/player-reengineering/BASELINE.md` holding the raw numbers, device facts, streams used, and the instrumentation code location. This file is the reference for the Station 19 BEFORE/AFTER table.
- After the baseline, the quantitative targets in Section 51A are reviewed against reality. If the baseline shows a target is unrealistic on this device/stream, record the evidence and propose an adjusted target at GATE A. Never weaken a target silently.

---

# 19. PERFORMANCE ROOT-CAUSE CANDIDATES

During investigation specifically test hypotheses involving:

- decoder bottlenecks
- software decoding
- renderer bottlenecks
- texture synchronization
- Surface recreation
- excessive Flutter rebuilds
- large Widget tree updates
- `setState` on high-frequency position updates
- broad provider/state notifications
- progress updates occurring too frequently
- expensive subtitle rendering
- expensive Liquid Glass effects
- excessive `BackdropFilter`
- shader compilation
- overlay animations
- synchronous disk access
- synchronous database writes
- progress persistence writes
- expensive JSON processing
- work on UI isolate
- network buffer starvation
- stream-server instability
- unsupported codec
- HDR conversion
- Dolby Vision
- incorrect audio/video synchronization
- display refresh mismatch
- source recreation
- decoder recreation
- player recreation
- orientation lifecycle
- app lifecycle
- memory pressure
- leaks
- allocations
- timers
- bad dispose behavior

Do not assume all stuttering has one cause.

---

# 20. STATION 04 — HARBOR INVESTIGATION

Investigate Harbor independently.

Do not use Nuvio or Stremio Kai conclusions as assumptions.

Inspect:

## Playback

- engine
- Flutter/native integration
- initialization
- source open
- rendering
- hardware decoding
- buffering
- caching
- seeking
- frame pacing
- error recovery

## Architecture

- player controller
- player state
- session state
- UI separation
- track state
- source state
- lifecycle management

## Tracks

- subtitles
- external subtitles
- subtitle styles
- audio tracks
- playback speed
- source switching

## User experience

- controls
- settings menus
- fullscreen
- landscape
- gestures
- resume
- skip recap
- skip intro
- skip outro
- credits
- next episode

## Performance

Determine specifically how Harbor avoids or minimizes:

- decoder stalls
- UI-induced playback stutter
- expensive rebuilds
- unnecessary player recreation
- slow seeking
- buffering problems

Use source inspection and REA where useful.

Record paths and evidence.

---

# 21. STATION 05 — NUVIO INVESTIGATION

Repeat the investigation independently for:

```text
NuvioMobile
```

Determine:

- player engine
- architecture
- rendering approach
- buffering
- decoder
- hardware acceleration
- lifecycle
- seeking
- subtitle architecture
- audio-track architecture
- playback speed
- source switching
- resume behavior
- skip behavior
- next episode
- error recovery
- controls
- phone/tablet design

Identify what Nuvio does:

- better than Harbor
- worse than Harbor
- differently from Harbor
- better than current NOVA

Do not assume Nuvio should be copied.

---

# 22. STATION 06 — STREMIO KAI INVESTIGATION

Inspect:

```text
Stremio-Kai
```

Independently investigate:

- playback engine
- source architecture
- streaming integration
- renderer
- hardware decoding
- buffer strategy
- seeking
- frame pacing
- subtitle pipeline
- external subtitles
- audio tracks
- playback speed
- source changes
- lifecycle
- resume state
- skip markers
- episode transitions
- error recovery
- phone/tablet UX

Pay particular attention to anything useful for streaming-heavy workloads.

## Supplementary MPV QoL scripts investigation

As part of the Stremio Kai investigation, inspect the supplementary repository when it is relevant:

```text
https://github.com/allecsc/mpv-qol-scripts
```

Use it as a read-only supporting source for MPV-specific behavior and techniques.

Investigate only items relevant to NOVA's player, such as:

- MPV configuration patterns
- playback quality-of-life behavior
- seeking behavior
- track/subtitle/audio handling
- playback controls
- timing or playback-state behavior
- scripts that may explain Stremio Kai behavior
- performance-related MPV configuration or scripting decisions

Do not assume these scripts are used by Stremio Kai unless repository evidence proves that relationship.

Classify that relationship as VERIFIED, STRONGLY INFERRED, or UNKNOWN using the same evidence standard.

Do not copy scripts blindly into NOVA.

Do not assume Stremio Kai's implementation is automatically appropriate for Flutter NOVA.

---

# 22A. STATION 06A — JELLYFIN ANDROID INVESTIGATION

Investigate:

```text
https://github.com/jellyfin/jellyfin-android.git
```

Treat Jellyfin Android as a primary Android-native playback reference.

Investigate independently from Harbor, Nuvio, and Stremio Kai.

At minimum determine:

## Playback stack

- actual player engine/backend
- Media3 / ExoPlayer integration where applicable
- decoder selection
- hardware decoding behavior
- MediaCodec usage where applicable
- rendering surface strategy
- audio rendering
- subtitle rendering
- track selection
- playback-speed handling
- seeking
- buffering
- startup and recovery

## Android platform behavior

- audio focus
- lifecycle
- background / foreground transitions
- configuration/orientation changes
- fullscreen behavior
- refresh-rate / frame-rate handling where applicable
- Surface / Texture implications
- resource cleanup
- player reuse vs recreation
- error handling

## Playback session behavior

- resume progress
- session persistence
- source/session replacement
- episode/media transitions
- subtitle/audio state retention
- retry/fallback behavior

## Performance lessons

Investigate anything relevant to NOVA's current problems:

- dropped frames
- decoder stalls
- excessive player recreation
- slow seek
- buffering
- surface recreation
- lifecycle-induced playback disruption
- UI/player separation

Record exact source paths and evidence.

Do not copy Jellyfin implementation directly into NOVA.

Extract Android-native engineering lessons and adapt them to NOVA's Flutter architecture only when supported by evidence.

---

## V2.1 addition to Station 06A — engine verification first

Before evaluating any Jellyfin Android player behavior, verify the actual playback engine from the code, not from memory or assumptions:

- inspect Gradle/dependency files and the player modules to identify the real engine(s) in use (for example Media3/ExoPlayer, libmpv, a native-player option, or more than one selectable)
- record which engine is the default, which are optional, and the exact file/line evidence
- only then compare MediaCodec, surface, audio-focus, and lifecycle behavior, scoped to the engine actually used
- never transfer conclusions to NOVA's engine without noting how NOVA's engine differs

---

# 22B. STATION 06B — JELLYFIN IOS INVESTIGATION

Investigate:

```text
https://github.com/jellyfin/jellyfin-ios.git
```

Treat Jellyfin iOS as a primary iOS-native playback reference.

Investigate independently from Harbor, Nuvio, Stremio Kai, and Jellyfin Android.

At minimum determine:

## Playback stack

- actual native player engine/backend
- AVFoundation / AVPlayer usage where applicable
- hardware decoding behavior
- rendering pipeline
- buffering
- seeking
- audio tracks
- subtitles
- playback speed
- session replacement/reuse
- error handling

## iOS platform behavior

- AVAudioSession
- application lifecycle
- background / foreground
- interruptions
- orientation
- fullscreen behavior
- external playback / AirPlay where relevant
- resource cleanup
- player item lifecycle
- player reuse vs recreation

## Playback session behavior

- resume progress
- persistence
- source changes
- episode/media transitions
- subtitle/audio state retention
- retry/fallback behavior

## Performance lessons

Investigate anything relevant to NOVA's current iOS player quality:

- frame pacing
- dropped frames
- player-item recreation
- render-layer behavior
- buffering
- seeking
- lifecycle disruption
- UI/player separation

Record exact source paths and evidence.

Do not copy Jellyfin implementation directly into NOVA.

Extract iOS-native engineering lessons and adapt them to NOVA's Flutter architecture only when supported by evidence.

---

## V2.1 addition to Station 06B — engine verification first

Before evaluating any Jellyfin iOS player behavior, verify the actual playback implementation from the code:

- inspect the project/dependency files to identify the real engine (for example AVPlayer/AVFoundation, a third-party native engine, a web/cross-platform wrapper)
- if the repository is not a native player pipeline, record that fact and use Swiftfin as the native iOS reference (see 0.7)
- record the exact file/line evidence and the commit SHA
- never state that an AVPlayer/AVFoundation behavior applies unless the code proves AVPlayer is what the reference actually uses

---

# 23. REA INVESTIGATION RULE

Use REA purposefully.

Do NOT use REA just to claim it was used.

Use REA when it can answer engineering questions more reliably than plain reading.

For each meaningful REA investigation record:

```text
Target:
Question:
Method:
Evidence:
Finding:
Confidence:
NOVA relevance:
```

Follow evidence trails.

Do not stop at superficial package names.

Understand the behavior.

---

# 24. STATION 07 — CROSS-PROJECT ENGINEERING COMPARISON

After NOVA, Harbor, Nuvio, Stremio Kai, Jellyfin Android, and Jellyfin iOS have all been investigated, create a full comparison.

At minimum compare:

| Area | NOVA Current | Harbor | Nuvio | Stremio Kai | Jellyfin Android | Jellyfin iOS | NOVA Recommendation |
|---|---|---|---|---|---|---|---|
| Player engine | | | | | | | |
| Flutter integration | | | | | | | |
| Native backend | | | | | | | |
| Rendering | | | | | | | |
| Hardware decoding | | | | | | | |
| Buffering | | | | | | | |
| Frame pacing | | | | | | | |
| Startup | | | | | | | |
| Seeking | | | | | | | |
| State architecture | | | | | | | |
| Position events | | | | | | | |
| Subtitles | | | | | | | |
| External subtitles | | | | | | | |
| Audio tracks | | | | | | | |
| Playback speed | | | | | | | |
| Source switching | | | | | | | |
| Resume | | | | | | | |
| Skip markers | | | | | | | |
| Next episode | | | | | | | |
| Lifecycle | | | | | | | |
| Recovery | | | | | | | |
| Resource management | | | | | | | |
| Phone UX | | | | | | | |
| Tablet UX | | | | | | | |

For every NOVA recommendation explain WHY.

Do not simply choose the project with the greatest number of features.

You may combine the strongest architectural ideas from multiple references.

Where `mpv-qol-scripts` provides relevant MPV-specific evidence, incorporate it into the applicable comparison rows and clearly label it as supplementary evidence rather than an additional application.

The result must be tailored to NOVA.

---

# 25. STATION 08 — ROOT-CAUSE ANALYSIS

Now determine the actual causes of NOVA's current player problems.

For every root cause provide:

```text
Problem:
Observed behavior:
Evidence:
Layer:
Root cause:
Confidence:
Severity:
Recommended fix:
Expected impact:
Verification method:
```

Prioritize:

```text
P0 — Playback breaking / severe stutter
P1 — Major reliability/performance issue
P2 — UX or moderate performance issue
P3 — polish
```

Do NOT begin architecture design until important P0/P1 causes are understood sufficiently.

---

# 26. PLAYER ENGINE DECISION

Do NOT replace NOVA's playback engine merely because another project uses a different engine.

First determine:

1. what NOVA currently uses
2. what native engine actually runs underneath
3. why the current implementation fails
4. whether the failure comes from architecture
5. whether the failure comes from configuration
6. whether the failure comes from the engine itself
7. whether current engine capabilities satisfy requirements
8. whether another engine provides measurable benefit

If replacement is being considered, create a formal decision record.

Compare realistic options by:

- Android support
- iOS support
- hardware decoding
- H.264
- H.265/HEVC
- AV1 where relevant
- VP9 where relevant
- HLS
- direct HTTP streams
- subtitle tracks
- external subtitles
- multiple audio tracks
- playback speed
- seeking
- HDR implications
- Dolby Vision implications
- renderer behavior
- Flutter integration maturity
- lifecycle control
- binary size
- maintenance
- upstream health
- debugging ability
- API control
- performance
- long-term risk

Do not switch engines without evidence.

---

# 27. STATION 09 — FINAL NOVA PLAYER ARCHITECTURE

Only after previous stations are complete, design the architecture.

The architecture should separate responsibilities appropriately.

Potential modules include:

```text
PlaybackEngineAdapter
PlaybackSession
PlayerController
PlayerState
MediaSource
SourceController
SubtitleController
AudioTrackController
PlaybackSpeedController
ResumeController
SkipSegmentController
NextEpisodeController
GestureController
OverlayController
PlayerLifecycleCoordinator
PlaybackPersistence
PlayerDiagnostics
```

These are conceptual recommendations.

Adapt names and boundaries to NOVA's existing architecture.

Do not create abstractions merely for abstraction's sake.

Do NOT create another monolithic giant player Widget.

Document:

- component responsibilities
- data flow
- ownership
- lifecycle
- state updates
- dependency boundaries
- rendering boundaries
- error propagation
- persistence
- platform-specific boundaries

Include a migration strategy from current player to final architecture.

---

# 28. PLAYBACK SURFACE ISOLATION

Where technically possible, isolate the video surface from rapidly changing UI state.

The video renderer must not unnecessarily rebuild because:

- playback position changed
- controls became visible
- a countdown changed
- a subtitle settings menu opened
- volume overlay changed
- brightness overlay changed
- skip button changed
- next-episode countdown changed

Audit:

- `setState`
- StreamBuilder
- ValueListenableBuilder
- ChangeNotifier
- Provider
- Riverpod/selectors if applicable
- Bloc
- animation listeners
- timers

Use appropriately scoped state updates.

Do not send 30–60 full player-tree rebuilds per second.

---

# 29. STATION 10 — PLAYBACK CORE STABILIZATION

This is the first major implementation station.

Priority:

1. stable decoding
2. stable rendering
3. correct frame pacing
4. minimal dropped frames
5. correct buffer behavior
6. low UI overhead
7. correct lifecycle
8. correct resource management
9. fast/reliable seeking
10. long-session stability

Fix verified root causes.

Do NOT prioritize visual redesign at this point.

Potential concerns include:

- decoder setup
- hardware acceleration
- video surface
- player creation
- source initialization
- buffering
- progress/event frequency
- state updates
- player disposal
- source transitions
- audio focus
- application lifecycle
- orientation changes

After every substantial performance change:

measure again.

Record evidence.

---

# 30. DO NOT MASK PERFORMANCE PROBLEMS

Do not solve problems superficially.

Examples:

Bad:

```text
video buffers too often
→ make loading spinner prettier
```

Bad:

```text
frame drops
→ increase buffer to huge values
```

Bad:

```text
UI jank
→ remove animations without identifying the rebuilding source
```

Required:

Find the root cause and fix the correct layer.

---

# 31. STATION 11 — PLAYER CONTROLS & GESTURES

After playback core stabilization implement/refine:

- play
- pause
- seek
- timeline
- controls visibility
- fullscreen
- orientation
- overlay behavior

Gestures must include:

## Right half — Volume

Vertical drag upward:

```text
increase volume
```

Vertical drag downward:

```text
decrease volume
```

Use:

- dead-zone
- reasonable sensitivity
- clamping
- lightweight overlay

## Left half — Brightness

Vertical drag upward:

```text
increase brightness
```

Vertical drag downward:

```text
decrease brightness
```

Use:

- dead-zone
- reasonable sensitivity
- clamping
- lightweight overlay

## Double tap

Right side:

```text
seek forward
```

Left side:

```text
seek backward
```

Gestures must not interfere with:

- buttons
- timeline
- sliders
- settings menus
- subtitle selection
- audio selection
- system gestures

Do not trigger full player rebuilds during every gesture update.

---

# 32. STATION 12 — SUBTITLES, AUDIO, SPEED & SOURCES

Build/refine a production-quality settings system.

## Subtitles

Support as applicable:

- available embedded subtitles
- external subtitles
- subtitle enable/disable
- subtitle selection
- language information
- subtitle sync/offset if supported
- subtitle style
- NOVA subtitle fonts/system
- reliable switching

Changing subtitles should not recreate the entire playback session unless the backend absolutely requires it.

## Audio

Support:

- available audio tracks
- language
- label/title information
- reliable switching
- currently selected track

Do not unnecessarily recreate the player.

## Playback speed

Provide appropriate speed options.

Ensure reliable switching.

## Sources

Support:

- source selection
- safe source switching
- current position preservation where appropriate
- playback-state preservation where possible
- appropriate fallback/recovery

Record whether the underlying player must reopen the media for certain operations.

Do not hide this behavior.

---

# 33. PLAYER SETTINGS WINDOWS

Subtitle, audio, playback-speed and source-selection interfaces must be appropriate for the NOVA player.

On phone landscape:

- menus may occupy the full player screen
- content must remain compact
- provide close icon/action
- support swipe-down dismissal where appropriate
- preserve player state
- avoid expensive transitions

Opening settings must NOT unnecessarily:

- recreate player
- recreate decoder
- reset playback position
- trigger source reload
- destroy video surface

Unless required by the selected backend.

---

# 34. STATION 13 — RESUME PLAYBACK

Build a robust resume system.

Persist appropriate information such as:

- content ID
- season where applicable
- episode where applicable
- source-independent media identity
- playback position
- duration
- timestamp

Do not write storage on every tiny position update.

Use sensible throttling/debouncing.

Do not offer resume if:

- saved position is extremely early
- duration is invalid
- playback was nearly complete
- saved state is stale/invalid

When applicable, display an experience equivalent to:

```text
Resume from 23:41
```

Actions:

```text
Resume
Start from beginning
```

Resume state must survive an application restart.

Test movie and episode behavior separately.

---

# 35. STATION 14 — GENERALIZED SKIP SEGMENT SYSTEM

Do NOT build only a hard-coded "Skip Intro" feature.

Create a generalized model such as:

```text
SkipSegment
```

Potential fields:

```text
type
start
end
metadata
source
confidence
```

Support segment types such as:

- recap
- intro
- opening
- outro
- credits

UI may expose:

```text
Skip Recap
Skip Intro
Skip Opening
Skip Outro
Skip Credits
```

Requirements:

- appear only while inside relevant segment
- disappear immediately after segment
- seeking updates segment state
- episode/source changes reset segment state
- overlapping segments handled predictably
- repeated events do not cause excessive rebuilds

Keep marker data independent from the player UI.

---

# 36. STATION 15 — NEXT EPISODE SYSTEM

Near the appropriate end of an episode show NOVA's next-episode experience.

Support:

- next episode information
- countdown
- cancel/dismiss
- play next
- source selection where required
- appropriate cast action if NOVA already supports casting in this flow

Episode transition must correctly handle:

- current player session
- source selection
- resume persistence
- subtitle state where appropriate
- audio state where appropriate
- playback speed where appropriate
- resource cleanup

Do not destroy and recreate more than necessary.

But do not preserve resources unsafely merely to avoid recreation.

---

# 37. STATION 16 — NOVA PLAYER UI & LIQUID GLASS

Only after playback is stable should final visual refinement occur.

The player must look like NOVA.

Do NOT visually copy:

- Harbor
- Nuvio
- Stremio Kai

Use NOVA's existing:

- typography
- spacing
- icon system
- reusable Widgets
- colors
- motion language
- responsive architecture
- Flutter Liquid Glass UI system/skill

Use the existing project skill/instructions for:

**Flutter Liquid Glass UI**

when designing suitable player UI surfaces.

However:

# PLAYBACK PERFORMANCE OVERRIDES GLASS EFFECTS

Do not stack expensive visual effects over a continuously rendering video surface unless profiling shows acceptable performance.

Be extremely cautious with:

- multiple `BackdropFilter`s
- large blur regions
- continuously animated glass
- expensive clipping
- shader-heavy transitions
- unnecessary translucency layers

If authentic Liquid Glass causes measurable playback degradation:

use the lightest equivalent implementation that preserves NOVA's visual identity.

---

# 38. UI PERFORMANCE RULES

Player visual state must be localized.

For example:

- progress bar updates should not rebuild unrelated buttons
- volume overlay should not rebuild video
- brightness overlay should not rebuild settings
- skip button state should not rebuild entire player
- countdown should not rebuild video renderer

Profile overlay animations.

Prefer efficient composition.

---

# 39. PHONE EXPERIENCE

Design intentionally for phones.

Verify:

- portrait where supported
- landscape
- safe areas
- notches
- camera cutouts
- Android gesture navigation
- iOS home indicator
- full-screen system UI
- rotation
- opening/closing settings
- compact landscape controls

Do not allow controls to become oversized in landscape.

---

# 40. TABLET EXPERIENCE

Design intentionally for:

- Android tablet
- iPad

Do not merely scale phone layout.

Evaluate:

- control spacing
- settings-panel width
- navigation behavior
- modal sizing
- video controls
- landscape usage
- portrait usage
- side navigation interactions where relevant

Preserve NOVA's tablet design language.

---

# 41. STATION 17 — ANDROID PLATFORM VERIFICATION

Use the Jellyfin Android findings from Station 06A as an additional Android-native benchmark when validating NOVA's Android implementation.

Investigate/verify as applicable:

- underlying native playback backend
- MediaCodec behavior
- hardware decoding
- codec selection
- Surface/Texture implications
- refresh rate
- frame-rate matching opportunities
- audio focus
- app lifecycle
- background/foreground
- rotation
- system UI
- resource cleanup
- stream recovery
- subtitle rendering path

Check platform-specific logs where helpful.

Never claim physical Android verification if only static analysis was performed.

---

## V2 additions to Station 17 (physical Android device protocol)

All Android runtime verification happens on the USB-connected device. Typical tools (adapt to the actual device/OS):

- Logs: `adb logcat -v threadtime`, filtered to NOVA's pid and to codec/player tags (MediaCodec, CCodec, the engine's own tag)
- Lifecycle: `adb shell input keyevent KEYCODE_HOME` (background), relaunch, power button/lock, recent-apps switch
- Rotation: `adb shell settings put system accelerometer_rotation 0|1` and `user_rotation 0..3` (restore afterwards)
- Memory pressure: `adb shell am send-trim-memory <package> RUNNING_CRITICAL`
- Audio focus: `adb shell dumpsys audio` while another app plays audio, during a call/notification, and with headphones/Bluetooth disconnect
- Display: `adb shell dumpsys display` (refresh rate/modes), `dumpsys SurfaceFlinger` where useful
- Memory/CPU: `adb shell dumpsys meminfo <package>`, `adb shell top`

Mark each verified item `VERIFIED-ON-DEVICE` with the evidence file/log path. Items that require a second device class (tablet, low-end phone, 120 Hz phone) that is not connected stay `NOT MEASURED`.

For tablets without a physical device: verify layout logic through widget tests at representative tablet logical sizes and orientations, marked `BUILD-VERIFIED`, never `VERIFIED-ON-DEVICE`.

---

# 42. STATION 18 — IOS PLATFORM VERIFICATION

Use the Jellyfin iOS findings from Station 06B as an additional iOS-native benchmark when validating NOVA's iOS implementation.

Investigate/verify as applicable:

- actual iOS playback backend
- AVFoundation behavior if applicable
- hardware decode
- video rendering
- audio session
- app lifecycle
- background/foreground
- orientation
- safe areas
- system UI
- subtitle behavior
- stream recovery
- resource cleanup

Do not assume Android implementation details automatically transfer to iOS.

Keep platform-specific implementation isolated where necessary.

Never claim physical iPhone/iPad testing if it was not performed.

---

## V2 REPLACEMENT of the verification rules for Station 18 (no Mac, Codemagic only)

Station 18 is a **static engineering + CI-readiness** station. It does NOT include running iOS. Follow Section 0.5 completely. The acceptance criteria for this station are:

- [ ] iOS native playback backend identified and documented (`STATIC-ONLY` or `BUILD-VERIFIED`)
- [ ] Info.plist, Podfile, deployment target, AVAudioSession, background modes, orientation, and safe-area configuration reviewed against the Jellyfin iOS (and Swiftfin if used) lessons
- [ ] Every hand-written native iOS change logged in `IOS_UNCOMPILED_CHANGES.md`
- [ ] `codemagic.yaml` present/updated with placeholders and the list of things I must configure
- [ ] `IOS_MANUAL_TEST_CHECKLIST.md` created
- [ ] iOS-specific differences from Android isolated behind platform-specific code paths
- [ ] Status table for iOS (0.2 vocabulary) created in the station file

A passing Codemagic build (when I run it after Gate D) upgrades items to `BUILD-VERIFIED`; only my own on-device test results can make an iOS item `VERIFIED-ON-DEVICE`.

---

# 43. ERROR HANDLING & RECOVERY

Handle player failures deliberately.

Cases include:

- invalid source
- HTTP error
- timeout
- network interruption
- buffering timeout
- decoder failure
- unsupported codec
- unsupported profile
- subtitle failure
- malformed subtitle
- audio-track switch failure
- seek failure
- source switch failure
- initialization failure
- player backend error

For relevant failures determine whether recovery should:

- retry
- reopen
- switch source
- fall back
- show error
- return to source selection

Do not silently swallow critical player exceptions.

Do not show raw low-level exceptions directly to normal users.

Preserve useful diagnostic information for debugging.

---

# 44. DO NOT DESTROY WORKING NOVA FEATURES

Before replacing current player functionality classify it as:

```text
WORKING
PARTIALLY WORKING
BROKEN
OBSOLETE
```

Preserve stable functionality.

Prefer targeted replacement over destructive rewrite unless evidence demonstrates the current architecture is fundamentally unsuitable.

---

# 45. DEPENDENCY POLICY

Do not add packages casually.

Before adding/replacing major playback dependencies document:

- reason
- alternatives considered
- impact
- platform support
- maintenance health
- size impact
- architectural impact
- migration cost
- performance benefit

Do not upgrade the Flutter SDK simply to avoid solving an implementation problem.

Do not perform unrelated dependency modernization.

Keep scope focused on the player unless a dependency change is necessary.

---

# 46. PLAYER STATE FREQUENCY POLICY

Playback position can update frequently internally.

UI does NOT need every decoder/player position event.

Create a deliberate strategy for:

- internal precise state
- UI progress updates
- persistence updates
- skip-segment evaluation
- next-episode evaluation

These may use different frequencies.

Avoid:

```text
player event
→ notify entire UI
→ rebuild entire player
```

for every position event.

---

# 47. PERSISTENCE PERFORMANCE POLICY

Resume/history persistence must not hurt playback.

Do not perform:

- synchronous disk writes on every position update
- database writes dozens of times per second
- blocking persistence on UI isolate

Use an appropriate strategy such as:

- throttling
- batching
- periodic persistence
- important lifecycle checkpoints

while preserving useful resume accuracy.

---

# 48. SUBTITLE PERFORMANCE

Investigate whether subtitles contribute to frame drops.

Check:

- subtitle parser
- subtitle event frequency
- text layout
- style changes
- font loading
- large rebuild scope
- animations
- external subtitle processing

Subtitle rendering must remain visually accurate without destabilizing video playback.

---

# 49. PERFORMANCE TEST MATRIX

Where possible test representative scenarios, not one stream only.

Include combinations such as:

## Transport

- HLS
- direct HTTP

## Resolution

- 720p
- 1080p
- 4K where relevant and supported

## Codecs

- H.264
- HEVC where supported
- other project-relevant codecs

## Tracks

- no subtitles
- embedded subtitles
- external subtitles
- multiple audio tracks

## Usage

- playback startup
- 10+ minutes continuous playback where possible
- repeated seeking
- subtitle switching
- audio switching
- opening settings
- closing settings
- source switching
- background/foreground
- orientation changes

Do not pretend to test streams or hardware unavailable in the environment.

---

## V2 additions to the test matrix

- The matrix is executed on the physical Android device(s) available, following Section 0.9. Each cell of the matrix gets a status from 0.2: executed cells = `VERIFIED-ON-DEVICE`; skipped cells = `NOT MEASURED` with a reason.
- Record per cell: device id, build mode, stream URL/identifier, codec, container/transport, network type, number of runs, median result.
- Add these Android-specific scenarios when possible: Bluetooth headphones connect/disconnect during playback, incoming notification/call interruption, split-screen/multi-window if NOVA supports it, 120 Hz vs 60 Hz display mode if the device allows both.
- iOS cells are NOT executed by you. They go into `IOS_MANUAL_TEST_CHECKLIST.md` for me.

---

# 50. STATION 19 — PERFORMANCE REGRESSION & LONG PLAYBACK

Repeat the most important Station 03 measurements.

Create a clear:

# BEFORE vs AFTER

comparison.

Include available metrics such as:

| Metric | Before | After | Difference | Evidence |
|---|---:|---:|---:|---|
| Time to first frame | | | | |
| Video dropped frames | | | | |
| Flutter UI jank | | | | |
| Seek latency | | | | |
| Rebuffer events | | | | |
| Player rebuild frequency | | | | |
| Memory behavior | | | | |
| CPU behavior | | | | |

Do not invent metrics.

If a metric could not be measured, say:

```text
NOT MEASURED
```

and explain why.

---

# 51. PERFORMANCE ACCEPTANCE CRITERIA

The work is NOT complete just because:

```text
flutter analyze
```

passes.

At minimum verify, where the environment allows:

- ordinary controls do not recreate the player
- opening settings does not recreate the player
- position updates do not rebuild entire player surface
- controls do not destabilize decoding
- settings do not destabilize decoding
- seeking works reliably
- subtitles switch reliably
- audio tracks switch reliably
- playback speed works reliably
- source switching works reliably
- lifecycle behavior is correct
- resources are disposed correctly
- resume playback works
- skip segments work
- next episode works
- NOVA-generated frame drops are reduced/eliminated
- Android architecture is sound
- iOS architecture is sound

---

# 51A. QUANTITATIVE ACCEPTANCE TARGETS (V2)

"Smooth" must be a number. Defaults below apply to the connected physical Android device, in profile mode, following Section 0.9. They are reviewed against the baseline at GATE A and may be adjusted ONLY with recorded evidence and my approval.

| Area | Target (default) |
|---|---|
| Player recreation | **0** player/controller recreations when toggling controls, opening/closing any settings window, changing subtitle/audio/speed, or rotating the device (unless the design explicitly requires it and Gate B approved it) |
| Rebuilds from position updates | **0** rebuilds of the video surface subtree from position/buffer updates; only the small progress widgets may rebuild |
| Position-driven UI update rate | at most ~10 updates/second to Flutter UI (and never faster than the display needs) |
| Flutter UI jank (steady state, controls visible and hidden) | janky frames (build or raster over the refresh-rate-aware budget) ≤ **1%**; no single frame > 3× budget outside of explicit transitions |
| Decoder dropped frames (steady state, stream the device decodes in hardware, healthy network) | ≤ **0.1%** of rendered frames AND not worse than baseline; network-caused drops are reported separately |
| Time to first frame | not worse than baseline by more than 10%; improvement expected |
| Seek latency (buffered seek) | median not worse than baseline; report P50 and P95 over ≥ 10 seeks |
| Subtitle / audio / speed switch | no player recreation, no audible gap longer than baseline, no visible freeze longer than 500 ms |
| Memory | no monotonic growth over 30 min playback + 20 source/episode switches + 10 settings open/close cycles + 5 background/foreground cycles + 5 rotations (judged after forced GC, excluding legitimate buffers) |
| Long playback | 30 min continuous playback on device with no crash, no ANR, no A/V drift beyond what the baseline shows, and no leak/resource warnings in logcat |
| Resume / skip / next-episode | each behavior verified on device with at least one real episode flow, matching the centralized completion rules (Section 67) |
| Lifecycle | background/foreground, lock/unlock, rotation, and audio-focus loss/regain verified on device |

If a target cannot be met, do not hide it: record the measured value, the suspected cause, and bring it to the next gate.

---

# 52. AUTOMATED TESTING

Add meaningful tests where reasonable.

Potential tests:

- PlayerState
- PlaybackSession
- ResumeController
- resume threshold behavior
- completed-content threshold
- SkipSegment
- active segment calculation
- seeking into/out of segments
- NextEpisodeController
- track-selection state
- source switching state
- playback-speed state
- lifecycle state
- error-state transitions

Do not add meaningless tests solely to inflate test counts.

---

# 53. STATIC ANALYSIS & QUALITY

At appropriate stages run applicable tools such as:

```text
flutter analyze
flutter test
```

and project-specific checks.

Fix regressions introduced by the player work.

Do not silently modify unrelated application code just to eliminate pre-existing unrelated warnings.

Record:

- command
- result
- failures
- whether failures are pre-existing or newly introduced

---

# 54. MULTI-AGENT EXECUTION

You may delegate independent investigation work to sub-agents.

Good parallel research tasks include:

- NOVA architecture audit
- Harbor investigation
- Nuvio investigation
- Stremio Kai investigation

However:

# DO NOT LET MULTIPLE AGENTS MODIFY THE SAME PLAYER FILES SIMULTANEOUSLY

The primary agent owns:

- master plan
- architecture
- shared interfaces
- dependency decisions
- integration
- player implementation
- conflict resolution
- verification
- final reporting

Research agents should return findings/evidence.

The primary agent integrates decisions.

---

## V2 file ownership during multi-agent work

- Create `docs/player-reengineering/OWNERSHIP.md` listing which agent may write which NOVA paths.
- Default: only the primary agent writes to `lib/` player files, shared interfaces, `pubspec.yaml`, and native Android/iOS configuration. Research agents write ONLY to their own report files under `docs/player-reengineering/research/<agent-name>/`.
- Sub-agents must never run `adb install`, `flutter run`, or any command that changes the connected device state while the primary agent is measuring — device access is exclusive to the primary agent.
- Sub-agents must never commit.

---

# 54A. AGENT ROSTER & BUDGET (V2.2 addition — paste after Section 54; if it conflicts with Section 54/55, this section wins)

Plan: the user has a ChatGPT PLUS plan with limited usage. Agents are used sparingly.

Rules
- Agents are defined in .codex/agents/. Spawn an agent ONLY when this section says so, and only by explicit request from the primary agent.
- HARD LIMIT: never more than 3 agents running at once. Default is ONE agent at a time; run 3 in parallel ONLY for the Station 04/05/06 reference trio. Everything else runs one at a time. Agents must not spawn agents.
- ALL agents are read-only. They return findings as their final message. The PRIMARY agent writes any resulting files (this replaces the earlier idea that research agents write into research/<agent-name>/).
- Agents never touch the device (no adb), never run builds, never commit.
- Every agent task must name: scope, exact paths it may read, exact questions, and the required return format.
- Never delegate implementation. Stations 10–16 are done by the primary agent alone, with no agents.
- Do not re-spawn an agent for something it already answered; ask the user instead of burning quota.

Roster and allowed uses
| Agent | Allowed when | Max invocations |
|---|---|---|
| reference_researcher | Stations 04, 05, 06 (up to 3 in parallel), then 06A and 06B (one each) | 5 total |
| nova_player_auditor | Station 02 | 1 |
| perf_log_analyst | after Station 03, after Station 10, and at Station 19 (saved logs only) | 3 total |
| ios_static_reviewer | Station 18, and once per Codemagic log the user pastes | 1 + per log |
| gate_reviewer | once before each Gate A, B, C, D, E | 5 total |

If any limit would be exceeded, stop and ask the user. Report the number of agent invocations used in FINAL_REPORT.md.

Model/effort guidance (the user switches the main session model; agents inherit it unless pinned)
- Stations 01–07: main session on GPT-6 Luna; agents inherit Luna.
- Stations 08–10, 17, 19, 20 and every Gate: main session on GPT-6.1 Sol. Reasoning "high" only for Stations 08 and 09; "medium" otherwise.
- Stations 11–16: Sol medium, or Luna for simple UI work when the user chooses.

# 55. AGENT HANDOFF RULE

If work is delegated, tell each agent exactly:

- repository/path it may read
- whether it may write
- exact investigation scope
- required evidence format
- output destination
- files it must not modify

Reference-project agents must remain read-only.

Only authorized NOVA implementation work may modify NOVA.

---

# 56. STATION 20 — FINAL FULL AUDIT

After all previous implementation and verification stations, perform a fresh audit.

Do not trust old checkmarks blindly.

Reinspect the final implementation.

Review:

```text
00_MASTER_PLAN.md
01...19 station files
actual repository state
tests
performance evidence
```

Search for:

- unfinished tasks
- stale TODOs
- debug-only code accidentally left active
- duplicate player logic
- unused old player implementation
- memory/resource leaks
- broad rebuilds
- temporary compatibility code
- architectural violations
- unresolved warnings
- missing tests
- invalid assumptions
- unresolved blockers

If a previously checked task no longer passes:

change:

```text
[x]
```

back to:

```text
[ ]
```

Fix it.

Verify it again.

Then mark it complete.

---

# 57. FINAL REPORT

After the final audit create:

```text
docs/player-reengineering/FINAL_REPORT.md
```

It must contain:

# Executive Summary

What was accomplished.

# Original NOVA Problems

What existed before.

# Root Causes

The actual causes discovered.

# Harbor Findings

Useful verified engineering lessons.

# Nuvio Findings

Useful verified engineering lessons.

# Stremio Kai Findings

Useful verified engineering lessons.

# Jellyfin Android Findings

Useful verified Android-native playback engineering lessons.

Clearly state which findings were directly applicable to NOVA and which were only platform-specific reference material.

# Jellyfin iOS Findings

Useful verified iOS-native playback engineering lessons.

Clearly state which findings were directly applicable to NOVA and which were only platform-specific reference material.

# Supplementary MPV QoL Scripts Findings

Document only relevant findings from:

```text
https://github.com/allecsc/mpv-qol-scripts
```

Clearly distinguish:

- findings directly relevant to Stremio Kai
- general MPV engineering lessons
- anything whose relationship to Stremio Kai remains unverified

# Cross-Project Decisions

What NOVA adopted conceptually and why.

# Playback Engine Decision

State clearly:

- retained or replaced
- why
- evidence
- tradeoffs

# Final NOVA Architecture

Explain the final system.

# Performance Results

Show:

```text
Before vs After
```

with real evidence only.

# Feature Status

Use:

| Feature | Status | Verification |
|---|---|---|
| Smooth playback | | |
| Dropped frames | | |
| Frame pacing | | |
| Buffering | | |
| Seeking | | |
| Subtitles | | |
| External subtitles | | |
| Audio tracks | | |
| Playback speed | | |
| Source switching | | |
| Resume playback | | |
| Skip recap | | |
| Skip intro | | |
| Skip opening | | |
| Skip outro | | |
| Skip credits | | |
| Next episode | | |
| Volume gesture | | |
| Brightness gesture | | |
| Double-tap seeking | | |
| Phone landscape | | |
| Tablet | | |
| Android | | |
| iOS | | |

# Changed Files

List significant:

- created
- modified
- replaced
- removed

# Tests

List exactly what was run.

Include actual results.

# Performance Measurements

List actual measured metrics.

# Blocked Verification

Document anything that could not be verified.

# Remaining Limitations

Be explicit.

# Future Recommendations

Only meaningful recommendations.

---

# 58. FINAL MASTER PLAN STATE

Only after final verification update:

```text
docs/player-reengineering/00_MASTER_PLAN.md
```

If all required non-blocked tasks are verified:

```text
PROJECT STATUS: COMPLETE ✓
```

If non-critical environmental blockers remain:

```text
PROJECT STATUS: COMPLETE WITH DOCUMENTED BLOCKERS
```

If critical work remains:

```text
PROJECT STATUS: INCOMPLETE
```

Never report COMPLETE inaccurately.

---

# 59. FINAL RESPONSE TO ME

Do NOT stop after creating the plan.

Do NOT stop after investigation.

Do NOT stop after architecture.

Do NOT stop after the first implementation stage.

Continue through the complete executable plan unless:

- a critical blocker makes safe continuation impossible
- continuation would require guessing critical architecture
- required source/input is unavailable
- a mandatory Human Review Gate (Section 0.4) or a conditional gate is reached

Otherwise continue automatically station by station.

When finished, return a concise report containing:

1. Overall status
2. Stations completed
3. Total tasks completed
4. Blocked tasks
5. Main root causes found
6. Playback engine decision
7. Major architectural changes
8. Performance before vs after
9. Features implemented
10. Tests executed
11. Platform verification status
12. Remaining limitations
13. Path to `FINAL_REPORT.md`

Do not merely say:

```text
Done.
```

Provide evidence-backed status.

---

# 60. PROGRESS REPORTING RULE

During execution, the persistent Markdown files are the primary progress tracker.

Do not interrupt the workflow simply to provide chat updates after every station.

Keep working.

Update:

```text
00_MASTER_PLAN.md
```

and the current station file continuously.

The final user-facing response should happen when:

- the mission is completed, or
- a critical blocker prevents further safe progress, or
- a Human Review Gate (Section 0.4) is reached (short gate message only)

---

# 61. NO PREMATURE SUCCESS

Never mark a feature complete because:

- code compiles
- a Widget exists
- a method exists
- a test was written
- static analysis passes

Feature completion requires verification appropriate to that feature.

Examples:

Subtitle selector existing ≠ subtitle switching verified.

Resume dialog existing ≠ resume persistence verified.

Skip button existing ≠ skip-segment logic verified.

Player opening ≠ playback performance solved.

---

# 62. RESEARCH VS IMPLEMENTATION BOUNDARY

Stations 01–08, including 06A and 06B, are primarily investigation and evidence gathering.

Station 09 defines the final architecture.

Stations 10–18 perform the main implementation and platform verification.

Station 19 measures regressions/performance.

Station 20 audits everything again.

Do not bypass the research stations just to start coding faster.

However, minor instrumentation needed to gather evidence is allowed if:

- documented
- isolated
- reversible
- not confused with final implementation

---

# 63. ARCHITECTURAL DECISION LOG

Inside `00_MASTER_PLAN.md`, maintain a section:

```text
## Architecture Decision Log
```

Each significant decision should have an ID:

```text
ADR-P001
ADR-P002
ADR-P003
```

Record:

```text
Decision:
Problem:
Options:
Evidence:
Selected option:
Reason:
Tradeoffs:
Affected stations:
```

Important examples:

- playback engine
- renderer strategy
- state architecture
- position update frequency
- persistence strategy
- subtitle architecture
- source switching
- player reuse vs recreation
- platform-specific implementation

---

# 64. PERFORMANCE DECISION RULE

When two approaches are functionally equivalent, prefer the one with:

1. fewer unnecessary player operations
2. fewer UI rebuilds
3. lower compositing cost
4. lower allocation frequency
5. lower lifecycle complexity
6. measurable playback stability

Do not optimize prematurely where there is no measurable issue.

But for known playback hotspots, performance evidence is mandatory.

---

# 65. LONG SESSION RELIABILITY

The player should not only work for the first 30 seconds.

Investigate long-session risks:

- memory growth
- stale subscriptions
- leaked timers
- old controllers
- stale subtitle objects
- repeated source switch leaks
- repeated episode transition leaks
- background/foreground cycles
- orientation cycles

Use the environment to test what is realistically possible.

Record limitations honestly.

---

# 66. SOURCE SWITCHING CORRECTNESS

Source switching deserves specific verification.

Determine intended behavior for:

- preserving current position
- preserving pause/play state
- subtitle reset/reselection
- audio reset/reselection
- playback speed
- buffering indicator
- error fallback

Avoid double-opening sources or overlapping player sessions.

---

# 67. MEDIA COMPLETION LOGIC

Create deliberate completion thresholds.

Do not blindly save content as "unfinished" when only a few seconds remain.

Resume and next-episode logic must agree on:

- when content is effectively complete
- when resume data is cleared
- when next episode should appear
- when countdown should start

Centralize these rules.

---

# 68. STREAM FAILURE RECOVERY

Where architecture supports multiple sources, design recovery thoughtfully.

Possible flow:

```text
current source fails
→ classify failure
→ decide retry/fallback
→ preserve position
→ open next viable source
→ seek safely
→ resume playback
```

Do not automatically switch sources for every minor transient event.

Avoid infinite retry loops.

---

# 69. PLAYER OVERLAY PRIORITY

Player overlays can include:

- controls
- loading
- errors
- volume
- brightness
- skip action
- resume
- next episode
- settings

Define interaction priority so overlays do not fight each other.

Example:

Full-screen settings should suppress normal gesture handling where appropriate.

Error UI should not appear behind a settings modal.

Next-episode UI should not conflict with active source selection.

Document state transitions.

---

# 70. NOVA VISUAL CONSISTENCY

Reference applications provide engineering inspiration.

They do NOT define NOVA's visual identity.

Final controls must follow NOVA.

Preserve:

- NOVA typography
- NOVA icons
- NOVA spacing
- NOVA visual hierarchy
- NOVA Liquid Glass language
- NOVA responsive behavior

Avoid a player that looks like three unrelated applications combined together.

---

# 71. CLEANUP

Before final completion:

- remove dead player code when safe
- remove obsolete duplicate controllers
- remove temporary instrumentation not intended for production
- remove unused imports
- remove temporary debug print spam
- remove obsolete TODOs introduced by this work
- ensure resource disposal is complete
- ensure documentation matches actual code

Do not delete old architecture until migration is safely complete.

---

## V2.1 addendum to Section 71 — timing and scope

Section 71 cleanup runs in two parts:

**Part 1 — before Station 20 (does NOT include the legacy player):** remove temporary instrumentation not meant for production, duplicate controllers, debug print spam, unused imports, and obsolete TODOs introduced by this work; ensure resource disposal and that documentation matches the code. The legacy player stays selectable behind its flag.

**Part 2 — only after Gate E and only with my approval (0.6.7):** remove the legacy player in a separate final commit after tagging `pre-legacy-removal`. After removal, repeat the LKG checks in 0.6.4 and a short on-device smoke test.

---

# 72. GIT SAFETY

Do not destroy unrelated work.

Before major changes inspect repository status.

Preserve unrelated user modifications.

Do not:

- reset unrelated files
- overwrite user changes
- perform destructive Git operations
- force-clean the repository

If existing local modifications overlap player files, investigate and preserve intended work.

---

# 73. DEFINITION OF DONE

This mission is complete only when:

- investigation is documented
- Harbor, Nuvio, Stremio Kai, Jellyfin Android, and Jellyfin iOS were actually analyzed
- NOVA root causes are documented
- architecture decision is evidence-based
- player core is stabilized
- UI rebuild behavior is controlled
- settings functionality is reliable
- resume is implemented and verified
- skip segments are implemented and verified
- next episode is implemented and verified
- phone UX is addressed
- tablet UX is addressed
- Android concerns are addressed and verified on the physical device (`VERIFIED-ON-DEVICE`) or explicitly marked otherwise
- iOS concerns are addressed through static review, a Codemagic-ready configuration, and a manual test checklist; iOS runtime status is honestly `BUILD-VERIFIED` or lower
- Gates A, B, C, D, E were each reached and my replies are recorded in the gate review files
- the Section 51A targets were measured and met, or each miss is documented with evidence
- LICENSE_NOTES.md, OWNERSHIP.md, IOS_UNCOMPILED_CHANGES.md, and IOS_MANUAL_TEST_CHECKLIST.md exist and are accurate
- the legacy player was removed only after Gate E approval (as a separate final commit after the `pre-legacy-removal` tag), or is explicitly kept behind a flag with a documented reason
- tests are run
- performance is compared
- final audit is performed
- master plan reflects reality
- final report is created

Anything that cannot be verified must be explicitly documented.

---

# 74. MANDATORY EXECUTION LOOP

For every station follow:

```text
READ MASTER PLAN
↓
READ CURRENT STATION
↓
INSPECT CURRENT REPOSITORY STATE
↓
EXECUTE NEXT UNCHECKED TASK
↓
VERIFY RESULT
↓
MARK TASK [x]
↓
UPDATE FINDINGS
↓
UPDATE MASTER PLAN
↓
EXECUTE NEXT TASK
↓
VERIFY STATION ACCEPTANCE CRITERIA
↓
MARK STATION COMPLETE ✓
↓
MOVE TO NEXT STATION
```

Repeat until Station 20 is complete or a critical blocker prevents safe continuation.

---

# 75. FINAL CORE RULE

The goal is NOT:

> Make the current NOVA player look better.

The goal is:

> Engineer a production-grade NOVA playback system that is smooth, reliable, performant, maintainable, responsive, and appropriate for Android and iOS phones and tablets.

Harbor, Nuvio, Stremio Kai, Jellyfin Android, and Jellyfin iOS are primary reference evidence sources.

`mpv-qol-scripts` is a supplementary MPV evidence source.

REA is an investigation tool.

NOVA is the product being engineered.

Performance must be measured.

Architectural decisions must be justified.

Completed tasks must be verified.

Documentation must stay synchronized with implementation.

Never fake completion.

Never guess when critical evidence is available.

Never prioritize decorative effects over playback stability.

---

# START NOW

Begin with:

# Station 00 — Persistent Planning Bootstrap

Before touching NOVA production player code:

1. Verify that the NOVA repository you are currently operating inside is:

```text
C:\Users\hosea\projects\app\Nova
```

2. Verify access to all three local read-only reference repositories:

```text
C:\Users\hosea\projects\app\player-references\harbor
C:\Users\hosea\projects\app\player-references\NuvioMobile
C:\Users\hosea\projects\app\player-references\Stremio-Kai
```

3. Cross-check the local repositories against their upstream GitHub repositories:

```text
Harbor      → https://github.com/Harborofficial/Harbor
Nuvio       → https://github.com/NuvioMedia/NuvioMobile
Stremio Kai → https://github.com/allecsc/Stremio-Kai
```

4. Verify read-only access to the Jellyfin reference repositories:

```text
Jellyfin Android → https://github.com/jellyfin/jellyfin-android.git
Jellyfin iOS     → https://github.com/jellyfin/jellyfin-ios.git
```

5. Verify access to the supplementary read-only MPV reference where GitHub access is available:

```text
https://github.com/allecsc/mpv-qol-scripts
```

6. Verify REA availability (if unavailable, apply the fallback in Section 0.7; this is not a blocker).
6A. Execute the Section 0.3 preflight: `adb devices -l`, device facts, `flutter doctor -v`, `flutter devices`. Remember: physical USB Android device only, NO emulators, and NO iOS runtime (no Mac; iOS is built later through Codemagic).
6B. Create the safety branch and baseline tag (Section 0.6) before touching any NOVA file.
7. Create:

```text
docs/player-reengineering/
```

8. Create `00_MASTER_PLAN.md`.
9. Create every station execution file.
10. Populate each station with concrete tasks based on the actual repositories rather than generic placeholders.
11. Establish the initial task counts.
12. Record repository/reference versions where available.
13. Start Station 01.
14. Continue sequentially through the entire plan.
15. Do not stop after planning.
16. Do not ask for approval between stations EXCEPT at the Human Review Gates defined in Section 0.4 (A: after Station 08, B: after Station 09, C: after Station 10, D: after Station 16, E: after Station 20) and the conditional gates listed there. At each gate, write the gate review file, commit the checkpoint, send the short gate message, and STOP until I reply.
17. Between gates, continue autonomously until the next gate, or until a genuine critical blocker prevents further safe progress.
18. At completion create `FINAL_REPORT.md` and return the final evidence-backed report.

Begin.
