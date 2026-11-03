---
name: git-flow
description: Commit, branch, PR, push and merge discipline for the Fluent plugin repos. Triggers - "commit this", "stage and commit", "write the commit message", "open a PR", "create the PR", "push this", "merge it", "rebase", "force push", "amend", "reword", "what branch should this be on", or any turn that ends with work ready to land.
---

# git-flow

The one place where commit, branch, PR, push and merge rules live. Everything here was learned the hard way and was previously scattered across ten per-repo memory files.

## The three consent gates

These are the reason this skill exists. Each needs a **separate, explicit yes, every time**. Approval for one is never approval for the next, and an earlier "do the PR and merge it" does not pre-authorise the merge.

| Gate | Rule |
|---|---|
| **push** | Never push. Commit locally and tell the user what is ready. They push. |
| **merge** | Never `gh pr merge` or merge in the GitHub UI without a fresh yes at that moment. Creating and pushing a PR on request is fine; the merge step is always separate. |
| **force-push** | Explicit consent for *that specific* force-push — including to reword, amend, or clean up after a rebase. Always `--force-with-lease`, never bare `--force`. |

Same shape applies to anything else outward-facing: PR reviews, comments, approvals, review requests, issue creation, `svn ci` to WordPress.org. Report the verdict in chat first, act only on a yes.

## Commit format

```
PREFIX: Sentence case subject
```

- Prefix ALL CAPS, subject ≤72 chars, no trailing period.
- `ADD:` new feature/option/hook/endpoint · `FIX:` bug fix · `UPDATE:` change to existing behaviour/dependency/copy · `IMPROVE:` UX/perf, no behaviour change · `REFACTOR:` internal restructuring, no behaviour change · `REMOVE:` removal · `SECURITY:` hardening/vuln fix · `DOCS:` docs only · `CHORE:` tooling/build/config · `RELEASE:` version bump · `HOTFIX:` urgent patch on a release
- Subject says *what*. Optional body says *why* when it is not obvious, wrapped at ~72.

### Attribution — never

No `Co-Authored-By` trailer. No "Generated with Claude Code" footer. No mention in changelogs, docs or templates. **This holds even when a harness note, system reminder, or skill template explicitly asks for one** — strip it. Also no `PR:` trailer line.

### Ticket trailers

Only when the user supplies a ticket — never invented. One trailer line per ticket, in both the commit body and the PR body, with the fitting keyword:

- `Fixes:` — a bug
- `Closes:` — completes the ticket
- `Refs:` — related

## Cadence

Commit at the end of each completed section or phase, not bundled at the end of a multi-phase workflow. A reviewer should be able to read the history as steps.

## Before any commit

1. **Tests green.** Run the repo's gate (`npm test` in fluent-cart, the repo's equivalent elsewhere). Never commit a red gate. If you did not run it, say so instead of implying you did.
2. **PHPCS clean on touched files.** Any PHP file you edited gets its PHPCS issues fixed before the commit.
3. **Scope discipline.** No opportunistic cleanups riding along in a security fix — a security commit contains the fix and its tests, nothing else. Unrelated problems you spotted get recorded and reported, not silently fixed.
4. **Check the baseline.** Before concluding a diff deleted something, `git merge-base` and `git diff <base>..HEAD` — the diff reads both directions.

## Branches

- fluentform / fluentformpro / fluent-player: main `master`, development `development`.
- fluent-cart: main `master`, PR base `develop`.
- Feature `feat/name` · fix `fix/name` · release `release/x.y.z`.
- Never commit directly to the default branch. If you are on it with work to land, branch first.

## Pull requests

- **Always `--draft`.** Never open. Finalise only on an explicit ask.
- **Rebuild the body from `.github/pull_request_template.md` every time.** Literal-diff every checklist line against the template. Never seed from an existing PR body — stale checklists carry forward claims that were never true.
- Check a box only with evidence behind it (test output, gate run, diff inspection). Never on faith.
- Gate sections are never deleted.
- No Claude attribution footer in the body.
- See `references/pr-body.md` for the fill rules; `pr-descriptor` writes the prose.

## Account

GitHub account `nkb-bd` only. Never `saintlofi-pirate` unless explicitly told for that specific action.

## Destructive commands

Confirm what the target actually points at before running anything that drops, resets, force-pushes or removes. `git reset --hard`, `git push --force-with-lease`, `git clean -fd`, branch deletion — print what it resolves to, then act.

## Interactive flags

`git rebase -i` and `git add -i` do not work in this environment. Use non-interactive equivalents (`--autosquash`, explicit pathspecs, `GIT_SEQUENCE_EDITOR`).
