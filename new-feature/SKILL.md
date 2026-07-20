---
name: new-feature
description: >
  End-to-end composite workflow for building a new feature in a WordPress plugin
  with PHP plus a per-repo frontend stack (Vue 2, Vue 3, or Gutenberg React —
  read CLAUDE.md to confirm). Orchestrates grill-with-docs → openspec →
  design-an-interface → tdd → pre-merge-review → pr-descriptor
  → openspec archive. Six numbered phases with explicit approval gates between
  each. Skips phases automatically for trivial changes; gates harden for big ones.
when_to_use: >
  Use when starting a new feature, capability, or non-trivial enhancement in
  a WPManageNinja-style plugin. Invoke as $new-feature or with "use the new-feature
  workflow". For a typo fix or single-line tweak, do not invoke — just commit.
context: fork
allowed-tools: Read Write Edit Bash(git *) Bash(gh *) Bash(grep *) Bash(find *) Bash(openspec *) Bash(rg *) Bash(composer *) Bash(npm *) Bash(open *)
effort: high
---

# New Feature — Composite Workflow

This is not a detector skill. It's an **orchestrator** that composes the
existing single-purpose skills into one workflow with approval gates. Use it
when you don't want to manually decide which skill to invoke when — the
phase-by-phase structure decides for you.

## Phase 0 — Triage (pick the intensity)

**Start-of-run hygiene:** list `openspec/changes/`. For any change whose PR
has already merged (check with `gh pr list --state merged --search <name>`),
run `openspec archive <name>` now. This is the backstop for Phase 6 step 4,
which runs after merge — usually in a dead session that can't remind anyone.

**First, read `CLAUDE.md` and `AGENTS.md` from the project root if either
exists.** They override the defaults in this skill — commit format,
sanitizer choice, hook prefix, base branch, REST namespace. Skipping
this step means Phase 4 may use the wrong patterns.

**Then ask what we're building — artifact or description, both are
first-class answers.** Phrase it openly, e.g.: *"What are we working on?
An issue #, PRD, or openspec change name is great — or just describe the
feature or bug in your own words."* Accept any of:

- A GitHub issue #
- A PRD path (any external product doc)
- An openspec change name (if a previous run already scaffolded it)
- A tracer-bullet / spike issue
- **A plain-language description** — "users can't export entries with
  conditional logic", "we need a duplicate-form button". Never bounce
  the user back to go file an issue first; the description IS the input.

If an artifact exists, read it BEFORE the grill in Phase 1. It already
answers "why" and often the canonical noun — the grill becomes a
confirmation pass, not a re-discovery. Record the issue # / PRD path so
Phase 6 can reference it in the PR description and close the loop.

If the answer is a description (raw intent), that's equally fine —
restate it back in one sentence to confirm you heard it right, then note
explicitly that Phase 1 is doing first-pass discovery, not confirmation.
If the description sounds like a bug rather than a feature, offer
`$bug-fix` instead before proceeding.

Then look at the request and pick a tier:

| Tier | Signal | Workflow |
|---|---|---|
| **Trivial** | Typo, config tweak, single-line copy change | Skip this skill entirely. Just commit. |
| **Small** | Single-file fix, one-component cosmetic change | Phase 5 light only (use `$pre-merge-review light`). |
| **Medium** | One new Vue panel, one new endpoint, one bugfix touching ~3 files | Phases 2 + 4 + 5 light (+ Phase 4.5 if it adds/reshapes a visible UI surface). Skip the grill if you already know the answer. |
| **Large** | New module / service / policy / capability / data migration | Full workflow, Phase 4.5 UI demo, Phase 5 deep. |
| **Breaking** | API change, schema migration, removed feature | Full workflow + mandatory Phase 1 + `/plugin-audit` post-merge. |

Announce the tier you picked and why. If the user disagrees, recalibrate before
moving on. The tier must survive the evidence: if the diff (or
`detect_changes`) shows Breaking signals — schema change, removed hook,
changed REST signature — escalate to the higher tier even if the request
sounded Small. Self-declared tiers don't override what the diff says.

