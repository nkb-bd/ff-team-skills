---
name: setup-code-review-graph
description: >
  Wire the code-review-graph MCP server into a repo so Claude Code can query the codebase as
  a structural knowledge graph (callers, dependents, test coverage) instead of grepping files.
  Use when onboarding a new repo, when `claude mcp list` doesn't show `code-review-graph`,
  when CLAUDE.md is missing the graph instructions block, or when the user asks to "wire up
  the graph", "install code-review-graph", or "set up the MCP graph for this repo".
when_to_use: >
  New repo onboarding. Existing repo missing `.mcp.json` + CLAUDE.md graph block + `.code-review-graph/`
  cache. Multi-repo expansion (registering additional repos for cross-repo queries).
---

# setup-code-review-graph

The `code-review-graph` MCP server (a pipx-installed Python CLI, `code-review-graph` binary) exposes a structural knowledge graph of the codebase to Claude Code via MCP tools (`query_graph`, `semantic_search_nodes`, `get_impact_radius`, `detect_changes`, etc.). The CLI's own `install` subcommand handles all the wiring — this skill is a thin, opinionated wrapper around it that adds verification, the seed `build` step, and optional multi-repo registration.

## When NOT to use

- The repo already has a working setup. Check first: `.mcp.json` exists, `CLAUDE.md` contains a "code-review-graph" section, `.code-review-graph/` cache directory exists, and `claude mcp list` shows the server connected.
- The `code-review-graph` binary isn't installed locally. Install it first via pipx (`pipx install code-review-graph`) — this skill assumes the binary exists on PATH.

## Workflow

### Step 1 — Verify the binary

```bash
command -v code-review-graph && code-review-graph --version
```

If not on PATH, find the pipx install:
```bash
ls ~/.local/bin/code-review-graph
ls ~/.local/pipx/venvs/code-review-graph 2>/dev/null
```

If neither resolves, stop. The user needs to install it first: `pipx install code-review-graph`.

### Step 2 — Dry-run first

Always dry-run before live install so the user sees exactly what files will be touched:

```bash
cd <target-repo-root>
code-review-graph install --platform claude-code --dry-run -y
```

**Important:** the dry-run is conservative — it advertises three actions, but the live install also writes additional files. Plan for the full scope:

| Action | Dry-run mentions? | Live install does? |
|--------|-------------------|---------------------|
| Write `.mcp.json` at repo root | ✓ | ✓ (uses absolute pipx python path + `cwd` for robustness) |
| Append graph block to `CLAUDE.md` | ✓ | ✓ |
| Add `.code-review-graph/` to `.gitignore` | ✓ | ✓ (idempotent — skipped if already present) |
| Generate skill files in `.claude/skills/` (`debug-issue/`, `explore-codebase/`, `refactor-safely/`, `review-changes/`) | ✗ silent | ✓ |
| Write `.claude/settings.json` with hooks (PostToolUse → `update --skip-flows`; SessionStart → `status`) | ✗ silent | ✓ |
| Install `.git/hooks/pre-commit` (runs `update` + `detect-changes --brief`) | ✗ silent | ✓ |

Show the dry-run output to the user AND flag the four silently-installed items. Get confirmation before Step 3.

If the user wants to opt out of any silent items, pass:
- `--no-skills` — skip the `.claude/skills/` subdirs
- `--no-hooks` — skip BOTH `.claude/settings.json` hooks AND the git pre-commit hook
- `--no-instructions` — skip CLAUDE.md / AGENTS.md injection

### Step 3 — Live install

```bash
cd <target-repo-root>
code-review-graph install --platform claude-code -y
```

