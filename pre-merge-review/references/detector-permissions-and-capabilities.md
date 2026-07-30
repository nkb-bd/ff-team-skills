# RBAC Alignment Criteria

Used by `pr-reviewer` detector `rbac-alignment`. **Always runs** when any
`app/Http/Policies/*Policy.php`, `app/Http/Controllers/*Controller.php`, or Vue file
that gates UI by capability has changed.

The rule: the capability the UI uses to *show* an action must match the capability
the API uses to *perform* it. Drift in either direction is exploitable. The
direction matters:

- UI gate is broader than API gate → menu item appears for users who get a 403 when they click it (frustration, not a security bug, but a UX bug).
- **UI gate is narrower than API gate → privilege escalation**: users who can't see the menu item can still call the API and the API allows it. **This is the dangerous direction**.

**Stored-resource authorization (authorize one, act on another).** A policy that
resolves `form_id` from the stored resource selected by `entry_id`/`feed_id` does
NOT protect a *separate* request-supplied `form_id` the controller then uses for
reads/mutations. Authorize the resource by its OWN stored id; reject any request
id that disagrees with the stored owner; scope every read/count/totals/bulk/delete
branch to that stored id (report/analytics grouping branches are a frequent leak).

**Refute the clean verdict.** Before recording "no permission issue" on
authorization, payments, or a destructive operation, adversarially try to disprove
it — a confident clean on money or access control is the verdict most likely to be
a false-negative. For payments, amount+currency agreement is not proof: verify the
provider transaction *identity* is bound to the stored order and re-checked at
confirmation, across every gateway.

---

## Policy capability vs UI menu visibility

For every changed REST route, identify (a) the policy class capability check and
(b) the Vue / PHP rendering of the menu item that exposes that route. They must
match.

**Smell patterns:**
- `AiPolicy::handle()` requires `manage_options` but `_AiSettings.vue` shows the menu
  to anyone with `read`
- Controller's `permission_callback` is `__return_true` while UI hides the menu for
  non-admins (the route is accessible by direct API call from a low-privilege user)
- Policy uses a custom helper `Acl::canAi()` that returns `true` for `editor` role,
  but the menu is gated by `current_user_can('manage_options')` in PHP — the editor
  doesn't see the menu but can still POST to the route

**Required pattern:** both UI gate and policy MUST consult the same authoritative
helper / capability constant. If the project has a custom ACL helper, use it
everywhere; if it uses raw `current_user_can`, the same string must appear on both
sides.

**Corpus evidence:**
- "AI route capability conflicts with template editor capability" (`fluent-crm#1810`, `AiPolicy.php:31`)
- "AI generation exposed to read-only contact capability" (`fluent-crm#1802`, `AiPolicy.php:31`)
- "RBAC mismatch between export UI gate and export API permission" (`fluent-cart#1658`, `AllProducts.vue`)

---

## Public endpoint missing resource ownership / publication gate

A public REST/AJAX endpoint (`permission_callback` returns `__return_true`, or
`wp_ajax_nopriv_*`) that operates on an attacker-supplied resource ID must check:

1. The resource is published / public (not draft, not private, not trashed).
2. The resource belongs to a "publishable" type (a published product, a published
   review, a public form — not a customer record, not an order, not a user).
3. If the resource has a parent, the parent is also public.

**Smell patterns:**
- `getReplyThread($id)` on a public endpoint that doesn't check the parent product
  is published
- `getOrder($id)` on a `nopriv` route with no ownership check
- `getReview($id)` that returns rejected / spam / pending reviews if the ID guesses
  right

**Corpus evidence:**
- "Reply thread endpoint skips published product gate" (`fluent-cart#1641`, `ProductReviewFrontendController.php:396`)

---

## Capability check inside the controller, not in the policy

When a controller starts with an inline `if (!current_user_can(...))` instead of
relying on a policy class, the policy class often gets edited without the controller
knowing — and vice versa. They drift silently.

**Smell patterns:**
- `app/Http/Controllers/FooController.php` first line: `if (!current_user_can('manage_options')) wp_die(...)` AND the route has a policy class registered
- Controller's policy is `Policy::class` but the controller also has its own capability check that disagrees
- One controller method uses the policy, another in the same class uses inline check with a different capability

**Required pattern:** capability checks live in policy classes only. Controllers
trust that if the request reached them, the policy passed. If a controller method
needs a finer-grained check, define it in the policy as a method (`canExportProducts`)
and call it from the policy's `handle()`.

---

