# Dev Lead Lounge Board Tasks

Source board: `https://lounge.authlab.io/projects#/boards/16`

Purpose: convert the Dev Lead brief into concrete board habits for FluentForm / FluentForm Pro / Fluent Player / Fluent Player Pro.

## Operating Changes

### 1. Monthly release plan for every product

Status: Semi Active

Current behavior:
- Release plans are shared informally between the team.
- Some release intent exists, but it is not always captured as a dated board commitment.

Change:
- Create one monthly release-plan task per product at the start of each month.
- Use the publishing channel `FluentForm Dev Group`.
- Keep the plan written, dated, owner-assigned, and visible before release work starts.

Board task title:
`Create monthly release plan for <Product> - <Month YYYY>`

Owner:
- Lukman: final plan and Arif-facing status.
- HR Delwar: FluentForm / FluentForm Pro release scope and readiness.
- Niluthpol Dhrupo: Fluent Player / Fluent Player Pro quality, tests, and automation readiness.

Definition of done:
- [ ] Product name and target version set.
- [ ] Release target date set.
- [ ] Publishing channel set to `FluentForm Dev Group`.
- [ ] Scope listed: bugs, features, compatibility, docs, QA.
- [ ] Owner assigned for each release item.
- [ ] QA/regression owner assigned.
- [ ] Risk level set.
- [ ] Arif-facing summary ready.

Suggested product tasks:
- `Create monthly release plan for FluentForm - <Month YYYY>`
- `Create monthly release plan for FluentForm Pro - <Month YYYY>`
- `Create monthly release plan for Fluent Player - <Month YYYY>`
- `Create monthly release plan for Fluent Player Pro - <Month YYYY>`

## 2. Assign tasks from the start in boards

Status: Semi Active

Current behavior:
- Initial selection happens first.
- Developers are often assigned on the go while work is already moving.

Change:
- Every selected task must be fully assigned before the sprint/release work starts.
- No release task should sit in the active release lane without owner, reviewer, QA/check owner, and due date.
- If ownership changes later, update the board instead of relying on chat memory.

Board task title:
`Assign owners for <Release/Sprint Name> tasks before work starts`

Owner:
- Lukman: final accountability for assignment completeness.
- HR Delwar: confirms FluentForm / Pro assignments.
- Niluthpol Dhrupo: confirms Fluent Player / Pro quality/test assignments.

Definition of done:
- [ ] Every selected task has an assignee.
- [ ] Every selected task has a reviewer.
- [ ] Security/schema/public API/cross-repo tasks have an external reviewer placeholder or named person.
- [ ] Every task has a due date.
- [ ] Every task has a product/repo label.
- [ ] Every task has a priority.
- [ ] Every task has a clear acceptance checklist.
- [ ] Tasks without owner stay out of active sprint/release lanes.

## Suggested Lounge Board Fields

Use or emulate these fields on board 16:

| Field | Required? | Notes |
|---|---|---|
| Product | Yes | FluentForm, FluentForm Pro, Fluent Player, Fluent Player Pro |
| Release / Sprint | Yes | Month or release version |
| Owner | Yes | The developer doing the work |
| Reviewer | Yes | Peer or Lead reviewer |
| QA / Check Owner | Yes | Person responsible for regression/checklist |
| External Reviewer | Conditional | Required for security, schema, public API, ADR, cross-repo |
| Due Date | Yes | Written commitment |
| Publishing Channel | Release tasks | `FluentForm Dev Group` |
| Risk | Yes | Low, Medium, High, Blocked |
| Status | Yes | Selected, Assigned, In Progress, Review, QA, Done |

## Board Rule

Selected does not mean ready.

A task becomes ready only when it has:

- owner
- reviewer
- due date
- product/repo label
- acceptance checklist
- external reviewer if required

## Weekly Check

Every Monday:
- [ ] Confirm this month's release-plan tasks exist.
- [ ] Confirm publishing channel is `FluentForm Dev Group`.
- [ ] Confirm all active tasks are assigned from the start.
- [ ] Move unassigned selected tasks out of the active lane.

Every Friday:
- [ ] Check which assigned tasks slipped.
- [ ] Update release risk.
- [ ] Prepare short Arif status.