## Optional: code-review-graph integration

If the project has a code-review-graph MCP server (check for `.mcp.json`
with `code-review-graph` or a `.code-review-graph/` cache directory),
use its tools BEFORE grep/find when the phase needs structural answers:

| Phase | Graph tool | What it answers |
|---|---|---|
| 0 Triage | `detect_changes --base dev` | Risk score, affected flows — helps pick the tier |
| 1 Align | `get_architecture_overview`, `list_communities` | Where does this feature land in the existing structure? |
| 3 Spec/design | `query_graph imports_of`, `semantic_search_nodes` | Existing seams, prior art for the noun |
| 4 Build | `query_graph callers_of <fn>`, `query_graph tests_for <fn>` | Before changing a function: who calls it, what tests cover it |
| 5 Review | `detect_changes`, `get_review_context` | Run before `$pre-merge-review`; feed the risk-scored priority list into the reviewer's attention budget |

The graph auto-updates via the project's `PostToolUse` hook on every
Edit/Write — no manual rebuild. Always cross-check `detect_changes`
results against `git diff` on a clean branch; the graph occasionally
lists stale files.

Fall back to grep/find only when the graph doesn't cover the question.

## Context for every WP plugin

- **Stack**: PHP (WPFluent framework) + frontend. **Frontend stack varies per repo — read CLAUDE.md first**:
  - FluentPlayer + Pro: Vue 3 (Composition API + `<script setup>`) + React/JSX (Gutenberg apiVersion 3) + Vite multi-entry.
  - FluentForm + Pro: Vue 2 (Options API) + Laravel Mix. No Gutenberg block surface in fluentform itself.
- **Hook prefix**: `<plugin-slug>/` (read CLAUDE.md or package.json to confirm).
- **Text domain**: matches plugin slug. PHP `__('text', '<slug>')`.
- **REST**: `<slug>/v1` namespace. Controllers in `app/Http/Controllers/`,
  policies in `app/Http/Policies/`. Routes in `app/Http/Routes/api.php`.
- **Base branch**: `dev` (not `main`).
- **Commit format**: prefix-style (`Add:`, `Fix:`, `Improve:`, `Refactor:`).
  No `Co-Authored-By` trailer. No `PR:` trailer unless the project requires it.
- **CLAUDE.md / AGENTS.md**: read these first if present. They override defaults.

## Phase 1 — Align (Tier ≥ Medium; ~3 min)

Invoke **`$grill-with-docs`** (matt-pocock). Interview the user until you share
vocabulary. Specifically resolve:

- Single canonical noun for the feature.
- The problem it solves + who hits it today.
- The smallest version that delivers value.
- Existing terms in `CONTEXT.md` / `ADRs` that constrain the design.

Update `CONTEXT.md` inline as terms get resolved (matt's grill skill does this
automatically). Do not proceed until the user agrees on a one-sentence problem
statement.

**Gate**: show the user the problem statement + canonical noun. Wait for "yes".

## Phase 2 — Plan (Tier ≥ Medium; ~5 min)

**Inputs: the canonical noun.** Sources, in priority order: Phase 1's grill;
the upstream artifact's title (issue / PRD); if Phase 1 was skipped and no
artifact names one, ask the user for the noun directly before proceeding —
never improvise it.

1. Pick a change name. Convention:
   - **If an upstream issue # was identified in Phase 0**: name = `issue-<n>-<canonical-noun>` (e.g. `issue-142-conditional-logic-export`). This creates a durable two-way link between the openspec change directory and the issue tracker — grep `issue-142` in either place finds both.
   - **Otherwise**: kebab-case canonical noun alone (e.g. `conditional-logic-export`).
