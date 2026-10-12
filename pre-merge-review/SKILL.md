---
name: pre-merge-review
description: >
  Review a branch or pull request before merge with specialised detectors, cross-layer
  pattern passes, adversarial refutation of every Blocking/High finding, repository-native
  verification, and an explicit merge verdict. Use for
  "review this PR", "is this ready to merge", "pre-merge check", "audit the branch",
  "deep review", or "check before merge". Supports a lighter mode for genuinely low-risk diffs.
---

# Pre-Merge Review

The single canonical pre-merge gate. This skill replaces the previous `engineering-review` (sequential 9-pass) and `pr-reviewer` (parallel multi-detector) skills, which were merged into one on 2026-05-21.

Two modes:

- **Full (default)** — runs the seven specialised detectors **and** every pattern-pass worker through a capacity-aware parallel queue. Use all available child slots without requiring every worker to exist simultaneously. Use for any non-trivial PR.
- **Light (`/pre-merge-review light`)** — runs only the pattern-pass workers. Step 2c refutation of Blocking/High findings still runs; a light review may produce fewer findings but never a less-verified one. Allow it only for a tiny diff with no authorization, persistence, schema, public-contract, async, payment, security-control, or generated-artifact surface; otherwise auto-promote to Full and say why.

## Review contract

- Review only; do not edit product code, rewrite git state, install dependencies, or publish anything. The report is the only default write. If the user requests read-only/no-file output, render the report in the response and do not write it.
- Lead with `READY`, `NOT READY`, or `INCOMPLETE VERIFICATION`. Never equate “no findings” with “ready” when scope or required verification is incomplete.
- Preserve user changes. Record staged, unstaged, and untracked files before running tools; never hide them behind a committed-branch diff.
- Treat tool absence, network failure, skipped tests, stale graph data, and unavailable sibling repositories as coverage gaps, not passing evidence.

## Resolve review scope

1. Record repo root, branch, `HEAD`, `git status --short`, staged diff, unstaged diff, and untracked files.
2. Determine the intended base in this order: user-supplied base; PR metadata (`gh pr view --json baseRefName` when available); configured remote default branch; then an existing `origin/dev`, `origin/main`, or `origin/master`. Verify the ref exists.
3. Compute `MERGE_BASE=$(git merge-base "$BASE_REF" HEAD)` and review `MERGE_BASE...HEAD`. Do not use `HEAD~1` as a clean fallback. If no reliable base can be established, continue only as `INCOMPLETE VERIFICATION` and state the assumed scope.
4. Review staged, unstaged, and untracked source in addition to the branch diff unless the user explicitly excludes it. List exclusions in the report.
5. Record whether the branch merges cleanly with the base using a read-only merge-tree check when available.

---

## Output location and re-run behaviour

**Output path** (in priority order):
1. `/Volumes/Workspace/pr-reviews/<repo>/<branch-slug>.md` — if `/Volumes/Workspace` exists.
2. `openspec/changes/<branch-slug>/PRE-MERGE-REVIEW.md` — when that exact openspec change already exists.
3. `<repo-root>/.review/<branch-slug>.md` — fallback when neither location applies.

Do **not** create `/Volumes/Workspace/pr-reviews/` if it is missing — that signals the machine isn't configured for hosted reviews and the fallback is correct.

**Re-run mode** — if a report already exists at the output path:
1. Read existing findings under `## Inline findings`.
2. Re-run against the complete resolved scope, never only commits since the prior report.
3. Compare findings by a stable fingerprint derived from normalized file path, enclosing symbol/context anchor, category, and failure mechanism. Line number and prose headline are display metadata, not identity.
   - Matching fingerprint: keep `open` unless explicitly verified otherwise.
   - Prior fingerprint absent from worker output: reopen the source and verify the original failure mechanism. Mark `cleared` only with evidence that it is structurally impossible; otherwise mark `unverified` or `not-reproduced`.
   - New fingerprint: add as `open`.
4. Archive the existing report as `<branch>-<prior-sha>-<timestamp>.md`; never overwrite an archive from the same SHA.
5. Write the new report and append `## Re-run history` with SHA, timestamp, scope fingerprint, verdict, and counts by status.

---

## Step 0 — Pre-flight

### 0a. Establish intent and PR type