## Attacker-controlled lookup keys (shortcodes, handlers, public data accessors)

A handler (shortcode, REST route, AJAX endpoint, block render callback) that
accepts a user-supplied identifier — post ID, meta key, option name, user ID,
file path, term ID — and uses it to **read** stored data must apply a
minimum-exposure lens, not just a regression lens. The capability needed to
*reach* the handler (e.g. `edit_posts` for shortcode authors) is **not** an
excuse for exposing arbitrary reads inside it.

The wrong question: "Does this require a new capability?" → too permissive.

The right question: "Does this let lower-trust input choose what gets read
out of higher-trust storage?" → if yes, that's a new surface even when the
caller already had the capability for other paths.

**Smell patterns:**

- `get_post_meta($attackerPostId, $attackerMetaKey, true)` where both args
  come from user-controlled shortcode/REST attributes
- `get_option($attackerOptionName)` where the name is a query/body parameter
- `get_post($attackerPostId)` without checking post type / status / current
  user can read it
- Any `get_user_meta` / `get_term_meta` / `get_post_meta` indexed by input
  the caller chose freely
- Lookups that fall back silently when the value doesn't match the expected
  shape — the "did it render vs. fall back?" signal is itself a probe vector
  (the attacker learns whether the key is set)

**Required pattern:**

1. **Scope the lookup to objects the caller could already access.** A
   shortcode author can write into posts they can publish; restrict any
   meta/options read to that same scope (e.g. always `get_the_ID()`, never
   an arbitrary `post_id` attribute).
2. **Reject WordPress-protected keys by default.** Meta keys with a leading
   underscore are protected by convention (`is_protected_meta()`, REST API
   default-hidden, `register_meta` opt-in). Apply the same gate at every new
   handler that reads meta by user-supplied key.
3. **Provide a named filter for opt-in exceptions.** Site owners with
   legitimate cross-scope needs (theme templates, static pages, third-party
   plugin private keys) can hook a `<plugin_slug>/<feature>_lookup_allowed`
   filter. The default MUST be deny.
4. **Don't trust "same capability → same exposure."** A user with
   `edit_posts` can already read meta on posts they own via other means —
   but they cannot freely select arbitrary post + arbitrary key on demand
   without your handler giving them that power.

**Smell example (real, fluent-player#356):**

The `[fluentplayer meta_key="..." post_id="..."]` shortcode let editors
probe any post's any meta key. URL-shaped values would render into the
public page; non-URL values fell back silently — itself a probe signal
("does post 42 have a `_private_token` set?"). The shortcode required
`edit_posts` to author, but the lookup was unbounded once authored.

Two-step fix: (a) drop `post_id` from the shortcode attribute surface;
default to `get_the_ID()` and add an opt-in filter for power users;
(b) reject `_*`-prefixed meta keys by default; add an allowlist filter.

**Corpus evidence:**

- `fluent-player#356` — `MediaShortcodeHandler.php` / `DynamicMediaSourceResolver.php`
  (probe + cross-post lookup via `get_post_meta`)

**Severity:** **Blocking** for arbitrary cross-scope read of stored data;
**High** for default-readable protected keys with no allowlist gate;
**Medium** for fallback signals that leak presence of stored keys.

---

## Authorization scope vs. acted-on IDs (IDOR by ID-array smuggling)

An endpoint that authorizes against a **scope named in the request** (a
`form_id`, `list_id`, `project_id`, `parent_id`) but then **acts on a separate
array of attacker-supplied object IDs** (`entries[]`, `ids[]`, `submission_ids[]`)
is a confused deputy. The policy validates the *scope you named*; the mutation
hits the *IDs you sent*. A user legitimately scoped to Form A passes the policy,
then smuggles Form B's IDs in the array and the unscoped query deletes/updates
them. Sanitization does not help — the IDs are well-formed integers; the cap
check does not help — it passed against the authorized scope.

This is the **branch-asymmetry** failure: when a handler dispatches on an
`action_type`, the *individual branches* often diverge. One branch builds a
scoped query (`->where('form_id', $formId)->whereIn('id', $ids)`) so smuggled
IDs resolve to zero rows; a sibling branch (often the delete path) passes the
raw `$ids` to an unscoped `whereIn('id', $ids)->delete()`. They must be
symmetric. The detector MUST compare every branch of the same dispatcher against
each other, not just review each in isolation — the bug lives in the *difference*.

**The two correct patterns (use one):**

1. **Re-scope the IDs to the authorized scope before acting.** Resolve
   `$ownedIds = Model::where('scope_id', $authorizedScope)->whereIn('id', $ids)->pluck('id')`
   and operate only on `$ownedIds`. Smuggled foreign IDs drop out by
   construction. Apply the **same** scope filter to every cascading
   meta/detail/log/order delete, not just the parent table.
2. **Authorize the targets, not the label.** Fetch the rows first, derive the
   scope from the *fetched records'* real `scope_id`, and authorize each
   distinct scope (`Acl::hasPermission($cap, $row->form_id)`), rejecting if any
   is unauthorized. Never trust a request-named scope as the authorization
   subject when the action targets a different ID set.

**Smell patterns:**
- A bulk/`action_type` handler where the status/favorite branch uses
  `->where('scope_id', $x)->whereIn('id', $ids)` but the delete branch uses
  `Model::whereIn('id', $ids)->delete()` with no `scope_id` filter
- `deleteEntries($requestIds, $formId)` where `$formId` is only used for
  logging/hooks, never as a query constraint
- Cascading deletes (`Meta::whereIn('submission_id', $ids)`,
  `OrderItem::whereIn('submission_id', $ids)`) that re-use the raw smuggled IDs
- A fix that hardened the policy's scope resolution (e.g. a prior CVE) while a
  sibling action path still acts on unscoped IDs — **always sweep siblings of a
  patched authz CVE**

**Required pattern:** every branch of a bulk/dispatch handler enforces an
**identical** scope constraint, OR the handler authorizes against the fetched
targets' real scope. A count assertion (`count($found) === count($requested)`,
as `SubmissionPrint` does) is an acceptable stricter variant for read paths —
it throws if any requested ID is out of scope.

