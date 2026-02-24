Your task is to create or refresh agent onboarding docs for this repository.

Primary objective:
Produce a high-signal onboarding set that reduces coding-agent variation, speeds implementation by minimizing unnecessary search, and improves correctness by adding durable architecture context.

Required outputs:
1. `/AGENTS.md` (concise, execution-focused)
2. `/docs/agent-architecture.md` (deep architecture context)
   - If the repository does not use `/docs`, use `/AGENT_ARCHITECTURE.md`.
3. Ensure `/AGENTS.md` explicitly references the architecture companion path.

Repository context assumptions:
- This may be a WordPress plugin repository.
- Local validation and manual QA may be the source of truth.
- GitHub Actions CI/CD may be absent or minimal; do not assume CI exists.

Output constraints:
- Keep `/AGENTS.md` concise: one to three pages depending on complexity.
- Keep architecture depth in the companion file, not in AGENTS.
- No task-specific instructions.
- No exhaustive file dumps, large README copy-paste, or generic filler.
- Prefer durable instructions that stay useful across many tasks.

Discovery and validation workflow:
1. Inspect key files first: `README.md`, `CONTRIBUTING.md`, `composer.json`, `package.json`, PHPCS/PHP-CS-Fixer/PHPStan/Psalm configs, test configs, build scripts, release scripts, and local environment files.
2. Inspect agent-facing onboarding docs if present (`CLAUDE.md`, `COPILOT.md`, `.cursorrules`, or equivalents).
3. Identify architecture-defining entry points (bootstrap, routing, service boundaries, data/schema layer, async/background processing, extension points).
4. Run safe, relevant commands when possible.
5. Record each command as `Validated` or `Not validated` with a concrete reason.
6. If workflows are undocumented or inconsistent, state the gap and provide the safest known fallback.

Required `/AGENTS.md` sections:
1. Repository Purpose
2. Stack and Runtime Requirements
3. Rapid Navigation Map
4. Project Layout (important paths only)
5. Architecture Overview (brief)
6. Architecture Companion (path + when to use)
7. Standard Local Workflow
8. Command Matrix
9. Manual QA Flow
10. Coding and Style Rules
11. Change Safety Rules
12. Pre-Handoff Checklist
13. Search Policy

Required architecture companion sections:
1. System Boundaries and Module Responsibilities
2. Boot and Lifecycle Flow
3. End-to-End Execution Paths
4. Data Model and Persistence Flow
5. Async and Background Processing
6. Extension Points (hooks/events/filters/plugins)
7. Critical Invariants and Contracts
8. Preferred Patterns and Anti-Patterns
9. Change Hotspots and Safe-Edit Guidance

Search policy line (use verbatim unless stricter policy is needed):
`Use this AGENTS.md first, then read the Architecture Companion; search only when instructions are missing, outdated, or conflicting.`

WordPress plugin additions (if applicable):
- Rapid navigation map should include plugin bootstrap file, admin/settings UI, REST/AJAX handlers, hooks/actions/filters, DB/options/migrations, cron, assets, i18n, and tests.
- Architecture companion should include plugin lifecycle, hook surfaces, options/meta persistence strategy, cron behavior, and REST/AJAX entry paths.
- Manual QA should include activation/deactivation/uninstall checks, settings save/load behavior, capability and nonce checks, sanitization/escaping checks, and key admin/frontend regression paths.
- Change safety should explicitly cover backward compatibility for public hooks/APIs and stored options/meta/schema.

Writing rules:
- Use imperative, unambiguous language.
- Be explicit about command order and required preconditions.
- Do not invent commands, tools, pipelines, or file paths.
- If CI is missing, state that and define local validation expectations.
- Include only content that improves implementation speed or reliability.

Final quality gate:
- Remove stale, redundant, contradictory, or low-signal content.
- Ensure `/AGENTS.md` and the architecture companion are consistent and complementary.
