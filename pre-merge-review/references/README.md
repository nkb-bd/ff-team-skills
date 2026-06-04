# pre-merge-review reference packs

Each pack is an independently-editable checklist owned by one detector or one
language/framework pattern set. Rules come from real PR-review comments in the
WPManageNinja corpus — nothing here is generic best-practice copied from docs.

## What each file covers (in plain English)

### Specialised detectors — one failure category each

| File | Plain-English purpose | Files it inspects |
|---|---|---|
| `detector-accessibility.md` | Keyboard navigation, screen-reader labels, focus rings, ARIA state staleness — "can a non-mouse user use this?" | `.vue`, `.jsx`, `.tsx`, `.scss`, `.css` |
| `detector-async-races.md` | Concurrent / out-of-order async failures: stale responses overwriting fresh ones, retry loops piling up, progress counters double-counting, cancel races | `.vue`, `.jsx`, `.tsx`, `.js`, `.ts` |
| `detector-ui-to-backend-wiring.md` | Does the UI actually reach the backend? Hardcoded stub data, dead CSS, dropped filter context, CTA labels that don't match what they do, broken render fallbacks | **all files** (always runs) |
| `detector-permissions-and-capabilities.md` | Permission / role-based access alignment: does the UI gate match the backend policy capability? Public endpoints missing publication gates, unvalidated redirects, dual-source capability checks. *(This is what "RBAC" used to be called.)* | PHP policies + controllers, Vue files gating by capability |
| `detector-backwards-compatibility.md` | Will this break existing callers? Payload-key renames, default-value flips, response-shape drift, gateway-contract drift, semantic shifts in aggregates, column constraints tightening | **all files** (always runs) |
| `detector-error-handling-ux.md` | What does the user see when the API fails? Blank screens on non-404, loading spinners stuck after errors, filters disappearing when panels collapse, hard-disabled blocks with no recovery path | `.vue`, `.jsx`, `.tsx`, `.js`, `.ts` |
| `detector-performance-and-data-integrity.md` | Performance + data correctness in one pack (they co-occur on the same files): N+1 queries, unbounded `->get()`, repeated transient writes, non-atomic state transitions, string-vs-int data-type bugs | `.php` (controllers, services, models, views, migrations) |

### General language / framework patterns — broad-spectrum checks

| File | Plain-English purpose |
|---|---|
| `patterns-wordpress-php.md` | WordPress + PHP idioms: `wp_unslash` + sanitizer choice, escaping at output, `$wpdb->prepare`, nonce-then-capability order, hook prefix conventions, `get_option` caching |
| `patterns-javascript.md` | Vanilla JS hygiene: null-checked `querySelector`, paired `addEventListener`/`removeEventListener`, `fetch` checking `response.ok`, init inside `DOMContentLoaded` |
| `patterns-vue.md` | Vue 2 Options API idioms: no `setup()`, paired `mounted`/`beforeDestroy` lifecycle, REST client usage, `.catch()` with user-visible messages |

### WordPress plugin review accelerators

| File | Plain-English purpose |
|---|---|
| `wp-review-brief-template.md` | Template + ranking rules + static-check list for the WP-specific review brief. The skill renders this as the **primary review artifact** (above detector findings) when the repo is detected as a WordPress plugin. Also defines the hooks-diff classification (additive vs non-additive) and the tier-escalation callout. |

### Evidence

- `test-corpus.tsv` — 30 representative real review-comment headlines with their expected detector category. Used to validate that detector criteria packs and the headline classifier in `shared/scripts/audit-autharif.sh` are still in sync (target ≥80% accuracy).

## How to add a new rule

1. **Pick the right pack.** Use the table above. If the rule doesn't fit any existing pack, prefer adding it to the closest neighbour rather than creating a new detector — seven detectors is the budget.

2. **Match the section structure.** Every rule has:
   - A `## Rule heading` (sentence-case, no period)
   - One paragraph stating the rule and default severity
   - `**Smell patterns:**` — bullet list of concrete code shapes
   - `**Required pattern:**` (optional) — a small code block showing the fix
   - `**Corpus evidence:**` — pointers to real review-comment headlines with PR # and `file:line`. Use `(local)` if the rule came from in-house experience without an external citation.

3. **Update the detector behaviour section** at the bottom of the pack — the grep/walk pattern the detector should use to find this rule.

4. **Add a test-corpus row** to `test-corpus.tsv` with one representative headline this rule should classify under. Re-run validation:

   ```bash
   bash /Volumes/Projects/Tools/agent-skills/shared/scripts/audit-autharif.sh --validate
   ```

   Must stay ≥80%.

## Project-specific customisation (no forking)

Each pack has a `Project-specific extensions` section near the bottom:

```markdown
<!-- BEGIN project-specific rules -->
<!-- END project-specific rules -->
```

Append your team's rules between those markers. The detector loads them after the base rules. Project rules can reinforce or specialise; they can never replace base rules. If a project rule contradicts a base rule, the base wins — file a PR upstream to fix the base instead.

## Severity discipline

Default severities per pack are conservative. Promote a rule from `Suggestion` → `Medium` → `High` → `Blocking` only after it has fired correctly on a real PR three times and the team agrees the impact warrants the gate. Burning developers with `Blocking` on a rule they don't trust is how this skill becomes ignored — and the whole multi-detector architecture depends on developers actually reading the report.

## Internal category strings (data labels)

The detector files emit findings tagged with short category strings — these stay as machine-readable labels even though the filenames are now plain English. The mapping:

| Category string in NDJSON | File / detector |
|---|---|
| `a11y` | `detector-accessibility.md` |
| `async-state` | `detector-async-races.md` |
| `traceability` | `detector-ui-to-backend-wiring.md` |
| `rbac-alignment` | `detector-permissions-and-capabilities.md` |
| `bc-regression` | `detector-backwards-compatibility.md` |
| `error-state` | `detector-error-handling-ux.md` |
| `perf-and-integrity` | `detector-performance-and-data-integrity.md` |

Short strings stay because they're used for dedup keys, precedence ordering, and the test-corpus TSV — changing them would invalidate the corpus and the validation harness. The plain-English filenames solve the "what does this file contain?" problem without churning the data layer.
