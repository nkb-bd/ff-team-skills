# WPManageNinja Plugin Structure Map (FluentCRM-Derived)

Use this map when the plugin has similar paths to FluentCRM (`app/Hooks/actions.php`, `app/Http/Routes/api.php`, `database/migrations/`).

## 1) Path Priority

1. Root plugin bootstrap (`<plugin>.php`) and `boot/*.php`.
2. `app/Hooks/actions.php` and `app/Hooks/Handlers/*` (WordPress hooks, AJAX entry points, schedulers).
3. `app/Http/Routes/*.php` -> `app/Http/Controllers/*` -> `app/Http/Policies/*`.
4. `database/Fluent*Migrator.php` and `database/migrations/*`.
5. `app/Services/*` and `app/Models/*`.
6. `app/Modules/*` for feature-specific logic.

## 2) Critical Verification Chains

### Route/permission chain

- Route group in `app/Http/Routes/api.php` with `withPolicy('XPolicy')`.
- Matching policy class in `app/Http/Policies/XPolicy.php`.
- Policy method authorization via `PermissionManager::currentUserCan(...)`.
- Controller method behavior and data side effects.

### Public endpoint chain

- `wp_ajax_nopriv_*` and public REST routes.
- Nonce/token validation.
- Behavior does not permit unauthorized state changes.

### Scheduler chain

- Hook registration in `boot/app.php` and/or handlers.
- Action Scheduler / WP-Cron setup keys and intervals.
- Duplicate schedule handling and deactivation cleanup.

### Migration chain

- DB version constant in root plugin file.
- Upgrade handler path and version comparison.
- Migrator coverage for new schema changes.

## 3) Common False-Positive Traps

- `wp_ajax_nopriv_*` is not automatically a bug; treat as bug only when missing effective auth/nonce for sensitive action.
- Controller methods may rely on policy-level auth; verify policy first.
- Cron hook duplication may be intentional fallback logic; confirm side effects before flagging.

## 4) High-Signal Real Bug Indicators

- Reachable debug artifacts (`dd`, `die`, `var_dump`, `print_r`) in runtime paths.
- Route action exists but policy lacks method-level coverage for destructive operations.
- Hook names drift between scheduler registration and processing handlers.
- DB schema/migration changes without synchronized DB version and upgrader flow.
