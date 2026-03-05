---
name: debugger
description: Evidence-first WordPress plugin bug discovery workflow with a finder-verifier feedback loop that reduces false positives over time. Use when users ask to find bugs, triage regressions, or run a two-agent bug sweep with independent verification.
---

# Debugger

Use this skill to find real bugs in a WordPress plugin and separate broad candidate discovery from independent verification.

## Required Outputs

- Create or update `debugger-report.md` at the repository root using `references/debugger-report-template.md`.
- Keep confirmed findings grouped by severity (`Critical`, `High`, `Medium`, `Low`).
- Keep feedback inside the same `debugger-report.md` file (no separate feedback file).
- Do not silently drop weak findings; place them in `Rejected candidates` or `Needs manual verification`.
- For each confirmed finding, include both `Risk classification` (`Bug` or `Hardening`) and `Severity rationale`.

## Output Hygiene

- Produce a final report, not a template dump.
- Never include template helper/instruction text in the final output.
- Specifically remove lines like `Use this field set for each confirmed bug:` and any placeholder-only bullets/headings.
- Do not keep example finding titles or empty placeholder entries in the table of contents.
- Omit empty severity sections under `Confirmed Bugs by Severity`.
- Never print placeholder text such as `_No confirmed critical findings in this pass._`.

## Quick Run Prompt

- Use this exact prompt to run the skill:
  - `Use $debugger on this plugin. Run Finder -> Verifier -> Feedback, keep only verifier-confirmed issues, and generate debugger-report.md with per-bug feedback notes.`

## Preflight Scope Setup

- If the repository contains `app/Hooks/actions.php` and `app/Http/Routes/api.php`, use the WPManageNinja baseline in `references/wpmanageninja-structure-map.md`.
- Prioritize plugin-owned code: `app/`, `boot/`, `database/`, `includes/`, `Modules/`, root plugin bootstrap file.
- De-prioritize `vendor/`, `node_modules/`, `assets/`, and `language/` unless a plugin-owned entry point reaches them.

## Execution Model (Finder -> Verifier -> Feedback)

Run these three passes in order:

1. Finder pass (`Agent A`).
2. Verifier pass (`Agent B` with independent stance).
3. Feedback pass (calibrate the next run).

If the runtime cannot spawn literal sub-agents, emulate the same phases sequentially and keep strict separation between candidate generation and verification.

## Finder Pass Rules (Agent A)

- Build an entry-point map before logging candidates:
  - Bootstrap and lifecycle: root plugin file + `boot/*.php`.
  - Hook wiring: `app/Hooks/actions.php`, `app/Hooks/filters.php`, `app/Hooks/Handlers/*`.
  - API surface: `app/Http/Routes/*.php`, `app/Http/Controllers/*`, `app/Http/Policies/*`.
  - Data layer: `database/FluentCRMDBMigrator.php`, `database/migrations/*`, model/service calls in `app/Models/*` and `app/Services/*`.
  - Optional module boundaries: `app/Modules/*`.
- Generate candidates across these bug classes:
  - Security issues (authz, nonce, sanitization/escaping, SQLi, unsafe file handling).
  - Functional defects (broken hooks, callback signature mismatch, wrong action/nonce names, invalid route wiring).
  - Data integrity bugs (migration errors, wrong option/meta keys, inconsistent state transitions).
  - Compatibility bugs (PHP/WP version API assumptions, multisite/object cache edge cases).
  - Performance regressions that can produce user-visible failures (timeouts, N+1 query chains).
- Include high-signal production checks:
  - Debug leftovers (`dd`, `die`, `var_dump`, `print_r`) in reachable runtime paths.
  - Cron/action scheduler drift (duplicate scheduling, mismatched hook names, missing deactivation cleanup).
  - Route/policy drift (`withPolicy` group exists but policy method coverage does not match controller actions).
