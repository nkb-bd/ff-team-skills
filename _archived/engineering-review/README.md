## Archived — replaced by `review`

This skill was merged into `~/.claude/skills/review/` on 2026-05-21 as part of consolidating the two pre-merge review skills into one.

- New trigger: `/review` (runs the full multi-detector + sequential-pass review by default)
- Lightweight equivalent: `/review light` (runs only the engineering-review-style 9 sequential passes)
- Reference packs (`wp-php-criteria.md`, `js-criteria.md`, `vue-criteria.md`) moved to `~/.claude/skills/review/references/`
- Original SKILL.md preserved as `SKILL.md.bak` for reference

Do not invoke this directory — its SKILL.md has been renamed so it is no longer registered as a skill.
