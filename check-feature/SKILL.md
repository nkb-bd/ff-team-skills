---
name: check-feature
description: >
  End-to-end composite workflow for checking an EXISTING, already-shipped feature in a
  WordPress plugin — the inverse of new-feature. Instead of building a feature forward
  through gated phases, it walks a shipped feature backward: locate → map the vertical
  slice (UI → REST → controller → policy → model → DB → hooks → tests → docs) → verify
  behavior at runtime → verify correctness & security → verify against the original
  intent (spec / success-signal / extension seams / test coverage) → write a re-runnable
  Feature Health Report. Read-only: it verifies and reports, then routes fixes to
  $bug-fix or $new-feature. Depth scales with a tier system.
when_to_use: >
  Use when you want to know whether a shipped feature is actually healthy end-to-end —
  "is feature X still working", "audit the conditional-logic feature", "does the export
  still do what we said it would", "check the payment flow before the release", "did we
  ever add tests for X", "verify feature X after the refactor". Invoke as $check-feature
  or "use the check-feature workflow". Scoped to ONE named feature — for a whole-plugin
  sweep use $plugin-audit; for a branch diff use $pre-merge-review; to just learn how a
  feature works use $explain-this.
context: fork
allowed-tools: Read Write Bash(git *) Bash(gh *) Bash(grep *) Bash(rg *) Bash(find *) Bash(openspec *) Bash(composer *) Bash(npm *) Bash(open *)
effort: high
---

# Check Feature — Composite Verification Workflow

This is the mirror image of **`$new-feature`**. `new-feature` builds a feature *forward*
through six phases, pausing at approval **gates**. `check-feature` walks an existing,
already-shipped feature *backward* through six phases, stopping at evidence **checks**.

Where `new-feature` asks *"should we build it this way?"* and waits for a "yes",
`check-feature` asks *"does the shipped code actually do what we said it would?"* and
waits for **evidence** — a file:line, a runtime observation, a passing (or missing) test.
It does not accept "looks fine". Every claim of health is proven or it is a finding.

**This skill is read-only.** It verifies and produces one re-runnable **Feature Health
Report**. It does not edit source. When it finds something broken it routes the fix to
**`$bug-fix`** (a defect) or **`$new-feature`** (a missing capability) — never patches
in place. Keeping the checker separate from the fixer is what keeps its verdicts honest.

## Debunk stance (the default posture, every tier)

**The checker's job is to prove the feature BROKEN.** HEALTHY is what you're forced to
conclude only after a genuine attempt to break it *fails* — never the starting assumption.
A confirmation pass ("I read the handler, it looks right") is not a check; it's how the
gap the feature was shipped with survives every review.

So every phase is run adversarially, not just Phase 4's fresh-context skeptic:

- **State the claim, then attack it.** For each thing you're about to mark PASS, first
  write the counterexample that *would* make it fail, then go looking for it. If you can't
  construct one, say why the class of failure is impossible here — don't skip straight to
  PASS.
- **Run the counterexample, don't summarize it.** For any data-changing / auth / money /
  PII / cross-boundary-key check, *construct and execute* the breaking input yourself (a
  missing-nonce request, a no-cap user, an empty/oversized value, the wrong keyspace) and
  observe the real result. A summary of "it should reject this" is not evidence; the
  rejection you triggered is.
- **A CLEAN result on a high-value surface is itself suspect.** When a security/money/PII
  check comes back clean, that clean verdict is the next thing to refute (Deep/Critical
  escalate this to the full `$doubt-driven-development` loop in Phase 4).
- **Cite file:line for every verdict, PASS included.** "No counterexample found, here's
  the guard at `File:line` that blocks it" — not "looks fine".

Tier sets the *depth* of the attack, never whether you attack: **Spot/Standard** run the
lightweight refute inline in each phase (construct + run one counterexample per PASS on a
sensitive path); **Deep/Critical** add the full fresh-context skeptic in Phase 4. No tier
gets to coast to HEALTHY on confirmation alone.

## The inversion — new-feature phase ↔ check-feature phase