Read the user request plus the PR title/body, linked issue/spec, acceptance criteria, and screenshots when available. State the promised behaviour in 1–3 sentences. If intent is inferred from commits/diff, label it inferred. Classify as `Feature | Bug Fix | Refactor | Schema | JS | Vue | Mixed`.

### 0b. Project instructions and glossary

Read every applicable `AGENTS.md` from repo root toward changed files, then `CONTRIBUTING.md`, `CLAUDE.md`, `CONTEXT.md`, `CONTEXT-MAP.md`, relevant README/test docs, and CI workflow definitions. Pass a concise instruction summary to every worker. Project instructions override generic pack advice. Use project vocabulary in headlines.

### 0c. code-review-graph context, when available

If the repo has `code-review-graph` wired (`.mcp.json` mentions `code-review-graph`, `.code-review-graph/` exists, or MCP tools such as `query_graph`, `get_impact_radius`, `detect_changes`, `get_review_context`, or `semantic_search_nodes` are callable), use it before grep for structural review context:

| Question | Prefer graph tool | Cross-check |
|---|---|---|
| What changed and what flows are affected? | `detect_changes` or `get_review_context` | resolved merge-base diff plus worktree inventory |
| Who calls/imports the changed symbol? | `query_graph` with `callers_of` / `importers_of` | targeted `rg` for the symbol |
| What tests cover the changed symbol? | `query_graph tests_for <symbol>` or equivalent | repo test names and changed tests |
| What is the impact radius? | `get_impact_radius` | detector findings and manual call-path reads |

Use graph output to prioritize detector attention, not to replace reading the diff. Treat graph data as potentially stale; if it conflicts with `git diff` or targeted `rg`, trust the live source and mention the mismatch in the report notes.

If graph is not available, say nothing special and continue with git diff plus `rg`/`find`.

### 0d. Map changed files to detectors

| Extension | Detectors that run |
|---|---|
| `.vue` | accessibility, async-races, error-handling-ux, ui-to-backend-wiring, backwards-compatibility, permissions-and-capabilities |
| `.jsx` / `.tsx` | accessibility, async-races, error-handling-ux, ui-to-backend-wiring, backwards-compatibility |
| `.js` / `.ts` | async-races, error-handling-ux, ui-to-backend-wiring, backwards-compatibility |
| `.php` (Controllers, Policies) | permissions-and-capabilities, ui-to-backend-wiring, backwards-compatibility, performance-and-data-integrity |
| `.php` (Services, Models, Views) | ui-to-backend-wiring, backwards-compatibility, performance-and-data-integrity |
| `.php` (Hooks, Providers, Bootstrap) | permissions-and-capabilities, ui-to-backend-wiring, backwards-compatibility, performance-and-data-integrity |
| `.scss` / `.css` | accessibility (focus-visible / outline-removal only) |
| `database/Migrations/*` or `migrations/*` | backwards-compatibility, performance-and-data-integrity |

**Always run** `ui-to-backend-wiring` and `backwards-compatibility` regardless of file types — they are PR-shape checks, not file-type checks.
Content triggers override path gating: capability/ACL tokens trigger permissions review; hook registration triggers hook-contract and mutating-callback review; query/mutation tokens trigger performance/data-integrity review.

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

If a tool is missing or cannot run, log it and add it to `Coverage gaps`. Distinguish “tool found issues” from “tool could not execute”; only the former becomes a code finding.

See `references/wp-review-brief-template.md` for the full WP-specific brief template + hooks-diff classification rules + "Look here first" ranking weights.

### 0f. Discover repository-native gates

Inspect package/composer scripts, Make/Task files, test documentation, local hooks, and CI workflows. Build a risk-based command list covering changed-area regression tests plus relevant full suites, static analysis, security checks, build/generated-artifact parity, and dependency audit. Record for each command: exact invocation, `pass | fail | skipped | missing | blocked`, essential output, skip count, and why it matters.

- A green static suite does not replace required runtime/integration evidence.
- A dependency audit that cannot reach its registry is `blocked`, never “no advisories”.
- Unexpected skips are verification gaps. A suite with zero executed tests is not a pass.
- For interactive UI or accessibility changes, exercise the compiled UI in a browser when available. If required interaction cannot be run, verdict is `INCOMPLETE VERIFICATION` unless other evidence proves the behaviour.
- Do not install dependencies or regenerate/commit artifacts without authorization. If source and committed bundles must stay in sync, compare them or report the missing build verification.

