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

## Report Header Format (mandatory)

The first two lines of every report must be:

```
# Plugin Audit Report — {PluginName}
**Branch:** {branch} | **Date:** {YYYY-MM-DD} | **Auditor:** {model} (5-workstream + Pass 6 verification)
```

Followed by `---` then the report body.

**Why this matters for the pr-analytics dashboard:**
- The `# h1` line is **stripped** by the dashboard renderer — it is never shown in the report body. The page title in the UI comes from the repo override in `serve_dashboard.ts`, not from the markdown.
- The `**Branch:** ...` frontmatter line is **hidden for logged-out users** and **visible for logged-in users** only. Write it clearly as a single paragraph line so the renderer can detect and conditionally hide it.
- Do not skip either line — they are required metadata even though the h1 is not rendered.

## Execution Model

Run exactly five audit workstreams (sub-agents):

1. Security.
2. Performance and optimization.
3. Dead code and duplication.
4. Traceability from UI entry points to handlers.
5. Traceability from handlers to services/database and back to response.

If the runtime cannot spawn literal sub-agents, emulate these as five separate passes and keep the same output boundaries.

## code-review-graph context, when available

If the repo has `code-review-graph` wired (`.mcp.json` mentions `code-review-graph`, `.code-review-graph/` exists, or MCP tools such as `query_graph`, `semantic_search_nodes`, `get_impact_radius`, `detect_changes`, or `get_architecture_overview` are callable), use it before grep for structural audit questions:

| Audit need | Prefer graph tool | Cross-check |
|---|---|---|
| High-level module map | `get_architecture_overview`, `list_communities` | repo tree and direct file reads |
| UI-to-handler trace | `query_graph callers_of` / `importers_of` | route files, enqueue files, targeted `rg` |
| Handler-to-service/database trace | `get_impact_radius`, `query_graph callers_of` | direct call-path reads and model/query files |
| Dead code candidates | graph dependents/callers queries | targeted `rg` before reporting |
| Test coverage around risky paths | graph tests coverage queries, when available | test tree and test command output |

Graph output should guide workstream targeting and traceability evidence, but it is not sufficient evidence by itself. Findings still need live source evidence (`File:line`, call path, or short code quote). Treat graph data as potentially stale; if it conflicts with live source, trust direct reads and mention the mismatch in audit notes.

If graph is not available, continue with repo tree, `rg`, `find`, and direct file reads.

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
- **Public nonce is not authorization**: any `wp_ajax_nopriv_` or public REST/AJAX endpoint that relies on a page-localized/frontend nonce must also bind the action to the exact resource being touched (attachment, post, draft, submission, file path, payment, webhook target, etc.). A public nonce plus attacker-chosen `attachment_id`, `post_id`, `path`, `link`, `hash`, or similar identifier is not sufficient authorization.
- **Delegated capability boundary drift**: when a plugin has custom ACL helpers or plugin-specific roles/capabilities, verify that "user has some plugin capability" does not incorrectly satisfy stronger checks such as settings-manager, full-access, payments-view, or role-manager routes. Compare helper results against `current_user_can(<requested capability>)` at the exact route/action being protected.
- **Shortcode and rendered-HTML sink rule**: audit every shortcode attribute, dynamic shortcode wrapper, and saved rich-text/message field that can become frontend HTML after plugin rendering. Treat encoded payload forms, nested shortcode construction, `do_shortcode(...)`, and client-side `.html(...)` insertion as first-class XSS sinks, especially when the plugin stores raw shortcode attributes and expands them later.
- **Secret-read surfaces**: treat integration/config read endpoints as sensitive even when they are "read-only". If a lower-trust delegated manager can retrieve API keys, private app tokens, refresh tokens, webhook secrets, or OAuth credentials through a REST/AJAX settings endpoint, report it as a confirmed disclosure issue.
- **SSRF with response reflection/logging**: if user-controlled URLs reach `wp_remote_*`, trace whether response body, headers, or status are copied into logs, action notes, admin notices, webhooks history, or API responses. This turns a blind SSRF into an exfiltration path and should be called out explicitly.
- **Public mail/link relay flows**: unauthenticated or low-privilege endpoints that send emails/messages must prove ownership of the saved object they reference and must rebuild sensitive URLs from trusted server-side state. If caller-controlled `to_email`, `link`, or resume/reset URL values are sent directly, treat it as a real abuse path.
- **Resource ownership on file/post/delete/update helpers**: for delete/update/populate endpoints, do not stop at nonce verification. Verify the target attachment, post, entry, file path, or draft belongs to the current form/session/user and is inside the intended Fluent Forms-owned resource set.

