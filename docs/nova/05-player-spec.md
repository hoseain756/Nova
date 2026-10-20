# NOVA player interaction specification

The video remains the darkest surface. Universal playback icons stay white over dark NOVA ink scrims; the played timeline uses the supplied red-to-soft-red brand gradient. Picker/settings/episode/subtitle-style surfaces follow the active Light or Dark theme.

Phone portrait: source/audio/subtitle/settings panels are full-width bounded bottom surfaces at 82% of viewport height. Playback controls split into two independent rows below the timeline, removing the previous overlapping start/end groups. Landscape phones and tablets: pickers attach to logical end, width 48% clamped to 360–560px. Only the actual outer screen edge's safe inset is applied. Outside tap dismisses the panel. Existing pause/resume ownership is preserved.

Sources now include local search, available-result count, selected-source treatment, and spacious rows. Loading panels use immediate row skeletons. Subtitle language grouping and search, audio language grouping, delays, source refresh, speed, fit, episodes, subtitle style and live previews all remain functional. Playback setting chips have 48px targets and switch to two columns under larger text scaling. Audio/subtitle timing steppers have their own rows to avoid Arabic and enlarged-text collisions.

The timeline fills from inline start. Tap/drag positions, horizontal seek deltas and double-tap seek regions mirror RTL together. Numeric timestamps remain LTR, while universal play/pause and transport symbols retain their shapes. Brightness/volume gesture regions and feedback use logical start/end. The custom timeline exposes accessible increment/decrement actions.

Reduced motion disables chrome fades, timeline thumb animation, ripple scale/fade, picker slides and subtitle-group rotations. Sheet transitions otherwise use 220ms easeOutCubic. Side pickers remain instant, with data loading visible inside them.

Subtitle colours are user-editable content values, preserved independently of the UI palette. No network or engine contract was removed. The targeted tests in test/nova_player_direction_test.dart check mirror math and timeline tap behavior; player surfaces still require real device playback and GPU profiling before a 60fps claim can be made.

## Saved preferences and playback lifecycle

Resume disabled starts from zero. Resume enabled uses saved progress automatically, unless the optional resume prompt is enabled and the position exceeds 30 seconds. The prompt pauses playback; choosing start over or resume explicitly starts it again. Progress/history writes must not replace the saved position while that choice is pending. Unknown and very short media durations use a safe seek bound.

Back first closes an open player panel. Leaving the player follows the saved confirmation preference, pauses behind the confirmation and restores playback on cancellation. Accepted exit attempts to save progress before popping; save failure cannot trap the user inside the player.

Default audio and subtitle preferences select matching available tracks after the engine reports them. ISO language aliases and track titles are supported. Explicit subtitle-track language takes priority over the ranked list; subtitles-off takes priority over both. Manual track choices are not overwritten by subsequent engine notifications. The legacy `subtitleTranslationLanguage` key remains a track-selection setting, not a machine-translation service.

Saved picture fit initializes the video: `fit` contains the frame, and the existing `fill`/`zoom` aliases cover it. The speed picker uses configured valid speeds plus the current speed, with standard speeds as fallback. The speed pill retains its compact visual shape within a 52 by 44 dp tap target.

Optional source information shares a compact metadata row below the title with the episode tag and active torrent status. Long source/status text ellipsizes; the full text remains available to semantics. Before the engine is ready, torrent feedback retains its standalone position. During playback it belongs to the header flow, preventing it from painting under the title. The composed header, side rail, central transport and footer have non-overlap widget coverage at 844 by 390 dp and 200% text in both directions.

Torrent speed, peers, seeds and percentage form an isolated LTR text run inside the localized status sentence, keeping number/unit pairs ordered correctly in Arabic.

Policy, language matching, speed sanitation and resume-boundary tests live in `test/nova_playback_preferences_test.dart`; responsive header and side-panel tests cover localized labels and enlarged text. Native engine execution and account scrobbling still need physical-device/provider acceptance.
