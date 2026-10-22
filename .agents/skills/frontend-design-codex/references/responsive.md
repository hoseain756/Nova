# Responsive Design

Use when the task affects layout across viewport sizes.

## Design adaptively

Do not treat responsiveness as desktop scaling.

Consider how structure changes on:

- small phones;
- large phones;
- tablets;
- laptops;
- desktop displays.

## Adapt structure, not only dimensions

Potential adaptive changes include:

- bottom navigation becoming a side rail;
- multi-column grids collapsing;
- persistent sidebars becoming drawers;
- metadata moving below primary content;
- dialogs becoming full-screen sheets on small devices;
- hover affordances receiving touch equivalents;
- dense tables becoming stacked summaries.

## Avoid brittle layout

Avoid hardcoded sizes that fail with:

- localization;
- long labels;
- dynamic content;
- browser zoom;
- large accessibility text;
- RTL.

Prefer flexible sizing, min/max constraints, grid/flex layout, and content-aware wrapping.

## Touch

Ensure touch interfaces have comfortable hit areas and spacing.

Do not rely on hover-only discovery for essential actions.

## Media

Preserve aspect ratios.

Use deliberate crop behavior and avoid stretching images/video.

For artwork-heavy interfaces, define how focal content behaves at narrow and wide aspect ratios.

## Validation

Check at representative widths and also near transition points where layouts change.

Look for:

- overflow;
- clipped text;
- overlapping controls;
- unusable tap targets;
- excessive empty space;
- accidental horizontal scrolling;
- dialogs exceeding viewport height.
