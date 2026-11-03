---
name: practical-ui
description: Logic-driven UI rules distilled from "Practical UI" (Adham Dannaway) — usability risk, interaction cost, cognitive load, accessible colour palettes (HSB, WCAG 2.1 AA + APCA), 8pt spacing, 12-column grid, visual hierarchy, type scales, UI copywriting, forms, and button hierarchy. Use when designing, building, reviewing, or auditing any web/app interface, creating design tokens (colour palette, type scale, spacing, shadows, radii), writing interface copy, designing forms or buttons, or when the user says "practical ui", "check this against practical ui", "UI rules", "why does this UI feel off". Complements `impeccable` — impeccable drives the workflow, this skill supplies the rulebook and rationale.
user-invocable: true
argument-hint: "[audit|tokens|forms|buttons|copy|colour|layout|type] [target]"
---

A rulebook, not a style. Every UI decision should have a logical reason that reduces **usability risk**, **interaction cost**, or **cognitive load**. Guidelines are strong defaults, not laws — break one only with a stated reason.

## Routing

| Task | Read |
|---|---|
| Audit / review an existing UI | `reference/audit-checklist.md` (+ the chapter for any failing area) |
| Create design tokens / a design system | `reference/fundamentals.md` → `reference/colour.md` → `reference/typography.md` → `reference/layout-spacing.md` |
| Simplify a cluttered screen | `reference/less-is-more.md` |
| Colour, contrast, palette, dark mode | `reference/colour.md` |
| Spacing, grouping, hierarchy, grid, alignment | `reference/layout-spacing.md` |
| Fonts, sizes, line height, line length | `reference/typography.md` |
| Labels, headings, buttons text, errors, microcopy | `reference/copywriting.md` |
| Forms | `reference/forms.md` |
| Buttons, actions, destructive flows | `reference/buttons.md` |

Read only the files the task needs.

## Non-negotiables (apply everywhere)

1. **WCAG 2.1 AA minimum**: text ≤18px → 4.5:1; large text (≥24px regular / >18px bold) and UI component boundaries (inputs, checkboxes, button shapes) → 3:1.
2. **Never colour alone** — pair with icon, underline, border weight, or text.
3. **Targets ≥ 48×48pt**, ≥ 8pt apart (16pt between buttons is safer).
4. **Predefined options only**: spacing, type sizes, colours, shadows, radii come from tokens — no one-off values.
5. **One primary action per screen.** Primary / secondary / tertiary hierarchy must not depend on colour alone.
6. **Labels above fields, single column, no placeholder-as-label, validate on submit.**
7. **Left-align text and buttons** by default; avoid centred/justified long text.
8. **Sentence case, concise, front-loaded, plain language.** Buttons = verb + noun.
9. **Conventional patterns first** (Jakob's Law). Innovate only where it's the product's differentiator.
10. **Minimal ≠ simple.** Never hide critical labels/actions just to look clean.

## Output conventions

- When auditing, report each finding as: **rule → evidence (selector/element) → risk → fix**, ordered by risk (accessibility & blocked tasks first, aesthetics last).
- When generating tokens, emit them as CSS custom properties (or the project's token format) and state the usage rule next to each token.
- When rejecting a request that breaks a rule (e.g. light-grey body text), say which rule, why, and offer the compliant alternative.
- Defer to an existing project design system when one exists; flag conflicts instead of silently overriding.
