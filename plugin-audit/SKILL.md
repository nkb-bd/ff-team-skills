---
name: plugin-audit
description: Comprehensive WordPress plugin auditing workflow covering security, optimization, dead code, and end-to-end traceability with evidence-backed findings and a grouped remediation backlog. Use when users ask for deep plugin audits, severity-ranked security review, performance/dead-code analysis, or UI-to-database call-chain verification.
---

# Plugin Audit

Use this skill to run a deep WordPress plugin audit and produce one actionable backlog file.

## Required Output

- Write `plugin-audit.md` to the **output path** specified in the task (e.g. `Output path: /Volumes/Workspace/audits/<repo>/plugin-audit.md`). If no output path is specified, default to the repository root.
- Before writing: if a file already exists at that path, copy it to `plugin-audit-YYYY-MM-DD.md` in the same directory as an archive.
- Group detailed findings by severity (`Critical`, `High`, `Medium`, `Suggestion`), not by area.
- Base output on `references/plugin-audit-template.md`.
- Keep findings deduplicated and implementation-ready.
- In the executive summary, include a severity-count table with columns `Severity` and `Count`.
- Use rows for `CRITICAL`, `HIGH`, `MEDIUM`, and `SUGGESTION` in that table.
- Add a `Table of Contents` section that links to every detailed finding.
- Do not render grouped findings as tables; each finding must be a heading with field bullets.
- In each finding body, do not repeat finding key or `Severity` as bullet fields.

## Execution Model

Run exactly five audit workstreams (sub-agents):

1. Security.
2. Performance and optimization.
3. Dead code and duplication.
4. Traceability from UI entry points to handlers.
5. Traceability from handlers to services/database and back to response.

If the runtime cannot spawn literal sub-agents, emulate these as five separate passes and keep the same output boundaries.

## Auditor Mindset

Approach this audit as a paranoid senior security engineer reviewing code written by a junior developer who is unfamiliar with security and performance implications. Assume every input is malicious, every permission check is probably missing or wrong, every external call is a potential vulnerability, and every database query is potentially unbounded. Your job is to prove the code is safe — not assume it is.

For optimization: assume the site has 100,000+ users, 1M+ database records, and every hook fires on every page load. A query that looks harmless on a dev site with 10 records is a production outage waiting to happen.

## Scope Rules

- Analyze only code present in the repository.
- Do not invent files, functions, hooks, routes, or call paths.
- Favor real exploitable issues and measurable bottlenecks over style comments.
- If uncertain, mark the item as `Needs manual verification`.
- Cross-plugin model calls (e.g. `ExternalPlugin\Model::get()`) are IN scope for performance analysis — treat them as if you own the model and know it hits the database.

## Required Finding Schema

Every finding must include:

- `Area` (`Security` | `Optimization` | `Traceability`)
- `Confidence` (`High` | `Med` | `Low`)
- `File:line`
- `Short finding` (single-line label used in headings and table of contents)
- `Evidence` (short code quote or explicit call path)
- `Impact`
- `Recommended fix`
- `Task statement` (one clear implementation task)

## Finding Link Rules

- Make each detailed finding a markdown heading in this format:
  - `#### <SEVERITY>-NN: <Short finding>` (example: `#### HIGH-02: Missing nonce check on admin action`)
- Generate finding keys with sequential numbering inside each severity group (`CRITICAL-01`, `CRITICAL-02`, `HIGH-01`, etc.).
- Build the `Table of Contents` using markdown links to those finding headings.
- Ensure a 1:1 mapping between table-of-contents entries and detailed findings.
- Treat the heading as the finding key source and the parent severity section as the severity source.
- Required bullet fields inside each finding are: `Area`, `Confidence`, `File:line`, `Evidence`, `Impact`, `Recommended fix`, `Task statement`.
- For Critical and High findings, also include: `Verifier note` (one sentence confirming the exploitation path survived Pass 6 scrutiny).

## Security Checks

Check at minimum:

