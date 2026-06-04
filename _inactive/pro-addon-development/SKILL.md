---
name: pro-addon-development
description: >
  Patterns for building or modifying a pro addon to a WPManageNinja-style WordPress plugin
  (free ↔ pro pair). Covers the bootstrap contract, filter-tap surface, short-circuit pattern,
  license-gating, hook naming, REST namespacing, policy/asset reuse, and signed-URL CDN
  integration. Use when adding a pro feature, changing a free↔pro contract, debugging
  free-plugin drift that breaks pro, or onboarding to a free/pro plugin pair for the first time.
when_to_use: >
  Building or extending a pro addon. Changing a hook, filter, or REST signature that pro
  consumes from free. Adding a CDN integration with signed URLs. Adding a new license-gated
  UI surface. Investigating "pro feature stopped working after free was updated" bugs.
---

# pro-addon-development

WPManageNinja plugins ship as a free/pro pair (FluentPlayer + FluentPlayer Pro, FluentForm + FluentForm Pro). The free plugin is published on WordPress.org; the pro addon is a separate plugin that **must be installed alongside free** and hooks into it. Free has no compile-time knowledge of pro. The entire contract is runtime hooks.

This skill captures the recurring patterns. The most internally-consistent reference is **fluent-player ↔ fluent-player-pro**; FluentForm has variations called out where they diverge.

## The bootstrap contract

Pro is bootstrapped from a single action fired by free during plugin load. In fluent-player-pro's `boot/app.php`:

```php
add_action('fluent_player/loaded', function ($app) use ($file) {
    // Register pro's services, controllers, hooks, integrations
});
```

The free plugin fires `do_action('<plugin>/loaded', $app)` once it's ready to be extended. Pro registers EVERYTHING inside this callback — services, REST routes, blocks, hook handlers. If `<plugin>/loaded` never fires (e.g. free deactivated), pro silently no-ops.

**Variation (FluentForm):** FluentForm pro doesn't use a `fluentform/loaded` action — it bootstraps via a different mechanism. Inspect `boot/app.php` of the specific pro plugin before assuming the action name.

## The filter-tap surface

Free fires `apply_filters('<plugin>/...', $default, $context)` at every meaningful extension seam. Pro extends or replaces via `add_filter`. Real surface in fluent-player free (~25 filters across `app/Services/`, `app/Http/Controllers/`, `app/Blocks/`):

**Settings** (most common):
```php
$playerSettings = apply_filters('fluent_player/player_settings', $media->settings);
$defaults = apply_filters('fluent_player/media_default_settings', $defaults, $mediaSettings, $globalSettings);
$sectionSettings = apply_filters("fluent_player/settings_section/{$section}", $sectionSettings, $settings);
```

**Lifecycle:**
```php
do_action('fluent_player/before_render_media', $media);
do_action('fluent_player/after_save_media', $media->ID, $payload);
do_action('fluent_player/register_email_providers');
```

**Registry / allowlists:**
```php
$integrations = apply_filters('fluent_player/integrations', self::$integrations);
$smartcodes = apply_filters('fluent_player/smartcode_groups', $smartcodes);
$allowed = apply_filters('fluent_player/dynamic_source_meta_key_allowed', false, $metaKey);
```

**Opt-out flag** (returning `false` disables a default):
```php
if (apply_filters('fluent_player/should_register_media_block', true) === false) {
    return; // pro can disable free's default block registration
}
```

When adding a new extension seam in free, **fire a filter even if the default is "do nothing"**. Once shipped, the filter name becomes part of the contract.

## The short-circuit pattern

A specific filter shape used for "let pro replace this entirely" — the default is `null`, and pro returns non-null to bypass the free implementation. From fluent-player free's `EmailCollectionService.php`:

```php
$preProcessResult = apply_filters('fluent_player/pre_process_email_provider', null, $providerType, $email, $config);
if (!is_null($preProcessResult)) {
    return $preProcessResult; // pro short-circuited; skip free's default
}
// ... free's default implementation below
```

Two conventions go together:
- `pre_process_*` filters return `null` by default; pro returns non-null to bypass
- `post_process_*` filters wrap free's result so pro can transform it

