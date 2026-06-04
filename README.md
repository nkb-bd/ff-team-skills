# agent-skills

Reusable AI-agent skill packs for WordPress-focused engineering workflows at WPManageNinja.

## Skills in this repository

| Skill | Purpose | Primary Output |
|---|---|---|
| `agents-onboarding` | Create or refresh repository onboarding docs for coding agents, with architecture depth and local validation focus. | `AGENTS.md` + `docs/agent-architecture.md` (or `AGENT_ARCHITECTURE.md`) |
| `php-cs-fixer-style` | Enforce shared PHP-CS-Fixer formatting rules when editing or reviewing PHP code. | Formatter-compliant PHP changes |
| `bug-fix` | Single canonical bug-handling skill. **Fix mode (default)**: reproduce → minimise → hypothesise → instrument → fix → regression-test. **Find mode** (`/bug-fix find`): plugin-wide bug-discovery sweep with Finder → Verifier → Feedback loop. Replaces the prior `diagnose` + `debugger` skills. | Fixed code + regression test, or `bug-discovery-report.md` |
| `plugin-audit` | Run a deep WordPress plugin audit across security, optimization, and end-to-end traceability. | `plugin-audit.md` |
| `pr-descriptor` | Generate concise, why-first PR descriptions from actual git changes using a project PR template. | Reviewer-ready PR markdown |
| `pre-merge-review` | Single canonical pre-merge review. **Full mode (default)**: 7 specialised detectors in parallel (accessibility, async-races, ui-to-backend-wiring, permissions-and-capabilities, backwards-compatibility, error-handling-ux, performance-and-data-integrity) **plus** the sequential pattern passes (WP-PHP / JS / Vue / state-machine + adversarial inputs). **Light mode** (`/pre-merge-review light`): only the sequential pattern passes for tiny diffs. Replaces the prior `engineering-review` + `pr-reviewer` skills. Re-runnable to clear resolved findings. | Hosted PR-review markdown in `/Volumes/Workspace/pr-reviews/<repo>/<branch>.md` (fallback `<repo>/.review/<branch>.md`) |
| `skill-creator` | Design and create new reusable Claude Code skills with correct frontmatter, structure, and registration. | `agent-skills/<name>/SKILL.md` |
| `explain-this` | Teach the user to deeply understand a file, feature, or change to mastery — running understanding checklist, five-whys drilling, eli5/eli14/intern levels, restate-first, and `AskUserQuestion` quizzes (shuffled answers, reveal after submit). Inverse of `grill-me`. Doesn't end until every checklist item is verified. | Verified understanding + green checklist |
| `rigorous-coding-workflow` | Disciplined workflow for non-trivial coding work — plan via openspec (synced with `grill-with-docs`), verify before done, capture lessons, push for elegance with calibration. Defers operational sequencing to `new-feature`. | openspec change (via `new-feature`) + `tasks/lessons.md` |
| `new-feature` | End-to-end composite workflow for a new feature in a WP plugin. Six phases with approval gates: align (`grill-with-docs`) → plan (`openspec` + `design-an-interface`) → spec → build (`tdd` + refactor against code-quality rules) → review (`pre-merge-review`) → ship (`pr-descriptor` + `openspec archive`). Picks intensity tier (trivial → breaking) automatically. | Code merged + `openspec` archived + PR opened |
| `setup-code-review-graph` | Wire the `code-review-graph` MCP server into a repo (project-scoped `.mcp.json`, CLAUDE.md graph block, `.gitignore` line, seed build, optional multi-repo registration). | `.mcp.json` + CLAUDE.md block + `.code-review-graph/` cache |
| `pro-addon-development` | WPManageNinja free↔pro patterns: bootstrap contract, filter-tap surface, short-circuit pattern, license-gating, hook naming, REST namespacing, policy/asset reuse, signed-URL CDN integration. Pre-PR checklists for both sides of the pair. | Pro addon code that respects the free contract |
| `cross-plugin-coordination` | Workflow for changing the free↔pro contract: inventory surface, decide additive/backcompat/breaking, paired PRs, joint validation, release-order coordination. | Lockstep free + pro PR pair with cross-references |
| `positioning` | Craft a sharp positioning statement using April Dunford's 5-step "Obviously Awesome" framework — alternatives, attributes, value, segment, category. | One positioning statement + 1-liner + 30s pitch + anti-positioning list |
| `jtbd` | Frame a product or feature using Jobs-to-be-Done. Surfaces the job, the 4 forces of switching (push/pull/anxiety/habit), and feature priority derived from the forces. | One-page JTBD brief |
| `competitor-gap-map` | Build a competitive landscape grid on buyer-mattering axes (not features), identify defensible empty quadrants, stress-test the wedge against moat candidates. | Competitor inventory + 2x2 chart + wedge statement + 3 risks |
| `hyperlocal-gtm` | Go-to-market playbook for hyperlocal / city-scoped consumer products in emerging markets. Wedge geography, supply-first seeding, community channels, trust scaffolding, staged metric ladder. | GTM brief |
| `brand-identity-brief` | Lightweight visual + verbal identity brief — 3 attributes, voice rubric with calibration sentences, naming criteria, visual direction, 3 do/don't rules. | 1-page brief usable to commission a designer |