Flags worth knowing:
- `--no-skills` — skip platform-native skill file generation (use this if the repo already has its own skill conventions you don't want disturbed)
- `--no-hooks` — skip hook installation
- `--no-instructions` — skip CLAUDE.md / AGENTS.md injection (use this if you want to write the graph block manually with custom wording)
- `--platform` — `claude-code` is the right target for Claude Code; other accepted values include `codex`, `cursor`, `windsurf`, `zed`, `continue`, `opencode`, etc. Default is `all detected`.

### Step 4 — Seed the graph

The install command writes config files but does NOT build the graph. Without a build, MCP queries return empty results. Run:

```bash
code-review-graph build
```

First-time build on a large repo can take **several minutes**. Don't kill it. The output ends with node/edge counts:

```
✓ Build complete. <N> nodes, <M> edges, <K> communities.
```

For very large repos (>100k LOC), consider `code-review-graph build --workers <N>` to parallelize.

### Step 5 — Verify wiring

```bash
# Files written:
test -f .mcp.json && echo "✓ .mcp.json"
grep -q "code-review-graph" CLAUDE.md && echo "✓ CLAUDE.md block"
grep -q ".code-review-graph/" .gitignore && echo "✓ .gitignore line"
test -d .code-review-graph && echo "✓ graph cache exists"

# Graph health:
code-review-graph status
```

`status` should report node/edge counts matching the build output. If counts are zero, the build didn't run or failed silently — re-run `build` with `-v` for verbose output.

### Step 6 — Restart Claude Code

**Critical.** `claude mcp list` will NOT show the new server until Claude Code is restarted (or the project is re-opened). Tell the user this explicitly:

> Restart Claude Code (or close and reopen the project). After restart, run `claude mcp list` and confirm `code-review-graph` appears with status `✓ Connected`. Until then, the MCP tools won't be callable.

### Step 7 (optional) — Multi-repo coordination

If the user works across multiple related repos (free/pro plugin pair, monorepo siblings), register each repo with an alias for cross-repo queries:

```bash
code-review-graph register --alias <short-name> <absolute-path>
# Example:
code-review-graph register --alias fp-free /Volumes/Projects/.../fluent-player
code-review-graph register --alias fp-pro  /Volumes/Projects/.../fluent-player-pro
```

List registered repos:
```bash
code-review-graph repos
```

For continuous multi-repo watching (auto-rebuilds on file changes):
```bash
code-review-graph daemon start
code-review-graph daemon status
```

## Common pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `claude mcp list` doesn't show the server after install | Claude Code not restarted | Close and reopen the project |
| MCP tools return empty results | Graph never built | Run `code-review-graph build` |
| `install` reports "no platforms detected" | No `.claude/`, `.codex/`, etc. exists | Pass `--platform claude-code` explicitly |
| `.gitignore` already has `.code-review-graph/` and `install` won't re-touch it | Idempotent — that's expected | No action needed |
| Graph cache massive (>1GB) on a small repo | Old artifacts from prior builds | `rm -rf .code-review-graph/ && code-review-graph build` |
| `build` fails on a file with parse errors | One bad source file shouldn't block — but old versions did | Update with `pipx upgrade code-review-graph` |

## What this skill writes (reference)

After successful install, the repo will have:

**`.mcp.json`** (project root) — registers the server for Claude Code. The install command writes the absolute pipx python path + module invocation + `cwd` for robustness (works regardless of Claude Code's PATH):
```json
{
  "mcpServers": {
    "code-review-graph": {
      "command": "/Users/<user>/.local/pipx/venvs/code-review-graph/bin/python",
      "args": ["-m", "code_review_graph", "serve"],
      "cwd": "/absolute/path/to/repo",
      "type": "stdio"
    }
  }
}
```

**`CLAUDE.md`** — appended block instructing the agent to prefer graph tools over Grep/Glob/Read for code exploration.

**`.gitignore`** — adds:
```
# Added by code-review-graph
.code-review-graph/
```

**`.code-review-graph/`** (gitignored) — graph cache. Persisted across sessions, incrementally updated. Don't commit, don't share — it's machine-local.

**`.claude/settings.json`** — Claude Code hooks (project-shared, committed by default):
```json
{
  "hooks": {
    "PostToolUse": [{"matcher": "Edit|Write|Bash", "hooks": [{"type": "command", "command": "... code-review-graph update --skip-flows ...", "timeout": 30}]}],
    "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "... code-review-graph status ...", "timeout": 10}]}]
  }
}
```
The PostToolUse hook fires on every Edit/Write/Bash in this repo, keeping the graph fresh. Errors are swallowed (`|| true`). If the team doesn't want this committed, gitignore `.claude/settings.json` or use `--no-hooks` at install time.

**`.git/hooks/pre-commit`** — runs `code-review-graph update` + `code-review-graph detect-changes --brief` before each commit. Not committed (lives in `.git/hooks/`). Each developer needs to re-install to get it locally.

**`.claude/skills/<name>/skill.md`** — four graph-aware skill files (`debug-issue`, `explore-codebase`, `refactor-safely`, `review-changes`) that wrap common graph queries. Useful but not player-specific — they work in any graph-indexed repo.

## Output contract

When the skill finishes, report to the user:

1. Files written (paths)
2. Graph stats (`<N> nodes, <M> edges`)
3. Restart reminder
4. (If multi-repo) Registered aliases

Example final report:

> Wired `code-review-graph` into `/path/to/repo`:
> - `.mcp.json` (created)
> - `CLAUDE.md` (graph block appended)
> - `.gitignore` (added `.code-review-graph/`)
> - `.code-review-graph/` (cache, 12,453 nodes / 38,901 edges)
>
> **Restart Claude Code** to pick up the new MCP server. After restart, `claude mcp list` should show `code-review-graph ✓ Connected`.
