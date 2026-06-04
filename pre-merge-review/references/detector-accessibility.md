# Accessibility Criteria

Used by `pr-reviewer` detector `a11y`. Load when any `.vue`, `.jsx`, `.tsx`, or `.scss`/`.css` file has changed.

Every rule below is derived from a real autharif review comment in the WPManageNinja corpus. Citations point to the canonical example PR.

---

## Mouse-only interactive elements

A `<div>`, `<span>`, `<li>`, `<tr>`, or icon-only button with `@click` / `onClick` and **no** `role`, `tabindex`, and key handler is keyboard-unreachable. Severity: **Blocking** when it is the only path to the action; **High** if a parallel keyboard-reachable path exists.

**Smell patterns:**
- `<div @click="...">` without `role="button"` + `tabindex="0"` + `@keydown.enter` / `@keydown.space`
- `<el-tag @click="...">` used as primary action — Element Plus tags are not buttons
- Card / row components with `@click` on the wrapper element
- Icon-only `<el-button :icon="...">` without an `aria-label` attribute

**Required pattern:**
```vue
<button type="button" :aria-label="label" @click="handleClick">
  <i class="icon-foo" />
</button>
```

**Corpus evidence:**
- "Locked Timed Content card is mouse-only" (`fluent-player-dev#343`, `TimedContentStylePanel.jsx:86`)
- "Search toggle is mouse-only and not keyboard accessible" (`fluent-members#148`, `MembersList.vue`)
- "Dropdown trigger is not keyboard-accessible" (`fluent-members#127`, `MembershipManage.vue`)
- "Entity card rows are mouse-only interactive elements" (`fluent-crm#1798`, `Dashboard.vue:229`)
- "Popover trigger is not keyboard accessible" (`fluent-cart#1670`, `_SiteTable.vue:44`)

When reviewing, grep the diff for `@click` or `onClick` and walk every match; the element must be a `<button>`, an `<a href>`, an `<input>`, or have `role="button"` + `tabindex` + key handler.

---

## ARIA state staleness on responsive / programmatic changes

`aria-expanded`, `aria-pressed`, `aria-selected`, `aria-checked` updated only inside the click handler is wrong. Responsive auto-collapse, programmatic open/close, route navigation, and "external" toggles will leave the ARIA state lying about the visual state.

**Smell patterns:**
- `el-collapse` / `el-drawer` whose open state is mutated by a `window.matchMedia` listener but whose toggle button never has its `aria-expanded` re-bound
- `aria-expanded="true"` hardcoded in a template (the value never updates)
- Two ways to open the panel (a button and a programmatic call) with `aria-expanded` updated only in the button handler

**Required pattern:** bind `aria-expanded` to the same reactive source the visual state derives from.
```vue
<button :aria-expanded="String(isOpen)" @click="toggle">…</button>
<!-- isOpen is a ref/computed updated by ALL paths that change visibility -->
```

**Corpus evidence:**
- "Playlist toggle ARIA state gets stale after responsive auto-collapse" (`fluent-player-dev#341`, `FluentPlaylist.js:395`)
- "Popover trigger lost keyboard/button semantics" (`fluent-crm#1811`, `BlockComposer.vue:105`)

---

## Focus visibility removed without replacement

Removing `outline: none`, `box-shadow: none`, or `:focus { outline: 0 }` without providing a replacement focus indicator violates WCAG 2.4.7. Severity: **High**.

**Smell patterns:**
- `outline: none` on `:focus`, `:focus-visible`, or `:focus-within` without a replacement
- `box-shadow: none !important` on `:focus`
- Range/slider styles that strip the thumb focus ring
- "Reset" CSS that removes focus rings globally

**Required pattern:** if you remove the default outline, add an explicit `:focus-visible` style with a 2px ring or 2px outline in the brand color.

**Corpus evidence:**
- "Range control focus visibility is removed" (`fluent-player-dev#343`, `fluent-player-block.scss:8167`)
- "Focus indicator removed from external site link" (`fluent-cart#1670`, `ViewSite.vue:174`)

---

## Icon-only buttons missing accessible name

An `<el-button>`, `<button>`, or `<a>` whose only child is an icon (`<i>`, `<svg>`, image) and which has no `aria-label`, no `aria-labelledby`, no visible text, no `title` is unreadable to screen readers. Severity: **High**.

**Smell patterns:**
- `<el-button :icon="EditPen" />` with nothing else
- `<button><i class="el-icon-..." /></button>`
- Toolbar buttons rendered from a `:icon` prop without a paired label prop

