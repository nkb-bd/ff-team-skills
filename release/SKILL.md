---
name: release
description: >
  Cut a complete WordPress plugin release: bump the version in lockstep by
  invoking the `version-bump` skill (plugin-header Version, the in-code VERSION
  constant, readme.txt Stable tag), generate the changelog from EVERY
  user-facing commit since the last release TAG, build the distribution zip via
  the repo build script, and create the annotated release tag. Pre-flight
  consistency and safety checks fail loudly so a stale or partial release cannot
  silently ship. Supports paired free/pro plugins.
when_to_use: >
  When the user wants to cut or prep a FULL release of a WordPress plugin —
  "release X.Y.Z", "prep the release", "update the changelog", "build the
  release", "tag the release", "publish a new version". For a bare version-only
  bump ("bump the version", "bump to X.Y.Z", "set the version"), route to the
  `version-bump` skill instead — this skill invokes it for its lockstep bump.
  Also for SYNC mode — "sync the changelog", "update the changelog
  again", "new commits landed after the release commit, fold them in", "check
  if the changelog needs updating" — where the current unreleased version's
  changelog block already exists and just needs late commits folded in WITHOUT
  a version bump. Especially useful for the FluentForm free + pro pair (or
  FluentPlayer, FluentCRM, FluentCommunity) where the two plugin versions must
  move together.
context: fork
allowed-tools: Read Edit Write Bash(git *) Bash(grep *) Bash(rg *) Bash(gh *) Bash(sh *) Bash(npm *) Bash(node *)
effort: medium
---

# Release Bump

Single canonical entry point for "bump version + add changelog" on a WP plugin or a paired free/pro plugin pair. Designed to fail loudly on inconsistency rather than silently producing a half-bumped release.

**Two modes — pick before Step 0:**

- **Bump mode** (default): version is moving to a new number. Run Steps 0 → 7.
- **Sync mode** (`--sync`): the current version's changelog block already exists and is not yet tagged; only fold in user-facing commits that landed after it, with **no** version change. Jump straight to *Sync mode* (below), which reuses Step 3's classifier. Use this when the operator says "sync/update the changelog again" after more commits merged into the same unreleased version.

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
| Paired pro path | optional | `/Volumes/Projects/work/forms/wp-content/plugins/fluentformpro` (or auto-detect — `version-bump` handles pairing) |
| Changelog entries | optional | If omitted, derived from `git log` since the previous release commit, filtered by Step 3 rules |
| Release date | optional | If omitted, today's local date (`May 25, 2026` style — match the existing changelog format in this readme) |
| Branch name prefix | optional | If omitted, default `lukman/release-` (matches the GitHub org branch-naming rule that rejects `release/*` and `release-fix/*` at the org level — see Step 7 lesson) |

---

## Step 0 — Bump the version (delegated to `version-bump`)

The entire lockstep bump is owned by the **`version-bump`** skill: discovering
every version location (`Version:` header, `_VERSION` constant, `Stable tag:`),
validating the target (semver, forward-only, magnitude), auto-detecting the
paired sibling, working-tree hygiene, and editing all version locations across
the plugin (or both halves of a pair).

**Invoke `version-bump` first — before touching the changelog** — so it runs
against a clean tree. Pass it the target version and, for a pair, the sibling
path (or let it auto-detect). Its discovery/validation/paired-detection/hygiene
logic (its Steps 0–1) is the single source of truth; do not re-implement or
hand-edit the version strings here.

When it returns, all version locations are edited but uncommitted. If it **STOP**s
on a mismatch (locations disagree, sibling out of sync, dirty tree, downgrade,
long-lived branch), resolve that before continuing — the release does not
proceed on a failed bump.

**Sync mode does NOT bump** — it never calls `version-bump`. Jump straight to the
*Sync mode* section below.

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

## Step 3 — Derive changelog entries from every commit since the last TAG

The boundary is the **last release tag**, NOT the last release commit. Tags are
the durable release marker; keying off the bump commit silently drops anything
that landed after it. **Always enumerate `lastTag..HEAD` and confirm the count.**

```bash
# The last release tag (e.g. 6.2.4). Confirm it is the version you expect.
last_tag=$(git describe --tags --abbrev=0 2>/dev/null)
echo "Last release tag: ${last_tag:-<none — fall back to previous bump commit>}"

# Every commit since that tag — this is the full candidate set. Count it.
git log --oneline "${last_tag}..HEAD"
git rev-list --count "${last_tag}..HEAD"

# Objectively classify each: did it touch user-facing code or internal-only?
for sha in $(git rev-list "${last_tag}..HEAD"); do
  files=$(git show --stat --format="" --name-only "$sha")
  if echo "$files" | grep -qE '^(app/|resources/|boot/|fluentform\.php)'; then
    echo "USER  $(git log -1 --format=%s "$sha")"
  else
    echo "skip  $(git log -1 --format=%s "$sha")"
  fi
done
```

