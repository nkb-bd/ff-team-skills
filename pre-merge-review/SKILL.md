---
name: pre-merge-review
description: >
  Pre-merge review for a branch — runs the FULL multi-detector + sequential-pass review
  by default. Catches accessibility, async races, permission/capability drift, backwards-compat
  regressions, error-state UX, performance + data integrity, and UI-to-backend wiring gaps.
  Lighter mode available with `light`. Writes a single re-runnable report and can be invoked
  repeatedly on the same branch to track which findings have been resolved.
when_to_use: >
  Before pushing a branch. After implementing a feature or bug fix. When the user asks
  "review this PR", "is this ready to merge", "pre-merge check", "audit the branch",
  "deep review", or "check before merge".
context: fork
allowed-tools: Read Bash(git *) Bash(grep *) Bash(rg *) Bash(find *)
effort: high
---

# Pre-Merge Review

The single canonical pre-merge gate. This skill replaces the previous `engineering-review` (sequential 9-pass) and `pr-reviewer` (parallel multi-detector) skills, which were merged into one on 2026-05-21.

Two modes:

- **Full (default)** — runs the seven specialised detectors in parallel **and** the sequential pattern passes (WordPress-PHP, JavaScript, Vue, backwards-compat, state-machine + adversarial inputs). Slow but thorough. Use for any non-trivial PR.
- **Light (`/pre-merge-review light`)** — runs only the sequential pattern passes. Faster sanity sweep. Use for tiny single-file diffs where the heavy detector fan-out is overkill.

## Live branch context

- **Diff stat:** !`git diff origin/dev...HEAD --stat 2>/dev/null || git diff HEAD~1...HEAD --stat`
- **Commits:** !`git log origin/dev...HEAD --oneline 2>/dev/null || git log HEAD~3..HEAD --oneline`
- **Changed files:** !`git diff origin/dev...HEAD --name-only 2>/dev/null || git diff HEAD~1..HEAD --name-only`

---

## Output location and re-run behaviour

**Output path** (in priority order):
1. `/Volumes/Workspace/pr-reviews/<repo>/<branch-slug>.md` — if `/Volumes/Workspace` exists.
2. `<repo-root>/.review/<branch-slug>.md` — fallback when hosted-review dir is not mounted.
3. `openspec/changes/<branch-slug>/PRE-MERGE-REVIEW.md` — for branches whose work is tracked in an openspec change.

Do **not** create `/Volumes/Workspace/pr-reviews/` if it is missing — that signals the machine isn't configured for hosted reviews and the fallback is correct.

