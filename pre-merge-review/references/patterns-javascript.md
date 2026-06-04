# JavaScript Review Criteria

Used by `engineering-review` Pass 5. Load when any `.js` file has changed.

---

## Null Safety

- Every `document.querySelector()` / `document.getElementById()` result null-checked before calling methods on it — these return `null` when no match (jQuery returns an empty truthy object)
- Every `e.target.closest('.selector')` result null-checked — returns `null` if no ancestor matches
- Optional chaining `?.` preferred over manual null checks for deeply nested access

## Event Handling

- `addEventListener` in any setup/init function has a matching `removeEventListener` in teardown
- No `document.addEventListener` or `window.addEventListener` inside a function that can be called multiple times — each call accumulates a new listener (memory leak)
- Event delegation uses `e.target.closest('.selector')` not `e.target.matches()` — `matches()` misses clicks on child elements within the target

## Accessibility State

- Interactive controls with `aria-expanded`, `aria-pressed`, `aria-selected`, `aria-hidden`, or disabled state keep that attribute synchronized from every state-changing path, not only the direct click handler
- If responsive code, resize handlers, mobile drawers, backdrops, keyboard shortcuts, async callbacks, or programmatic open/close helpers add/remove classes like `is-open`, `active`, `hidden`, or `sidebar-collapsed`, verify the matching ARIA attribute is updated in the same helper or through one shared sync function
- For toggle buttons that control another element, inspect all alternate controls for the same target (floating open buttons, close buttons, backdrop clicks, breakpoint auto-collapse) and confirm they update the original toggle's announced state
- Prefer a small shared `sync*State()` helper over duplicating ARIA updates in only one event branch

## DOM Ready

- Any code that queries the DOM runs inside a `DOMContentLoaded` listener or a `readyState` check — not at module evaluation time (module may evaluate before DOM is ready)
- Correct pattern:
  ```js
  function init() { document.querySelectorAll('.target').forEach(setup); }
  if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', init);
  } else {
      init();
  }
  ```

## WordPress jQuery noConflict

- No bare `$()` outside a `(function($){ ... })(jQuery)` wrapper — WordPress loads jQuery in noConflict mode; `$` is not defined globally
- Detection uses `typeof jQuery !== 'undefined'` — not `typeof $` (`$` may exist but point to Prototype/Mootools)
- No `jQuery.isArray`, `jQuery.parseJSON`, `jQuery.trim`, `jQuery.type`, `jQuery.now`, `jQuery.isNumeric`, `jQuery.isFunction` — removed in jQuery 4.0 (shipping in WordPress 6.8)

## Async / Fetch

- `fetch()` checks `response.ok` before reading body — HTTP 4xx/5xx responses do not reject the promise
  ```js
  const res = await fetch(url);
  if (!res.ok) throw new Error(res.statusText);
  const data = await res.json();
  ```
- `.catch()` shows a user-visible message — not just `console.error`
- No fire-and-forget async calls where failure is silent

## Custom Events vs jQuery Events

- jQuery `.trigger('eventName', [data])` fires ONLY through jQuery's event system — native `addEventListener` will NOT receive it (jQuery Bug #11047, WONTFIX)
- Native `CustomEvent` fires through the browser's event system — jQuery `.on()` handlers will NOT receive it by default
- If a dual-event bridge is used: `e.preventDefault()` on the native event does NOT cancel the jQuery event (and vice versa) — check if this matters for the specific events
- Custom event names should not collide with native DOM event names (`submit`, `change`, `remove`, `error`) — triggering native event names via jQuery has side effects

## Bundling

- `require()` inside `if/else` — webpack bundles BOTH files regardless of runtime branch (CommonJS is statically resolved at build time). Document this if intentional.
- Dynamic `import()` needed for true code splitting (requires `output.chunkFilename` in webpack config)
- No accidental `require('jquery')` in public bundles — jQuery is provided by WordPress's script loader; bundling it adds ~90KB gzipped

## Memory Leaks

- Any reference stored on `window.*` is cleaned up when no longer needed
- DOM elements removed from the document should have their jQuery event cache cleaned with `.off()` first, otherwise jQuery's internal `_data()` cache is never released
- `setInterval` / `setTimeout` IDs stored and cleared in teardown

## Dead Code

- Every `require()` / `import` at the top of a file — is the imported symbol actually called?
- Inner functions with the same name as an imported symbol shadow the import silently — check for this
- Any `.plain.js` or `-jquery.js` file that is neither an entry point nor `require()`d anywhere
