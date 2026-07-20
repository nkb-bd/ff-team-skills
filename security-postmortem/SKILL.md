---
name: security-postmortem
description: >
  Turn a security fix (or a vulnerability report) into a durable guardrail. Traces the full
  vulnerability chain source→sink, root-causes WHY existing scans/skills missed it, then hardens:
  updates the associated review skill's checklist AND/OR writes a prevention script (CI guard or
  lint rule) that is proven to fail on the vulnerable pattern and pass on the fix. Produces a
  short post-mortem report. Complements `bug-fix` (which fixes) and `pre-merge-review` (which
  reviews) — this skill closes the loop so the same CLASS never ships again.
when_to_use: >
  After a security patch lands or a vuln report (Patchstack/CVE/researcher PoC) arrives, when the
  user asks "why did we miss this", "make sure this can't happen again", "add a guardrail",
  "harden against this", "post-mortem this CVE", "trace this security issue", or "prevent this
  class of bug". Also when reviewing a just-merged SECURITY: commit and asking what systemic gap
  let it through.
context: fork
allowed-tools: Read Edit Write Bash(git *) Bash(grep *) Bash(rg *) Bash(find *) Bash(npm *) Bash(bash *) Bash(chmod *)
effort: high
---

# Security Post-Mortem → Guardrail

One vuln is a bug. The same vuln twice is a process failure. This skill converts a single security
fix into a durable defense so the **class** cannot recur.

Input is one of:
- a merged `SECURITY:`/`FIX:` commit or PR,
- a vuln report (Patchstack ID, CVE, researcher PoC with reproduction steps),
- a suspected-but-unpatched issue the user describes.

