# NOVA design system

## Direction
Cinematic Ink surfaces, calm Nova Red actions, soft red selected labels, original play/film-strip logo, disciplined typography. Glass is reserved for floating navigation and hero chrome.

## Palette
Only supplied NovaColors values and alpha composites. Dark canvas #141417, surface #232329, elevated #2E2E35, text #FFFFFF, secondary #A4A4AC, accent #E8858D. Light canvas #F6F6F7, surface #FFFFFF, text #141417, secondary #585862, accent #B82C39. Primary action #D13B47 with #FFFFFF text. Error dark #E8858D / light #9E2A34, always with text and icon.

## Typography
Poppins for Latin and IBM Plex Sans Arabic for Arabic; logo always supplied SVG. Body 16/1.5, supporting 14/1.5, labels 14/1.3, headings 20/24/32/40 with weights 500/600/700. Preserve subtitle font preferences independently.

## Geometry
8dp spacing grid: 8,16,24,32,48,64. 4dp optical half step. Radius 12 inputs and controls,16 posters,24 sheets,999 floating navigation. Controls at least48dp. Flat content surfaces; no nested decorative cards.

## Responsive
Compact windows below 600dp use 16dp gutters and a bottom dock. From 600–839dp, use 24dp gutters and the dock. At 840dp and above, use the narrow icon-only logical-start rail and 32dp gutters. Featured Home, Anime and Kids heroes use full-bleed artwork at 78% of screen height, with a legible overlaid caption and controls. Below 700dp prefer portrait artwork fitted across the full hero; wider layouts prefer landscape artwork. The available catalog image stays stable while optional metadata arrives, and known slide images are prefetched. Centered dots have an 8dp visual gap, a slightly longer active dot and a 48dp-high touch region. Detail artwork fills the available width at 50% of screen height on phones and tablets, with its caption below. Keep enlarged hero text reachable and let the page scroll from the artwork.

## Motion
120ms press,180ms state,240ms route/expansion, easeOutCubic. Respect OS and in-app reduced motion, stop offscreen animations. Fallback opaque chrome with reduced transparency.

## Components
Theme-level buttons, inputs, switches, sliders, tabs, chips, dialogs and sheets. On iPhone/iPad, standard UIKit switches, simple confirmations and anchored selection menus use the system appearance; iOS 26 supplies Liquid Glass where Apple applies it. Keep data, forms, artwork and player video in their content layer. Shared page header, empty/error message, skeleton, cached image, branded mark and parental gate.
