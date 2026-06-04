# Vue 2 Review Criteria

Used by `engineering-review` Pass 6. Load when any `.vue` file has changed.

---

## Options API Compliance

- Options API only: `data()`, `computed`, `methods`, `watch`, `props`, `emits` — no `setup()`, `ref()`, `reactive()`, `computed()` from Composition API
- `data()` returns a plain object — not a class instance
- No direct `this.$store.state` mutation — all state changes go through Vuex mutations/actions
- Props validated with type and `default` or `required` — no `props: ['name']` shorthand on non-trivial components
- `$emit` event names are kebab-case strings

## Memory Leaks (most commonly missed in Vue 2)

- `addEventListener` in `mounted()` → matching `removeEventListener` in `beforeDestroy()`
- `$on()` / `$root.$on()` / event bus subscriptions → matching `$off()` in `beforeDestroy()` — Vue 2 does NOT auto-clean these
- `setInterval` / `setTimeout` started in `mounted()` or `created()` → cleared in `beforeDestroy()`
- Third-party library instances (charts, editors, Choices.js) → destroyed in `beforeDestroy()`
- `this.$watch()` (programmatic watchers) → store the returned unwatch function, call it in `beforeDestroy()` — the `watch:` option is auto-cleaned but `this.$watch()` is not

## API Call Patterns

- Uses project REST client (`FluentFormsGlobal.$rest.get/post/put/del()` for FluentForm) — not raw `fetch` or `axios`
- No API calls in `data()` — only in `created()`, `mounted()`, or methods triggered by user action
- All API calls handle errors in `.catch()` with a user-visible `this.$message.error()` or equivalent
- Loading states use `v-loading` directive or a `isLoading` data property — not custom spinner implementations
- Vuex actions used for shared state; local component `data()` for UI-only state

## Element UI Compliance (FluentForm-specific)

- Uses `el-button`, `el-dialog`, `el-table`, `el-form` — not custom-built equivalents
- `el-form` uses `:model`, `:rules`, `ref` — validates programmatically with `this.$refs.form.validate()`
- Dialog close via `this.$refs.dialog.close()` — not direct DOM manipulation

## Keyboard QA for Element UI Tables and Dropdowns

- For `el-table` row-click behavior, verify Tab order in the browser: decorative status dots, tooltip/popover references, hover-only actions, and fixed-column clones must not become extra tab stops.
- If rows are focusable, `ArrowDown` / `ArrowUp` must move exactly one row and `Enter` must activate the same detail action as mouse row-click.
- For searchable `el-dropdown` menus, verify ArrowDown from the search input enters the filtered list, ArrowUp from the first selectable item returns to the search input, and Enter selects the focused item.
- For navigation dropdowns, hide or preserve the menu state during route/page changes so users do not see a brief reset/list flash.
- For striped tables, check focused/current-row background against odd and even rows; override both states if they differ.

## Reactivity Traps

- New properties added to reactive objects use `this.$set(obj, 'key', value)` — not direct assignment `obj.key = value` (Vue 2 cannot detect new property additions)
- Array mutations use Vue-compatible methods: `push`, `pop`, `splice`, `sort` — not index-based assignment `arr[0] = value`

## Template Safety

- `v-html` not used with user-controlled content — XSS risk; use `v-text` or template interpolation `{{ }}` instead
- Dynamic component `:is` binding validated against an allowlist of component names — not raw user input

## Index Stability in List Rendering

When a list is filtered/transformed before rendering and the consumer uses indices to identify items, **the rendered index does not match the source index**. This silently corrupts state.

**Smell:** `array.filter(...).map(...)` followed by an emit/handler that uses the v-for index:
```vue
<!-- ❌ unsafe: gi is the post-filter index, parent's array still has the dropped items -->
<el-tag v-for="(group, gi) in summary"
        @close="$emit('clear-group', gi)" />

computed: {
  summary() {
    return this.filters.filter(g => g.length > 0)  // drops empty groups
                       .map(g => transform(g))
  }
}
```
A parent indexing into the original (un-filtered) array will hit the wrong slot.

**Required pattern:** preserve the original index alongside the transformed item.
```vue
<!-- ✅ safe -->
<el-tag v-for="(group, displayIdx) in summary"
        :key="'g_' + group.originalIndex"
        @close="$emit('clear-group', group.originalIndex)" />

computed: {
  summary() {
    const out = [];
    this.filters.forEach((g, originalIndex) => {
      if (g.length === 0) return;
      out.push({ originalIndex, items: transform(g) });
    });
    return out;
  }
}
```

When reviewing, grep for `\.filter\(.*\)\.map\(` and `\.filter\(` immediately preceding a v-for. Walk through with at least one **sparse-array input** (`[[], populated, populated]`) and confirm chip-N closes the correct group.

## State-Coupling and Single-Source-of-Truth

A boolean flag should govern exactly one concern. The most common Vue 2 leak:

**Smell:** the same flag (`x_active`, `panel_open`, `is_editing`) gates BOTH the editing UI AND the data persistence/query layer. Hiding the editor then silently changes the data behavior.

```js
// ❌ overloaded flag
if (this.advanced_filter_active) {            // panel visible
  data.advanced_filter = this.advanced_filter // ALSO gates query
}
```
Result: collapse the panel → query stops sending the filter → indicators also vanish (or worse, indicators stay while query unfilters). Two interpretations, both wrong.

**Required pattern:** decide which flag is the *source of truth* for "is this feature active" and derive UI visibility separately.
```js
// ✅ derived from data
hasAppliedFilters() {                       // ← single source of truth
  return Array.isArray(this.advanced_filter)
      && this.advanced_filter.some(g => g.length > 0);
}
// query gating:
if (this.hasAppliedFilters) data.advanced_filter = this.advanced_filter
// chip visibility, badge count: also derive from hasAppliedFilters
// editor panel visibility: separate flag, not coupled
```

When reviewing, draw a 2×2 grid of `(flag) × (data state)` and label each cell. If any cell is "?" or "this can't happen but the code allows it", that's the bug.

## Prop / Internal-State Sync

A child component that has both a prop and a `data()` field with related names (`advanced_filter` prop + `advanced_filters` data) is a smell. Pick one:

- **Stateless:** drop the `data()` field, render from prop, emit on every change. Parent owns state.
- **Stateful with sync:** add a deep watcher on the prop that copies it into the `data()` field when the parent mutates externally. Otherwise reopening the child shows stale state and a subsequent "save"/"apply" silently re-applies the just-removed state.

When reviewing, search for `data()` returning a value with the same shape as a `props` declaration. If there's no watcher and no explicit "panel re-mounts on every open", flag it.

## Adversarial Input Walkthrough (mental test)

Before signing off on a Vue PR that builds lists or maintains array state, run these inputs through the affected components in your head:

- `[]` (empty)
- `[[]]` (single empty group / one-element wrapper)
- `[[], populated]` (empty before populated — exposes index-stability bugs)
- `[populated, [], populated]` (empty in middle)
- One `null` entry mixed in (defensive `Array.isArray` checks)
- Length 1 vs length >1 (off-by-one)
- The same array passed in twice in quick succession (race / stale closure)

If any of these produce a "weird but plausibly user-reachable" state, write down the case and verify the code handles it.
