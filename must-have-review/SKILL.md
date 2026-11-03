---
name: must-have-review
description: >
  Product review of a feature's settings, options and controls in any product (web app,
  plugin, CLI, mobile app, API, config file): does each one serve a real user job, does
  it actually do anything, is it in the right place, and should it be kept, moved,
  merged, cut, reworded, deprecated or investigated. Evidence-based and read-only until
  the owner picks. Optional product lens for activation, retention, packaging and
  discoverability.
when_to_use: >
  Use when someone asks "are there too many settings", "is this option needed", "what can
  we cut", "does this control even do anything", "simplify this screen", "MoSCoW this
  feature", "product review", or before adding yet another option to a crowded surface.
  Also use after a cleanup that removed stored settings or flags, to check no user-facing
  control was lost. Not for bugs, code health or visual polish; use the matching review
  skill for those.
---

# Must-have review

Every control costs users attention and the team maintenance. A control earns its place
when it serves a real user job, visibly does something, and sits where users look for it.
"Control" means anything a user can set: field, toggle, flag, CLI option, API parameter,
config key or environment variable.

## Core principles

- **Start from the job.** Name the user and the job-to-be-done (JTBD) the feature serves.
  Judge each control by the outcome it supports for that job.
- **Hide before you remove.** Sensible defaults should cover most users' frequent tasks;
  move the rest behind one clearly visible "advanced" step (progressive disclosure). Two
  levels at most; a third level means the design needs simplifying.
- **Basics are not optional.** Separate what users expect as basic or safe (Kano
  "must-be") from differentiators. Basics and safety controls are not cut for low usage.
- **Protect contracts.** Accessibility, security, compliance, stored user settings,
  documented keys and integrations outrank tidiness.
- **Absence of evidence is uncertainty.** No telemetry, silence, or default values in
  local data never prove non-use.
- **Recommend only.** Do not change product state, saved data, or contact users without
  the owner's approval.

## Workflow

### 1. Scope
Name the feature, its surfaces (screens, commands, endpoints, config files), the users
and their job. Find the intent: specs, design docs, tickets, the change that added it.
State what you will not inspect.

### 2. Inventory (bounded)
List every reachable control on the named surface: location, label, stored key, where it
is defined, and at least one runtime consumer. Trace all consumers only for controls
heading to CUT or MERGE, or when compatibility risk is suspected. The same value can
travel under different names (UI field, stored key, API field, style variable, env var):
check each name. Readers can be indirect (dynamic keys, loops, string-built names).

### 3. Prove behaviour
Runtime-test dead, misleading, duplicated, conditional and high-risk controls; for
ordinary KEEP candidates, code-path evidence plus one smoke test is enough. Set a
non-default value and observe the documented output in every known activation condition
(role, plan, state, platform, integration, save and reload). One unchanged scenario is
not proof: classify INVESTIGATE until code, logs or tests rule out conditional or
deferred effects. Use a disposable test environment; never enter real credentials, don't
save unless saving is the test, and restore anything you change.

### 4. Gather evidence
When analytics exist, use usage by segment. Without them, use, in descending weight:
1. Redacted stored configurations or exported settings
2. Support tickets, cancellation or unsubscribe reasons, documentation searches
3. Sales objections, onboarding notes, integration requests
4. Interviews or usability sessions the owner supplies or approves
5. Tests, examples, presets, documentation and migration code
6. Version history, release notes, issue history (`git log -S<key>` for git)
7. Public community questions and competitors: weak context only

Record sample size, date range, segment and likely bias.

### 5. Risk gate (before any CUT or MERGE)
Check: accessibility; security and safety; legal and compliance; roles and permissions;
enterprise policy; public API, config or schema compatibility; integrations and
webhooks; feature, experiment and rollout flags; localization; automation; power-user
escape hatches; import, export and backups; multi-tenant inheritance; mobile and
offline. If the control is a shipped contract, recommend DEPRECATE first: replacement,
default mapping or migration, warning period (typically 3-6 months for end users, 6-12
for APIs and enterprise), docs and release note stating what, why, when, replacement and
how to move, rollback plan, removal version.

