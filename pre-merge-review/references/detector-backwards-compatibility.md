# Backward-Compat Regression Criteria

Used by `pre-merge-review` for the `bc-regression` detector. **Always runs**, regardless of file types.

This pack extends Pass A (Breaking Changes) of the sequential pattern passes.
Rules here cover failure modes Pass A misses: payload-key renames, default-value
flips, response-shape drift, gateway/loader contract drift, aggregate semantic
changes, and **non-additive hook-contract changes** (the tier-escalating signal
that drives WP-plugin tier upgrades).

---

## Cross-plugin paired-release contract widening (version-skew fatal)

When a paired-plugin pair (free + pro, host + addon, library + consumer) ships
a contract change in lockstep — typically widening a `private`/`protected`
method to `public`, adding a new method, or introducing a new class — the
**consumer side** (pro / addon) calling the new surface without a runtime
guard will hard-fatal on every install that updates the consumer first but
hasn't yet updated the provider. A `Requires X >= Y` line in `readme.txt` is
**not** a runtime guard — it gates the *next* update prompt, not the *current*
fatal.

Specific to WP plugin pairs (FluentForm ↔ Pro, FluentCRM ↔ Pro, etc.) and any
similar free/pro split where the two are installed and updated independently
by the site owner.

**Smell patterns:**

- Free PR: `-private function renderFormHtml(` → `+public function renderFormHtml(`
  paired with Pro PR: `$x->renderFormHtml(...)` — no `is_callable` / `method_exists` guard.
- Pro PR adds `new \Free\Namespace\NewClass()` — no `class_exists(...)` guard.
- Pro PR adds `Free\Helper::newStaticMethod(...)` — no `is_callable` /
  `method_exists` guard on the static target.
- Pro PR adds a call to a newly introduced free hook (`apply_filters('free/new_hook', ...)`)
  *and the call's return is required* (e.g. `if (apply_filters('free/new_hook', false))`)
  — running on an old free where no handler exists is fine for filters, but if the pro
  side assumes a *handler will fire* (e.g. expects a side-effect from
  `do_action`), an old free silently degrades.
- Pro PR description / changelog says "requires free X.Y.Z" with no
  `version_compare(FLUENTFORM_VERSION, 'X.Y.Z', '>=')` check before the call.
- `readme.txt` `Requires Fluent Forms` bumped, but no runtime guard in PHP.

**Why `Requires` in readme is not enough:**

- A site running pro 6.3.0 with free 6.2.2 will fatal on every page-load that
  hits the pretty-URL handler, even though WP-admin shows an "update available"
  notice. The site owner sees a White Screen of Death, not the update notice.
- Auto-updaters do not enforce the `Requires` field consistently across hosts.
- Many sites disable auto-updates entirely and update on a schedule.
- The pro plugin is loaded *before* WP renders the admin update screen.

**Required pattern:**

Wrap every paired-release call to a newly-exposed free surface with a runtime
guard that respects PHP visibility rules:

```php
// PUBLIC INSTANCE METHOD — is_callable from outside the class returns
// false when the method is still private on the old free version.
$conversationalForm = new \FluentForm\App\Services\FluentConversational\Classes\Form();
if (is_callable([$conversationalForm, 'renderFormHtml'])) {
    $conversationalForm->renderFormHtml($formId, $providedKey);
    return;
}
// Fallback path that still works on the old free version.

// PUBLIC STATIC METHOD — method_exists returns true for private static methods
// too, so use is_callable (which respects scope from outside the class).
if (is_callable(['\FluentForm\App\Helper', 'newStaticMethod'])) {
    \FluentForm\App\Helper::newStaticMethod(...);
}

// NEW CLASS — class_exists is the right guard.
if (class_exists('\FluentForm\App\NewService')) {
    (new \FluentForm\App\NewService())->run();
}

// NEW HOOK whose handler the pro relies on being present in free
if (has_action('fluentform/new_hook')) {
    do_action('fluentform/new_hook', $payload);
} else {
    // explicit fallback
}
```

**`method_exists` is wrong for visibility widening.** It returns `true` even
for private methods, so it will *not* catch the "still private on old free"
case. Use `is_callable` (called from outside the class) — it respects scope.

**Detection:**

When reviewing a paired PR (signals: PR description references a sibling repo,
branch name matches across two repos, body mentions "paired with #N" or
"requires free X.Y.Z", or the diff references a class/method from a different
plugin namespace), for each cross-plugin call site:

1. Identify the qualified target (class + method, class constructor, static
   method, hook name).
2. Check the sibling PR's diff for visibility changes (`private` → `public`,
   `protected` → `public`), new class additions, new hook introductions.