### 0g. Announce the plan
Print one line so the user has a cheap interrupt point:

```
[pre-merge-review:plan] 14 changed files (8 vue, 4 php, 2 scss). WP plugin: yes (plugin-slug).
                        Mode: full. Refutation: Blocking/High (Step 2c). Detectors: accessibility, async-races, error-handling-ux,
                        ui-to-backend-wiring, backwards-compatibility, permissions-and-capabilities,
                        performance-and-data-integrity + pattern-pass workers. Scheduling: <N> child slots, bounded queue.
```

---

## Step 1 — Parallel detectors (skip in light mode)

If the runtime can spawn sub-agents, build one job per detector. Determine available child-agent capacity, reserve the outer reviewer slot, and run at most that many jobs concurrently. Start the next queued job as soon as one finishes; every job must run even when capacity is smaller than the queue. Each sub-agent receives:

```yaml
detector: <one of: accessibility | async-races | ui-to-backend-wiring | permissions-and-capabilities | backwards-compatibility | error-handling-ux | performance-and-data-integrity>
diff_path: <abs path to git diff file or "use git">
changed_files: <list from the diff>
worktree_files: <staged, unstaged, untracked lists>
base_ref: <resolved base ref>
merge_base: <sha>
repo_root: <abs path>
acceptance_criteria: <short summary>
project_instructions: <short summary plus source paths>
criteria_ref: references/detector-<name>.md
output_format: ndjson
max_findings: 50
```

Each sub-agent reads its criteria pack, walks every changed file relevant to its category, and emits **NDJSON to stdout** — one finding per line, no prose.

If sub-agents are not available, emulate as **seven sequential passes** in this skill's outer agent. Don't skip detectors when running sequentially; just run them in series and concatenate the NDJSON.

### Canonical finding schema

Every finding from every detector MUST conform to this JSON schema:

