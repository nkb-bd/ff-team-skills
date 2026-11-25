# Performance + Data Integrity Criteria

Used by `pre-merge-review` detector `perf-and-integrity`. Load when any `.php` (Controllers,
Services, Models, Views, Migrations) file has changed.

These two categories are combined because the autharif corpus shows they co-occur
on the same files (controllers, services, migrations) at high rates — splitting
them into two detectors produced redundant findings during corpus dedup.

---

## N+1 query patterns

A query inside a `foreach` / `while` / `array_map` / `Collection::map` loop is
N+1. The fix is always: pre-fetch the related rows in one query, key by ID, look up
in PHP.

**Smell patterns:**
- `foreach ($variations as $v) { Product::find($v->product_id); }`
- `array_map(fn($id) => $wpdb->get_row(...), $ids)`
- `$contacts->map(fn($c) => $c->customFields()->get())` without `with('customFields')`
- `foreach ($products as $p) { $p->categories(); $p->gallery(); }` — two N+1s in one loop
- **Helper-indirection:** `foreach ($forms as $form) { $rows[] = ['entries' => Helper::entryCount($form->id)]; }` — the loop body contains no query token at all; the `COUNT(*)` lives inside the helper. Token-grepping the loop body misses this entirely.

**Required pattern:** Eloquent `with()`, raw SQL `IN()`, or `SELECT FROM ... WHERE id IN (...)` + PHP-side `array_column` indexing. For helper-indirection: a batch variant of the helper (`entryCounts(array $ids)` → one `GROUP BY` query, map results to rows).

**Corpus evidence:**
- "N+1 variation selects during backfill" (`fluent-cart#1647`, `ProductVariationMigrator.php`)
- "Per-product taxonomy and gallery lookups during export" (`fluent-cart#1658`, `ProductController.php:203`)
- "Bulk contact import performs repeated per-row lookups" (`fluent-crm#1826`, `ContactTools.php:626`)
- "Campaign list computes stats with per-row aggregate queries" (`fluent-crm#1826`, `CampaignTools.php:66`)
- "N+1 entry count queries in list-forms" (`fluentform#1011`, `FormTools.php:190`) — `FormAccess::entryCount($form->id)` per row; missed by this detector across three runs because the query was one helper-call deep and the loop body matched no query token

---

## Unbounded query

`->get()`, `->all()`, `->find()` on tables that grow with usage (subscribers,
customers, orders, contacts, posts, comments, products, transactions) without a
`->limit()` / `->where()` / `->take()`.

**Smell patterns:**
- `Contact::all()`, `Order::all()`, `Subscriber::get()` with no constraints
- `$wpdb->get_results("SELECT * FROM {$table}")` without LIMIT
- A controller endpoint accepting `?per_page=N` without capping N
- `whereIn(...)->get()` where the `IN` list comes from request data, saved
  settings, serialized post meta, option values, or filter output without a
  validated max count before the query

**Required pattern:** cap caller-controlled or settings-controlled ID lists before
querying (`array_slice`, explicit counter, or validated `per_page` max), sanitize
IDs before `whereIn`, and select only the columns needed on frontend render paths.

**Corpus evidence:**
- "Unbounded reply eager-load on public review listing" (`fluent-cart#1641`, `ProductReviewFrontendController.php:69`)
- "Unbounded product query allowed via per-page setting" (`fluent-cart#1638`, `ProductsCollection.php:295`)
- "Selected export can exceed API page cap and truncate records" (`fluent-cart#1658`, `useExport.js`)

---

## Materialize-then-reduce (aggregate in PHP instead of SQL)

A `->get()` / `->all()` / `$wpdb->get_results()` whose result is **only** consumed by
a `foreach` (or `array_sum`/`array_reduce`/`collect()->sum()`) that computes a total,
a `count()`, or a `GROUP BY`-shaped map. The rows are loaded solely to be reduced —
work the database should do. **This is distinct from "Unbounded query": even a
`->where()`-scoped, span-clamped `get()` is a bug here**, because memory still scales
with the number of matching rows when the DB could return a single aggregate row (or
one row per group). Clamping the date span does **not** fix it — the row count inside
the window is still unbounded.

**Smell patterns:**
- `$rows = $q->get(); foreach ($rows as $r) { $total += $r->amount; }` → `SUM(amount)`
- `count($q->get())` → `$q->count()`
- `foreach ($rows as $r) { $byKey[$r->plan] += $r->amount; }` → `GROUP BY plan, SUM(amount)`
- top-N-by-group built by loading all rows, grouping in PHP, `arsort`, `array_slice(…, N)`
  → `GROUP BY … ORDER BY SUM(...) DESC LIMIT N`