**Payment and subscription security (treat as HIGH — never downgrade without a verified mitigation):**
- Any `wp_ajax_nopriv_` endpoint that can change payment status, mark a submission as paid/failed, or cancel a subscription must verify: (a) the caller owns the target submission/transaction, AND (b) the amount and currency match what was recorded at order creation. Missing either check = High finding, confirmed.
- Payment intent / token reuse: the payment intent, charge ID, or confirmation token must be bound to a specific submission at creation time and re-verified at confirmation time. A valid intent from a cheap payment must not be reusable to mark a different submission as paid. Look for `handlePaymentSuccess()`, `handlePaymentChargeError()`, and gateway-specific confirmation handlers — check whether they validate intent-to-submission binding before updating status.
- Subscription/transaction ownership on self-service AJAX routes: any endpoint reachable by a low-privilege role (Subscriber+) that accepts a `subscription_id`, `transaction_id`, or `submission_id` must assert the caller owns that resource. An auth helper that only checks subscription status or payment-method feature availability (e.g. `canCancelSubscription()`) is NOT an ownership check — treat it as a missing auth check and flag it.
- **Gateway fan-out rule**: when you find one `wp_ajax_nopriv_` payment confirmation handler missing ownership or amount validation, **do not stop there**. Enumerate every handler registered via `wp_ajax_nopriv_`, `addPublicAjaxAction`, or equivalent across ALL payment gateway integrations in the plugin (Stripe, RazorPay, Paystack, Paddle, Authorize.Net, Mollie, etc.). For each one, independently trace whether its validation helper (e.g. `validatePaymentConfirmation()`, `verifyPaymentNonce()`) actually verifies: (a) caller owns the target submission, AND (b) payment amount/currency matches. The presence of a validation helper in one gateway is NOT evidence that other gateways are safe — trace each one to its implementation. Flag every gateway handler where this cannot be confirmed as a separate finding.

**Conditional logic bugs (audit every branch — do not skip):**
- Always-true / always-false conditions: read every `if` / `else if` / `switch` for PHP truthy traps:
  - **String literal as condition**: `else if ('some_string')` is always `true` in PHP — the variable is never compared.
  - Assignment instead of comparison: `if ($x = someValue())` when `=` should be `==`/`===`.
  - Boolean operator precedence errors: `&&` binds tighter than `||`, so `A && B || C` is `(A && B) || C` — verify compound auth checks group operands as intended. A misplaced `&&`/`||` can flip which branch the authorization logic denies.
  - Non-empty constant expressions (non-empty array literal, object reference) used as a condition.
  - Even if the current codebase has a fix for a known instance, scan the rest of the file and related files for the same class of mistake.

**Superglobal sanitization:**
- `$_REQUEST`, `$_GET`, or `$_POST` assigned wholesale without a whitelist (e.g. `$data = $_REQUEST;`) and then passed to shortcode renderers, HTML output, or database functions. Every field used downstream must be extracted explicitly and run through `sanitize_text_field(wp_unslash(...))` or an equivalent typed sanitizer. Flag any wholesale assignment as at minimum Medium even when downstream re-assignment partially mitigates it, because the unsanitized superglobal may reach other callees before the re-assignment.

**WordPress/Fluent Forms style follow-up sweeps (mandatory when applicable):**
- Run a dedicated shortcode/rendered-HTML pass after the initial security sweep. Re-check shortcode attributes, saved confirmation/approval/coupon/button messages, modal/button labels, and rich-text settings that later reach `do_shortcode`, `printf`, string-concatenated HTML, or frontend `.html(...)` insertion.
- Run a delegated-manager pass: enumerate custom capabilities, ACL helpers, route policies, and manager/settings endpoints, then verify lower delegated roles cannot satisfy stronger permissions through helper short-circuits.
- Run a public-endpoint ownership pass: enumerate all `wp_ajax_nopriv_`, public REST routes, and frontend-localized nonces, then test whether attacker-chosen object IDs/paths can touch resources outside the current form/session/user.
- Run a secrets-and-integrations pass: enumerate integration settings endpoints, OAuth/token storage readers, webhook/feed config readers, and confirm lower-trust users cannot read global credentials.

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