```json
{
  "category": "async-state",
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

**Required:** `category`, `severity`, `file`, `headline`, `evidence`, `impact`, `recommended_fix`, `detectors`. **Optional:** `line` (omit for whole-file findings), `tier_escalating` (boolean; default `false`), `fix_alternatives` (array; required for confirmed Blocking/High findings with more than one cut point — see Step 2d), `refutation` (object; added by Step 2c, never emitted by a detector).

**Severity tiers:** `Blocking | High | Medium | Suggestion`.

**`tier_escalating: true`** — emitted by `bc-regression` when a non-additive hook-contract change is found in a WP plugin (see `references/detector-backwards-compatibility.md` "Non-additive hook-contract change"). When any finding has this flag, the WP review brief renders a "⚠ Tier escalation" callout above the brief recommending the PR be re-tiered to Breaking. The flag is informational — it does not programmatically modify the `new-feature` tier.

**Category vocabulary** (closed set — short machine-readable strings; plain English in filenames):
`a11y`, `async-state`, `traceability`, `rbac-alignment`, `bc-regression`, `error-state`, `perf-and-integrity`, `security`, `data-integrity`, `ui-logic`.

A finding missing any required field is dropped with a tagged stderr log:

| Tag | Used when |
|---|---|
| `[pre-merge-review:detector]` | Detector start / completion / count |
| `[pre-merge-review:drop]` | Finding rejected as malformed or out-of-vocabulary |
| `[pre-merge-review:overflow]` | Finding retained outside the rendered cap and counted as a coverage gap |
| `[pre-merge-review:dedup]` | Exact failure-mechanism fingerprints merged |
| `[pre-merge-review:related]` | Independent cross-category findings linked without data loss |
| `[pre-merge-review:cleared]` | Re-run mode: prior finding no longer reproduces |
| `[pre-merge-review:refute]` | Step 2c skeptic verdict — `confirmed` / `narrowed` / `refuted` / `unreachable` plus the named mechanism |

Tail with `2>&1 | grep '\[pre-merge-review:'` to audit decisions post-run.

### Aggregate and dedup

Concatenate the NDJSON from **every** worker — the seven detectors and all Step 2 pattern-pass workers — then run this once over the combined stream:

1. Compute a fingerprint from normalized file path, enclosing symbol/context anchor, category, and failure mechanism. Line number and headline are excluded from identity.
2. Merge only identical fingerprints. Same line/category is not sufficient; one line may contain multiple independent defects.
3. Preserve cross-category findings. Link them as related when they share a root cause, but never discard one category's impact or recommended fix.
4. Exact-duplicate merge: keep maximum severity, union detectors/evidence, retain the strongest concrete fix, and log the merged fingerprints.
5. Sort by severity → category → file → line and assign `open | cleared | accepted-residual | unverified | not-reproduced | refuted | narrowed` status. `refuted` and `narrowed` are assigned only by Step 2c, never by a detector or by the dedup pass.

---

## Step 2 — Pattern-pass workers (always run, parallel)

These are the broad-spectrum, language- and pattern-specific checks. Add them to the same capacity-aware job queue as Step 1. Do not skip jobs because all child slots are occupied; wait for a slot and continue the queue. Each worker emits NDJSON in the canonical schema from Step 1; all output feeds the single aggregate/dedup pass.

### Worker bundles

Spawn one sub-agent per bundle. Each receives the same envelope as a detector (`diff_path`, `changed_files`, `repo_root`, `output_format: ndjson`, `max_findings: 50`) plus the passes it owns. Gate by file type — skip a bundle whose files aren't in the diff.

| Worker | Owns passes | Runs when |
|---|---|---|
| `pp-contracts` | A, A2, A3, H | always |
| `pp-regression-quality` | B, C | always |
| `pp-php-perf` | D, G | diff touches `.php` |
| `pp-frontend` | E, F | diff touches `.js` / `.ts` / `.jsx` / `.tsx` / `.vue` |
| `pp-state-adversarial` | I | always |
| `pp-security-assertion` | J | diff adds/changes a security test, detector, or guard |

Each worker reads only the pass definitions it owns (below), applies them to its gated files, and emits one JSON finding per line — the prose grids and walkthroughs (e.g. Pass I's two-axis grid) are the worker's internal reasoning, not report output. **Fallback:** if the runtime can't spawn sub-agents, run every pass sequentially in the outer agent (the pre-2026 behaviour) and concatenate the NDJSON.

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

### Pass A2 — Cross-boundary key contracts (all PR types)

Triggered whenever the diff touches string-keyed data that crosses a boundary: Free↔Pro filter payloads, `wp_localize_script` vars, REST response shapes, postMessage payloads, or option arrays consumed by another layer. Assume several parallel keyspaces exist for the same entities (UI source keys vs service-layer slugs vs settings/integration keys) — mixed keyspaces inside one contract are the primary failure mode.

Procedure (all steps mandatory — a match on one pair is NOT verification of the contract):

1. Grep the payload key name (e.g. `pro_providers`) across ALL repos in the workspace. Enumerate every list/map that produces into or reads from the contract, including ones the diff did not touch.
2. Name the keyspace each list speaks before comparing anything.
3. Literal-diff every producer list against every consumer lookup — report N lists found and which pairs were diffed. Never write "keyspaces match" for the contract unless every pair was checked; list them in the report.
4. Prefer runtime evidence (the localized payload in page source / console / a test) over reading one side's code.

Origin: PR #546/#151 review miss — `connected_providers` was diffed against the consumer and declared "matching exactly" while `pro_providers`, six lines above in the same Pro filter and part of the same contract, spoke a different keyspace (`bunny` vs `bunnycdn`). An external reviewer caught it.

### Pass A3 — Scope of every new guard (all PR types)

Pass A2 catches a key name that fails to match across a boundary. This catches
the inverse: a key name that matches **too much**.

For every sanitizer, validator, normalizer or guard the diff adds, ask two
questions in this order:

1. **Does it fire where it must?** (coverage — what reviewers naturally ask)
2. **Does it fire *only* where it must?** (scope — what they naturally skip)

Question 2 is the one that gets dropped, because a coverage-shaped question
gets a coverage-shaped answer: "yes, both write paths are sanitized" is true
and useless if one of them sanitizes far more than it should.

Anchor the check: name what confines the new guard to its intended target — a
containing node, an element type, a route, a capability. "It matches on the key
name" is not confinement. See **Key-name match without positional anchoring**
in `references/detector-performance-and-data-integrity.md`.

**When the guard lives inside a recursive walker, do not answer from a read.**
Build an input carrying the same key in an unrelated branch and run it.

### Pass B — Regression risk (all PR types)

What currently-working behaviour could break?

For each changed file: what did it do before, is it still doing all of that?

- Conditional added around previously unconditional code → fallback path exists and works?
- Early `return` added → does it skip anything that must still happen?
- Default value changed → what breaks on first read before anyone saves the new setting?
- Code moved to a new file → all callers updated?
- Hook priority changed → now runs before/after something it depends on?
- `isset()` replaced with direct access → key always exists in all contexts?
- **Bug fixed in one function → does a copy-paste twin have the same bug?** A shared routine (sanitizer, escaper, deserializer, auth check) is often duplicated. Grep by name AND shape — `grep -rn "function .*[Ss]anitiz" app boot src` — not just callers: an orphaned duplicate with zero callers (e.g. `Helper::sanitizer()` shadowing `fluentFormSanitizer()`) is invisible to `get_impact_radius`/`callers_of`. Fix/flag every implementation and confirm the guard/detector's target list covers all of them.

### Pass C — Code quality (all PR types)

- **Dead code:** imports never called, functions defined but never invoked, always-true/false branches.
- **Duplication:** logic copied instead of calling existing function; same `get_option()` in two new methods without a shared helper.
- **Complexity:** functions over ~50 lines doing more than one thing; nesting deeper than 3 levels; magic strings/numbers in more than one place.
- **Naming:** methods that don't describe what they do; booleans without `is`/`has`/`should` prefix; `public` methods only called internally.
- **Comment form (hard rule, flag as Low):** an added comment must be one short line explaining a non-obvious WHY. `grep -nE '^\+\s*(//|#|\*)' <diff>` and flag any run of **2+ consecutive added comment lines** (a block comment to collapse to one line or delete) and any comment added directly above a single-statement line. Also flag a comment that restates WHAT the code does, or WHY in terms of the task/fix/caller ("added for X", "fixes #123") — that belongs in the commit message. The "state the contract at each producer/consumer" guidance (Pass A2) does **not** license a multi-line comment; the contract note is still one line.

### Pass D — WordPress PHP patterns (PHP PRs)

Load `references/patterns-wordpress-php.md` for the full checklist. Mandatory:

- Sanitize all `$_GET`/`$_POST`/`$_REQUEST` with the right sanitizer + `wp_unslash()`.
- Escape every output at the point of output (`esc_html`, `esc_attr`, `esc_url`, `esc_js`).
- All `$wpdb` calls with variables use `$wpdb->prepare()`.
- `get_option()` not inside loops; not called twice for same key without static cache.
- `ArrayHelper::get($arr, 'dot.key', $default)` instead of nested `isset()` ternaries.
- Hook names follow project convention (e.g. `fluentform/` prefix).
- AJAX/form requests use the project-required CSRF mechanism; REST routes use their registered permission/policy layer. Nonces are CSRF protection, not authorization.
- Every data-modifying endpoint is authorized through the project ACL/policy, resource ownership, or the exact required capability; do not require raw `current_user_can()` when project instructions designate another gate.

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
- **Materialize-then-reduce:** a `->get()` whose rows are only fed to a `foreach`/`array_sum`/`count()` that builds a total, a count, or a `GROUP BY`-shaped map? → push the reduction into SQL (`COUNT`/`SUM`/`GROUP BY … LIMIT`). Even a *scoped* or span-clamped `->get()` is a bug here — memory scales with row count when the DB could return the aggregate. Ask "is every field read only being summed/counted/grouped?" Corpus: fluentformpro#249 (`getSubscriptions` loaded every row to sum totals + build a top-5 chart; the span clamp didn't bound the rows).
- **Redundant duplicate scans:** the same scan run once per category — a per-type/per-status helper called N times (`getX('a')` then `getX('b')`) where one query `GROUP BY` that dimension returns all categories in a single pass? → collapse to one grouped query, each caller reads its slice. Delegation can *introduce* this (one-call-per-type reads clean but doubles the scans). Corpus: fluentform#1113 (payment summary called `getPaymentsByType` per type = two scans; folded into one `GROUP BY transaction_type`).
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

**I.6 — Multi-source aggregates and SQL aliases.** Load the populate-vs-enrich and alias-shadow rules from `references/detector-performance-and-data-integrity.md`. Run the empty-primary/non-empty-auxiliary probe and verify `GROUP BY`/`ORDER BY` aliases do not shadow raw columns.

### Pass J — Security assertion trust (when the diff adds/changes a security test, detector, guard, or any test that claims to *prove* a security property)

Load `references/detector-security-assertion-quality.md`. Challenge signal forgeability and enumeration completeness, construct a counterexample, and distrust a self-test that shares the production assertion's shape. Emit `category: "security"`; severity is `High` when a claimed security proof can pass without proving its control and `Blocking` when that false proof is itself a required merge/security gate.

## Step 2b — Synthesis and disproof

After aggregation, the outer reviewer must reopen the top-risk files and every Blocking/High path, inspect relevant unchanged callers/consumers, reconcile cross-worker findings, and challenge the clean verdict. A mechanical NDJSON merge is not synthesis. If no findings remain, explicitly attempt to disprove readiness on authorization, money/data integrity, public contracts, migrations, and required runtime behavior.

---

## Step 2c — Refute the findings (adversarial verification)

Step 2b disproves the **clean verdict** — it hunts false negatives. This step hunts the opposite error:
a finding that is wrong, overstated, or unreachable. Both errors are expensive, and on a merge gate the
second one is the more corrosive. A Blocking finding that turns out to be false blocks a good PR, costs
the author an afternoon, and teaches the team that the gate cries wolf — after which the real Blocking
finding gets waved through too.

The detector that produced a finding is the worst judge of it. It already believes it. So the finding is
attacked by something that has never seen the detector's reasoning.

### 2c.1 — What gets refuted

| Severity | Refutation |
|---|---|
| `Blocking` | Mandatory, one skeptic each |
| `High` | Mandatory, one skeptic each |
| `Medium` | Sample — any finding whose evidence is a single line read without a traced call path |
| `Suggestion` | None. Not worth the tokens; they block nothing. |

Also mandatory regardless of severity: any finding whose `recommended_fix` would change a public contract
(hook signature, REST shape, DB column, option key). A wrong finding there costs more than the bug would.

### 2c.2 — Envelope

One sub-agent per finding, clean context, added to the same capacity-aware queue as Steps 1 and 2.

```yaml
finding: <headline, file, line, category, severity, evidence, impact — the finding only>
repo_root: <abs path>
base_ref: <resolved base ref>
merge_base: <sha>
project_instructions: <short summary plus source paths>
stance: refute
task: >
  Prove this finding wrong. Open the file and read the real call paths. Look for the guard,
  precondition, framework behaviour, project convention, or type constraint that makes the
  described failure impossible or unreachable. Name it at file:line.
  If you cannot make it impossible, try to make it SMALLER — show the impact is narrower than
  claimed, or reachable only in a configuration this project does not support.
