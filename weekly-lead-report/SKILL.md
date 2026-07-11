---
name: weekly-lead-report
description: Generate a short, precise weekly Dev Lead status report from git history across the Fluent product repos (you + teammates), mapped to the role-dev-lead reporting format (shipped, quality, security, people, planned, risks). Use when the user asks for "weekly report", "lead status report", "what did the team ship this week", or a status update for Arif.
---

# Weekly Lead Report

Produce a one-page weekly status report a Dev Lead sends to the department lead. Source of truth is **git history** across the Fluent product repos for the report window. Keep it short and evidence-backed — no padding, no commit-by-commit narration.

## Output Contract

- One page. Sections in this order: **TL;DR → Shipped → Quality/Testing → Security → People → Planned → Risks/Decisions Needed**.
- Every claim traces to commits in the window. Attribute work to the engineer (`*(Name)*`).
- Group by theme, not by repo or by commit. Collapse a cluster of related commits into one bullet.
- TL;DR is 2-3 sentences: what shipped, the one number that matters, the one open risk.
- Never invent PRs, tickets, test results, or outcomes not present in git.
- Convert raw commit counts into a small People table; don't list every commit.
- Match the tone of `lukman-lead-assesment.md` §7.1 ("Send weekly: shipped, planned, quality, people, risks, decisions needed"). When that assessment file is reachable, cross-reference open items (e.g. coverage deadlines, CI-gate gaps) so the report shows movement against named gaps.

## Repos & Authors

Default product surface (find under the WordPress plugins dir, e.g. `*/wp-content/plugins/`):

- `fluentform`, `fluentformpro`, `fluent-player`, `fluent-player-pro`

Resolve paths dynamically — do not hardcode. Find the git repos:

```bash
find /Volumes/Projects -maxdepth 6 -type d -name ".git" 2>/dev/null \
  | sed 's#/.git##' | grep -iE "/(fluentform|fluentformpro|fluent-player|fluent-player-pro)$"
```

The user is **Lukman Nakib** (`lukman.nakib@gmail.com`). Known teammates: **Dhrupo** (`dhrupo@gmail.com`, commits as both "Dhrupo" and "Dhrupo Nil" — merge them), **Habibur Rahman Delwar / Delwar** (`hrdelwar75@gmail.com`), **Mahmudul Hasan** (`mahmudulhasanarif@gmail.com`). Always **exclude** `Checkpointer`, `dependabot`, and merge commits.

## Execution Workflow

1. **Window.** Default to the last 7 days ending today (`since="7 days ago"`). If the user names a range, use it. State the explicit date window in the header.

2. **Resolve repos** with the find command above. If a default repo is missing locally, note it and continue.

3. **Pull commits per repo** (all branches, no merges, no bots):

   ```bash
   git -C "$REPO" log --all --since="$SINCE" --no-merges \
     --pretty=format:"%ad|%an|%s" --date=short 2>/dev/null \
     | grep -viE "Checkpointer|dependabot"
   ```

   Filter by **commit date**, not author date — rebased/merged old commits carry stale author dates; mention only work actually landed in the window.

4. **Per-author counts** for the People table:

   ```bash
   git -C "$REPO" log --all --since="$SINCE" --no-merges --pretty=format:"%an" 2>/dev/null \
     | grep -viE "Checkpointer|dependabot" | sed 's/Dhrupo Nil/Dhrupo/' | sort | uniq -c | sort -rn
   ```

5. **Classify** each commit cluster by prefix and content:
   - `ADD/FEAT` → Shipped (or Quality if it's tests/coverage/CI).
   - `SECURITY`, CVE bumps, IDOR/injection/sanitization fixes → Security.
   - `TEST`, coverage, PHPStan/PHPCS, E2E, a11y, quality-gate → Quality/Testing.
   - `RELEASE` → Shipped (call out the version).
   - `FIX/REFACTOR/IMPROVE/CHORE/DOCS` → fold into the most relevant theme or omit if minor.

6. **Cross-reference** `lukman-lead-assesment.md` if present in the working dir or a parent — tie the week's work to named gaps/deadlines so progress is visible.

7. **Draft** the report against the Output Contract. Default save path: alongside the assessment as `weekly-report-YYYY-MM-DD.md` (use today's date from the environment context — git/`date` is fine, but the date is already in the session context). Confirm the path with the user before writing if it's ambiguous.

8. **Planned / Risks** come from: in-progress branch names, `TODO`/openspec changes, and unresolved items in the assessment. Don't fabricate — if there's no signal, keep these short and grounded in what the commits imply (e.g. "gates are local pre-push, not server CI").

## Quality Bar

- A reader who never saw the repos should understand what shipped, who carried what, and the one decision needed — in under a minute.
- If two engineers touched the same theme, one bullet, both attributed.
- The TL;DR number should be the most defensible signal available (release shipped, coverage milestone, commit volume) — pick one, don't list three.
