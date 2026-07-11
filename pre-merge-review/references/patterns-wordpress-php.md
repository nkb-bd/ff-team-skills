# WordPress PHP Review Criteria

Used by `engineering-review` Pass 4. Load this file when any PHP file has changed.

---

## Sanitization (sanitize early)

- Every `$_GET`, `$_POST`, `$_REQUEST`, `$_COOKIE`, `$_FILE` value sanitized before use or storage
- `wp_unslash()` applied **before** sanitizing — WordPress magic-quotes superglobals
- Right sanitizer for data type:
  - Plain text → `sanitize_text_field()`
  - Email → `sanitize_email()`
  - URL → `sanitize_url()` (store) / `esc_url_raw()` (store) — never `esc_url()` for storage
  - Integer → `intval()` or `absint()`
  - HTML with allowed tags → `wp_kses_post()` or `wp_kses()`
  - Textarea → `sanitize_textarea_field()`
- Arrays recursively sanitized — `sanitize_text_field($_POST['array'])` does nothing to the array
- No raw user input to `$wpdb->query()`, `shell_exec()`, `eval()`, `preg_replace()` with `e` flag
- **WordPress plugin review team auto-reject:** not sanitizing before use

## Escaping (escape late, at output)

- Escaping at the **point of output**, not when storing — double-escaping corrupts data
- `esc_html()` for plain text in HTML context
- `esc_attr()` for HTML attributes
- `esc_url()` for URLs in `href`/`src` output — NOT `esc_url_raw()` (that's for storage)
- `esc_js()` for values interpolated into inline `<script>`
- `wp_json_encode()` for PHP arrays passed to `wp_localize_script()` — NOT `json_encode()`
- `wp_kses_post()` for intentional HTML output
- No bare `echo $variable` anywhere in templates or inline scripts
- **Common plugin review finding:** using `esc_url_raw()` for output instead of `esc_url()`
- **Stored value echoed into a `<script>` block = JS-context sink, not HTML.** When
  a stored setting is emitted as `var x = <?php echo $value; ?>;` inside inline
  JS, HTML-oriented sanitizers (`wp_kses`, tag-stripping regexes, a `fluentform_kses_js`-style
  `<script>`-tag remover) do NOT neutralize it — the payload runs *inside* the
  existing script, no tags needed. For a JS **object literal** the value MUST be
  `json_decode()`'d and re-emitted via `wp_json_encode()` (or `wp_localize_script`);
  a shape check like "starts with `{` and ends with `}`" is trivially bypassed by
  `{};attackerCode();({})`. For a bare string interpolation use `esc_js()`.
  Failure mode: stored XSS executes for every visitor rendering the form/page.
- **Trace field-setting sanitization at BOTH ends.** A form field's `settings.*`
  key is only sanitized if it appears in the save-time sanitizer map (e.g.
  `Updater::sanitizeFieldMaps` `$settingsMap`). A key absent from that map is
  stored verbatim — verify every setting that later reaches an output/JS/eval sink
  is either in the map or escaped at output. Note the trust boundary:
  `fluentformCanUnfilteredHTML()` short-circuits sanitization for `unfiltered_html`
  users, so the attacker is the lower-privileged form editor (form-manager ACL),
  whose input MUST be neutralized. Failure mode: unmapped setting → stored XSS.

## Authorization (nonce + capability, in that order)

- Nonce verified **before** capability check (fail fast, cheapest check first)
- `wp_verify_nonce()` or `check_admin_referer()` on every form handler
- `check_ajax_referer()` on every AJAX handler (includes nonce verification)
- `current_user_can()` on every data-modifying endpoint
- REST routes have `permission_callback` — never `__return_true` on data-modifying routes
- Nonce is anti-CSRF, NOT authorization — never use nonce-only as auth gate
- `wp_ajax_nopriv_*` handlers: must still validate ownership of the resource being touched
- **Mutating hook callbacks need an authorization gate of their own.** Any
  `add_filter()` / `add_action()` callback that writes (calls `update_*`,
  `delete_*`, `wp_set_object_terms`, `wp_insert_term`, `wp_update_term`,
  `$wpdb->update`, `$wpdb->insert`, `Model::save`, `wp_schedule_*`, etc.) MUST
  establish that the caller is authorized for this mutation — inside the
  callback, not by relying on the upstream caller. Filters can be applied from
  REST, AJAX, cron, CLI, REST batch endpoints, or third-party code; the
  controller-side cap check does not transitively cover the callback.

  Acceptable gates (any one is sufficient):
  - `current_user_can($cap)` for the relevant capability
  - A project ACL helper such as `Acl::canManageX()` or `Helper::isAdmin()`
  - Resource-ownership check (`get_current_user_id() === $resource->user_id`)
  - A nonce verified in this same request flow (combined with a capability —
    nonce alone is not authorization)
  - Hard context gate (`if (!is_admin()) return;`, `if (!defined('WP_CLI'))
    return;`, `if (!wp_doing_ajax()) return;`) when the callback is genuinely
    valid only in that context

  The miss to flag: a mutating callback with **none** of the above —
  trusting that "only our code calls this filter." Treat every mutating
  filter callback as its own trust boundary.
- **Authorize the acted-on IDs, not just the named scope.** When a handler
  authorizes a request-named scope (`form_id`/`list_id`/`parent_id`) but mutates
  or reads a separate attacker-supplied array of object IDs (`entries[]`,
  `ids[]`, `submission_ids[]`), the cap check on the scope does NOT protect the
  IDs — that's IDOR by ID-smuggling. Either re-scope the IDs
  (`->where('scope_id', $authorized)->whereIn('id', $ids)`) before acting, OR
  derive authorization from the *fetched rows'* real scope. In a bulk
  `action_type` dispatcher, **every branch must apply the identical scope
  filter** — the classic bug is a delete branch that omits the `where('scope_id')`
  its sibling status/favorite branches apply (fluent-forms WPScan req 11316830,
  sibling of CVE-2026-5396). Cascading meta/detail/log deletes need the same
  filter. When patching an authz CVE, sweep sibling action paths for this class.
- **Auto-reject:** missing nonce check or missing capability check on admin actions

## SQL / Database

- All `$wpdb` calls with variables use `$wpdb->prepare()`
- `prepare()` uses typed placeholders (`%d`, `%s`, `%f`) — never string concatenation
- `ORDER BY` / `LIMIT` values from user input validated against an allowlist (can't use `prepare()` for these)
- No `$wpdb->query()` with string concatenation
- `$wpdb->insert()`, `$wpdb->update()`, `$wpdb->delete()` preferred over raw queries for simple operations
- **Auto-reject:** direct DB queries with user input not using `prepare()`

## Options and Transients

- `get_option()` not called inside loops
- `get_option()` not called twice per request for the same key without a static cache:
  ```php
  private static $cached = null;
  private static function getSettings(): array {
      if (static::$cached === null) {
          static::$cached = get_option('_plugin_settings', []);
      }
      return static::$cached;
  }
  ```
- `ArrayHelper::get($arr, 'dot.key', $default)` used instead of nested `isset()` ternaries
- Autoloaded (`true`) only for small options read on every page load
- Transients used for per-site data, not per-user (shared cache poisoning risk)

## Array Access

- `ArrayHelper::get($settings, 'misc.jquery_loading_mode', 'auto')` — not `isset($settings['misc']['jquery_loading_mode']) ? ... : 'auto'`
- `isset()` + `? :` ternary chains replaced by `ArrayHelper::get()` with a default

## Hooks and Actions

- Hook names follow project convention (`fluentform/` prefix for FluentForm)
- `do_action()` argument list documented inline for third-party plugin authors
- `add_action()`/`add_filter()` callbacks removed in teardown if registered inside object instances
- Deprecated hooks fire the new hook first, then the deprecated one
- `apply_filters()` return values sanitized/validated before use (filter output is untrusted)

## File Handling

- `move_uploaded_file()` never used — use `wp_handle_upload()` instead (auto-reject)
- `ALLOW_UNFILTERED_UPLOADS` never set (auto-reject)
- File paths from user input use `realpath()` + `basename()` + constrained to expected directory
- `validate_file()` called on any path before use
- MIME type validated server-side with `wp_check_filetype_and_ext()`

## Translation / i18n

- No variables in gettext functions: `__( $variable, 'plugin' )` → must be string literals (auto-reject)
- Text domain matches plugin slug
- `_e()` output escaped: use `echo esc_html( __( 'text', 'domain' ) )` not `_e('text', 'domain')` in HTML context

## General PHP Hygiene

- No HEREDOC/NOWDOC syntax (prevents automated scanning — plugin review team flags this)
- No short PHP tags `<?` or `<?=`
- Generic function/class names prefixed — no `function get_data()` without plugin prefix
- No reserved prefix usage: `wp_`, `__`, `_` as function/class prefix
- `defined('ABSPATH') || exit;` at top of every directly-accessible PHP file
- Any external API calls documented (what data sent, to whom, under what conditions)
- `\Exception` used (fully qualified) — not `use Exception` import at top of file

## WordPress Coding Standards Sniffs (WPCS)

These are the five core sniffs that auto-flag in plugin review:
1. `ValidatedSanitizedInputSniff` — missing `isset()` + `wp_unslash()` + sanitization on superglobals
2. `EscapeOutputSniff` — bare `echo`/`print` of variables, unescaped `_e()`/`printf()`
3. `PreparedSQLSniff` — string concatenation in `$wpdb` queries
4. `PreparedSQLPlaceholdersSniff` — placeholder count/type mismatches
5. `NonceVerificationSniff` — superglobal access without preceding nonce check
