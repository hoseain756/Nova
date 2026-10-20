# NOVA redesign deliverables

Project tracking: [living plan](10-project-plan.md) · [major milestone work log](11-work-log.md).

The order below matches the requested deliverables. The implementation is the Flutter app in `lib/`; this folder records the rationale, page behavior, source-inspection findings and verification limits. Attachments were reviewed first: the identity guide supplies the red/ink wordmark and logo rules, the ZIP supplies the original SVG/native brand assets, and `nova_colors.dart` supplies the only brand palette. There were no additional reference-screen images in the supplied ZIP.

1. **Current UI/UX and performance audit:** [01-audit.md](01-audit.md). It separates baseline source findings from changes and performance opportunities.
2. **Design system:** [02-design-system.md](02-design-system.md) and the implementation in [`lib/core/theme/nova_theme.dart`](../../lib/core/theme/nova_theme.dart).
3. **Information architecture and key flows:** [03-information-architecture.md](03-information-architecture.md).
4. **Page specifications:** [04-browse-spec.md](04-browse-spec.md), [04-cinematic-spec.md](04-cinematic-spec.md), [04-settings-spec.md](04-settings-spec.md), [05-player-spec.md](05-player-spec.md). Together they cover the shell, Home, search, discovery, Anime, Kids, Library/lists, Calendar, Live TV, Details, sources, settings, provider authorization, player, downloads, onboarding, errors, sheets and confirmations. Loading, empty, failed and success behavior is included per flow.
5. **Motion, RTL/LTR and accessibility:** [05-motion-accessibility.md](05-motion-accessibility.md) and the component timing/reduced-motion rules in the design-system spec.
6. **Flutter implementation:** [`lib/`](../../lib/), localization source files under [`lib/l10n/`](../../lib/l10n/), shared brand assets under [`assets/brand/`](../../assets/brand/) and included fonts under [`assets/fonts/`](../../assets/fonts/).
7. **Design rationale:** [07-rationale.md](07-rationale.md).

## Verification status

The live acceptance tracker is [requirements-status.md](requirements-status.md); it contains the current command results and artifact evidence. The follow-up [completion audit](08-completion-audit.md) records gaps found in the interrupted redesign and their repairs, including playback settings, startup animation, contrast and persistence coverage. On-device visual inspection, measured profile-mode frame time, accessibility hardware exploration, iOS/Xcode build and successful external OAuth/provider accounts still require their respective runtime setup.

The subsequent [acceptance hardening](09-acceptance-hardening.md) records reproducible parental-gate, storage, authorization-recovery and layout fixes, with headless Home/Details captures and focused flow regressions.

## Compatibility note

The visible brand, launcher labels, launch identity, About page and app description use NOVA. Existing app IDs, OAuth callback URIs, secure-storage keys and sync identifiers remain stable so upgrades and registered provider flows keep working. See the preservation contract in [01-audit.md](01-audit.md).
