---
name: release-plan
description: Generate a monthly release plan (8-section playbook format) for a Fluent product free+pro pair from a short list of items, owners, and rough sizes. Resolves the repo pair and current version, gathers git+PR evidence to classify merged vs in-flight, sizes each item S/M/L, and writes docs/release-plans/<product>-<version>-<month>.md. Optional opt-in phases: FluentBoards sync (create board/column/cards, map FB refs, split merged vs In Review) and a styled HTML preview. Use when the user says "release plan", "monthly plan", "plan the release", "draft the plan for <version>", or pastes a list of release items with owners. Complements (does not replace) the `release` skill, which does the version bump / changelog / tag / zip.
---

# release-plan

Turn a rough list of release items into a filed monthly release plan for a Fluent free+pro pair. The user supplies items + owners + rough time/size (freeform or a table, loosely split Free/Pro); this skill does the rest.

## Golden rules (the playbook spine — never violate)

- **Committed = named owner + a date.** No owner or no date → it is NOT committed; it goes to Deferred or is flagged. Owner is a person, never "the team".
- **The engineer sets their own date.** If the user hasn't given one, leave `` `[date]` `` and flag it — do not invent dates.
- **Deferred is never empty** on a full plan. If nothing was cut, say why, or pull a real backlog item in.
- **Every change after filing gets a §8 change-log row** (what / why / what it displaced).
- **Outcome level, 3–8 committed items.** Consolidate tickets into outcomes; tickets live in FluentBoards.
- **Free and Pro ship paired, lockstep.** Separate their scope within §2.
- **Confirm before writing.** Draft the full plan, show it, get a yes, then write the file. Same gate before ANY board write.

## Authoritative sources (read before drafting)

- **Template:** `template.md` in this skill = the canonical `template-monthly-release-plan.md`. Match its section order, headers, and columns exactly.
- **Core playbook:** `/Volumes/Projects/Tools/work-flow/engineering-playbook.md` — §7.0 (monthly plan), §7.1 (cadence), §7.2 (versioning), §7.3 (release calendar), §2.4 (free+pro cross-repo). The rules below are lifted from it; if it and this file ever disagree, the playbook wins.
- **Team adaptation:** `/Volumes/Projects/Tools/work-flow/ff-team-adaptation-doc.md` — the `[ADAPT]` decisions (release calendar, how the team produces the plan).

## Sizing scale

**Size** column = **S / M / L** (per the canonical template §2). Header is "Size", not "Points". The last column header is "FluentBoards ref".

## Filing, posting & calendar (playbook §7)

- **Due the last Friday of the prior month**, sent to Arif (Engineering Dept Lead). **Visible across teams** (product, marketing, other teams read it) — it is *not* dev-only. The plugin-repo `docs/release-plans/` file is the working copy; the filed copy is shared where Arif + other teams can read it (the team's FC / FluentCommunity engineering space).
- **Release date comes from the team release calendar**, not invented. From the adaptation doc: **Fluent Player = 3rd Tuesday**, **Fluent Forms = 2nd Tuesday** (both Tuesdays; avoid Mon and Thu/Fri). Flag any deviation in the header.
- **Cadence:** released products ship **≥1/month**; in-development products file milestone dates instead; FluentCart files a month of weekly targets.
- **Versioning (§7.2):** MINOR is the default monthly bump; PATCH for fix-only. **Free and Pro tag the same version** for a release (§2.4) — free repo leads.

## Inputs

Accept either form (auto-detect; honor a table if given, else parse freeform):
- **Freeform dump** — items/owners/times however written, including pasted teammate Slack updates.
- **Structured** — `item | owner | free/pro | size` rows.

Always needed (ask only if genuinely missing — see Phase 2 gate): product, target version, release date, and which items are Free vs Pro.

## Product registry

Read `reference/products.json` for `{ plugins_root_hint, free_dir, pro_dir, board_project_id, board_url, base_branch }` per product. Resolve the plugins root from the current working directory (walk up to the `wp-content/plugins` folder) rather than trusting absolute paths — the registry stores **folder names**, not machine paths. If the product isn't in the registry, ask for its free/pro folder names + board URL and offer to add it.

## Phases

### 0 — Resolve context
- Identify the product; resolve `free_dir` and `pro_dir` under the current plugins root.
- Current released version: readme `Stable tag` and the plugin-header `Version:` (they should match; note if not).
- Base branch (default `dev`); last release **tag** for the "since" window.

### 1 — Gather evidence
- `git log <last-release-tag>..HEAD --pretty=format:"%h|%an|%s"` on the free repo (and pro if separate) to see what actually merged.
- Open PRs: `gh pr list --state open --limit 100 --json number,title,author,isDraft`.
- Classify each user-supplied item: **merged** (in git log) vs **in-flight/unmerged** (only a PR, or reported but not landed). This drives Committed vs Deferred/In-Review.
- Prefer the graph/`gh`/`git` evidence over assumptions. Do not claim an item merged unless you see it.

### 2 — Draft the plan
- Use `template.md`. Fill all 8 sections at outcome level.
- Points 1/2/3/5. Owner + `` `[date]` `` per committed row (fill dates only if the user gave them).
- §3 Modernization slice: name the module(s), or state the reason there's none this month.
- §4 Deferred: at least one real item.
- §7: if no prior plan, write "First formal plan cycle" + current in-flight state.
- **Missing-must-have gate:** if version, release date, or Free/Pro split can't be inferred, ask a single batched question. Otherwise proceed.
- Show the full draft. **Wait for approval.**

### 3 — Write
- On approval, write `<free_dir>/docs/release-plans/<product>-<version>-<month>-<year>.md` (e.g. `fluent-player-1.3.0-july-2026.md`).
- Seed §8 with the "Plan filed" row (today's date).

### 4 — FluentBoards sync (opt-in; only if the user asks or provides a board URL)
- Read `reference/fluentboards-api.md` for the exact working calls, auth, and gotchas.
- Ensure the board exists (create if missing). Then either **pull from existing backlog cards** (map plan items to them and reuse their IDs) or **create fresh cards** — ask which.
- Create a `<version>` column; create cards for items lacking one; move merged roadmap cards in; put unmerged items in an `In Review` column.
- Write the resulting task IDs back into the plan's FB-ref column, and add §8 rows for every board change.

### 5 — HTML preview (opt-in)
- Run `scripts/render-plan-html.mjs <plan.md>`; it writes a styled HTML file and prints its path. Then `open` it.

## After any post-file change
Add a §8 change-log row. Keep the plan, the board, and (if touched) the readmes telling the same story.

## Supporting files
- `template.md` — the 8-section skeleton.
- `reference/products.json` — product → repo/board registry.
- `reference/fluentboards-api.md` — board REST cookbook (hard-won endpoints + gotchas).
- `scripts/render-plan-html.mjs` — markdown → styled HTML.
