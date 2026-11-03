---
name: public-mirror
description: >
  Publish a shipped free-plugin release to its public GitHub mirror as ONE
  commit (PHP + resources/ source + compiled assets), tag it v<version>, and
  draft a GitHub Release from the changelog. Covers Fluent Forms
  (fluentform/fluentform) and Fluent Player (WPManageNinja/fluent-player).
  Stages first, commits on OK, never pushes or publishes without explicit
  per-action consent.
when_to_use: >
  After a free release is live on wordpress.org — "update the public repo",
  "mirror the release", "push the release to the public GitHub", "sync the
  public mirror", "draft the GitHub release". Also to backfill versions the
  mirror is missing. Not for dev-repo tagging or the wp.org SVN deploy.
allowed-tools: Read Bash(git *) Bash(gh *) Bash(svn *) Bash(diff *) Bash(/Volumes/Projects/Release/public-facing-repos/sync-mirror.sh *)
---

# Public mirror release

Mirrors live in `/Volumes/Projects/Release/public-facing-repos/`; the engine is `sync-mirror.sh` there.

| Plugin arg | Dev repo | Mirror dir → remote (branch) |
|---|---|---|
| `fluentform` | `…/plugins/fluentform` (fluentform-dev) | `fluentform` → fluentform/fluentform (`main`) |
| `fluent-player` | `…/plugins/fluent-player` (fluent-player-dev) | `fluent-player-public` → WPManageNinja/fluent-player (`master`) |

Convention per release: one commit `RELEASE: v<version>`, body = that version's `readme.txt` changelog
block, annotated tag `v<version>` (message = tag name). Ignore the stale clone at
`/Volumes/Projects/Release/fluent-player-public`.

## 1. Find what to mirror

- `git -C <mirror> fetch origin --tags` and confirm the mirror is on its branch, level with origin, clean.
- Released versions = wp.org SVN tags: `svn ls https://plugins.svn.wordpress.org/<slug>/tags/`
  (slugs: `fluentform`, `fluent-player`). Missing from the mirror = those without a `v<version>` tag there.
  Several missing → mirror them oldest first, one commit each.

## 2. Pin each version to the dev ref that actually shipped

Dev tags are inconsistent (`v1.2.0`, `1.3.0`, some untagged), so never trust a tag name alone. Export the
wp.org tag and diff PHP against the candidate ref; the right ref has **zero** differing files:

```bash
svn export -q https://plugins.svn.wordpress.org/<slug>/tags/<version> $TMP/svn
git -C <dev> archive <ref> app boot config database <main>.php readme.txt | tar -x -C $TMP/ref
diff -rq $TMP/ref $TMP/svn -x assets -x vendor -x resources -x language | grep -v "^Only in $TMP/svn"
```

No tag matches → search `git log --all -S'= <version> (Date' -- readme.txt` for candidates and diff each.

## 3. Stage, review, commit

```bash
./sync-mirror.sh <plugin> <ref>          # clean export → npm run production → scoped rsync → stage
./sync-mirror.sh <plugin> commit         # after the user reviewed: commit + tag v<version>
```

Stage only, then STOP and let the user review (GitHub Desktop: add the mirror dir, not the stale clone).
For a multi-version backfill the user may approve `--commit` on the older ones so they stack; the newest
still stops staged. Before reporting, check `git diff --cached --name-only` holds no `.map`, `CLAUDE.md`,
`openspec/`, `tests/`, or Fluent Player `resources/milestones|progression/`.

## 4. Push — explicit OK only

```bash
git -C <mirror> push origin <branch> --follow-tags
```

## 5. Draft the GitHub Release — after the tag is on origin

```bash
gh release create v<version> --repo <remote> --draft --verify-tag \
  --title "<Plugin name> <version>" --notes-file <notes.md>
```

`notes.md` = the changelog block, then a footer linking the wp.org plugin page
(`https://wordpress.org/plugins/<slug>/`) and the docs. Always `--draft`; the user publishes.
Backfilled versions get drafts too, oldest first so the newest ends up as Latest.

## Guardrails

- Never push, publish a release, or move/delete an existing tag without explicit per-action consent.
- `sync-mirror.sh` refuses a dirty mirror and a version already tagged; never work around either — find out why.
- Never hand-copy files into a mirror; untracked leftovers get force-added. Run `clean-mirror.sh` (Fluent Forms) if unsure.
- New plugin → add a `case` block to `sync-mirror.sh` (dev dir, mirror dir, main file, PUBLIC paths,
  excludes, runtime manifest) rather than special-casing here.
