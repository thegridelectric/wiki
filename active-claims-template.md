# Active claims

Live multi-session coordination for the GridWorks wiki. The SessionStart hook
bootstraps this file (gitignored copy) from this template and inserts your
starter row above the protocol section.

| Session | Focus | Scope (path globs) | Since |
| --- | --- | --- | --- |

## Protocol

- **Start from a clean tree.** If `git status` shows changes you don't
  recognize, stop and raise it — do not edit or regenerate over foreign WIP.
- **Your starter row is auto-appended at session start** (friendly name +
  first-6 hash). Four columns: Session · Focus · Scope · Since. **No Status,
  no Notes**; **remove your row when finished** (empty table = no active claims).
- **On your first response, ASK the user for the session Focus** — a one-line
  intent (e.g., "Decouple Sema from Transport") — and fill the Focus column.
- **Update Scope** as work progresses; keep it tight.
- **Watch for focus drift.** If the work clearly moves off the stated Focus,
  prompt the user to update Focus or to close this session and start a fresh
  one.
- **Stale rows:** the hook surfaces any row whose `Since` is more than 2 days
  old at session start. Ask the user whether those sessions have ended;
  remove their rows if so.
- **Before extending into a new path or area, re-check this file** and update
  your row. If the new area overlaps another active session's scope, **stop
  and raise it** instead of editing across the boundary.
- **Commits:** Jessica does all commits. Stage only your own paths; never
  `git add -A` while other sessions may be live. (See `GridWorks_CLAUDE.md`
  "Commit suggestions".)
