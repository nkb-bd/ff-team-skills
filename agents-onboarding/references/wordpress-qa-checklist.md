# WordPress Plugin Manual QA Checklist

Use this checklist when the target repository is a WordPress plugin and CI is absent or minimal.

## Install and Lifecycle

- Verify plugin installs and activates cleanly.
- Verify deactivation does not break the site.
- Verify uninstall behavior matches project policy (retain or remove data as documented).

## Settings and Persistence

- Verify key settings pages load without PHP warnings/notices.
- Verify save and reload behavior for critical settings.
- Verify defaults are applied when options are missing.

## Security and Capability

- Verify privileged actions enforce capability checks.
- Verify state-changing requests enforce nonce validation.
- Verify user-controlled input is sanitized before storage.
- Verify output is escaped for the target context.

## Runtime Behavior

- Verify key admin flows affected by the change.
- Verify key frontend flows affected by the change.
- Verify REST/AJAX endpoints used by the feature.
- Verify cron/scheduled behavior if touched.

## Compatibility and Regression

- Verify existing hooks/filters keep expected behavior.
- Verify backward compatibility for stored options/meta/schema.
- Verify localization strings remain translatable when changed.

## Evidence

Record concise QA notes in AGENTS-driven outputs:
- What was tested
- Environment assumptions
- Pass/fail result
- Known gaps and follow-ups
