---
name: pr-descriptor
description: Generate concise, why-first pull request descriptions from git evidence and the merge-gate PR template (Definition of Done + review routing). Use when users ask to draft or update PR text, summarize branch work for reviewers, or fill `pull_request_template.md` with evidence-backed checklists.
---

# PR Descriptor

Generate PR descriptions that explain why the PR is needed first, then summarize what changed at a high level, and fill the merge-gate checklists honestly from evidence.

## Output Contract

- Always include `What does this PR do and why?`.
- Keep output concise: short opening paragraph plus brief supporting bullets only when needed.
- Prioritize problem, intent, and reviewer-relevant impact.
- Avoid file-by-file or commit-by-commit narration; `Key changes` carries the few `file::method` anchors that matter, nothing exhaustive.
- Do not invent issue IDs, tests, screenshots, risks, or outcomes.
- Gate sections (`Merge checklist`, `Changes & review routing`) are never deleted; the omit-empty-sections rule applies only to non-gate sections of repo templates.
- Check a checklist box only when backed by evidence (test output, gate run, diff inspection). Never check on faith.

## Execution Workflow

1. Resolve the PR template:
   - `references/pull_request_template.md` (in this skill's directory) — the single source of truth. The template travels with the skill, so any machine carrying the skill carries the template.
   - If a repo carries its own `.github/pull_request_template.md`, honor it for section layout but still apply the gate fill rules below.
2. Determine base branch.
   - Prefer upstream merge target if it maps to `development`, `master`, or `main`.
   - Otherwise evaluate candidates in this order:
     - `origin/development`, `origin/master`, `origin/main`, `origin/dev`
     - `development`, `master`, `main`, `dev`
   - If only one candidate exists, use it.
   - If multiple candidates exist, compare `git merge-base HEAD <candidate>` and choose the candidate with the most recent merge-base commit.
   - If no candidate exists or selection is ambiguous, ask the user: `Which base branch should I diff against: development, master, main, or dev?`
3. Gather change evidence:
   - `git status --short --branch`
   - Use the base branch resolved in step 2
   - `git diff --name-status <base>...HEAD`
   - `git diff --stat <base>...HEAD`
   - `git log --oneline <base>..HEAD`
   - Inspect changed files as needed to extract intent, testing details, and gate evidence (debug code, schema changes, public-API surface).
4. Derive narrative:
   - Problem or need
   - High-level solution approach
   - Scope and impact boundaries
5. Fill template sections using the section rules.
6. Run final quality gate checks.

## Template Section Rules

### What does this PR do and why?

- This section is required.
- First sentence states the underlying problem.
- Second sentence states the solution approach.
- Optional third sentence states impact/scope boundary.
- Ticket link: include if provided or discoverable from branch name, commits, or conversation context. Ask once if a ticket seems to exist but is unidentified. Omit silently when none exists — not all PRs have tickets. Never invent one.
- Use the closing keyword that fits: `Fixes` (bug), `Closes` (completes the ticket), `Refs` (related work). Full URL when given; raw ID when given.
- `Paired free/pro PR` line: link the counterpart PR when the diff touches a free ↔ pro contract surface (hooks, filters, REST signatures, asset handles pro consumes); otherwise `N/A`. Consistent with the Cross-repo routing tick.

### Key changes

- 3–6 bullets, each anchored to `path/File.php::method()` (or file-level when no single method applies) — what changed there and why it matters to the reviewer.
- Anchors for the important review points, not a file-by-file inventory; diff noise (lockfiles, regenerated baselines) gets at most one combined bullet.

### How to test

- Required. Numbered reproduction/verification steps with expected outcomes.
- UI changes: include before/after screenshots inline here.
- Changes with no runnable flow (docs-only, config): state that in one line instead of fabricating steps.

### Merge checklist

- Always present; never deleted.
- Check a box only with evidence: tests ran (paste-worthy result), PHPCS/PHPStan output, diff grep for debug code/secrets, changelog diff, etc.
- Inapplicable items: annotate `N/A — reason` inline.
- Unverifiable items: leave unchecked with a one-line note on what is missing.
- Any gate bypass (`--no-verify`, new `@phpstan-ignore`/`phpcs:disable`) requires a written reason in `Anything the reviewer should know?`.

### Changes & review routing

- Tick area boxes (PHP, JS/Vue, Tests, Build/config, Docs) from the diff's file types — every area the diff actually touches, no more.
- Tick ⚠ routing categories from diff evidence:
  - auth, payments, uploads, data handling → Security-touching
  - migrations, tables, columns, indexes → Database schema change
  - new/changed hooks, filters, REST endpoints → Public API
  - `docs/adr/` changes → Architecture decision (link the ADR)
  - free ↔ pro contract surface → Cross-product / cross-repo
- When no ⚠ category applies, tick `None of the ⚠ categories — peer review is sufficient`.

### Anything the reviewer should know?

- Include risks, trade-offs, migrations, rollout notes, known limits, and written reasons for any gate bypass.
- Bot `REQUEST CHANGES` override notes are written here by the Dev Lead only; never pre-fill one.
- Omit content (leave section minimal) when there is nothing material to flag.

## Concision Rules

- Keep wording direct, plain, and compact.
- Remove filler and repeated statements.
- Prefer short sentences and concrete nouns/verbs.
- Keep overall output as short as possible without losing key context.

## Quality Gate

Verify before final output:

- Opening section clearly answers why this PR is needed.
- Every checked box is evidence-backed; routing ticks match the diff.
- Ticket linked, or legitimately absent.
- Gate bypasses carry a written reason.
- No fluff, no bloat, no redundant details.

## References

- Template (single source of truth, ships with the skill): `references/pull_request_template.md`
- Skill home: https://github.com/nkb-bd/agent-skills (`pr-descriptor/`)
