---
name: skill-creator
description: Create new reusable Claude Code skills. Guides skill design, writes the SKILL.md with correct frontmatter and structure, adds it to the global agent-skills repo, and registers it in the README. Use when you want to turn a repeatable workflow or review process into an invocable skill.
---

# Skill Creator

Use this skill to design and create a new reusable Claude Code skill. A skill is a markdown file that gives Claude a structured, repeatable workflow for a specific type of task — review, audit, generation, check, or transformation.

## When to create a skill

Create a skill when:
- You just did a review or analysis you want to repeat on future PRs with `/skill-name`
- You have a multi-step process you always run in a certain order
- You want to encode institutional knowledge so future agents don't have to rediscover it
- You want a checker that remembers past findings and can re-run to verify fixes

Do NOT create a skill for:
- One-off tasks specific to a single file or feature
- Things already covered by an existing skill (check the list first)

---

## Step 0 — Understand the request

Ask (or infer from context):

1. **What is the skill for?** (e.g. "review any PHP PR for WordPress patterns", "check if migration findings are fixed")
2. **What type is it?**
   - `review` — reads code, produces a structured findings report
   - `checker` — re-checks specific past findings (has memory of a previous review)
   - `workflow` — step-by-step process to follow when doing a certain task
   - `generator` — produces a specific output file (PR description, AGENTS.md, audit report)
   - `transformer` — edits existing code to meet a standard (code style, refactor pattern)
3. **Is it project-specific or universal?**
   - Universal → goes in `/Volumes/Projects/Tools/agent-skills/<name>/SKILL.md`
   - Project-specific → goes in `.claude/skills/<name>.md` inside the repo
4. **Does it need a re-run mode?** (Can it be called again later to check if previous findings are fixed?)
5. **Does it need reference files?** (Templates, config files, checklists stored in `references/`)

---

## Step 1 — Design the skill structure

### For a `review` or `checker` skill, design:
- What inputs does it read? (git diff, specific files, a previous output file)
- What passes does it run? (security, performance, patterns, etc.)
- What does it output? (file path, format, severity levels)
- Does it have a re-run mode that checks previous findings?

### For a `workflow` skill, design:
- What triggers it? (PR type, file type, stage of development)
- What steps does it run in order?
- What does "done" look like?

### For a `generator` skill, design:
- What is the output file name and location?
- What is the mandatory output format/structure?
- What inputs does it read to produce the output?

### For a `transformer` skill, design:
- What standard does it enforce?
- How does it decide what to change vs leave alone?
- Does it need a reference config or style guide?

---

## Step 2 — Write the SKILL.md

### File location

**Universal skill (available globally):**
```
/Volumes/Projects/Tools/agent-skills/<skill-name>/SKILL.md
```

**Project-specific skill:**
```
<repo>/.claude/skills/<skill-name>.md
```

### Required frontmatter

Every SKILL.md must start with:
```yaml
---
name: <skill-name>
description: <one or two sentences — this is what Claude reads to decide whether to invoke the skill. Be specific about WHEN to use it and what it produces.>
---
```

The `description` field is critical — Claude uses it to match user intent to the right skill. Write it as: "Use when [trigger condition]. Produces [specific output]."

### Content structure by skill type

**For `review` / `checker` skills:**
```markdown
# <Skill Name>

<One paragraph: what problem this solves and when to run it.>

## Two Modes (if applicable)
**First run:** [what it does when no previous output exists]
**Re-run:** [what it does when previous output exists — checks findings, reports status]

## Step 0 — Orient
[How to get context before starting: git diff, log, existing files to read]

## Pass 1 — <Dimension Name>
**Question:** [The one question this pass answers]
[Checklist of what to look for]

## Pass 2 — ...
[repeat]

## Output Format
[Exact structure of the output file, with a template]

## Severity Definitions (if applicable)
| Level | Definition |

## Re-run Mode (if applicable)
[How to check previous findings instead of doing a full review]
```

**For `workflow` skills:**
```markdown
# <Skill Name>

<When to use this workflow.>

## Trigger
[What condition triggers this workflow]

## Steps
### Step 1 — <Name>
[What to do, concrete commands if applicable]

### Step 2 — ...

## Done When
[How to know the workflow is complete]
```

**For `generator` skills:**
```markdown
# <Skill Name>

<What it generates and why.>

## Required Output
- Write to: [exact file path pattern]
- Format: [exact structure with template]
- Before writing: [any pre-flight checks]

## Inputs
[What to read to produce the output]

## Output Template
[Exact mandatory structure]

## Quality Checks
[How to verify the output is correct before finishing]
```

**For `transformer` skills:**
```markdown
# <Skill Name>

<What standard it enforces.>

## When to apply
[File types, PR types, conditions]

## Rules
[Specific patterns to enforce, with before/after examples]

## Reference
[Path to any config or style guide file in references/]

## What NOT to change
[Explicit exclusions]
```

---

## Step 3 — Create reference files (if needed)

If the skill needs supporting files (templates, config, checklists):

```
agent-skills/<skill-name>/references/
├── template.md          # output template
├── checklist.md         # detailed checklist
└── config.json          # tool config
```

Reference files are loaded by the skill on demand — the SKILL.md should explicitly say when and how to use them.

---

## Step 4 — Update the README

After creating the skill, add a row to `/Volumes/Projects/Tools/agent-skills/README.md`:

```markdown
| `<skill-name>` | <one-line purpose> | <primary output> |
```

---

## Step 5 — Verify the skill is discoverable

After creating, confirm Claude Code can see it:
- Global skill: check `ls /Users/lukmannakib/.claude/skills/` — the folder should appear (since `~/.claude/skills/` symlinks to `agent-skills/`)
- Project skill: check `.claude/skills/<name>.md` exists

To test: start a new conversation and say "use the <skill-name> skill" — Claude should recognize it from the `description` frontmatter.

---

## Skill design principles

**A good skill is:**
- Triggered by a clear condition, not "whenever you feel like it"
- Specific about its output — exact file path, exact format
- Actionable — every check produces a FIXED / STILL OPEN verdict, not just observations
- Self-contained — a new agent with no prior context can follow it

**A bad skill is:**
- Vague ("review the code for quality")
- Duplicates an existing skill without adding a new dimension
- Project-specific but saved globally (wastes context on irrelevant content)
- Has no output — just produces in-chat text with no persistent record

---

## Existing skills (check before creating a new one)

| Skill | Purpose |
|---|---|
| `plugin-audit` | Deep WordPress security + optimization + traceability audit |
| `debugger` | Bug discovery with finder/verifier feedback loop |
| `php-cs-fixer-style` | PHP code style enforcement |
| `pr-descriptor` | PR description generation from git evidence |
| `agents-onboarding` | AGENTS.md creation/refresh |
| `engineering-review` | Pre-merge engineering review, any PR type, re-callable |
| `skill-creator` | This skill — creates new skills |

If the new skill overlaps significantly with an existing one, extend the existing skill rather than creating a new one.
