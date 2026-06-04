---
name: rigorous-coding-workflow
description: >
  A disciplined workflow for non-trivial coding work — plan before executing, use subagents to
  keep main context clean, capture lessons from every correction, verify before declaring done,
  and push for elegance with calibration. Use this skill whenever the user starts a multi-step
  coding task (3+ steps or any architectural decision), reports a bug, asks to fix failing CI,
  requests a refactor, or asks for a new feature. Trigger this even when the user doesn't
  explicitly ask for "process" — if the work is non-trivial, default to this workflow rather
  than improvising.
when_to_use: >
  Any multi-step coding task (3+ steps), architectural decision, bug report, failing CI,
  refactor, new feature, or re-attempt of a task that went sideways. Skip for trivial edits
  (typo, single-variable rename, comment).
---

# Rigorous Coding Workflow

A workflow for serious coding work. The premise: most failures in agentic coding aren't from lack of capability, they're from skipping steps. Planning, verifying, and capturing corrections are cheap; redoing botched work is expensive.

## When to use this skill

Apply this workflow when:
- The task involves 3+ steps or any architectural decision
- The user reports a bug or asks you to fix failing tests/CI
- You're refactoring, building a feature, or making non-trivial changes
- You're touching unfamiliar code
- A previous attempt went sideways and you're re-attempting

Skip it for trivial edits — fixing a typo, renaming one variable, adding a comment. Don't turn it into ritual.

## 1. Plan before executing

For any non-trivial coding task, **always plan via openspec, synced with `grill-with-docs`**. Don't write ad-hoc `tasks/todo.md` files — that fragments the planning artifact and contradicts openspec's single-source-of-truth convention.

The canonical sequence:

1. **Sync vocabulary first with `/grill-with-docs`.** A grilling session against the existing `CONTEXT.md` resolves canonical nouns before you commit them to a proposal. Skipping this step produces openspec changes that drift from project vocabulary — `Submission` in one place, `Entry` in another. The grill writes resolved terms back into `CONTEXT.md` inline.
2. **Scaffold the openspec change.** `openspec new change <name>` creates `openspec/changes/<name>/` with `proposal.md`, `design.md` (when architectural), `specs/<capability>/spec.md`, and `tasks.md`. Use the name `issue-<n>-<noun>` when an upstream issue exists; otherwise kebab-noun.
3. **Validate before executing.** `openspec validate <name> --strict` must pass. That's the last gate before code.

The detailed phase structure is documented in the `new-feature` skill — it orchestrates `grill-with-docs → openspec → tdd → review → ship` with explicit approval gates between phases. **Invoke `new-feature` rather than re-deriving the steps.** This skill (`rigorous-coding-workflow`) is the underlying principles; `new-feature` is the operational sequence.

For **read-only tasks** (review, audit, investigation, "tell me what's there"), no openspec needed — keep the plan in the response itself.

For **in-session execution tracking** (which steps of the current plan are in-flight, completed, blocked), use the built-in `TaskCreate` tool. That's a different concern from *planning* — execution tracking is ephemeral; the plan is durable in `openspec/changes/<name>/`.

If something goes sideways during execution, **update the openspec change** (proposal / tasks / design) before re-attempting. Don't recover by improvising — that fragments the plan from the artifact.

## 2. Use subagents for context hygiene

The main context window is a scarce resource. Spend it on the actual problem, not on reading files you'll skim once. Offload to subagents:

- Exploring an unfamiliar codebase
- Researching how a library works
- Running parallel analyses ("check these five files for X")
- Summarizing long logs or large outputs

One task per subagent, narrowly scoped. The main thread stays focused on the real work.

## 3. Capture lessons from every correction

When the user corrects you — "no, do it this way," "you missed X," "that's not how we do Y here" — append the lesson to `tasks/lessons.md`. Phrase it as a rule that would have prevented the mistake.

**Example:**
- Correction: "You added a try/except that swallowed the error. Don't do that."
- Lesson written: "Don't add try/except blocks that catch exceptions without re-raising or logging — surface errors instead of hiding them."

At the start of any session in this project, read `tasks/lessons.md` first. The goal is for the same mistake to happen once, not every session. This is the highest-leverage rule in this workflow — a single well-captured correction prevents dozens of future ones.

## 4. Verify before declaring done

A task isn't complete because you wrote the code. It's complete because you proved the code works. Before marking anything done:

- Run the tests. Read the output, don't just check the exit code.
- Diff your changes against main. Read the diff. Look for things you didn't mean to change.
- Demonstrate correctness — run the code, check the logs, hit the endpoint, exercise the feature.
- Ask: "Would a staff engineer approve this?" If no, fix it before claiming done.

The cost of a false "done" is high — the user moves on, the bug surfaces later, trust erodes. Verification takes minutes; the fallout from skipping it can take hours.

## 5. Push for elegance, but calibrate

For non-trivial changes, pause before submitting and ask: "Is there a more elegant way?" If the current approach feels hacky, force the rethink: "Knowing everything I know now, what would the clean version look like?"

But don't over-apply this. For obvious one-line fixes, ship the obvious fix. The elegance check is a tool for catching accidental complexity in real changes, not a ritual to perform on every edit. Calibration matters — without it, every task balloons into a refactor.

## 6. Fix bugs autonomously

When given a bug report, fix it. Don't ask which file to look in — find it. Don't ask if you should run the tests — run them. Don't ask the user to repeat what they already said.

Exceptions: ask when the report is genuinely ambiguous (two plausible interpretations leading to different fixes), or when the fix would touch something the user might not expect (changing a public API, modifying a config the user owns). Otherwise, drive.

For failing CI: read the logs, find the failure, fix it. Don't wait to be told how.

## Durable artifacts

Two on-disk files persist across sessions and resets:

- **`openspec/changes/<name>/tasks.md`** — the current plan, scaffolded by `openspec new change`. Mark items complete as you finish them. Archive with `openspec archive <name>` once shipped (moves into `specs/`).
- **`tasks/lessons.md`** — running list of corrections written as rules. Read at session start. Lives outside `openspec/` because lessons span multiple changes and survive after individual openspec changes are archived.

Don't create `tasks/todo.md` — that pre-dates the openspec convention and now duplicates `openspec/changes/<name>/tasks.md`. If you find one in an old repo, migrate its contents into an openspec change.

## Core principles

Underneath everything above:

- **Simplicity first.** Make every change as small as it can be while still solving the problem. Bias toward less code, not more.
- **No laziness.** Find root causes. Don't paper over symptoms with try/except, conditional flags, or "temporary" workarounds. Senior-developer standards apply.
- **Minimal impact.** Touch only what's necessary. Resist drive-by refactors unless the user asked for them.

When the rules above conflict with these principles, the principles win. The rules are means; the principles are ends.