3. For every newly-exposed target, search the consumer-side call site for one of:
   - `is_callable([...])` immediately before the call,
   - `class_exists(...)` immediately before `new ...`,
   - `has_action(...)` / `has_filter(...)` immediately before the dispatch,
   - `version_compare(FLUENTFORM_VERSION, 'X.Y.Z', '>=')` immediately before.
4. If no guard is found, emit a finding.

**Finding template:**

```json
{
  "category": "bc-regression",
  "severity": "High",
  "headline": "Pro calls newly-public Form::renderFormHtml without is_callable guard",
  "evidence": "SharePage.php:213 — `$conversationalForm->renderFormHtml($formId, $providedKey)` paired with free PR widening this method from private to public. Sites with pro-updated-first will fatal with 'Cannot access private method' until free is also updated.",
  "impact": "Hard fatal (White Screen of Death) on every conversational pretty-URL hit when free is older than the paired release. WP admin update notice will not save the user from the WSOD because the fatal happens before WP can render that notice on the public page hit.",
  "recommended_fix": "Wrap the call in `if (is_callable([$conversationalForm, 'renderFormHtml']))`. On false, fall back to the previous (pre-fix) rendering path or a graceful 'feature requires free X.Y.Z' notice.",
  "detectors": ["bc-regression"]
}
```

Default severity: **High** (silent fatal on partial-update window). Escalate to
**Blocking** when the affected code path is on a public URL (every visitor
WSODs, not just admins).

**Corpus evidence:**

- "Pro pretty-URL handler calls newly-public free `renderFormHtml` without guard"
  (`fluentformpro` PR #209, `SharePage.php:213` — fixed before merge by adding
  `is_callable` check during pre-merge-review re-run).

---

## Filter / hook / action payload key renamed without compatibility

Changing the key of an array passed through `apply_filters()` / `do_action()` /
emitted to the frontend breaks every external listener / consumer. Renaming
without leaving the old key in place is a hard break.

**Smell patterns:**
- `$payload['contact_id']` becomes `$payload['contactId']` — every plugin filtering
  this hook is now broken
- Filter `'fluentform/save_form_data'` payload `['form' => $form]` → `['formData' => $form]`
- AJAX/REST response renames `total_count` to `totalCount` (or vice versa)

**Required pattern:** when renaming, keep both keys for at least one minor version
and add a `_deprecated_argument` notice when the old one is read.

**Corpus evidence:**
- "Filter payload key renamed without compatibility" (`fluent-crm#1827`, `AdminMenu.php`)

---

## Default-value flip that propagates to call sites

Changing the default of a setting / function arg / model attribute changes behavior
for every caller that didn't explicitly pass a value. The change is silent at the
call site but visible in production.

**Smell patterns:**
- `function getPosts($limit = 10)` → `function getPosts($limit = 50)`
- `'sort_by' => 'date'` → `'sort_by' => 'popularity'` in default options array
- `data() { return { showLegend: true } }` → `data() { return { showLegend: false } }`
  in a shared chart component

**Required pattern:** when changing a default that any caller relies on, either
(a) make the arg required and update every caller in the same PR, or (b) keep the
old default and add a new arg/setting that opts into the new behavior.

**Corpus evidence:**
- "Backward-compat default is overridden in caller" (`fluent-cart#1673`, `ProductsCollection.php`)
- "Sort-by default behavior changed across renderer call sites" (`fluent-cart#1673`, `ShopAppRenderer.php`)
- "Missing-setting path overrides sort-by default to disabled" (`fluent-cart#1673`, `ProductsCollection.php`)

---

## Response shape drift between server and client

Backend response shape changes (field added, removed, renamed, or moved one level)
without corresponding frontend update. Frontend reads `response.data.foo` while
backend now sends `response.payload.foo`.

**Smell patterns:**
- Controller change: `return $this->sendSuccess(['data' => $items])` → `return $this->sendSuccess(['items' => $items])`
- Model change: `toArray()` adds/removes/renames a field; some Vue component reads
  the old name
- Pagination wrapper change: `{ items, total }` → `{ data, meta: { total } }`

**Required pattern:** every server shape change must be paired with a frontend update
in the same PR, OR the old shape must be preserved alongside the new one.

**Corpus evidence:**
- "State endpoint contract mismatch" (`fluent-members#162`, `_PmproMigration.vue:259`)
- "Migration state response shape mismatch" (`fluent-members#162`, `_PmproMigration.vue:259`)

---

## Gateway / loader contract hardcoded to a specific provider

A "generic" payment / loader / connector contract that takes a specific provider's
shape (Stripe-shaped intent, Mailchimp-shaped audience, etc.) and rejects others.
Severity: **High** when the generic contract has multiple consumers.