### Dispatch — which skill to invoke

| User intent | Skill |
|---|---|
| "Build feature X" / "add capability Y" | `new-feature` |
| "Fix this bug" / "diagnose this" / "debug this" / "X is broken" | `bug-fix` |
| "Find bugs in this plugin" / "sweep for bugs" / "audit for bugs" | `bug-fix find` |
| "Review this PR" / "is this ready to merge" / "pre-merge check" | `pre-merge-review` |
| "Deep audit" / quarterly security sweep | `plugin-audit` |
| "Write the PR description" | `pr-descriptor` |
| "How do we plan this rigorously" (principles, not phases) | `rigorous-coding-workflow` |
| "Explain this code/feature" / "teach me how X works" / "walk me through this PR" | `explain-this` |

## Repository layout

```text
agent-skills/
├── agents-onboarding/          SKILL.md + agents/ + references/
├── php-cs-fixer-style/         SKILL.md + agents/ + references/.php-cs-fixer.php
├── bug-fix/                    SKILL.md + references/ (report-template.md, wordpress-plugin-structure-map.md)
├── plugin-audit/               SKILL.md + agents/ + references/plugin-audit-template.md
├── pr-descriptor/              SKILL.md + agents/ + references/pull_request_template.default.md
├── pre-merge-review/           SKILL.md + references/
│                                 ├── README.md
│                                 ├── detector-accessibility.md
│                                 ├── detector-async-races.md
│                                 ├── detector-ui-to-backend-wiring.md
│                                 ├── detector-permissions-and-capabilities.md
│                                 ├── detector-backwards-compatibility.md
│                                 ├── detector-error-handling-ux.md
│                                 ├── detector-performance-and-data-integrity.md
│                                 ├── patterns-wordpress-php.md
│                                 ├── patterns-javascript.md
│                                 ├── patterns-vue.md
│                                 └── test-corpus.tsv
└── (other skills…)

shared/
└── scripts/
    └── audit-autharif.sh       Weekly drift check: confirms every category in
                                autharif's review corpus is still owned by a
                                pre-merge-review detector criteria pack.

_archived/                      Old skills retained for reference. Their
                                SKILL.md files have been renamed to .bak so the
                                directories are no longer registered as skills.
├── engineering-review/         → replaced by pre-merge-review
├── pr-reviewer/                → replaced by pre-merge-review
├── debugger/                   → replaced by bug-fix
└── diagnose/                   → replaced by bug-fix
```

## Installation

### Codex

1. Clone this repository.
2. Install the skills into Codex (for example with your skill installer flow) or copy/link skill folders into `$CODEX_HOME/skills`.
3. Start a Codex session in your target repository.

### Claude

1. Clone this repository.
2. Add the relevant skill files (`SKILL.md` and any needed `references/` files) to your Claude workflow context (for example, Claude Project knowledge or attached files).
3. Instruct Claude to follow the selected `SKILL.md` as the source of truth for the task.

## Usage examples

### Codex examples