When designing a new extension point, ask: does pro need to **add behavior** (use `post_*` filter) or **replace behavior** (use `pre_*` short-circuit)? Pick the right shape — they're not interchangeable.

## The license-gating pattern

Pro features must be gated behind an active license check. fluent-player-pro's `app/Services/PluginManager/License.php`:

```php
class License
{
    const SETTINGS_KEY = '__fluent-player-pro_sl_info';

    public static function getKey()
    {
        $storedKey = self::getStoredKey();
        $defaultKey = defined('FLUENT_PLAYER_PRO_LICENSE_KEY')
            ? (string) FLUENT_PLAYER_PRO_LICENSE_KEY
            : $storedKey;

        $licenseKey = apply_filters('fluent_player_pro/license_key', $defaultKey, $storedKey);
        return is_string($licenseKey) ? sanitize_text_field($licenseKey) : '';
    }

    protected static function getStoredKey()
    {
        try {
            return FluentLicensing::getInstance()->getCurrentLicenseKey();
        } catch (\Exception $e) {
            $data = get_option(self::SETTINGS_KEY, []);
            return !empty($data['license_key'])
                ? sanitize_text_field((string) $data['license_key'])
                : '';
        }
    }
}
```

Three resolution layers, in priority order:
1. **`define()` in wp-config.php** (`FLUENT_PLAYER_PRO_LICENSE_KEY`) — for managed hosting / fleet deploys
2. **`FluentLicensing` shared library** — WPManageNinja's cross-plugin license store
3. **WP option** (`__<plugin>-pro_sl_info` array, `license_key` field) — UI-set fallback

And one filter override (`apply_filters('<plugin>_pro/license_key', ...)`) for programmatic license override (e.g. secrets manager integration).

Every pro UI surface must check license before rendering. Every pro REST endpoint must check license in the Policy class. Tests should confirm:
- Free-tier site does not see pro UI
- Free-tier site cannot hit pro REST endpoints (403)
- License cache invalidation works when key is rotated

**Variation (FluentForm):** ff-pro uses a vendored `libs/ff_plugin_updater/updater/FluentFormAddOnChecker.php` instead of a `Services/PluginManager/License.php` class. Different shape, same intent. Check the plugin's actual license source before writing license-aware code.

## The hook-naming convention

| Hook prefix | Owner | Purpose |
|-------------|-------|---------|
| `<plugin>/` | free | Shared hooks that pro (and any 3rd party) can hook into. e.g. `fluent_player/player_settings`. |
| `<plugin>_pro/` | pro | Pro-internal hooks. Free should NOT hook these. e.g. `fluent_player_pro/license_key`. |

Why the split: pro can be uninstalled without breaking free. If free hooked `<plugin>_pro/...`, removing pro would leave dead listeners on a missing hook. Cleanly: free fires its own hooks; pro fires its own hooks; the only crossing is pro → free (consuming).

## REST namespacing

| Plugin | Namespace | Lives in |
|--------|-----------|----------|
| free | `<plugin>/v1` | `app/Http/Routes/api.php` (free) |
| pro | `<plugin>/v2` | `app/Http/Routes/api.php` (pro) |

Pro **reuses free's Policy classes** by name (e.g. `MediaPolicy::verifyRequest`). Don't redefine — instantiate from free's namespace. If free renames a policy, every pro route using it 500s.

When adding a route in pro, ask: does the existing free Policy cover this capability check? If yes, reuse. If no, add a pro-specific Policy in `app/Http/Policies/` under pro's namespace.

## Asset reuse (no pro frontend build)

Asset reuse varies by plugin pair — check the target pro repo's `package.json` and CLAUDE.md before assuming:

- **fluent-player-pro**: no frontend build pipeline — no Vite, no webpack, no npm. All JS/CSS comes from free's enqueued bundles. PHP-only. Confirmation in its CLAUDE.md: _"No frontend build needed — assets come from the free plugin"._
- **fluentformpro**: has its own Laravel Mix build (`package.json` scripts `dev`/`watch`/`production`, `webpack.mix.js`). Ships its own compiled assets alongside free's.

Common rule across pairs: **never duplicate** what free already enqueues (Vidstack, hls.js for fluent-player-pro; the free form-builder runtime for fluentformpro). When pro needs its own JS, depend on free's handles via `wp_enqueue_script`'s `$deps` array so load order is enforced.

