# Error-State UX Criteria

Used by `pr-reviewer` detector `error-state`. Load when any `.vue`, `.jsx`, `.tsx`,
`.js`, or `.ts` file with async surface has changed.

The rule: every async fetch must have a non-success path that the user sees.
"Stuck loading," "blank screen on error," "modal that won't close after a 500" —
these are all symptoms of code that handles success but not failure.

---

## Blank UI on non-404 fetch errors

Fetch that handles `404` gracefully but renders an empty white page on `5xx`,
network failure, or `403`. The user sees nothing and doesn't know what happened.

**Smell patterns:**
- `if (response.status === 404) showNotFound(); else render(response.data)` — what
  about 500?
- `try { ... } catch { /* swallow */ }`
- `axios.get(url).then(r => this.data = r.data)` with no `.catch` (the error
  bubbles to a generic handler that does nothing visible)

**Required pattern:** every fetch must lead to either rendered content, a "loading"
state, or an explicit error UI. Generic error UI ("Something went wrong, retry?")
is acceptable as a fallback.

**Corpus evidence:**
- "Blank UI on non-404 fetch errors" (`fluent-cart#1642`, `ViewSite.vue:7`)
- "Missing generic API-error UI state in site details page" (`fluent-cart#1642`, `ViewSite.vue:343`)

---

## Network failure rendered as domain-specific error

Showing "Membership not found" or "Order does not exist" when the actual problem is
a network timeout, 500 server error, or auth failure misleads the user into thinking
the resource is missing.

**Smell patterns:**
- `if (!response) showNotFound()` where `!response` is true for both 404 and network failure
- `catch (e) { this.error = 'Membership not found' }` — the user retries forever
  thinking the URL is wrong
- Error message strings hardcoded to a domain interpretation regardless of which
  failure tier hit

**Required pattern:** branch on error type. 4xx with `not_found` code → domain
error; network/5xx → "Connection problem, please retry"; 401/403 → "You don't have
access."

**Corpus evidence:**
- "Network failures are shown as 'Membership not found'" (`fluent-members#127`, `MembershipManage.vue:35`)

---

## Severity promotion: user-visible content-loss paths are always Blocking

Before scoring any finding in this pack, check whether the silent-failure can
cause **user-visible content loss** — the user believes their save succeeded
but their authored content is gone, partially missing, or out of sync with
the visible UI. Examples: silent sync failure after "Save", silent settings
write that fails after the editor closed, partial save where one half persists
and the other half doesn't. **These findings are Blocking, not Medium**,
regardless of how cleanly the rest of the criteria pack would score them.

**Smell patterns that trigger promotion:**
- The user clicked "Save" / "Publish" / "Apply" and the UI showed success.
- A backend write in the same flow failed silently (no toast, no log surfaced
  to UI, no `$message.error()`).
- The failure happens AFTER the UI's modal/editor has already closed (no
  retry path possible without re-opening the same data).
- The user has authored content (text, settings, blocks) that the failure
  loses.

**Required pattern:** every async write that can fail MUST surface failures
to the user before they navigate away. Either via:
- An inline toast/notice on the same surface
- A persistent banner that survives navigation until acknowledged
- Forcing the modal to stay open until the write confirms

**Corpus evidence:**
- "Silent sync failure after lesson save" (`fluent-player-dev#352`,
  `fluent-player-block.jsx:94:119`) — autharif marked this as blocker-level
  Important. pr-reviewer's local run initially scored it Medium under the
  generic "hidden failures" rule; this severity-promotion rule corrects
  that calibration.

When reviewing, ask: "If this write fails silently, what does the user lose?"
If the answer is content they authored, the finding is Blocking.

---

## Loading flag stuck on after error

A `loading` / `submitting` / `importing` flag set to `true` before fetch and reset
to `false` only in `.then()` will stay `true` forever if the fetch rejects.
Modal stays disabled, button stays grey, page never recovers.

**Smell patterns:**
- `this.loading = true; await api.fetch(); this.loading = false` (with no try/finally)
- Loading reset only in success branch; error branch silently passes
- `try { this.loading = true; await api.fetch() } catch { /* nothing */ }` (loading is leaked)

**Required pattern:**
```js
this.loading = true
try {
  await api.fetch()
} catch (e) {
  this.error = e
} finally {
  this.loading = false  // ALWAYS reached
}
```

**Corpus evidence:**
- "Import failure leaves modal stuck in loading state" (`fluent-crm#1791`, `UserImportManager.vue:91`)
- "Source fetch failure leaves migration page stuck loading" (`fluent-members#157`, `Migration.vue`)
- "PMPro wizard initialization can hang forever" (`fluent-members#157`, `_PmproMigration.vue`)
- "Campaign action stays locked after API failure" (`fluent-crm#1791`, `CampaignActions.vue:5`)

