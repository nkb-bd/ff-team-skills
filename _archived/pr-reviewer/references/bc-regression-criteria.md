# Backward-Compat Regression Criteria

Used by `pr-reviewer` detector `bc-regression`. **Always runs**, regardless of file types.

This pack extends `engineering-review`'s Pass 1 (Breaking Changes). The rules here
cover failure modes Pass 1 misses: payload-key renames, default-value flips,
response-shape drift, gateway/loader contract drift, and aggregate semantic changes.

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
6. Default severities: `High` for filter-payload renames, response-shape drift,
   aggregate semantic change, gateway-contract drift; `Blocking` for column shrinks
   without backfill; `Medium` for default-value flips.
7. Emit findings with `category: "bc-regression"`. Cap at 50.
