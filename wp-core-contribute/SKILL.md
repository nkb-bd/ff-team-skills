---
name: wp-core-contribute
description: >
  Find and execute a real WordPress core contribution on Trac — across three lanes:
  a code patch, missing unit tests, or a reproduction / patch-testing report. Filters out
  the saturated and the unmergeable (tickets already blocked on a committer, text-processing
  tar pits), verifies the bug against real core source before any writing, and drafts the
  Trac comment or PR without ever posting under the user's account unprompted.
when_to_use: >
  "find something to contribute to WordPress", "find a core ticket", "contribute to WP core",
  "find a good first bug", "is there a ticket I could patch", "write tests for core",
  "test a core patch", "contributor day prep". Also when a ticket URL is pasted and the
  user wants to know whether it is worth their time.
---

# WordPress core contribution

Three lanes. Pick by what the ticket is actually missing, not by what is easiest.

| Lane | Ticket signal | Output |
|---|---|---|
| **Patch** | `needs-patch`, no PR | Code + tests, PR on the GitHub mirror |
| **Tests** | `needs-unit-tests`, or patch exists with no coverage | PHPUnit test-only PR |
| **Testing** | `needs-testing`, `needs-test-info`, or a patch nobody confirmed | Reproduction / Patch Testing Report comment |

The Testing lane is the most under-supplied and the fastest to real value. Do not treat it
as the consolation prize — an unconfirmed patch cannot be committed, so a reproduction report
often unblocks more than a fourth redundant patch.

## 0. Access: Trac blocks automated fetching

`WebFetch` and `curl` both return **nginx 403** on `core.trac.wordpress.org` — every URL,
including plain ticket pages, with full browser headers. This is not rate limiting; do not
retry or burn turns on header tricks.

Use `claude-in-chrome` (invoke the `claude-in-chrome` skill, then batch the tool loads into
ONE `ToolSearch`). The user's Chrome is logged into Trac, so ticket pages render with their
account. `navigate` + `get_page_text` in a `browser_batch` is the working read primitive.

Trac query URLs work fine in the browser and are far better than the canned reports:

```
https://core.trac.wordpress.org/query?status=new&status=reopened&status=assigned
  &keywords=~needs-patch
  &component=Mail&component=Shortcodes
  &col=id&col=summary&col=component&col=keywords&col=changetime&col=type
  &order=changetime&desc=1&max=60
```

Swap `keywords=~needs-unit-tests` or `~needs-testing` for the other two lanes.
`~` means "contains". Repeat `component=` to OR components.

## 1. Do NOT start at the good-first-bugs report

`/tickets/good-first-bugs` looks like the front door and is a trap. Verify this each time
rather than trusting the memory of it, but the standing pattern: **every row already carries
`has-patch`.** Those tickets are blocked on a *committer*, not a contributor — approved PRs
with unit tests and independent test reports, punted across three or four milestones.

A fifth patch on one of those adds nothing. Read the newest comments: if a core committer has
said some version of "I can't shepherd this into core", the bottleneck is not you.

Exception: such a ticket is still a fine **Testing**-lane target if its patch has gone stale
and needs re-confirming against current trunk.

## 2. Filter for tractability

Score each candidate before opening the editor:

**Good signs**
- `needs-patch` with **0 PRs** and a low comment count — genuinely unclaimed
- Failing unit tests already attached but no fix (the hard half is done)
- Reported *by* a core committer (the premise is pre-blessed)
- Touched in the last ~3 months, or in a component the user knows cold
- Narrow, single-function blast radius

**Tar pits — walk away**
- `wpautop`, `wptexturize`, `get_shortcode_regex`, `wp_html_split`, kses: core text
  processing. dd32's standing objection is on the record — "complex nature of text processing
  in WordPress and risk of breaking existing code (in core, plugins, or themes) or
  introducing additional edge-cases of security issues". These do not merge.
- The reporter themselves doubts it is fixable
- 7+ years old, several abandoned patches, zero committer engagement
- `needs-design` / `needs-design-feedback` without a design decision recorded
- Anything whose fix is "change the regex"

