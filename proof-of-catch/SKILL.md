---
name: proof-of-catch
description: >
  Evidence discipline for any test or guard an agent writes: prove it goes red on the broken code,
  keep it honest (real DB, own fixtures, cleaned up), never weaken it, and carry the red output and
  gate numbers into the commit message. Use whenever a test, lint or CI guard is added or changed,
  and before committing a bug fix or security fix. Triggers: "add a test", "regression test",
  "prove the fix", "write the commit message", "is this test real".
when_to_use: >
  Called by `tdd`, `bug-fix` (Phase 5) and `new-feature` (build) for every new test, and by
  `security-postmortem` for guards. Skip for changes that add or touch no test and no guard.
---

# Proof of Catch

**A test you have never seen fail asserts nothing.** The usual failure of AI-written tests is that
they pass whether the code works or not. This skill makes every test prove it can fail, and makes
the commit carry that proof.

## 1. Prove each test, and each guard, goes red

Write the test before the fix where you can (`$tdd`, `bug-fix` Phase 5): it is red on the old code
by construction. Tests written after the fix, and every guard, still need the revert below.

For every new case:

1. Break the thing it covers: revert the fix, flip the comparison, delete the `where`, drop the
   capability check. Use `git stash` or a temp copy, never a hand edit you might forget.
2. Run the suite. **It must go red, with a message that names the real problem.** A red caused by a
   fatal, a typo or a missing fixture is not a catch.
3. Restore the code and confirm `git diff` shows only your intended change.
4. Run again. Green.

**A fix with several guards needs each guard proven on its own.** Remove guard 1, see its case go
red, restore; then guard 2; and so on. A case that stays green when its guard is removed is
covering nothing: fix the case or delete the guard.

If a test cannot be made to fail, delete it.

## 2. Keep the test honest

- **Never mock the database, the query builder or the models.** The bugs that ship from WordPress
  plugins are SQL and runtime bugs (missing prefix, `ONLY_FULL_GROUP_BY`, wrong discriminator), and
  a mocked-DB test passes on all of them. Mock only outbound third parties (SMTP, payment, remote APIs).
- **Create your own fixtures and delete them in a `finally`.** Dev sites hold real contacts, forms
  and entries. Never assert on rows you did not create. Give fixtures unique names
  (`uniqid('t_')`) so repeat and parallel runs do not collide.
- **Assert behaviour, not log text or exact SQL strings.**
- No `sleep()`, no real loopback HTTP, no real mail: intercept `wp_mail` with `pre_wp_mail`.
- Clear caches and transients before the suite, so a stale cache cannot hide broken code.

## 3. Never game the suite

- **Never weaken, narrow or delete a test to make it pass.** The test is the spec. If it looks
  wrong, say so and leave it.
- **Never commit a red suite.** A flaky case gets skipped with a written reason, not reported green.
- Red that exists on the base branch too is not yours: say so with numbers ("34 failures, identical
  with and without this change"), do not hide it.
- A bug you find that is out of scope goes in the repo's backlog file (`tests/FIX-PLAN.md` or the
  existing equivalent) with symptom, `file:line` and the parked test. Do not fix it in passing.

## 4. Put the evidence in the commit

Commit body, after the why and the what:

```
Cases added: <n> (<test file>)

Proof of catch (<what was reverted>):
  <suite>: <passed>/<total>, <failed> failed
  <case name>  expected <x>, actual <y>
Each later guard was removed in turn and its case went red: <guard>, <guard>.

Gate: <tier> <n>/<n>, <tier> <n>/<n>, static green.

Deliberately skipped: <behaviour> — <reason>
Needs a human decision: <anything ambiguous>
```

Real numbers from real runs only. Drop a section that is empty; never write "all tests pass"
without the counts.

## 5. Lock the class, not just the instance

A test locks one bug. Ask what class it belongs to (unprefixed raw SQL, a route with no policy, an
entry chunk that exports, Title Case in UI copy, a display name in a mail header) and whether a
machine can spot that class. If it can, add a gate in the same branch so the class cannot return:

- **Lint**: a zero-dependency script (`bash` + `grep`, or `php`/`node` over the tree) that exits
  non-zero on the pattern. Security classes: design it with `$security-postmortem` Phase 4B.
- **Inventory gate** for "every X must have Y": the check fails when a new route, entry or setting
  appears without its manifest entry, policy method or test. New code cannot drift in silently.
- **Ratchet budget** when old code already breaks the rule and fixing all of it is out of scope.
  Count the violations, store the count in the lint, fail if the count is above it, **and fail if it
  is below it** until the budget is lowered in the same commit. The number only goes down, and every
  fix locks its gain.

Every gate needs:

1. **Its own proof, committed**: a `fixtures/bad-*.php` (or `.js`) file holding the pattern; running
   the lint on it must exit 1 with the expected hits. That proof re-runs in CI, unlike a one-off revert.
2. **A green run on the real tree**, or exactly the budget.
3. **Wiring into the gate people already run** (`run-all.sh`, `npm run build`, the pre-push hook) and
   a line in the repo's CLAUDE.md test table. A lint nobody runs catches nothing.
4. **A one-line header** naming the bug or report it came from.

Skip the gate when the class is semantic or cross-file and no script can see it; add a checklist item
to `pre-merge-review` instead, and say so in the commit.

## Done when

- [ ] Every new case was seen red for the right reason, then green
- [ ] Each guard of a multi-guard fix was removed in turn and its case went red
- [ ] No DB mocks; fixtures created, uniquely named and cleaned up in `finally`
- [ ] No test weakened; suite green (or base-branch red stated with numbers)
- [ ] Commit body carries the cases, the red output and the gate numbers
- [ ] The bug class has a gate (lint, inventory or ratchet) with a committed bad fixture and wiring, or the commit says why not
