# Performance + Data Integrity Criteria

Used by `pr-reviewer` detector `perf-and-integrity`. Load when any `.php` (Controllers,
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
2c. **Refactor-mode re-scan.** If `git log origin/dev...HEAD --oneline` returns
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
8. Default severities: `Blocking` for skipped data-integrity tests, non-atomic
   state changes, non-unique lookup updates; `High` for N+1, unbounded queries,
   inverted ranges; `Medium` for repeated writes and meta-uniqueness assumptions.
9. Emit findings with `category: "perf"` for performance issues, `"data-integrity"`
   for correctness issues. Both belong to this single detector. Cap at 50 combined.