**SQL correctness traps (catch every occurrence):**
- `apply_filters()` callbacks that build raw SQL via `whereRaw` / `$wpdb->prepare` — verify the operator and column come from a server-side whitelist, never from `$_REQUEST`. Even if the value is parameterized, an attacker-controlled operator string is enough to break out.
- `CAST(col AS X)` where X is not a valid MySQL cast type. Valid types: `BINARY, CHAR, DATE, DATETIME, DECIMAL, JSON, NCHAR, SIGNED, TIME, UNSIGNED`. **`DOUBLE` and `FLOAT` are NOT valid** — they cause silent SQL errors that fall back to unfiltered results in the calling code.
- A REGEXP/CAST guard (`col REGEXP '^[0-9]+$' AND CAST(col AS DECIMAL) = ?`) applied to columns that are already typed numeric in the schema. The guard is only needed for TEXT columns that may hold non-numeric values; on typed columns it forces a full table scan and defeats the index.
- `OR` between filter groups not wrapped in an outer `where(function($q) { ... })`: AND binds tighter than OR, so the OR escapes outer scope conditions like `form_id = ?` and matches rows from other forms.
- `$query->distinct()` always applied even when no joins exist — DISTINCT forces a sort/hash pass with no rows to deduplicate.

**Stateful service object hazards:**
- A class instantiated once via `init()` (registered as a hook callback / singleton-by-convention) holding instance properties that are appended to during request handling — if the same hook fires twice in one request, the second call inherits stale state from the first. Look for `$this->someArray[] = ...` inside hook callbacks; require a reset at the top of the callback.
- Memoization caches keyed only by request lifecycle (instance properties): correct as long as the class is instantiated per request, but fragile if the bootstrap pattern changes.

**PHP 8+ type-fatal traps:**
- `array_map`, `array_filter`, `array_walk`, `count`, `foreach` over a value that isn't guaranteed to be an array. PHP 7.x warned, PHP 8+ throws `TypeError`. Look especially at code paths that take user-submitted JSON / REST payloads where a field could be `null` or a scalar.

## Traceability Checks

For each UI trigger that reaches project code (buttons, links, forms, admin actions, AJAX, REST, blocks, shortcodes):

- Verify target handler exists and is wired correctly.
- Verify invocation signature and parameter names match.
- Verify argument types/shape expectations across each layer.
- Verify validation and transformation boundaries are correct.
- Verify downstream DB/service calls and returned payload shape.
- Report any broken chain explicitly with the exact break point.

For shared helpers and editor-state infrastructure uncovered during traceability:

- treat helper functions as contract boundaries, not merely implementation detail
- check how behavior changes when a payload omits keys or returns only a partial managed response
- inspect backward compatibility with existing saved records and legacy rows, especially when identity moves from positional/index-based handling to ID-based handling
- call out hidden assumptions explicitly, such as “all rows have IDs” or “override keys are always meaningful”

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
   - Resource binding or ownership checks that tie the action to the exact form/session/user/object.
3. **Verdict for each finding:**
   - **Confirmed** — full exploitation path traced end-to-end with direct code evidence. Keep at current severity.
   - **Downgrade** — path exists but a real mitigation reduces exploitability. Move to Medium or Suggestion with a note explaining what partial protection exists.
   - **Needs manual verification** — path is plausible but cannot be fully traced without runtime testing. Move to the verification section with the specific uncertainty noted.
   - **Rejected** — path is broken or finding is based on a misread. Remove from findings entirely.
4. **Skeptical stance** — actively try to disprove each finding. If you cannot find direct evidence that the protection is missing, do not confirm it. The burden of proof is on the finding, not the defense.
5. **Add a `Verifier note`** field to every Critical and High finding in the report stating the confirmation reasoning or why it survived scrutiny.

When a candidate finding involves shared helper behavior or state merge semantics, the verifier pass must also try to disprove it by checking:

- omitted response keys
- `undefined` vs `null` vs empty-string handling
- legacy saved data without modern identifiers
- stale async responses after the helper change

When a candidate finding involves a public endpoint, shortcode attribute, delegated-manager boundary, or integration reader, the verifier pass must also try to disprove it by checking:

- whether the nonce is merely anti-CSRF or is actually bound to a specific resource
- whether the target object is constrained to the current form/session/user/resource set
- whether a lower delegated capability is accidentally treated as full access by a helper short-circuit
- whether rendered HTML passes through a real allowlist sanitizer at the final sink, not only at save time
- whether secrets/tokens are redacted before being returned or logged
- whether SSRF responses are reflected into logs, notes, or API output

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
