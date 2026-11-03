# Detector: Security assertion trust

Applies when the diff adds or changes a **security test, detector, guard, lint rule, or any assertion that claims to prove a security property** (authorization holds, input is sanitized, a secret is not exposed, a vuln class is caught). The unit under review is the *check itself*.

The failure mode this detector exists for: the reviewer runs the check, sees it pass, praises its scaffolding, and ships it — never noticing the check trusts a forgeable signal or iterates an incomplete set. A green run validates the implementation and **inherits the author's framing**. These are the questions a green run cannot answer.

## J.1 — Signal forgeability (what else produces this signal?)

For every assertion, name what it keys on, then name every *other* thing that could produce that same value while the security control has actually failed.

| Assertion keys on | Forged by | Correct fix |
|---|---|---|
| dispatched HTTP status ∈ {401,403} = "denied" | a handler that returns 401/403 for its *own* reasons (bad nonce, missing param) *after* the gate let the caller through | call the permission callback/policy **directly**; read its own boolean, not a downstream status |
| status ≥ 400 = "rejected" | 404 from an unroutable test URI; 400 from validation; 500 from a crash — none are authorization | accept only the *specific* code the control emits, and prove the control was reached |
| "no `.innerHTML` in source" = "no XSS sink" | a library `formatter`/callback whose return the lib injects via innerHTML | assert on the data flowing *into* the sink, not the literal sink token |
| grep finds the guard string = "guarded" | the string present in a comment/dead path while the live path is unguarded | tie the assertion to the executed path; mutation-test it (remove the guard → check must fail) |
| exception thrown = "blocked" | an exception from an unrelated precondition before the control ran | assert the exception is the control's, by type/code/message |

Rule: **if the signal can be produced by anything other than the control succeeding/failing, the assertion keys on the wrong thing.** Move it to the control's own decision.

**A comment is not code — strip it before matching a code token.** A detector that greps a callback body for a gate/nonce token (`Acl::verify(`, `verifyNonce(`, `wp_verify_nonce(`) matches the token wherever it appears — *including in a comment*. FluentForm's `TransactionShortcodes::routeAjaxEndpoints()` carries `// Nonce verified by verifyNonce() method below`; a per-callback CSRF check keyed on `verifyNonce(` passed **even after the real `$this->verifyNonce();` call was deleted**, because the phpcs comment still contained the token. The green baseline hid it; only a mutation (remove the real call, keep the comment, expect FAIL) exposed it. Fix: run the body through `token_get_all` and drop `T_COMMENT`/`T_DOC_COMMENT` before matching, so the token must live in executed code. Reflex: whenever a detector matches a *code* signal against *text*, the text includes comments and (often) strings — the match target must be narrowed to code, and a mutation must prove it. This is the same failure as the table row above, made concrete: I had written that row and still shipped a detector vulnerable to it — the discipline that caught it was the mutation, not the review.

## J.2 — Enumeration completeness (what is it not iterating?)

Green on the enumerated subset says nothing about the skipped remainder.

- **First-of-N.** `$mutating[0]`, first route, first field, first handler, `array[0]`. A handler registered for `['POST','PUT','DELETE']` tested only on POST leaks on DELETE. Require every element.
- **One side of a pair.** Free but not Pro (or vice versa); producer but not consumer; source keyspace but not service keyspace. Cross-boundary security holds only if *both* ends are checked.
- **Happy status/config only.** Default settings, populated data, logged-in-admin. The leak lives in the empty/absent/anonymous/alternate-role cell.
- **Silent caps.** Top-N, sampling, "skip if absent." A cap that isn't logged reads as full coverage. Require an explicit, printed reason for anything dropped.
- **The enumerator's own grammar is a silent cap.** A regex/parser that bakes in a naming convention drops off-convention entries with no trace — the count still looks plausible. `wp_ajax_([a-z_]+)` silently omits kebab-case and capitalised actions (`fluentform-form-update`, `fluentform-do_entry_bulk_actions_payment`, `...formSettings`); the ledger prints "16 actions" and reads complete. **Never trust an enumerator's output for a completeness claim — regenerate ground truth independently and diff the count.** Grep the raw registrations/routes/hooks with a deliberately permissive pattern, assert `enumerator_count == grep_count`, and eyeball the diff. This is not optional for "enumerate-all"/coverage-gate/security-detector code; reasoning about completeness is not verifying it.

Rule: **enumerate the full set, or log exactly what was excluded and why.** An unlogged cap is a coverage lie — and the most dangerous cap is the one hidden inside the matcher, because a buggy security enumerator does not just under-report: it *hides the very vuln it exists to catch* (a hyphenated privileged handler was never enumerated, so the ungated-handler check stayed green over a live broken-access-control hole).

## Two reflexes that keep the halo off

- **The self-test shares the blind spot.** A planted-leak probe or positive control proves the check *can fire* — but it's almost always built to the same narrow shape as the main assertion (planted open gate returns 200, so the probe only ever exercises the 200 path; the 403-masquerade path is invisible to both). Its presence should not lower suspicion; verify the self-test covers a *different* failure shape than the main path — and for an enumerator, that the planted fixture uses an **off-format name** (a hyphen, a capital), or it proves the mechanism while never reaching the awkward entries where real bugs hide.
- **AI reviewing AI-written code shares the author's priors.** If the diff was likely AI-authored (and you are an AI reviewer), you share its assumptions by construction — including the wrong ones about data shape. You cannot introspect your way out of a shared blind spot; you must go get ground truth from the system (grep, run, count). On a completeness/enumeration claim you could not independently verify against ground truth, do not pass it — output "**enumeration completeness UNVERIFIED**" as a finding and say what you'd need to check.
- **Scaffolding ≠ evidence.** Discriminators ("an admin must get through"), restore-by-hash, coverage tables, mutation harnesses raise confidence in the *plumbing* being honest. They say nothing about J.1/J.2. Judge those two on their own.

## The move

For each security assertion in the diff, **adversarially construct the counterexample**: the concrete input where the control fails but the assertion still passes. If you can build it → finding. If you genuinely cannot after trying both J.1 and J.2 → say so explicitly in *What looks good* ("verified the gate is read directly, not via status; all mutating verbs enumerated"). Never infer safety from a passing suite.

## Worked example — the miss this detector was written for

A runtime authorization sweep dispatched every mutating REST route and asserted anon/subscriber got 401/403. Self-review ran it (all routes 401), saw a planted-leak self-test and an admin discriminator pass, and shipped it. A fresh adversarial reviewer found two holes the green run hid:

1. **J.1:** a route whose gate *permits* anon while the handler independently returns 403 read as "rejected" — the 401/403 signal was forgeable by the handler. Fix: query `permission_callback` directly; only a literal `true` is permit. Proof test asserts dispatch returns 403 yet the gate check still flags the leak.
2. **J.2:** `$mutating[0]` tested only the first verb of each handler. Fix: enumerate every verb.

The self-test (planted open gate → 200) shared J.1's blind spot exactly — it never exercised open-gate-behind-403, so it couldn't have caught it. That is the halo in action.
