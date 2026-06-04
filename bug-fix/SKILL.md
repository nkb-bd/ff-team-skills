---
name: bug-fix
description: >
  Disciplined bug-handling workflow. Default mode: fix a known bug via reproduce → minimise →
  hypothesise → instrument → fix → regression-test. Discovery mode (`/bug-fix find`): sweep
  the plugin for new bugs using a Finder → Verifier → Feedback loop. Replaces the previous
  `diagnose` and `debugger` skills.
when_to_use: >
  User says "fix this bug", "diagnose this", "debug this", "find bugs in this plugin",
  "what's wrong with X", reports a regression, says something is broken / throwing / failing,
  or describes a performance regression. Default to fix-mode unless they explicitly ask
  for a bug-discovery sweep.
context: fork
allowed-tools: Read Write Edit Bash(git *) Bash(grep *) Bash(rg *) Bash(find *) Bash(npm *) Bash(composer *) Bash(php *) Bash(node *)
effort: high
---

# Bug Fix

The single canonical bug-handling skill. Replaces `diagnose` (the reproduce → fix loop) and `debugger` (the Finder → Verifier → Feedback sweep), merged on 2026-05-21.

Two modes:

- **Fix (default)** — user has reported a specific bug. Six phases: build a feedback loop → reproduce → hypothesise → instrument → fix + regression-test → cleanup. Triggered by "fix this", "diagnose this", "debug this", a bug report, or a failing-CI message.
- **Find (`/bug-fix find`)** — sweep the plugin for new bugs. Finder → Verifier → Feedback pipeline writes a severity-grouped report. Triggered by "find bugs", "sweep this plugin", or "audit for bugs".

If the user's intent isn't obvious from the trigger phrase, ask once. A wrong-mode start wastes 10–20 minutes.

---

# Mode A — Fix (default)

A discipline for hard bugs. Skip phases only when explicitly justified.

When exploring the codebase, use the project's domain glossary (`CONTEXT.md`) for a clear mental model of the relevant modules and check ADRs in the area you're touching.

## code-review-graph context, when available

If the repo has `code-review-graph` wired (`.mcp.json` mentions `code-review-graph`, `.code-review-graph/` exists, or MCP tools such as `query_graph`, `semantic_search_nodes`, `get_impact_radius`, or `detect_changes` are callable), use it before grep for structural questions:

| Debugging question | Prefer graph tool | Cross-check |
|---|---|---|
| What changed near the reported regression? | `detect_changes` | `git diff`, recent commits, failing test output |
| Who calls the suspected function/class? | `query_graph callers_of <symbol>` | targeted `rg` for the symbol |
| What imports/depends on the changed module? | `query_graph importers_of <symbol>` or `get_impact_radius` | targeted `rg` and direct file reads |
| What tests already cover this path? | `query_graph tests_for <symbol>` or equivalent | repo test tree and test command output |
| Is there a better regression-test seam? | callers/dependents plus tests graph | manual call-path read |

Use graph output to choose hypotheses and test seams, not as proof. Treat graph data as potentially stale; if it conflicts with the live source, trust `git diff`, targeted `rg`, and direct file reads.

If graph is not available, continue with git diff, `rg`, and focused file reads.

## Phase 1 — Build a feedback loop

**This is the skill.** Everything else is mechanical. If you have a fast, deterministic, agent-runnable pass/fail signal for the bug, you will find the cause — bisection, hypothesis-testing, and instrumentation all just consume that signal. If you don't have one, no amount of staring at code will save you.

Spend disproportionate effort here. **Be aggressive. Be creative. Refuse to give up.**

### Ways to construct one — try in roughly this order

1. **Failing test** at whatever seam reaches the bug — unit, integration, e2e.
2. **Curl / HTTP script** against a running dev server.
3. **CLI invocation** with a fixture input, diffing stdout against a known-good snapshot.
4. **Headless browser script** (Playwright / Puppeteer) — drives the UI, asserts on DOM/console/network.
5. **Replay a captured trace.** Save a real network request / payload / event log to disk; replay through the code path in isolation.
6. **Throwaway harness.** Spin up a minimal subset of the system (one service, mocked deps) that exercises the bug code path with a single function call.
7. **Property / fuzz loop.** If the bug is "sometimes wrong output", run 1000 random inputs and look for the failure mode.
8. **Bisection harness.** If the bug appeared between two known states (commit, dataset, version), automate "boot at state X, check, repeat" so you can `git bisect run` it.
9. **Differential loop.** Run the same input through old-version vs new-version (or two configs) and diff outputs.
10. **HITL bash script.** Last resort. If a human must click, drive *them* with a structured loop so the loop is still mechanical. Captured output feeds back to you.

