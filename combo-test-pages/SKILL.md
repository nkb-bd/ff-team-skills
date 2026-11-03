---
name: combo-test-pages
description: >
  Plugin-agnostic: discovers a WordPress plugin's own features (shortcodes, blocks,
  CPTs, widgets/page-builder modules, admin settings, free-vs-pro gates) by reading its
  code, then builds the smallest set of real WP pages that together exercise every
  feature and every feature×feature interaction at least once. Those pages become a
  durable regression fixture: re-open them before/after a plugin or WP-core update to
  catch frontend/backend/CSS/JS breakage before release. Use when the user wants test
  pages, a test matrix, QA pages, or a "does anything break on update" fixture for a
  plugin — framed generically ("build test pages for X", "make a regression suite",
  "cover all combos") rather than as a one-off content request.
when_to_use: >
  User asks to build test/QA pages for a plugin, wants a feature matrix or combo
  coverage, wants to verify nothing breaks before a free/pro plugin update or a WP-core
  update, or asks for a reusable way to catch regressions across releases. Not for
  writing PHPUnit/Jest tests (that's `tdd`) and not for reviewing a diff (`pre-merge-review`).
context: fork
allowed-tools: Read Write Edit Bash Grep Glob
effort: medium
---

# Combo Test Pages

Builds a small, named set of real WordPress pages that collectively exercise every
feature a plugin ships, plus the interactions between features that are likely to
break together. The pages persist as a fixture — re-visit them (not re-create them)
before and after any plugin/WP-core update to catch regressions.

This skill is plugin-agnostic. It never hardcodes which features exist — it discovers
them from the target plugin's own code each run, so it works unmodified on any plugin.

## Non-goals

- Not unit/integration tests (PHPUnit, Jest). This produces browsable WP pages for
  human/visual/Chrome-driven verification, not an automated test suite.
- Not a security or code-quality audit (`plugin-audit`, `pre-merge-review`).
- Not exhaustive combinatorics. The goal is *minimal sufficient coverage*, not every
  possible combination — see "Combination budget" below.

## Phase 1 — Discover the feature inventory

Work from the plugin's own source, never from memory of "what plugins usually have."
Identify the plugin slug and directory first (`wp plugin list`, or the folder under
`wp-content/plugins/`), then grep it for each of these **feature surfaces**:

| Surface | What to grep for |
|---|---|
| Shortcodes | `add_shortcode(`, `addShortCode(` |
| Gutenberg blocks | `register_block_type(`, `block.json` files |
| Custom post types | `register_post_type(` |
| Taxonomies | `register_taxonomy(` |
| Widgets | `WP_Widget`, `register_widget(` |
| Page-builder modules | `Elementor`, `Divi`, `Beaver`, `/PageBuilders/` dirs |
| Admin settings that change frontend output | `register_setting(`, options read in frontend render paths |
| Free-vs-Pro gates | `hasPro(`, `is_pro`, `FLUENT_*_PRO`, license-check helpers — note every feature each gate unlocks |
| REST/AJAX endpoints that render markup | routes under `/Http/Routes/`, `wp_ajax_` hooks |

For each discovered item, record: **name**, **how it's invoked** (shortcode tag +
atts, block name + attributes, CPT single/archive template), **what visibly changes**
(markup, CSS class, JS behavior), and **free or pro**. Skip internal-only code paths
that produce no observable frontend/backend surface.

Read each render path far enough to know its *meaningful attribute variants* — not
every attribute, only the ones that change markup/behavior in a way a regression could
break (e.g. a player's `source` type: self-hosted vs YouTube vs Vimeo vs audio; a
playlist's layout: grid vs list). Treat purely cosmetic numeric params (padding=12 vs
padding=14) as the same variant.

## Phase 2 — Reduce to a combination budget

Exhaustive cross-product of all features × all variants is never the goal — it produces
too many pages to be useful as a fixture anyone actually re-checks. Build instead:

1. **One page per feature, happy path** — each shortcode/block/CPT template rendered
   once with its default or most common real content. This alone guarantees every
   feature has at least one page.
2. **One page per meaningful variant axis** — only for axes identified in Phase 1 as
   changing markup/behavior (source type, layout mode, free vs pro variant of the same
   feature). Fold variants of the *same* feature onto as few pages as layout allows
   (e.g. one page with three player instances: self-hosted, YouTube, Vimeo) rather than
   three separate pages, as long as they don't interact badly (don't combine things
   likely to conflict on the same page, like two JS-heavy sliders, unless that
   combination itself is a thing users do).
