---
name: frontend-design
description: Design and implement distinctive, production-grade frontend interfaces in existing or greenfield web projects. Optimized for Codex: inspect the repository first, preserve architecture and design systems, load only the reference guidance needed for the task, make targeted edits, and validate real working code.
license: Complete terms in LICENSE.txt
---

# Frontend Design — Codex Skill

Use this skill when Codex is asked to build, redesign, refine, audit, or repair frontend UI, including websites, dashboards, landing pages, product interfaces, React/Next.js/Vue applications, HTML/CSS layouts, design systems, responsive behavior, and visual polish.

The objective is to produce interfaces that are:

- distinctive rather than generic;
- production-grade rather than mockups;
- coherent with the product and repository;
- responsive, accessible, and maintainable;
- visually intentional without unnecessary visual noise.

## 1. Core execution rule

For existing repositories, inspect before designing.

Before editing:

1. Read the applicable `AGENTS.md` files.
2. Identify the framework, routing, styling system, component library, theme architecture, icons, localization system, tests, and build commands.
3. Inspect the target screen/component and nearby shared primitives.
4. Reuse established project patterns unless the user explicitly requests a deliberate departure.
5. Prefer targeted changes over broad rewrites.

Do not treat an existing application as a blank canvas.

## 2. User direction has priority

Honor explicit user requirements for:

- visual style;
- reference screenshots;
- brand colors;
- typography;
- layout behavior;
- platform conventions;
- animation style;
- responsive behavior;
- accessibility or localization constraints.

Do not replace the user's requested direction merely because another style is easier to implement.

## 3. Avoid generic AI UI

Do not default to generic generated aesthetics such as:

- purple/blue gradients on white;
- identical floating glass cards everywhere;
- oversized marketing hero text without product relevance;
- excessive pills and rounded rectangles;
- generic SaaS dashboards;
- meaningless glow, blur, or gradients;
- repetitive cards with no visual hierarchy;
- arbitrary "modernization" that erases product identity.

Every visual choice should have a product reason.

## 4. Preserve repository integrity

When modifying an existing application:

- preserve framework and routing conventions;
- preserve state-management patterns;
- reuse existing tokens and shared components;
- reuse the existing icon system;
- avoid introducing duplicate design systems;
- avoid unrelated refactors;
- retain compatibility code unless removal is explicitly required;
- inspect current dependencies before adding packages.

Do not add a dependency for functionality already available in the repository or platform.

## 5. Implement real behavior

Do not stop at static mockups when implementation is requested.

Connect controls to real application behavior where the surrounding code supports it. Handle relevant states such as loading, empty, error, disabled, selected, hover/focus, success, and responsive variations.

## 6. Responsive-first discipline

Design responsively from the start, not as a final patch.

At minimum, consider:

- small phones;
- large phones;
- tablets when applicable;
- laptops/desktops;
- large text and long labels;
- RTL when the project supports it.

Do not simply shrink the desktop composition onto mobile.

## 7. Accessibility is part of quality

Preserve or improve:

- semantic controls;
- keyboard navigation;
- visible focus;
- contrast;
- touch target sizing;
- screen-reader labels;
- reduced-motion behavior;
- scalable text.

Do not weaken accessibility for visual convenience.

## 8. Component and token discipline

Before creating a new primitive, search for an existing equivalent.

Prefer semantic design tokens over scattered literal values. Extract reusable components when they represent a meaningful repeated pattern or complex interaction, not merely to increase file count.

## 9. Motion discipline

Use motion to clarify hierarchy, state change, and interaction. Prefer a small number of coordinated motion moments over many decorative animations.

Respect reduced-motion preferences where supported.

## 10. Validation

After implementation, run the relevant repository commands when available:

- formatter;
- lint;
- type checking;
- unit/component/widget tests;
- integration tests;
- build.

Do not weaken tests just to obtain a green result. If validation cannot run in the environment, state exactly what remains unverified.

## 11. Efficient reference loading

Do NOT load every reference file by default.

Read only the files relevant to the current task.

### Always consider

- `references/codex-workflow.md` for non-trivial work in an existing repository.
- `references/visual-design.md` for redesigns, visual refinement, or new UI.

### Read when needed

- `references/responsive.md` — breakpoints, adaptive layout, mobile/tablet/desktop behavior.
- `references/accessibility.md` — semantics, keyboard, contrast, focus, touch targets, reduced motion.
- `references/typography.md` — font hierarchy, multilingual typography, density, readable scale.
- `references/motion.md` — transitions, micro-interactions, animation performance.
- `references/rtl-localization.md` — Arabic, RTL, bidirectional layout, localization behavior.
- `references/components-states.md` — reusable components and loading/empty/error/selected states.
- `references/performance.md` — rendering cost, media, blur, animation, bundle/dependency discipline.

If a task does not involve a topic, do not read that topic's reference file.

## 12. Final quality gate

Before completing a frontend task, verify that:

- the requested design direction is actually visible in the implementation;
- the result fits the existing product rather than looking imported from another app;
- responsive behavior is intentional;
- accessibility has not regressed;
- shared components/tokens were reused appropriately;
- no unnecessary dependency or broad rewrite was introduced;
- relevant validation was run;
- remaining unverified items are reported honestly.

## Core principle

Create an interface that feels specifically designed for the product.

Optimize for:

**distinctiveness + coherence + functionality + accessibility + responsiveness + maintainability.**