Output is always a **written report file** (resolved to the project's existing post-mortem location — see Phase 6) containing three things: a **traced chain**, a **root-cause of the miss**, and a **guardrail** (skill update and/or script) that is negative-tested.

Do not skip phases. The value is in the honesty of Phase 3 and the proof in Phase 5.

> **MANDATORY — sibling-plugin parity.** The Fluent products ship as paired plugins (FluentForm free ↔ FluentForm **Pro**; likewise FluentCRM, FluentCommunity, FluentBooking). A fix or guard applied to ONE plugin is not done until you have grepped the sibling(s) for the same sink and either applied the same fix or recorded (in the report) that the sibling is clean. **Whenever a check runs on `fluentform` OR `fluentformpro`, run it on both.** This is not optional and not "phase 4 only" — it applies to tracing (a source in Pro can reach a sink in free), to the fix, and to the guard's coverage. The recurring failure mode this skill exists to kill is exactly *"free got hardened, Pro never followed"* (e.g. `Helper::safeUnserialize` shipped in free 2025-08 but Pro kept raw `maybe_unserialize` sinks). See Phase 4C.

---

## Phase 0 — Frame the artifact

Identify what you're analysing and pull the ground truth. Never work from the report's prose alone.

- If a commit/PR: `git show <sha> --stat` then the full diff of each touched file.
- If a report only: locate the vulnerable code the report describes; read it as it exists on the default branch.
- Record: severity/CVSS, the actors (attacker privilege level, victim role), and the one-sentence claim of what executes.

Write these down before tracing — they anchor the rest.

## Phase 1 — Trace the chain (source → sink)

A real vuln is almost never one line. Map every link:

1. **Source** — where attacker-controlled data enters (URL/hash param, POST body, header, stored value, a param from a *different repo*).
2. **Carriers** — every function/helper the tainted value flows through unchanged. Note repo boundaries — the source may live in a Pro plugin while the vulnerable helper lives in Free.
3. **Sink** — where the damage happens (eval/globalEval, echo without escaping, SQL, `include`, a WP-core endpoint reached via traversal, an unencoded path segment, a redirect).
4. **Trust inversion** — what made the malicious request *look* legitimate (a valid nonce, a real endpoint, an authenticated session). This is usually why generic auth checks passed.

Produce a numbered chain: `source → carrier → carrier → sink`, citing `file:line` for each link. Identify which link the fix cut (ideally the fix cuts more than one — defense in depth).

## Phase 2 — Reproduce the reasoning (confirm the fix actually cuts a link)

You don't need to run the exploit. You DO need to confirm, from the code, that:
- the fix removes at least one link in the Phase-1 chain, and
- it is **inert for legitimate traffic** (enumerate real callers/inputs and show the fix is a no-op for them — the way `encodeURIComponent` is identity for integer IDs).

If the fix breaks legitimate flows, that's a finding — surface it before hardening.

## Phase 3 — Root-cause the miss (the important part; be honest)

Ask, concretely, why each existing layer failed to catch this. Walk the actual layers this repo has:
- **Per-file linters / grep scanners** — did every individual line look innocent? (Usually yes — the vuln is in the *interaction*.)
- **Review skills** (`pre-merge-review`, `plugin-audit`) — do their checklists cover this pattern? Which detector *should* have owned it?
- **Taint/scope boundaries** — is the sink in code we don't scan (WP core, another repo)? Does source and sink live in different diffs so single-branch review never sees both ends?
- **Heuristic blind spots** — did present-but-insufficient auth (a valid nonce) make a "missing auth" heuristic pass? Is the whole chain in frontend JS where the PHP-centric scanners don't point?

Write 3–6 numbered reasons, each naming the specific tool/skill that should have caught it and why it didn't. Vague reasons ("we need to be more careful") are failures — name the mechanism.

## Phase 4 — Design the guardrail(s)

For each root cause, pick the cheapest layer that would have caught it. Two kinds:

**A. Skill/checklist update** — for semantic, cross-file, cross-repo classes a linter can't see.
- Find the associated skill: usually `pre-merge-review` (a detector or a `references/patterns-*.md` file) or `plugin-audit`.
- Add checklist items phrased as an imperative a reviewer can execute, each ending in the concrete failure mode. Include the source→sink trace note when the two ends live in different diffs/repos.

**B. Prevention script** — for a mechanical pattern a machine can detect.
- Prefer a **zero-dependency guard** the repo can run today (this repo has NO ESLint — check first with `node -e` on package.json). A `bash + grep` guard wired as an npm script is often the only thing that will actually run in CI.
- Provide a proper **ESLint/AST rule** as the upgrade path only when the repo has (or is adopting) a lint pipeline.
- Each rule must pin a *specific* regression, not a broad style preference — it should map 1:1 to a link in the chain.

**C. Sibling-plugin parity (mandatory — do this before declaring the fix done).**
- Grep the sibling plugin(s) for the SAME sink/pattern: e.g. `grep -rn "maybe_unserialize\|unserialize(" ../fluentform*/src ../fluentform*/app`. Enumerate every hit and classify each as user-reachable or trusted-internal.
- If the vulnerable pattern exists in the sibling, apply the same fix there too. Report each sibling as *patched* or *confirmed-clean* — never silently one-sided.
- **Do not fix a Pro sink by calling a helper that only exists in a newer free.** Cross-plugin method calls fatal under version skew: Pro admits any free ≥ `FLUENTFORM_MINIMUM_CORE_VERSION` (currently `6.0.0`), which may predate the helper. Give the Pro plugin its OWN copy of the safe helper (e.g. in `PaymentHelper`/a Pro helper), or `method_exists`-guard only as a last resort. Note the min-core floor vs. the helper's introduction release in the report.
- Extend the CI guard to scan BOTH `src` trees (free `app/` + Pro `src/`), so reintroducing the pattern in either plugin fails.

Match house style: read `~/.claude/CLAUDE.md` and the repo `CLAUDE.md` (comment policy: default zero comments; the guard's *why* goes in a one-line header referencing the CVE/Patchstack ID, not inline narration).

## Phase 5 — Prove it (negative test — mandatory)

A guardrail that isn't proven to fire is decoration.
- **Positive:** run it against the fixed tree → must pass.
- **Negative:** transiently revert the fix (temp copy, `sed`, or stash), run the guard → must fail with a clear message and non-zero exit. **Restore the file** and confirm `git status`/`git diff` is clean.
- For a checklist update, sanity-check that the item, applied to the original vulnerable diff, would have flagged it.

Never leave the working tree dirty from a negative test. Verify with `git diff <file>` returning empty.

**Parity coverage:** run the negative test against BOTH plugins' sinks — revert the fix in each patched sibling in turn and confirm the guard fires for each. A guard that only scans one plugin's tree is a half-guard.

## Phase 6 — Report & wire in

**Always write a report file** — the post-mortem is an artifact, not just chat output.

### 6a. Resolve the report location (check for an existing folder FIRST)

Before writing, look for where post-mortems already live, in this order — reuse the first that exists:

```bash
# 1. the team's canonical post-mortem home (Fluent product line)
ls -d /Volumes/Projects/Tools/work-flow/postmortems 2>/dev/null
# 2. an in-repo post-mortem/security-report folder
ls -d .review/security docs/security security/postmortems .security/postmortems 2>/dev/null
# 3. any existing report or standing audit anywhere (match the sibling's dir + naming; cross-link, don't merge)
find . -maxdepth 4 \( -iname "*postmortem*" -o -iname "*post-mortem*" -o -iname "*security-report*" -o -iname "*audit*.md" \) \
  -not -path "*/node_modules/*" -not -path "*/vendor/*" 2>/dev/null
```

- **Primary home** → `/Volumes/Projects/Tools/work-flow/postmortems/` — the established location for Fluent Forms / FluentCRM / FluentCommunity post-mortems. Match the existing reports' format and naming.
- **Else, if a repo-local post-mortem folder or sibling report exists** → write there, matching its convention. Never start a second parallel location.
- **Else, if tracked in an openspec change** → `openspec/changes/<change-slug>/POSTMORTEM.md`.
- **Filename:** `YYYY-MM-DD-<vuln-slug>.md`, date from the report's disclosure/confirmation date (e.g. `2026-06-30-oembed-jsonp-xss.md`) — this matches the existing `2026-06-08-bulk-delete-idor.md`. Never fabricate a CVE; if there's only a Patchstack/WPScan ref, cite it in the body.
- **Format:** mirror the newest sibling report in the folder — metadata block (Severity/Product/Reporter/Class/Owner/Fix/Status/Date) · blameless note · **What happened (timeline)** · **Customer impact** · **Root cause** (Technical + Process) · **Mitigation** (table + code) · **§15.1 mandatory answers** · **Action items (owned, dated)** · **Lessons**. Cross-link any related prior post-mortem in the same folder.
- **A standing broad audit** (e.g. `audit_todo.md`) is a DIFFERENT artifact — cross-reference it, don't write into it.
- **Re-run / update:** if the target file already exists, UPDATE it in place (append a `## Follow-up <date>` section) rather than duplicating — same idempotence rule as `pre-merge-review` reports.

Announce the resolved path before writing.

### 6b. Write the report (template)

```markdown
# Security Post-Mortem — <short title>

- **ID:** <CVE / Patchstack ref>  · **Severity:** <CVSS + vector>
- **Fix:** <commit sha / PR> · **Reported:** <date> · **Author:** <name>
- **Actors:** attacker = <privilege>, victim = <role>

## Chain (source → sink)
1. **Source** — <where tainted data enters> (`file:line`)
2. **Carrier** — <helper it flows through> (`file:line`)
3. **Sink** — <what executes> (`file:line`)
- **Trust inversion:** <what made it look legitimate>
- **Link(s) the fix cut:** <which, and why it's inert for legit traffic>

## Why it was missed
1. <tool/skill that should have caught it> — <the mechanism that let it through>
2. ...

## Guardrails added
| Guardrail | File | Proven by |
|-----------|------|-----------|
| <checklist item> | <skill ref path> | would have flagged the original diff |
| <CI guard> | `scripts/<name>.sh` | ✓ pass on fix, ✗ fail on revert (negative-tested) |

## How to run
`npm run <script>`  → exits non-zero if the regression returns.
```

### 6c. Wire in

- Wire any script into CI / the npm scripts block so it runs unattended; a guard nobody runs is worthless.
- Flag any stray build artifacts you created (e.g. a dev rebuild dirtying a tracked bundle) and offer to revert.
- Do NOT commit unless the user asks. When they do: `SECURITY:` prefix for the guard, follow the repo's commit + attribution rules, reference the CVE/Patchstack ID in the body (never invent one).

---

## Guardrail patterns (reusable)

**Zero-dep CI grep guard** (works with no toolchain):
```bash
#!/usr/bin/env bash
# One-line why + CVE/Patchstack ref. Fail on the exact regression, exit non-zero.
set -euo pipefail
fail=0
grep -qE "<pattern-that-MUST-exist>" path/to/file || { echo "✗ <what> missing — <impact>"; fail=1; }
grep -RnE "<pattern-that-MUST-NOT-exist>" path/ && { echo "✗ <what> reintroduced — <impact>"; fail=1; }
[ "$fail" -eq 0 ] && echo "✓ guard intact."; exit $fail
```

**ESLint AST rule** (upgrade path; only if a lint pipeline exists) — one rule per chain link, `meta.docs.description` states the vuln class, message ends in the failure mode.

## Scope discipline

- One vuln → one post-mortem. Don't sweep the whole codebase for unrelated issues (that's `plugin-audit`/`bug-fix find`).
- Prefer editing an EXISTING checklist/detector over inventing a new skill — the guardrail should live where reviewers already look.
- A guardrail that would fire on legitimate code is worse than none — verify inertness (Phase 2) before shipping it.
- Never ship a one-sided fix for a paired plugin. Free-and-Pro parity (Phase 4C) is part of "done", not a follow-up.
