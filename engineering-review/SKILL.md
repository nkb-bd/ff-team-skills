---
name: engineering-review
description: Pre-merge engineering review for any PR type — feature, fix, refactor, PHP, JS, Vue, schema. Covers breaking changes, regression risk, code quality, WordPress patterns, performance, and backwards compatibility. Writes findings to a persistent file and can be re-called to check which issues have been fixed.
---

# Engineering Review

Run this before every PR is marked ready for review. Works for any PR type. Complements (does not replace) `plugin-audit` (deep security) and `php-cs-fixer-style` (code style).

## Two Modes

**First run** — no existing review file: do the full 8-pass review, write findings to `openspec/changes/<branch-slug>/ENGINEERING-REVIEW.md` (or repo root if no openspec dir).

**Re-run** — review file already exists: read the file, re-check every OPEN finding, update status to FIXED / STILL OPEN / NEEDS MANUAL TEST, report how many remain.

---

## Step 0 — Orient

```bash
git diff origin/dev...HEAD --stat       # what files changed
git log origin/dev...HEAD --oneline     # commits on this branch
git diff origin/dev...HEAD              # full diff
```

Identify PR type: Feature / Bug Fix / Refactor / Schema Change / JS / Vue / Mixed.
Determine output path: `openspec/changes/<branch-slug>/ENGINEERING-REVIEW.md`

---

## Pass 1 — Breaking Changes (all PR types)

**Question:** Does this PR change anything external code depends on?

**PHP:**
- Public method signatures changed? → `_deprecated_function()` wrapper keeping old signature?
- Hook names changed? → old name still fires?
- REST endpoint URL, method, or response shape changed? → version bump?
- `get_option` / `update_option` key changed? → old data migrated?

**JavaScript:**
- `window.*` globals removed or renamed?
- Custom event names or payload shapes changed? → old shape still supported?
- CSS class names removed that themes or JS might target?

**Database:**
- Column renamed, dropped, or type changed? → data migrated first?
- New `NOT NULL` column without a default? → breaks existing rows on write.

Flag anything changed with no migration path or deprecation notice.

---

## Pass 2 — Regression Risk (all PR types)

**Question:** What currently-working behaviour could this break?

For each changed file:
1. What feature/flow does it belong to?
2. What did it do before — is it still doing all of that?

**High-risk patterns:**
- Conditional added around previously unconditional code → does the fallback path work?
- Early `return` added → does it skip anything that must still happen?
- Default value changed → what breaks on first read before anyone saves the new setting?
- Code moved to new file → are all callers updated?
- Hook priority changed → does it now run before or after something it depends on?
- `isset()` replaced with direct access → does the key always exist in all contexts?

---

## Pass 3 — Code Quality (all PR types)

**Dead code:**
- Imported symbols never called
- Functions defined but never invoked
- Conditional branches that can never be true

**Duplication:**
- Logic copied instead of calling the existing function
- Same `get_option()` call in two new methods that could share a helper

**Complexity:**
- Functions over ~50 lines doing more than one thing
- Nesting deeper than 3 levels
- Magic strings/numbers used in more than one place → extract to a constant

**Naming:**
- Method names that don't describe what they do
- Boolean variables without `is`/`has`/`should` prefix
- `public` methods only called internally → should be `private`/`protected`

---

## Pass 4 — WordPress PHP Patterns (PHP PRs)

**Sanitization:**
- Every `$_GET`/`$_POST`/`$_REQUEST` value sanitized with the right sanitizer for the type
- `wp_unslash()` applied before sanitizing

**Escaping:**
- Every `echo`/`print` of a variable uses the correct escape function for context (`esc_html`, `esc_attr`, `esc_url`, `esc_js`)
- No raw `echo $variable`

**Queries:**
- Every `$wpdb` call with a variable uses `$wpdb->prepare()`
- No `$wpdb->query()` with string concatenation

**Options:**
- `get_option()` not inside loops
- `get_option()` not called twice for the same key without a static cache
- `ArrayHelper::get($arr, 'dot.key', $default)` used instead of nested `isset()` ternaries