**Re-run mode** — if a report already exists at the output path:
1. Read existing findings under `## Inline findings`.
2. Re-run detectors / passes **against the full branch diff (`origin/dev...HEAD`), never only the commits since the prior report**. Delta-only scrutiny is how findings on earlier commits survive every re-run (corpus: fluentform#1011 — an N+1 introduced mid-branch was cleared in run 1's blind spot and never revisited because runs 2–3 reviewed only new commits). The prior report is for *comparing* findings, not for *narrowing* scope. For each new finding, compare against priors on `(file, line, headline)`:
   - **Match:** keep (still open).
   - **Prior exists, no match now:** mark `[cleared]` in the new report.
   - **New finding, no prior match:** add fresh.
3. Move the existing report to `<branch>-<short-sha>.md` (use `git rev-parse --short HEAD`).
4. Write the new report.
5. Append a `## Re-run history` section listing each run with sha, timestamp, and counts.

---

## Step 0 — Pre-flight

### 0a. Identify PR type
From the diff, classify as one of: `Feature | Bug Fix | Refactor | Schema | JS | Vue | Mixed`. The PR type decides which pattern packs load in the sequential pass; **all detectors run regardless of PR type** (modulo file-type gating below).

### 0b. Project glossary awareness
If `CONTEXT.md` or `CONTEXT-MAP.md` exists at repo root, read it once. Findings should use project vocabulary in headlines, not generic best-practice labels. If the glossary defines a noun (`Submission`, `Entry`, `Conversation`, `PmproImport`), the headline uses that noun.

### 0c. code-review-graph context, when available

If the repo has `code-review-graph` wired (`.mcp.json` mentions `code-review-graph`, `.code-review-graph/` exists, or MCP tools such as `query_graph`, `get_impact_radius`, `detect_changes`, `get_review_context`, or `semantic_search_nodes` are callable), use it before grep for structural review context:

| Question | Prefer graph tool | Cross-check |
|---|---|---|
| What changed and what flows are affected? | `detect_changes` or `get_review_context` | `git diff origin/dev...HEAD --stat` and changed-file list |
| Who calls/imports the changed symbol? | `query_graph` with `callers_of` / `importers_of` | targeted `rg` for the symbol |
| What tests cover the changed symbol? | `query_graph tests_for <symbol>` or equivalent | repo test names and changed tests |
| What is the impact radius? | `get_impact_radius` | detector findings and manual call-path reads |

Use graph output to prioritize detector attention, not to replace reading the diff. Treat graph data as potentially stale; if it conflicts with `git diff` or targeted `rg`, trust the live source and mention the mismatch in the report notes.

If graph is not available, say nothing special and continue with git diff plus `rg`/`find`.

### 0d. Map changed files to detectors

| Extension | Detectors that run |
|---|---|
| `.vue` | accessibility, async-races, error-handling-ux, ui-to-backend-wiring, backwards-compatibility |
| `.jsx` / `.tsx` | accessibility, async-races, error-handling-ux, ui-to-backend-wiring, backwards-compatibility |
| `.js` / `.ts` | async-races, error-handling-ux, ui-to-backend-wiring, backwards-compatibility |
| `.php` (Controllers, Policies) | permissions-and-capabilities, ui-to-backend-wiring, backwards-compatibility, performance-and-data-integrity |
| `.php` (Services, Models, Views) | ui-to-backend-wiring, backwards-compatibility, performance-and-data-integrity |
| `.scss` / `.css` | accessibility (focus-visible / outline-removal only) |
| `migrations/*` | backwards-compatibility, performance-and-data-integrity |

**Always run** `ui-to-backend-wiring` and `backwards-compatibility` regardless of file types — they are PR-shape checks, not file-type checks.

### 0e. WordPress plugin detection

Check whether the repo is a WordPress plugin (cheapest signals first):

1. A `*.php` file at repo root has `Plugin Name:` in its top docblock → **WP plugin**.
2. `app/Http/Routes/api.php` exists → **WP plugin** (WPManageNinja shape).
3. `readme.txt` at repo root starts with `=== ... ===` and has `Stable tag:` → **WP plugin**.
4. None of the above → not a WP plugin; skip the brief and hooks-diff sections of the report.

When WP-detected, **also run the WP static-check suite** before the detector fan-out:

| Tool | Invocation | Outcome |
|---|---|---|
| WP Plugin Check (official) | `wp plugin check <slug>` | Failures → `Blocking` findings |
| PHPCS / WordPress-Extra | `phpcs --standard=WordPress-Extra --filter=GitModified` | New errors in changed lines → `High` |
| PHPStan + WP stubs | `phpstan analyse --level=5 <changed .php>` | New errors → `Medium` |
| `wp-cli i18n make-pot` | `wp i18n make-pot . languages/<slug>.pot --dry-run` | Diff with committed `.pot` if strings added → `Medium` |
| `readme.txt` parser | parse `readme.txt`; check `Stable tag:` matches `Version:` header | Mismatch → `High` |

If a tool isn't installed, log `[pre-merge-review:tool-missing] <tool>` to stderr and skip — don't fail the run. Reviewers may run them manually.

See `references/wp-review-brief-template.md` for the full WP-specific brief template + hooks-diff classification rules + "Look here first" ranking weights.

### 0f. Announce the plan
Print one line so the user has a cheap interrupt point:

```
[pre-merge-review:plan] 14 changed files (8 vue, 4 php, 2 scss). WP plugin: yes (plugin-slug).
                        Mode: full. Detectors: accessibility, async-races, error-handling-ux,
                        ui-to-backend-wiring, backwards-compatibility, permissions-and-capabilities,
                        performance-and-data-integrity. Estimated: ~2 min parallel / ~8 min sequential.
```

---

## Step 1 — Parallel detectors (skip in light mode)

If the runtime can spawn sub-agents (Claude Code Agent tool), spawn one per detector in **parallel**. Each sub-agent receives:

```yaml
detector: <one of: accessibility | async-races | ui-to-backend-wiring | permissions-and-capabilities | backwards-compatibility | error-handling-ux | performance-and-data-integrity>
diff_path: <abs path to git diff file or "use git">
changed_files: <list from the diff>
repo_root: <abs path>
criteria_ref: references/detector-<name>.md
output_format: ndjson
max_findings: 50
```

Each sub-agent reads its criteria pack, walks every changed file relevant to its category, and emits **NDJSON to stdout** — one finding per line, no prose.

If sub-agents are not available, emulate as **seven sequential passes** in this skill's outer agent. Don't skip detectors when running sequentially; just run them in series and concatenate the NDJSON.

### Canonical finding schema

Every finding from every detector MUST be a JSON object with exactly these fields:

```json
{
  "category": "async-races",
  "severity": "Blocking",
  "file": "resources/admin/Modules/Settings/Migration/Pmpro/_PmproProgress.vue",
  "line": 41,
  "headline": "Retry can start concurrent import loops",
  "evidence": "retryImport() called from button handler without checking if importInFlight === true",
  "impact": "Two concurrent import loops mutate state in parallel; progress UI double-counts and import can corrupt data.",
  "recommended_fix": "Guard retryImport() with `if (this.importInFlight) return;` and await prior loop's completion before resuming.",
  "detectors": ["async-races"]
}
```

**Required:** `category`, `severity`, `file`, `headline`, `evidence`, `impact`, `recommended_fix`, `detectors`. **Optional:** `line` (omit for whole-file findings), `tier_escalating` (boolean; default `false`).

**Severity tiers:** `Blocking | High | Medium | Suggestion`.

**`tier_escalating: true`** — emitted by `bc-regression` when a non-additive hook-contract change is found in a WP plugin (see `references/detector-backwards-compatibility.md` "Non-additive hook-contract change"). When any finding has this flag, the WP review brief renders a "⚠ Tier escalation" callout above the brief recommending the PR be re-tiered to Breaking. The flag is informational — it does not programmatically modify the `new-feature` tier.

**Category vocabulary** (closed set — short machine-readable strings; plain English in filenames):
`a11y`, `async-state`, `traceability`, `rbac-alignment`, `bc-regression`, `error-state`, `perf-and-integrity`, `security`, `data-integrity`, `ui-logic`.

A finding missing any required field is dropped with a tagged stderr log:

| Tag | Used when |
|---|---|
| `[pre-merge-review:detector]` | Detector start / completion / count |
| `[pre-merge-review:drop]` | Finding rejected (malformed, over cap, out-of-vocabulary) |
| `[pre-merge-review:dedup]` | Two findings merged on `(file, line, category)` |
| `[pre-merge-review:precedence]` | Cross-category collision resolved by precedence |
| `[pre-merge-review:cleared]` | Re-run mode: prior finding no longer reproduces |

Tail with `2>&1 | grep '\[pre-merge-review:'` to audit decisions post-run.

### Aggregate and dedup

1. **Dedup key:** `(file, line, category)`. Same key → merge.
2. **Cross-category collision** (same file:line, different categories) — keep one using:
   ```
   security > rbac-alignment > data-integrity > traceability > async-state > a11y > bc-regression > error-state > ui-logic > perf
   ```
3. **Merge rules:** `severity` ← max of both; `category` ← higher-precedence; `headline`/`evidence`/`impact`/`recommended_fix` ← higher-precedence finding's text; `detectors` ← union.
4. Sort by severity → category precedence → file → line.

---

## Step 2 — Sequential pattern passes (always run)

These are the broad-spectrum, language- and pattern-specific checks. Run them after the detectors so findings can be merged into the same report.

### Pass A — Breaking changes (all PR types)

What does external code (Pro plugin, themes, third-party plugins) depend on that changed?

- Public PHP method signatures changed without `_deprecated_function()` wrapper?
- Hook names changed without the old name still firing?
- REST endpoint URL, method, or response shape changed without a version bump?
- `get_option`/`update_option` key changed without migrating old data?
- `window.*` globals removed or renamed?
- Custom event names or payload shapes changed without backwards compat?
- CSS classes removed that themes or JS might target?
- DB column renamed, dropped, or type-changed without migrating existing rows?
- New `NOT NULL` column without a default? Breaks existing rows on write.

### Pass B — Regression risk (all PR types)

What currently-working behaviour could break?

For each changed file: what did it do before, is it still doing all of that?

- Conditional added around previously unconditional code → fallback path exists and works?
- Early `return` added → does it skip anything that must still happen?
- Default value changed → what breaks on first read before anyone saves the new setting?
- Code moved to a new file → all callers updated?
- Hook priority changed → now runs before/after something it depends on?
- `isset()` replaced with direct access → key always exists in all contexts?

### Pass C — Code quality (all PR types)

- **Dead code:** imports never called, functions defined but never invoked, always-true/false branches.
- **Duplication:** logic copied instead of calling existing function; same `get_option()` in two new methods without a shared helper.
- **Complexity:** functions over ~50 lines doing more than one thing; nesting deeper than 3 levels; magic strings/numbers in more than one place.
- **Naming:** methods that don't describe what they do; booleans without `is`/`has`/`should` prefix; `public` methods only called internally.

### Pass D — WordPress PHP patterns (PHP PRs)

Load `references/patterns-wordpress-php.md` for the full checklist. Mandatory:

- Sanitize all `$_GET`/`$_POST`/`$_REQUEST` with the right sanitizer + `wp_unslash()`.
- Escape every output at the point of output (`esc_html`, `esc_attr`, `esc_url`, `esc_js`).
- All `$wpdb` calls with variables use `$wpdb->prepare()`.
- `get_option()` not inside loops; not called twice for same key without static cache.
- `ArrayHelper::get($arr, 'dot.key', $default)` instead of nested `isset()` ternaries.
- Hook names follow project convention (e.g. `fluentform/` prefix).
- Nonce verified **before** capability check on every AJAX/REST handler.
- `current_user_can()` present on every data-modifying endpoint.

### Pass E — JavaScript patterns (JS PRs)

Load `references/patterns-javascript.md`. Summary:

- Every `querySelector()` result null-checked before method calls.
- `addEventListener` in setup has matching `removeEventListener` in teardown.
- ARIA state (`aria-expanded`, etc.) stays synced across click handlers, responsive transitions, alternate open/close controls, and programmatic state helpers.
- Initialization inside `DOMContentLoaded` or `readyState` check — not at module evaluation.
- `fetch()` checks `response.ok` — 4xx/5xx don't throw.
- `require()` inside `if/else` → both files bundle (document if intentional).

### Pass F — Vue 2 patterns (Vue PRs)

Load `references/patterns-vue.md`. Summary:

- Options API only — no `setup()`, `ref()`, `reactive()`.
- `addEventListener` in `mounted()` → `removeEventListener` in `beforeDestroy()`.
- `$on()`/`$root.$on()` → `$off()` in `beforeDestroy()`.
- API calls use project REST client; all `.catch()` with user-visible message.

### Pass G — Performance quick-check (PHP PRs)

- `get_option()` or DB call inside a hook firing on every page load — new **or moved into one** by this PR?
- `->get()` on a model without `->where()` or `->limit()`? → full table scan.
- `whereIn(...)->get()` whose ID list comes from request data, saved settings, serialized post meta, option values, or filter output without an explicit max count? → unbounded batched query.
- A helper/method call inside a `foreach` whose **body** runs a query (e.g. `Helper::countFor($row->id)` per row)? → N+1 hidden behind one level of indirection; open the callee, don't just scan the loop body for query tokens.
- Caller-supplied range params (`date_from`/`date_to`, timestamps, offsets) bounding a query with **no maximum span**? A `where created_at BETWEEN` is still unbounded work if the window can be 10 years — clamp the span the same way `per_page` is clamped.
- WordPress-API queries without bounds: `get_terms()`, `get_posts()`, `get_users()`, `wp_get_object_terms()`, `WP_Query` without `posts_per_page` / `number` / `numberposts`? → unbounded retrieval.
- DB call inside a `foreach`? → N+1.
- New `add_action`/`add_filter` registered on every request that could be registered once at boot?
- **Refactor-moved query rule:** when a refactor extracts a query into a new method/file, treat it as a fresh "is this bounded?" review even though behaviour is unchanged. Pre-existing unbounded queries don't show up as red diff lines, but the move is the right moment to add `LIMIT` / `DISTINCT` / per-page caps.

### Pass H — Backwards compatibility (feature PRs)

- New PHP setting: does the default preserve existing behaviour for users who never saved it?
- New JS variable from PHP: what if the key is `undefined` on old cached pages?
- New DB column: every read handles `NULL` gracefully for existing rows?
- New hook: follows naming convention? Documented in changelog?
- Removed feature: deprecation notice added? UI warning shown?

### Pass I — State machine and adversarial inputs (all PR types)

Most subtle bugs survive earlier passes because the reviewer reads the diff top-to-bottom and assumes well-formed inputs and a single "happy" state. These checks force the opposite stance.

**I.1 — Single-source-of-truth audit.** For each new piece of state (a `data()` field, instance property, computed, settings option): what is the single source of truth? Where else is it read? Do those readers re-derive correctly when the source changes? If the same boolean flag controls **both** UI visibility and data persistence/query — flag it.

**I.2 — Two-axis grid for boolean flags.** For every boolean flag introduced or modified, draw:

```
              │ feature_data: present │ feature_data: empty
flag = true   │      A                │      B
flag = false  │      C                │      D
```

Walk each cell. Any cell that is "?" or "this can't happen but the code allows it" or "this state silently degrades" — that is the bug.

**I.3 — Index-stability rule.** Whenever an array is transformed (`.filter(...)`, `.map(...)`) before being exposed to a consumer that uses indices (event emitters, parent handlers, key-based lookups):

- Verify the consumer indices line up with the **source** array, not the transformed one.
- If they don't, require an `originalIndex` to be carried alongside the transformed item.
- Grep for `\.filter\(.*\)\.map\(` and `\.filter\(` immediately preceding a `v-for` in templates.

**I.4 — Adversarial input walkthrough.** Before declaring the PR done, mentally feed:

- Empty array `[]`
- Single-element wrapper `[[]]`
- Sparse arrays with empty slots before populated entries: `[[], X, Y]`
- One `null` mixed in
- Length 1 vs length >1 (off-by-one)
- Concurrent triggers (rapid clicks before previous response returns)

If any input produces a plausible-but-broken state, document it and either fix or note explicitly.

**I.5 — Symptom vs root cause.** When a PR fixes a reported issue, ask: **"What broader design choice made this issue possible?"** A symptom fix narrows to the reported case but leaves the underlying design open. A root-cause fix touches the design. If you change behavior under condition X to fix bug Y, also reason about condition NOT X — does it now have a related bug?

---

## Step 3 — Render the report

Single file. Section order **depends on whether the repo is a WP plugin** (Step 0d).

### Report structure — WP plugin detected

```
# Pre-Merge Review — <branch>
**Date:** YYYY-MM-DD | **Mode:** Full / Light | **PR type:** ... | **Plugin:** <slug>

## ⚠ Tier escalation              ← only when any finding has tier_escalating: true
## WP Review Brief                 ← THE primary review artifact
## Summary                         ← detector + pattern-pass severity tally
## Inline findings                 ← all detector findings (supplementary)
## Hooks diff                      ← only when any hook was added/changed/removed
## What looks good
## Verification Checklist
```

The brief is the **primary review artifact** for WP plugins — designed so the reviewer can decide approve/ask/block in 60 seconds without scrolling the diff. The detector findings come *after* — supplementary detail for reviewers who want to drill in.

**Render the brief** by filling the template at `references/wp-review-brief-template.md` from the diff:

- **Surface area** — count actions/filters added/changed/removed; count REST routes; check for DB migrations, new capabilities, cron events, public method signature changes, option/postmeta key renames; check `readme.txt` and `.pot` regeneration.
- **Security checklist** — grep the diff for `$_GET`/`$_POST`/`$_REQUEST` accesses (need sanitizer + `wp_unslash`), echo/print sites (need escaping), nonce checks, capability checks, `$wpdb` calls (need `prepare()`), and `ABSPATH` guards on new files. Report each as `found/required` with `✓` only when satisfied.
- **Compatibility** — read plugin headers and `readme.txt`; note min WP / PHP / multisite / integration touches.
- **Lifecycle** — diff activation/deactivation/uninstall hooks for new behaviour.
- **Look here first** — rank changed files by the weight table in `wp-review-brief-template.md`; surface top 3–5 with a one-sentence "why riskiest" for each. Omit the section entirely if no file scores above 0.

**Render the hooks-diff block** when any hook was added/changed/removed (see classification rules in `references/wp-review-brief-template.md` and detector logic in `references/detector-backwards-compatibility.md`):

```markdown
## Hooks diff

### Actions
`myplugin/order_completed` — **ADDED** (additive)
  after:  `do_action( 'myplugin/order_completed', $order )`
  Impact: new extension point.
  Action: document in changelog under "For developers".

`myplugin/order_saved` — **REMOVED** (non-additive — TIER-ESCALATING)
  before: `do_action( 'myplugin/order_saved', $order )`
  Impact: BREAKING for any site hooking this.
  Action: keep deprecated shim for 2 minor versions; schedule removal in changelog.

### Filters
`myplugin_pricing` — **CHANGED** (additive)
  before: `apply_filters( 'myplugin_pricing', $price, $product_id )`
  after:  `apply_filters( 'myplugin_pricing', $price, $product_id, $context )`
  Impact: existing handlers still work (extra arg ignored).
  Action: note in changelog under "For developers".
```

### Report structure — non-WP repo

```markdown
# Pre-Merge Review — <branch name>
**Date:** YYYY-MM-DD | **Mode:** Full / Light | **PR type:** Feature / Fix / Refactor / Mixed

## Summary

**Blocking:** 4 | **High:** 7 | **Medium:** 12 | **Suggestion:** 3

### Blocking
- `app/Http/Controllers/Migration/Pmpro/PmproMigrationController.php:92` — **PMPro routes are wired to nonfunctional handlers** (ui-to-backend-wiring)
- `resources/admin/Modules/Settings/Migration/Pmpro/_PmproProgress.vue:41` — **Retry can start concurrent import loops** (async-races)

### High
- ...
```

### Inline findings (both report shapes)

```markdown
## Inline findings

### `resources/admin/Modules/Settings/Migration/Pmpro/_PmproProgress.vue:41` — async-races — Blocking

**Retry can start concurrent import loops**

**Evidence:** retryImport() called from button handler without checking if importInFlight === true.

**Impact:** Two concurrent import loops mutate state in parallel; progress UI double-counts and import can corrupt data.

**Recommended fix:** Guard retryImport() with `if (this.importInFlight) return;` and await prior loop's completion before resuming.

**Detectors:** `async-races`

---
```

One block per finding, separated by `---`. The bold-headline convention matches the WPManageNinja AI reviewer so reports read consistently.

### What looks good (2–4 bullets)

Non-obvious things done well — prevents review feeling adversarial.

### Verification Checklist

```markdown
## Verification Checklist
- [ ] B-01: <description>
- [ ] B-02: <description>
- [ ] H-01: <description>
```

### Severity definitions

| Level | Definition |
|---|---|
| **Blocking** | Active breakage — crash, data loss, security hole, silent wrong behaviour |
| **High** | A documented feature stops working or behaves differently |
| **Medium** | Correctness, performance, or maintainability issue — no user-visible breakage |
| **Suggestion** | Design issue, dead code, naming — no immediate impact |

### Severity calibration rules

- **Impact sets the floor; probability adjusts at most one tier.** A narrow
  trigger window never demotes silent-data-loss/contract-breaking impact to
  Suggestion. Classify by what happens WHEN it fires, then discount once for
  rarity if warranted.
- **Contract-violation floor:** if the finding makes the change break its own
  documented promise (tool description, schema contract, PR claim), minimum
  severity is High.
- **Self-incrimination check:** if your evidence sentence states the failure
  scenario is the feature's primary use case ("exactly the X scenario"), the
  finding cannot be a Suggestion — re-tier it.

### Resolution standard (re-runs and fix verification)

- A finding is **resolved** only when the failure mechanism is structurally
  impossible — not merely narrower or less likely. "Shrank the window" is a
  mitigation, not a resolution; mark it `accepted-residual` with explicit
  maintainer sign-off instead of closing it, and expect external reviewers to
  re-flag it until the mechanism is gone.
- When fixing a concurrency/atomicity finding, reach for the structural tool
  first (row lock, transaction, compare-and-swap, idempotency key) and fall
  back to narrowing only when the structural fix is genuinely unavailable —
  then say so in the fix description.
- When a finding's recommended fix says "X and/or Y", implement the strongest
  option you can justify, not the cheapest half — half-fixes reopen as
  re-blocks and cost more than doing Y up front.

---

## Required behaviours (do not skip)

1. **Always run `ui-to-backend-wiring` and `backwards-compatibility`** regardless of changed file types — they are PR-shape checks, not file-type checks. A PHP-only PR can still introduce a payload-key rename.
2. **Never report a finding outside the closed category vocabulary** — if a real issue doesn't fit a detector, add it to the most-relevant detector's criteria pack and re-run; do not invent a new category at runtime.
3. **Severity is conservative by default** — anything ambiguous is `Suggestion`, not `Blocking`. Promote to `Blocking` only when the criteria pack says so.
4. **Cap each detector at 50 findings** — runaway detectors hurt readability more than missing edge cases.
5. **Always emit the canonical schema** — even prose-style findings get reduced to the JSON shape before rendering.
6. **Use project vocabulary in headlines** — load `CONTEXT.md` first.

## Anti-patterns

- Don't fold `pre-merge-review` back into separate review skills. The merge was intentional — both depth points are available via the mode flag.
- Don't add an eighth detector before exhausting the existing seven. New finding categories belong in an existing detector's criteria pack, not as a new parallel pass.
- Don't report findings in the Summary section without a corresponding Inline-findings block.
- Don't silently drop findings on dedup — always log to stderr what was merged.

---

## Skill workflow

```
/pre-merge-review          ← first run: full multi-detector + sequential review
/plugin-audit              ← optional: deep security on flagged paths
/php-cs-fixer-style        ← formatting
                           ← fix Blocking + High
/pre-merge-review          ← re-run: confirm fixes, archive prior report
/pr-descriptor             ← write PR description
```

For tiny single-file diffs: `/pre-merge-review light` (skips parallel detectors).