output_format: ndjson
```

**Do not pass the detector's name, its criteria pack, or its reasoning.** The skeptic gets the claim and
the repository, nothing else. Passing the pack's rationale reproduces the anchor you are trying to break.

### 2c.3 — Verdicts

| Verdict | Means | Required evidence |
|---|---|---|
| `confirmed` | The attack failed | What the skeptic tried and why each attempt failed |
| `narrowed` | Real, but smaller than claimed | The constraint that bounds it, at file:line — drop severity by one tier |
| `refuted` | Structurally impossible | The guard/precondition at file:line that makes it so |
| `unreachable` | Path cannot execute in any supported configuration | The gate that blocks it, plus which configs were considered |

**A refutation needs a named mechanism at `file:line`.** "Unlikely", "the caller probably validates",
"this would be caught in testing", "no one calls it that way" are not refutations — they are the same
absence-of-evidence reasoning that Required Behaviour 7 already forbids for clearing. If the skeptic
cannot name the guard, the verdict is `confirmed` and the finding stands.

Symmetrically: a skeptic that returns `confirmed` for everything has not done its job either. Its report
must say what it actually attempted.

### 2c.4 — What happens to the report

- `confirmed` → renders normally, and its block notes that it survived refutation. This is what makes a
  Blocking finding worth acting on immediately.
- `narrowed` → renders at the lower severity, with both the original claim and the bounding constraint.
- `refuted` / `unreachable` → **moves to a `## Refuted findings` section — never silently dropped.**
  Record the finding, which detector raised it, and the guard that killed it. Silent deletion is how the
  same false positive comes back every run.
