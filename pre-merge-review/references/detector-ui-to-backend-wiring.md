# Traceability Criteria

Used by `pr-reviewer` detector `traceability`. **Always runs**, regardless of which
file types changed. Traceability is a PR-shape check, not a file-type check.

The rule: every new UI control, route, setting, CTA, menu item, or config flag
introduced in this PR must close its end-to-end chain inside the same PR.
"Phase 2 is coming next sprint" is not closure.

---

## New CTA must reach a working handler

Every new button / link / menu item / route must be traced from click → handler →
service/db → response → render. Stub handlers, placeholder return values, and
`// TODO` markers in the render path are blockers.

**Smell patterns:**
- Controller method body returning `[]` / `null` / `{ data: [] }` with no actual implementation
- New REST route registered, controller method exists, but the controller's first line is `return $this->sendSuccess([]);`
- New menu item routes to a Vue page whose entire template is `<h1>Coming soon</h1>` or contains hardcoded sample data
- "Phase 2" / "Step 2" CTA whose `@click` handler runs `this.$router.push('/foo')` where `/foo` doesn't exist

**Required:** the chain produces real data from real services and renders real UI in
the SAME PR. If the feature is genuinely incremental, hide the CTA behind a feature
flag — don't ship a dead button.

**Corpus evidence:**
- "PMPro routes are wired to nonfunctional handlers" (`fluent-members#162`, `PmproMigrationController.php`)
- "PMPro route chain terminates in stubs" (`fluent-members#157`, `PmproMigrationController.php:93`)
- "Phase 2 CTA enters unimplemented wizard path" (`fluent-members#163`, `_PmproMigration.vue`)
- "Phase 2 CTA leads to unavailable flow" (`fluent-members#162`, `_PmproChecklist.vue`)
- "Broken route-to-detail trace for site rows" (`fluent-cart#1640`, `_SiteTable.vue`)
- "Cancel action becomes unreachable in embedded contexts" (`fluent-members#136`, `MembershipManage.vue:31`)

---

## Settings toggle must reach the renderer

A new settings flag added to the editor must have a code path from save → store →
render that ACTUALLY uses the flag. Common bug: toggle is added to the editor and
saved into post meta, but the template / Vue render / PHP view never reads it.

**Smell patterns:**
- Editor adds `settings.behavior.showNavButtons` but no template references `showNavButtons` (or its PHP-rendered counterpart)
- PHP view only ever sets a fallback default; no caller ever overrides it
- Default value present in two places (PHP defaults, JS defaults) — they drift

**Required:** trace the new flag from editor save handler → backend storage → PHP
render variable → final template branch. All four steps must exist in the diff or
in adjacent files referenced by the diff.

**Corpus evidence:**
- "Behavior toggles are not wired to PHP render variables" (`fluent-player-dev#341`, `bottom-controls.php`)
- "Free-path setting-to-render chain is not locally traceable" (`fluent-player-dev#341`, `bottom-controls.php:46`)

---

## Hardcoded dummy data on a real surface

Production-facing UI rendering hardcoded arrays, "John Doe" entries, fake amounts,
or `console.log`-style placeholder data is a Blocking finding regardless of severity.
Either wire it to a real source or hide the section.

**Smell patterns:**
- `data() { return { payments: [{ id: 1, amount: 100, customer: 'John' }] } }`
- Fixed arrays declared at module top and rendered without ever being replaced
- `const sampleData = [...]` referenced by the template

**Corpus evidence:**
- "Payments table shows hardcoded dummy data" (`fluent-members#127`, `MembershipManage.vue`)

---

## Bypassed config / hardcoded menu items

Component receives an `actions` / `menu` / `items` config prop, ignores it, and
renders a hardcoded list anyway. The config exists but is dead.

**Smell patterns:**
- `props: { actions: { type: Array, default: () => [] } }` then template renders
  `<el-dropdown-item v-for="a in HARDCODED_ITEMS">`
- Backend provides `secondary_actions[]` but the Vue template hardcodes the buttons

**Corpus evidence:**
- "Secondary action config is bypassed by hardcoded menu items" (`fluent-members#127`, `MembershipManage.vue`)

---

## Mobile/responsive rules target unused markup

CSS rules for a layout that no longer exists, or for a markup variant that was
removed/refactored. The CSS is dead — flag it for removal.

**Smell patterns:**
- `@media (max-width: 768px)` rules referencing class names that don't appear in any
  template
- Responsive rules scoped to a `.payment-table-mobile` class that the template no
  longer outputs