Build the right feedback loop, and the bug is 90% fixed.

### Iterate on the loop itself

Treat the loop as a product. Once you have *a* loop, ask:

- Can I make it faster? (Cache setup, skip unrelated init, narrow the test scope.)
- Can I make the signal sharper? (Assert on the specific symptom, not "didn't crash".)
- Can I make it more deterministic? (Pin time, seed RNG, isolate filesystem, freeze network.)

A 30-second flaky loop is barely better than no loop. A 2-second deterministic loop is a debugging superpower.

### Non-deterministic bugs

The goal isn't a clean repro but a **higher reproduction rate**. Loop the trigger 100×, parallelise, add stress, narrow timing windows, inject sleeps. A 50%-flake bug is debuggable; 1% is not — keep raising the rate until it's debuggable.

### When you genuinely cannot build a loop

Stop and say so explicitly. List what you tried. Ask the user for: (a) access to whatever environment reproduces it, (b) a captured artifact (HAR file, log dump, core dump, screen recording with timestamps), or (c) permission to add temporary production instrumentation. Do **not** proceed to hypothesise without a loop.

Do not proceed to Phase 2 until you have a loop you believe in.

## Phase 2 — Reproduce

Run the loop. Watch the bug appear.

Confirm:

- [ ] The loop produces the failure mode the **user** described — not a different failure that happens to be nearby. Wrong bug = wrong fix.
- [ ] The failure is reproducible across multiple runs (or, for non-deterministic bugs, at a high enough rate to debug against).
- [ ] You have captured the exact symptom (error message, wrong output, slow timing) so later phases can verify the fix actually addresses it.

Do not proceed until you reproduce the bug.

## Phase 3 — Hypothesise

Generate **3–5 ranked hypotheses** before testing any of them. Single-hypothesis generation anchors on the first plausible idea.

Each hypothesis must be **falsifiable**: state the prediction it makes.

> Format: "If <X> is the cause, then <changing Y> will make the bug disappear / <changing Z> will make it worse."

If you cannot state the prediction, the hypothesis is a vibe — discard or sharpen it.

**Show the ranked list to the user before testing.** They often have domain knowledge that re-ranks instantly ("we just deployed a change to #3"), or know hypotheses they've already ruled out. Cheap checkpoint, big time saver. Don't block on it — proceed with your ranking if the user is AFK.

## Phase 4 — Instrument

Each probe must map to a specific prediction from Phase 3. **Change one variable at a time.**

Tool preference:

1. **Debugger / REPL inspection** if the env supports it. One breakpoint beats ten logs.
2. **Targeted logs** at the boundaries that distinguish hypotheses.
3. Never "log everything and grep".

**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup at the end becomes a single grep. Untagged logs survive; tagged logs die.

**Perf branch.** For performance regressions, logs are usually wrong. Instead: establish a baseline measurement (timing harness, `performance.now()`, profiler, query plan), then bisect. Measure first, fix second.

## Phase 5 — Fix + regression test

Write the regression test **before the fix** — but only if there is a **correct seam** for it.