- A refutation may lower the verdict from `NOT READY` to `READY` only when every Blocking/High finding
  was refuted with a named mechanism, and the report shows each one. Never on a tally.

### 2c.5 — Feed the corpus

Every `refuted` and `narrowed` verdict is a calibration signal about the detector that raised it. Append a
row to `references/test-corpus.tsv` recording the pattern, the detector, and the guard that made it a false
positive. A detector that produces repeat false positives in the same shape needs its criteria pack
tightened — that is the pack's bug, not the reviewer's.

---

## Step 2d — Fix options: recommend the smallest change that closes the class

A finding's `recommended_fix` is a recommendation to someone who knows this code better than the reviewer
does. Handing them one option, stated as the answer, wastes what they know and invites either an
over-broad refactor inside a fix commit or a narrow patch that leaves the class open.

### 2d.1 — Required for every confirmed Blocking and High finding

When the failure can be cut at more than one depth, give **at least two candidates at different depths** —
the guard at the sink, the fix at the carrier, the fix at the source, or the structural change. Add them to
the finding as `fix_alternatives`:

```json
"fix_alternatives": [
  {
    "depth": "sink",
    "change": "Guard retryImport() with `if (this.importInFlight) return;`",
    "closes": "The reported double-click path",
    "leaves_open": "Any other caller of the import loop; a second entry point re-opens it",
    "blast_radius": "1 file, 1 method"
  },
  {
    "depth": "carrier",
    "change": "Move the in-flight flag into the import service so every caller shares one guard",
    "closes": "The whole concurrent-import class",
    "leaves_open": "Nothing in this class",
    "blast_radius": "2 files, 3 callers, no public contract change"
  }
]
```

