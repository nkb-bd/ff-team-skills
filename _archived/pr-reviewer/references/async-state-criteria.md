# Async State Machine Criteria

Used by `pr-reviewer` detector `async-state`. Load when any `.vue`, `.jsx`, `.tsx`, `.js`, or `.ts` file has changed.

Async-state bugs hide in code that LOOKS correct on a single trace but breaks under
re-entry, cancellation, or out-of-order responses. Every rule below is derived from
a real autharif review in the WPManageNinja corpus.

---

## Stale async response overwrites current state

A request fired with state `{ id: A }` returns later than a request fired with state
`{ id: B }`. If both writes go to the same reactive field, the later request can
overwrite the current view with stale data. Classic in summary panes, search-as-you-type,
and "view contact" flows.

**Smell patterns:**
- `await api.get(...)` followed by `this.summary = response.data` with no request-id check
- `axios.get(url).then(r => this.contact = r.data)` where `url` depends on a prop that can change before the response arrives
- Composable that returns a `data` ref and writes to it inside `then()` without comparing the request key

**Required pattern:**
```js
async function load(id) {
  const myRequestId = ++this.requestSeq
  const data = await api.fetch(id)
  if (myRequestId !== this.requestSeq) return  // a newer request superseded us
  this.contact = data
}
```

Or use AbortController:
```js
this.abort?.abort()
this.abort = new AbortController()
const data = await api.fetch(id, { signal: this.abort.signal })
this.contact = data
```

**Corpus evidence:**
- "Stale async response can overwrite current contact summary" (`fluent-crm#1820`, `ProfileAiSummary.vue:104`)

---

## Cancel races with in-flight writes

Cancel button that resets local state while a network request is still mutating it
will produce one of: (a) cancel runs, then late response writes, view shows the
cancelled-then-resumed state; (b) request finishes after cancel, server-side still
processes; (c) cancel and finish race on the same `loading` flag and one wins
silently.

**Smell patterns:**
- A "Cancel" handler that sets local state to `'idle'` without aborting the in-flight request
- A `loading` flag that both `cancelHandler` and `responseHandler` set/unset
- A migration / import flow with a Cancel button and no `AbortController` plumbed through

**Required pattern:** Cancel must (a) abort the in-flight request via `AbortController`
or `axios.CancelToken`, (b) drop any pending mutations queued for after the response,
(c) only then reset local state. Server-side, the cancel must mark a state record
that the next response handler reads before writing.

**Corpus evidence:**
- "Cancel can race with in-flight import state writes" (`fluent-members#163`, `_PmproProgress.vue`)
- "country-toggle-loading-race" (`fluent-cart#1679`, `TaxRates.vue:191`)

---

## Retry resumes from stale offset

A long-running operation that persists offset/cursor state and lets the user retry
must re-read the persisted offset on retry, not reuse the in-memory offset that was
captured at the first attempt.

**Smell patterns:**
- Component data `currentOffset: 0` mutated locally during loop, retry button calls
  `runLoop(this.currentOffset)` instead of re-fetching from server state
- Retry button shares its handler with "start" button and they both read in-memory state

**Corpus evidence:**
- "Retry resumes from stale offset" (`fluent-members#163`, `_PmproProgress.vue`)

---

## Retry can start concurrent loops

A retry / resume button without an "in-flight" guard can be clicked twice and start
two loops that interleave their writes. The progress UI then double-counts and the
backend sees concurrent writes.

**Smell patterns:**
- `<el-button @click="retry">` with no `:disabled="importInFlight"`
- Loop function that doesn't early-return when called while a prior invocation is still running
- Setting a `loading` flag at the END of the loop's setup (not the START) — the second click happens before the flag is set

**Required pattern:**
```js
async retry() {
  if (this.importInFlight) return
  this.importInFlight = true
  try { await this.runLoop() } finally { this.importInFlight = false }
}
```

**Corpus evidence:**
- "Retry can start concurrent import loops" (`fluent-members#162`, `_PmproProgress.vue:41`)
- "Import loop completes before all backend phases run" (`fluent-members#163`, `_PmproProgress.vue`)

---

## Progress UI double-counts the final-state response

A progress loop that polls `/state` and renders `processed_count` from each response,
then the final "completion" response also includes `processed_count`, will double-count
if the loop's local counter is incremented from polls AND the final response is
treated as another increment.

**Smell patterns:**
- `progress = response.processed` inside the poll AND `progress += response.processed` on the final response
- Mixing absolute and delta counts in the same loop

**Corpus evidence:**
- "Progress UI double-counts final state response" (`fluent-members#162`, `_PmproProgress.vue`)

---

## Progress total never updates during fresh imports

Progress total seeded once at start from a "preview" response, then never refreshed
when the actual import starts and the real total may differ. UI shows wrong percentage.

**Corpus evidence:**
- "Progress total never updates during fresh imports" (`fluent-members#162`, `_PmproProgress.vue`)

---

## Cancel reset orphans persisted state

Cancel that resets local state without persisting "cancelled" to the server leaves
backend in mid-operation. On retry, the server resumes from where it stopped, but
the local state is fresh — they diverge.

**Smell patterns:**
- Cancel button mutates local state but doesn't `POST /cancel` to the backend
- Cancel button POSTs `/cancel` but doesn't await the response before resetting local state
- "Start over" reset that doesn't clear server-side migration progress

**Corpus evidence:**
- "Cancellation flow drops persisted migration state" (`fluent-members#163`, `_PmproMigration.vue:292`)
- "Cancel reset can orphan imported records and duplicate structure on rerun" (`fluent-members#163`, `_PmproProgress.vue:218`)
- "Cancel hides resumable import state" (`fluent-members#163`, `_PmproMigration.vue:300`)

---

## Stale preview after Start Over

Components that cache a "preview" / "analysis" result and re-render after a "Start Over"
must invalidate the cache. Otherwise users see the prior preview against the new
inputs.

**Corpus evidence:**
- "Preview can show stale analysis after Start Over" (`fluent-members#162`, `_PmproPreview.vue:208`)

---

## Re-mount triggers full re-analysis

A Vue/React component that runs an expensive analysis in `mounted()` / `useEffect(()=>{}, [])`
and is allowed to unmount-remount (modal, route navigation, conditional `v-if`)
will re-run the analysis on every remount. If the analysis is `O(n)` over a remote
dataset, this is a perf bug masquerading as a state bug.

**Required pattern:** persist the analysis result in a parent / store / cache keyed
by input identity; the child reads the cached result and only kicks off analysis if
absent or stale.

**Corpus evidence:**
- "Repeated full PMPro analysis on preview remount" (`fluent-members#162`, `_PmproPreview.vue`)

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

1. Walk every changed `.vue` / `.jsx` / `.tsx` / `.js` / `.ts` file.
2. Quickly skip files with no async surface — grep for `await`, `.then(`, `axios`, `fetch(`, `setTimeout(`, `setInterval(`, `Promise`. If none, no findings.
3. For each async surface, walk the rules above.
4. Severity defaults to `Blocking` for cancel-races and concurrent loops; `High` for stale-overwrites and cancel-orphans; `Medium` for double-count and stale-preview.
5. Emit findings with `category: "async-state"`. Cap at 50.