- Missing or incorrect authorization/capability checks (`current_user_can`).
- Missing or incorrect nonce checks (CSRF risk).
- Input validation/sanitization issues (`$_GET`, `$_POST`, `$_REQUEST`, AJAX, REST).
- Output escaping gaps leading to XSS.
- SQL injection risk (`$wpdb->prepare` misuse or absence).
- Privilege escalation/auth bypass paths.
- Unsafe AJAX and REST route permissions (including `permission_callback`).
- File upload abuse, path traversal, LFI/RFI.
- Insecure deserialization/object injection.
- SSRF/open redirect.
- Dangerous dynamic execution (`eval`, dynamic includes/requires, shell calls).
- Secret/token exposure and insecure option storage.

**Additional security patterns to catch:**
- OAuth/auth callbacks that don't validate state parameters or bind to a specific initiating session — allows CSRF-style account hijacking.
- Any `wp_remote_get/post` with user-controlled URLs (SSRF).
- Missing `sanitize_*` before storing to database even if `prepare()` is used (stored XSS after retrieval).
- HTML strings built from external plugin data (e.g. product titles, course names, user-provided fields) injected into `body_html`, `innerHTML`, or similar without escaping.
- REST endpoints or AJAX handlers where `permission_callback` returns `__return_true` or is missing.
- `wp_set_auth_cookie` or privilege changes without re-authentication.

**Payment and subscription security (treat as HIGH — never downgrade without a verified mitigation):**
- Any `wp_ajax_nopriv_` endpoint that can change payment status, mark a submission as paid/failed, or cancel a subscription must verify: (a) the caller owns the target submission/transaction, AND (b) the amount and currency match what was recorded at order creation. Missing either check = High finding, confirmed.
- Payment intent / token reuse: the payment intent, charge ID, or confirmation token must be bound to a specific submission at creation time and re-verified at confirmation time. A valid intent from a cheap payment must not be reusable to mark a different submission as paid. Look for `handlePaymentSuccess()`, `handlePaymentChargeError()`, and gateway-specific confirmation handlers — check whether they validate intent-to-submission binding before updating status.
- Subscription/transaction ownership on self-service AJAX routes: any endpoint reachable by a low-privilege role (Subscriber+) that accepts a `subscription_id`, `transaction_id`, or `submission_id` must assert the caller owns that resource. An auth helper that only checks subscription status or payment-method feature availability (e.g. `canCancelSubscription()`) is NOT an ownership check — treat it as a missing auth check and flag it.

**Conditional logic bugs (audit every branch — do not skip):**
- Always-true / always-false conditions: read every `if` / `else if` / `switch` for PHP truthy traps:
  - **String literal as condition**: `else if ('some_string')` is always `true` in PHP — the variable is never compared.
  - Assignment instead of comparison: `if ($x = someValue())` when `=` should be `==`/`===`.
  - Boolean operator precedence errors: `&&` binds tighter than `||`, so `A && B || C` is `(A && B) || C` — verify compound auth checks group operands as intended. A misplaced `&&`/`||` can flip which branch the authorization logic denies.
  - Non-empty constant expressions (non-empty array literal, object reference) used as a condition.
  - Even if the current codebase has a fix for a known instance, scan the rest of the file and related files for the same class of mistake.

**Superglobal sanitization:**
- `$_REQUEST`, `$_GET`, or `$_POST` assigned wholesale without a whitelist (e.g. `$data = $_REQUEST;`) and then passed to shortcode renderers, HTML output, or database functions. Every field used downstream must be extracted explicitly and run through `sanitize_text_field(wp_unslash(...))` or an equivalent typed sanitizer. Flag any wholesale assignment as at minimum Medium even when downstream re-assignment partially mitigates it, because the unsanitized superglobal may reach other callees before the re-assignment.

## Optimization Checks

Check at minimum:

- Unused code paths and unreachable functions/classes.
- Duplicate logic that should be consolidated.
- Hot-path inefficiencies (loops, repeated expensive calls, query patterns).
- Unnecessary allocations/work in request lifecycle.
- Overly complex/long functions that hurt maintainability or latency.