**Corpus evidence:**
- `fluent-forms` WPScan req 11316830 (sibling of **CVE-2026-5396**) —
  `SubmissionService::handleBulkActions` delete branch
  (`app/Services/Submission/SubmissionService.php`): status/favorite branches
  re-scoped by `form_id` (line ~340), the `other.delete_permanently` branch
  passed raw `entries[]` to `Submission::remove()` →
  `whereIn('id', $ids)->delete()` with no `form_id` filter. A Manager scoped to
  specific forms could permanently delete any form's entries by smuggling IDs
  under an authorized `form_id`. The sibling `PaymentEntries::handleBulkAction`
  was *not* vulnerable — it used pattern 2 (`authorizeTransactionForms` on the
  fetched rows' real form_ids).

**Severity:** **Blocking** for cross-scope delete/update via smuggled IDs;
**High** for cross-scope read (export/print) where one branch lacks the scope
filter; **High** when the parent table is scoped but a cascading delete is not.

---

## Mutating hook callbacks without an authorization gate

A callback registered with `add_filter()` or `add_action()` that mutates
persistent state (calls `update_*`, `delete_*`, `wp_set_object_terms`,
`wp_insert_term`, `wp_update_term`, `$wpdb->update`, `$wpdb->insert`,
`Model::save`, `wp_schedule_*`, etc.) is its own trust boundary. Filters and
actions can be invoked from REST, AJAX, cron, CLI, REST batch endpoints, or
third-party code — the controller-side cap check does not transitively cover
the callback. The detector MUST scan files like `app/Hooks/filters.php`,
`app/Hooks/actions.php`, and any `Provider`/`Bootstrap` class that wires hooks.

The rule is **"establish authorization for this mutation,"** not "always call
`current_user_can`." Any one of these gates inside the callback is sufficient:

- `current_user_can($cap)` for the relevant capability
- A project ACL helper (`Acl::canManageX()`, `Helper::isAdmin()`)
- Resource-ownership check (`get_current_user_id() === $resource->user_id`)
- A nonce verified in the same request flow **paired with** a capability or
  ownership check (nonce alone is not authorization)
- A hard context gate that genuinely restricts callers (`if (!is_admin())
  return;`, `if (!defined('WP_CLI')) return;`, `if (!wp_doing_ajax()) return;`)
  — only valid when the callback is meaningful only in that context

**Smell patterns:**
- `add_filter('plugin_slug/before_save_tag', function ($tag, $id) { wp_set_object_terms($id, $tag); ... });`
  — no cap check, no ownership check, runs anywhere the filter is applied
- `add_action('plugin_slug/media_updated', [$this, 'syncTags']);` where
  `syncTags` calls `wp_insert_term` and trusts the hook caller
- A "tag mutation" filter callback that reads `$_POST` or relies on the
  upstream caller having validated the request
- Pro-plugin filter callback that mutates Free-plugin state, or vice versa,
  with no gate inside the callback ("the other side checked it" → cross-repo
  trust drift)

**Required pattern:** the first executable lines of any mutating hook
callback must establish authorization via one of the gates above. If the
callback is meant to be internal-only ("we only fire this filter ourselves"),
either inline the call instead of registering a filter, or document the
internal-only contract with a guard like `if (!doing_action('plugin_slug/internal_save')) return;`.

**Cross-repo note:** when a Free plugin defines a filter and a Pro plugin
registers the mutating callback (or vice versa), the detector MUST flag the
callback if neither side gates it. Do not assume the other repo handles auth
unless you have the other repo loaded and have verified.

**Corpus evidence:**
- `pr-reviewer-build-2026-05-15` — `fluent-player-pro` PlaylistShortcodeHandler
  refactor: tag-mutation filter at `app/Hooks/filters.php:41` registered a
  callback that wrote tag terms with no `current_user_can`, ACL helper,
  ownership check, or context gate. Generic `general-purpose` reviewer ran
  against the diff and missed it because the only auth checks it scanned for
  lived in `Controllers/`.

**Severity:** **Blocking** when the callback writes terms, options, posts, or
user data with no gate. **High** when the gate is nonce-only (CSRF protection
without authorization). **Medium** when the callback only writes transient/
cache state but still trusts the caller.

---

## Default-grant fallback in a permission check (allow-by-default authorization)

Applies to **any** plugin's authorization helper (custom ACL class, policy
method, or raw `current_user_can` wrapper). A permission check that resolves
access through a **fallback branch that grants** — "if the specific capability
check fails, fall back to a broader role/flag and allow" — is a confused deputy
in the *default direction*. The danger is not the explicit `deny`; it's the
branch that silently *upgrades* a restricted principal to a broader grant. When
the fallback is applied to **everyone** instead of only the population it was
designed for, a deliberately-restricted user (e.g. one scoped to "view" only)
whose *role* also carries a broad delegation re-acquires the access the admin
tried to remove. Sanitization and nonces are irrelevant — the request is
authentic; the auth logic itself over-grants.

