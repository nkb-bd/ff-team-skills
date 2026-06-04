---
name: release-bump
description: >
  Bump the version of a WordPress plugin (or a paired free/pro plugin pair) and
  add a changelog entry in lockstep. Handles plugin-header Version, the
  in-code VERSION constant, readme.txt Stable tag, and the changelog block.
  Performs pre-flight consistency and safety checks before editing so a stale
  or skewed source state cannot silently produce a bad release.
when_to_use: >
  When the user wants to cut a new release of a WordPress plugin —
  "bump to X.Y.Z", "release 6.2.4", "prep the release", "version bump",
  "update changelog", "publish a new version". Especially useful for the
  FluentForm free + pro pair (or FluentPlayer, FluentCRM, FluentCommunity)
  where the two plugin versions must move together.
context: fork
allowed-tools: Read Edit Write Bash(git *) Bash(grep *) Bash(rg *) Bash(gh *)
effort: medium
---

# Release Bump

Single canonical entry point for "bump version + add changelog" on a WP plugin or a paired free/pro plugin pair. Designed to fail loudly on inconsistency rather than silently producing a half-bumped release.

## Live context

- **Free plugin pwd:** !`pwd`
- **Free branch:** !`git rev-parse --abbrev-ref HEAD 2>/dev/null`
- **Free recent log:** !`git log --oneline -10 2>/dev/null`
- **Free unstaged:** !`git status --short 2>/dev/null | head -20`

---

## Inputs the operator must (or may) supply

| Input | Required? | Example |
|---|---|---|
| Target version | required | `6.2.4` |
| Paired pro path | optional | `/Volumes/Projects/work/forms/wp-content/plugins/fluentformpro` (or auto-detect — see Step 0c) |
| Changelog entries | optional | If omitted, derived from `git log` since the previous release commit, filtered by Step 3 rules |
| Release date | optional | If omitted, today's local date (`May 25, 2026` style — match the existing changelog format in this readme) |
| Branch name prefix | optional | If omitted, default `lukman/release-` (matches the GitHub org branch-naming rule that rejects `release/*` and `release-fix/*` at the org level — see Step 7 lesson) |

---

## Step 0 — Pre-flight discovery

### 0a. Identify all version locations

For each plugin root, find every place the version string lives:

```bash
# Plugin header in main plugin file
grep -n "^[[:space:]]*\(\*[[:space:]]*\)\?Version:" *.php

# In-code constants
grep -rn "FLUENTFORM_VERSION\|FLUENTFORMPRO_VERSION\|PLUGIN_VERSION\|_VERSION'\s*,\s*'" *.php

# readme.txt Stable tag
grep -n "^Stable tag:" readme.txt
```

Normally that yields 3 locations per plugin: `Version:` header line, the `define('XXX_VERSION', '...')` constant, and `Stable tag:` in `readme.txt`. **All three must agree on the current version before the bump runs.**

### 0b. Cross-plugin minimum version gates (when paired)

When bumping a free/pro pair, also identify any cross-version compatibility constants and version_compare gates. These usually do not need to be bumped per release, but if the new release breaks back-compat with an older pair-half, they must be bumped together.

```bash
# Free's hard pro requirement
grep -rn "FLUENTFORM_MINIMUM_PRO_VERSION\|MINIMUM_PRO_VERSION\|MINIMUM_CORE_VERSION" *.php

# Pro's hard free requirement (and version_compare gates)
grep -rn "FLUENTFORM_MINIMUM_CORE_VERSION\|version_compare.*FLUENTFORM" *.php
```

Surface every result so the operator can decide whether to bump the minimum-required constant. The default is **do not bump**.

### 0c. Detect the paired repo automatically

For WPManageNinja-style pairs, when the operator supplies only the free path, look for the pro alongside:

```bash
# Walk up to wp-content/plugins/ and look for known siblings.
plugins_dir="$(dirname "$PWD")"
case "$(basename "$PWD")" in
  fluentform)        sibling="$plugins_dir/fluentformpro" ;;
  fluentformpro)     sibling="$plugins_dir/fluentform" ;;
  fluent-crm)        sibling="$plugins_dir/fluent-crm-pro" ;;
  fluent-crm-pro)    sibling="$plugins_dir/fluent-crm" ;;
  fluent-player)     sibling="$plugins_dir/fluent-player-pro" ;;
  fluent-player-pro) sibling="$plugins_dir/fluent-player" ;;
esac

# If the sibling directory exists AND its current version matches the free's, treat as a pair.
```