2. `openspec new change <name>` — scaffolds `openspec/changes/<name>/`.
3. Run `openspec instructions --change <name> proposal` to see the template.
4. Write `proposal.md`:
   - **Why** — 1–2 sentences
   - **Who + problem** — who hits this today (from Phase 1's grill), what it costs them.
   - **Success signal** — one observable way you'll know it worked (a metric, a
     support-ticket class that disappears, a task that gets faster). "Definition of
     done" at the product level, not the test level. If you can't name one, the
     feature may not be worth building — surface that.
   - **Analytics / telemetry** — does this need event tracking? The plugin ships an
     analytics module; state explicitly "yes, track X" or "no telemetry" so it's a
     decision, not an omission.
   - **Free vs Pro placement** — does this land in the free plugin or the Pro addon
     (and if Pro, what min-Pro-version does the free side require)? This is
     expensive to reverse once shipped — force the call here, not at review time.
   - **What Changes** — bullet list (mark `BREAKING` explicitly)
   - **Capabilities** — `New Capabilities` + `Modified Capabilities` (kebab-case names)
   - **Impact** — affected code / APIs / dependencies
   - **Non-Goals** — what this deliberately does NOT do (scope fence).

For Tier ≥ Large, ALSO invoke **`$design-an-interface`** (matt). Generate 3+
radically different designs in parallel sub-agents — assign each a divergent
constraint (e.g. "minimize method count," "maximize flexibility,"
"optimize for the most common case"). Present, compare, pick one. Record the
chosen design in `design.md` later.

**Gate**: show `proposal.md` (and selected interface design if you ran
design-an-interface). Wait for "yes".

## Phase 3 — Spec (Tier ≥ Medium; ~5 min)

1. Write `specs/<capability>/spec.md`:
   - `### Requirement: <name>` with SHALL/MUST language
   - One or more `#### Scenario: <name>` blocks with `**WHEN**` / `**THEN**`
   - Every scenario is a future test
2. Write `design.md`:
   - Context, Goals/Non-Goals, Decisions (with alternatives + rationale),
     Risks/Trade-offs, Migration Plan, Open Questions
   - **Ground every API-dependent decision** via **`$source-driven-development`** before writing it
     down. Any WPFluent/Vidstack/hls.js/Gutenberg/WP-core behavior the design relies on must be
     verified against the vendored source or official docs, not memory. Tag anything still unverified.
3. Write `tasks.md`:
   - Numbered groups (`## 1. Setup`, `## 2. Core implementation`)
   - Tasks as `- [ ] N.M description`
   - Tasks small enough to complete in one session
4. `openspec validate <name> --strict` — must pass.

**Gate**: show spec + tasks. Wait for "yes".

**Breaking tier — doubt before the gate.** If Phase 0 classed this **Breaking** (API change,
schema migration, removed feature, public hook-contract change), run **`$doubt-driven-development`**
on the core decision *before* presenting the gate. Its CLAIM → EXTRACT → DOUBT → RECONCILE → STOP
loop spawns a fresh-context skeptic to refute the design; carry any accepted-doubt mitigations into
`design.md` and `tasks.md`. A Breaking spec that hasn't survived the doubt loop is not ready to gate.

**Gate batching (optional):** working solo on a well-understood feature, you
may present the Phase 2 and Phase 3 gates together (proposal + spec + tasks,
one "yes"). Never batch the Phase 1, Phase 5, or Phase 6 gates — alignment,
pre-push, and PR consent always stand alone. Rubber-stamped gates are worse
than no gates.

## Phase 4 — Build (always; ~time varies)

**Before coding against any external API**, verify it with **`$source-driven-development`** — the exact
WPFluent/Vidstack/hls.js/Gutenberg/WP-core signature, event name, or hook contract, checked against the
vendored source (the version this repo actually ships) or official docs. Do not write against a
remembered API. This is where most confident-but-wrong code originates.

Follow **`$tdd`** (matt) red-green-refactor for each scenario:

1. **Red**: write the failing test at the correct seam (matt's "correct seam"
   check — the test must exercise the bug pattern as it occurs at the call
   site, not at a shallower seam that gives false confidence).
2. **Green**: minimum code to pass.
3. **Refactor**: simplify against the code-quality rules below — only after green. If a `$simplify` (or equivalent refactor) skill is available in the current environment, invoke it; otherwise refactor manually.

Code-quality rules (do not skip):

