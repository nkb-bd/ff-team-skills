# Claude Code Unified Flow

This folder groups the skills that belong to the main Claude Code operating flow.

Do not move the actual skill directories into this folder unless the skill loader is confirmed to support nested skill discovery. The source skills stay at the repository root so they remain registered and callable.

## Primary Flow

| Intent | Skill | Source |
|---|---|---|
| Build a feature or non-trivial enhancement | `new-feature` | [`../../new-feature/SKILL.md`](../../new-feature/SKILL.md) |
| Fix a reported bug or failing CI | `bug-fix` | [`../../bug-fix/SKILL.md`](../../bug-fix/SKILL.md) |
| Review a branch before merge | `pre-merge-review` | [`../../pre-merge-review/SKILL.md`](../../pre-merge-review/SKILL.md) |
| Apply workflow principles to non-trivial work | `rigorous-coding-workflow` | [`../../rigorous-coding-workflow/SKILL.md`](../../rigorous-coding-workflow/SKILL.md) |

## Graph Support

| Need | Skill | Source |
|---|---|---|
| Set up or verify code-review-graph | `setup-code-review-graph` | [`../../setup-code-review-graph/SKILL.md`](../../setup-code-review-graph/SKILL.md) |
| Coordinate free/pro contract changes | `cross-plugin-coordination` | [`../../cross-plugin-coordination/SKILL.md`](../../cross-plugin-coordination/SKILL.md) |

## Supporting Skills

| Phase | Skill | Source |
|---|---|---|
| Vocabulary and planning alignment | `grill-with-docs` | [`../../grill-with-docs/SKILL.md`](../../grill-with-docs/SKILL.md) |
| Interface/API shape exploration | `design-an-interface` | [`../../design-an-interface/SKILL.md`](../../design-an-interface/SKILL.md) |
| Test-first implementation | `tdd` | [`../../tdd/SKILL.md`](../../tdd/SKILL.md) |
| PR description | `pr-descriptor` | [`../../pr-descriptor/SKILL.md`](../../pr-descriptor/SKILL.md) |
| PHP style | `php-cs-fixer-style` | [`../../php-cs-fixer-style/SKILL.md`](../../php-cs-fixer-style/SKILL.md) |
| Deep plugin audit | `plugin-audit` | [`../../plugin-audit/SKILL.md`](../../plugin-audit/SKILL.md) |
| Pro addon patterns | `pro-addon-development` | [`../../pro-addon-development/SKILL.md`](../../pro-addon-development/SKILL.md) |
| Architecture lift | `improve-codebase-architecture` | [`../../improve-codebase-architecture/SKILL.md`](../../improve-codebase-architecture/SKILL.md) |
| Refactor planning | `request-refactor-plan` | [`../../request-refactor-plan/SKILL.md`](../../request-refactor-plan/SKILL.md) |

## Dispatch Rule

1. If the user asks to build a feature, start with `new-feature`.
2. If the user reports broken behavior, start with `bug-fix`.
3. If the user asks whether a branch is ready, start with `pre-merge-review`.
4. If the work is non-trivial but the exact operational skill is unclear, apply `rigorous-coding-workflow` first.
5. If `code-review-graph` is available, use it before grep for structural questions, then cross-check with live source.

