# ff-team-skills

FF team Claude Code skill library — orchestrator workflows, review gates, and WordPress-plugin engineering patterns.

**📖 [Skill Guide (GitHub Pages)](https://nkb-bd.github.io/ff-team-skills/)** — illustrated guide to every skill, when to use it, and how they chain.
**🗺 [new-feature illustrated manual](https://nkb-bd.github.io/ff-team-skills/new-feature.html)** — phase rail, tier matrix, call graph, and every check the orchestrator runs ([audit record](new-feature/AUDIT.md)).

## Active skills

### Orchestrators

| Skill | Purpose |
|---|---|
| `new-feature` | End-to-end composite workflow for a new plugin feature. Six phases with approval gates: triage (tier pick) → align (`grill-with-docs`) → plan (`openspec` + `design-an-interface`) → spec → build (`tdd`) → review (`pre-merge-review`) → ship (`pr-descriptor` + `openspec archive`). Ceremony scales with a 5-step tier system (trivial → breaking). |
| `rigorous-coding-workflow` | The principles layer under `new-feature` — plan before executing, subagents for context hygiene, capture lessons, verify before done, push for elegance. Defers operational sequencing to `new-feature`. |

### Plan & align

| Skill | Purpose |
|---|---|
| `grill-with-docs` | Interview that stress-tests a plan against the project's domain model (CONTEXT.md, ADRs), sharpening terminology and updating docs inline as decisions crystallise. |
| `grill-me` | Relentless plan interview until shared understanding — resolves every branch of the decision tree. No doc updates; pure alignment. |
| `design-an-interface` | Generate 3+ radically different interface designs for a module via parallel sub-agents, each with a divergent constraint. Compare, pick, record. |

### Build

| Skill | Purpose |
|---|---|
| `tdd` | Red-green-refactor loop with the "correct seam" check — the failing test must exercise the bug pattern at the real call site. |
| `bug-fix` | Canonical bug workflow. **Fix mode (default):** reproduce → minimise → hypothesise → instrument → fix → regression-test. **Find mode** (`/bug-fix find`): plugin-wide discovery sweep with Finder → Verifier → Feedback loop. |
| `zoom-out` | Higher-level map of an unfamiliar code area when you're lost mid-task. |

### Review & quality

| Skill | Purpose |
|---|---|
| `pre-merge-review` | Canonical pre-merge review. **Full (default):** 7 parallel detectors (accessibility, async-races, ui-to-backend-wiring, permissions, backwards-compat, error-handling-ux, performance + data integrity) plus sequential pattern passes (WP-PHP / JS / Vue / state-machine + adversarial inputs). **Light:** sequential passes only, for tiny diffs. Re-runnable — clears resolved findings. |
| `plugin-audit` | Deep WordPress plugin audit: security, optimization, dead code, UI-to-DB traceability. Evidence-backed findings, severity-ranked remediation backlog. |
| `improve-codebase-architecture` | Find deepening/refactoring opportunities informed by CONTEXT.md domain language and ADRs. The post-merge home for mid-feature refactor itches. |
| `explain-this` | Teach a file/feature/PR to mastery — teaches directly without interrogating the user first; running coverage checklist, five-whys, eli5/eli14/intern levels. Quizzes are opt-in. Ends when everything is taught, grounded in the real code. |

### Ship & setup

| Skill | Purpose |
|---|---|
| `pr-descriptor` | Why-first PR description from git evidence, filling the repo PR template. |
| `agents-onboarding` | Create or refresh `AGENTS.md` onboarding docs for coding agents. |
| `setup-code-review-graph` | Wire the code-review-graph MCP server into a repo (`.mcp.json`, CLAUDE.md block, seed build). |

### Product

| Skill | Purpose |
|---|---|
| `hyperlocal-gtm` | Go-to-market playbook for hyperlocal / city-scoped consumer products in emerging markets. |

## Dispatch — which skill to invoke

| User intent | Skill |
|---|---|
| "Build feature X" / "add capability Y" | `new-feature` |
| "Fix this bug" / "diagnose this" / "X is broken" | `bug-fix` |
| "Find bugs in this plugin" | `bug-fix find` |
| "Review this PR" / "is this ready to merge" | `pre-merge-review` (`light` for single-file diffs) |
| "Deep audit" / quarterly security sweep | `plugin-audit` |
| "Write the PR description" | `pr-descriptor` |
| "Stress-test my plan" | `grill-with-docs` (with docs) / `grill-me` (without) |
| "Design this API" / "design it twice" | `design-an-interface` |
| "Teach me how X works" / "walk me through this PR" | `explain-this` |
| "I'm lost in this code area" | `zoom-out` |
| "Where can the architecture improve" | `improve-codebase-architecture` |

## How the skills chain

```text
                         ┌──────────────────── new-feature ────────────────────┐
  issue / PRD / intent → triage → grill-with-docs → openspec (+ design-an-interface)
                          → spec → tdd → pre-merge-review → pr-descriptor → ship
                                    │
                                    └─ bug surfaces mid-build → bug-fix
                                    └─ lost in the code      → zoom-out
                                    └─ refactor itch         → improve-codebase-architecture (post-merge)
```

`new-feature` decides which of these to invoke and when; invoke the others directly for standalone work.

## Repository layout

```text
ff-team-skills/
├── <skill-name>/            SKILL.md (+ agents/, references/ when applicable)
├── new-feature/             SKILL.md + AUDIT.md + README.html (illustrated manual)
├── docs/                    GitHub Pages skill guide (index.html)
├── shared/scripts/          audit-autharif.sh — weekly drift check for pre-merge-review criteria packs
├── _flows/                  Flow definitions
├── _inactive/               Shelved skills — unused but kept. Move back to root to re-activate.
└── _archived/               Superseded skills (SKILL.md renamed .bak so they don't register):
                             engineering-review + pr-reviewer → pre-merge-review
                             debugger + diagnose → bug-fix
```

All skill directories are self-contained real copies (former matt-skills symlinks were dereferenced) — the repo is clonable on any machine.

## Installation

This repo **is** the live skills directory on the primary machine:

```text
~/.claude/skills → ~/.agents/skills → /Volumes/Projects/Tools/ff-team-skills
```

On a new machine: clone, then symlink `~/.claude/skills` (or `~/.agents/skills`) to the clone. Skills in `_inactive/` and `_archived/` don't register; everything at root does.

## Usage examples

- `Use $new-feature` — full composite workflow; announces a tier, then walks align → plan → spec → build → review → ship with gates between phases.
- `Use $bug-fix` — "submit button does nothing on second click in Save.vue" → reproduce → fix → regression test.
- `Use $bug-fix find` — plugin-wide sweep; only verifier-confirmed issues land in `bug-discovery-report.md`.
- `Use $pre-merge-review` — diff against `origin/dev`; all detectors + pattern passes; re-run after fixes to mark findings `[cleared]`.
- `Use $pre-merge-review light` — single-file diffs.
- `Use $plugin-audit` — produce `plugin-audit.md` from the bundled template.
- `Use $pr-descriptor` — fill the repo PR template from the actual branch diff.
- `Use $explain-this on app/Services/Transfer/TransferService.php` — checklist-driven teaching session.
- `bash shared/scripts/audit-autharif.sh --validate` — confirm pre-merge-review criteria packs still classify the test corpus at ≥80% (skip if the script isn't on this machine).

## Skill conventions

Each skill directory contains:

- `SKILL.md` — behavior contract, workflow, required outputs.
- `agents/openai.yaml` (when applicable) — UI-facing metadata.
- `references/` (optional) — templates, checklists, criteria packs.

## Notes

- `pre-merge-review`'s seven detector packs live in `references/detector-*.md` and are independently editable; output mirrors the autharif GitHub review shape.
- `bug-fix` find-mode calibrates public-trigger findings to `Low-Hardening` unless concrete auth/data impact is proven.
- `new-feature` was audited 2026-06-04 (see `new-feature/AUDIT.md`); all findings fixed — consistent tier rules, explicit phase inputs, evidence-based tier veto, start-of-run openspec archive hygiene.
