# pr-reviewer criteria packs

Each pack is an independently-editable checklist owned by one detector. Rules
inside are derived from real autharif review comments in the WPManageNinja corpus —
nothing here is a generic best-practice list pulled from documentation.

## Pack → detector → autharif categories owned

| Pack file | Detector | Autharif categories it covers | File types loaded for |
|---|---|---|---|
| `a11y-criteria.md` | `a11y` | Mouse-only / ARIA stale / focus removed / aria-label gap / screen-reader hidden / keyboard-disabled drift / modal focus management | `.vue` `.jsx` `.tsx` `.scss` `.css` |
| `async-state-criteria.md` | `async-state` | Stale-response overwrites / cancel races / retry concurrent / progress double-count / remount re-analysis / not-persisted / total-never-updates | `.vue` `.jsx` `.tsx` `.js` `.ts` (only files with async surface) |
| `traceability-criteria.md` | `traceability` | Stub handlers / Phase-2 CTAs / hardcoded dummy data / bypassed config props / dead CSS rules / dropped filter context / CTA-label mismatch / broken render fallback / undefined-breaks-render | **all files** (always runs) |
| `rbac-alignment-criteria.md` | `rbac-alignment` | UI gate vs policy capability drift / public endpoint missing publication gate / dual-source capability checks / unvalidated redirect / dev-config-in-prod | `app/Http/Policies/*.php`, `app/Http/Controllers/*.php`, Vue files that gate by capability |
| `bc-regression-criteria.md` | `bc-regression` | Payload-key renames / default-value flips / response-shape drift / gateway-contract drift / aggregate semantic shift / column-constraint shrinks | **all files** (always runs) |
| `error-state-criteria.md` | `error-state` | Blank-on-error / network-as-domain-error / loading-flag-stuck / hidden failures / search-clear no-refresh / filters-invisible-when-collapsed / wrong-chip-removed / unconditional loader / hard-disabled blocks | `.vue` `.jsx` `.tsx` `.js` `.ts` |
| `perf-and-integrity-criteria.md` | `perf-and-integrity` | N+1 / unbounded queries / repeated transient writes / non-unique lookup updates / meta uniqueness / inverted ranges / non-atomic state changes / skipped data-integrity tests / string-vs-int data-type bugs | `.php` (Controllers, Services, Models, Views, Migrations) |

## Evidence corpus

The canonical evidence base lives at `pr-reviewer/references/test-corpus.tsv` —
30 representative headlines, 5 per detector, with the expected classification. The
classifier in `shared/scripts/audit-autharif.sh` is validated against this corpus
on every change.

The full 97-finding inline catalog used to derive these packs is at
`<fluent-player>/openspec/changes/audit-ai-review-feedback/evidence/inline-headlines.tsv`
in the project that landed this work. Future audits regenerate the catalog with
`audit-autharif.sh --since YYYY-MM-DD --out evidence/`.

## How to add a rule

1. **Pick the right pack.** Use the table above. If the rule doesn't fit any
   existing pack, prefer adding it to the closest neighbor over creating a new
   detector — six packs is the budget.

2. **Match the section structure.** Every rule has:
   - A `## Rule heading` (sentence-case, no period)
   - One paragraph stating the rule and default severity
   - `**Smell patterns:**` — bullet list of concrete code shapes
   - `**Required pattern:**` (optional) — a small code block showing the fix
   - `**Corpus evidence:**` — one or more bullet pointing to autharif headlines
     with PR# and file:line. Use `(local)` if the rule came from in-house
     experience without an autharif citation.

3. **Update the detector behavior section** at the bottom of the pack — add the
   grep/walk pattern the detector should use to find this rule.

4. **Add a test corpus row.** Update `test-corpus.tsv` with one representative
   headline that this rule should classify under. Re-run validation:

   ```bash
   bash /Volumes/Projects/Tools/agent-skills/shared/scripts/audit-autharif.sh --validate
   ```

   Must stay ≥80%.

5. **Add a classifier branch** in `shared/scripts/audit-autharif.sh` (the bash
   `classify_headline` function) — a `*pattern*` glob that catches the headline
   shape.

## How to project-customize without forking

Each pack has a `Project-specific extensions` section near the bottom with a slot:

```markdown
<!-- BEGIN project-specific rules -->
<!-- END project-specific rules -->
```

Append your team's rules between those markers. The detector loads them after the
base rules — your rules can reinforce or specialize, never replace, the base
checklist. If a project rule contradicts a base rule, the base wins (file a PR
upstream to fix the base instead).

## Severity discipline

Default severities per pack are conservative. Promote a rule from `Suggestion` →
`Medium` → `High` → `Blocking` only after the rule has fired correctly on a real
PR three times and the team agrees the impact warrants the gate. Burning
developers with `Blocking` on a rule they don't trust is how this skill becomes
ignored — and the whole multi-detector architecture relies on developers actually
reading the report.