3. **A handful of interaction pages** — combinations the user actually does in
   practice and that are plausible breakage points: the feature embedded inside a page
   builder, two instances of the feature on one page, the feature inside a shared
   template (e.g. a block theme's single/archive template) rather than only the block
   editor. Pick these from genuine adjacency (same plugin area, same JS bundle, known
   coupling) — not an arbitrary pairwise algorithm over unrelated features.
4. **One edge/empty-state page** — missing media, invalid ID, empty playlist, logged-out
   vs logged-in if the feature gates content — whatever this plugin's render path
   actually branches on (read the code's early-return / fallback branches to find
   these, don't guess).
5. **Unrelated-area canary** — one plain page/post with zero plugin content, to catch
   "update broke something totally unrelated" (enqueued assets leaking globally, PHP
   fatal on an unrelated hook, etc).

State the resulting page count and what each page covers before creating anything;
confirm with the user if the discovered feature count would push this past roughly
8–12 pages — more than that stops being a quick pre-release check.

## Phase 3 — Build the fixture content

For each video/media/content item the pages need, prefer **reusing what already
exists** in the install (query existing posts/attachments of the relevant type) over
creating new ones; only add new seed content where the matrix needs a variant that
doesn't exist yet (e.g. a YouTube-sourced item when the install only has self-hosted
ones). Keep seed content obviously fake/local (sample video URLs, placeholder titles)
and never inject secrets or real user data.

Create pages via `wp post create` (or the REST API) with:
- Title prefix `QA:` plus the plugin slug and scenario, e.g.
  `QA: fluent-player — self-hosted + youtube + vimeo combo`
- Status `publish` so they render for Chrome-driven verification, but excluded from
  search/sitemaps if the theme/SEO plugin honors `post_meta` `_yoast_noindex`-style
  flags or a dedicated `qa-fixture` category/tag — create and apply a `qa-fixture`
  category (or equivalent taxonomy term) to every page this skill creates, so they're
  identifiable and bulk-cleanable.
- Idempotent re-runs: before creating, check for an existing page with the same title
  prefix + scenario slug and update it in place rather than duplicating.

Write a manifest at `<wp-root>/wp-content/.qa-fixtures/<plugin-slug>.json` — **never
inside the plugin's own directory**. A plugin reinstall/update (`wp plugin install
--force`, or any installer that replaces the plugin folder) deletes and recreates that
directory wholesale, silently wiping anything stored inside it — including the exact
manifest this skill depends on for Phase 4. `wp-content/.qa-fixtures/` survives plugin
reinstalls and isn't mistaken for plugin code. List in the manifest: plugin slug +
version at creation time, each page's ID/URL/scenario/what-it-covers, and the date
built. This is what makes the fixture re-discoverable on the next release instead of
re-derived from scratch.

## Phase 4 — Baseline and re-check workflow

This skill's job ends at "pages exist and are documented." The actual before/after
check is a separate, short pass the caller (or a future invocation) runs using the
manifest:

- **Baseline** (before the plugin/core update): visit each manifest URL, capture
  — page loads (HTTP 200, no PHP warnings/fatals in `wp-content/debug.log` if enabled),
  console errors (browser dev tools / Claude-in-Chrome `read_console_messages`),
  and a screenshot. Store under `<plugin-dir>/.regression-matrix/baseline/`.
- **Update** the plugin (free and/or pro) as the user directs.
- **Re-check**: revisit the same URLs, same captures, under
  `<plugin-dir>/.regression-matrix/after/`. Diff: HTTP status, console error count,
  visible DOM text, and screenshot-visible layout. Report drift per page, not just
  pass/fail — note which *feature* broke, since the manifest already maps page→feature.
- Report format: one line per page — `OK` / `CHANGED: <what>` / `BROKE: <what>` — plus
  a one-paragraph verdict on whether it's safe to release.

Don't silently skip this phase when invoked as "update the plugin and check for
breakage" — that phrasing means run Phase 4 against an existing manifest, not rebuild
the matrix from zero.

## Output expectations

- List the discovered feature inventory (Phase 1) before building anything.
- State the page plan and count (Phase 2) and get a quick nod if it's larger than
  ~10 pages.
- After creating pages, give the user the manifest path and the page URLs.
- Keep the whole thing boring and inspectable: real WP pages with real shortcodes/blocks,
  not a custom test harness — anyone on the team can open them in a browser.
