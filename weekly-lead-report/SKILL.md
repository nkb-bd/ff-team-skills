---
name: weekly-lead-report
description: Generate a short, precise weekly Dev Lead status report for Arif, assembled from git history + merged PRs + release tags across the Fluent product repos (you + teammates), mapped to the official template-weekly-dev-lead-report.md (shipped, blocked/at-risk, decisions, people, worries, metrics). Use when the user asks for "weekly report", "lead status report", "what did the team ship this week", or a status update for Arif.
---

# Weekly Lead Report

Produce the one-page weekly status report a Dev Lead sends to **Arif**. The report is *assembled from evidence collected across the window* — git history, merged PRs, release tags, and metrics queries — not reconstructed from memory. Fill the official template exactly. Keep it short, outcome-focused, and evidence-backed — no padding, no commit-by-commit narration.

**Golden rule — outcomes, not activity.**
- Bad: "Merged 14 PRs" / "Team worked on the release and various bug fixes."
- Good: "Shipped Fluent Player 1.3.0 (free + pro) Tuesday — page-builder support (Elementor/Divi/Bricks) + private signed-token media. Plan item 2, on time."
Every Section 1 bullet is measured against the release plan.

## Output Contract

Fill `template-weekly-dev-lead-report.md` (in this skill dir). Sections in this exact order — **all required**:

1. **What shipped this week** — 3–5 bullets max. Outcomes vs plan. Releases (product + version), features merged, modernization slices.
2. **What's blocked or at risk** — each item: *what, why, what would unblock it*. If nothing: "Nothing significant."
3. **Decisions I need from Arif** — per item, four lines: **Decision** (1 sentence) · **Context** (2–3 sentences) · **My recommendation** · **Deadline** (when it becomes urgent). If none: "None this week."
4. **Team and people** — one line per signal from 1:1s (growing fast, overloaded, gone quiet). If nothing: "Steady."
5. **What I'm worried about** — forward-looking concerns tracked but not yet acted on.
6. **Key metrics** — one line each, **with trend vs last week**. Never blank a metric — if unmeasured, write the honest labeled estimate ("~20h, estimated") or "not measured yet" (itself a signal).

**One-time (first report only):** append the *state of the team* block — coverage baseline per repo, framework version per product, modernization status, WP.org deploy-automation status, whether weekly 1:1s are running (Y/N per engineer).

Rules that hold across all sections:
- Attribute work to the engineer (`*(Name)*`). Group by theme, not by repo or commit — collapse a cluster into one bullet.
- Never invent PRs, tickets, test results, releases, or outcomes not present in the evidence.
- **Slip rule (do not violate):** a release at risk of missing its date goes to Arif *directly, before the day* — never first surfaced in Friday's report. The report *records* a known-at-risk item; it never *substitutes* for the direct heads-up.
- **Decision test:** an item belongs in Section 3 only if (a) Arif's answer would change what you do AND (b) waiting costs time. No recommendation written = not ready to escalate.

## Repos & Authors

Default product surface (find under the WordPress plugins dir, e.g. `*/wp-content/plugins/`):

- `fluentform`, `fluentformpro`, `fluent-player`, `fluent-player-pro`

Resolve paths dynamically — do not hardcode:

```bash
find /Volumes/Projects -maxdepth 6 -type d -name ".git" 2>/dev/null \
  | sed 's#/.git##' | grep -iE "/(fluentform|fluentformpro|fluent-player|fluent-player-pro)$"
```

The user is **Lukman Nakib** (`lukman.nakib@gmail.com`). Known teammates: **Dhrupo** (`dhrupo@gmail.com`, commits as both "Dhrupo" and "Dhrupo Nil" — merge them), **Habibur Rahman Delwar / Delwar** (`hrdelwar75@gmail.com`), **Mahmudul Hasan** (`mahmudulhasanarif@gmail.com`). Always **exclude** `Checkpointer`, `dependabot`, and merge commits.

## Evidence Collection

Assemble from three sources — git, GitHub PRs, and release tags. Git is the always-available floor; `gh` enriches when authenticated.

1. **Window.** Default: current week Mon–Fri (or last 7 days ending today). If the user names a range, use it. State the explicit window in the header, dated to the Friday.

2. **Resolve repos** with the find command above. If a default repo is missing locally, note it and continue.

3. **Shipped — merged PRs per repo** (preferred outcome signal; skip gracefully if `gh` unauthenticated). **The GitHub slug is NOT the local dir name — use this exact mapping** (local `fluent-player` → GitHub `fluent-player-dev`; FluentForm repos live under the `fluentform` org, not `WPManageNinja`):

   | Local dir | GitHub `--repo` slug |
   |---|---|
   | `fluent-player` | `WPManageNinja/fluent-player-dev` |
   | `fluent-player-pro` | `WPManageNinja/fluent-player-pro` |
   | `fluentform` | `fluentform/fluentform` |
   | `fluentformpro` | `fluentform/fluentformpro` |
   | (related) community | `WPManageNinja/fluent-community` |
   | (related) conversational | `WPManageNinja/fluent-conversational-js` |

   Confirm the real slug from each repo's `git remote -v` if unsure, then:

   ```bash
   gh pr list --repo <org>/<slug> --state merged \
     --search "merged:$SINCE..$UNTIL" --limit 50 --json number,title,mergedAt,author 2>/dev/null
   ```
   Empty PR results with a valid slug = genuinely no PRs; empty with the wrong slug = a false "nothing shipped". Never conclude "this repo pushes direct / has no PRs" without confirming the slug first.