| new-feature (build forward) | check-feature (verify backward) | The question flips from → to |
|---|---|---|
| 0 Triage — pick the tier | 0 **Locate & Triage** — find the feature, pick the tier | "how big is what we're building?" → "how big is what we're checking?" |
| 1 Align — agree the canonical noun | 1 **Map the slice** — trace the whole vertical slice | "what will we build?" → "what did we actually build, and where does it live?" |
| 2–3 Plan + Spec — write the contract | 4 **Verify against intent** — check reality vs the contract | "what should it do?" → "does it still do that?" |
| 4 Build — write the code (TDD) | 2 **Verify behavior** — run it, observe it | "make it work" → "does it work?" |
| 4.5 UI demo — show it works | 2 **Verify behavior** (runtime capture) | "show me it looks right" → "prove it still looks/behaves right" |
| 5 Review — pre-merge detectors | 3 **Verify correctness & security** — scoped detectors | "is this diff safe to merge?" → "is this shipped code still safe?" |
| 6 Ship — PR + archive | 5 **Report** — Feature Health Report + verdict | "write the PR" → "write the verdict + a fix backlog" |

You do not have to run the phases in numeric order once the slice is mapped — Phases 2, 3,
and 4 are independent verification passes over the same slice. Run them in whatever order
the tier warrants; the report in Phase 5 collates all of them.

## Phase 0 — Locate & Triage (always; ~3 min)

**First, read `CLAUDE.md`, `CONTEXT.md`, and `AGENTS.md` from the project root if they
exist.** `CONTEXT.md` is the glossary — the feature almost certainly has a **canonical
noun** there, plus the *aliases to avoid*. Checking a feature under the wrong name is how
you miss half its code (FluentForm: "Entry" is the legacy alias for the canonical
"Submission" — grep only "Entry" and you skip the modern call sites, grep only
"Submission" and you skip the legacy ones; you need **both keyspaces**).

**Then ask which feature to check — a name or a description, both are first-class.**
Phrase it openly, e.g.: *"Which feature should I check? A name, a screen, a REST route, a
hook, an openspec change, or just describe it — 'the entry export', 'the Stripe payment
flow', 'conditional logic on the form editor'."* Accept any of:

- A **feature name / canonical noun** ("conditional logic", "form scheduling").
- A **UI surface** — an admin screen, a settings panel, a public-form control.
- An **entry point** — a REST route, an ajax action, a shortcode, a hook name, a Vue
  component, a controller class.
- An **openspec change name** (shipped) — its `specs/` entry IS the intended contract.
- A **plain-language description** — restate it back in one sentence to confirm you heard
  it, then resolve it to the canonical noun before mapping.

**Establish the "intended contract" now, before you look at the implementation.** What is
this feature *supposed* to do? Sources, in priority order:

1. The **openspec spec** (`openspec/specs/<capability>/spec.md` or an archived change) —
   `### Requirement` + `#### Scenario` blocks are literally the acceptance criteria.
2. The **proposal's success signal** (`proposal.md` — the one observable way you'd know it
   worked). Phase 4 checks reality against exactly this.
3. `CONTEXT.md` — the domain contract for the nouns the feature touches.
4. If none exist, the feature was shipped without a written contract. Say so explicitly
   (that is itself a Low finding) and **reconstruct** the intended contract from the code +
   the user's description, then have the user confirm it in one sentence before proceeding.
   You cannot verify "does it match intent" without a stated intent.

Then pick a depth tier:

| Tier | Signal | What to run |
|---|---|---|
| **Spot** | One control, one endpoint, "does this one thing still work" | Phase 1 (slice) + Phase 2 (behavior) only. |
| **Standard** | One feature touching ~3–8 files, one screen + its endpoints | Phases 1 + 2 + 3 (light detector sweep) + 4 (spec/coverage). |
| **Deep** | A module / service / policy surface / payment or auth path | Full workflow, Phase 3 deep detectors, Phase 4 adversarial refute. |
| **Critical** | Security/permission surface, money, PII, a public hook contract others depend on | Full workflow + mandatory adversarial refute + $plugin-audit scoped to the slice. |

