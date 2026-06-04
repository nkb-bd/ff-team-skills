# Changelog Style Guide

Conventions derived from FluentForm `readme.txt` and the WPManageNinja plugin family.

## Heading format

```
= X.Y.Z (Date: Month DD, YYYY) =
```

- `Month` is the full English name (`January`, not `Jan` or `01`).
- Comma between `DD` and `YYYY`.
- Exactly one space between `Date:` and the date.
- Two equal signs on each side, surrounded by single spaces.

**Do not** invent new heading formats per release. Read the existing top entry to confirm the current convention before generating a new one.

## Bullet format

```
- <Verb> <user-visible change>
```

- Hyphen + space, no asterisks, no nested bullets.
- Sentence case, no trailing period.
- One bullet per change. Combine two commits that fix two facets of one user-visible bug.

## Verb taxonomy

| Verb | Use for |
|---|---|
| `Adds` | New end-user feature, new setting, new integration |
| `Improves` | Better UX or workflow on an existing feature |
| `Fixes` | A bug end users can observe |
| `Removes` | A feature, setting, or behavior taken away |
| `Hardens` | A security fix (use neutral language — don't reveal exploit details) |
| `Updates` | Third-party integration bumped to a new API version |
| `Tightens` | A scope or access change that constrains an existing behavior |

## What never goes in the changelog

- Refactors and code-cleanup with no user-visible effect ("REFACTOR: rename …", "Move … to …")
- Lint, formatting, comment-only commits
- Docs commits ("DOCS: update …", "Update README")
- Build / asset regeneration
- Dependency lock-file bumps
- Test additions / fixes
- Visibility widening of internal methods (mention only the resulting user-visible behavior, if any)
- `.gitignore`, `.claude/`, `.mcp.json`, CI config tweaks

## Wording rules

- **Front the user-visible effect**, not the technical fix. Write *"Fixes conversational form pretty URLs rendering inside the landing-page wrapper"*, not *"Replace inline shortcode with standalone renderer"*.
- **Plain English**, not framework jargon. *"Fixes conditional logic not-equal check when the target field has no value"* beats *"Fixes ConditionalLogic operator handling for empty rule.value"*.
- **Identify the feature** by its product name. *"Multi-step form submit visibility"*, not *"StepForm submit visibility"*.
- **No commit-prefix bleed.** Drop `FIX:` / `IMPROVE:` / `FEAT:` SCREAMING prefixes; they live in commit messages, not changelogs.
- **No issue numbers.** Changelogs are for users, not for tracking.
- **No author attribution.** No `@username`, no `(thanks X)`. WP.org strips these anyway.
- **No marketing.** Do not write *"Brand-new amazing Pretty URL feature!"* — write *"Adds pretty URL support for Landing Page and Conversational Form share pages."*
- **Don't reveal security exploit details.** *"Hardens email attachment path resolution to keep notification attachments inside allowed paths"* — not *"Fixes a path-traversal vulnerability in attachment handling exploitable via crafted POST"*.

## Length

- One line per bullet, no hard wrap.
- The top entry for a release should fit in a screen — if you have more than ~25 bullets, you have either a minor release (not a patch) or you are listing things that don't belong in the changelog.

## Date discipline

- Use **today's date** at the time the version bump commit lands (not the date the fix was written).
- If the release date slips, update the date in the PR before merging — never ship a future date.
- For paired releases, both repos must show the same release date.