A correct seam is one where the test exercises the **real bug pattern** as it occurs at the call site. If the only available seam is too shallow (single-caller test when the bug needs multiple callers, unit test that can't replicate the chain that triggered the bug), a regression test there gives false confidence.

**If no correct seam exists, that itself is the finding.** Note it. The codebase architecture is preventing the bug from being locked down. Flag this for the next phase.

If a correct seam exists:

1. Turn the minimised repro into a failing test at that seam.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 feedback loop against the original (un-minimised) scenario.

## Phase 6 — Cleanup + post-mortem

Required before declaring done:

- [ ] Original repro no longer reproduces (re-run the Phase 1 loop)
- [ ] Regression test passes (or absence of seam is documented)
- [ ] All `[DEBUG-...]` instrumentation removed (`grep` the prefix)
- [ ] Throwaway prototypes deleted (or moved to a clearly-marked debug location)
- [ ] The hypothesis that turned out correct is stated in the commit / PR message — so the next debugger learns

**Then ask: what would have prevented this bug?** If the answer involves architectural change (no good test seam, tangled callers, hidden coupling) hand off to `/improve-codebase-architecture` with the specifics. Make the recommendation **after** the fix is in, not before — you have more information now than when you started.

---

# Mode B — Find (`/bug-fix find`)

Use this when the user wants a bug-discovery sweep, not a single-bug fix. Default: WordPress plugin codebases (the repo shape this skill knows best).

## Required outputs

- Write to `bug-discovery-report.md` at the repository root, using `references/report-template.md` as the shape.
- Group confirmed findings by severity (`Critical`, `High`, `Medium`, `Low`).
- Keep feedback inside the same report file (no separate feedback file).
- Don't silently drop weak findings — put them in `Rejected candidates` or `Needs manual verification`.
- For each confirmed finding, include both `Risk classification` (`Bug` or `Hardening`) and `Severity rationale`.

### Output hygiene

- Produce a final report, not a template dump.
- Never include template helper/instruction text in the final output.
- Specifically remove lines like `Use this field set for each confirmed bug:` and any placeholder-only bullets/headings.
- Omit empty severity sections under `Confirmed bugs by severity`.
- Never print placeholder text such as `_No confirmed critical findings in this pass._`.

## Quick-run prompt

```
Use $bug-fix find on this plugin. Run Finder → Verifier → Feedback, keep only verifier-confirmed
issues, and generate bug-discovery-report.md with per-bug feedback notes.
```

## Pre-flight scope

- If the repository contains `app/Hooks/actions.php` and `app/Http/Routes/api.php`, use the WPManageNinja baseline at `references/wordpress-plugin-structure-map.md`.
- Prioritise plugin-owned code: `app/`, `boot/`, `database/`, `includes/`, `Modules/`, root plugin bootstrap file.
- De-prioritise `vendor/`, `node_modules/`, `assets/`, `language/` unless a plugin-owned entry point reaches them.

## Execution model — Finder → Verifier → Feedback

Three passes in order:

1. **Finder pass** (Agent A).
2. **Verifier pass** (Agent B with independent stance).
3. **Feedback pass** — calibrate the next run.

If the runtime cannot spawn literal sub-agents, emulate the same phases sequentially and keep strict separation between candidate generation and verification.

### Finder pass rules (Agent A)

- Build an entry-point map before logging candidates:
  - Bootstrap and lifecycle: root plugin file + `boot/*.php`.
  - Hook wiring: `app/Hooks/actions.php`, `app/Hooks/filters.php`, `app/Hooks/Handlers/*`.
  - API surface: `app/Http/Routes/*.php`, `app/Http/Controllers/*`, `app/Http/Policies/*`.
  - Data layer: `database/migrations/*`, model/service calls in `app/Models/*` and `app/Services/*`.
  - Optional module boundaries: `app/Modules/*`.
- Generate candidates across these classes:
  - **Security** — authz, nonce, sanitization/escaping, SQLi, unsafe file handling.
  - **Functional** — broken hooks, callback signature mismatches, wrong action/nonce names, invalid route wiring.
  - **Data integrity** — migration errors, wrong option/meta keys, inconsistent state transitions.
  - **Compatibility** — PHP/WP version API assumptions, multisite/object-cache edge cases.
  - **Performance regressions** that produce user-visible failures (timeouts, N+1 chains).
- High-signal production checks:
  - Debug leftovers (`dd`, `die`, `var_dump`, `print_r`) in reachable runtime paths.
  - Cron/action-scheduler drift (duplicate scheduling, mismatched hook names, missing deactivation cleanup).
  - Route/policy drift (`withPolicy` group exists but policy method coverage does not match controller actions).
  - Public frontend nonce misuse — page-localised nonces on `wp_ajax_nopriv_` or public REST that still accept attacker-chosen IDs, paths, links, hashes, or target URLs.
  - Delegated-role helper drift — custom ACL helpers treating any plugin capability as equivalent to stronger permissions (full access, settings access, manager access, payment visibility).
  - Shortcode/rendered-HTML sinks — shortcode attributes, nested shortcode builders, rich-text settings, and JSON-returned messages that later reach `do_shortcode(...)`, string-built HTML, or frontend `.html(...)`.
  - Secret-read endpoints — "read-only" integration/config routes that can leak tokens, secrets, or credentials to lower-trust delegated users.
  - SSRF with exfil path — user-controlled outbound requests whose response body/status/headers are reflected into logs, notes, or API output.
  - Public email/link relay flows — guest endpoints sending attacker-controlled links or emails without proving ownership of the referenced saved object.
- For each candidate, include: `Area`, `Confidence`, `File:line`, `Entry point`, `Reproduction path`, `Evidence`, `Expected vs actual behaviour`, `Impact`, `Recommended fix`.

### Verifier pass rules (Agent B)

- Start from a sceptical stance and try to disprove each candidate.
- Re-trace call paths end-to-end (entry point → handler → service/db → response/UI effect).
- Validate real preconditions (capability checks, nonce names, route args, feature flags, plugin settings).
- For WPManageNinja-style plugins, verify these chains explicitly:
  - `app/Http/Routes/api.php` `withPolicy(...)` → matching `app/Http/Policies/*` permission checks.
  - Public AJAX endpoints (`wp_ajax_nopriv_*`) → nonce/token verification and least-privilege behaviour.
  - Scheduled jobs in `boot/app.php` and handlers → duplicate/unsynced hook behaviour under repeated init.
  - DB version constant → upgrader path → migration coverage for schema changes.
  - Custom ACL helper → requested route/controller policy → actual `current_user_can(...)` comparison for the requested permission.
  - Shortcode attribute/source field → sanitizer/save path → final render sink (`do_shortcode`, template echo, JS `.html(...)`, modal/button builder).
  - Public object-action endpoints → resource binding check for attachment/post/draft/path/submission ownership within the current form/session/user.
  - Integration/webhook readers and writers → whether secrets or remote-response content are disclosed back to delegated users.
- Reclassify each candidate as exactly one of: `Confirmed`, `Rejected`, `Needs manual verification`.
- Add a short `Verifier note` for every candidate including the exact break point or guard that determined the verdict.
- Don't mark `Confirmed` without at least one concrete reproduction path and one code-level evidence point.
- Don't confirm third-party file findings unless plugin-owned code invokes the vulnerable path.
- Don't treat a public nonce alone as sufficient mitigation when the endpoint touches a resource chosen by user input.
- For stored XSS candidates, verify the final rendered sink, not only the save-time sanitizer.

#### Severity calibration gate (verifier-owned)

- Default to `Low` with `Risk classification: Hardening` when a public/internal trigger is reachable but does not bypass authorization and does not expose or modify restricted data beyond intended scheduled/internal behaviour.
- Upgrade to `Medium` or higher only when at least one concrete impact is proven:
  - Unauthorised sensitive state change.
  - Unauthorised data disclosure.
  - Privilege escalation or permission bypass.
  - Reliable low-cost denial-of-service path with demonstrated operational impact.
- If impact is plausible but not proven, keep as `Needs manual verification` instead of inflating severity.
- Every confirmed finding must include explicit justification for both severity and why it is not one level higher.

### Feedback pass rules (calibration)

- Read existing `bug-discovery-report.md` before finalising.
- Update in-report feedback memory with:
  - New false-positive patterns rejected by verifier.
  - Evidence thresholds that would have prevented those false positives.
  - Recurring confirmed bug archetypes worth prioritising next run.
  - Severity misclassification corrections (`previous → final`) and the calibration rule learned.
- Record structure-specific calibrations (e.g. intentionally-public unsubscribe endpoints that are nonce-guarded).
- Add a `Feedback for next run` bullet inside every confirmed bug block.
- Apply this calibration once to tighten wording/severity before final output.

## Prioritisation rules

- Sort confirmed bugs by severity, then confidence.
- Prefer exploitable or user-impacting defects over style or micro-optimisation notes.
- Prefer `Bug` items over `Hardening` items when severity is tied.
- Deduplicate by root cause; keep the clearest reproduction path.

## Confirmed bug block schema

Each confirmed bug block must include: `Area`, `Risk classification`, `Confidence`, `File:line`, `Entry point`, `Reproduction path`, `Evidence`, `Expected vs actual behaviour`, `Impact`, `Severity rationale`, `Recommended fix`, `Verifier note`, `Feedback for next run`, `Task statement`.

## Final report contract

Populate `bug-discovery-report.md` in this order:

1. Executive summary (severity + verdict-count tables).
2. Table of contents (one link per confirmed bug).
3. Confirmed bugs by severity (only severity subsections that contain at least one confirmed bug).
4. Rejected candidates.
5. Needs manual verification.
6. Prioritised fix backlog.
7. Feedback-loop updates (what changed after verification).