---

## Failures hidden from progress / activity log

Live import logs / progress streams that render `successful_records` but silently
drop `failed_records` make the operation look like it succeeded. Users only notice
when downstream data is missing.

**Smell patterns:**
- Log component renders `entries.filter(e => e.status === 'success')` and ignores `e.status === 'error'`
- Progress total counts only successes; the user sees "100/100 complete" but 30 failed silently
- Backend returns `{ ok: 70, failed: 30 }`; frontend uses only `ok`

**Required pattern:** failures must be rendered with the same visual weight as successes.
Activity logs should color or icon-mark errors and surface them in the summary.

**Corpus evidence:**
- "Live import log renders blank messages" (`fluent-members#162`, `_PmproProgress.vue`)
- "Checklist save failures are hidden" (`fluent-members#162`, `_PmproChecklist.vue`)
- "Inactive-level warning hidden for string allow_signups" (`fluent-members#162`, `_PmproLevelMapper.vue`)

---

## Filter / search clearing does not refresh results

A filter / search input whose "clear" button resets the input but doesn't refire
the query produces stale results that don't match the now-empty filter UI.

**Smell patterns:**
- `clearFilter() { this.searchTerm = '' }` — no follow-up `runSearch()`
- "Reset" button that clears state but the table continues to render the filtered set
- Toggle that clears one filter but leaves a related dependent filter applied

**Corpus evidence:**
- "Clearing input does not refresh filtered results" (`fluent-members#148`, `SearchFilter.vue:64`)

---

## Applied filters become invisible when their UI is hidden

Filter chips / summary indicators that hide along with the filter editor panel,
even though the filters are still being applied to the query. User can't tell why
the result set is what it is.

**Smell patterns:**
- `<el-tag v-if="panelOpen">{{ filter }}</el-tag>` (chips disappear when panel collapses, but the query still uses the filter)
- Single boolean flag gates BOTH "show editor" and "render summary chips"

**Required pattern:** chip / summary visibility derives from `hasAppliedFilters`,
not from `panelOpen`. Panel and chip are independently controlled.

**Corpus evidence:**
- "Applied filters become invisible when panel is collapsed" (`fluentform#922`, `Entries.vue:156`)

---

## Wrong group / chip removable from summary

A "remove this filter" chip that uses the post-filter index to identify which
group to remove will remove the wrong group when the source array has gaps.

**Smell patterns:**
- `<el-tag v-for="(g, i) in groups.filter(g => g.length > 0)" @close="$emit('remove', i)">`
- The `i` index here is the displayed-index, NOT the source-index. Parent removes
  the wrong group.

See `patterns-vue.md` "Index Stability in List Rendering"
for the canonical pattern. This rule overlaps with that one — flag once.

**Corpus evidence:**
- "Wrong filter group can be removed from summary chips" (`fluentform#922`, `_AppliedFilterSummary.vue`)

---

## Unconditional loader on a not-yet-available surface

A loader / preview / iframe / setup script that runs unconditionally even when the
prerequisite (checkout enabled, gateway configured, license active) isn't met.
At minimum, wastes resources; at worst, throws errors users can't dismiss.

**Smell patterns:**
- `loadStripe(key)` called on page mount even when Stripe isn't configured
- `<iframe :src="checkoutUrl">` rendered when `checkoutUrl` is null/empty
- Init scripts that error-loop because their dependency was disabled

**Corpus evidence:**
- "Unconditional gateway loader on unavailable checkout" (`fluent-members#147`, `checkout.php`)

---

## Promo / upsell / banner is hard-disabled

A promo / upsell / what's-new component whose render is gated by a hardcoded `false`
or a build flag. Either it should ship enabled or the component should be deleted.
Hard-disabled code is dead code.

**Corpus evidence:**
- "Promo/upsell section is hard-disabled" (`fluent-crm#1801`, `DynamicSegmentPromo.vue:171`)

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

1. Walk every changed Vue / JSX / TSX / JS / TS file.
2. For each `await` / `.then(` / `axios` / `fetch` / `XMLHttpRequest`, verify the
   error path leads to user-visible UI (a `catch`, a `.catch`, a try/catch, or a
   route-level error handler).
3. For each `loading` / `submitting` / `isImporting` / similar flag, verify it is
   reset in `finally` or the catch branch.
4. For each filter / search / progress component, verify error states render with
   the same visual treatment as success states.
5. For each unconditional loader / mount-time fetch, verify the prerequisite check.
6. For each `v-if="false"` / `:if(false)` / `false &&` JSX, flag as
   hard-disabled.
7. Default severities: `High` for stuck loading flags and blank-on-error;
   `Medium` for hidden failures, wrong-error-type, hard-disabled blocks;
   `Suggestion` for unconditional loaders.
8. Emit findings with `category: "error-state"`. Cap at 50.
