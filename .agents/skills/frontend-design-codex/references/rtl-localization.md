# RTL and Localization

Use when the project supports Arabic, Hebrew, RTL, or multilingual UI.

## Localization infrastructure

Reuse the project's localization system.

Do not introduce hardcoded user-visible strings in localized areas.

## RTL layout

Verify:

- text alignment;
- logical start/end spacing;
- navigation order;
- drawers and side panels;
- chevrons and directional icons;
- carousel controls;
- breadcrumbs;
- animation direction when spatial meaning changes;
- mixed RTL/LTR content.

Prefer logical CSS properties such as inline-start/inline-end where they fit the codebase.

## Bidirectional content

Numbers, URLs, filenames, media titles, timestamps, and Latin product names may appear inside RTL text.

Avoid assumptions that all content follows one direction.

## Text expansion

Do not size controls only for the shortest language.

Allow labels to wrap or adapt where appropriate.

## Arabic typography

Verify vertical metrics, line height, weight, and clipping with the actual bundled Arabic font when available.

Do not assume Latin typography settings transfer directly to Arabic.

## Icons

Mirror only icons whose meaning is directional.

Do not mirror brand marks, media symbols, or universally fixed pictograms without reason.
