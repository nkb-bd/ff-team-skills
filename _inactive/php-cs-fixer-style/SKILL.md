---
name: php-cs-fixer-style
description: Apply the shared PHP-CS-Fixer style when suggesting or editing PHP code. Use when users ask for style compliance, when code should match the team formatter, or when working in PHP codebases that follow the bundled `references/.php-cs-fixer.php` configuration (or a repo-local override).
---

# PHP CS Fixer Style

1. Resolve the config path before proposing or editing PHP:
   - If the target repository has its own `.php-cs-fixer.php`, use that file.
   - Otherwise, use this skill's bundled config: `references/.php-cs-fixer.php` (resolved relative to the skill directory).
2. Treat the selected config file as the source of truth for style; do not invent overrides unless explicitly requested.
3. Apply high-impact rules explicitly in suggestions:
   - Use cast spacing with one space: `(int) $value`, `(string) $name`, `(bool) $flag`.
   - Use single quotes unless interpolation or escaping makes double quotes clearer.
   - Keep spaces inside parentheses.
   - Keep one space around operators; keep minimal aligned spacing for `=>` in arrays.
4. Prefer writing patches already formatter-compliant rather than relying on later cleanup.
5. If formatting verification is needed and `php-cs-fixer` is available, run:
   - `php-cs-fixer fix <file-or-dir> --config=<selected-config-path> --allow-risky=yes`
6. If fixer is unavailable, enforce rules manually and state that verification was manual.
