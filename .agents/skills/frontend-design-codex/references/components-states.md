# Components and UI States

Use when building reusable UI primitives or screens with meaningful application states.

## Reuse before creation

Search for an existing primitive before creating a new one.

Prefer extension over duplication when the existing API can remain understandable and backwards compatible.

## Extraction criteria

Extract a component when it represents:

- a repeated visual pattern;
- a meaningful product concept;
- complex interaction;
- a reusable primitive;
- a unit that improves readability/testability.

Do not split every few lines into a separate component.

## States

Where relevant, design and implement:

- default;
- hover;
- focus;
- pressed;
- selected;
- disabled;
- loading;
- empty;
- error;
- success;
- offline or unavailable;
- skeleton/placeholder.

## Data density

Avoid using the same card pattern for every kind of information.

Choose presentations appropriate to the data: list, table, grid, timeline, compact row, media tile, inspector, etc.

## Dialogs and overlays

Ensure clear dismissal behavior, focus handling, responsive sizing, and layering.

Avoid nested overlays unless the interaction requires them.

## Forms

Keep labels, help text, validation, and actions spatially coherent.

Do not hide important constraints until submission if they can be communicated earlier.
