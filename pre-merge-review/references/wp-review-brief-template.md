# WP Review Brief Template

This is the template `pre-merge-review` renders into when the repo is detected as a WordPress plugin. The rendered brief sits at the **top** of the report — above detector findings and pattern-pass results — so the reviewer can decide in 60 seconds whether to approve, ask, or block, without reading the diff.

## Detection signals

A repo is treated as a WordPress plugin when any of these is true (cheapest check first):

1. A `*.php` file at repo root contains a header line `Plugin Name:` in its top docblock (the canonical WP plugin signal).
2. `app/Http/Routes/api.php` exists (WPManageNinja-shaped plugin).
3. `readme.txt` at repo root starts with `=== ... ===` and has `Stable tag:` / `Tested up to:` headers.

If none match → skip the brief; render the report in the default (non-WP) shape.

## Render order in the report

When WP-detected, the report file structure becomes:

```
# Pre-Merge Review — <branch>
**Date:** YYYY-MM-DD | **Mode:** Full / Light | **PR type:** ... | **Plugin:** <name>

## Tier escalation              ← only when any finding has tier_escalating: true
## WP Review Brief              ← THE brief — see template below
## Summary                      ← detector + pattern-pass severity tally
## Inline findings              ← all detector findings
## Hooks diff                   ← when any hook was added/changed/removed
## What looks good
## Verification checklist
```

The brief is the primary review artifact. The detector findings come **after** — supplementary detail for reviewers who want to drill in.

## Brief template

Fill every line. Use `n/a` when a section doesn't apply rather than omitting it — reviewers learn what to expect.

```markdown
## WP Review Brief

### Surface area touched
| Surface | Count | Notes |
|---|---|---|
| Actions added                 | {{n}} | {{list or "—"}} |
| Actions changed               | {{n}} | {{list with old → new signature}} |
| Actions removed               | {{n}} | {{list — BREAKING if external dependents exist}} |
| Filters added                 | {{n}} | {{list or "—"}} |
| Filters changed               | {{n}} | {{list with old → new signature}} |
| Filters removed               | {{n}} | {{list — BREAKING if external dependents exist}} |
| DB schema changes             | yes/no | {{migration file paths}} |
| New capabilities              | {{n}} | {{capability slug list}} |
| REST routes added             | {{n}} | {{namespace + route list}} |
| REST routes changed           | {{n}} | {{method/URL/permission changes}} |
| Cron events                   | {{n}} | added: {{...}}  removed: {{...}} |
| Free/Pro boundary moved       | yes/no | {{which features moved which direction}} |
| Public PHP signatures changed | {{n}} | {{class::method list}} |
| Options / postmeta keys       | added: {{n}}  removed: {{n}} | {{key list}} |
| `readme.txt`                  | {{updated / not updated}} | Stable tag bumped? Changelog entry? Tested up to current WP? |
| `.pot` regenerated            | yes/no/n/a | {{matches strings in diff?}} |

### Security checklist (static scan of diff only)
Each row shows `<found / required>`. A `✓` only appears when found ≥ required.

| Check | Score |
|---|---|
| New `$_GET` / `$_POST` / `$_REQUEST` accesses sanitized + unslashed | {{found}}/{{required}} {{✓ or ✗}} |
| Output escaped at print site (`esc_html`, `esc_attr`, `esc_url`, `esc_js`) | {{found}}/{{required}} {{✓ or ✗}} |
| Nonces on every form / `admin-post` / AJAX / REST handler | {{found}}/{{required}} {{✓ or ✗}} |
| Capability checks (`current_user_can` / policy) on every data-modifying endpoint | {{found}}/{{required}} {{✓ or ✗}} |
| `$wpdb` queries with variables use `$wpdb->prepare()` | {{found}}/{{required}} {{✓ or ✗}} |
| `ABSPATH` guard on every new PHP file | {{found}}/{{required}} {{✓ or ✗}} |

### Compatibility
| Field | Value |
|---|---|
| Minimum WP version  | {{e.g. 6.4}} ({{unchanged / bumped from X}}) |
| Minimum PHP version | {{e.g. 7.4}} ({{unchanged / bumped from X}}) |
| Multisite           | {{tested / unaffected / n/a}} |
| Known integrations touched | {{e.g. WooCommerce order hooks, FluentCRM contacts}} |

### Lifecycle
| Hook | Behaviour |
|---|---|
| Activation   | {{adds N options / N cron events / N tables; or "no change"}} |
| Deactivation | {{N cron events unscheduled; or "no change"}} |
| Uninstall    | {{N options removed / N tables dropped; or "no change"}} |

### Look here first (ranked by risk)
The top 3–5 files where the actual risk lives. Order by descending risk. Each line is one sentence.

1. `path/to/file.php:line` — {{one-sentence why this is the riskiest spot}}
2. `path/to/other.php:line` — {{...}}
3. `path/to/third.php:line` — {{...}}
```