If both directories exist and their current versions agree, run the bump in lockstep across both. If versions disagree, **STOP** and surface the mismatch — never bump only one half of a pair that was historically synced.

### 0d. Working-tree hygiene

```bash
git status --short    # must be empty (or only contain the files this skill will touch)
git rev-parse --abbrev-ref HEAD   # must NOT be master / main — bump goes on a release branch
```

Refuse to run when uncommitted changes exist that this skill did not author. Refuse to run when the current branch is the long-lived deployment branch (`master`, `main`, or `dev` unless the operator passes `--allow-direct`).

---

## Step 1 — Version validation

Before any file edit:

1. **Semver shape:** target must match `^\d+\.\d+\.\d+(-[a-z0-9.-]+)?$`. Reject `6.2`, `6.2.4.1`, `6.2.4 beta`, etc.
2. **Forward-only:** `version_compare($target, $current, '>')` must be true. Reject decrements unless the operator passes `--allow-downgrade`.
3. **No skip-bumps:** if the previous changelog entry is X.Y.Z and the target is X.Y.Z+2 (e.g. 6.2.3 → 6.2.5), warn but allow.
4. **Patch vs minor vs major sanity:** look at the staged changelog entries — if any line starts with `Adds` (new feature) or breaks a documented contract, suggest a minor or major bump instead of a patch. Operator can override.

---

## Step 2 — Locate the changelog block

```bash
# Find the line right after the changelog heading and the most-recent version entry.
grep -n "^== Changelog ==" readme.txt
grep -n "^= [0-9].*(Date:" readme.txt | head -3
```

Insert the new entry **immediately after** the `== Changelog ==` line (or above the most-recent `= X.Y.Z (Date: ...)` entry), preserving:

- The exact heading format used in the file (`= X.Y.Z (Date: Month DD, YYYY) =` is the FluentForm convention — confirm by reading the existing top entry).
- A blank line between the new block and the next-most-recent block.
- Bullet character (`-` is the FluentForm convention — confirm).

---

## Step 3 — Derive changelog entries from git log

When the operator does not supply entries manually, derive them:

```bash
# Find the commit where the current version was bumped — its parent is the last release point.
last_bump_sha=$(git log --grep="Bump\|RELEASE:" --grep="changelog" -i --all-match --format=%H -n 1)
# Fallback: search for the previous version string in readme.txt history.
git log --oneline "${last_bump_sha}..HEAD"
```

Filter out commits that should never go into a changelog:

- `CHORE:`, `DOCS:`, `Update readme`, build-asset bumps (`Update: remove from build assets`, `Add: build assets`)
- Anything that only touched `.gitignore`, `.claude/`, `.mcp.json`, `package-lock.json`, `composer.lock`, `pnpm-lock.yaml`, `mix-manifest.json`, `builds/` (compiled output)
- Anything before the last `= X.Y.Z (Date: …) =` line in the existing changelog (those are already shipped)

For the surviving commits, generate one user-facing changelog line each. Style guide (per existing FF changelog):

- Start with `Adds`, `Improves`, `Fixes`, `Removes`, `Hardens`, `Updates`, `Tightens` (no `FIX:` / `IMPROVE:` SCREAMING PREFIX).
- Describe **user-visible behavior**, not internals (e.g. write *"Fixes conversational form pretty URLs rendering inside the landing-page wrapper"* not *"FIX: Render conversational pretty URLs standalone"*).
- One line per commit; merge two commits if they fix two facets of the same bug.
- Hide developer-only changes (visibility widening, refactor) unless they have a user-visible upstream effect — in which case mention only the effect.
- Skip anything that doesn't ship to end users.

Present the derived list back to the operator for confirmation **before** writing it into `readme.txt`.

---

## Step 4 — Edit in lockstep

For each plugin in the pair:

1. Update **all** of:
   - `Version:` header in the main `.php` file
   - The in-code `_VERSION` constant
   - `Stable tag:` in `readme.txt`
2. Prepend the new changelog block to the `== Changelog ==` section of `readme.txt`.
3. Verify with `git diff --stat` that each plugin touched exactly 2 files (main `.php` + `readme.txt`).

For the paired bump, both plugins must end up on the same target version. After edit, re-run Step 0a and confirm all six locations (3 per plugin) now read the new version.

---

## Step 5 — Commit

One commit per plugin, with this format:

```
RELEASE: 6.2.4 — version bump and changelog

Patch release covering:
- <one-line per major changelog bullet>

(Paired with <sibling-repo> 6.2.4 — must release together.)
```

