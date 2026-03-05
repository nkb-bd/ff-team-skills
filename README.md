# agent-skills

Reusable AI-agent skill packs for WordPress-focused engineering workflows at WPManageNinja.

## Skills in this repository

| Skill | Purpose | Primary Output |
|---|---|---|
| `agents-onboarding` | Create or refresh repository onboarding docs for coding agents, with architecture depth and local validation focus. | `AGENTS.md` + `docs/agent-architecture.md` (or `AGENT_ARCHITECTURE.md`) |
| `php-cs-fixer-style` | Enforce shared PHP-CS-Fixer formatting rules when editing or reviewing PHP code. | Formatter-compliant PHP changes |
| `debugger` | Find real WordPress plugin bugs with a finder/verifier feedback loop that reduces false positives. | `debugger-report.md` |
| `plugin-audit` | Run a deep WordPress plugin audit across security, optimization, and end-to-end traceability. | `plugin-audit.md` |
| `pr-descriptor` | Generate concise, why-first PR descriptions from actual git changes using a project PR template. | Reviewer-ready PR markdown |

## Repository layout

```text
agent-skills/
├── agents-onboarding/
│   ├── SKILL.md
│   ├── agents/openai.yaml
│   └── references/
├── php-cs-fixer-style/
│   ├── SKILL.md
│   ├── agents/openai.yaml
│   └── references/.php-cs-fixer.php
├── debugger/
│   ├── SKILL.md
│   ├── agents/openai.yaml
│   └── references/
├── plugin-audit/
│   ├── SKILL.md
│   ├── agents/openai.yaml
│   └── references/plugin-audit-template.md
└── pr-descriptor/
    ├── SKILL.md
    ├── agents/openai.yaml
    └── references/pull_request_template.default.md
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
- `Use $debugger on this plugin. Run Finder -> Verifier -> Feedback, keep only verifier-confirmed issues, and generate debugger-report.md with per-bug feedback notes.`
- `Use $plugin-audit to audit this plugin and produce plugin-audit.md.`
- `Use $pr-descriptor to draft a concise, why-first PR description from my current branch.`

### Claude examples

- `Use the agents-onboarding workflow from the attached SKILL.md to create or update AGENTS.md and docs/agent-architecture.md.`
- `Apply the php-cs-fixer-style SKILL.md rules to this PHP diff and return a formatter-compliant patch.`
- `Use the debugger SKILL.md workflow to find, verify, and prioritize real plugin bugs in debugger-report.md with per-bug feedback notes in the same file.`
- `Run the plugin-audit SKILL.md workflow and produce plugin-audit.md using the template from references/plugin-audit-template.md.`
- `Use the pr-descriptor SKILL.md workflow to fill my pull request template from the git diff.`

## Skill conventions used here

Each skill directory contains:

- `SKILL.md`: behavior contract, workflow, and required outputs.
- `agents/openai.yaml`: UI-facing metadata (`display_name`, `short_description`, `default_prompt`).
- `references/` (optional): templates, checklists, or config files used by the skill.

## Notes

- `php-cs-fixer-style` prefers a repo-local `.php-cs-fixer.php`; otherwise it falls back to its bundled `references/.php-cs-fixer.php`.
- `plugin-audit` is intentionally evidence-driven and uses a fixed report structure defined in `references/plugin-audit-template.md`.
- `debugger` separates finder and verifier passes, keeps feedback in `debugger-report.md`, includes a WPManageNinja structure map derived from FluentCRM, and calibrates public-trigger findings to `Low-Hardening` unless concrete auth/data impact is proven.
- `pr-descriptor` reads a repo PR template first and falls back to `references/pull_request_template.default.md`.