**Required pattern:**
```vue
<el-button :icon="EditPen" :aria-label="$t('Edit template')" />
```

**Corpus evidence:**
- "Icon-only preview button lacks accessible name" (`fluent-crm#1822`, `Campaigns.vue:205`)
- "Template preview icon button missing aria label" (`fluent-crm#1822`, `BlockComposer.vue`)

---

## Screen-reader-hidden essential context

`aria-hidden="true"`, `visually-hidden { display: none }`, or `sr-only { display: none }` on content that conveys meaning (price, status, count, label) hides it from assistive tech. The CSS pattern that hides instead of visually-hides is the more dangerous one.

**Smell patterns:**
- `display: none` on a `.sr-only` / `.visually-hidden` class — the correct pattern uses `clip-path` / `position: absolute` to hide visually but keep readable
- `aria-hidden="true"` on a wrapper that contains the price / status text the user needs

**Corpus evidence:**
- "Screen reader price context is forcibly hidden" (`fluent-crm#1793`, `block-styles.php`)

---

## Keyboard can interact with disabled state

`disabled` styling without a corresponding `disabled` HTML attribute (or `aria-disabled` + click prevention) lets keyboard users tab into and activate "disabled" controls.

**Smell patterns:**
- `<el-option>` with `class="is-disabled"` but no `disabled` prop
- Locked rows / locked levels rendered with opacity but no `tabindex="-1"` and no `aria-disabled`
- `cursor: not-allowed` styling without functional disablement

**Required pattern:** use the framework's `disabled` prop AND check it server-side before submission.

**Corpus evidence:**
- "Keyboard can select locked corporate type" (`fluent-members#139`, `_AddLevelDialog.vue:51`)
- "Disabled triggers can still be selected and submitted" (`fluent-crm#1829`, `_CreateFunnelModal2.vue:167`)

---

## Modal does not manage focus

Modal/dialog/drawer that opens without moving focus into it, or that does not return focus to the trigger when it closes, breaks keyboard navigation. Modals built from raw `<div>` + `v-if` rather than `<el-dialog>` are the highest risk.

**Smell patterns:**
- `<div v-if="modalOpen">` containing form fields, no `ref` on the first focusable child, no `nextTick(() => firstField.focus())` after open
- `<el-dialog>` with `:modal="false"` and no `lock-scroll`
- Reply-thread / comment / inline-edit modals built from scratch

**Corpus evidence:**
- "Reply thread modal does not manage keyboard focus" (`fluent-cart#1641`, `Reviews.js`)

---

## Table and dropdown keyboard traps

Interactive tables and searchable dropdowns often look keyboard-ready while Element UI / cloned DOM creates bad tab order or swallowed arrow keys. Severity: **High** when keyboard users cannot reach or activate the same action; **Medium** when focus order is noisy but a usable path remains.

**Smell patterns:**
- Visual status dots, tooltip references, popover references, hidden hover actions, or fixed-column clones receive Tab focus.
- `ArrowDown` / `ArrowUp` handlers move two rows because both framework and custom handlers process the same event.
- Focused rows do not open on `Enter`, even though mouse row-click opens detail.
- Searchable dropdown input cannot ArrowDown into filtered results, or ArrowUp from the first result cannot return to the input.
- Selecting a dropdown item clears / flashes the list before the page navigation or route change.
- Striped tables use different focused-row colors for odd/even rows.

**Required pattern:** verify the compiled UI in a browser with Tab, ArrowUp, ArrowDown, and Enter. Decorative nodes should use `tabindex="-1"` / `aria-hidden` as appropriate; custom arrow handlers should own the event with `preventDefault()` and stop propagation; focused-row styling should override both striped and non-striped row states.

**Corpus evidence:**
- "Entries table and form switcher keyboard traps" (`fluentform local`, `Entries.vue` / `entries.scss`)

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

1. Walk every changed `.vue` / `.jsx` / `.tsx` / `.scss` / `.css` file.
2. For Vue/JSX/TSX: grep for `@click`, `onClick`, `aria-`, `tabindex`, `@keydown`, `:icon`, `el-button`, `el-tag`, `el-dialog`, `el-table`, `el-dropdown` — apply the rules above.
3. For SCSS/CSS: grep for `outline: none`, `outline: 0`, `box-shadow: none` on `:focus*` selectors — apply the focus-visibility rule.
4. For each violation, emit a finding with `category: "a11y"` and severity per the rule. Default severity is `High` unless the rule says otherwise.
5. Cap output at 50 findings; if more, prioritize Blocking → High → Medium and drop Suggestions first.