**Ask:** "Is every field read from these rows only being summed/counted/grouped?" If yes,
the `->get()` should not exist — push the reduction into the query. Memory then bounds to
O(1) (totals) or O(distinct groups), not O(all rows).

**Required pattern:** `selectRaw('COUNT(*) … SUM(…) …')`, `groupBy(...)`, `orderByRaw`,
`limit` — return the reduced result. Keep any per-group PHP fallback (e.g. a `?:` label
coalesce) running over the *grouped* result, not the raw rows.

**Corpus evidence:**
- "Subscription report materializes every matching row" (`fluentformpro#249`, `ReportHelperPro::getSubscriptions`) — `$query->get()` then a PHP loop summed recurring totals and built a top-5-plans chart over a caller-controlled window; a 366-day span clamp did not bound the rows. Fix: `COUNT`/`SUM` + `GROUP BY (plan_name, item_name)`.

---

## Redundant duplicate scans (query-per-category)

The **same** scan executed once per category — a per-type / per-status / per-bucket
helper called N times (`getX($a)` then `getX($b)` …) where a single query grouped by
that dimension would return every category in one pass. Each call re-scans the same
table over the same window with only the category filter changed.

**Smell patterns:**
- `getPaymentsByType($s, $e, 'subscription')` **and** `getPaymentsByType($s, $e, 'onetime')`
  on the same table/window → one `GROUP BY transaction_type` scan
- a `foreach ($statuses as $st) { $totals[$st] = countWhereStatus($st); }` → `GROUP BY status`
- calling the same report helper once per form when a `GROUP BY form_id` covers all

**Watch the delegation trap:** consolidating a hand-rolled query into a shared per-category
helper can *introduce* this — "one call per type" reads clean but doubles the scans vs a
prior single grouped query. When a refactor replaces one query with N helper calls, count
the scans before/after.

**Required pattern:** one query grouped by the category dimension (returning both/all
categories), then let each caller read its slice from the single result.

**Corpus evidence:**
- "Payment summary now scans transactions twice" (`fluentform#1113`, `ReportTools::getPaymentSummary`) — delegated to `getPaymentsByType()` once per type = two transaction range-scans where the prior code did one grouped scan; a regression re-introduced by the delegation. Fix: a single `getPaymentBreakdown()` grouped by `(transaction_type, status, currency)`.

---

## Aggregated integer overflow on 32-bit PHP

A SQL aggregate over a monetary/counter column — `SUM(amount_in_cents)`, `SUM(quantity)` — cast to `(int)` in PHP. On 32-bit PHP `PHP_INT_MAX` is 2,147,483,647; a cents SUM past ~$21.4M silently overflows to a wrong/negative number. Grep is clean on 64-bit dev boxes, so this never reproduces locally — reason about it, don't test-and-move-on.

**Smell patterns:**
- `(int) $row->total_cents`, `(int) $row->sum_amount` where the column is `SUM()`/`COUNT()` of money or a growing counter
- `intval($aggregate)` before a `/ 100` money conversion