This is the **fallback-scope** failure: the fallback must be gated to the exact
population it models. For every `$x = <specific-check> ?: <broader-fallback>`
or `if (!$allowed && $broaderGrant) $allowed = true;` in an auth helper, ask:
*who is `$broaderGrant` meant to cover, and does an explicitly-restricted user
slip into that set?* Two access **sources** (a per-user grant vs. a
role/group-delegated grant) must never be OR'd into a single "any access → full
access" decision.

**Smell patterns:**
- A broad capability/role lookup computed **unconditionally**, then used to
  satisfy *any* scoped permission (`if (!$allowed && $broadGrant) $allowed = true;`)
  — a per-user-restricted principal who also holds the role gets every scoped cap
- A fallback grant with **no guard distinguishing the two access sources** (a
  direct per-user grant vs. an inherited role/group delegation) — the restricted
  principal is defined by their per-user caps, but the role fallback overrides them
- `?: true`, `?? $adminCap`, `|| current_user_can($broaderCap)` as the *else* of a
  narrow check inside an ACL/policy helper
- A "manager"/"delegated"/"team"/"member" tier whose restriction is enforced by
  *omitting* caps, while a sibling code path *adds* caps back via a role/flag lookup
- The enforcement helper and the UI-report helper diverging: one applies the
  fallback, the other doesn't — the admin UI shows scoped caps while the API grants
  full (or vice versa)

**Required pattern:** a fallback grant MUST be gated to the exact principal class
it models. When two access sources coexist (an explicit per-user grant vs. a
role/group-delegated grant), detect the restricted source first and **skip the
broadening fallback for it** — the restricted principal is governed strictly by
their own capabilities. The enforcement path and the UI-report path MUST apply
the identical rule so displayed permissions match what the API enforces. When
reviewing any change to an ACL/permission helper, **enumerate every user
population** (superadmin, explicit per-user grantee, role/group-delegated, plain)
and confirm the *restricted* one cannot reach a grant through a fallback intended
for a *different* one.

**Corpus evidence:**
- `fluent-forms` PR #1031 (Wordfence, commit `d32540cc`) —
  `app/Modules/Acl/Acl.php::hasPermission()`: `$grantedRole =
  getCurrentUserCapability()` was applied to every user, so a Manager restricted
  to "View Forms" whose WP role was *also* delegated FluentForm access silently
  regained full scoped access (read/delete every submission, edit global
  settings). Fix gates the fallback on an explicit-manager check
  (`isExplicitManager()` / `userHasDirectGrant()`); the UI-report helper
  `getUserPermissions()` was aligned to report the same scoped set.

