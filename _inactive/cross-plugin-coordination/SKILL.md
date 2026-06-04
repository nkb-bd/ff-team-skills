---
name: cross-plugin-coordination
description: >
  Workflow for changing the contract between a free WordPress plugin and its pro addon in
  lockstep (FluentPlayer ↔ Pro, FluentForm ↔ Pro). Covers contract-surface inventory, impact
  search via grep + code-review-graph, backwards-compat vs breaking decisions, paired PR
  authoring, joint validation, and release-order coordination. Use when changing a hook,
  filter, policy, REST route, asset handle, or service that pro consumes from free.
when_to_use: >
  Free PR will change a hook name, filter signature, policy class, REST namespace, asset
  handle, or any other surface pro depends on. Pro needs to consume a new free hook
  introduced in an upcoming release. Investigating "pro broken after free upgrade" bugs
  retrospectively to identify the missed coordination.
---

# cross-plugin-coordination

Free and pro ship as separate plugins on separate release schedules, but they share a runtime contract. When that contract changes, the two PRs must move in lockstep or one of three failure modes happens:

1. **Free releases first with a breaking change** → users who haven't updated pro see broken features
2. **Pro releases first depending on new free behavior** → users on old free see broken pro
3. **Both released the same week but uncoordinated** → users on old free see broken pro; users on new free + old pro see different broken things

This skill is the workflow to avoid all three.

> Pair with `pro-addon-development` — that skill captures the patterns; this one captures the change-management process. They cite the same contract surface.

## When NOT to use

- Free-only change with no pro consumption (e.g. a free-only UI tweak). Skip the whole skill.
- Pro-only change with no free hook/contract touched. Skip.
- A bug fix that doesn't change any signature, just behavior inside an existing signature. Document in the changelog, but no coordination overhead.

If you're unsure whether your change touches the contract, run **Step 1** below — that IS the check.

## Step 1: Inventory the contract surface

Before writing any code, enumerate what pro consumes from free. Use the code-review-graph if both repos are indexed (`code-review-graph repos` should show both); fall back to grep otherwise.

**Surface categories to enumerate:**

| Category | What pro consumes | How to find usage in pro |
|----------|-------------------|---------------------------|
| Hooks (actions/filters) | `<plugin>/...` hook names | `rg -n "(add_filter\|add_action\|addFilter\|addAction).*<plugin>/" <pro>/app <pro>/boot` (WPFluent uses both bare `add_filter` and `$app->addFilter` styles) |
| Policy classes | `<Free>\App\Http\Policies\<X>` | `grep -rn "use <Free>\\\\App\\\\Http\\\\Policies" <pro>/` |
| Model classes | `<Free>\App\Models\<X>` | `grep -rn "use <Free>\\\\App\\\\Models" <pro>/` |
| Service classes | `<Free>\App\Services\<X>` | `grep -rn "use <Free>\\\\App\\\\Services" <pro>/` |
| REST routes | `/<plugin>/v1/...` | `grep -rn "fluent_player/v1\|<rest-namespace>" <pro>/` |
| Asset handles | `<plugin>-frontend`, `<plugin>-playlist`, etc. | `grep -rn "wp_enqueue_script.*'<handle>'" <pro>/` |
| Constants | `<PLUGIN>_VERSION`, `<PLUGIN>_DIR_PATH` | `grep -rn "<PLUGIN>_VERSION\|<PLUGIN>_DIR_PATH" <pro>/` |

If `code-review-graph` is wired and both repos registered (multi-repo registry, `code-review-graph repos`), use:
- `cross_repo_search_tool` with the symbol name to find usages across both
- `query_graph_tool` pattern="callers_of" or "importers_of" on the changing entity

## Step 2: Decide the change strategy

Three options, in order of preference:

### A. Additive (no contract change)

Best case — add the new thing without changing the old. Examples:
- Add a new filter hook; old filter unchanged
- Add a new method on a service class; existing methods unchanged
- Add a new REST route; existing routes unchanged

No coordination needed. Free ships first, pro consumes when ready, mismatched versions still work.

### B. Backwards-compatible (deprecate, keep both)

When you must change behavior but can keep the old surface alive:
- Rename a filter but `apply_filters` BOTH names for one major version
- Add a new method signature with the old as a thin wrapper
- New REST route mirrors old, both registered

Pro can migrate over multiple releases. Mark deprecations clearly in the changelog. Pick a deprecation horizon (typically 2 major versions).

### C. Breaking (lockstep required)

