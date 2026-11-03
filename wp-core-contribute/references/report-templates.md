# Trac report templates

Formats below mirror what committers actually scan on live tickets (observed on #52976,
#26649). Keep the headings — they are load-bearing for skimming.

Both reports are plain text with Trac WikiFormatting. Keep the environment block; a report
without one gets skipped.

---

## Reproduction Report

Answers one question: **does this bug exist on current trunk, with no patch applied?**

```
Reproduction Report

Description
This report validates whether the issue can be reproduced.

Environment
WordPress: 7.1-alpha-<build>
PHP: 8.3.x
Server: <nginx / PHP.wasm / Apache>
Database: <MySQL 8.4.x / WP_SQLite_Driver>
Browser: <if UI involved>
OS: <...>
Theme: <...>
MU Plugins: <None activated>
Plugins:
 - <plugin + version, or None>

Steps to Reproduce
1. ...
2. ...
3. ...

Actual Results
<what happens — the user-visible harm, not the mechanism>

Expected Results
<what should happen>

Supplemental Artifacts
<screenshots, screencast link, or the reproduction snippet>
```

Add `has-screenshots` only if artifacts are genuinely attached.

---

## Patch Testing Report

Answers: **does the patch fix it, and does it leave the legitimate case alone?**

```
Patch Testing Report

Patch Tested: <attachment URL or PR link>

Environment
<same block as above>

Steps taken
1. Reproduce on unpatched trunk — record the failure.
2. Apply the patch.
3. Repeat — record the result.
4. Exercise the NEGATIVE case: confirm the legitimate behaviour still fires.

Expected result
<...>

Result
<Patch is solving the problem. / Patch does not fully solve it because ...>

Unit tests
<targeted test names, then the full file>
 - test_<name>
 - full tests/phpunit/tests/<file>.php: N tests, M assertions, K skipped
 - PHPCS: clean on <paths> / pre-existing unrelated warnings in <paths>

Additional Notes
<edge cases, other call sites the patch does not cover>
```

Step 4 is the one most reports skip, and the one that decides whether a committer trusts it.
A fix that stops the false positive by suppressing the true positive passes step 3 and fails
step 4.

---

## Re-characterisation comment

When the real defect is sharper than the summary. Reframing beats patching on old tickets.

```
<Reproduction Report, as above>

The reported symptom undersells the bug. <the sharper statement>

Chain (<file>):
1. <call site>
2. <what it writes / overwrites>
3. <why that breaks the earlier state>
4. <the user-visible failure, verbatim error string if there is one>

On the attached patches: <why they cannot fix it — wrong layer, JS-only guard on a
server-side defect, breaks with JS off, does not cover other call sites>

Suggested direction for the dev-feedback / 2nd-opinion this needs: <approach>. That is a
behaviour change worth a committer's opinion before anyone writes it, since <blast radius>.

Also noting: filed as <type>/<severity>; <more accurate classification> seems closer given
<consequence>.

Environment: WordPress <version>
```

Keep the suggested direction a *direction*. Proposing an approach invites the decision;
attaching a patch pre-empts it, and pre-empted patches sit unmerged.

---

## Tone

- Plain, factual, no hedging and no padding. Committers skim.
- Credit by handle when carrying someone else's testing onto a ticket.
- Never imply authority you lack: "seems closer", not "should be reclassified".
- No AI attribution anywhere. This posts under the user's name.
