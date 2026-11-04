# NOVA Cinema design system

## Direction
Artwork-led browsing, warm paper in daylight and warm ink in dark rooms. Keep the original NOVA mark. Separate titles, metadata and controls from busy imagery. Home uses a two-part feature story; wide detail pages use an overview/actions column beside synopsis and ratings. Content uses spacing and dividers; material surfaces identify interactive objects and navigation.

## Palette
Use semantic NovaTheme/ColorScheme roles. Dark canvas #191715, surface #282522, elevated #34302C, secondary text #C5BBB1, accent #F19A87. Light canvas #F6F1E9, surface #FFFFFF, text #191715, secondary #625C55, accent #A32E23. Primary action #B93529 with white text. Android 12+ system accent seeds tonal container surfaces; action identity remains NOVA. OLED remains an explicit pure-black dark option. Errors include text and an icon, never color alone.

## Typography
Poppins for Latin and IBM Plex Sans Arabic for Arabic; logo always supplied SVG. Body 16/1.5, supporting 14/1.5, labels 14/1.3, headings 20/24/32/40 with weights 500/600/700. Preserve subtitle font preferences independently.

## Geometry
8dp spacing grid: 8,16,24,32,48,64 with a 4dp optical half step. Controls use 12dp corners, media uses the persisted user radius (default 12), sheets use 24–28, floating Android navigation uses 28–32. Controls have at least 48dp touch targets. Keep content groups flat. Card size/orientation/radius come from CardPreferences, with geometry shared by loading rails, live preview and grids.

## Responsive
Compact below600dp: 16–20dp gutters and floating bottom navigation. Medium600–839dp:24dp gutters and floating navigation. Expanded840dp+: labeled logical-start sidebar,32dp gutters and split detail/settings layouts. Known iPhones retain phone navigation in landscape. Compact tablet multitasking follows available window width. Hero controls scroll into reach on short windows; player overlays stay bounded by their video viewport. Every screen reserves the navigation and system safe-area clearance.

## Platform materials
iOS26 uses system UIGlassEffect/UITabBar in a presentation-only scene overlay for phone navigation and the iPad sidebar. Flutter owns routing and authorization. Older iOS and reduced-transparency modes use accessible Flutter fallback chrome. Android uses an actual Material3 NavigationBar inside a floating tonal surface; tablets use persistent directional navigation. Do not claim a Flutter blur as native refraction.

## Motion
120ms press,180ms state,240ms route/expansion, easeOutCubic. Respect OS and in-app reduced motion, stop offscreen animations. Fallback opaque chrome with reduced transparency.

## Components
Theme-level buttons, inputs, switches, sliders, tabs, chips, dialogs and sheets. Shared page header, empty/error message, skeleton, cached image, branded mark and parental gate.

## Media and motion policies
Hero trailers default to Wi-Fi only, start muted after 3 seconds, and are bounded to 35 seconds. Never, Reduce Motion, low-power mode, OS data saver, covered routes, background state and insufficient player space stop preview creation/playback. Provider embeds remain unobscured and use the OS WebView; the full media player has separate ownership. Missing or blocked trailers retain artwork. Hero/card image quality is independent; CDN changes are limited to recognized TMDB paths and decode memory stays bounded even for Original.

## Arabic and accessibility
Use logical start/end layout and directional navigation order. Arabic uses IBM Plex Sans Arabic, slightly more leading, and no tracking. Latin uses Poppins. Mixed provider names, dates, episode identifiers and numerical readouts retain explicit direction where needed. Never flip logos, artwork or play/pause icons. Retain the player's established explicit timeline convention. Prefer natural-height fields and rows, 200% text stress checks, semantic selected/disabled states, tooltips, keyboard focus and reduced motion.

## Review evidence
See docs/redesign/audit.md for the complete surface inventory and docs/redesign/qa.md for executed tests, rendered evidence and native/device limits.
