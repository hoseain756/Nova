# NOVA acceptance hardening

Follow-up review, 18 October 2026. This continues the interrupted redesign with reproducible fixes; it does not substitute for device or provider acceptance.

## Findings and changes

- **Parental gate:** the PIN dialog overflowed with a keyboard and 200% text because only its form scrolled. The entire dialog body now scrolls while actions remain reachable. Arabic and Persian digits normalize to the same ASCII PIN before validation. A busy guard prevents duplicate keyboard submissions; storage errors fail closed with localized feedback. Existing secure-storage identifiers and salted hashes are preserved.
- **Storage settings:** the cache-reset sheet contained a fixed-height column taller than its 80%-viewport limit. Its choices now scroll, including the last interval and reset action. The explanatory sentence now uses the selected language for its interval instead of embedding English in Arabic.
- **Provider recovery:** a failed external-browser launch previously left a waiting authorization screen. Initial launch failures now restore the connect action. Code submission always clears its busy state after exceptions. Simkl polling treats transport timeouts and transient server responses as pending so the existing bounded flow can retry; terminal authorization errors remain failures.
- **Cinematic layout:** the Home pager and hero copy need to fit narrow screens without shrinking the user's text scale. Poster rail height must use the text style's actual metrics, including release metadata. Layout acceptance uses deterministic fixture content and the production Home and Details widgets.

## Focused regression coverage

- `nova_parental_gate_test.dart`: PIN normalization, persisted attempt lock, missing/unavailable credentials, duplicate submit protection, and EN/AR × Light/Dark × portrait/landscape keyboard layouts at 200% text.
- `nova_storage_sheet_test.dart`: localized interval description and selection of the last interval on a 320 px phone at 200% text in both locales and themes.
- `nova_auth_recovery_test.dart`: browser-launch failure/retry, code-submission exception recovery, transient Simkl polling and terminal authorization errors. Network and browser responses are mocked; no real authorization is claimed.
- `nova_flow_acceptance_test.dart`: onboarding navigation and manager-backed download states, including removal confirmation, on narrow portrait and landscape layouts.
- `nova_visual_acceptance_test.dart`: production Home/Details with fixture artwork, initial and covered hero states, both locales/themes, phone and tablet. Optional captures use `--dart-define=NOVA_WRITE_ACCEPTANCE=true` and are written under ignored `build/nova-review/acceptance/`.

Final command results and build evidence belong in [requirements-status.md](requirements-status.md). No emulator is used. Native playback, real OAuth, GPU frame timing, screen-reader exploration and iOS builds require their respective runtime environments.
