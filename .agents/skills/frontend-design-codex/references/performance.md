# Frontend Performance

Use this reference when the task includes heavy media, effects, animation, large pages, or new dependencies.

## Rendering cost

Avoid unnecessary re-renders and large component trees.

Use memoization only when it solves a measured or obvious structural problem; do not cargo-cult it everywhere.

## Effects

Blur, filters, layered transparency, large shadows, and backdrop effects can be expensive.

Limit them to areas that provide visible value and test on representative devices when possible.

## Media

Use appropriate image sizes and formats.

Lazy-load heavy media where architecture permits.

Do not load full-resolution assets when small thumbnails are sufficient.

Preserve aspect ratios and avoid layout shifts.

## JavaScript

Avoid unnecessary client-side logic and event listeners.

Prefer CSS for simple visual states and transitions when appropriate.

## Dependencies

New libraries carry bundle, maintenance, and security cost.

Prefer existing dependencies or platform features for simple requirements.

## Animation

Avoid expensive continuously running animation without purpose.

Prefer transform/opacity-style motion when suitable.

## Validation

Do not claim performance targets such as 60 fps unless they were actually measured under relevant conditions.
