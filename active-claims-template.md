# Active claims

Live multi-session coordination for the GridWorks wiki. The SessionStart hook
bootstraps this file (gitignored copy) from this template and inserts your
starter row above the protocol section.

| Session | Focus | Scope (path globs) | Since |
| --- | --- | --- | --- |

## Protocol

This protocol is **normative**. Every Claude session SHALL follow it
verbatim; deviation is a defect, not a stylistic choice. RFC 2119 keywords
(MUST, SHALL, MUST NOT, SHALL NOT) carry their RFC 2119 meaning.

- **Start from a clean tree.** If `git status` shows changes you don't
  recognize, you MUST stop and raise it — you MUST NOT edit or regenerate
  over foreign WIP.
- **Your starter row is auto-appended at session start** (friendly name +
  first-6 hash). The table has exactly four columns: Session · Focus · Scope
  · Since. You MUST NOT add Status, Notes, or any other column. You MUST
  remove your row when finished (an empty table means no active claims).
- **On your first response, you MUST ASK the user for the session Focus** —
  a one-line intent (e.g., "Decouple Sema from Transport") — and fill the
  Focus column before doing any other work.
- **Focus is short.** The Focus cell SHALL be **5 words or fewer**. It is a
  label, not a description (e.g., "spec bakeoff", "decouple sema/transport",
  "scada wiki cleanup"). Longer prose, qualifiers, or paths MUST NOT appear
  in Focus.
- **Update Scope** as work progresses; keep it tight.
- **Claim granularity.** Scope entries SHALL be exactly **one directory
  deep** for code-repo claims (e.g., `sema/`, `gridworks-base/`,
  `gridworks-scada/`) and SHALL be **at most two deep** for `wiki/` claims
  (e.g., `wiki/sema/`, `wiki/gridworks-scada/`). Finer-grained claims
  fragment coordination — if two sessions both touch the same top-level dir
  (or the same `wiki/<domain>/`), one SHALL block and wait; they MUST NOT
  coexist with a narrower path glob.
- **Top-level wiki files require explicit per-file claims.** Files that sit
  at the root of `wiki/` (e.g., `wiki/README.md`, `wiki/GridWorks_CLAUDE.md`,
  `wiki/glossary.md`, `wiki/working-with-llms.md`, `wiki/active-claims.md`
  itself) are NOT covered by any domain claim — they fall outside the
  per-domain pattern. To edit any such file, the specific file path MUST
  appear verbatim in your Scope on its own `<br>`-separated line. This
  prevents top-level wiki edits from going silently uncoordinated across
  sessions. The same rule applies to top-level wiki *folders* that are not
  per-domain (e.g., `wiki/doing/`, `wiki/todo/`, `wiki/tools/`) — claim by
  the folder path.
- **Scope is paths only. This is absolute.** The Scope cell MUST contain
  *only* path globs — one path per line inside the cell using `<br>`
  separators. You MUST NOT include parentheticals, notes, rationale,
  qualifiers (e.g., "(read-only)", "(specs only)"), status, or any other
  prose in the Scope column. All such context belongs in the Focus column.
  A Scope cell that contains anything other than paths + `<br>` is a
  protocol violation and MUST be fixed immediately upon notice.
- **Watch for focus drift.** If the work clearly moves off the stated Focus,
  you MUST prompt the user to update Focus or to close this session and
  start a fresh one.
- **Stale rows:** the hook surfaces any row whose `Since` is more than 2 days
  old at session start. You MUST ask the user whether those sessions have
  ended and remove their rows if so.
- **Before extending into a new path or area, you MUST re-check this file**
  and update your row. If the new area overlaps another active session's
  scope, you MUST stop and raise it; you MUST NOT edit across the boundary.
- **Commits:** Human does all commits. You MUST stage only your own paths;
  you MUST NOT `git add -A` while other sessions may be live. (See
  `GridWorks_CLAUDE.md` "Commit suggestions".)
