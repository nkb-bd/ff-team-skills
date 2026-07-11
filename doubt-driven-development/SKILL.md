---
name: doubt-driven-development
description: >
  Adversarial fresh-context review for high-stakes or irreversible decisions, run as a
  CLAIM → EXTRACT → DOUBT → RECONCILE → STOP loop. A clean-context skeptic is spawned to
  REFUTE the decision, not confirm it. Use before a schema migration, a hook-contract change,
  a capability/permission change, deleting or overwriting non-trivial code, a security-sensitive
  change, or any call that is expensive to reverse. Triggers: "am I sure", "sanity-check this",
  "is this safe to ship", "second-guess this", "what could go wrong".
when_to_use: >
  Before committing to an architectural or irreversible decision — schema/DB migration, a change
  to a public hook or filter contract, a capability or policy change, deleting/overwriting code you
  did not write, a security-sensitive change, or anything a Pro addon or third party depends on.
  Skip for reversible, low-blast-radius edits (typo, cosmetic tweak, additive private helper).
---

# Doubt-Driven Development

## Philosophy

Most expensive mistakes are not from lack of skill — they are from confident momentum past an
assumption that was never checked. The author of a change is the worst person to find its flaws:
they already believe it. This skill deliberately separates the *deciding* mind from the *doubting*
mind by spawning a fresh-context skeptic whose only job is to **refute**.

Doubt is cheap. A reverted migration, a broken addon contract, or a security regression is not.

## When to use this skill

Run the loop before the point of no return. Concretely, any of:

- DB schema change — column added/renamed/dropped, table created, index change, data backfill.
- A change to a **public hook or filter** contract (name, argument shape, return type, firing order).
- A capability, policy, or permission-boundary change (who can do what).
- Deleting or overwriting non-trivial code — especially code you did not write.
- A security-sensitive change (auth, nonce, sanitization boundary, file/SQL access).
- Anything a Pro addon, third party, or the user's own `functions.php` is known to depend on.

If the change is reversible and low-blast-radius, do NOT run this — it is overhead. Judgement, not
ritual.

## The loop: CLAIM → EXTRACT → DOUBT → RECONCILE → STOP

### 1. CLAIM
State the decision as **one falsifiable sentence**. Not "improve the player" — rather
"renaming the `fluent_player/render` filter's third argument from array to object is safe because
no shipped addon reads it positionally." A claim you cannot falsify is too vague to doubt; sharpen
it first.

### 2. EXTRACT
List the load-bearing assumptions the claim rests on. Ground them in evidence, not memory:
- `get_impact_radius` and `get_affected_flows` (code-review-graph) for blast radius.
- `query_graph` `callers_of` / `imports_of` for who actually depends on the seam.
- The Pro addon repo when the seam is a public contract.
Write each assumption as a bullet. These become the skeptic's attack surface.

### 3. DOUBT
Spawn a subagent (`Agent` tool) with **clean context** — it must not inherit your belief. Prompt it
to REFUTE, with a bias toward "unsafe":

> Here is a decision and the assumptions it rests on. Your job is to find why it is WRONG or unsafe.
> For each assumption, try to construct a concrete counterexample. Default to "unsafe" when uncertain.
> Return: surviving doubts, each with the concrete scenario that triggers it.

For the highest-stakes calls (schema migration touching live data, a security boundary), escalate to
a **cross-model** second opinion when the environment allows it — a different model fails differently.

### 4. RECONCILE
For every surviving doubt: either **resolve** it (evidence that the counterexample can't occur) or
**accept** it (explicitly, with the reason it's tolerable and any mitigation — migration guard, back-compat
shim, feature gate). No silent dismissals. "The skeptic was probably wrong" is not a resolution.

### 5. STOP
An explicit **go / no-go**, stated as such — not a drift back into implementation. If go: proceed, and
carry any accepted-doubt mitigations into the build. If no-go: the decision changes, and the loop was
worth more than the whole feature.

## Anti-rationalization

| The shortcut you'll reach for | Why it's wrong |
|---|---|
| "The diff is small, so it's safe." | Blast radius ≠ diff size. A one-line hook-signature change can break every addon. |
| "I'm confident, I don't need a skeptic." | Confidence is the trigger for this skill, not the exemption from it. |
| "I'll just check it myself." | Same-context self-review re-confirms; it doesn't refute. Fresh context is the point. |
| "Tests pass, so it's fine." | Tests encode behavior you thought of. The doubt loop hunts the behavior you didn't. |
| "I'll add a back-compat shim later if someone complains." | For a public contract, "later" is after it's shipped and forked. Decide now. |

## Relationship to other skills

- `$new-feature` calls this at its **Phase 3 gate** (Breaking tier), inside **Phase 4 `/build auto`**
  when it hits an irreversible decision, and in **Phase 5** for any high-stakes reviewer finding.
- `$pre-merge-review` *reviews a diff after it exists*; this skill *interrogates a decision before it's built*.
  They are complementary — doubt upstream, review downstream.
- Pair with `$source-driven-development` when a surviving doubt is really "I'm not sure the API behaves
  the way I assumed" — that's a grounding problem, resolve it there.
