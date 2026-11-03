# Pre-Merge Review Improvement Plan

## Goal

Make `pre-merge-review` a trustworthy merge gate: it must review the intended change against the correct base, preserve every independent finding, execute repository-native verification, and distinguish a clean review from incomplete verification.

## P0 — Correctness and false-clean prevention

- [x] Resolve the actual PR/base ref and record the merge base instead of silently assuming `origin/dev`.
- [x] Inventory staged, unstaged, and untracked files; never imply they were reviewed when excluded.
- [x] Align finding categories and detector routing so valid findings are not dropped.
- [x] Preserve independent findings during aggregation; deduplicate only the same failure mechanism.
- [x] Require explicit source verification before a prior finding is marked cleared.
- [x] Remove execution-context-only authorization exemptions.
- [x] Add an explicit `READY`, `NOT READY`, or `INCOMPLETE VERIFICATION` verdict.

## P1 — Evidence-backed review

- [x] Read the PR/issue intent and applicable repository instructions before reviewing the diff.
- [x] Discover repository-native test, build, lint, security, and dependency gates.
- [x] Record every command as pass, fail, skipped, missing, or blocked, including skip counts.
- [x] Treat network/tool failures as verification gaps rather than clean results.
- [x] Require runtime/browser verification for changed interactive behavior when static review cannot prove it.
- [x] Add a final synthesis and clean-verdict disproof pass after the parallel workers finish.
- [x] Add a per-finding refutation pass (Step 2c) so false positives are killed by a clean-context skeptic, not by the detector that raised them.
- [x] Require fix alternatives at different depths for confirmed Blocking/High findings (Step 2d), recommending the smallest change that closes the class.

## P2 — Deterministic runner

- [ ] Add a small runner that resolves scope, creates worker envelopes, validates NDJSON, computes stable fingerprints, and renders the report.
- [ ] Define a machine-readable manifest linking detector-pack anchors, worker-routing labels, final finding categories, and corpus cases.
- [ ] Add fixtures for wrong-base detection, dirty-worktree coverage, category rejection, duplicate findings on one line, and re-run line movement.
- [ ] Add fixtures for refutation: a finding whose guard makes it impossible (expect `refuted`), one bounded by a precondition (expect `narrowed`), and one where the skeptic finds nothing (expect `confirmed`, finding stands).
- [ ] Add pack-deletion and rule-omission mutation tests proving that detector drift cannot pass validation or mark findings cleared.
- [ ] Add a fixture repository for Free/Pro version-skew and cross-repository contract checks.
- [ ] Generate or refresh `agents/openai.yaml` if this skill is distributed through the Codex skill registry.

## P3 — Forward testing

- [ ] Run the revised skill in fresh agent contexts against one PHP-only authorization diff, one Vue async/UI diff, one schema migration, and one security-detector diff.
- [ ] Compare results with a human review and record false positives, false negatives, and incomplete-verification cases.
- [x] Require 100% classification of the curated corpus; do not let the aggregate percentage hide newly unmapped cases.

## Done criteria

The skill is ready to call a canonical merge gate when:

1. Scope resolution and worktree accounting are deterministic.
2. No valid category is rejected by the finding contract.
3. A finding cannot become cleared through detector absence alone.
4. Required project gates and their skips are visible in the report.
5. A `READY` verdict is impossible while blocking/high findings or material verification gaps remain.