- **Clean, simple, readable code first.** Prefer obvious, boring code over clever
  abstractions. Short functions with intention-revealing names. No premature
  generalization, no unused parameters "for the future," no helper layers that
  exist to be helpers. If a reader has to hold three jumps in their head to
  understand one method, the method is doing too much. Three similar lines beat
  a premature abstraction.
- **No comments that restate code.** Comment only the non-obvious *why* —
  hidden constraint, subtle invariant, workaround. Well-named identifiers
  describe the *what*.
- **Boring is a feature.** Use existing patterns in the codebase before inventing
  new ones. Match the surrounding style (PSR-12 PHP, repo's PHP-CS-Fixer config,
  Vue Composition API, Element Plus).
- **No half-done implementations or feature flags for code not yet written.**

WordPress-specific rules (do not skip):

- Every `$_GET` / `$_POST` / `$_REQUEST` sanitized with the right sanitizer + `wp_unslash()`.
- Every output escaped at the point of output (`esc_html`, `esc_attr`, `esc_url`, `esc_js`).
- Every REST route has a policy class OR explicit `permission_callback` — never `__return_true`.
- All `$wpdb` calls with variables use `prepare()`.
- Nonce verified BEFORE capability check on every AJAX/REST handler.
- `current_user_can()` on every data-modifying endpoint.
- Hook names use the plugin prefix.
- **Use WordPress hooks and filters at meaningful seams.** WP plugins live or die
  by their extension surface — pro addons, third-party integrations, and the
  user's own functions.php all hook in. When you write a new resolver, service,
  or render path, ask: "where would a Pro plugin need to short-circuit, extend,
  or observe this?" Then expose a filter (`apply_filters('plugin_slug/...', ...)`)
  or action (`do_action('plugin_slug/...', ...)`) there. Two filters at the right
  seams beat ten convenience methods. Without them, addons must fork.
  - Pre-filter: lets addons short-circuit a computation by returning a non-default
    value (default arg = `null`, listener returns array/object to take over).
  - Post-filter: lets addons extend/transform a result before it's returned.
  - Action: lets addons observe a lifecycle event (no return value).
  Use the plugin's hook prefix (look in CLAUDE.md). Document the filter contract
  in a comment above `apply_filters` so addon authors know what to return.
- Vue style follows the target repo: FluentPlayer family uses Vue 3 Composition API + `<script setup>` (no Options API for new code); FluentForm family uses Vue 2 Options API. Read CLAUDE.md to confirm.
- React Gutenberg blocks (where applicable) use apiVersion 3 (iframe-aware).

After each milestone task in `tasks.md`:

1. Mark the checkbox `[x]`.
2. Commit with the project's prefix format. No `Co-Authored-By`. No `PR:` trailer.
3. Do NOT `git push` without explicit user consent. Once-approved is not
   forever-approved.

**After creating any new PHP class file:** run `composer dump-autoload` from the
plugin root (and `composer dump-autoload --working-dir=dev` for test classes).
Many WordPress plugins build their `vendor/composer/` with
`--classmap-authoritative`, which disables PSR-4 dynamic fallback — new classes
become invisible until the autoloader is regenerated. Symptom of forgetting:
PHP Fatal `Class "X\Y\Z" not found` even though the file exists and `php -l`
passes. Verify with `grep <ClassName> vendor/composer/autoload_classmap.php`
before declaring the feature done.

### `/build auto` — autonomous task stepping (opt-in)

Invoked as `$new-feature` then "build auto", or when the user says "build it out" / "run it
autonomously". After the Phase 3 gate is approved, step through `tasks.md` **one task at a time**
without pausing for approval *between* tasks. Every task still gets the full loop — `$tdd`
red-green-refactor, then commit as its own atomic checkpoint. Autonomy removes the manual stepping,
never the discipline.