**Corpus evidence:**
- "Mobile payment table responsiveness rules target unused markup" (`fluent-members#127`, `member-portal.scss`)

---

## Filter / search context dropped on rebuild

A component that builds a query from filters and rebuilds it on a different
code path (AJAX vs initial render, sort vs filter, pagination vs reset) must
preserve the same filter context across paths. Common bug: AJAX path forgets the
"category" filter the initial render used.

**Smell patterns:**
- Initial render builds query with `{ category, page }`; AJAX rebuild uses only `{ page }`
- Filter applied via Vuex action; sort dispatched via direct API call that ignores the action

**Corpus evidence:**
- "Category filter traceability dropped in AJAX default-filters path" (`fluent-cart#1638`, `ProductsCollection.php:531`)

---

## CTA label does not match action

Button labelled "Save" that calls `delete()`, "Update" that calls `create()`,
"Resubscribe" that calls `cancel()`. Severity: **High**.

**Smell patterns:**
- `<button @click="delete">{{ $t('Save changes') }}</button>`
- Submit handlers that do something other than what the form's primary verb says
- Confirmation dialog whose "Confirm" button doesn't match the description text

**Corpus evidence:**
- "Primary CTA label does not match triggered action" (`fluent-members#127`, `MembershipManage.vue:387`)

---

## Old write path made redundant by new write path

A PR that introduces a new write path (backend hook, REST route, service method)
for a resource that already had one MUST either delete the old write path or
document why both must coexist. Two writers to the same resource in the same
flow produce: avoidable network/server load, ordering bugs (which write wins?),
maintenance drift (the two paths diverge over time), and reviewer confusion
("which is the source of truth?"). Severity: **Blocking** when the two paths
write the same fields; **High** when they overlap partially.

**Smell patterns:**
- A new PHP hook handler writes to `update_post_meta('foo', $value)`. The
  diff also keeps a frontend `axios.put('/api/foo', {value})` that does the
  same thing — neither one is removed.
- A new service method `MediaSyncService::syncFromLesson()` is added; the
  frontend listener that previously did `PUT /media/{id}` per block still runs.
- Commit message says "backend now syncs this" but the old frontend sync
  code is still present in the diff.
- Two REST routes register handlers that both end up calling the same
  `Service::persist()` method through different controllers.

**Required pattern:** when adding a new write path, the same PR must
(a) delete the old path entirely, (b) gate the old path behind a feature
flag with a TODO to remove it, or (c) add a code comment block explaining
why both paths must coexist (different trigger conditions, fallback,
incremental rollout).

**Corpus evidence:**
- "Redundant per-media REST writes still run after backend hook sync"
  (`fluent-player-dev#352`, `fluent-player-block.jsx:95:116`) — frontend
  listener still issues one PUT per media block on every lesson save even
  though the PR introduced backend lesson-message parsing/sync for the same
  data path.

When reviewing, identify every NEW write call site (`update_post_meta`,
`wp_insert_post`, `wp_update_post`, model `->save()`, `$wpdb->update`,
controller responses that persist data) in the diff. For each, grep the
codebase for OTHER write paths to the same resource. If two exist and the
PR doesn't justify the coexistence, flag it.

---

## Render fallback breaks the chain

A "fallback" branch (default value, error catch, missing-data path) that returns
broken markup, malformed HTML, or a state that downstream code can't consume.

**Smell patterns:**
- `try { return formatAmount(amount) } catch { return '' }` consumed by code that
  expects a string with currency
- Default object `{}` substituted for a missing record where downstream expects
  `{ id, name, status }`
- `v-if="data" || data === undefined ? render() : ''` where the empty string breaks
  a parent's layout

**Corpus evidence:**
- "Broken amount rendering fallback breaks checkout view chain" (`fluent-members#141`, `checkout.php`)

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

1. List every NEW route / handler / component / setting / CTA in the diff (additions, not modifications).
2. For each, trace forward (UI → handler) and backward (handler → UI).
3. If any segment is missing, stub, hardcoded, or falls through to a placeholder, emit a finding.
4. For each `props.config` / `props.actions` / `props.items` declared in a changed Vue file, verify the template actually uses it. If hardcoded, emit a finding.
5. For each new CSS rule, verify the matched class / selector appears in some template. If not, flag as dead.
6. Default severity `Blocking` for stub handlers and hardcoded dummy data; `High` for ignored config props and CTA-label mismatches; `Medium` for dead CSS and dropped filter context.
7. Emit findings with `category: "traceability"`. Cap at 50.
