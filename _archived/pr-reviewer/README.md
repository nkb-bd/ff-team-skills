## Archived — replaced by `review`

This skill was merged into `~/.claude/skills/review/` on 2026-05-21 as part of consolidating the two pre-merge review skills into one.

- New trigger: `/review` (runs the full multi-detector fan-out by default — the old pr-reviewer behaviour)
- Lightweight equivalent: `/review light` (skips the parallel detectors)
- Detector criteria packs (`a11y-criteria.md`, `async-state-criteria.md`, etc.) moved to `~/.claude/skills/review/references/`
- Original SKILL.md preserved as `SKILL.md.bak` for reference

Do not invoke this directory — its SKILL.md has been renamed so it is no longer registered as a skill.