4. **Shipped — release tags** (every tag = one Section-1 bullet, product + version):

   ```bash
   git -C "$REPO" tag --sort=-creatordate --format='%(creatordate:short) %(refname:short)' | head
   ```

5. **Commits per repo** (evidence floor — no merges, no bots; filter by **commit date**, not author date):

   **Source of truth for "landed" = `origin/dev`, not `--all`.** These Fluent repos integrate on **`dev`** even though the default/PR base is often **`master`** — so a `gh pr list --state merged` against the default base can read **0 while 30+ commits landed on `dev`** (false "nothing shipped"). Always run the `origin/dev` query below and treat it as the shipped-to-integration signal; use `--all` only for the activity/People floor (it sweeps unmerged WIP branches and overstates Section 1). Separately, **tags = shipped-to-users**; keep "merged to dev" and "tagged/released" as distinct lines in Section 1 — work on `dev` but untagged is *not yet released*.

   ```bash
   # landed on dev (source of truth for Section 1):
   git -C "$REPO" log origin/dev --since="$SINCE" --until="$UNTIL" --no-merges \
     --pretty=format:"%ad|%an|%s" --date=short 2>/dev/null | grep -viE "Checkpointer|dependabot"
   # activity floor only (all branches — overstates; do NOT use as "shipped"):
   git -C "$REPO" log --all --since="$SINCE" --until="$UNTIL" --no-merges \
     --pretty=format:"%ad|%an|%s" --date=short 2>/dev/null | grep -viE "Checkpointer|dependabot"
   ```

6. **Per-author load** (supports Section 4 + the People evidence aid; note `--all` inflates via cross-branch duplicates — label counts "~" / relative):

   ```bash
   git -C "$REPO" log --all --since="$SINCE" --until="$UNTIL" --no-merges --pretty=format:"%an" 2>/dev/null \
     | grep -viE "Checkpointer|dependabot" | sed 's/Dhrupo Nil/Dhrupo/' | sort | uniq -c | sort -rn
   ```

## Key Metrics queries (Section 6)

Same queries every week — script once, reuse. Record what you can; **label estimates, never blank**.

| Metric | Source |
|---|---|
| Releases shipped vs planned this month | release plan vs `git tag` pushed |
| Open PR count / median age | `gh pr list --repo WPManageNinja/<repo> --state open --json createdAt,title` per repo |
| Review turnaround (median) | `gh pr list --state merged --search "merged:>=$SINCE" --json createdAt,reviews` |
| Bot REQUEST CHANGES overrides | your override notes in PRs this week |
| Coverage per repo + delta | CI coverage report; record weekly, delta is automatic |
| Modernization % (modules done / total) | modernization plan |
| Open P0/P1s | FluentBoards priority filter |

If `gh` is unauthenticated or a source is unavailable, say so in the metric line ("not measured yet") rather than omitting it.

## Drafting

1. **Classify** each commit/PR cluster into the template sections:
   - `RELEASE` / tag → Section 1 (call out version).
   - `ADD/FEAT`, merged feature PRs, modernization slices → Section 1.
   - `SECURITY`, CVE bumps, IDOR/injection/sanitization → Section 1 if shipped in a release; always name it (security is a headline outcome).
   - `TEST`, coverage, PHPStan/PHPCS, E2E, a11y, quality-gate → Section 1 (as a quality outcome) and/or Section 6 (coverage metric).
   - `FIX/REFACTOR/IMPROVE/CHORE/DOCS` → fold into the most relevant outcome bullet or omit if minor.
2. **Blocked / at-risk / decisions / worries** come from: the **running note** (default `/Volumes/Projects/work/weekly-running-note.md` — the `BLOCK`/`DECISION`/`PEOPLE`/`WORRY`/`METRIC`-tagged lines for the window are the primary source; git/PR evidence only supplements it), stale open PRs (2+ days), in-progress release branches vs their dates, and `TODO`/openspec changes. Don't fabricate — if there's no signal, use the "Nothing significant." / "None this week." / "Steady." defaults.
3. **Cross-reference** `lukman-lead-assesment.md` if reachable in the working dir or a parent — tie the week's work to named gaps/deadlines (coverage targets, CI-gate promotion) so the report shows movement.
4. **Save.** Write `weekly-report-YYYY-<monthname>-DD.md` (Friday's date, month spelled out lowercase — e.g. `weekly-report-2026-july-31.md`) to **both** locations, identical copies: (a) `/Volumes/Projects/Tools/work-flow/weekly-report/`, and (b) the plugin repo dir the report was generated from. If either dir is missing, create it. Keep the report short — trimmed bullets, one line each where possible.
5. **Final re-read (required):** ask "what would Arif ask after reading this?" and answer it inside the report before saving.

## Quality Bar

- A reader who never saw the repos understands what shipped, who carried what, what's at risk, and the one decision needed — in under a minute.
- Section 1 is outcomes vs plan, max 5 bullets — never an activity dump.
- If two engineers touched the same theme, one bullet, both attributed.
- Every metric line carries a trend or an honest "not measured yet" — no blanks.
- Nothing in the report is the first time Arif hears about a slipping release.
