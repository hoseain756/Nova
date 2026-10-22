# Accessibility

Use this reference when implementing or auditing interactive frontend UI.

## Semantic interaction

Prefer native semantic elements when possible.

Interactive controls need meaningful accessible names and correct roles/states.

Do not use non-interactive elements as buttons without equivalent keyboard and semantic behavior.

## Keyboard

Verify:

- logical tab order;
- visible focus;
- Enter/Space activation where appropriate;
- Escape behavior for dialogs/overlays;
- focus containment/restoration for modals when required.

## Contrast

Check important text, icons, controls, borders, and status indicators against their actual rendered backgrounds.

Do not assume brand colors automatically meet contrast requirements.

## Touch targets

Ensure important touch controls are large enough to activate reliably and are not packed too tightly.

## Screen readers

Provide labels for icon-only controls.

Decorative graphics should not create noisy accessibility output.

Dynamic status changes should be exposed appropriately when users need to know about them.

## Motion

Respect reduced-motion preferences where supported.

Provide a stable final state rather than removing essential content.

## Scalable text

Avoid layouts that depend on fixed single-line labels.

Allow wrapping or adaptation for larger text and localization.

## Forms

Associate labels and errors with their fields.

Do not rely on color alone to indicate validation state.

## Completion

Do not claim TalkBack, VoiceOver, NVDA, or other assistive-technology verification unless it was actually performed.
