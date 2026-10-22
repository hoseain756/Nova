# Repository Guidelines

## Project Map

- `lib/main.dart` starts the app; `lib/app/noor_app.dart` composes launch, theme, and localization.
- `lib/core/` contains API, data/cache, downloads, models, OAuth, state, sync, theme, torrent, tracking, and Trakt.
- lib/core/update/app_update_service.dart validates root version.json and APK content, compares installed build metadata, classifies update failures, downloads to app cache, and opens the package installer.
- `lib/core/models/integration_cw.dart` normalizes linked-service playback progress (Trakt/Simkl pause points and AniList/MyAnimeList episode counters); `AppState.refreshLinkedContent` refreshes it, and `AppState.historyForTitle` merges provider episode state with local history for details.
- `lib/core/storage/resume_snapshot_store.dart` saves compressed, expiring video pause frames locally; its metadata stays separate from synced watch history.
- `lib/features/` contains `shell/`, `home/`, `media/` (details/episodes/sources), `catalog/`, `anime/`, `calendar/`, `live_tv/`, `kids/`, `library/`, `downloads/`, `player/`, `settings/`, `onboarding/`, `splash/`, and torrent handlers.
- `lib/features/player/session/playback_progress.dart` contains immutable progress samples and a latest-value coalescer (100 ms minimum publication spacing, injected monotonic clock/scheduler, generation reset and close cancellation). `playback_progress_binding.dart` owns the route-local display listener and invalidates old engine identities. `VideoPlayerPage` enables this projection only with `--dart-define=NOVA_COALESCED_PROGRESS=true` (default false). Timeline commands use exact engine readers; persistence/feature decisions remain exact. The common engine/page notifier still exists, so this is not full rendering isolation or completion of Station 10. Tests: `playback_progress_test.dart`, `playback_progress_binding_test.dart`, `player_timeline_progress_test.dart`.
- `lib/features/player/playback_entry_page.dart` chooses legacy (default) or `core_video_player_page.dart` once per route, before engine allocation; enable the experimental core with `--dart-define=NOVA_PLAYER_CORE=true`. `session/playback_state.dart` freezes route inputs and defines command outcomes; `playback_session.dart` owns serialized commands, source/resolver generations, exclusive native ownership, progress/transport projections, panel/lifecycle intent and awaitable close. `playback_checkpoint.dart` serializes exact immutable checkpoints across core routes through existing AppState/storage APIs; no storage schema or sync keys change. `widgets/player_session_surface.dart` caches the video child until engine identity or fit changes. The legacy page stays selectable until Gate E; runtime/performance acceptance is separate from compilation/tests.
- `MediaKitEngine.open` retains legacy autoplay by default and adds `playWhenReady: false` for the core; `close()` awaits native retirement. Do not mix legacy `dispose()` ownership with core `close()` on the same engine. Apply startup offsets/subtitle-off inside the open generation before play; source continuity overrides startup defaults. Core handoffs revalidate play-intent revision and current lifecycle. Core resolver handoffs must retire native playback before `TorrentService.prepare`, which deactivates an existing torrent. Session explicitly owns current/retiring leases: never stop a torrent before successful native retirement or create another engine after a failed/hanging close.
- `lib/shared/widgets/` holds reusable cards, rails, image helpers, dialogs, parental gates, and loading states. `lib/l10n/` contains Arabic/English ARB sources and generated code.
- `lib/features/media/episode_views.dart` owns detail episode list/grid presentation; long-press actions are wired from `media_detail_page.dart`, while `AppState` stores watched ranges and sends one enabled-service sync per provider.
- `lib/features/home/widgets/continue_watching_rail.dart` renders local and linked Continue Watching cards together in one horizontal rail; `lib/features/media/episode_views.dart` presents episode progress and mark-watched actions; Anime reuses the same linked-progress rail.
- Local Continue Watching cards can display device-only resume frames; the playback retention choice lives in `SettingsPreferencesPage` and defaults to 30 days.
- `assets/brand/` and `assets/fonts/` hold NOVA identity and fonts; `android/` and `ios/` hold platform files; `test/` has tests, including updater manifest/build regression coverage in `app_update_service_test.dart` and version pinning in `version_pin_test.dart`; `tool/` has utilities.
- Root configuration includes pubspec.yaml, the public update manifest version.json, analysis_options.yaml, DESIGN.md, and PRODUCT.md. .github/workflows/release.yml runs Android analysis, tests, and APK builds; docs/nova/release-signing.md records the release-signing limits.

## Build, Test, and Development

- `flutter pub get` resolves the locked dependencies.
- `flutter analyze --no-pub` checks diagnostics; `flutter test --no-pub` runs unit/widget tests (or pass `test/<name>_test.dart` for one file).
- `dart format lib test` formats code; use `--output=none --set-exit-if-changed` for a check.
- `python tool/generate_nova_l10n.py` regenerates localization code from ARB sources.
- `flutter build apk --release --no-pub` builds Android. An iOS build requires macOS and Xcode.
- Never launch an emulator. Do not claim physical-device verification unless a device was actually used.

## Code Style and Localization

Use standard Dart formatting, two-space indentation, `UpperCamelCase` types, `lowerCamelCase` members, and `snake_case.dart` files. Keep feature state scoped and reuse shared widgets. Add copy to both `lib/l10n/app_en.arb` and `app_ar.arb`, run the generator, and never hand-edit `nova_messages.g.dart`. Use logical directional layout and check RTL behavior.

## Architecture and Compatibility

Preserve app IDs, callbacks, secure-storage and sync keys. Internal `noor` names are compatibility identifiers. Claim provider/device behavior only after real verification.

## Testing and Review

Name tests `*_test.dart`; cover changed behavior, including RTL/LTR and themes for UI. For releases, keep `pubspec.yaml`, `lib/core/version.dart`, and root `version.json` aligned; advance Android build numbers monotonically and test that the previous build sees the manifest as an update, and verify that JSON strings returned as `text/plain` are decoded before validation. Before submitting, run relevant tests/analyzer, inspect `git diff --check`, and disclose checks needing hardware, accounts, or macOS. Publish the updated root manifest before expecting installed clients to discover a release; attach the matching-signed APK to the corresponding GitHub Release before relying on the app download link.

## Commit and Pull Requests

Use concise Conventional Commit subjects, e.g. `feat(player): ...`. PRs should describe behavior, list validation, link issues, and include UI screenshots.

## Security and Configuration

Never commit provider credentials or private signing keys. Keep key.properties and *.jks ignored. Android release builds use the existing debug-key fallback until a complete local android/key.properties is configured; the GitHub workflow has no upload keystore and its APK artifact must not be published as an app update. See android/key.properties.example and docs/nova/release-signing.md. The updater reads public version metadata and installs downloaded APKs from app cache.

## Required Documentation Maintenance

**Always update this `AGENTS.md` whenever project structure, architecture, commands, conventions, or important development practices change. Keep the project map accurate as files and modules evolve.**
