---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

**Default to continuing.** A short session of 2–3 questions is a bug, not a feature. After each answer, immediately ask the next question — don't wait to be prompted. Stop only when the user explicitly says "enough" / "stop" / "we're done", or when every branch of the decision tree is resolved and no dependencies remain open. If you find yourself wrapping up before that, you are failing the skill — keep grilling.

If a question can be answered by exploring the codebase, explore the codebase instead.