Announce the tier and why. The tier must survive the evidence: if Phase 1 reveals the
feature is a payment or capability surface, escalate — a self-declared "Spot" check does
not override what the slice turns out to be.

## Optional: code-review-graph integration

If the project has a code-review-graph MCP server (check for `.mcp.json` mentioning
`code-review-graph`, or a `.code-review-graph/` cache), use its tools BEFORE grep/find
when the phase needs structural answers:

| Phase | Graph tool | What it answers |
|---|---|---|
| 0 Locate | `semantic_search_nodes <noun>` | Where does this feature's code live? Entry points by name/keyword. |
| 1 Map slice | `query_graph callers_of` / `callees_of` / `imports_of`, `get_affected_flows` | The full call chain UI→handler→service→DB, and every flow the feature participates in. |
| 1 Map slice | `query_graph tests_for <fn>` | Which tests (if any) cover each hop — feeds Phase 4's coverage check. |
| 3 Correctness | `get_impact_radius`, `get_review_context` | Blast radius of the feature's shared functions; token-efficient source for the detector sweep. |
| 4 Intent | `detect_changes` (since the spec landed) | Has the feature drifted from the commit that shipped its spec? |

Always cross-check graph output against live source (`git`, `rg`, direct reads) — the
graph occasionally lists stale files, and a verification skill that trusts a stale
enumerator will green a gap it exists to catch. Fall back to grep/find when the graph
doesn't cover the question.

## Context for every WP plugin

- **Stack**: PHP (WPFluent framework) + a per-repo frontend. **Read CLAUDE.md to confirm
  the frontend stack** (FluentForm = Vue 2 Options API + Laravel Mix; FluentPlayer = Vue 3
  + Gutenberg React). The slice you trace in Phase 1 crosses this boundary.
- **Hook prefix**: `<plugin-slug>/`. The feature's extension seams (Phase 4) use it.
- **REST**: `<slug>/v1`. Controllers in `app/Http/Controllers/`, policies in
  `app/Http/Policies/`, routes in `app/Http/Routes/api.php`.
- **DB**: custom `<prefix>_` tables, Eloquent-style ORM. Note: `->get()` returns a
  **Collection**, not a plain array — a Phase 3 loop that assumes `array` may be checking
  the wrong shape.
- **Base branch**: `dev` (not `main`).
- **CLAUDE.md / CONTEXT.md / AGENTS.md**: read first; they override this skill's defaults.

## Phase 1 — Map the vertical slice (always; ~5 min)

Build the feature's full call graph, top to bottom. This is the spine every later check
hangs off — a verification pass over an incomplete map silently skips the very hop where
the bug lives. Trace, with a file:line for each hop:

1. **UI entry** — the Vue component / admin screen / public-form control / shortcode /
   block that a user touches. Note the localized JS vars it reads (`wpFluentForm`, etc.).
2. **Transport** — the REST route(s) and/or ajax action(s) it calls. Enumerate these
   **against ground truth, not from memory**: `rg` the raw route/`add_action('wp_ajax_...')`
   registrations with a permissive pattern and count them. **`wp_ajax_*` action names are
   snake_case AND kebab-case AND mixedCase** (`fluentform_submit`, `fluentform-form-update`,
   `...formSettings`) — match `[A-Za-z0-9_-]+` anchored to the closing quote, or you drop
   the hyphenated privileged ones, which is exactly where broken-access-control hides.
3. **Auth** — the policy class or `permission_callback` on each transport. `__return_true`
   or a missing callback on a data-changing route is a Phase 3 finding, flagged here.
4. **Controller / handler** — the method that runs. Its inputs and where they come from.
5. **Service / model** — the business logic and the ORM/`$wpdb` calls it makes.
6. **DB** — the tables/columns read and written.
7. **Extension seams** — every `apply_filters` / `do_action` on the path (Phase 4 checks
   these still fire and still pass what addons expect).
