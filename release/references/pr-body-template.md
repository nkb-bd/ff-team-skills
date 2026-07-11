# Release-Bump PR Body Template

```markdown
## Summary

<Patch | Minor | Major> release <X.Y.Z>. Bumps `Version:` header, `<PLUGIN>_VERSION`, and `readme.txt` Stable tag from <X.Y.Z-1> → <X.Y.Z>. Adds changelog entry covering post-<X.Y.Z-1> fixes.

## Changelog

<one bullet per user-visible change — same content as the readme.txt entry>

## Paired with

`<org>/<sibling-repo>` <X.Y.Z> — must release together so the <feature-name> fix lands as a complete pair.

Sibling PR: #<sibling-pr-number>

## What's preserved

- <classic / non-affected paths that still behave the same>
- <gates / toggles that still gate the same things>

## How to test

1. <manual test path 1>
2. <manual test path 2>
3. <manual test path 3>
4. <regression check for the un-affected branch>

## Version-skew safety

<short statement on what happens if a site updates only one half of the pair — e.g. "Pro is guarded by is_callable; old-free + new-pro falls through to the pre-fix behavior. No fatal in either update order.">
```

## Notes for the skill

- Do not fill in marketing copy in the Summary section.
- "Paired with" section is omitted for non-paired plugins.
- "Version-skew safety" is omitted for non-paired plugins or when the bump introduces no new cross-plugin surface.
- Never add a Claude attribution footer (`🤖 Generated with [Claude Code]`) or `Co-Authored-By: Claude` trailer.
