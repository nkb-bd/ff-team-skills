---
name: plugin-audit
description: Comprehensive WordPress plugin auditing workflow covering security, optimization, dead code, and end-to-end traceability with evidence-backed findings and a grouped remediation backlog. Use when users ask for deep plugin audits, severity-ranked security review, performance/dead-code analysis, or UI-to-database call-chain verification.
---

# Plugin Audit

Use this skill to run a deep WordPress plugin audit and produce one actionable backlog file.

## Required Output

- Create `plugin-audit.md` at the repository root.
- Group findings by area, then by severity.
- Base output on `references/plugin-audit-template.md`.
- Keep findings deduplicated and implementation-ready.
- Add an `Executive Findings Table` immediately after the executive summary.
- Include one summary-table row per finding with a link to that finding's detailed entry.

## Execution Model

Run exactly five audit workstreams (sub-agents):

1. Security.
2. Performance and optimization.
3. Dead code and duplication.
4. Traceability from UI entry points to handlers.
5. Traceability from handlers to services/database and back to response.

If the runtime cannot spawn literal sub-agents, emulate these as five separate passes and keep the same output boundaries.

## Scope Rules

- Analyze only code present in the repository.
- Do not invent files, functions, hooks, routes, or call paths.
- Favor real exploitable issues and measurable bottlenecks over style comments.
- If uncertain, mark the item as `Needs manual verification`.

## Required Finding Schema

Every finding must include:

- `ID`
- `Area` (`Security` | `Optimization` | `Traceability`)
- `Severity` (`Critical` | `High` | `Medium` | `Low`)
- `Confidence` (`High` | `Med` | `Low`)
- `File:line`
- `Short finding` (single-line label for summary table)
- `Evidence` (short code quote or explicit call path)
- `Impact`
- `Recommended fix`
- `Task statement` (one clear implementation task)

## Finding Link Rules

- Make each detailed finding linkable with a stable anchor in grouped findings:
  - Use anchor format `finding-<normalized-id>`, where normalized ID is lowercase and non-alphanumeric characters replaced with `-`.
  - Example: `SEC-001` becomes `finding-sec-001`.
- In the executive findings table, link each ID (or a dedicated details column) to its anchor using markdown fragments.
- Ensure a 1:1 mapping between summary-table rows and detailed findings.

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

## Optimization Checks

Check at minimum:

- Unused code paths and unreachable functions/classes.
- Duplicate logic that should be consolidated.
- Hot-path inefficiencies (loops, repeated expensive calls, query patterns).
- Unnecessary allocations/work in request lifecycle.
- Overly complex/long functions that hurt maintainability or latency.

## Traceability Checks

For each UI trigger that reaches project code (buttons, links, forms, admin actions, AJAX, REST, blocks, shortcodes):

- Verify target handler exists and is wired correctly.
- Verify invocation signature and parameter names match.
- Verify argument types/shape expectations across each layer.
- Verify validation and transformation boundaries are correct.
- Verify downstream DB/service calls and returned payload shape.
- Report any broken chain explicitly with the exact break point.

## Prioritization Rules

- Sort by severity first, then confidence.
- Deduplicate findings by root cause.
- Highlight quick wins and high-risk remediations first.

## Final Output Contract

Populate `plugin-audit.md` with these sections in order:

1. Executive summary (top risks).
2. Executive findings table (one row per finding, each linking to its detailed finding anchor).
3. Grouped findings by area and severity (with stable anchors per finding).
4. Prioritized implementation backlog (quick wins first).
5. Needs manual verification.