If you're unsure whether a pro repo builds frontend assets, check for `package.json` at its root and a `scripts` block with `dev` / `build` / `production` / `watch`. Absence = PHP-only.

## Signed-URL pattern (CDN integrations)

Pro plugins often integrate with CDN/video-host APIs (BunnyCDN, Mux). Signed URLs follow a JWT or HMAC pattern with expiration. fluent-player-pro's `app/Libraries/Mux.php` exposes:

- `createSigningKey()` — request a new signing key from the provider
- `getSigningKeys()` — list existing keys (rotation support)
- `getPlaybackRestrictions()` — query who's allowed to play
- `getAssets()` — fetch asset metadata

When implementing a signed-URL flow:
1. Sign on the server (PHP) — never expose private keys to JS
2. Expire conservatively (5–15 min for streaming, 1 hour for download)
3. Bind to the user's IP or session where the provider supports it
4. Rotate keys quarterly (signing key compromise is a hidden critical risk)
5. SSL verify ON for every HTTP call to the CDN API — never `sslverify => false`

CDN integration files belong in `app/Integrations/<Provider>Integration.php` (or `app/Libraries/<Provider>.php` for thin API clients). Avoid mixing the two — `Integrations/` knows about plugin state, `Libraries/` is a transport-layer wrapper.

## Common pitfalls

1. **Free renames a hook → pro silently breaks.** Pro never errors, just stops applying its filter. Symptom: a pro feature stops working with no logs. Fix: search pro for `add_filter|add_action.*<old-hook>` and update; coordinate the change in free's changelog.

2. **Both free and pro register the same handler.** Symptom: doubled side effects (two analytics events, two emails). Fix: check for `has_filter` / `has_action` before registering, or de-dupe by handler reference.

3. **License cache staleness.** Symptom: paid user blocked from pro UI after license rotation. Fix: `delete_transient` on license-change and force a fresh check.

4. **Pro UI surface unprotected by license check.** Symptom: free-tier site renders pro Vue components (empty/broken). Fix: every pro template / Vue route must check license-active before mounting.

5. **Pro REST endpoint unprotected.** Symptom: free-tier site can call `/wp-json/<plugin>/v2/...` and get pro data. Fix: every v2 route's Policy class must `verifyRequest` includes a license check, not just a capability check.

6. **Asset handle drift.** Symptom: pro's player JS uses `wp_enqueue_script('fluent-player')` but free renamed the handle to `fluent-player-frontend`. Result: ReferenceError in browser. Fix: pin the handle name in a constant in free, document it in CLAUDE.md as a contract.

7. **Signed URL leaks long-lived.** Symptom: URLs from server logs work hours later, used by scrapers. Fix: shorten expiration; consider per-IP binding.

## Pre-PR checklist (pro)

Before opening a pro PR:

- [ ] `<plugin>/loaded` (or pro's bootstrap action) still fires in free — verify by activating both plugins on a clean install
- [ ] All `add_filter` / `add_action` calls reference hooks that exist in free (grep free for each name)
- [ ] If a new `apply_filters` was added to free, document the contract in free's changelog under **Hooks added**
- [ ] If an existing hook signature changed in free, document under **Breaking** and bump major version
- [ ] Every new pro UI surface has a license check
- [ ] Every new pro REST endpoint has a Policy with license + capability check
- [ ] No pro JS or CSS assets duplicate free's (depend on free's handles)
- [ ] No `sslverify => false` on CDN/license API calls
- [ ] Signed URL expirations are short (≤15 min for stream, ≤1 hour for download)
- [ ] `composer dump-autoload` ran if a new PHP class was added (no npm/build in pro)
- [ ] Tested against the latest free version AND the previous free version (graceful degradation)

## Pre-PR checklist (free, when changing the contract)

When changing free in a way pro depends on:

- [ ] Hook name unchanged, OR pro PR is opened in lockstep
- [ ] Filter/action signature unchanged (same arg count, types)
- [ ] Policy class signatures unchanged
- [ ] Asset handles unchanged
- [ ] If breaking: free version bumped MAJOR, changelog calls out the break, pro PR ready to merge same release

When in doubt, run both plugins activated together with the proposed change and exercise the pro surface end-to-end.
