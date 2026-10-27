# ff-team-skills

FF team Claude Code skill library — orchestrator workflows, review gates, and WordPress-plugin engineering patterns.

**🏠 [Home (GitHub Pages)](https://nkb-bd.github.io/ff-team-skills/)** — landing page: the library at a glance, grouped by what each skill does.
**📖 [Skill Guide](https://nkb-bd.github.io/ff-team-skills/guide.html)** — illustrated guide to every skill, when to use it, and how they chain.
**📕 [Skill Flow](https://nkb-bd.github.io/ff-team-skills/flow.html)** — the workflow as a readable flow; every skill and term in one line of plain English.
**🧪 [proof-of-catch](https://nkb-bd.github.io/ff-team-skills/guide.html#proof-of-catch)** — tests seen red, evidence in the commit, bug classes locked by a gate.
**🗺 [new-feature illustrated manual](https://nkb-bd.github.io/ff-team-skills/new-feature.html)** — phase rail, tier matrix, call graph, and every check the orchestrator runs ([audit record](new-feature/AUDIT.md)).

## Active skills

### Orchestrators

| Skill | Purpose |
|---|---|
| `new-feature` | End-to-end composite workflow for a new plugin feature. Six phases with approval gates: triage (tier pick) → align (`grill-with-docs`) → plan (`openspec` + `design-an-interface`) → spec → build (`tdd`) → review (`pre-merge-review`) → ship (`pr-descriptor` + `openspec archive`). Ceremony scales with a 5-step tier system (trivial → breaking). |
| `check-feature` | The mirror of `new-feature` — **verifies** an existing, shipped feature end-to-end instead of building one. Walks the feature backward: locate → map the vertical slice (UI → REST → controller → policy → DB → hooks → tests) → verify behavior at runtime (`verify`) → verify correctness & security (`pre-merge-review` scoped to the slice) → verify against original intent (spec drift, success signal, extension seams, test coverage, `doubt-driven-development` refute) → re-runnable Feature Health Report. Read-only: routes fixes to `bug-fix` / `new-feature`. Depth scales with a 4-step tier system (spot → critical). |
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
| `source-driven-development` | Ground every framework claim (WPFluent / Vidstack / hls.js / Gutenberg / WP core) in the vendored source or official docs before asserting it; tag anything unverified `UNVERIFIED:`. `new-feature` calls it in spec + build. |
| `bug-fix` | Canonical bug workflow. **Fix mode (default):** reproduce → minimise → hypothesise → instrument → fix → regression-test. **Find mode** (`/bug-fix find`): plugin-wide discovery sweep with Finder → Verifier → Feedback loop. |
| `zoom-out` | Higher-level map of an unfamiliar code area when you're lost mid-task. |

### Review & quality

| Skill | Purpose |
|---|---|
| `pre-merge-review` | Canonical pre-merge review. **Full (default):** 7 parallel detectors (accessibility, async-races, ui-to-backend-wiring, permissions, backwards-compat, error-handling-ux, performance + data integrity) plus sequential pattern passes (WP-PHP / JS / Vue / state-machine + adversarial inputs). **Light:** sequential passes only, for tiny diffs. Re-runnable — clears resolved findings. |
| `proof-of-catch` | Evidence discipline for every test and guard: seen red on the broken code (each guard of a fix in turn), real DB and self-cleaning fixtures, never weakened, red output and gate numbers in the commit body; each bug class locked by a lint, inventory gate or ratchet budget. Called by `tdd`, `bug-fix` and `new-feature`. |
| `prove-it` | Second pair of eyes for evidence: runs as its own Opus subagent, re-runs each `Proof of catch` claim in a commit (break only what it covers → red for the stated reason → restore → green) and reports confirmed / not reproduced / wrong reason / could not run. Refuses a dirty tree. |
| `doubt-driven-development` | Adversarial fresh-context review for high-stakes / irreversible decisions: CLAIM → EXTRACT → DOUBT → RECONCILE → STOP, spawning a clean-context skeptic to refute. `new-feature` calls it at the Breaking-tier spec gate, in `/build auto`, and on non-trivial review fixes. |
| `plugin-audit` | Deep WordPress plugin audit: security, optimization, dead code, UI-to-DB traceability. Evidence-backed findings, severity-ranked remediation backlog. |
| `improve-codebase-architecture` | Find deepening/refactoring opportunities informed by CONTEXT.md domain language and ADRs. The post-merge home for mid-feature refactor itches. |
| `explain-this` | Teach a file/feature/PR to mastery — teaches directly without interrogating the user first; running coverage checklist, five-whys, eli5/eli14/intern levels. Quizzes are opt-in. Ends when everything is taught, grounded in the real code. |

### Ship & setup

| Skill | Purpose |
|---|---|
| `pr-descriptor` | Why-first PR description from git evidence, filling the repo PR template. |
| `agents-onboarding` | Create or refresh `AGENTS.md` onboarding docs for coding agents. |
| `setup-code-review-graph` | Wire the code-review-graph MCP server into a repo (`.mcp.json`, CLAUDE.md block, seed build). |

## Dispatch — which skill to invoke

| User intent | Skill |
|---|---|
| "Build feature X" / "add capability Y" | `new-feature` |
| "Is feature X healthy" / "check/audit one shipped feature end-to-end" / "does X still work after the refactor" | `check-feature` |
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
| "Is this safe to ship" / "second-guess this decision" | `doubt-driven-development` |
| "Is this test real" / "prove the fix" / "write the commit body" | `proof-of-catch` |
| "Prove it" / "check the proof" / "is this evidence real" | `prove-it` |
| "Verify how this API behaves" / "check the docs before coding" | `source-driven-development` |

## How the skills chain

```text
                         ┌──────────────────── new-feature ────────────────────┐
  issue / PRD / intent → triage → grill-with-docs → openspec (+ design-an-interface)
                          → spec → tdd (+ proof-of-catch) → pre-merge-review (+ prove-it) → pr-descriptor → ship
                                    │  (spec grounds APIs via source-driven-development;
                                    │   Breaking-tier decisions pass doubt-driven-development)
                                    └─ bug surfaces mid-build → bug-fix (+ proof-of-catch)
                                    └─ lost in the code      → zoom-out
                                    └─ unverified API claim  → source-driven-development
                                    └─ irreversible decision → doubt-driven-development
                                    └─ refactor itch         → improve-codebase-architecture (post-merge)

  ┌──────────────────── check-feature (the mirror) ─────────────────────┐
  shipped feature → locate → map slice → verify behavior (verify)
                     → verify correctness (pre-merge-review, scoped)
                     → verify intent (spec drift · seams · coverage · doubt-driven-development)
                     → Feature Health Report ─┬─ defect        → bug-fix
                                              └─ missing capability → new-feature
```

`new-feature` builds a feature forward through approval gates; `check-feature` walks a
shipped one backward through evidence checks and routes any fixes back to `bug-fix` /
`new-feature`. `new-feature` decides which sub-skills to invoke and when; invoke the
others directly for standalone work.

## Repository layout

```text
ff-team-skills/
├── <skill-name>/            SKILL.md (+ agents/, references/ when applicable)
├── new-feature/             SKILL.md + AUDIT.md (illustrated manual lives in docs/)
├── docs/                    GitHub Pages: index.html (landing) · guide.html · flow.html · new-feature.html
├── shared/scripts/          audit-autharif.sh — weekly drift check for pre-merge-review criteria packs
│                            ratchet-lint.sh — ratchet budget lint for proof-of-catch §5
│                            test-gates.sh — self-test for ratchet-lint.sh and hooks/commit-msg
│                            check-repo.sh — frontmatter, $skill refs, docs anchors, gates
│                            eval-prove-it.sh — planted fake proofs; prove-it must catch each
├── shared/hooks/            commit-msg — rejects a commit that changes tests without proof-of-catch evidence
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
- `Use $check-feature on the entry export` — announces a tier, maps the vertical slice, runs the behavior/correctness/intent passes, then writes a re-runnable Feature Health Report with a verdict and a routed fix backlog.
- `Use $bug-fix` — "submit button does nothing on second click in Save.vue" → reproduce → fix → regression test.
- `Use $bug-fix find` — plugin-wide sweep; only verifier-confirmed issues land in `bug-discovery-report.md`.
- `Use $pre-merge-review` — diff against `origin/dev`; all detectors + pattern passes; re-run after fixes to mark findings `[cleared]`.
- `Use $pre-merge-review light` — single-file diffs.
- `Use $plugin-audit` — produce `plugin-audit.md` from the bundled template.
- `Use $pr-descriptor` — fill the repo PR template from the actual branch diff.
- `Use $explain-this on app/Services/Transfer/TransferService.php` — checklist-driven teaching session.
- `Use $prove-it` — re-run the proof-of-catch claims on this branch before merge.
- `bash shared/scripts/ratchet-lint.sh 'whereRaw\(.*fc_' 3 app includes` — fail unless exactly 3 known hits remain; add the bad fixture as a path to prove it fires.
- `cp shared/hooks/commit-msg <plugin>/.git/hooks/ && chmod +x <plugin>/.git/hooks/commit-msg` — block test commits without evidence. `bash shared/scripts/test-gates.sh` self-tests both.
- `bash shared/scripts/check-repo.sh` — frontmatter, skill references, docs anchors and the gates; run it before pushing.
- `bash shared/scripts/eval-prove-it.sh` — after editing `prove-it`: five toy repos with planted proofs (honest, uncovered guard, wrong case count, red for the wrong reason, dirty tree); each must get the right verdict and an untouched tree. Calls `claude -p` once per case; `MODEL=sonnet` to compare.
- `bash shared/scripts/audit-autharif.sh --validate` — confirm pre-merge-review criteria packs still classify the test corpus at ≥80% (skip if the script isn't on this machine).

## Real-life example: one bug, start to finish

Illustrative walkthrough (file names and numbers are examples). Report: *a user who can manage form A
deletes entries of form B by sending B's entry IDs to the bulk-delete endpoint.*

1. **Fix it** — `Use $bug-fix: bulk entry delete accepts entry IDs from other forms.`
   The agent writes a failing test first (`tests/integration/entry-bulk-delete-scope.php`), sees it red,
   then scopes the query: `->where('form_id', $formId)->whereIn('id', $ids)`.
2. **Prove it** — `proof-of-catch` is called from bug-fix Phase 5. The fix also added a capability
   check, so each guard is removed in turn and its case goes red. Fixtures are two forms and four
   entries the test creates and deletes by ID in a `finally`.
3. **Lock the class** — the same bug lives in any handler that takes an ID array without a scope.
   An inventory gate fails when a route reads `entries[]` / `ids[]` without a scope filter; old
   offenders sit under a ratchet budget:
   `bash shared/scripts/ratchet-lint.sh 'whereIn\(.id., \$ids\)' 4 app` (exactly 4 known hits).
4. **Commit** — the body carries the evidence. Forget it and the hook stops you:

   ```text
   ✗ This commit changes tests but has no 'Proof of catch:' or 'Cases added:' section.
   ```

   ```text
   Stop bulk delete removing entries from other forms

   Cases added: 3 (tests/integration/entry-bulk-delete-scope.php)

   Proof of catch (fix reverted):
     INTEGRATION: 1/3 passed, 2 failed
     form B entry survives a delete scoped to form A  expected 2, actual 0
   Each later guard was removed in turn and its case went red: form scope, capability check.

   Gate: smoke 120/120, permissions 214/214, integration 388/388, static green.
   ```

5. **Review** — `Use $pre-merge-review`. It lists the proof as unchecked and recommends `$prove-it`.
6. **Check the proof** — `Use $prove-it`. A fresh Opus subagent replays each claim on a clean tree:

   ```text
   | Commit  | Claim            | Mutation                            | Result         | What we saw                     |
   |---------|------------------|-------------------------------------|----------------|---------------------------------|
   | 4f2c9e1 | whole fix        | non-test changes reversed           | confirmed      | 1/3 passed; "form B entry ..."  |
   | 4f2c9e1 | form scope       | removed EntryService.php:212 only   | confirmed      | 1/3 passed                      |
   | 4f2c9e1 | capability check | removed EntryPolicy.php:48-50 only  | not reproduced | 3/3 passed with the check gone  |
   Verdict: 2 confirmed, 1 not reproduced.
   ```

   The capability check has no case that reaches it. Add one (a subscriber gets 403), commit, and
   re-run `$prove-it` until every row is `confirmed`. Then `Use $pr-descriptor` and open the PR.

Set up once per plugin repo: `cp shared/hooks/commit-msg <plugin>/.git/hooks/ && chmod +x <plugin>/.git/hooks/commit-msg`.

## Skill conventions

Each skill directory contains:

- `SKILL.md` — behavior contract, workflow, required outputs.
- `agents/openai.yaml` (when applicable) — UI-facing metadata.
- `references/` (optional) — templates, checklists, criteria packs.

## Notes

- `pre-merge-review`'s seven detector packs live in `references/detector-*.md` and are independently editable; output mirrors the autharif GitHub review shape.
- `bug-fix` find-mode calibrates public-trigger findings to `Low-Hardening` unless concrete auth/data impact is proven.
- `new-feature` was audited 2026-06-04 (see `new-feature/AUDIT.md`); all findings fixed — consistent tier rules, explicit phase inputs, evidence-based tier veto, start-of-run openspec archive hygiene.
