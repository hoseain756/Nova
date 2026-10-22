# Motion

Use this reference for transitions, micro-interactions, animated surfaces, and motion systems.

## Purpose

Motion should communicate:

- state change;
- hierarchy;
- spatial relationship;
- progress;
- interaction feedback.

Avoid animation whose only purpose is to make the interface look busy.

## Prioritize strong moments

A coordinated page entrance, meaningful shared transition, or well-designed modal motion is usually more effective than dozens of unrelated micro-animations.

## Performance

Prefer properties that avoid unnecessary layout work.

Be cautious with:

- large blurred layers;
- continuous filters;
- huge animated shadows;
- many simultaneous animations;
- scroll-bound JavaScript work.

## Existing libraries

Use the animation system already present in the repository when practical.

Do not add a library for a trivial fade or transform.

## Reduced motion

When supported, reduce or remove non-essential movement while preserving information and usable final states.

## Interaction

Animations must not delay user input unnecessarily.

Controls should remain predictable during transitions.