**Unbounded query patterns (HIGH priority — catch all of these):**
- Any `->get()`, `->all()`, `->find()`, `->select()` on a model representing potentially large data (subscribers, users, customers, orders, tickets, posts, comments, transactions, logs) without a `->where()`, `->limit()`, `->take()`, or scope constraint.
- Cross-plugin model queries loading full tables: e.g. `ExternalPlugin\Subscriber->get()`, `ExternalPlugin\Order::all()` — these load every row in the external plugin's table into memory.
- Any query inside a WordPress action/filter hook (`add_action`, `add_filter`) that fires on every page load with no caching.
- `->get()` chained after `->orderBy()` or `->select()` without a `->where()` — the ordering doesn't prevent a full table scan.
- Any query in a loop: `foreach` / `while` containing a model query = N+1 problem.
- `$wpdb->get_results()` or `$wpdb->query()` without a `LIMIT` clause on tables that grow with usage.
- Loading a full collection then filtering in PHP: `->get()->filter()` instead of filtering at the query level.

**Memory and request lifecycle:**
- Large arrays or collections built in memory from database results.
- Missing `wp_cache_get`/`wp_cache_set` on repeated identical queries within a request.
- Transients used for data that changes per-user (shared cache poisoning).

## Traceability Checks

For each UI trigger that reaches project code (buttons, links, forms, admin actions, AJAX, REST, blocks, shortcodes):

- Verify target handler exists and is wired correctly.
- Verify invocation signature and parameter names match.
- Verify argument types/shape expectations across each layer.
- Verify validation and transformation boundaries are correct.
- Verify downstream DB/service calls and returned payload shape.
- Report any broken chain explicitly with the exact break point.

## Verification Pass (Pass 6)

After completing the five audit workstreams, run a mandatory verification pass over every Critical and High finding before writing the final report.

For each Critical and High candidate:

1. **Re-trace the full exploitability path** — entry point → permission check → handler → data layer → effect. If any step breaks the path, the finding is not confirmed at that severity.
2. **Check for existing mitigations that the initial pass may have missed:**
   - Middleware or base controller auth checks not visible at the handler level.
   - WordPress core protections (e.g. `check_admin_referer`, nonce in a parent hook).
   - Capability checks in a parent class or trait.
   - Feature flags or settings that gate the vulnerable path.
   - Input already sanitized or escaped at an earlier layer.
3. **Verdict for each finding:**
   - **Confirmed** — full exploitation path traced end-to-end with direct code evidence. Keep at current severity.
   - **Downgrade** — path exists but a real mitigation reduces exploitability. Move to Medium or Suggestion with a note explaining what partial protection exists.
   - **Needs manual verification** — path is plausible but cannot be fully traced without runtime testing. Move to the verification section with the specific uncertainty noted.
   - **Rejected** — path is broken or finding is based on a misread. Remove from findings entirely.
4. **Skeptical stance** — actively try to disprove each finding. If you cannot find direct evidence that the protection is missing, do not confirm it. The burden of proof is on the finding, not the defense.
5. **Add a `Verifier note`** field to every Critical and High finding in the report stating the confirmation reasoning or why it survived scrutiny.

Medium and Suggestion findings do not require this pass — include them as-is from the workstream passes.

## Prioritization Rules

- Sort by severity first, then confidence.
- Deduplicate findings by root cause.
- Highlight quick wins and high-risk remediations first.

## Final Output Contract

Populate `plugin-audit.md` with these sections in order:

1. Executive summary (top risks + severity-count table).
2. Table of contents (one link per finding).
3. Findings by severity (non-tabular detail blocks per finding).
4. Prioritized implementation backlog (quick wins first).
5. Needs manual verification.

**Empty severity sections:**
- If a severity level has zero findings, OMIT that section entirely from the report
- Do NOT include "### Critical" followed by "None." or any placeholder text
- Only include severity headings that have actual findings under them
- The severity-count table in executive summary should still show all levels (including 0 counts) for transparency