8. **Tests** — the test file(s), if any, that exercise this slice (Phase 4 checks coverage).
9. **Cross-boundary keys** — any string key that crosses a boundary (Free↔Pro payload,
   localized JS var, REST field, option consumed by another layer). Name the keyspace each
   producer and consumer speaks and literal-diff them; parallel keyspaces for the same
   entity (UI source keys vs service slugs vs settings keys) are a classic silent break.

Output a compact slice map (the hops with their file:line). This is Phase 1's evidence —
show it before running the verification passes so the user can catch a mis-located slice
early (the cheap course-correction, mirroring new-feature's Phase 1 alignment gate).

**Check**: the slice is complete — every UI action reaches a DB effect and back, with no
"and then somehow it saves" gaps. An incomplete slice is not a pass; it's an UNKNOWN to
resolve before continuing.

## Phase 2 — Verify behavior (Tier ≥ Spot; runtime)

Static reading proves the code *exists*; it does not prove the feature *works*. Run it.

1. **Build first if the UI is involved.** Compiled assets under `assets/js/*` are
   **gitignored** — a fresh checkout has none. Run the **full** build (`npm run
   production` / `npm run dev` — the complete multi-entry build, never a single entry; a
   partial build clobbers `mix-manifest.json` / `assets/manifest.json` and blanks the
   admin UI, serving assets as `text/html`). Confirm the build succeeded before loading.
2. **Exercise the real feature.** If **`$verify`** is available, use it for a structured
   "run the app and observe behavior" pass. Otherwise drive it directly:
   - Prefer the browser-automation tools (`mcp__claude-in-chrome__*`) to load the real
     admin screen / public form / editor, perform the feature's core action, and capture a
     screenshot — plus a **GIF** (`gif_creator`) for any multi-step flow (open → configure
     → save → confirm). Capture frames before and after each action.
   - Read the **console** (`read_console_messages`) and **network** (`read_network_requests`)
     — a 200 that returns `{success:false}` or a silent JS error is a behavior finding a
     screenshot alone misses.
   - Exercise the states that break in production, not just the happy path: **empty,
     loading, error, permission-denied, and the filled/success** state.
3. **Compare against the intended contract** from Phase 0. Each `#### Scenario`'s
   `WHEN/THEN` is a concrete thing to reproduce. A scenario you cannot reproduce is a
   finding; a scenario with no test *and* no reproduction is an UNKNOWN, not a pass.

If the live app isn't reachable, say so and fall back to the strongest static evidence
(the exact handler + its assertions) — but mark those checks **UNKNOWN (not run at
runtime)**, never PASS. Do not launder "I read the code" into "I verified it works".

**Check**: the feature's core action produces its intended DB effect and UI result, with
clean console/network. Attach the screenshot/GIF as evidence.

## Phase 3 — Verify correctness & security (Tier ≥ Standard; scoped)

Run **`$pre-merge-review`** — but scoped to the feature's slice (the files from Phase 1),
not a branch diff. Feed it the slice file list as the review surface.

- **Standard tier → light**: the sequential pattern passes (WordPress-PHP, JS, Vue,
  backwards-compat, state-machine + adversarial inputs) over the slice files.
- **Deep / Critical tier → full**: add the seven parallel detectors (accessibility,
  async-races, ui-to-backend-wiring, permissions-and-capabilities, backwards-compat,
  error-handling-ux, performance-and-data-integrity).

Regardless of tier, confirm the WordPress non-negotiables *on this feature's handlers*:

- Every `$_GET`/`$_POST`/`$_REQUEST` sanitized with the right sanitizer + `wp_unslash()`.
- Every output escaped at the point of output (`esc_html`/`esc_attr`/`esc_url`/`esc_js`;
  data into inline `<script>` uses `wp_json_encode(..., JSON_HEX_TAG)`).
- Every REST/ajax route on the slice has a real policy or `permission_callback` — never
  `__return_true` on anything that changes data.
- Nonce verified BEFORE the capability check; `current_user_can()` on every data-modifying
  endpoint.
- All `$wpdb` calls with variables use `prepare()`; ORM queries are bounded (no unbounded
  `->get()` on a user-growable table).

**Break it, don't read it (every tier — the Debunk stance applied here).** For each
non-negotiable above on a data-changing / auth / money / PII endpoint, don't confirm the
guard by reading it — *construct and send the request that the guard should reject* and
observe the real response: the endpoint with the nonce stripped, with a no-capability
cookie, with an oversized or wrong-type value, with the wrong Free↔Pro keyspace. A guard
you triggered and watched hold is evidence; a guard you only read is UNKNOWN. When you
enumerate the slice's routes/actions to attack, enumerate against ground truth (permissive
raw grep + matching count, `[A-Za-z0-9_-]+` for ajax names) — a refute pass that never
fires on the hyphenated privileged action is how the broken-access-control gap ships green.

