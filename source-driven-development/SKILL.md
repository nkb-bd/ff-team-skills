---
name: source-driven-development
description: >
  Ground every framework or library claim in an authoritative source before asserting it. Verify
  WPFluent, Vidstack, hls.js, Gutenberg (apiVersion 3), and WordPress core behavior against the
  official docs OR the vendored source in the repo — never from memory. Any claim you cannot ground
  gets an explicit UNVERIFIED tag so it is visible, never silently asserted. Use when writing code
  against a library API, debugging "the API should do X", or citing framework behavior.
when_to_use: >
  Any time you assert how WPFluent, Vidstack, hls.js, Gutenberg, or WordPress core behaves — a hook's
  firing order, a method signature, a filter's arguments, a component prop, a lifecycle guarantee.
  Also when a bug hypothesis depends on "the framework does X". Skip only for plain-language app logic
  that touches no external API.
---

# Source-Driven Development

## Philosophy

The most confident-sounding bugs come from mis-remembered APIs. A model (or a human) recalls a
signature that was true two major versions ago, writes code against it, and the error surfaces three
layers away from the wrong assumption. The fix is not to remember harder — it is to **not rely on
memory for external contracts at all**.

Every claim about how a framework behaves is either grounded in a source or it is a guess. Guesses are
allowed — but only when labelled as such, so the reader (and future you) knows which lines rest on
verified ground and which rest on a hunch.

## When to use this skill

Before you write or assert:

- A **WPFluent** contract — validator rules (note: there is **no `boolean` rule**), router, ORM
  method, request helper. WPFluent diverges from Laravel; do not assume parity.
- A **Vidstack** or **hls.js** API — player method, event name, provider config, lifecycle hook.
- A **Gutenberg** API — block registration, apiVersion 3 iframe behavior, editor store selector.
- A **WordPress core** behavior — hook firing order, sanitizer semantics, capability meaning,
  `$wpdb` quoting, REST arg schema.

If the assertion is about the plugin's own app logic and touches no external library, this skill
doesn't apply — read the code directly.

## The discipline

### 1. Locate the authoritative source (in priority order)
1. **The vendored source in this repo** — the version actually shipping. `vendor/` (PHP),
   `node_modules/` (JS). Find it with code-review-graph `semantic_search_nodes` (kind `Function`/`Class`)
   or `query_graph` `imports_of`. This is the ground truth because it's the exact version running.
2. **Official docs** for that version (`WebFetch`) — WPFluent/WPManageNinja docs, vidstack.io,
   Gutenberg block-editor handbook, WordPress developer reference. For Anthropic/Claude APIs use the
   `$claude-api` skill instead of the open web.
3. **A canonical example** in this codebase that already calls the API correctly — precedent beats
   documentation when they conflict, because it demonstrably works here.

Prefer vendored source over docs when they disagree: docs describe the API's intent, source describes
the version you actually have.

### 2. Verify against the version you ship
Pin the claim to the real version. `composer.lock` / `package-lock.json` say what's installed. An API
that exists in the latest docs may not exist in the pinned release — and vice versa.

### 3. Label the ground
- Grounded claim → state it plainly and, when non-obvious, cite where (`vidstack ChangeEvent, per
  node_modules/vidstack/...`).
- Ungrounded claim you still need to make → prefix it **`UNVERIFIED:`** so it stands out and gets
  checked before it hardens into code. Example: "UNVERIFIED: I believe `canPlay` fires before
  `loadedmetadata` — confirm against the vidstack source before relying on ordering."

An `UNVERIFIED:` tag is a promise to verify, not permission to ship a guess.

## Anti-rationalization

| The shortcut you'll reach for | Why it's wrong |
|---|---|
| "I'm pretty sure the signature is X." | "Pretty sure" about an external contract is exactly the case this skill exists for. Verify or tag. |
| "The docs say X, that's enough." | Docs describe the latest version; you ship a pinned one. Check `composer.lock`/`package-lock.json`. |
| "Laravel does it this way, so WPFluent does too." | WPFluent is not Laravel — it lacks rules and helpers Laravel has (e.g. no `boolean` validator). |
| "It worked in another plugin." | Different pinned version, different framework build. Precedent must be *in this repo*. |
| "I'll find out when it errors." | The error surfaces layers from the wrong assumption. Grounding up front is cheaper than the trace. |

## Relationship to other skills

- `$new-feature` calls this in **Phase 3 (Spec)** to ground API-dependent decisions, and in
  **Phase 4 (Build)** before writing code against any WPFluent/Vidstack/Gutenberg surface.
- `$claude-api` is the source-of-truth skill for Anthropic/Claude APIs specifically — defer to it there.
- When a `$doubt-driven-development` skeptic's surviving doubt is "I'm not sure the API behaves that
  way," resolve it here — grounding is how that doubt gets closed.