**Severity:** **Blocking** when the fallback lets a deliberately-restricted
principal reach broader write/delete/settings access; **High** for broader read;
**Medium** when only the UI-report helper over-reports (enforcement is correct
but the displayed permission set misleads the admin).

---

## Project-specific extensions

Teams using this pack in their own repo can append rules below this line
without modifying the base pack. Each appended rule MUST follow the same
structure: smell patterns, required pattern, corpus evidence (or `(local)` if
no shared corpus), severity. Rules added here are loaded by the detector
alongside the base rules.

<!-- BEGIN project-specific rules -->

<!-- Promoted to base rule "Default-grant fallback in a permission check" (applies to all plugins). -->

<!-- END project-specific rules -->

---

## Detector behavior

When this criteria reference is loaded, the detector MUST:

0. **Scan hook-registration files for mutating callbacks.** Include any
   changed file matching `app/Hooks/filters.php`, `app/Hooks/actions.php`,
   `app/Hooks/Handlers/**/*.php`, or any class registering hooks via
   `$app->addFilter`, `$app->addAction`, `add_filter`, `add_action`. For each
   changed callback (anonymous closure or method reference), grep its body for
   mutation calls: `update_*`, `delete_*`, `wp_set_object_terms`,
   `wp_insert_term`, `wp_update_term`, `wp_insert_post`, `wp_update_post`,
   `$wpdb->update`, `$wpdb->insert`, `$wpdb->delete`, `$wpdb->replace`,
   `Model::save`, `->save()`, `->update(`, `wp_schedule_*`, `set_transient`,
   `update_user_meta`, `update_post_meta`, `update_term_meta`. If any are
   present, verify an authorization gate (capability check, ACL helper,
   ownership check, or hard context gate — see "Mutating hook callbacks"
   section) exists in the callback body before the mutation. If absent, emit
   a `rbac-alignment` finding.
1. List every changed file matching `app/Http/Policies/*.php` or `app/Http/Controllers/*.php`.
2. For each, identify the route(s) it gates (grep `Route::get/post/put/delete` and
   `register_rest_route` mentioning this controller).
3. For each route, find the UI menu item / Vue component / PHP template that exposes
   it (grep changed files + adjacent Vue trees for the route URL or controller class
   name).
4. Compare the capability strings. If they differ — even if both are "checking
   something" — emit a finding.
5. For every new public endpoint (`permission_callback` returns `__return_true`,
   `nopriv` AJAX), verify a publication-gate / ownership check exists.
6. For controllers with inline `current_user_can` AND a registered policy, emit a
   finding for the dual-source capability check.
7. **For every new or modified handler (shortcode, REST, AJAX, block render
   callback) that reads stored data using a user-supplied identifier**
   (`get_post_meta`, `get_option`, `get_post`, `get_user_meta`, `get_term_meta`,
   etc., where any argument comes from `$atts`, `$_GET`, `$_POST`, REST params,
   or block attributes): apply the **attacker-controlled lookup keys** rule.
   Do NOT classify these as "no regression" purely because the capability
   needed to reach the handler is unchanged — that lens misses minimum-exposure
   violations. Ask: "does this let lower-trust input choose what gets read?"
7b. **For every bulk / `action_type` dispatch handler that reads an array of
   object IDs from the request** (`entries`, `ids`, `submission_ids`, `entry_ids`)
   and mutates or reads by those IDs: apply the **Authorization scope vs.
   acted-on IDs** rule. Enumerate *all* branches of the dispatcher and diff their
   query scoping against each other — if any branch (typically delete) omits the
   `scope_id` (`form_id`/`list_id`/`parent_id`) filter that a sibling branch
   applies, emit a finding. Trace cascading deletes (meta/details/logs/order)
   for the same missing scope. When the diff touches a known authz CVE area,
   explicitly sweep sibling code paths for the same class.
8. Default severity: **Blocking** for UI-narrower-than-API drift (escalation);
   **Blocking** for arbitrary cross-scope read of stored data via attacker-
   controlled keys; **High** for UI-broader-than-API (UX); **High** for missing
   publication gate; **High** for default-readable protected keys without an
   allowlist gate; **Medium** for dual-source check; **Medium** for fallback
   signals that leak presence of stored keys.
9. Emit findings with `category: "rbac-alignment"`. Cap at 50.