### 6. Decide
Per control record:
- **Decision:** KEEP / MOVE / MERGE / CUT / FIX COPY / DEPRECATE / GAP / INVESTIGATE
- **Priority for the named job:** Must / Should / Could / Won't (MoSCoW)
- **Evidence:** runtime, usage, customer, contractual or historical
- **Confidence:** High / Medium / Low
- **Removal risk:** None / Migration / Compatibility / Compliance

CUT needs evidence of no supported job, contract, safety purpose or meaningful use;
missing evidence means INVESTIGATE. FIX COPY (a label or doc promising what the code
doesn't do) is always top priority. A past plan is context, not proof: report GAP only
when a current job is unsupported and a control is the simplest remedy. Bundle values
into a named preset only when the bundle expresses one clear intent, behaves
predictably, and keeps an advanced escape hatch where users need fine control.

### 7. Rank and stop
Rank actions by Impact x Confidence / Effort using High / Medium / Low (ICE); do not
invent numbers. Accessibility, security, compliance, data-loss and compatibility risks
override the score. Write the report, then stop and ask which items to act on. Each
accepted item becomes its own small change, test-first, with a before/after check.

## Optional product lens

Run when the owner asks for product strategy, or when the review exposes a feature-level
problem. Keep these ideas separate from control-level decisions. Each line is a question
to answer with evidence, not a rule.

- **Lowest-friction start:** steps from "I want this" to first value. Is there a shortcut
  users already trust (single sign-on such as Google, sensible defaults, presets)?
- **Clean, fast, convincing first screen:** landing page, empty state or settings home.
- **Charge for value:** is the most valuable part where the business model needs it, and
  is anything paid that users see as basic? Paying users' behaviour is a strong signal.
- **Price on value, not competition:** what is it worth to the user?
- **Use your own product often:** what did using it surface that the code didn't?
- **Talk to users:** what did real users say (owner-approved contact only)?
- **Respect the people who leave:** what do cancellations and unsubscribes say?
- **Retention over acquisition:** does this help existing users stay?
- **Launch is the start:** is the feature discoverable (onboarding, "what's new", docs,
  changelog)? Who will hear about it, and where?
- **Show it off:** can the value be seen at a glance (preview, before/after, shareable
  result)?
- **Think bigger:** the one change that would make this 10x more valuable.
- **Sunset what doesn't earn:** if it brings no usage, retention or revenue, should it go?
- **Stay in the game:** prefer steady small improvements over a stalled big rewrite.

## Report template

```
## <Feature> must-have review
Users and job: <who, JTBD>. Not inspected: <surfaces>.
Headline: <N controls on M surfaces; K dead, misleading, duplicated or niche>

### <Section or surface>
| Control | Key | Consumer | Decision | Priority | Evidence | Confidence | Risk |

### Ranked actions (ICE, max 10)
1. <decision>: <what>; why; evidence; impact/confidence/effort

### Counts
Before: <N controls / M sections>. After: <N' / M'>.

### Product lens (only if run)
Friction · first screen · value and pricing · discoverability · show-off · evidence ·
think bigger · sunset?

### Suggested change order
1. Misleading copy  2. Dead controls (keep reading old keys)  3. Merges  4. Moves (mock
first)  5. Deprecations  6. Gaps
```

## Failure modes

- Treating "no UI" as "no effect": hidden stored values can still drive behaviour.
- Checking one name for a value that travels under several.
- Calling a control dead after one scenario.
- Cutting a basic, accessibility or compliance control for low usage.
- Dropping a stored key and silently resetting users' data; prefer to keep reading it.
- Replacing a three-state control with two states (e.g. off / default / custom).
- Merging controls whose combinations users rely on without a compatibility mapping.
- Turning every stored value into its own knob.
- Acting before the owner picks.