**Needs a decision before code**
- `dev-feedback` or `2nd-opinion` still open. Writing a patch first is how tickets end up
  with approved-but-unmerged patches. Contribute the *analysis* that resolves the keyword,
  and say plainly that the implementation is waiting on a committer's call.

Match the component to the user's actual expertise. For a forms/payments plugin developer:
Mail, Login and Registration, Users, REST API, Options/Meta, Shortcodes, Role/Capability.

## 3. Verify against real core source — before writing anything

Never trust the ticket's framing. An 8-year-old summary is often vaguer or plainly weaker
than the real defect, and sharpening it IS the contribution.

There is usually a WordPress install on disk already (check the working tree — a plugin repo
lives inside one). Read the real source:

```bash
grep -m1 "wp_version = " wp-includes/version.php
sed -n "$(grep -n 'function retrieve_password' wp-includes/user.php | cut -d: -f1),+160p" wp-includes/user.php
```

Trace source → sink and name the **user-visible harm**, not the mechanism. Then ask what the
ticket failed to say. Re-characterising a ticket (wrong `type`, understated `severity`,
attached patches that cannot work) is high-value and almost never contested.

**Label your evidence honestly.** A code read is not an execution. Say which you did. If the
claim is cheap to execute, execute it — a report carrying run evidence outranks one carrying
a careful read, and reviewers can tell the difference.

Check the local core version against the ticket's milestone: a fix landing in trunk may
already have shipped, which turns the whole ticket into a `close` recommendation.

## 4. Lane: write the tests

For `needs-unit-tests`, a test-only PR is a complete, welcome contribution.

- Tests live in `tests/phpunit/tests/<area>.php`, class `Tests_<Area>`, methods
  `test_<behaviour>`. Add `@ticket <number>` to each new test.
- Cover **both** directions: the bug case fails before the fix, and the legitimate case
  still passes after it. A test that only pins the bug case lets a fix over-correct.
- Run narrowly, then the whole file — a file-level red is what reviewers will hit:
  `npm run test:php -- tests/phpunit/tests/user.php`
- Report counts (`N tests, M assertions`) and PHPCS state in the comment. Numbers are what
  a committer scans for.

Write the test **fail-first** against unpatched core. A test that passes before the fix is
testing nothing, and this is the single most common way a test-lane contribution is worthless.

## 5. Lane: the testing report

Two distinct documents — do not conflate them:

- **Reproduction Report** — does the bug exist on current trunk? (no patch applied)
- **Patch Testing Report** — does the attached patch fix it, without suppressing the
  legitimate case?

Templates: `references/report-templates.md`. Both need a real environment block; a report
without one gets ignored.

Environments, cheapest first:
- **Playground** — `https://playground.wordpress.net/?php=8.3&wp=trunk&networking=yes`.
  Zero setup, genuine trunk. Cannot apply patches, so Reproduction-only.
- Local `wordpress-develop` Docker — required for the Patch lane.
- An existing local WP install — fine for reading source and for reproducing against a
  released version; state the version, and never claim it is trunk.

Always test the negative case too. "Patch fixes it" is half a report; "and a genuine change
still triggers the notification" is what makes it trustworthy.

## 6. Deliver — and do not publish unprompted

Posting to Trac or opening a PR acts **under the user's own account** on a public,
permanently-indexed tracker. Draft to the scratchpad, show it, and ask.

Ask separately for each surface. A yes to the Trac comment is not a yes to the PR.

Core PRs: branch on the `WordPress/wordpress-develop` GitHub mirror, with the Trac ticket
URL in the description — that is what links PR to ticket. Note the ticket number but do not
change Trac keywords unless asked; keyword changes are a maintainer signal.

Never add Claude attribution to a core PR, commit, or Trac comment. This is the user's
contribution under their name.

## 7. Report back

- Ticket, lane, and the one-line reason it is worth their time
- The verified chain, with `file:line`
- What the ticket got wrong, if anything
- Code-read vs executed, stated explicitly
- What is drafted, where, and what you are asking permission to post
- Candidates rejected and why — stops the next session re-walking the same tar pits