## Ranking "Look here first"

Score each changed file on these signals, sum, take the top 3–5:

| Signal | Weight |
|---|---|
| Touches a security-sensitive WP API (sanitize/escape/nonce/cap/`$wpdb`) | +5 per touch |
| Adds/changes/removes an action or filter | +4 per hook |
| Changes a REST `permission_callback` | +5 |
| First DB migration or destructive schema change | +5 |
| Moves the Free↔Pro boundary or touches a license-gating call site | +4 |
| Changes a public PHP method signature | +4 |
| Touches activation / deactivation / uninstall handler | +3 |
| Renames an option / postmeta key | +3 |
| New `wp_remote_*` outbound call with user-controlled URL | +5 |
| New `do_shortcode(...)` / `.html(...)` / `v-html` sink with non-static input | +5 |
| Plain bug-fix in a leaf function with full test coverage | +0 |

Ties broken by file size (smaller = more concentrated risk = ranked higher).

If no file scores above 0, omit the "Look here first" section entirely with `_No high-risk files in this diff — read the inline findings._` — don't pad it with low-risk filler.

## Tier-escalation callout

When any finding in the report has `tier_escalating: true` (see `detector-backwards-compatibility.md` for emission rules), the report **prepends** this block above the brief:

```markdown
## ⚠ Tier escalation

This PR currently classifies as **{{current tier}}** but the review found a non-additive hook-contract change. Recommended tier: **Breaking**.

Reasons:
- `{{hook-name}}` — {{removed / signature-shrunk}} ({{file:line}})
- ...

A Breaking-tier PR must include: deprecation notices, a changelog entry under "For developers", and (for `new-feature`) a post-merge `/plugin-audit` pass.
```

The human reviewer reads this first, decides whether to re-tier or argue, and the rest of the brief follows. No programmatic coupling with `new-feature` — the gate is the reviewer reading the callout.

## Hooks-diff block

When any hook was added, changed, or removed, render this block **after** the inline findings:

```markdown
## Hooks diff

### Actions

`{{hook_name}}` — **{{ADDED | CHANGED | REMOVED}}**
  before: `do_action( '{{name}}', {{args}} )`         {{when changed/removed}}
  after:  `do_action( '{{name}}', {{args}} )`         {{when added/changed}}
  Classification: **additive** / **non-additive (TIER-ESCALATING)**
  Impact: {{one sentence}}
  Action: {{one sentence — keep shim, note in changelog, etc.}}

### Filters
{{same shape}}
```

Classification rules:

| Change | Classification |
|---|---|
| Hook added (never existed before) | **additive** |
| Hook removed entirely | **non-additive — TIER-ESCALATING** |
| Hook renamed | **non-additive — TIER-ESCALATING** (treat as removed + added) |
| Arg appended at end | **additive** (existing hookers ignore extra arg) |
| Arg removed | **non-additive — TIER-ESCALATING** |
| Arg position reordered | **non-additive — TIER-ESCALATING** |
| Arg type changed (scalar → array, etc.) | **non-additive — TIER-ESCALATING** |
| Argument count documented in PHPDoc changed but real call unchanged | additive (docs catching up) |

If both an added and a removed line for the same hook appear in the diff with **different names**, treat as a rename — non-additive.

## Static checks to run before generating the brief

These run as part of Step 0 of `pre-merge-review`. Failures become entries in the report — `Blocking` or `High` depending on the check — that the user fixes before the report is surfaced.

| Tool | Invocation | Expected |
|---|---|---|
| WP Plugin Check (official) | `wp plugin check <slug>` (when `wp-cli` available) | Pass |
| PHPCS / WordPress-Extra | `phpcs --standard=WordPress-Extra --filter=GitModified` | No new errors in changed lines |
| PHPStan + WP stubs | `phpstan analyse --level=5 <changed php files>` (when configured) | No new errors |
| `wp-cli i18n make-pot` | `wp i18n make-pot . languages/<slug>.pot --dry-run` | Diff matches committed `.pot` if strings added |
| `readme.txt` parser | parse `readme.txt`; check `Stable tag:` matches plugin header `Version:` | Equal |

If a tool isn't installed in the environment, log `[pre-merge-review:tool-missing]` to stderr and skip — don't fail the run. Reviewers may run these manually.