**Pause and hand back to the user when:**
- A test can't be greened in one red-green cycle → stop, surface the failure, don't paper over it.
- The next task requires an **irreversible or high-stakes decision** (schema change, public
  hook-contract change, capability change, deleting code you didn't write) → run
  **`$doubt-driven-development`** on it and present the go/no-go before proceeding.
- An API behavior is unverified → resolve via **`$source-driven-development`** before coding, or
  pause if it can't be grounded.
- A new PHP class was created → run `composer dump-autoload` (see below) before the next task.

Never auto-`git push`. `/build auto` commits locally; the Phase 5 review and Phase 6 push gates
still stand alone.

If a bug surfaces during dev, invoke **`$bug-fix`** — build the
feedback loop FIRST. Do not hypothesize before you can reproduce.

If you get lost in the codebase, invoke **`$zoom-out`** (matt) if available in
the current environment for a higher-level map of the area; otherwise build the
map manually (`get_architecture_overview` from code-review-graph, or a quick
directory + entry-point sweep).

If a section feels architecturally wrong, defer to post-merge and invoke
**`$improve-codebase-architecture`** (matt) later. Do not refactor the world
mid-feature.

## Phase 4.5 — UI Demo & Runtime Verify (Tier ≥ Large, OR any new/changed user-facing UI surface)

Tests and static review prove the code is *correct*; they do not prove the
feature *looks and behaves* the way anyone intended. For anything significant —
a new module, a new admin panel or settings screen, a new Gutenberg block, a
changed player control — build it, run it, and show the user the real UI before
asking them to sign off on the review.

**Don't ask about obvious cases — only ask when the demo is a real judgment
call.** Decide silently:

- **Obvious skip** — backend-only change, or a small/cosmetic UI tweak (copy
  edit, spacing, a single label, an icon swap). Skip the demo, don't ask, just
  announce the skip in one line and move to Phase 5. Asking here is noise.
- **Obvious demo** — a genuinely new module, admin panel, settings screen, or
  Gutenberg block. Building a demo is clearly warranted; just do it (still
  respecting the build cost — see below), no need to ask permission first.
- **Ask only in the middle** — a substantial change to an existing surface where
  it's a real toss-up whether a demo earns its cost: *"This reshapes the X
  screen. Want a runtime demo (screenshots / GIF) before review, or skip to
  review?"* Generating one costs a full build + browser run and the user may
  already have it open.

If it's skipped (obvious or by the user's choice), go straight to Phase 5.
Otherwise:

1. **Full build, not a partial one.** Run `npm run build` (the complete
   multi-entry build + manifest merge), never a single entry. A partial build
   clobbers `assets/manifest.json` and blanks the admin UI (assets served as
   `text/html`) — a known footgun in this repo. Confirm the build succeeded
   before loading anything.
2. **Run it and capture the UI.** Load the real screen and capture what the user
   will see:
   - Prefer the browser-automation tools (`mcp__claude-in-chrome__*`) to
     navigate to the admin page / block editor / front-end player, then take a
     screenshot — and a **GIF** (`gif_creator`) for any multi-step flow (open →
     configure → save). Capture frames before and after each action.
   - If the live app isn't reachable, generate a **self-contained demo HTML**
     that renders the new component/states against the real built CSS, write it
     to `.review/<change-name>-ui-demo.html`, and `open` it.
   - Capture the meaningful states, not just the happy path: empty, loading,
     error, and a filled/success state.
3. **Show the user the demo** (screenshots / GIF / demo file path) alongside a
   one-line note on what to look at. This is where UX problems that no test
   catches surface — misalignment, missing labels, awkward flow, wrong copy.
4. **Accessibility spot-check while it's on screen** (CLAUDE.md rule 13): every
   icon-only control has a localized `aria-label`; nothing conveys state by color
   alone; all visible strings go through `$t(...)` / `__()`. The DEEP a11y
   detector runs in Phase 5, but catching it here — with the UI in front of you —
   is cheaper than a review finding.

If available, `Use $verify` for a structured "run the app and observe behavior"
pass, and `$impeccable` if the UI needs a design/polish critique before shipping.

**Gate**: show the demo. Wait for "yes" before moving to review.

## Phase 5 — Review (always; ~3 min light / ~10 min deep)

Pick intensity:

