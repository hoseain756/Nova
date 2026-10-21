# Gate B — approved Option A, structural decoupling only

## Current decision — 2026-10-21, Asia/Riyadh

**Gate B APPROVED WITH CONDITIONS: Option A — retain media_kit and decouple the structure.** Verification status: STATIC-ONLY. Approval records the user's engineering direction, not runtime verification. Station 10 has NOT started and awaits the user's explicit go-ahead.

The detailed engine comparison, per-option RC1/RC3/RC4 evidence mapping, dependency notes and proposed contracts remain in `GATE_B_REVIEW.md-draft` and `09_STATION.md`. The options draft is historical; this file is the authoritative Gate B disposition. ADR-P001 is accepted for engine/direction; session, progress, rendering, recovery and persistence interface contracts remain DRAFT for finalization in Station 10. Other draft ADRs are not silently finalized.

## User approval and conditions — verbatim

> Gate B approved: Option A (retain media_kit, decouple the structure). Conditions:
> 1. Performance benefit remains UNKNOWN; the purpose is structural decoupling only. No performance claim without a valid before/after measurement.
> 2. Bundled native-library license stays classified as unclear, with the verification plan from the draft. Personal-use scope: no distribution is planned. If distribution is ever planned, reopen license review before that step.
> 3. Interface contracts (session, progress, rendering, recovery, persistence) are DRAFT, to be finalized in Station 10.
> 4. Do not change production code, build, install, or run device commands until Station 10 starts with my explicit go-ahead.
> 5. Update 00_MASTER_PLAN.md with the Gate B decision and the current last-known-good commit. Commit only the Gate B documentation files and the plan update, after showing me `git diff --cached --name-only` first. Do not push or tag.
>
> Stop after the commit and send me the decision summary (10 lines max).

## Evidence and rationale

Retain locked media_kit 1.2.6 / media_kit_video 2.0.1 / Android libs 1.3.8 / iOS libs 1.1.4. No new dependency approved. Station 08 RC1 (broad notifications), RC3 (ambiguous watchdog) and RC4 (missing explicit same-episode continuity transfer) support structural investigation. Candidate mitigations are STRONGLY INFERRED; none demonstrates a performance improvement or a playback-engine defect. Alternative engine substitution alone is not an established fix for host-level coupling, recovery policy or state handoff.

**Performance benefit remains UNKNOWN because no valid before/after measurement exists. Purpose: structural decoupling only.** Gate A's explicit baseline waiver allows reduced-confidence planning; it does not create a baseline or support a performance claim. `BASELINE.md` stays INCOMPLETE; every BEFORE value NOT MEASURED. Absolute measurements may later document behavior but do not by themselves establish an improvement over the legacy player. All build/runtime acceptance is NOT-VERIFIED in this continuation.

## License disposition and retained verification plan

Under Section 0.8, the four media_kit package/wrapper LICENSE files are classified permissive (MIT), source evidence VERIFIED / review STATIC-ONLY; exact file paths are in `LICENSE_NOTES.md`. Preserve required copyright/permission notices.

Bundled native libmpv/FFmpeg/transitive artifacts stay **unclear**, evidence UNKNOWN / verification NOT-VERIFIED. Do not inherit MIT classification from the wrapper. Personal use only; no distribution is planned. This records scope, not distribution clearance or a change to the license classification.

Retained plan: identify exact Android v1.1.7 default ABI jars and iOS v0.6.0 video-default frameworks and their included components; inspect matching build recipes/flags, LICENSE/NOTICE files and linkage; establish applicable corresponding-source/relink/notice obligations and review target distribution compatibility. **If any distribution is planned, reopen and resolve the license review before that step.** No downloads/build scripts/native changes performed here. New dependency/native replacement and data/signing/platform conditional gates remain.

## Station 10 boundary

Session ownership, state/progress frequency, rendering isolation, recovery budget, checkpoint ordering and persistence contracts remain DRAFT. Numerical design proposals in the options packet are not finalized interfaces. Station 10 must explicitly finalize these contracts within its authorized scope while preserving compatibility. No production, instrumentation, dependency, native, CI, signing or stored-data change is authorized now. No build, install or device command. Legacy player intact; two-implementation selector not implemented. Legacy-removal approval remains at Gate E.

## Repository safety and checkpoint scope

**Checkpoint pending, not committed:** initial `git add` failed to create protected `.git/index.lock` (Permission denied). The required elevated index-write request was rejected by the user; no bypass attempted. No files staged, so no commit/push/tag. Gate B approval is recorded independently of this blocked Git operation. Before any later authorized retry/commit, display `git diff --cached --name-only` after staging the exact six files below.

Verified branch `feature/player-reengineering`, pre-commit HEAD `d19224bc3a59dbfe9db1c43126842159820ff33f`, empty initial index. Current recorded production LKG remains **`c9257c0ea6b74b2b4fd180d5ca0f3e08da8617b5`**, verified to exist, ancestor of HEAD and equal to existing safety tag. No fresh build/device check, so no LKG promotion. No tag is created or moved.

Authorized checkpoint files, all under `docs/player-reengineering/`:

- `00_MASTER_PLAN.md`
- `09_STATION.md`
- `GATE_B_REVIEW.md`
- `GATE_B_REVIEW.md-draft`
- `GATE_B_REVIEWER.md`
- `LICENSE_NOTES.md`

Earlier uncommitted `BASELINE.md`, `GATE_A_REVIEW.md`, `OWNERSHIP.md` updates and all unrelated user changes are excluded from this commit. Current Gate A waiver is also recorded in the detailed Gate B packet, so older committed pending/no-waiver text does not control resumption. Current decision overrides historical no-commit/pending statuses only for this exact documentation checkpoint.

Validation: scoped documentation whitespace/content/checkbox checks, Git root/branch/LKG/tag/ancestry/index and exact staged-path inspection. Show `git diff --cached --name-only` to the user before the authorized commit, then inspect the resulting commit paths. Historical independent Gate B review/correction is retained in `GATE_B_REVIEWER.md`; no repeated reviewer or fabricated re-review. No analyzer/tests/build/runtime commands. Commit subject: `player: station 09 gate b approval`.

**STOP AFTER THE DOCUMENTATION COMMIT. No push or tag. Station 10 awaits explicit user go-ahead.**