Do **not** combine the version bump and the actual fix commits into one — they live separately so reviewers can audit the bump itself.

---

## Step 6 — Branch + push + PR

Create a release branch in each repo. **WPManageNinja org branch-naming rule:** branch names starting with `release/`, `release-fix/`, `hotfix/`, or any other reserved prefix are rejected with `Internal Server Error` from the GitHub push endpoint. Use a user-prefixed branch (`lukman/release-X.Y.Z`, `<gh-handle>/release-X.Y.Z`) instead.

```bash
git checkout -b lukman/release-X.Y.Z
git push -u origin lukman/release-X.Y.Z
gh pr create --draft --base dev --title "RELEASE: X.Y.Z — version bump and changelog" --body "<body>"
```

PR body template (per `references/pr-body-template.md`).

For paired releases, link the two PRs to each other in the body so reviewers can navigate.

---

## Step 7 — Necessary checks (the safety net)

Run these checks before declaring the bump done. Block on any **FAIL**, warn on **WARN**.

| Check | Severity | How to verify |
|---|---|---|
| All three version locations match the target | **FAIL** | `grep -n "<target>" *.php readme.txt` returns ≥ 3 lines |
| Target version > current version (semver) | **FAIL** | `version_compare` |
| readme.txt `Stable tag:` matches plugin-header `Version:` | **FAIL** | string equality after edits |
| Changelog entry for the new version exists | **FAIL** | `grep "^= X.Y.Z (Date" readme.txt` returns 1 line |
| Changelog block has at least one bullet | **FAIL** | block between this version and the next has ≥ 1 `- ` line |
| `Tested up to:` is current WP version | WARN | compare with `https://wordpress.org/download/releases/` (skip if offline) |
| Cross-plugin minimum-version constants still satisfied | **FAIL** | if free 6.2.4 + pro X.Y.Z, ensure `version_compare(6.2.4, FLUENTFORM_MINIMUM_PRO_VERSION, '>=')` and the inverse |
| Paired-release sibling is on the same target version | **FAIL** | same `grep -n "<target>"` in the sibling repo |
| Paired-release call sites use runtime guards (`is_callable`, `class_exists`, `has_action`) when the call depends on a newly-exposed surface | WARN | grep the pro PR for any free-namespace call introduced in this release; verify a guard precedes it. (Cross-link with the `cross-plugin-coordination` skill and the `detector-backwards-compatibility.md` "Cross-plugin paired-release contract widening" rule.) |
| No release-prefix branch name (`release/*`, `release-fix/*`, `hotfix/*`) | WARN | branch starts with a personal handle |
| Working tree clean (no untracked / unstaged files outside what this skill edited) | **FAIL** | `git status --porcelain \| grep -v "^[MA] \(<expected-paths>\)"` |
| Date in changelog matches today (or matches the operator-supplied date) | WARN | `grep "^= X.Y.Z (Date: $TODAY" readme.txt` |
| Build artifacts not staged | **FAIL** | no `builds/`, no `assets/js/*.js`, no `composer.lock` diff in the commit |

If any **FAIL** trips, stop and report. Do not push.

---

## Skill workflow

```
read user request → derive target version + scope
    ↓
Step 0 — discover all version locations + paired sibling
    ↓
Step 0d — abort if working tree dirty / on master
    ↓
Step 1 — validate target version (semver, forward-only, magnitude vs changelog)
    ↓
Step 2/3 — derive changelog from git log, filter, present to operator for confirmation
    ↓
Step 4 — edit all version locations in lockstep
    ↓
Step 7 — run safety checks
    ↓
Step 5/6 — commit, branch, push, draft PR (paired if applicable)
    ↓
Surface PR links and the post-merge release-tagging checklist
```

## Post-merge release-tagging checklist (after PRs land)

This skill does **not** tag or publish — that is a separate operator action. But it should print this checklist:

- [ ] Merge both PRs to `dev` (paired)
- [ ] Promote `dev` → `master` per project release flow
- [ ] Tag `vX.Y.Z` on `master` in both repos
- [ ] Build the distribution zips (if applicable)
- [ ] Update WordPress.org SVN trunk (free plugin only)
- [ ] Upload pro distribution to license server
- [ ] Cross-link the two GitHub releases in their respective release notes

---

## Reference packs

- `references/changelog-style.md` — full style guide for changelog lines (verbs, voice, scope)
- `references/wpmn-org-rules.md` — WPManageNinja-org-specific rules (branch prefixes, PR template fields, paired-release sequencing)
- `references/pr-body-template.md` — template for the release-bump draft PR body