**Tier findings by impact-when-fired, not trigger probability.** A missing capability check
on a payment endpoint is High even if "you'd need to be logged in" — a contract violation
floors at High. Do not down-rank a real gap because it's "hard to hit".

**Check**: no Blocking correctness/security finding on the slice. Each finding carries a
file:line and a concrete trigger, not a category name.

## Phase 4 — Verify against intent (Tier ≥ Standard; the unique pass)

Phases 2–3 prove the code works and is safe. This phase proves it's still the *right*
code — that the shipped feature matches what was promised. This is the pass no generic
review gives you, and the reason to scope to one feature.

1. **Spec drift.** For each `#### Scenario` in the feature's spec, find the code that
   satisfies it (file:line) OR flag it as **unimplemented / regressed**. For each behavior
   in the code with no matching scenario, flag it as **undocumented** (spec is stale).
   Drift runs both directions.
2. **Success-signal check.** Read the `proposal.md` success signal (the one observable way
   you'd know it worked) and confirm the shipped feature can actually produce it. A feature
   that "works" but can't move its own success metric was mis-built — surface that.
3. **Extension-seam check.** Every `apply_filters`/`do_action` on the slice (from Phase 1):
   confirm it still fires, still uses the plugin prefix, and still passes the arguments its
   documented contract promises. A pro addon or third party hooks these — a silently
   dropped arg or renamed hook is a back-compat break even though nothing in the free
   plugin notices. Cross-check the payload keyspace on both producer and consumer.
4. **Test-coverage check.** For each scenario, is there a test — and is it at the **correct
   seam** (exercising the behavior at the real call site, not a shallower seam that gives
   false confidence)? Enumerate the feature's tests against ground truth; a coverage claim
   is only as trustworthy as the enumerator that made it. "No test" is a finding sized by
   the slice's risk (Critical tier: floor at High).
5. **Adversarial refute — full fresh-context skeptic (Tier ≥ Deep; escalation of the
   always-on Debunk stance).** Spot/Standard already refute inline in each phase; Deep and
   Critical escalate to a clean-context challenger. Run **`$doubt-driven-development`** on the
   headline claim *"this feature is healthy"*. Its CLAIM → EXTRACT → DOUBT → RECONCILE →
   STOP loop spawns a fresh-context skeptic to *refute* the verdict with concrete file:line
   evidence — so a clean bill of health has to survive challenge instead of being the
   default. **A CLEAN verdict on a high-value surface (money, auth, PII) that hasn't been
   refuted is not trustworthy** — refute it before you write PASS.

If a claim depends on how WPFluent / WP-core / a vendored library actually behaves, ground
it with **`$source-driven-development`** against the vendored source or official docs — do
not verify against a remembered API. Tag anything you can't ground `UNVERIFIED:` so it's
visible, never silently asserted as PASS.

**Check**: reality matches the stated intent, or every gap between them is a logged finding.

## Phase 5 — Report (always; ~3 min)

Write one **Feature Health Report**. Output path, in priority order:

1. `/Volumes/Workspace/feature-checks/<repo>/<feature-slug>.md` — if `/Volumes/Workspace`
   exists (do **not** create it if missing — that signals the machine isn't set up for
   hosted reports and the fallback is correct).
2. `<repo-root>/.review/<feature-slug>-health.md` — fallback.
3. `openspec/changes/<change-name>/FEATURE-HEALTH.md` — if the feature is tracked in an
   openspec change.

Report shape:

```
# Feature Health — <Canonical Noun>
**Repo:** <repo> | **Branch:** <branch> | **Date:** <YYYY-MM-DD> | **Tier:** <tier> | **Checker:** <model>

## Verdict
HEALTHY | HEALTHY-WITH-FINDINGS | DEGRADED | BROKEN — one sentence of why.

## Slice map
<the Phase 1 hops: UI → transport → auth → handler → service → DB → seams → tests, each with file:line>

## Checks
| Phase | Check | Verdict | Evidence |
|---|---|---|---|
| 2 Behavior | core action works at runtime | PASS/FINDING/UNKNOWN | screenshot / file:line |
| 3 Correctness | security non-negotiables on slice | ... | ... |
| 4 Intent | spec scenarios ↔ code | ... | ... |
| 4 Intent | test coverage at correct seam | ... | ... |
| ... | ... | ... | ... |

## Findings
<grouped by severity: Blocking / High / Medium / Low. Each = heading + file:line +
trigger + recommended route ($bug-fix for a defect, $new-feature for a missing capability).
Severity by impact-when-fired; contract violations floor at High.>

## Unknowns
<anything NOT verified at runtime — explicitly, so "not checked" never reads as "fine".>
```

**Re-runnable** (mirrors `$pre-merge-review`): if a report already exists at the path, read
its findings, re-run every check against the **current** slice (not just what changed since
last run — delta-only scrutiny is how earlier findings survive every re-run), mark resolved
findings `[cleared]`, archive the prior report to `<feature-slug>-<short-sha>.md`, and append
a `## Re-run history` line with sha, date, and counts. This lets you check the same feature
before each release and watch its health trend.

**Never launder unknowns into passes.** A verdict of HEALTHY means every check is PASS with
evidence. Any UNKNOWN caps the verdict at HEALTHY-WITH-FINDINGS and is listed explicitly.

**Route the fixes, don't apply them.** Present the report. For Blocking/High findings, offer
to hand off: **`$bug-fix`** for a defect (it builds the reproduction FIRST — do not
hypothesize before you can reproduce), **`$new-feature`** for a missing capability. This
skill's job ends at the verdict; keeping check and fix separate is what keeps the verdict
honest.

## What NOT to do

- **Don't skip Phase 1.** A verification pass over an incomplete slice map silently skips
  the hop where the bug lives. Map the whole vertical slice first.
- **Don't call a static read a runtime pass.** If you didn't run it, the behavior check is
  UNKNOWN, not PASS. Say so.
- **Don't trust your own enumerator.** Any "I found all the routes / actions / tests /
  seams" claim gets checked against a permissive raw grep with a matching count. A buggy
  enumerator doesn't just under-report — it hides the exact gap the check exists to catch.
- **Don't down-rank real gaps as unlikely.** Severity is impact-when-fired; contract and
  security violations floor at High regardless of how hard they are to trigger.
- **Don't fix in place.** This skill verifies and reports. Route defects to `$bug-fix`,
  missing capability to `$new-feature`. A checker that also patches loses the independence
  that makes its verdict worth anything.
- **Don't use this for a whole-plugin sweep** (that's `$plugin-audit`) **or a branch diff**
  (that's `$pre-merge-review`). This skill is scoped to ONE named feature, end to end.

## Stack adaptation

On a non-WordPress stack (Node, Python, etc.), keep the phase structure and swap the
stack-specific rules in Phases 2–3 (the WP sanitize/escape/nonce/policy list). The
locate → map → verify-behavior → verify-correctness → verify-intent → report spine is
stack-agnostic.

## Invocation

```text
Use $check-feature
```

Or, in any agent that doesn't auto-resolve skills:

```text
Read ~/.claude/skills/check-feature/SKILL.md and follow it to check <feature>.
Start with Phase 0 — locate the feature, establish its intended contract, and tell me
the tier before running the verification passes.
```
