---
name: agents-onboarding
description: Create or refresh repository AGENTS.md files with consistent, high-signal onboarding guidance and durable architecture understanding. Use when users ask to set up, standardize, or update agent instructions for a repository, reduce agent behavior variation, or generate reusable AGENTS.md guidance prompts (especially for WordPress plugin repositories with local QA-first workflows).
---

# Agents Onboarding

Create or update `/AGENTS.md` and a deep architecture companion so agents can implement and validate changes quickly with minimal repo searching.

## Default Outputs

- `/AGENTS.md`: concise operating guide for fast execution.
- `/docs/agent-architecture.md`: deep architecture context for reasoning-heavy changes.
- If the repository does not use a `/docs` folder, use `/AGENT_ARCHITECTURE.md`.
- Always add a clear pointer from `/AGENTS.md` to the architecture companion path.

## Workflow

1. Audit only high-signal sources.
   - Read existing `AGENTS.md` first if present.
   - Read workflow-defining docs and configs: `README.md`, `CONTRIBUTING.md`, `composer.json`, `package.json`, linter/static-analysis configs, test configs, local environment files, and release scripts.
   - Read agent-facing onboarding files if present (`CLAUDE.md`, `COPILOT.md`, `.cursorrules`, or equivalents).
   - Read architecture-defining entry points (bootstrap files, routing setup, service/domain boundaries, migration/schema paths, async scheduler/queue paths).
   - Avoid exhaustive inventory unless a gap blocks correctness.

2. Build the architecture mental model.
   - Extract the highest-value execution paths agents need to reason about.
   - Capture boot/lifecycle flow, request flow, data/schema flow, async/background flow, and extension points (events/hooks/filters/plugins).
   - Surface stable contracts and invariants that must not be broken by routine changes.

3. Draft or refresh the architecture companion.
   - Write deep architecture context to `/docs/agent-architecture.md` (or `/AGENT_ARCHITECTURE.md` fallback).
   - Include end-to-end execution paths, contract boundaries, invariants, and change hotspots.
   - Keep AGENTS concise by moving extended architecture details into this file.

4. Identify the real validation model.
   - Confirm whether CI exists.
   - If CI is missing or minimal, state that local validation and manual QA are the source of truth.

5. Build a reliable command matrix.
   - Capture bootstrap/dev/lint/test/build or release commands.
   - Validate safe commands when possible.
   - For each command, record: purpose, exact command, preconditions, expected result, and status (`Validated` or `Not validated` with reason).

6. Draft or refresh `/AGENTS.md`.
   - Keep output concise (target one to three pages depending on repository complexity).
   - Keep guidance non-task-specific.
   - Keep language imperative and unambiguous.
   - Preserve high-level architecture summary, contracts summary, and coding conventions that speed up decision-making.
   - Reference the architecture companion for deep flow details.
   - Preserve useful existing repo-specific details; replace stale or contradictory guidance.

7. Enforce search minimization.
   - Add a rapid navigation map that points agents to likely edit paths by task type.
   - Include only structurally important paths.
   - Avoid full tree dumps, long copied docs, and low-signal filler.

8. Apply the final quality gate.
   - Remove contradictions, stale assumptions, and duplicated content.
   - Ensure `/AGENTS.md` and the architecture companion do not conflict.
   - Ensure architecture guidance is concrete enough to reduce trial-and-error:
     - Include at least one end-to-end execution path.
     - Include a `Critical Invariants and Contracts` section.
     - Include a `Preferred Patterns and Anti-Patterns` section.

## Required AGENTS.md Sections

1. Repository Purpose
2. Stack and Runtime Requirements
3. Rapid Navigation Map
4. Project Layout (important paths only)
5. Architecture Overview (brief)
6. Architecture Companion (path + usage note)
7. Standard Local Workflow
8. Command Matrix
9. Manual QA Flow
10. Coding and Style Rules
11. Change Safety Rules
12. Pre-Handoff Checklist
13. Search Policy

## Required Architecture Companion Sections

1. System Boundaries and Module Responsibilities
2. Boot and Lifecycle Flow
3. End-to-End Execution Paths
4. Data Model and Persistence Flow
5. Async and Background Processing
6. Extension Points (hooks/events/filters/plugins)
7. Critical Invariants and Contracts
8. Preferred Patterns and Anti-Patterns
9. Change Hotspots and Safe-Edit Guidance

## Search Policy Text

Use this exact policy line unless the repository needs a stricter variant:

`Use this AGENTS.md first, then read the Architecture Companion; search only when instructions are missing, outdated, or conflicting.`

## WordPress Plugin Defaults

When the repository is a WordPress plugin:

- Treat backward compatibility and upgrade safety as first-class constraints.
- Include a high-level plugin lifecycle map (load, activation, deactivation, uninstall policy) and key extension points.
- Include manual checks for activation/deactivation/uninstall, options persistence, capabilities/nonces, sanitization/escaping, and key admin/frontend paths.
- Call out WordPress-specific directories and bootstrap files in the rapid navigation map.
- In the architecture companion, include hook surfaces, options/meta storage strategy, cron behavior, and REST/AJAX entry paths.

## References

- Reusable prompt template: `references/master-prompt.md`
- AGENTS.md section scaffold: `references/agents-md-outline.md`
- Architecture companion scaffold: `references/architecture-companion-outline.md`
- WordPress QA checklist: `references/wordpress-qa-checklist.md`