**Required pattern:** cast summed money to `(float)` (exact for integers up to 2^53 ≈ $90T) before dividing, or use `bcmath`/string math if exactness beyond that matters. `(int)` is fine only for values provably under 2^31 (a single row's column, a bounded count).

**Corpus evidence:**
- "Aggregated cents can overflow on 32-bit PHP" (`fluentformpro#249`, `ReportHelperPro::getSubscriptions`) — `(int) SUM(recurring_amount)` on the subscription totals; fixed to `(float)`.

---

## Repeated filter predicates without a supporting index

A query (especially one a caller can invoke repeatedly, or over a caller-controlled date range) filters a growing table by the same non-PK columns — `WHERE created_at BETWEEN … AND status IN (…) [AND form_id = …]` — and the table has **no index** covering those columns. Each call is a full scan; the report may run several such scans per invocation.

**How to check:** read the table's migration (`CREATE TABLE`) and list its keys. Match the report's `WHERE`/`GROUP BY`/`ORDER BY` columns against them. Note the query *shapes* (all-forms vs form-scoped) — the index's leading column should match the most-selective equality predicate common to them.

**Required pattern:** add an index suited to the predicates (equality columns first, then the range), in an **upgrade** migration that also alters existing tables — not only the initial `CREATE` (which skips installed sites). Verify the migration's trigger actually runs on in-place updates, not just activation. **Own the index where the table is owned** — grep both repos; adding it to a duplicated migration in the wrong plugin is a cross-boundary duplication smell.

**Corpus evidence:**
- "Subscription report filters lack a supporting index" (`fluentformpro#249`, `ReportHelperPro::getSubscriptions`) — filters `created_at`/`status`/`form_id` on `fluentform_subscriptions` with only a PK. Note: the table is owned by the *free* plugin, so the index belongs in the free migration, not the Pro reporting PR.

---

## WordPress-API queries without bounds

The Eloquent rule above doesn't catch WordPress-native query functions, but
the same unbounded-retrieval problem applies. Default arguments for these
APIs return *all matching rows*, which on a tag/term/post table can grow
unboundedly with usage and frequently produces duplicates the caller forgets
to dedupe.

**Smell patterns:**
- `get_terms(['taxonomy' => $tax])` without `number` — returns every term
- `get_terms(['taxonomy' => $tax, 'object_ids' => $ids])` without `number` and
  without `array_unique()` on the result — duplicate-tag bug, one tag per
  object association
- `get_posts(['post_type' => $type])` without `numberposts` / `posts_per_page`
  (default `numberposts` for `get_posts` is 5, but `WP_Query` is unbounded —
  easy to mix up)
- `get_users(['role' => $r])` without `number`
- `wp_get_object_terms($ids, $tax)` over a large `$ids` set without
  post-processing dedup
- `new WP_Query(['post_type' => ...])` without `posts_per_page`

**Required pattern:** every WP-API query gets an explicit `number` /
`posts_per_page` / `numberposts` argument with a validated cap. Tag/term
retrievals that could return per-object duplicates either pass `fields =>
'ids'` + `array_unique` or use `wp_get_object_terms` with explicit dedup.

**Severity:** **High** for unbounded retrieval on tables that grow with usage
(terms, posts, users, comments, postmeta). **Medium** when the result is
clearly bounded by upstream constraints but still missing the explicit cap.

---

## Refactor-moved query without re-establishing bounds

A "refactor: extract method" / "modularize" / "split into helpers" diff that
*moves* an existing query into a new method or file is the highest-miss
category for unbounded-query bugs. The query line itself is unchanged, so it
doesn't appear as a red diff line — but the move is the right moment to add
the missing `LIMIT` / `DISTINCT` / `number` / `posts_per_page` / `array_unique`
that the original code lacked.

**Detection rule for the detector:** when a PR's commit messages include
`Refactor`, `REFACTOR`, `modularize`, `extract`, `split`, or the diff shows a
function being moved (large `-` block in one file matched by a large `+`
block in another with similar contents), re-evaluate every query in the moved
code against the unbounded-query and WP-API-bounds rules above as if it were
new code. Pre-existing absence of bounds is NOT an excuse to leave them
absent in the new location.

**Smell patterns:**
- `git diff` shows a method moved from `Controller` into a new
  `Handler`/`Service` — the query inside has `->get()` with no `->limit()`,
  unchanged from the original
- A "shortcode flow extracted into discrete normalize/query/hydrate/render
  methods" diff where the new `query` method runs `get_terms()` without a
  `number` argument
- A "modularize" diff where `wp_get_object_terms()` is moved into a helper
  with no dedup added downstream

**Required pattern:** treat moved queries like new queries. Add bounds during
the refactor or note explicitly why they are intentionally absent.

**Corpus evidence:**
- `pr-reviewer-build-2026-05-15` — `fluent-player-pro` PlaylistShortcodeHandler
  refactor: tag-playlist path was factored into normalize/query/hydrate/render
  methods. The tag-retrieval query at `app/Hooks/filters.php:55` was moved
  into the new structure unbounded; reviewer treated the diff as
  "structure-only, no behavior change" and did not re-evaluate the query.
  Corpus evidence: this codebase has had two prior commits fixing the same
  class of bug (`88c7a1ae PERF: Cap language media source queries`,
  `c91609b8 FIX: Remove per-item tag queries from media pagination`) — a
  recurring pattern that refactor-anchored review should not have missed.

**Severity:** inherited from the underlying query rule (Eloquent unbounded /
WP-API unbounded / N+1 / etc.). The "refactor" framing does not lower
severity — it raises detection priority.

---

## Repeated transient writes / option writes on read paths

`set_transient()` / `update_option()` / `wp_cache_set()` called inside a loop or
inside a hook that fires multiple times per request, especially when the cached
value isn't actually changing.

**Smell patterns:**
- `update_option()` inside `the_post`, `template_include`, or `init` hooks
- Per-iteration `set_transient` inside a render loop
- Cache-set without a corresponding cache-get short-circuit

**Required pattern:** read once, cache once, render N times.

**Corpus evidence:**
- "Repeated transient writes in non-frontend renders" (`fluent-cart#1638`, `ProductsCollection.php:421`)
- "Repeated full PMPro analysis on preview remount" (`fluent-members#162`, `_PmproPreview.vue`) — overlaps with async-state but the cause is also perf

---

## Non-unique lookup updates only one record

Lookup-by-non-unique-column followed by single-record-update. The DB can have
many matches; the code processes one and silently leaves the others stale.

**Smell patterns:**
- `Subscription::where('parent_order_id', $id)->first()->update(...)` when `parent_order_id` can match multiple subscriptions
- `$wpdb->get_row(...)->update(...)` on a column without a UNIQUE constraint
- `Post::where('post_status', 'draft')->first()` used to "find the post" when many drafts exist

**Required pattern:** if the column is non-unique, either iterate (`->get()->each()`)
or add a UNIQUE constraint to the schema. The single-record path is silently wrong.

**Corpus evidence:**
- "Non-unique parent_order lookup updates only one subscription" (`fluent-cart#1662`, `OrderController.php:755`)
- "Zero-total COD activation also only touches first matching subscription" (`fluent-cart#1662`, `CodHandler.php`)
- "Inconsistent subscription activation path across entrypoints" (`fluent-cart#1662`, `CodHandler.php`)

---

## Defaulted identifier reused as storage key

Code that generates artifacts (forms, feeds, configs, schemas) from component
templates/defaults, where some template field doubles as a **storage key**
downstream (submission response key, meta key, array index, slug). If the
generator doesn't supply that identifier, every instance of the same template
inherits the same default — and the first time a consumer builds two of the
same type, their stored data collides silently (last write wins).

The local diff looks complete: it passes type + label, the save pipeline
accepts it, a single-field test works. The bug only appears by asking "which
of these template fields is a KEY, and who guarantees it's unique per
instance?" — that's domain knowledge about the storage layer, not visible in
the generator's own file.

**Smell patterns:**
- A create/builder API forwarding `type` + `settings` into a template-merge
  pipeline (`wp_parse_args($field, $template)`) without setting the template's
  `name`/`key`/`slug` attribute
- Downstream storage keyed by that attribute (`$responses[$field['name']]`,
  `update_post_meta($id, $field['key'], ...)`)
- A fallback like `$name = $input['name'] ?? $template['name']` with no
  uniqueness pass over the generated collection

**Required pattern:** the generator owns key uniqueness — derive from a
caller-supplied label/slug, fall back to the default, and uniquify across the
generated set (`_1`, `_2` suffixes) before save.

**Detection rule:** for every changed create/generate/build path that merges
caller input over component defaults, list the template attributes that act as
keys anywhere downstream (grep consumers for indexing by that attribute), and
verify the generator uniquifies them per instance.

**Severity:** **Blocking** when the colliding key stores user-submitted data.

**Corpus evidence:**
- "MCP-created repeated field types reuse duplicate storage keys"
  (`fluentform#1011`, `FormTools.php:123`) — create-form passed type + label
  only; `AiFormBuilder` kept the component-default `attributes.name`, so two
  text fields shared the `input_text` response key and submitted values
  overwrote each other. Missed because the generator file read fine in
  isolation — the key-ness of `attributes.name` lives in the submission
  storage layer.

---

## Meta uniqueness not enforced when assumed

Code that reads a meta key and treats it as a single value while writing the same
key from multiple paths without UNIQUE / single-row enforcement.

**Smell patterns:**
- `get_post_meta($id, 'tax_status', true)` while `update_post_meta` is called from
  filters that don't always replace
- `wp_insert_user_meta` followed by `meta_query` reading "the" value of a key that
  has multiple rows
- `add_post_meta(..., $value, false)` with downstream code expecting one row

**Corpus evidence:**
- "Tax status meta is not uniquely enforced" (`fluent-cart#1679`, `TaxManager.php`)

---

## Range / interval allows inverted bounds

A scheduling / range / window input that accepts `start` and `end` without checking
`start <= end` will silently store an inverted range that breaks downstream logic
(empty ranges, negative durations).

**Smell patterns:**
- `Schedule::create(['start' => $req->start, 'end' => $req->end])` with no order check
- Date-range filter UI that doesn't constrain the second picker by the first
- Form validation that catches "missing" but not "out-of-order"

**Corpus evidence:**
- "Range schedule allows inverted date ranges" (`fluent-crm#1826`, `CampaignTools.php:892`)

---

## Caller-controlled range without a span clamp

A query bounded by caller-supplied range parameters (`date_from`/`date_to`,
timestamps, id ranges, offsets) is NOT bounded work just because it has `where`
clauses. If nothing limits the **span** of the range, the caller controls scan
size and output size — a 10-year window over a high-volume table forces a large
scan/aggregate and (for `GROUP BY` day/bucket queries) an unbounded number of
output rows. The unbounded-query rule above misses this because the query
*does* have `->where()` constraints.

**Smell patterns:**
- `where('created_at', '>=', $from)->where('created_at', '<=', $to)` where
  `$from`/`$to` come from request/tool params and no maximum window is enforced
- `selectRaw('DATE(created_at) as day, COUNT(*)')->groupBy('day')` whose bucket
  count is caller-controlled (one row per day in the requested window)
- An export/report/trend endpoint clamping `per_page` carefully while leaving
  the date window unclamped — same class of input, inconsistent treatment

**Required pattern:** clamp the span the same way `per_page` is clamped: define
a max window (e.g. 366 days), validate after defaulting, return the API's
invalid-param error when exceeded. Mention the cap in the param description so
callers (especially AI agents) self-correct.

**Severity:** **Medium** on authenticated/admin surfaces, **High** when the
endpoint is reachable by low-privilege roles or the table is unbounded-growth
(submissions, orders, logs).

**Corpus evidence:**
- "Unbounded trend date range" (`fluentform#1011`, `ReportTools.php:136`) —
  get-submissions-trend accepted any valid date_from/date_to span; the review
  validated date *format* and *order* but never asked "how wide can this get?"

---

## Pre-cleanup not atomic with status update

Schedule-cleanup / publish flow that first deletes / nullifies records then writes
the new status. If the second write fails, the record is in a half-state.

**Smell patterns:**
- `delete from old_targets where campaign_id = ?` followed by `update campaigns set status = 'draft'` without a transaction
- "Pre-schedule cleanup" that empties dependent tables but leaves the parent's
  status pointing to the now-empty data

**Required pattern:** wrap multi-step state changes in a DB transaction. If a
transaction is impossible (cross-service writes), use a state-machine column with
intermediate values that downstream code knows to ignore.

**Corpus evidence:**
- "Pre-schedule cleanup is not atomic with draft status update" (`fluent-crm#1826`, `CampaignTools.php`)

---

## Key-name match without positional anchoring (recursive walker over-reach)

When a recursive walker visits every node of a decoded document (form meta,
options blob, settings JSON, API payload) and dispatches on the **key name
alone**, any rule written for one context silently applies everywhere that name
occurs. The rule is correct where it was meant to fire and destructive where it
was not. Severity: **High** — it corrupts unrelated third-party data on the
write path, and the corruption is invisible until someone re-imports.

Ask for every key-specific rule inside a recursive walker: *what anchors this
to the node I meant?* If the answer is "the key is called X", that is not an
anchor — it is a name collision waiting for an add-on to pick the same word.

**Smell patterns:**
- `sanitizeNode(&$node)` recurses into every array/object member and calls
  `applyRule($key, $value)` for each; `applyRule()` is a chain of
  `if ('some_key' === $key) { return transform($value); }`.
- A sanitizer written for `$field['attributes']['x']` reached instead by key
  name, so `$settings->integrations->x` and `$design->widget->x` get it too.
- Generic words as keys: `autocomplete`, `type`, `mode`, `display`, `format`,
  `value`, `status`, `class`. The more generic the word, the more certain the
  collision.
- The transform is **lossy for non-matching input** (returns `''`, a default,
  or `absint()`), so a boolean/array/object under the same key is destroyed
  rather than passed through.

**Required pattern:** anchor on position, not name — sanitize the container
when you reach it, so the rule can only reach members of that container:

```php
if ('attributes' === $key) {
    $value = self::sanitizeFieldAttributes($value);   // scoped to this node
}
```

…rather than `if ('autocomplete' === $key)` evaluated at every depth.

**How to verify (do not read-only this one):** construct a document carrying the
key in an *unrelated* branch — a boolean, an array, a nested config object —
run it through the walker, and assert those values are unchanged while the
intended one is transformed. A source read cannot distinguish the two cases.

**Watch for the sibling rules.** This defect arrives by copy-paste: a new
`if ('x' === $key)` added beside existing ones inherits their scoping bug. When
you find one, enumerate every branch in the same dispatcher and report the
whole set, noting which are pre-existing.

**Corpus evidence:**
- `fluentform-dev#1246` (2026-09-24) — `TransferService::sanitizeJsonNode()`
  walks all decoded form meta and calls `sanitizeAttributeControlSetting($key,
  $value)` at every depth. A new `if ('autocomplete' === $key)` branch rewrote
  *every* JSON property named `autocomplete` — an add-on's boolean flag became
  `''`, a nested select2 config object became `''` — because `sanitize()`
  returns `''` for anything outside its token allowlist. Caught by a human PR
  reviewer, **not** by this skill: the detector had been asked "is the import
  path sanitized?" and correctly answered yes. Three sibling branches
  (`max_repeat_field`, `display_mode`, `display_type`) carry the same flaw and
  predate the PR.

## Normalizer output assigned to destructive destination

When a normalizer / sanitizer / transformer function can return `''`, `null`,
`[]`, or any falsy "I couldn't parse this" value, callers MUST NOT assign that
output to a destination column that treats empty as a wipe (`post_content`,
`post_title`, `meta_value` written via `update_post_meta`, etc.). The
combination — defensive-empty-on-failure + unconditional-assign — silently
destroys existing data on malformed input. Severity: **Blocking** when the
destination is a content column users have authored data into.

**Smell patterns:**
- Function `normalizeFoo($input)` has paths that return `''` (validation
  failure, unsupported format, regex no-match). A caller does
  `$model->foo = normalizeFoo($input)` with no guard.
- `extract<Resource>($payload)` returns empty array on absent key; caller
  assigns to a column that's persisted via `wp_update_post`.
- Controller `sanitizeData()` returns scrubbed array including a key whose
  value normalized to `''`; downstream `Model::save()` writes the empty
  value over existing content.

**Required pattern:** either guard the assignment:

```php
$normalized = normalizeFoo($input);
if ($normalized !== '' && $normalized !== null) {
    $model->foo = $normalized;
}
```

Or treat the empty normalization output as a validation failure and return
4xx before reaching the write call.

**Corpus evidence:**
- `pr-reviewer-build-2026-05-11` — pr-reviewer's blind run on
  `fluent-player-dev#352` flagged `MediaController.php:222` with this exact
  pattern: `sanitizeMediaData()` runs `normalizeMediaPostContent()` which
  returns `''` when no `fluent-player/media` block is found; `prepareMedia()`
  then unconditionally assigns `$media->post_content = ''` and `Media::save()`
  writes it via `wp_update_post`, destroying existing content. The
  block-PHP path guards against this with `if (!$normalizedPostContent) return;`
  but the controller path does not.

When reviewing, grep changed PHP for `normalize`, `extract`, `sanitize`,
`parse` function definitions. For each, trace callers — every assignment of
the return value to a model attribute or `update_post_meta` key is a
potential finding. Confirm a guard exists between normalizer and assignment.

---

## Auxiliary source populates a primary keyed aggregate (enrich vs populate)

When a function returns a collection **keyed by some dimension** (currency, form,
user, day, status) and builds it from **more than one source**, each source is
either a **populate** source — it defines *which keys exist* — or an **enrich**
source — it only *adds fields to keys that already exist*. The bug is an enrich
source that silently creates keys: a baseline/previous/comparison/default/fallback
fold calls `ensure($k)` / `$map[$k] ??= …` / `$map[$k] = …` instead of guarding
with `if (isset($map[$k]))`. The result carries phantom entries — zero-total,
zero-count keys that no primary row produced — and any downstream consumer keyed
on the map's **emptiness or cardinality** (an "empty ⇒ no results" branch, a
`count() > 1 ⇒ multi-*` flag, a "dominant key" pick) is now wrong.