`recommended_fix` then states which candidate the reviewer recommends **and why**, in one sentence.

### 2d.2 — The rule

**Recommend the smallest change that closes the whole class.**

Both halves bind, and they resolve what looks like a contradiction with
`references/severity-and-resolution.md`:

- That file's *"implement the strongest justified option; a partial mitigation does not resolve the
  stronger mechanism"* forbids the **too-small** fix — the one that narrows the race window instead of
  removing it, and earns `accepted-residual` rather than `cleared`.
- This rule forbids the **too-large** one — a structural redesign recommended for a one-line race, landing
  inside a fix commit where it gets no review of its own.

They agree on the target: close the whole mechanism, nothing beyond it. When a structural change genuinely
is the smallest thing that closes the class, it *is* the recommendation — say so plainly, and note that it
warrants its own PR.

### 2d.3 — Boundaries

- The review recommends; the author decides. Never render a fix as the only possibility when the finding
  has more than one cut point.
- Never recommend a fix the reviewer has not read the surrounding code for. A plausible-sounding fix that
  breaks a caller is worse than "this needs a fix, here is the mechanism".
- A fix that changes a public contract is itself a `tier_escalating` signal — flag it rather than burying
  it in `recommended_fix` prose.
- Still review-only. Recommending a fix is never authorization to write it.

---

## Step 3 — Render the report

Single file. Section order depends on whether Step 0e detects a WP plugin.

### Report structure — WP plugin detected

