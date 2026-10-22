# Codex Frontend Workflow

Use this reference for non-trivial frontend work in an existing repository.

## Repository reconnaissance

Before changing code:

1. Read root and nested `AGENTS.md` files that govern the target files.
2. Identify package manager and workspace layout.
3. Identify framework and rendering model.
4. Identify routing and navigation conventions.
5. Identify styling approach: CSS, CSS Modules, Tailwind, styled-components, Sass, design tokens, etc.
6. Identify the shared component system.
7. Identify theme and color token sources.
8. Identify typography and icon sources.
9. Identify localization and RTL infrastructure.
10. Identify tests, lint, typecheck, and build commands.

Do not assume common defaults when the repository already defines a convention.

## Scope control

Before editing, determine:

- which files directly implement the requested UI;
- which shared files must change;
- which files should remain untouched;
- whether the change is local, cross-page, or design-system level.

Prefer the smallest coherent change set.

Avoid opportunistic cleanup unrelated to the task.

## Existing design system

If a project has shared primitives or tokens, extend them rather than creating parallel versions.

Before adding a new button, dialog, card, field, chip, icon wrapper, spacing token, or surface token, search for the existing equivalent.

If the existing primitive is close but insufficient, prefer a backwards-compatible extension when reasonable.

## Dependency policy

Before adding any package:

- inspect current dependencies;
- confirm the capability is not already present;
- consider bundle cost and maintenance;
- prefer platform/framework primitives for simple needs;
- avoid overlapping libraries for the same concern.

Do not replace a working library merely because another is more fashionable.

## Editing discipline

Do not:

- rewrite unrelated files;
- reformat the repository globally;
- rename unrelated symbols;
- delete compatibility code casually;
- hand-edit generated files unless required by the repository workflow;
- remove behavior to make the UI easier to implement.

Preserve public interfaces unless a breaking change is explicitly requested.

## Multi-agent work

If delegation is available:

- use it only when tasks are genuinely separable;
- assign clear file ownership;
- avoid two agents editing the same file simultaneously;
- avoid duplicate repository exploration;
- share discovered design-system facts with delegated agents;
- integrate to one coherent visual result.

For small UI changes, one capable agent is usually more efficient than a swarm.

## Validation sequence

Use repository-native commands where possible.

A typical order:

1. format changed files;
2. lint;
3. typecheck;
4. focused tests;
5. broader tests if risk justifies them;
6. production build when relevant.

Do not weaken assertions to hide regressions.

## Completion report

Report:

- what changed;
- important design/architecture decisions;
- validation performed;
- anything not verified in the current environment.

Never claim device/browser/assistive-technology verification that was not performed.