This is the set-membership cousin of the boolean two-axis grid (SKILL Pass I.2):
draw the membership grid for primary set A and auxiliary set B and walk **every**
cell, especially **B-only**:

```
              in A (current)     not in A
in B (prev)   enrich A[k]  ✅     ← MUST NOT create A[k]  (the usual miss)
not in B      A[k] only    ✅     n/a
```

**Smell patterns:**
- Two loops over two datasets writing the same accumulator; the second loop
  (previous/baseline/prior/comparison/fallback/default) calls the same
  `ensure()`/create helper as the first instead of a membership guard.
- A "growth", "delta", "trend", "vs previous period" computation whose baseline
  rows are folded into the per-key output rather than only into a scalar total.
- A LEFT/OUTER join or `array_merge` of a secondary map where only-right-side /
  only-in-B entries get carried into a result meant to represent A.
- A blended scalar (blended total/growth) and a per-key breakdown built in the
  same pass — correct blended math but the per-key map over-populated.

**Required pattern:** the enrich source updates existing keys only; its scalar
contribution (for blended math) is kept separately so totals stay unchanged:

```php
foreach ($previousRows as $r) {
    $prevBlendedTotal += $r->amount;          // scalar baseline: every row counts
    if (isset($byKey[$r->key])) {             // per-key: enrich, never populate
        $byKey[$r->key]['prev'] += $r->amount;
    }
}
```

