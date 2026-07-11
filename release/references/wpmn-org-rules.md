# WPManageNinja Org Rules

Org-level constraints that have caused release-bump pain in the past.

## Branch naming

GitHub at the WPManageNinja org rejects pushes to branch names with these prefixes:

- `release/*`
- `release-fix/*`
- `hotfix/*`
- `feature/*` (sometimes — observed inconsistently)

The rejection appears as **`Internal Server Error`** from the push endpoint with no useful explanation. There is no public-facing branch-protection or ruleset that surfaces this; it appears to be an org-level "naming policy" check.

**Always use a user-prefixed branch**: `<gh-handle>/release-X.Y.Z`, e.g. `lukman/release-6.2.4`. This succeeds reliably.

If the operator insists on `release-fix/X.Y.Z` locally, push with a refspec mapping to the user-prefixed remote name:

```
git push -u origin release-fix/6.2.4:lukman/release-6.2.4
```

## Paired-release pairing

When the plugin is half of a free/pro pair (FluentForm + Pro, FluentCRM + Pro, FluentPlayer + Pro, FluentCommunity + Pro), the two halves must be released **in lockstep**:

- Same version number on both halves of the pair.
- Same release date.
- Both PRs go to `dev` first, then `dev` → `master` happens in one move per repo.
- PR descriptions cross-link to each other.
- Tagging happens on both repos in the same release window.

## Cross-plugin guard rule

When a release bumps a free plugin and that bump exposes a new public surface that the pro half calls, the pro PR **must** include a runtime guard (`is_callable`, `class_exists`, `has_action`, `version_compare`) so that sites updating only one half do not crash. `Requires X >= Y` in `readme.txt` is not a runtime guard — it only affects the next-update prompt, not the current request lifecycle.

See `~/.claude/skills/pre-merge-review/references/detector-backwards-compatibility.md` → "Cross-plugin paired-release contract widening (version-skew fatal)" for the full rule.

## PR conventions

- Title prefix: `RELEASE:` for the bump PR itself, `FIX:` / `IMPROVE:` / `FEAT:` / `SECURITY:` / `HARDEN:` / `REFACTOR:` / `DOCS:` / `CHORE:` for content PRs.
- All caps prefixes, colon, single space.
- Always open as draft (`--draft`); never as a regular PR. Mark Ready-for-review manually when verified locally.
- Body must list paired-PR link when applicable.
- Body must list test paths the reviewer should hit manually for any user-visible change.

## Build assets

The free plugin's `builds/` directory and the pro plugin's `public/` compiled assets MUST be rebuilt before the release zip is published, but the **release-bump commit itself** must not include rebuilt assets — those are committed separately (often after the bump merges to `dev`) so the diff stays reviewable.

If `git diff --stat` on the bump branch shows anything outside the main `.php` file and `readme.txt`, that's a smell — investigate before pushing.

## Tagged-release flow

Tags happen on `master`, not `dev`:

1. Bump PR merges to `dev`.
2. Sibling-pair bump PR merges to `dev`.
3. Once both `dev` branches are green, promote `dev` → `master` in each repo (PR or fast-forward, per the repo's flow).
4. Tag `vX.Y.Z` on `master` in each repo.
5. Push tags.
6. The release-bump skill does **not** automate tagging — that's a deliberate operator action.