A commit that touches `app/`/`boot/` only via phpcs annotations, comments, or a
trivial copy/string tweak is still **internal** — open its diff and confirm the
change is user-visible behavior before keeping it. (The classifier flags such
commits as USER; the operator demotes them on inspection.)

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

## Sync mode — fold late commits into an unreleased changelog block (no bump)

Triggered by `--sync` or phrasings like *"sync the changelog"*, *"update the
changelog again"*, *"new commits landed after the release commit"*, *"check if
the changelog needs updating"*. This is **NOT** a bump. The current version's
changelog block already exists (committed, or sitting unstaged in the working
tree); user-facing commits have landed since it was written and must be folded
into that **same** block. No version location changes, no new heading.

**When sync applies (all must hold):**

1. All version locations already agree on the current version (grep the
   `Version:` header, the `_VERSION` constant, and `Stable tag:`) — there is
   nothing to bump, so `version-bump` is **not** invoked in sync mode.
2. A `= <current> (Date: …) =` changelog block already exists.
3. The current version is **NOT yet tagged**. `git tag --list "<current>" "v<current>"`
   must be empty. If it IS tagged, the version already shipped — new commits
   belong to the *next* version, so this is a real bump (run Step 0 —
   `version-bump` — instead of sync).

**Boundary (what counts as "late"):** take the later of

- the last commit that edited the changelog: `git log -1 --format=%H -- readme.txt`, and
- the version-bump / `RELEASE:` commit for the current version (`git log --oneline -S"<current>" -- <main>.php | head -1`).

If the changelog block is still uncommitted in the working tree, there is no
"commit after it" — instead scan `<last-readme-commit>..HEAD` and **de-dupe
against the bullets already present** in the block. The de-dupe step is the
whole game: never emit a line whose behavior is already described.

```bash
current=$(grep -n "^= [0-9].*(Date:" readme.txt | head -1 | sed -E 's/.*= ([0-9.]+) .*/\1/')
git tag --list "$current" "v$current"          # must be empty for sync
boundary=$(git log -1 --format=%H -- readme.txt)
git log --oneline "$boundary..HEAD"            # candidate late commits
```

**Then:** run the Step 3 classifier over `boundary..HEAD` (USER vs skip — drop
`CHORE:`/`DOCS:`/lockfile/build-asset commits), draft one user-facing line per
surviving commit in the existing block's voice, drop any already represented,
slot each under the correct subsection (`Feature` / `Improvement` / `Fix` /
`Security`) in the existing block, and present the delta to the operator before
editing. Insert in place — **do not** touch `Version:`, the `_VERSION` constant,
or `Stable tag:`.

**A clean sync that finds nothing is a valid, expected result** — report
"changelog already covers HEAD (N commits scanned, M skipped as internal)"
rather than inventing filler.

**Paired free/pro:** run sync independently in each repo — each half has its own
post-changelog commits and its own block. Do not copy one repo's lines into the
other.

**Safety net for sync:** from Step 7 run only the changelog-relevant checks
(block exists, ≥1 bullet, date sane). Skip every version-equality check — sync
deliberately leaves versions untouched. Still refuse if the working tree holds
unrelated unstaged changes this skill did not author.

---

## Step 4 — Write the changelog block

The version locations were already edited in Step 0 by `version-bump`. Here, only
the changelog changes:

1. Prepend the new `= X.Y.Z (Date: …) =` block (Step 2/3 output) to the `== Changelog ==` section of `readme.txt`.
2. Verify with `git diff --stat` that each plugin now shows exactly 2 files changed — the main `.php` (version, from Step 0) and `readme.txt` (version + changelog).

For a paired bump, confirm both halves landed on the same target version — re-run `version-bump`'s Step 3 consistency check (or `grep -n "<target>"`) across all six locations.

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

Run these checks before declaring the release done. Block on any **FAIL**, warn on **WARN**. The version-location rows below re-verify what `version-bump` already enforced in Step 0 — kept here as the final release gate; the changelog, paired-release, and build-artifact rows are release-specific.

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
Step 0 — invoke `version-bump` (discovery, validation, paired detection,
         hygiene, lockstep edit of every version location)
    ↓
Step 2/3 — derive changelog from git log since last TAG, filter, confirm with operator
    ↓
Step 4 — write the changelog block into readme.txt
    ↓
Step 7 — run safety checks (final gate; re-verifies the bump)
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
- [ ] Mirror the free release to its public GitHub repo + draft the GitHub Release (`public-mirror` skill)
- [ ] Upload pro distribution to license server
- [ ] Cross-link the two GitHub releases in their respective release notes

---

## Reference packs

- `references/changelog-style.md` — full style guide for changelog lines (verbs, voice, scope)
- `references/wpmn-org-rules.md` — WPManageNinja-org-specific rules (branch prefixes, PR template fields, paired-release sequencing)
- `references/pr-body-template.md` — template for the release-bump draft PR body
