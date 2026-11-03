---
name: challenge
description: Respond to an automated PR-review finding (PRView / pr-reviewer bot) on a GitHub PR — challenge it as incorrect, mark it fixed for recheck, or ask for clarification — by posting a correctly-formatted comment via the bot's command protocol. Trigger with /challenge, /recheck, or /clarify plus a PR link. First VERIFY the finding against the real code; never post a challenge to a valid finding.
---

# challenge — reply to an automated PR-review finding

Posts a command comment to a GitHub PR so the review bot (PRView / `pr-reviewer`) re-processes a specific finding. Handles the exact protocol: command on the first line, targeted by Blocker ID or exact title, posted as an **inline reply** to the finding thread when possible (top-level only as fallback).

## Invocation

```
/challenge <pr-url-or-number> [B-XXXXXXXX | "exact finding title"] <evidence>
/recheck   <pr-url-or-number> [B-XXXXXXXX | "exact finding title"] <what changed>
/clarify   <pr-url-or-number> [B-XXXXXXXX | "exact finding title"] <question>
```

The verb the user typed maps to the bot command posted on the first line:
- `/challenge` → finding is **incorrect** (you must supply refuting evidence)
- `/recheck`  → finding is **fixed** (supply what changed / the commit)
- `/clarify`  → finding is **unclear** (ask a question)

If no `B-XXXX` / title is given, resolve the target (below) and confirm it with the user before posting.

## MANDATORY: verify before you challenge

**Never post `/challenge` on a finding you have not disproved in the actual code.** A `/challenge` asserts the reviewer is wrong; if the finding is valid you waste a round-trip and lose credibility.

1. Fetch the finding's full body (path, line, "What is wrong", "Why it matters", Blocker ID).
2. Read the cited code path AND its callers/lifecycle — trace every link of the claimed failure.
3. Decide honestly:
   - **Finding is wrong** → `/challenge` with concrete file:line evidence that refutes it.
   - **Finding is right** → do NOT challenge. Tell the user, apply the fix, push, then `/recheck` with the commit. (Offer this instead of arguing.)
   - **Ambiguous / missing context** → `/clarify` with a specific question.
4. For `/recheck`, confirm the fix is actually pushed to the PR branch (`git log`/`gh pr view` shows the commit) before claiming "fixed."

Show the user the drafted comment and wait for approval before posting.

## Resolving the target finding

Prefer the **Blocker ID** (`B-XXXXXXXX`, shown beside "Finding reference" at the bottom of the inline finding). Otherwise use the **exact title**.

List the PR's inline findings to find the thread and its comment id:

```bash
OWNER=fluentform; REPO=fluentform-dev; PR=<n>
gh api repos/$OWNER/$REPO/pulls/$PR/comments \
  --jq '.[] | {id, path, line, ref: (.body | capture("B-(?<id>[A-F0-9]{8})") .id // ""), title: (.body | capture("· (?<t>[^<]+)<") .t // ""), user: .user.login}'
```

Match the row whose `ref` == the `B-XXXXXXXX` (strip the `B-`) or whose `title` == the given title. Keep its `id` (the review-comment id) for an inline reply.

## Posting the comment

**Command must be on the FIRST line.** Include the target (Blocker ID or title) right after the verb when replying top-level; for an inline reply the thread already identifies the finding, but including the ID is still safe.

**Preferred — inline reply to the finding thread** (uses the matched comment `id`):
```bash
gh api -X POST repos/$OWNER/$REPO/pulls/$PR/comments/<COMMENT_ID>/replies \
  -f body="$(printf '/recheck B-EB7B574E %s' 'One-shot self-removing hook; stamps only this submission. Fixed in <sha>.')"
```

**Fallback — top-level PR comment** (only when inline reply is unavailable):
```bash
gh api -X POST repos/$OWNER/$REPO/issues/$PR/comments \
  -f body="$(printf '/recheck %s %s' 'Missing authorization check' 'Fixed in latest commit <sha>.')"
```

## After posting

- Wait for the bot to finish processing (it re-reads the finding and replies). Re-fetch the thread to read the verdict:
  ```bash
  gh api repos/$OWNER/$REPO/pulls/$PR/comments --jq '.[] | select(.in_reply_to_id==<COMMENT_ID>) | .body'
  ```
- If the bot confirms the finding is addressed, **resolve the conversation** (GraphQL `resolveReviewThread`) — get the thread id via:
  ```bash
  gh api graphql -f query='query($o:String!,$r:String!,$p:Int!){repository(owner:$o,name:$r){pullRequest(number:$p){reviewThreads(first:50){nodes{id isResolved comments(first:1){nodes{databaseId body}}}}}}}' -F o=$OWNER -F r=$REPO -F p=$PR
  ```
  then:
  ```bash
  gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -F id=<THREAD_ID>
  ```
  Only resolve on the bot's confirmation or explicit user go-ahead — never to silence an unresolved valid finding.

## Guardrails

- One command per comment; the verb on the first line, nothing before it.
- Never fabricate a commit sha or "fixed" claim — verify it landed on the PR branch.
- Never `/challenge` a finding you could not disprove in code; prefer `/recheck` (after a real fix) or `/clarify`.
- Show the drafted comment and get the user's OK before posting (posting is outward-facing).