**Hooks:**
- Hook names follow the project's naming convention (e.g. `fluentform/` prefix)
- `do_action()` argument list documented inline for third-party authors

---

## Pass 5 — JavaScript Patterns (JS PRs)

**Null safety:**
- Every `document.querySelector()` result null-checked before method calls
- Every `e.target.closest()` result null-checked

**Event handling:**
- `addEventListener` in setup has a matching `removeEventListener` in teardown
- No `document.addEventListener` inside a function that can be called multiple times (leak)

**DOM ready:**
- Initialization that queries the DOM is inside `DOMContentLoaded` or a `readyState` check — not at module evaluation time

**Correct pattern:**
```js
function init() { document.querySelectorAll('.target').forEach(setup); }
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else { init(); }
```

**Async:**
- `fetch()` checks `response.ok` — a 4xx/5xx does not throw
- `.catch()` shows a user-visible message

**Bundling:**
- `require()` inside `if/else` → both files always bundled (document if intentional)
- Dynamic `import()` needed for true code splitting

---

## Pass 6 — Vue 2 Patterns (Vue PRs)

- Options API only (`data()`, `computed`, `methods`, `watch`) — no `setup()`, `ref()`, `reactive()`
- `addEventListener` in `mounted()` has matching `removeEventListener` in `beforeDestroy()`
- `$on()` / `$root.$on()` has matching `$off()` in `beforeDestroy()`
- `setInterval`/`setTimeout` cleared in `beforeDestroy()`
- API calls use the project's REST client — not raw fetch
- All API calls have `.catch()` with a user-visible error message
- Props have type and `default` or `required` defined

---

## Pass 7 — Performance Quick-Check (PHP PRs)

Flag obvious issues only. Use `plugin-audit` for a deep pass.

- New `get_option()` or DB call inside a hook that fires on every page load?
- `->get()` on a model without `->where()` or `->limit()`? → full table scan
- DB call inside a `foreach` loop? → N+1
- New `add_action`/`add_filter` registered on every request that could be registered once at boot?

---

## Pass 8 — Backwards Compatibility (Feature PRs)

- New PHP setting: does the default preserve existing behaviour for users who have never saved it?
- New JS variable from PHP: what happens if the key is `undefined` on old cached pages?
- New DB column: does every read handle `NULL` gracefully for existing rows?
- New hook: named following convention? Documented in changelog?
- Removed feature: deprecation notice added? UI warning shown?

---

## Output Format

```markdown
# Engineering Review — <PR title / branch>
**Date:** YYYY-MM-DD | **PR type:** Feature / Fix / Refactor / Mixed

## Severity Summary
| Severity | Count |
|---|---|
| Critical | N |
| High | N |
| Medium | N |
| Code Smell | N |

## Critical — Fix Before Merge
### C-01: <short title>
- **File:** path/to/file:line
- **Evidence:** short code quote
- **Impact:** what breaks for which users
- **Fix:** concrete action

## High — Significant Regression Risk
[same structure]

## Medium
[same structure]

## Code Smells
[same structure]

## Verification Checklist
- [ ] C-01: description
- [ ] H-01: description
```

### Severity definitions

| Level | Definition |
|---|---|
| **Critical** | Active breakage — crash, data loss, security hole, silent wrong behavior |
| **High** | A documented feature stops working or behaves differently |
| **Medium** | Correctness, performance, or maintainability issue — no user-visible breakage |
| **Code Smell** | Design issue, dead code, naming — no immediate user impact |

---

## Re-run Mode

When `ENGINEERING-REVIEW.md` already exists:
1. Read the file, collect all OPEN findings
2. For each finding, re-check the current code (grep-verifiable or read+reason)
3. Update the verification checklist — check off fixed items
4. Report: "X of Y findings resolved. Z critical issues remain."
5. Do NOT re-run all 8 passes — only check the open findings

---

## Workflow with Other Skills

```
/engineering-review    ← first: catch everything (any PR type)
/plugin-audit          ← deep security on high-risk paths flagged above
/php-cs-fixer-style    ← formatting
fix Critical + High
/engineering-review    ← re-run to confirm fixes
/pr-descriptor         ← write PR description
```