- `Use $agents-onboarding to create or update AGENTS.md for this repo.`
- `Use $php-cs-fixer-style to format this PHP change.`
- `Use $bug-fix to fix the bug in resources/admin/Modules/Settings/Save.vue — submit button does nothing on the second click.`
- `Use $bug-fix find on this plugin. Run Finder → Verifier → Feedback, keep only verifier-confirmed issues, and write bug-discovery-report.md with per-bug feedback notes.`
- `Use $plugin-audit to audit this plugin and produce plugin-audit.md.`
- `Use $pr-descriptor to draft a concise, why-first PR description from my current branch.`
- `Use $pre-merge-review on the current branch. Diff against origin/dev. Run all detectors plus the sequential pattern passes; save the report to /Volumes/Workspace/pr-reviews/<repo>/<branch>.md.`
- `Use $pre-merge-review light` — for single-file diffs; skips the parallel detectors.
- `Use $new-feature` — full composite workflow. Asks about intensity tier, then walks align → plan → spec → build → review → ship with gates between phases.
- `bash shared/scripts/audit-autharif.sh --since 7-days-ago` — weekly drift check: harvest autharif's comments and exit non-zero if >5% are unmapped.
- `bash shared/scripts/audit-autharif.sh --validate` — confirm the criteria packs still classify the canonical test corpus at ≥80% accuracy.
- `bash shared/scripts/audit-autharif.sh --diff-with-pr WPManageNinja/fluent-cart 1641` — show local-vs-autharif classification gap on a specific PR.

### Claude examples

- `Use the agents-onboarding workflow from the attached SKILL.md to create or update AGENTS.md and docs/agent-architecture.md.`
- `Apply the php-cs-fixer-style SKILL.md rules to this PHP diff and return a formatter-compliant patch.`
- `Use the bug-fix SKILL.md workflow to fix the reported bug. Default mode = fix. Add 'find' to switch to the discovery sweep.`
- `Run the plugin-audit SKILL.md workflow and produce plugin-audit.md using the template from references/plugin-audit-template.md.`
- `Use the pr-descriptor SKILL.md workflow to fill my pull request template from the git diff.`
- `Use the pre-merge-review SKILL.md workflow on this branch. Run the seven detectors (accessibility, async-races, ui-to-backend-wiring, permissions-and-capabilities, backwards-compatibility, error-handling-ux, performance-and-data-integrity) plus the sequential pattern passes. Save the report to /Volumes/Workspace/pr-reviews/<repo>/<branch>.md.`

## Skill conventions

Each skill directory contains:

- `SKILL.md`: behavior contract, workflow, required outputs.
- `agents/openai.yaml` (when applicable): UI-facing metadata (`display_name`, `short_description`, `default_prompt`).
- `references/` (optional): templates, checklists, criteria packs, or config files used by the skill.

## Notes

- `php-cs-fixer-style` prefers a repo-local `.php-cs-fixer.php`; otherwise it falls back to its bundled `references/.php-cs-fixer.php`.
- `plugin-audit` is intentionally evidence-driven and uses a fixed report structure defined in `references/plugin-audit-template.md`.
- `bug-fix` separates the **fix** loop (single known bug — reproduce → fix → regression test) from the **find** sweep (plugin-wide bug discovery via Finder → Verifier → Feedback). The find mode includes a WPManageNinja structure map at `references/wordpress-plugin-structure-map.md` and calibrates public-trigger findings to `Low-Hardening` unless concrete auth/data impact is proven.
- `pr-descriptor` reads a repo PR template first and falls back to `references/pull_request_template.default.md`.
- `pre-merge-review` runs seven specialised detector passes derived from the autharif review corpus (in the default `full` mode) plus the sequential pattern passes (WP-PHP, JS, Vue, state-machine + adversarial inputs). Each detector's checklist lives in its own `references/detector-*.md` pack and is independently editable. Output mirrors autharif's GitHub review shape (per-line bold-headline inline findings + summary tally). Re-runnable on the same branch to clear resolved findings.
- `shared/scripts/audit-autharif.sh` is the regression detector for `pre-merge-review`. Run weekly to confirm every category autharif catches is still owned by a detector criteria pack; exits non-zero if >5% of new findings are unmapped. Also has `--validate` (against the 30-row test corpus) and `--diff-with-pr` (local-vs-autharif gap analysis on one PR).
- Filenames in `references/` are in plain English so anyone scanning the directory can tell what each pack covers. The short category identifiers (`a11y`, `rbac-alignment`, etc.) stay as machine-readable labels inside the detector NDJSON output — see `pre-merge-review/references/README.md` for the mapping.