```
# Pre-Merge Review — <branch>
**Date:** YYYY-MM-DD | **Mode:** Full / Light | **PR type:** ... | **Plugin:** <slug>

## Merge verdict                  ← READY / NOT READY / INCOMPLETE VERIFICATION
## ⚠ Tier escalation              ← only when any finding has tier_escalating: true
## Review scope and evidence      ← base, merge-base, HEAD, worktree, intent, instructions
## WP Review Brief                 ← THE primary review artifact
## Summary                         ← detector + pattern-pass severity tally (post-refutation)
## Inline findings                 ← confirmed + narrowed findings (supplementary)
## Refuted findings                ← Step 2c killed these; detector + guard that killed it
## Hooks diff                      ← only when any hook was added/changed/removed
## Verification results           ← exact commands and pass/fail/skip/missing/blocked
## Coverage gaps                  ← unavailable evidence and exclusions
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

Render the hooks-diff block from `references/wp-review-brief-template.md` when any hook changes.

### Report structure — non-WP repo

Use the same verdict, scope, summary, findings, verification, gaps, and positives sections, omitting only WP-specific brief/hooks sections.

### Inline findings (both report shapes)

Render one block per finding with fingerprint/status, file:line, category, severity, headline, evidence, impact, recommended fix, `fix_alternatives` when present, and detectors. For a finding that went through Step 2c, add one line stating it survived refutation (or, for `narrowed`, the original claim and the constraint that bounds it). Separate blocks with `---`.

### Refuted findings

One line per `refuted`/`unreachable` finding: headline, the detector that raised it, and the guard at `file:line` that killed it. Never omit the section when it has entries — a false positive that vanishes silently returns next run.

### What looks good (2–4 bullets)

Non-obvious things done well — prevents review feeling adversarial.

### Verification Checklist

Include an actionable checklist for open Blocking/High findings plus a command table: `command | status | result | significance`.

### Merge verdict

- `NOT READY`: any open Blocking/High finding that survived Step 2c, merge conflict, failed required gate, or violated acceptance criterion.
- `INCOMPLETE VERIFICATION`: base/scope uncertain or material required evidence is missing, blocked, unexpectedly skipped, or excluded.
- `READY`: no open Blocking/High findings, acceptance criteria are traced, scope is complete, and all risk-required gates passed. Medium/Suggestion debt remains visible. When Blocking/High findings were refuted rather than absent, the Refuted-findings section must name the mechanism for each — a `READY` reached by refutation is only as good as the guards it cites.

### Severity and resolution

Load `references/severity-and-resolution.md` before calibrating findings or verifying fixes. Its impact floors and structural-resolution standard are mandatory.

---

## Required behaviours (do not skip)

1. **Always run `ui-to-backend-wiring` and `backwards-compatibility`** regardless of changed file types — they are PR-shape checks, not file-type checks. A PHP-only PR can still introduce a payload-key rename.
2. **Never report a finding outside the closed category vocabulary** — if a real issue doesn't fit a detector, add it to the most-relevant detector's criteria pack and re-run; do not invent a new category at runtime.
3. **Severity is conservative when both mechanism and impact remain ambiguous** — then use `Suggestion`. Never use uncertainty to lower a demonstrated impact floor; promote to `Blocking` only when the criteria pack says so.
4. **Cap each detector at 50 rendered findings.** Prioritize Blocking → High → Medium → Suggestion, report overflow counts as a coverage gap, and never silently discard Blocking/High findings.
5. **Always emit the canonical schema** — even prose-style findings get reduced to the JSON shape before rendering.
6. **Use project vocabulary in headlines** — load applicable repository instructions and context docs first.
7. **Never clear by absence.** Reopen and verify the original mechanism.
7b. **Never refute by absence.** A finding is `refuted` only with a named guard/precondition at `file:line`. "Unlikely", "the caller validates", "tests would catch it" leave the finding `confirmed`.
7c. **Never drop a refuted finding.** It moves to the Refuted-findings section with its killing mechanism, and a row goes to the corpus.
8. **Never report a blocked/missing/skipped gate as passing.** Put it in verification results and coverage gaps.
9. **Never issue `READY` without resolved base/worktree scope, intent traceability, and risk-required repository-native verification.**

## Anti-patterns

- Don't fold `pre-merge-review` back into separate review skills. The merge was intentional — both depth points are available via the mode flag.
- Don't add an eighth detector before exhausting the existing seven. New finding categories belong in an existing detector's criteria pack, not as a new parallel pass.
- Don't report findings in the Summary section without a corresponding Inline-findings block.
- Don't silently drop findings on dedup — always log to stderr what was merged.
- Don't let the detector that raised a finding also refute it, and don't hand the skeptic the detector's reasoning. Refutation by the author of the claim is confirmation wearing a different hat.
- Don't recommend a structural redesign as the fix for a one-line defect. Offer it as the wider alternative and say it deserves its own PR.

---

## Skill workflow

```
/pre-merge-review          ← first run: full multi-detector + pattern-pass review (bounded parallel queue)
/plugin-audit              ← optional: deep security on flagged paths
/php-cs-fixer-style        ← formatting
                           ← fix Blocking + High
/pre-merge-review          ← re-run: confirm fixes, archive prior report
/pr-descriptor             ← write PR description
```

For tiny single-file diffs: `/pre-merge-review light` (skips parallel detectors).
