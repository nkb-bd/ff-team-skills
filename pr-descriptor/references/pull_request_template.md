<!-- Merge-gate PR template. Do not delete sections.
     SINGLE source of truth — no repo copies; pr-descriptor reads this file directly.
     (FYI: .github/pull_request_template.md only pre-fills from a repo's DEFAULT branch — inert on dev-based repos.)
     Per-PR repo-specific lines may be APPENDED in the PR body — never remove or reword the shared lines. -->

## What does this PR do and why?

<!-- Problem first, then the approach. Link the ticket (FluentBoards #/url) with the closing keyword that
     fits: Fixes (bug), Closes (completes the ticket), Refs (related). Not every PR has a ticket. -->

**Paired free/pro PR:** <!-- link the counterpart PR when this changes a free ↔ pro contract surface, or N/A -->

## Key changes

<!-- 3–6 bullets anchoring the review: `path/File.php::method()` — what changed there and why it matters.
     Anchors for the important points, not a file-by-file inventory. -->

-

## How to test

<!-- Numbered repro/verification steps. UI change: add before/after screenshots.
     Docs/config-only: one line saying so. -->

1.

## Merge checklist

<!-- Definition of Done. Check only what's verified; mark N/A with a reason. -->

- [ ] PHPCS clean (or violations not increased vs base — see gate)
- [ ] PHPStan clean at the project's configured level (no new `@phpstan-ignore`)
- [ ] Tests added or updated; coverage **not decreased**
- [ ] No debug code (`error_log`, `var_dump`, `dd`, `print_r`, `console.log` in shipped paths)
- [ ] No secrets committed (keys, license keys, customer data)
- [ ] Backward compatibility preserved, or migration documented
- [ ] Customer-facing strings i18n'd (if applicable)
- [ ] Changelog entry added under **Unreleased**
- [ ] Dev docs updated **in this PR** if public hooks/filters/REST/APIs changed
- [ ] Reproduction steps filled in "How to test" + screenshots/recording for UI changes

## Changes & review routing

<!-- Check every area the diff touches. Repos may append product-specific lines.
     ⚠ lines require a named external reviewer, even with peer review. -->

- [ ] PHP (backend logic, models, services, hooks)
- [ ] JS/Vue (admin UI, public scripts)
- [ ] Tests
- [ ] Build/config (composer, npm, CI)
- [ ] Docs (READMEs, dev docs, ADRs)
- [ ] ⚠ Security-touching (auth, payments, data handling, file upload)
- [ ] ⚠ Database schema change (tables, columns, indexes, activation migration)
- [ ] ⚠ Public API add/signature change (hook, filter, REST endpoint)
- [ ] ⚠ Architecture decision (link the ADR)
- [ ] ⚠ Cross-product / cross-repo dependency (free ↔ pro)
- [ ] None of the ⚠ categories — peer review is sufficient

## Anything the reviewer should know?

<!-- Risks, trade-offs, gate-bypass reasons, areas needing extra scrutiny.
     Bot REQUEST CHANGES: address it, or the Dev Lead writes the override note here. -->
