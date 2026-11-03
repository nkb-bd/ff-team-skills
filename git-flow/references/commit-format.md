# Commit format reference

## Prefix picker

| Prefix | Use for |
|---|---|
| `ADD:` | new feature, option, hook, endpoint, file |
| `FIX:` | bug fix — something was wrong and now is not |
| `UPDATE:` | change to existing behaviour, a dependency, or user-facing copy |
| `IMPROVE:` | UX or performance enhancement with no behaviour change |
| `REFACTOR:` | internal restructuring, no behaviour change |
| `REMOVE:` | deletion of a feature, file, or dependency |
| `SECURITY:` | hardening or a vulnerability fix |
| `DOCS:` | documentation only |
| `CHORE:` | tooling, build, config |
| `RELEASE:` | version bump |
| `HOTFIX:` | urgent patch on top of a release |

Ambiguous cases:

- Bug fix that also changes copy → `FIX:` (the fix is the point).
- Refactor that happens to fix a latent bug → two commits.
- New hook added so a Pro addon can extend core → `ADD:`.
- Tightening a capability check that was too loose → `SECURITY:`, not `FIX:`.

## Body

Only when the *why* is not obvious from the subject. State the constraint, the rejected alternative, or the non-obvious consequence. Wrap at ~72.

```
SECURITY: Bind instant carts to the session that created them

The instant-checkout cart hash travels in the shopper's address bar, so
it reaches browser history, referrers and access logs. Anyone replaying
it could read the cart. Binding to the session makes a leaked hash inert.

Fixes: #1234
```

## Never in a commit message

- `Co-Authored-By:` any Claude/Anthropic identity
- `🤖 Generated with [Claude Code]`
- `PR:` trailer lines
- Invented ticket numbers
