# PR body fill rules

## Build order

1. Read `.github/pull_request_template.md` from the repo being PR'd. That is the source of layout.
2. Start from the template file, blank. **Never** start from an existing PR body, even the one you are editing — stale checkmarks survive edits and become claims nobody made.
3. Literal-diff your filled body against the template: every checklist line present, same wording, same order.
4. Fill `What does this PR do and why?` first — the why leads.

## Checkbox rule

A box is checked only when you can name the evidence:

| Claim | Evidence required |
|---|---|
| Tests pass | the gate command and its exit code, run this session |
| Manually tested | what you did in the browser and what you saw |
| No breaking changes | the back-compat pass, naming what you checked |
| Docs updated | the file and section |

No evidence → leave it unchecked and say why in the body. An unchecked box is information; a falsely checked one is a lie the reviewer trusts.

## Never

- Delete a gate section (`Merge checklist`, `Changes & review routing`) — they stay even when awkward.
- Invent issue IDs, screenshots, test names, or reviewer names.
- Add a Claude attribution footer.
- Open a PR non-draft without an explicit ask.

## Posting

Creating and pushing the PR on request is fine. Posting **reviews, comments, approvals or review requests** on GitHub is not — report the verdict in chat and wait for a go-ahead. Merging always needs a separate yes.
