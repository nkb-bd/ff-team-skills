---
name: version-bump
description: >
  Move a WordPress plugin's version number in lockstep across every place it
  lives — the plugin-header `Version:` line, the in-code `_VERSION` constant,
  and `readme.txt`'s `Stable tag:` — for a single plugin or a paired free/pro
  pair. Validates semver shape and forward-only direction, auto-detects the
  paired sibling, and fails loudly on any location that disagrees so a
  half-bumped version can never ship. Does NOT write the changelog, commit,
  build a zip, or tag — those belong to the `release` skill, which invokes this
  skill for its bump step.
when_to_use: >
  When the user wants ONLY the version number moved — "bump the version",
  "bump to X.Y.Z", "set the version to X.Y.Z", "move the version number",
  "sync the version across the header/constant/readme". Use this instead of
  `release` when there is no changelog, commit, build, or tag intent. A full
  release ("release X.Y.Z", "cut/prep the release", "build the release", "tag
  it", "update the changelog") routes to `release`, which calls this skill for
  its lockstep bump.
context: fork
allowed-tools: Read Edit Write Bash(git *) Bash(grep *) Bash(rg *)
effort: low
---

# Version Bump

Single-purpose skill: move the version number, nothing else. Every version
location must agree before and after the bump — the whole point is to fail loud
rather than silently ship a half-bumped release. No changelog, no commit, no
build, no tag; if the user wants those, hand back to `release`.

## Live context

- **pwd:** !`pwd`
- **Branch:** !`git rev-parse --abbrev-ref HEAD 2>/dev/null`
- **Unstaged:** !`git status --short 2>/dev/null | head -20`

## Inputs

| Input | Required? | Example |
|---|---|---|
| Target version | required | `1.3.1` |
| Paired sibling path | optional | auto-detected (Step 0c) or supplied explicitly |
| `--allow-downgrade` | optional | permit a decrement (default: refuse) |
| `--allow-direct` | optional | permit running on a long-lived branch (`master`/`main`/`dev`) |

---

## Step 0 — Discover every version location

### 0a. Locate the version string in each plugin root

```bash
# Plugin header in the main plugin file
grep -n "^[[:space:]]*\(\*[[:space:]]*\)\?Version:" *.php

# In-code constant — any *_VERSION define (skip DB / MIN constants, handled in 0b)
grep -rn "define(\s*'[A-Z_]*_VERSION'\s*,\s*'[0-9]" *.php

# readme.txt Stable tag
grep -n "^Stable tag:" readme.txt
```

Normally 3 locations per plugin: the `Version:` header, the plugin's own
`_VERSION` constant, and `Stable tag:`. **All three must already agree on the
current version before the bump runs** — if they disagree, STOP and surface the
mismatch; a disagreeing set means a prior bump was left half-done.

Do **not** touch DB-schema constants (`*_DB_VERSION`) or minimum-dependency
constants (`*_MIN_*_VERSION`, `*_MINIMUM_*_VERSION`) — those track different
things and move on their own cadence (see 0b).

### 0b. Cross-dependency version gates (informational)

```bash
grep -rn "MINIMUM_.*_VERSION\|MIN_.*_VERSION\|version_compare" *.php
```

Surface any minimum-required-dependency constants so the operator can decide
whether this bump also needs one moved (e.g. the release breaks back-compat with
an older pair-half). **Default: do not bump them.**

### 0c. Auto-detect the paired sibling

```bash
plugins_dir="$(dirname "$PWD")"
case "$(basename "$PWD")" in
  fluentform)         sibling="$plugins_dir/fluentformpro" ;;
  fluentformpro)      sibling="$plugins_dir/fluentform" ;;
  fluent-crm)         sibling="$plugins_dir/fluent-crm-pro" ;;
  fluent-crm-pro)     sibling="$plugins_dir/fluent-crm" ;;
  fluent-player)      sibling="$plugins_dir/fluent-player-pro" ;;
  fluent-player-pro)  sibling="$plugins_dir/fluent-player" ;;
  fluent-community)   sibling="$plugins_dir/fluent-community-pro" ;;
esac
```

If the sibling exists AND its current version matches, bump both in lockstep. If
the versions disagree, **STOP** — never bump only one half of a historically
synced pair. If the pair is intentionally decoupled (versions diverged by
design), the operator must pass the sibling explicitly or bump each separately.

### 0d. Working-tree hygiene

```bash
git status --short                 # empty, or only files this skill will touch
git rev-parse --abbrev-ref HEAD    # not master/main/dev unless --allow-direct
```

Refuse to run when uncommitted changes this skill did not author exist, or when
on a long-lived deployment branch without `--allow-direct`.

---

## Step 1 — Validate the target version

1. **Semver shape:** `^\d+\.\d+\.\d+(-[a-z0-9.-]+)?$`. Reject `1.3`, `1.3.1.1`, `1.3.1 beta`.
2. **Forward-only:** `version_compare(target, current, '>')` must hold. Refuse a decrement unless `--allow-downgrade`.
3. **No silent skip:** if current is X.Y.Z and target is X.Y.Z+2, warn but allow.
4. **Magnitude sanity:** eyeball the commits since the last tag (`git log --oneline $(git describe --tags --abbrev=0 2>/dev/null)..HEAD`). If any add a feature or break a contract, suggest minor/major over a patch. Operator can override.

---

## Step 2 — Edit in lockstep

For each plugin in the pair, update **all** of:

- `Version:` header in the main `.php`
- the plugin's own `_VERSION` constant
- `Stable tag:` in `readme.txt`

Leave `*_DB_VERSION` and `*_MIN_*_VERSION` untouched unless 0b flagged a needed
change and the operator approved it.

Verify each plugin's diff touches only the version lines:

```bash
git diff -- *.php readme.txt
```

---

## Step 3 — Consistency checks (fail loud)

| Check | Severity | How |
|---|---|---|
| All version locations now equal the target | **FAIL** | `grep -n "<target>" *.php readme.txt` shows every location |
| No location still reads the old version | **FAIL** | old string absent from `Version:` / `_VERSION` / `Stable tag:` |
| `Stable tag:` equals the header `Version:` | **FAIL** | string equality |
| Target > current (semver) | **FAIL** | `version_compare` |
| Paired sibling on the same target | **FAIL** | same grep in the sibling |
| DB / min-dependency constants unchanged (unless 0b-approved) | WARN | diff shows no `_DB_VERSION` / `_MIN_*` change |

Any **FAIL** → stop and report; leave the working tree for the operator to inspect.

---

## Handoff

This skill stops at edited-but-uncommitted version locations. It does **not**:

- write or touch the changelog,
- commit, branch, push, or open a PR,
- build a distribution zip,
- create or push a tag.

If the user wants any of those, that is the **`release`** skill — which invokes
this skill for the lockstep bump, then layers the changelog, commit, PR, build,
and tag on top.
