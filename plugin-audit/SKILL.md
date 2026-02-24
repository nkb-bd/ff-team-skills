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
- `Evidence` (short code quote or explicit call path)
- `Impact`
- `Recommended fix`
- `Task statement` (one clear implementation task)

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
2. Grouped findings by area and severity.
3. Prioritized implementation backlog (quick wins first).
4. Needs manual verification.
