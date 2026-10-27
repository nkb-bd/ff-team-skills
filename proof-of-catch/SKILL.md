---
name: proof-of-catch
description: >
  Evidence discipline for any test or guard an agent writes: prove it goes red on the broken code,
  keep it honest (real DB, own fixtures, cleaned up), never weaken it, and carry the red output and
  gate numbers into the commit message. Use whenever a test, lint or CI guard is added or changed,
  and before committing a bug fix or security fix. Triggers: "regression test", "prove the fix",
  "is this test real".
when_to_use: >
  Called by `tdd`, `bug-fix` (Phase 5) and `new-feature` (build) for every new test. Skip for changes that add or touch no test and no guard.
---

# Proof of Catch

**A test you have never seen fail asserts nothing.** The usual failure of AI-written tests is that
they pass whether the code works or not. This skill makes every test prove it can fail, and makes
the commit carry that proof.

## 1. Prove each test, and each guard, goes red

Write the test before the fix where you can (`$tdd`, `bug-fix` Phase 5). A case you saw red before
the fix needs no revert: record that red output. For a case written after the fix, and for each guard
of a multi-guard fix:

1. Break only the thing it covers. Whole fix: `git stash push -- <fix files>`, then `git stash pop`
   (a bare `git stash` also hides the new test). One guard of several: save `git diff > /tmp/fix.patch`,
   remove just that guard, and restore with `git checkout -- <file> && git apply /tmp/fix.patch`, so
   the other guards stay in and cannot cause the red.
2. Run the suite. **It must go red, with a message that names the real problem.** A red caused by a
   fatal, a typo or a missing fixture is not a catch.
3. Restore, and confirm `git diff` shows exactly your change again.
4. Run again. Green.

A case that stays green when its guard is removed covers nothing: fix the case. A guard no case can reach goes under "Needs a human decision";
never delete it.

If a test you just wrote cannot be made to fail, rewrite it or drop it before committing.

## 2. Keep the test honest

- **Never mock the database, the query builder or the models.** The bugs that ship from WordPress
  plugins are SQL and runtime bugs (missing prefix, `ONLY_FULL_GROUP_BY`, wrong discriminator), and
  a mocked-DB test passes on all of them. Mock only outbound third parties (SMTP, payment, remote APIs).
- **Create your own fixtures and delete them in a `finally`, by the exact IDs you created.** Dev
  sites hold real contacts, forms and entries; never clean up by name pattern. Never assert on rows
  you did not create. Give fixtures unique names (`uniqid('t_')`) so repeat and parallel runs do
  not collide. Prefer a dedicated test site or DB when the repo has one.
- **Assert behaviour, not log text or exact SQL strings.**
- No `sleep()`, no real loopback HTTP, no real mail: intercept `wp_mail` with `pre_wp_mail`.
- Clear the plugin's own caches and transients before the suite, so a stale cache cannot hide
  broken code.

## 3. Never game the suite

- **Never weaken, narrow or delete a test to make it pass.** The test is the spec. If it looks
  wrong, say so and leave it.
- **Never commit new red.** A flaky case gets skipped with a written reason, not reported green.
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
without the counts. `$prove-it` re-runs these claims before merge, so a guessed number gets caught.

## 5. Lock the class, not just the instance

For bug and security fixes, not features. A test locks one bug. Ask what class it belongs to
(unprefixed raw SQL, a route with no policy, an entry chunk that exports, a display name in a mail
header) and whether a script can spot it. If it can, add a gate in the same branch:

- **Lint**: a zero-dependency script that exits non-zero on the pattern
  (template: `$security-postmortem` "Guardrail patterns").
- **Inventory gate** for "every X must have Y": the check fails when a new route, entry or setting
  appears without its manifest entry, policy method or test. New code cannot drift in silently.
- **Ratchet budget** when old code already breaks the rule and fixing all of it is out of scope.
  Count the violations over fixed scan paths, store the count in the lint, and fail unless the
  count **equals** the budget, printing the new count. Above it is a new violation; below it means
  lower the budget now, so every fix locks its gain (ready-made: `shared/scripts/ratchet-lint.sh`). A count cannot see one hit swapped for another;
  list the known hits instead when that matters.

Every gate needs:

1. **Its own proof, committed**: a `tests/**/fixtures/bad-*.php` (or `.js`) copied from the real
   pre-fix code, not written to fit the regex. Running the lint on it must exit 1 with the expected
   hits (for a ratchet, scan the real tree plus the fixture, so the count goes over budget). Keep it
   out of the normal scan and the release build (`.distignore`).
2. **A green run on the real tree** (for a ratchet: count equals budget).
3. **Wiring into the gate people already run** (`run-all.sh`, `npm run build`, the pre-push hook) and
   a line in the repo's CLAUDE.md test table. A lint nobody runs catches nothing.
4. **A one-line header** naming the bug or report it came from.

Skip the gate for a one-off bug with no repeatable pattern. When the class is semantic or
cross-file and no script can see it, add a checklist item to `pre-merge-review` instead, and say
so in the commit.

## Done when

- [ ] Every new case was seen red for the right reason, then green
- [ ] Each guard of a multi-guard fix was removed in turn and its case went red
- [ ] No DB mocks; fixtures created, uniquely named and cleaned up in `finally`
- [ ] No test weakened; no new red (base-branch red stated with numbers)
- [ ] Commit body carries the cases, the red output and the gate numbers
- [ ] Bug/security fix: the class has a gate with a committed bad fixture and wiring, or the commit says why not