- For each candidate include:
  - `Area` (`Security` | `Functional` | `Data Integrity` | `Compatibility` | `Performance`)
  - `Confidence` (`High` | `Med` | `Low`)
  - `File:line`
  - `Entry point`
  - `Reproduction path`
  - `Evidence`
  - `Expected vs actual behavior`
  - `Impact`
  - `Recommended fix`

## Verifier Pass Rules (Agent B)

- Start from a skeptical stance and try to disprove each candidate.
- Re-trace call paths end-to-end (entry point -> handler -> service/db -> response/UI effect).
- Validate real preconditions (capability checks, nonce names, route args, feature flags, plugin settings).
- For WPManageNinja-style plugins, verify these chains explicitly:
  - `app/Http/Routes/api.php` `withPolicy(...)` -> matching `app/Http/Policies/*` permission checks.
  - Public AJAX endpoints (`wp_ajax_nopriv_*`) -> nonce/token verification and least-privilege behavior.
  - Scheduled jobs in `boot/app.php` and handlers -> duplicate/unsynced hook behavior under repeated init.
  - DB version constant -> upgrader path -> migration coverage for schema changes.
- Reclassify each candidate as exactly one of:
  - `Confirmed`
  - `Rejected`
  - `Needs manual verification`
- Add a short `Verifier note` for every candidate, including the exact break point or guard that determined the verdict.
- Do not mark `Confirmed` without at least one concrete reproduction path and one code-level evidence point.
- Do not confirm third-party file findings unless plugin-owned code invokes the vulnerable path.

### Severity Calibration Gate (Verifier-Owned)

- Default to `Low` with `Risk classification: Hardening` when a public/internal trigger is reachable but does not bypass authorization and does not expose or modify restricted data beyond intended scheduled/internal behavior.
- Upgrade to `Medium` or higher only when at least one concrete impact is proven:
  - Unauthorized sensitive state change.
  - Unauthorized data disclosure.
  - Privilege escalation or permission bypass.
  - Reliable low-cost denial-of-service path with demonstrated operational impact.
- If impact is plausible but not proven, keep as `Needs manual verification` instead of inflating severity.
- Every confirmed finding must include explicit justification for both severity and why it is not one level higher.

## Feedback Pass Rules (Calibration)

- Read existing `debugger-report.md` before finalizing.
- Update in-report feedback memory with:
  - New false-positive patterns rejected by verifier.
  - Evidence thresholds that would have prevented those false positives.
  - Recurring confirmed bug archetypes worth prioritizing next run.
  - Severity misclassification corrections (`previous -> final`) and the calibration rule learned.
- Record structure-specific calibrations (for example: intentionally public unsubscribe endpoints that are nonce-guarded).
- Add a `Feedback for next run` bullet inside every confirmed bug block.
- Apply this calibration once to tighten wording/severity before final output.

## Prioritization Rules

- Sort confirmed bugs by severity, then confidence.
- Prefer exploitable or user-impacting defects over style or micro-optimization notes.
- Prefer `Bug` items over `Hardening` items when severity is tied.
- Deduplicate by root cause; keep the clearest reproduction path.

## Confirmed Bug Block Schema

Each confirmed bug block must include:

- `Area`
- `Risk classification` (`Bug` | `Hardening`)
- `Confidence`
- `File:line`
- `Entry point`
- `Reproduction path`
- `Evidence`
- `Expected vs actual behavior`
- `Impact`
- `Severity rationale`
- `Recommended fix`
- `Verifier note`
- `Feedback for next run`
- `Task statement`

## Final Report Contract

Populate `debugger-report.md` in this order:

1. Executive summary (including severity and verdict-count tables).
2. Table of contents (one link per confirmed bug).
3. Confirmed bugs by severity (include only severity subsections that have at least one confirmed bug).
4. Rejected candidates.
5. Needs manual verification.
6. Prioritized fix backlog.
7. Feedback loop updates (what changed after verification).
