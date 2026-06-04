# Audit: `/new-feature` skill

> Audit date: 2026-06-04 · Subject: `~/.claude/skills/new-feature/SKILL.md` (317 lines)
> Scope: structure, gates, tier logic, user-facing questions, multi-perspective review.
>
> **Status: all defects D1–D7 fixed in SKILL.md on 2026-06-04**, plus the
> evidence-based tier veto from §5 (diff/`detect_changes` can escalate a
> self-declared tier). Defect table below preserved as the audit record.

---

## 1. What it is

An **orchestrator** skill — not a detector. It composes single-purpose skills
(`grill-with-docs`, `openspec`, `design-an-interface`, `tdd`, `pre-merge-review`,
`pr-descriptor`) into one pipeline with approval gates, so sequencing is no longer
left to in-the-moment judgment.

```
Phase 0  Triage   → pick intensity tier, read CLAUDE.md/AGENTS.md, find upstream artifact
Phase 1  Align    → $grill-with-docs       → one-sentence problem + canonical noun
Phase 2  Plan     → openspec proposal.md   (+ $design-an-interface if Large)
Phase 3  Spec     → spec.md / design.md / tasks.md, openspec validate --strict
Phase 4  Build    → $tdd red-green-refactor, commit per milestone
Phase 5  Review   → $pre-merge-review (light or deep)
Phase 6  Ship     → $pr-descriptor, gh pr create (with consent), openspec archive
```

### Tier system (Phase 0)

| Tier | Signal | What runs |
|---|---|---|
| **Trivial** | Typo, config tweak | Nothing — skill exits, just commit |
| **Small** | Single-file fix | Phase 5 light only |
| **Medium** | One panel / endpoint / ~3-file fix | Phases 2 + 4 + 5 light |
| **Large** | New module / service / policy / migration | Full workflow, Phase 5 deep, + design-an-interface |
| **Breaking** | API change, schema migration | Full + mandatory Phase 1 + `/plugin-audit` post-merge |

Each tier *adds* phases going down. Medium is the first tier that plans;
Large is the first that grills and specs formally.

### Every question it asks the user