- **LIGHT** (Tier ≤ Medium): `Use $pre-merge-review light`.
  Single-pass sanity sweep — only the sequential pattern passes (WordPress-PHP,
  JavaScript, Vue, backwards-compat, state-machine + adversarial inputs). Skips
  the parallel detectors. Use for tiny single-file diffs.

- **DEEP** (Tier ≥ Large, default): `Use $pre-merge-review`.
  Seven specialised detectors in parallel (accessibility, async-races,
  ui-to-backend-wiring, permissions-and-capabilities, backwards-compatibility,
  error-handling-ux, performance-and-data-integrity) PLUS the sequential pattern
  passes. Writes a single re-runnable report to
  `/Volumes/Workspace/pr-reviews/<repo>/<branch>.md` (fallback
  `<repo>/.review/<branch>.md`). Address every Blocking before push.
  Re-run after fixing — it marks resolved findings `[cleared]`.

If pre-merge-review flags a category you don't fully understand, `$zoom-out`
(if available; otherwise map the area manually) to see how it fits the broader
codebase before changing the code.

If a review finding is **high-stakes and the fix itself is non-trivial or irreversible** (reworking a
migration, changing a hook contract to resolve a back-compat flag), run
**`$doubt-driven-development`** on the proposed fix before applying it — a rushed fix to a serious
finding is how the second bug ships.

**Gate**: show the report. Wait for "yes" before pushing.

## Phase 6 — Ship (always; ~2 min)

1. `Use $pr-descriptor` to draft the PR description from the actual git diff.
   It reads `.github/PULL_REQUEST_TEMPLATE.md` if present, otherwise its
   bundled default.
   - **If an upstream issue # was identified in Phase 0**, ensure the PR
     description includes a closing reference: `Closes #<n>` for features /
     enhancements, `Fixes #<n>` for bug fixes. GitHub auto-closes the issue
     when the PR merges to the default branch — no manual cleanup needed.
   - If you skipped Phase 0's upstream-artifact check, do it now before
     drafting. A PR with no issue reference is harder to triage later.
2. Show the user the draft.
3. **Ask before running `gh pr create`**. Never open the PR or push without
   explicit consent. Once-approved is not forever-approved.
4. After the PR merges:
   - `openspec archive <change-name>` — moves the change into `specs/` and
     marks it done. (If this session is gone by merge time, Phase 0's
     start-of-run hygiene check archives it on the next run.)
   - Verify the upstream issue closed automatically (the `Closes #<n>` /
     `Fixes #<n>` reference should have triggered it). If it didn't (e.g.
     PR merged to a non-default branch first), close manually:
     `gh issue close <n> --comment "Shipped in #<pr-number>"`.

## Optional post-merge

- **Quarterly**: `Use $plugin-audit` for full security + perf + dead-code +
  traceability sweep.
- **If feature introduced new domain terms**: append to `CONTEXT.md`.

## What NOT to do

- **Don't skip Phase 1 on Tier ≥ Large even if you "know what to build"** — the
  grilling catches the communication gap that costs 10× to fix later. (Medium
  may skip it per the tier table, but must then resolve the canonical noun via
  the Phase 2 inputs rule.)
- **Push/PR consent** — see the rules in Phase 4 (push) and Phase 6 (PR).
  Once-approved is not forever-approved.
- **Don't fold the workflow into one mega-step.** The gates between phases
  are where course corrections happen cheaply.
- **Trivial-tier filter** — see Phase 0 table. Trivial changes skip
  this skill entirely.
- **Don't refactor the codebase mid-feature.** Defer to `/improve-codebase-architecture`
  post-merge.

## Stack adaptation

If the user is on a non-WordPress stack (Node, Python, etc.), keep the phase
structure but swap the stack-specific rules in Phase 4. The skill structure is
stack-agnostic; only the WordPress-specific bullet list (sanitize/escape/nonce)
changes.

## Invocation

```text
Use $new-feature
```

Or, in any agent that doesn't auto-resolve skills:

```text
Read /Volumes/Projects/Tools/agent-skills/new-feature/SKILL.md and follow it
for this feature. Start with Phase 0 — pick the tier and tell me before
proceeding.
```
