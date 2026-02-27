---
name: pr-descriptor
description: Generate concise, why-first pull request descriptions from git evidence and a repository PR template. Use when users ask to draft or update PR text, summarize branch work for reviewers, or fill `pull_request_template.md` while omitting non-meaningful sections.
---

# PR Descriptor

Generate PR descriptions that explain why the PR is needed first, then summarize what changed at a high level.

## Output Contract

- Always include `What does this PR do and why?`.
- Keep output concise: short opening paragraph plus brief supporting bullets only when needed.
- Prioritize problem, intent, and reviewer-relevant impact.
- Avoid file-by-file or commit-by-commit narration.
- Do not invent issue IDs, tests, screenshots, risks, or outcomes.

## Execution Workflow

1. Resolve the PR template path in this order:
   - `.github/pull_request_template.md`
   - `.github/PULL_REQUEST_TEMPLATE.md`
   - `references/pull_request_template.default.md` (fallback)
2. Determine base branch.
   - Prefer upstream merge target if it maps to `development`, `master`, or `main`.
   - Otherwise evaluate candidates in this order:
     - `origin/development`, `origin/master`, `origin/main`, `origin/dev`
     - `development`, `master`, `main`, `dev`
   - If only one candidate exists, use it.
   - If multiple candidates exist, compare `git merge-base HEAD <candidate>` and choose the candidate with the most recent merge-base commit.
   - If no candidate exists or selection is ambiguous, ask the user: `Which base branch should I diff against: development, master, main, or dev?`
3. Gather change evidence:
   - `git status --short --branch`
   - Use the base branch resolved in step 2
   - `git diff --name-status <base>...HEAD`
   - `git diff --stat <base>...HEAD`
   - `git log --oneline <base>..HEAD`
   - Inspect changed files as needed to extract intent and testing details
4. Derive narrative:
   - Problem or need
   - High-level solution approach
   - Scope and impact boundaries
5. Fill template sections conditionally using the section rules.
6. Run final quality gate checks.

## Template Section Rules

### What does this PR do and why?

- This section is required.
- First sentence states the underlying problem.
- Second sentence states the solution approach.
- Optional third sentence states impact/scope boundary.
- Include issue reference only if explicitly provided.

### Changes

- Include only if it adds meaningful reviewer context.
- Keep to 1 to 4 concise bullets by capability/area.
- Do not list raw filenames or diff noise.
- Omit the section entirely when a change list would be obvious or redundant.

### How to test

- Include only when there are concrete, reproducible validation steps.
- Use numbered steps with expected outcomes.
- Omit the section entirely when no meaningful test flow is available.

### Screenshots

- Include only for visual UI changes where screenshots add review value.
- Omit when no meaningful visual delta exists.

### Anything the reviewer should know?

- Include only for risks, trade-offs, migrations, rollout notes, or known limits.
- Omit when there is nothing material to flag.

## Concision Rules

- Keep wording direct, plain, and compact.
- Remove filler and repeated statements.
- Prefer short sentences and concrete nouns/verbs.
- Keep overall output as short as possible without losing key context.

## Quality Gate

Verify before final output:

- Opening section clearly answers why this PR is needed.
- Optional sections are present only when meaningful.
- All statements are evidence-backed.
- No fluff, no bloat, no redundant details.

## References

- `references/pull_request_template.default.md`