When neither A nor B is feasible (e.g. security fix that can't preserve old behavior, fundamental rename, restructured signature):
- Free version bumps MAJOR
- Pro PR ready in the same release window
- Both ship within hours of each other
- Changelog calls out the break loudly: "**BREAKING:** Pro <X.Y.Z>+ required for this release"

Prefer A → B → C. Most "I have to break this" feelings are solvable with B if you think for 10 minutes.

## Step 3: Author paired PRs

One PR in each repo. Cross-reference them.

**Free PR (the contract source):**
- Changelog entry under **Hooks added** / **Hooks deprecated** / **BREAKING** (per strategy above)
- Code change is minimal — just the new/changed surface
- Inline comment at every new/changed `apply_filters` / `do_action` / class signature naming the consumer ("Consumed by `<pro>` since vX.Y.Z" — helps future maintainers understand why the surface exists)
- PR description references the pro PR: `Pairs with <org>/<pro-repo>#<n>`

**Pro PR (the consumer update):**
- Adopts the new surface (or migrates off the old)
- PR description references the free PR and the minimum-required free version
- If strategy is C (breaking), bump pro's MAJOR
- If strategy is B (backcompat), pro can stay on existing major; document the migration completion in the next major

Both PRs in DRAFT until paired and reviewed together.

## Step 4: Joint validation

Don't merge either PR alone. Validation steps:

1. **Local install:** check out free's PR branch + pro's PR branch on the same WordPress site. Activate both.
2. **Exercise the contract surface:** invoke the feature(s) that depend on the changed surface. Verify:
   - No PHP errors in `wp-content/debug.log`
   - No JS errors in browser console
   - Feature behaves as designed
3. **Test the backcompat path (if B strategy):** activate the new free with the OLD pro. Confirm graceful degradation (no fatals, deprecated-but-working behavior).
4. **Test the upgrade path:** install old free + old pro, then upgrade both. Confirm no data loss, no orphan transients, no broken license state.

If any step fails, fix in the appropriate PR and re-run from step 1.

## Step 5: Release coordination

**For strategy A (additive):**
- Free can release whenever. Pro PR can sit until pro's next release. No deadline pressure.

**For strategy B (backwards-compat):**
- Free releases first. Pro releases in the same week or next sprint. No same-day pressure.
- Pro's changelog notes: "Deprecates use of `<old>` (still supported until pro vX.0.0). Migrate to `<new>`."

**For strategy C (breaking):**
- Free release MUST be paired with a pro release. Free's tag goes up minutes before pro's tag.
- Free's update-server release notice should say: "Requires <pro> vX.Y.Z+ if using <pro>."
- Pro's release notice: "Requires <free> vX.Y.Z+."
- Post-release: monitor support channels for "pro features broken" reports — most will be users who updated free but not pro yet.

**Version sync rule:** for breaking changes, free and pro should match `X.Y` (e.g. free 1.5.0 + pro 1.5.0). Patch versions can drift. Major changes always bump together.

## Common failure modes

| Failure | Root cause | Prevention |
|---------|-----------|------------|
| Pro filter handler stops firing after free update | Free renamed the hook without a backcompat alias | Strategy B; alias the old name for one major |
| Pro 500s on REST call after free update | Free removed/renamed a Policy class pro instantiates | Step 1's policy enumeration catches this; never delete Policies without strategy C |
| Pro Vue components render empty after free update | Free changed an asset handle pro depends on | Step 1's asset-handle enumeration catches this |
| Free's hook fires but pro's handler doesn't apply | Hook signature changed (arg count, types) without changelog mention | Inline comment on the `apply_filters` line referencing the consumer; CI test that exercises both plugins |
| Users see "fluent-player-pro version mismatch" warnings | Pro shipped with stale min-version requirement | Update pro's `Requires Plugin:` / `requires_plugin_version` field in plugin header on every breaking free change |
| Free released first, pro PR sat in draft for 3 weeks | Coordination broke down | Both PRs in same review queue; reviewer must approve both or neither |

## Pre-merge checklist (cross-plugin PR pair)

Before any merge:

- [ ] **Step 1 complete:** contract surface inventoried; nothing pro consumes is changing silently
- [ ] **Strategy decided:** A, B, or C — documented in the free PR description
- [ ] **Both PRs reference each other** in their descriptions
- [ ] **Changelog entries** in both repos describe the change from each side
- [ ] **Joint local validation passed:** both plugins active, feature exercised, no errors
- [ ] **Backcompat tested** (if B): new free + old pro works in graceful-degradation mode
- [ ] **Version bumps decided:** matches strategy (A: no bump; B: minor bump in free; C: major bump in both)
- [ ] **Release order written down** in the free PR: "Merge free first; pro merges within <window>"
- [ ] **No `BREAKING` keyword** in either changelog unless strategy is C
- [ ] **Backports planned** if multiple maintenance branches exist (older free version may need the backcompat shim)

## When you find an existing contract drift

If you discover free and pro are already out of sync (a feature broken because of a past breaking change that wasn't coordinated):

1. **Don't "fix" by changing free again.** That digs the hole deeper.
2. **Add a backcompat shim in pro** — pro handles both the old and new free surfaces, picks based on `defined()` / `function_exists()` / version check.
3. **Document the drift** in pro's changelog: "Adds compatibility shim for free vX.Y.Z's renamed `<hook>`."
4. **Add a regression test** that runs pro against multiple free versions.
5. **Open a follow-up free issue** to deprecate the new surface in favor of restoring a canonical name in a future major — but ONLY if doing so doesn't break the world more.

The principle: **never fix a contract bug by breaking the contract again.** The shim is ugly but reversible. The clean rewrite isn't.