**Smell patterns:**
- `loadGateway($config)` that returns `{ stripe_intent_id, stripe_publishable_key }`
  even when called for Razorpay
- A "generic" loader that hardcodes `stripe.confirmPayment(...)` in the success
  branch
- Contract docs say "any gateway" but implementation has `if (gateway === 'stripe')` everywhere

**Corpus evidence:**
- "Gateway loader contract is hardcoded to Stripe-specific output" (`fluent-members#147`, `_public.scss`)

---

## Aggregate count semantic change

A function returning a count, total, or aggregate that subtly changes what's
included/excluded. Callers see the same name but a different number.

**Smell patterns:**
- `getTotalContacts()` previously included all statuses, now filters to non-bounced
- `getRevenue()` previously gross, now net
- Dashboard stat cards reading these aggregates show "wrong" numbers without warning

**Required pattern:** add a new function with the new semantics
(`getActiveContactCount`) and keep the old one. Or version the report.

**Corpus evidence:**
- "Total contact count now excludes non-default statuses" (`fluent-crm#1794`, `ReportingController.php:323`)

---

## Column constraint shrunk without backfill

Database column changing from `TEXT` → `VARCHAR(120)`, `BIGINT` → `INT`, nullable →
NOT NULL, or longer-precision DECIMAL → shorter without a backfill / data migration.
Existing rows that overflow will fail or truncate on next write.

**Smell patterns:**
- Migration adds `$table->string('subject', 120)` to a column previously TEXT
- AI-generated content stored to a column smaller than the model's max output
- `unsigned()` added to a column that may have negative values historically

**Required pattern:** schema-shrinks must include a pre-shrink "validate" migration
that fails if any existing row violates the new constraint, OR a "truncate-with-warning"
migration that emits a notice for each truncated row.

**Corpus evidence:**
- "AI subject/preheader can exceed campaign column limits" (`fluent-crm#1810`, `BlockComposer.vue:1039`)

---

## Non-additive hook-contract change (TIER-ESCALATING)

WordPress plugins ship hooks (`do_action`, `apply_filters`) as part of their
public contract — themes, sibling plugins, and customer-written snippets hook
them. A non-additive change to a hook silently breaks every dependent without a
test ever failing. This is the **#1 silent-failure mode** in WP plugins.

The rule:

- A hook change is **additive** when existing hookers continue to work unchanged:
  - New hook added
  - New argument **appended at the end** of an existing hook (existing handlers ignore extra args)
  - PHPDoc / inline-comment-only changes
- A hook change is **non-additive** when any existing handler would break or
  silently misbehave:
  - Hook removed entirely
  - Hook renamed (treat as remove + add)
  - Argument removed from the middle or end
  - Argument position reordered
  - Argument type changed (scalar → array, int → string, single value → object)
  - The same hook now fires under different conditions in a way that changes
    payload semantics (e.g. previously fired pre-save, now fires post-save)

**Smell patterns:**
- A line `-do_action( 'myplugin/order_saved', $order );` paired with
  `+do_action( 'myplugin/order_completed', $order );` → rename, non-additive.
- `-apply_filters( 'myplugin_pricing', $price, $product_id );` paired with
  `+apply_filters( 'myplugin_pricing', $price, $product_id, $context );` →
  additive (new arg at end). **Note:** appending an arg is only safe when
  existing PHP handlers ignore it; for `apply_filters` returning a value, ensure
  the new arg is not required for the handler to compute the return.
- `-apply_filters( 'myplugin_pricing', $price, $product_id );` paired with
  `+apply_filters( 'myplugin_pricing', $price, $cart_item );` → arg type
  changed (scalar `int` → `array`), non-additive.
- `-do_action( 'myplugin_legacy_tax', $tax );` with no replacement → removal,
  non-additive.

**Detection:**

For every changed PHP file, grep the diff for `do_action(` and `apply_filters(`
calls — both removed lines (`-`) and added lines (`+`). Pair them by hook name.
For each pair, compare the arg lists:

| Removed | Added | Classification |
|---|---|---|
| `do_action( 'foo', $a, $b )` | `do_action( 'foo', $a, $b, $c )` | additive |
| `do_action( 'foo', $a, $b )` | `do_action( 'foo', $a, $c )` | **non-additive** |
| `do_action( 'foo', $a, $b )` | (nothing) | **non-additive** (removed) |
| (nothing) | `do_action( 'foo', $a, $b )` | additive (new hook) |

When a removed hook and an added hook have **different names but identical
argument lists in the same file within ~20 lines of each other**, treat the
pair as a **rename** — non-additive.

**Required pattern:**

Non-additive changes must either:

(a) **Keep the old hook firing** alongside the new one for at least one minor
    version, with a `_deprecated_hook()` notice marking it for removal:

```php
do_action( 'myplugin/order_completed', $order );

// Deprecated: kept for backwards compatibility until v3.0.
if ( has_action( 'myplugin/order_saved' ) ) {
    _deprecated_hook( 'myplugin/order_saved', '2.5.0', 'myplugin/order_completed' );
    do_action( 'myplugin/order_saved', $order );
}
```

(b) **Be flagged as a Breaking change** — bump the PR tier, document the
    contract change under "For developers" in the changelog, schedule a
    deprecation window.

**Finding emission — TIER-ESCALATING flag:**

When the detector finds a non-additive change, it MUST emit the finding with
an additional `tier_escalating: true` field in the canonical schema:

```json
{
  "category": "bc-regression",
  "severity": "Blocking",
  "tier_escalating": true,
  "file": "includes/class-pricing.php",
  "line": 42,
  "headline": "Filter myplugin_pricing arg-type change is non-additive",
  "evidence": "apply_filters('myplugin_pricing', $price, $product_id) → apply_filters('myplugin_pricing', $price, $cart_item) — arg 2 changed from int to array.",
  "impact": "Every third-party handler reading arg 2 as $product_id will now receive an array and silently produce wrong prices.",
  "recommended_fix": "Add a new filter with the new signature (e.g. 'myplugin_pricing_v2') and keep the original firing with the old args for backwards compatibility. Document deprecation timeline in changelog.",
  "detectors": ["bc-regression"]
}
```

The `tier_escalating` flag tells the report renderer to surface the
**Tier escalation callout** at the top of the brief (see
`wp-review-brief-template.md`). It does **not** automatically modify the
`new-feature` tier — the human reviewer reads the callout and decides.

**Corpus evidence:**
- "Hook removed without deprecation shim" (local — WP plugin pattern)
- "Filter signature changed mid-arg-list breaks downstream consumers" (local)

---

## Project-specific extensions

Teams using this pack in their own repo can append rules below this line
without modifying the base pack. Each appended rule MUST follow the same
structure: smell patterns, required pattern, corpus evidence (or `(local)` if
no shared corpus), severity. Rules added here are loaded by the detector
alongside the base rules.

<!-- BEGIN project-specific rules -->
<!-- END project-specific rules -->

---

## Detector behavior

When this criteria reference is loaded, the detector MUST:

1. For every PHP file changed, grep added lines for `apply_filters(` / `do_action(`
   and check whether any pre-existing call to the same hook in the codebase passes
   the old payload shape. Emit a finding if shape changed without a compatibility shim.
2. For every public method whose default arg was modified, identify all callers
   (search with `rg`). If any caller doesn't explicitly pass the arg, emit a finding.
3. For every controller response shape change, scan changed Vue / JSX for the old
   field path and emit a finding if it's still being read.
4. For every database migration, check column type / constraint shrinks. Emit a
   finding if no backfill migration accompanies it.
5. For every aggregate / count / sum function whose body changed, emit a finding
   noting the semantic shift, even if a fix isn't obvious. Severity: `High` minimum.
6. **For every changed PHP file**, grep diff for `do_action(` and `apply_filters(`
   on both removed (`-`) and added (`+`) lines. Pair by hook name. Classify each
   pair as **additive** or **non-additive** per the table in the "Non-additive
   hook-contract change" section. Emit a finding for every non-additive change
   with `tier_escalating: true`. Severity: `Blocking`.
6a. **Cross-plugin paired-release scan.** If the PR description, branch name,
    or diff references a sibling plugin (free ↔ pro, host ↔ addon), or the diff
    instantiates / calls a class from a *different* plugin namespace:
    - Identify every cross-plugin call site (`new \Free\Foo()`, `Free\Foo::bar()`,
      `$x->method()` where `$x` is a free-plugin class).
    - For each, check the sibling PR (or via `gh pr view` if branch names match
      across repos) for visibility changes / new class additions / new hooks
      introduced *in this release pair*.
    - Emit a finding when a newly-exposed surface is called without a runtime
      guard (`is_callable`, `class_exists`, `has_action`, `version_compare`).
    - **`method_exists` does NOT count** as a guard for visibility widening —
      it returns `true` for private methods. Flag it explicitly if seen.
    - Severity: `High`; escalate to `Blocking` when the call site is on a
      publicly-reachable URL (e.g. `template_redirect`, `wp`, `init` with
      front-end side effects).
7. Default severities: `High` for filter-payload renames, response-shape drift,
   aggregate semantic change, gateway-contract drift; `Blocking` for column shrinks
   without backfill **and** for non-additive hook changes; `Medium` for
   default-value flips.
8. Emit findings with `category: "bc-regression"`. Cap at 50.
