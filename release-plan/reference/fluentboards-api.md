# FluentBoards REST cookbook (for the optional board-sync phase)

FluentBoards is authenticated by **WP cookie + REST nonce**, so calls must run **inside the logged-in browser tab** via the `mcp__claude-in-chrome__javascript_tool`, not from Bash. Confirm the user is logged into the board first (open the board URL, screenshot).

## Auth pattern (every call)

```js
const n = window.wpApiSettings.nonce;              // the REST nonce the SPA uses
await fetch(url, { credentials:'include', headers:{ 'X-WP-Nonce': n, 'Content-Type':'application/json' }, method:'...' , body: JSON.stringify(...) });
```

Base namespace: `/api/fluent-boards/v2/`. **Discover exact routes at runtime** from the route index (don't assume): `GET /api/fluent-boards/v2` → `.routes` (200 with a valid nonce). Filter keys for `stage-create`, `tasks`, `move-to-board`, `re-position-stages`, `assignees`, etc.

## Output-filter gotcha

The javascript_tool blocks results that look like cookies/query-strings ("[BLOCKED: Cookie/query string data]"). When returning board data, **sanitize**: strip non-ASCII and anything after `?`, e.g. `String(t.title).replace(/[^a-zA-Z0-9 .]/g,' ')`. Stash big payloads on `window.__x` and return only small, cleaned summaries.

## Known-good calls (verified)

- **List tasks by column:** `GET /projects/{board}/tasks/by-stage` → `{ tasks:[ {id,title,stage_id,status,priority,...} ], pagination_by_stage }` (paginated ~20/stage).
- **List stages/columns:** `GET /projects/{board}` → `.board.stages` (each `{id,title,position}`; position is a decimal string used for ordering).
- **Board members (for assignees):** `GET /projects/{board}/assignees` → `.data[]` (member id = `ID` or `id`).
- **Create a column:** `POST /projects/{board}/stage-create` body `{ title }` → `{ updatedStages:[...] , message }`. Find the new stage by title in `updatedStages`.
- **Create a card:** `POST /projects/{board}/tasks` body **must be wrapped**: `{ task: { title, board_id, stage_id, status:'open', type:'task' } }` → `{ task:{id,...} }`. A flat (unwrapped) body 500s with `Validator::make(): ... null given`.
- **Move a card to a column:** `PUT /projects/{board}/tasks/{id}/move-to-board` body `{ board_id, stage_id }` → 200. **Use this, not `move-task`** — `move-task` returns 500 "Invalid Stage" for every payload shape tried.

## Known limitations (fall back to the UI)

- **Assignee / priority on a card:** the base task `PUT /projects/{board}/tasks/{id}` rejects `assignees`/`priority` ("Invalid property"); only `assign-yourself` (POST) exists, which assigns the current user. Assigning teammates goes through the app's socket layer → **do it in the UI**, or hand the user a table of {card → owner, priority}.
- **Reorder columns:** `PUT /projects/{board}/re-position-stages` returns 200 "Stages Reordered" but did **not** actually reorder in testing (tried `{stages:[{id,position}]}` and `{stages:[ids]}`). **Recommend a manual drag.**
- **Create a board (if missing):** not verified here. Discover from the route index (`POST /projects` is the likely create route) and confirm the response before creating cards in it.

## Backlog handling (per the skill's board phase)

Before creating fresh cards, offer to **reuse existing backlog cards**: read `tasks/by-stage`, match plan items to existing card titles (fuzzy), and reuse those IDs for the FB refs. Only create new cards for items with no match. Then create the `<version>` column, move matched+shipped cards in, and put unmerged items in an `In Review` column.