**Degenerate-input probe (do this, don't reason about it):** feed **empty primary
+ non-empty auxiliary** (no current rows, history exists) and trace the real
return value. If the documented "empty ⇒ no-results / zero" contract does not
hold — or a `multi-*`/cardinality flag flips — that's the finding. This single
probe catches the whole class and belongs in the test suite as its own case.

**Corpus evidence:**
- `fluentformpro#251` (`ReportHelperPro.php:290`) — the subscription report's
  previous-period loop called `ensure($code)`, so a currency present only in the
  growth-baseline window created an empty `by_currency` block; a report with no
  current subscriptions but historical data returned non-empty currency blocks
  and the MCP layer reported data (and `multi_currency`) instead of its "No active
  subscriptions" result. Fix: guard `if (isset($byCur[$code]))`; keep adding every
  previous row to the blended baseline scalar.

Severity: **High** (silent wrong output + broken empty-state contract); **Blocking**
when the contaminated cardinality/emptiness drives an authorization or billing
branch.

---

## GROUP BY / ORDER BY alias shadows a raw column (silent regroup)

A query selects a **normalization expression** under an alias that happens to
match a real column name — `COALESCE(NULLIF(s.plan_name,''), NULLIF(s.item_name,''), '…') AS plan_name`,
`UPPER(COALESCE(x.currency, ?)) AS currency` — then writes `GROUP BY plan_name`
or `GROUP BY currency`. In MySQL, GROUP BY resolves an unqualified name to a
**FROM-clause column first, the select-list alias only if no column matches**. So
the query silently groups by the *raw* column, not the expression: rows the
expression would separate get merged under one arbitrary label with a summed
value, and rows the expression would unify (`NULL` vs `''`, `usd` vs `USD`) split
into duplicate groups. A downstream PHP re-aggregation by the projected value can
mask the *duplicate-split* half, but the *merge* half is lost in SQL and
unrecoverable — top-N / breakdown output is corrupted.

**Smell patterns:**
- `SELECT <expr> AS name … GROUP BY name` (or `ORDER BY name`) where `name` is
  also a column in any FROM/JOIN table. Especially `plan_name`, `currency`,
  `status`, `type`, `name`, `title` — common column names reused as aliases.
- The expression normalizes (`COALESCE`, `NULLIF`, `UPPER`, `LOWER`, `IFNULL`,
  `CASE`) so raw-column grouping ≠ expression grouping.

**Required pattern:** group/order by the **select ordinal** or repeat the
expression — never the bare shadowing alias:

```sql
SELECT UPPER(COALESCE(NULLIF(x.currency,''), ?)) AS currency,
       COALESCE(NULLIF(s.plan_name,''), NULLIF(s.item_name,''), 'Unnamed') AS plan_name,
       SUM(s.amount) AS amount_cents
FROM …
GROUP BY 1, 2          -- ordinals bind to the SELECT expressions, not raw columns
ORDER BY amount_cents DESC
```

**Corpus evidence:**
- `fluentformpro#251` (`ReportHelperPro.php:247`) — `GROUP BY currency, plan_name`
  grouped by raw `sub.currency` + raw `s.plan_name`; two subscriptions with
  `plan_name=''` and distinct `item_name`s ("Alpha", "Beta") collapsed into one
  arbitrary label with the combined amount, corrupting `top_plans`. Fixed with
  `GROUP BY 1` / `GROUP BY 1, 2`.

Severity: **High** (silent data corruption in aggregate output).

---

## Shared resources and historical records

When a change deletes a resource referenced by saved records, trace the stored identifier through candidate selection, the database prefilter, the final comparison and the deletion target.

- **Equivalent representations.** Use two ordinary records that refer to the same resource using supported stored representations, for example a plain filename and a percent-encoded URL. Test both deletion orders. The first deletion must preserve the resource for the survivor and the final deletion must remove it. Check that the SQL prefilter admits every representation accepted by the comparison.
- **Schema changes after capture.** Save a record under the original schema, rename or remove its field, then load the current schema in a fresh request and delete the historical record. Check the resource on disk or in storage. Run a control with an unrelated file that should survive. Check what evidence still identifies a resource as managed before recommending broader cleanup.

Report which boundary was exercised and distinguish a failed lookup from an observed deletion. Examples: fluentform-dev#1642, review threads B-592F84B9 and B-D475582D.

## Test coverage skipped on data-integrity surface

A test marked `skip()`, `markTestSkipped(...)`, or `@group skip` on a feature whose
correctness is data-integrity sensitive (refunds, status transitions, payment
verification) is a Blocking finding regardless of why it's skipped.

**Corpus evidence:**
- "Skipped data-integrity coverage" (`fluent-cart#1648`, `RefundOrderCest.php:32`)

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

1. For every changed PHP file, grep for the loop-with-query pattern: `foreach (`,
   `while (`, `array_map(` containing `->get()`, `->all()`, `->first()`,
   `->find()`, `$wpdb->get_`, or any `Model::` static call. Emit N+1 findings.
1a. **Indirection follow-through.** For every *other* function/method call inside
   a loop body (helper statics, `$this->` methods, service calls), resolve the
   callee when it is defined in the changed files or the same module and check
   its body for the query tokens from rule 1. One level of indirection is
   mandatory; two when the intermediate is a trivial delegator. A loop body with
   zero query tokens is NOT evidence of no N+1 (corpus: `fluentform#1011`
   `FormAccess::entryCount` — missed three runs in a row by token-grepping).
2. For every `->get()` / `->all()` / `->find()` without a preceding `->where()` or
   `->limit()` chain, emit unbounded-query finding.
2a. For every `whereIn(...)->get()`, trace the source of the `IN` list. If it
   comes from request data, saved settings, serialized post meta, option values,
   or filter output and is not capped before the query, emit an unbounded-query
   finding even though the query has a `whereIn`.
2b. For every WordPress-API query — `get_terms(`, `get_posts(`, `get_users(`,
   `get_comments(`, `wp_get_object_terms(`, `new WP_Query(` — verify a `number`
   / `posts_per_page` / `numberposts` argument is present in the args array. For
   `wp_get_object_terms(` and `get_terms( ... 'object_ids' => ... )`, also
   verify the result is `array_unique`'d or queried with `'fields' => 'ids'`
   followed by dedup. Missing → emit unbounded-query finding (severity High).
2c. **Refactor-mode re-scan.** If the resolved review-scope commit log returns
   any commit whose subject matches `/refactor|modularize|extract|split/i`, OR
   the diff shows large `-` blocks in one file matched by similar large `+`
   blocks in another file (function move), re-run rules 2, 2a, and 2b against
   every query in the moved code as if it were freshly added — pre-existing
   absence of bounds does not exempt the new location. Emit findings even when
   the query line itself is unchanged.
3. For every `update_option(` / `set_transient(` / `wp_cache_set(` inside a hook
   callback or loop, emit repeated-write finding.
4. For every lookup-and-update pattern (`->where(...)->first()->update(...)` or
   `get_row(...)` with assignment then update), check the WHERE column has a
   UNIQUE constraint in any migration. If not, emit non-unique-lookup finding.
5. For every `Schedule::`, `DateRange::`, `Window::`, or similar create call with
   `start` + `end` args, verify a range-validation guard exists. If not, emit
   inverted-range finding.
5a. For every query whose `where` bounds come from caller-supplied range params
   (`date_from`/`date_to`, `start`/`end`, timestamps), verify a **maximum span**
   is enforced after defaulting (not just format/order validation). Missing →
   emit range-span finding (severity per the "Caller-controlled range without a
   span clamp" rule). `GROUP BY` time-bucket queries get this check even when
   every other bound is present.
6. For every multi-table state change in a controller (delete + update, insert + update),
   verify a `DB::transaction(` / `$wpdb->query('START TRANSACTION')` wraps it. If
   not, emit atomicity finding.
7. For every test marked skipped that touches a data-integrity surface, emit a
   Blocking finding.
7a. **Enrich-vs-populate scan.** For every function returning a map/assoc array
   keyed by a dimension that is built from **two or more** loops/sources, identify
   the primary (defines keys) and any auxiliary source whose loop matches
   `/previous|prior|baseline|comparison|delta|growth|fallback|default/i` or a
   LEFT/OUTER-join / `array_merge` of a secondary map. If that auxiliary loop
   creates keys (`ensure(`, `$m[$k] =`, `$m[$k] ??=`) instead of guarding with
   `isset($m[$k])`, emit an enrich-vs-populate finding, AND construct the
   empty-primary + non-empty-auxiliary input to confirm the emptiness/cardinality
   contract of every downstream consumer still holds. Severity High (Blocking when
   the map's emptiness/cardinality drives an auth or billing branch).
   Corpus: `fluentformpro#251`.
7b. **GROUP BY / ORDER BY alias-shadow scan.** For every changed query with a
   `GROUP BY`/`ORDER BY` naming an unqualified identifier, check whether that
   identifier is BOTH a select-list alias built from an expression AND a real
   column in any FROM/JOIN table. If so, emit an alias-shadow finding (require
   `GROUP BY <ordinal>` or the repeated expression). Watch `plan_name`, `currency`,
   `status`, `type`, `name`, `title`. Corpus: `fluentformpro#251`.
8. Default severities: `Blocking` for skipped data-integrity tests, non-atomic
   state changes, non-unique lookup updates; `High` for N+1, unbounded queries,
   inverted ranges, enrich-vs-populate leaks; `Medium` for repeated writes and meta-uniqueness assumptions.
9. Emit findings with `category: "perf-and-integrity"` for performance issues, `"data-integrity"`
   for correctness issues. Both belong to this single detector. Cap at 50 combined.
