# Severity and Resolution Policy

Load this reference before calibrating findings or verifying fixes.

## Severity definitions

| Level | Definition |
|---|---|
| **Blocking** | Active breakage: crash, data loss, security hole, or silent wrong behaviour |
| **High** | A documented feature stops working or behaves differently |
| **Medium** | Correctness, performance, or maintainability issue without current user-visible breakage |
| **Suggestion** | Design, dead-code, or naming issue without immediate impact |

## Calibration rules

- **Impact sets the floor; probability adjusts at most one tier.** A narrow trigger window never demotes silent data loss or contract breakage to Suggestion.
- **Contract-violation floor:** breaking the change's own documented promise, schema, or PR claim is High or above.
- **Self-incrimination check:** when the evidence describes the feature's primary use case, the finding cannot be Suggestion.
- **Stale-async floor:** an out-of-order response that commits state for the wrong entity is High; escalate to Blocking across user, tenant, or permission boundaries.
- Ambiguity defaults to Suggestion only when impact is also ambiguous. Do not use uncertainty to lower a demonstrated impact.

## Resolution standard

- Mark a finding `cleared` only when its failure mechanism is structurally impossible and the reviewer records evidence.
- A narrower race window or reduced likelihood is `accepted-residual`, never cleared, and requires explicit maintainer sign-off.
- Prefer structural concurrency/atomicity fixes such as a transaction, row lock, compare-and-swap, request token, or idempotency key.
- When a recommendation offers alternatives, implement the strongest justified option; a partial mitigation does not resolve the stronger mechanism.
- "Strongest justified" bounds the fix from below, not from above. It forbids the fix that narrows a mechanism instead of removing it; it does not ask for a change wider than the class. The target both rules share: close the whole mechanism, nothing beyond it. See `SKILL.md` Step 2d.

