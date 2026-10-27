---
name: prove-it
description: >
  Independently re-run the "Proof of catch" claims in a commit or branch: for each claimed red,
  break only what it covers, run the named test, check it goes red for the stated reason, restore,
  and check green. Returns confirmed / not reproduced / wrong reason / could not run per claim.
  Use for "prove it", "check the proof", "verify the proof of catch", "is this evidence real",
  or before merging a fix whose commits carry proof-of-catch sections.
when_to_use: >
  After a fix lands on a branch and before merge, when its commits claim red/green evidence per
  `proof-of-catch`. Skip for commits with no proof section; there is nothing to check.
context: fork
agent: general-purpose
model: opus
---

# Prove It

The agent that wrote a fix also wrote its proof. This skill is the second pair of eyes: it starts
with no memory of the work and trusts nothing in the commit message until it has seen it happen.

Input: a commit SHA, a range (`main..HEAD`) or a branch. Default: the commits on the current branch
that are not on its base.

## Safety first (stop if any fails)

1. `git status --porcelain` must be empty. Uncommitted work would be mixed into the mutations and
   could be lost on restore: stop and ask the user to commit or stash it.
2. HEAD must be the commit under check or contain it. Record `git rev-parse HEAD`.
3. Find the test command in the repo's own docs (CLAUDE.md, AGENTS.md, README.md, `tests/README.md`).
   Read all of them and use the narrowest documented command that runs just the named suite. If the proof names
   a suite but the repo does not say how to run it, stop and ask; never guess a command that could
   touch a live site's data.

Restore after **every** run with `git checkout -- .` (exact, because the tree started clean). A
reversed delete or rename brings an old path back as untracked: delete only the `??` paths that
appear in the reversed patch, never others. Then confirm `git status --porcelain` is empty again. If it is not, stop at once and report the files; do not
continue to the next claim.

## For each claim

Read every `Proof of catch` / `Proof-of-catch` section and its `Each later guard was removed…` line.
One row per claimed red. Also check `Cases added: <n> (<file>)` against `git show --stat`: the named
test file must be in the commit and hold that many new cases. Only a mismatch gets a row (Result
`mismatch`); a match or no `Cases added:` line gets none.

1. **Mutate only what the claim covers.**
   - Whole fix: reverse the commit's non-test changes. First list its test files (`git show --stat`:
     anything under the repo's test dirs, `*.test.*`, `*.spec.*`, `*Test.php`, any case) and exclude
     each: `git diff <sha>^ <sha> -- . ':!<test path>'… | git apply -R`. Check with `git diff --stat`
     that no test file changed before you run anything.
   - One named guard: remove only that guard's lines, leaving the other guards in. One diff hunk often
     holds several guards, so edit the lines directly rather than reversing a whole hunk. If you
     cannot tell which lines are the guard, mark the claim `could not run` and say why.
   - If the reverse patch no longer applies (later commits moved the code), mark `could not run`.
2. **Run the named test** (the suite or file the claim names, not the whole gate). Capture the
   pass/fail counts and the failure messages.
3. **Judge the red.**
   - `confirmed`: it went red, and a failure message matches the claimed problem.
   - `wrong reason`: red, but from a fatal, a parse error, a missing fixture or a different case.
   - `not reproduced`: still green with the code broken; the test does not cover what it claims.
4. **Restore and run again.** It must be green (or match the stated base-branch red). If not,
   the claim's green half fails: say so in the same row, not a row of its own.

Finally run the gate the commit claims (`Gate: …`) once on the restored tree and compare the counts.
Compare passed and failed; report skipped as seen. A claim with no counts ("10 tiers passed") is
checked at the level it states.

## Hard limits

- Never commit, push, amend, edit tests, or change the fix. Mutations are temporary and local.
- Never run commands the repo does not document, and never run against a site the repo marks as
  production.
- Report what you saw. "Could not run" is a valid result; a guessed "confirmed" is not.

## Report (returned to the main conversation)

```
prove-it: <range> at <HEAD sha>   tree clean before and after: yes|NO

| Commit | Claim | Mutation | Result | What we saw |
|---|---|---|---|---|
| abc123 | whole fix | non-test changes reversed | confirmed | 2/11 passed; "victim contact is not linked" |
| abc123 | click relink guard | removed app/Services/X.php:48-50 only | not reproduced | 11/11 passed with the guard removed |
| abc123 | Cases added: 9 | git show --stat | mismatch | tests/x.php not in the commit |

Gate claimed: smoke 258/258, integration 609/609   Gate seen: smoke 258/258, integration 607/609
Verdict: <n> confirmed, <n> not reproduced, <n> wrong reason, <n> could not run, <n> cases mismatch.
```

Write the Result column and the Verdict line exactly as above, plain text, no bold: other tools read them.
The four red counts add up to the red-claim rows; `cases mismatch` counts the mismatch rows.

Lead with any `not reproduced` or `wrong reason` row: those commits claim evidence they do not have.