| # | Phase | Question | Why |
|---|---|---|---|
| Q1 | 0 | "Is there an upstream artifact?" (issue #, PRD, openspec change) | Grill becomes confirmation, not re-discovery; issue # feeds `Closes #<n>` in Phase 6 |
| Q2 | 0 | "I picked tier X because Y — agree?" | Tier decides how much workflow runs; user gets veto before work starts |
| Q3 | 1 | Grill interview: canonical noun, problem, who hits it, smallest valuable version | Shared vocabulary; catches the communication gap that costs 10× later |
| Q4 | 1 gate | "Problem statement + canonical noun — yes?" | Cheapest place to catch misalignment; noun propagates into change name, spec, classes, PR |
| Q5 | 2 gate | "proposal.md — yes?" (+ "which interface design?" if Large) | Approving one page is cheap; a wrong API shape at review time is not |
| Q6 | 3 gate | "spec + tasks — yes?" | WHEN/THEN scenarios are the contract TDD builds against |
| Q7 | 4 | "May I push?" (per push) | Outward-facing action; "once-approved is not forever-approved" |
| Q8 | 5 gate | "Review report — yes, before push?" | Every Blocking must be addressed pre-push |
| Q9 | 6 | "PR draft — may I run `gh pr create`?" | Same consent rule as push; never automatic |

Two kinds of questions: **alignment gates** (Q2–Q6, Q8 — freeze decisions while
they're one paragraph, not 500 lines) and **consent asks** (Q7, Q9 — fresh
explicit permission for every outward-facing action). It deliberately never asks
permission for local commits, spec files, or running review — reversible,
in-workspace actions.

---

## 2. Strengths

1. **Tier table.** Scales ceremony to risk with concrete signals ("one endpoint",
   "~3 files"); the Trivial row ("don't invoke me at all") is rare self-awareness.
2. **Consent rules at the point of use, twice.** "Once-approved is not
   forever-approved" appears in both Phase 4 and Phase 6, exactly where push/PR
   happen. Agents drift on rules stated once in a footer.
3. **`composer dump-autoload` gotcha** (SKILL.md:211-218). Real, non-obvious
   failure (`--classmap-authoritative` hides new classes) with symptom, cause,
   and verification command.
4. **Upstream-artifact → `Closes #<n>` loop.** Issue # captured in Phase 0,
   threaded into the change name (`issue-142-<noun>`) and the PR description —
   a durable two-way link greppable from both ends, zero integration code.
5. **Hooks-at-seams rule** (Phase 4). Encodes the free/pro business model into
   the build phase: "where would a Pro plugin need to short-circuit this?"

---

## 3. Defects (severity order)

| # | Severity | Defect | Detail | Fix |
|---|---|---|---|---|
| D1 | High | **Internal contradiction** | Tier table (Medium): "Skip the grill if you already know the answer" vs. What NOT to do: "Don't skip Phase 1 even if you 'know what to build'" | Amend don't-skip rule to "Tier ≥ Large" |
| D2 | High | **Dangling dependency in Medium tier** | Phase 2's change name needs the canonical noun, produced by Phase 1 — which Medium skips. Source of the noun undefined | State Phase 2 inputs explicitly: noun from Phase 1, upstream artifact, or ask the user |
| D3 | Medium | **Frontmatter lies about the stack** | Description says "PHP + Vue 3 + Gutenberg React"; body correctly says stack varies (FluentForm = Vue 2 Options API, no Gutenberg). Description drives skill selection | Description: "frontend stack varies per repo — read CLAUDE.md" |
| D4 | Medium | **One-laptop portability** | Hardcoded `/Volumes/Workspace/pr-reviews/...`, `/Volumes/Projects/Tools/agent-skills/shared/scripts/audit-autharif.sh` — silently breaks on any other machine | Relative/fallback paths; hedge script refs like `$simplify` is hedged |
| D5 | Medium | **References a skill that may not exist** | `$zoom-out` invoked twice (Phase 4) with no "if available" hedge; not in this environment's registry | Add the same hedge as `$simplify` |
| D6 | Medium | **Unenforceable post-merge step** | "After the PR merges: `openspec archive`" — merge happens days later, session is dead, nothing reminds anyone. Zombie change dirs accumulate | External trigger: `/schedule` routine, CI step, or archive-check at start of next run |
| D7 | Low | **Gate fatigue** | Large tier = 6 interactive stops; by gate 4, rubber-stamping risk. A rubber-stamped gate is worse than no gate (false confidence) | Offer batching gates 2+3 (proposal + spec shown together) |

---

## 4. Five-perspective review

### CTO — "Does this scale beyond its author?"

- ✅ **Encoded institutional knowledge.** Autoload trap, hooks-at-seams,
  free↔pro thinking — senior judgment made executable; survives the author leaving.
- ⚠️ **Bus factor disguised as automation** (D4). Looks shared, is one laptop.
  Worst outcome isn't breakage — it's the team concluding "AI workflows don't work."
- ⚠️ **No measurement.** Nothing tracks escaped-defect rate per tier; the
  ceremony is faith-based without it.
- ⚠️ **Workflow ends at PR-create; business process ends at merge+release** (D6).
- **Verdict:** approve as pilot; demand portability before calling it team process.

### Architect — "Are the abstractions right?"

- ✅ **Correct layering.** Orchestrator delegates to replaceable single-purpose
  skills — pipeline-of-strategies, done right.
- ✅ **Tier system = policy/mechanism split.** Mechanism (phases) fixed; policy
  (which phases run) parameterized by risk. "Stack adaptation" section shows the
  author knew invariant vs. variant parts.
- ✅ **`issue-<n>-<noun>` naming** = lightweight foreign key between tracker and
  openspec with no integration code.
- ❌ **Implicit phase contracts** (D2): nullable dependency dereferenced without
  a guard. ❌ **Two sources of truth for one rule** (D1) — duplicated config
  disease. ❌ **Interface drift** (D3): the description is the skill's public
  interface; interface lies are worse than implementation lies.
- **Verdict:** sound skeleton, leaky contracts.

### Technical lead — "Will the team follow it?"

- ✅ Gates map to exactly where a lead intervenes: problem, proposal, spec,
  pre-push, pre-PR. An async version of looking over a shoulder.
- ✅ Re-runnable review report with `[cleared]` tracking — findings as stateful
  checklist, not read-once wall of text.
- ✅ "Don't refactor the world mid-feature" prevents the 40-file diff where
  35 files are drive-by refactoring.
- ⚠️ **Gate fatigue → rubber-stamping** (D7); watch "yes"-latency dropping.
- ⚠️ **Tier is self-reported.** Nothing stops declaring "Small" on a risky
  change to skip the spec. Breaking-tier signals (schema change, removed hook)
  should be *detected* from the diff — `detect_changes` already feeds Phase 0.
- **Verdict:** adopt; watch compliance decay; batch the middle gates.

### Experienced developer — "Help or friction?"

- ✅ Tier table respects time; the skill scales *down*, not just up.
- ✅ Phase 4 WordPress checklist (unslash+sanitize, escape-at-output,
  nonce-before-capability, `prepare()`, never `__return_true`) is the exact
  PR-grep list. Autoload paragraph = half a day of debugging compressed.
- ✅ Friction placed on outward actions only; local commits flow freely.
- ⚠️ Inconsistent grill-skipping (D1) means unpredictable friction — more
  annoying than high friction.
- ⚠️ Time estimates ("~3 min") are fantasy for real grills/specs.
- ⚠️ Nothing forces re-reading the approved spec mid-Phase-4; long sessions
  drift from it.
- **Verdict:** net positive on Large/Breaking; marginal on Medium until D1 fixed.

### Manager — "Visibility and failure handling?"

- ✅ **Audit trail for free:** issue → change dir → spec → tasks checkboxes →
  review report → PR with `Closes #n`. "Why does export work this way?" is
  answered in design.md with alternatives and rationale.
- ✅ tasks.md checkboxes = feature status without interrupting anyone.
- ✅ Tier announcement = implicit estimate commitment, recalibrated in the open.
- ⚠️ **Loop doesn't close** (D6): GitHub auto-close works, but
  `openspec/changes/` accumulates zombie dirs; stale process artifacts are worse
  than none — people read them as current.
- ⚠️ **No escalation path.** Gates only know "yes" or "revise" — no park/kill/
  defer state for abandoned features; scaffold fate undefined.
- ⚠️ Quarterly audit + weekly drift-check are "optional" with no owner or
  trigger. Optional + unowned = never happens; belongs in `/schedule`.
- **Verdict:** great visibility during the feature, blind after merge.

---

## 5. Synthesis

Findings every seat converged on (signal they're real):

| Finding | Flagged by |
|---|---|
| Post-merge steps unowned/unenforceable (D6) | CTO, manager, lead |
| Implicit contracts drift (D1, D2, D3) | Architect, developer, lead |
| One-laptop portability (D4, D5) | CTO, lead |

One tension needing a deliberate decision, not a patch: **gates protect quality
but decay under fatigue.** The fix is neither more nor fewer gates — make tier
detection partly evidence-based (let `detect_changes` on the diff veto a
self-declared "Small").

**Net:** the core bet — *ceremony proportional to risk, consent for outward
actions, artifacts as memory* — holds from every seat. Everything wrong is
erosion, not design. Fix maintenance debt; keep the architecture.

### Recommended fix order

1. D1 + D2 + D3 — ten-minute text edits, removes all contradiction.
2. D5 — one-line hedge for `$zoom-out`.
3. D4 — path fallbacks.
4. D6 — wire archive/audit steps to `/schedule` or a start-of-run check.
5. D7 — optional gate batching for solo-dev Large runs.
