---
name: jtbd
description: >
  Frame a product or feature using Jobs-to-be-Done (Christensen / Bob Moesta).
  Surfaces the actual "job" a user hires the product to do, the forces
  that push and pull them, and the anxieties that block adoption.
  Use when scoping a new product, prioritizing features, writing a brief,
  or diagnosing why people don't switch. Triggers: "what job is this
  doing", "JTBD", "why don't users adopt", "what should we build first".
---

# Jobs-to-be-Done

People don't buy products. They **hire** them to make progress on a
job they're trying to get done. The job is stable; products come and go.

Frame the work around the **job**, not the user demographic, not the
feature list.

## Step 1 — Write the job statement

Use this form (and only this form):

```
When [situation],
I want to [motivation],
So I can [expected outcome].
```

Rules:
- The job is **solution-agnostic**. "I want to book a doctor online"
  is a *solution*, not a job. The job is "I want to see a doctor I
  trust without wasting half a day."
- The job has a **trigger**. No situation, no urgency, no job.
- The outcome is what they'd tell a friend, not what your product does.

Examples (good):
- *When my child has a sudden fever, I want to find a paediatrician
  someone I trust has actually used, so I can avoid a 3-hour wait at
  the wrong clinic.*
- *When I'm visiting Sylhet from London for two weeks, I want to find
  places to eat my parents would actually approve of, so I can spend
  time with family instead of researching.*

Examples (bad):
- "I want to use a directory app" → that's the solution
- "Doctors need a way to manage their profile" → that's a feature

## Step 2 — Map the forces of progress

Every switch (from old solution to new) is governed by 4 forces.
Write them out **for the actual switching moment**, not in general.

```
PUSH (of current situation)         PULL (of new solution)
- What's broken about today          - What's attractive about new
- The "I'm done with this" moment    - The promise of progress

ANXIETY (of new solution)           HABIT (of current situation)
- Fear of new being worse            - Comfort of known, even if bad
- Trust gaps, learning cost          - "It mostly works"
```

For a switch to happen: **push + pull > anxiety + habit**.

Most products obsess over PULL (features) and ignore ANXIETY (trust).
For directory / review / healthcare products, anxiety is usually the
biggest force — solve it first.

## Step 3 — Identify the small hire and big hire

- **Small hire**: opening the app / visiting the site once
- **Big hire**: becoming a regular user / paying / recommending

A product can win the small hire (curiosity) and lose the big hire
(trust, habit). Audit both separately.

## Step 4 — List the "jobs you are NOT doing"

Equally important. Each excluded job sharpens the product. Example for
a city directory:

- NOT: a generic national yellow pages
- NOT: a telemedicine app
- NOT: a food delivery platform
- NOT: a Facebook replacement

Exclusions become the anti-positioning list.

## Step 5 — Derive feature priority from the job

For each candidate feature, ask:

1. Does it reduce push, increase pull, lower anxiety, or break habit?
2. For which step in the customer's progress timeline?
3. Could the job be done **without** this feature for now?

Cut anything that doesn't materially shift one of the 4 forces for the
primary job. Defer everything else to Phase 2.

## Output

A one-page JTBD brief:

1. Primary job statement (one)
2. Secondary jobs (up to 2)
3. Jobs explicitly excluded (3-5)
4. The forces map for the primary job
5. Feature → force → priority table
