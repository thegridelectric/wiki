# Active work — multi-session coordination

Jessica runs **2–4 Claude sessions at once** across the GridWorks repos (and
this wiki). This file is the **well-known place to declare who is editing
what**, so sessions don't collide. It is the single coordination point across
*all* repos — git worktrees isolate within one repo, but only this registry
makes cross-repo work visible.

> **Template vs. live copy.** This file, `active-work-template.md`, is the
> **committed seed** (version-controlled). The **live** working copy is
> `active-work.md`, which is **gitignored** — it's local to your machine and is
> where sessions add and clear claims (its churn never causes merge conflicts).
> **Protocol changes go in this template; live claims go in `active-work.md`.**
> On a fresh checkout, copy this file to `active-work.md` to start.

## Launch from the umbrella directory (recommended for everyone)

Start Claude from the **GridWorks umbrella directory** (Jessica's is
`/Users/jessica/GridWorks`) — the parent holding all the repos + this `wiki/` —
**not** from inside a single repo like `gridworks-ear`. Only then do you get:

- the **project memory** keyed to the umbrella dir (a sub-repo gets a different,
  empty memory);
- this wiki + `active-work.md` on a stable relative path;
- the ability to make **cross-repo** edits in one session.

If you forget and launch in a sub-repo, quit and relaunch from the umbrella dir.
Jessica enforces this locally with a **SessionStart hook** in her personal
`~/.claude/settings.json` that prints a reminder when a session starts inside a
GridWorks sub-repo. Collaborators who mirror this folder structure should adopt
the same convention (and may replicate the hook with their own path).

## Protocol (every session follows this)

0. **Start from a clean tree.** Before claiming/editing a new area, run
   `git status` and confirm there are **no uncommitted changes you don't
   recognize**. If you find foreign/abandoned WIP, stop and raise it — do **not**
   edit or run a global regeneration over it, or you will entangle someone
   else's work into your commit (this happened once with sema). Only your own
   in-session changes should be present.
1. **On start:** read this file.
2. **Claim your area:** append/update a row in the table below — your session
   label, the repo(s)/domain, the path globs you expect to edit, status, and
   the date. Keep the scope as tight as honestly possible.
3. **Before editing outside your claimed scope:** re-read this file. If the new
   area falls inside another **active** claim, **stop and raise it to Jessica** —
   do not edit across the boundary. If it's unclaimed, widen your row first,
   then proceed.
4. **On pause/finish:** set your status (`paused` / `done`) so others can take
   the area. Stale `active` rows are worse than none — keep yours honest.

Claims are advisory coordination, not a lock — they work because every session
respects them and surfaces conflicts to Jessica rather than guessing.

## Git workflow for concurrent sessions

`wiki/` is one git repo that several sessions write to at once (different
subfolders). Two things to internalize:

- **Commit frequency does not make this safe.** Git only governs what's
  committed; two sessions editing the *same* file in the shared working tree is
  a filesystem race regardless of cadence. Safety comes from **partitioning**
  (the claims above — edit different subfolders) plus the staging rule below.
- **Stage only your own paths — never `git add -A` / `git add .`.** A blanket
  add sweeps another session's *in-progress* files into your commit. Always
  scope: `git add gridworks-scada/ && git commit …`.

Cadence and hygiene:

- **Commit at logical units, not per change** — one discovery pass or cleanup
  batch per commit (mirrors "one changelog entry per commit"). Per-file commits
  are noisy and buy no safety.
- **Push promptly** after a unit so other sessions can pull.
- **Pull at session start.**
- **Shared root files** (`README.md`, `GridWorks_CLAUDE.md`, `working-with-llms.md`, `glossary.md`, `active-work.md`) are the
  one real conflict zone: pull first, keep edits small, commit + push
  immediately.

Worktrees are intentionally **not** used for the wiki: a session typically edits
a code repo *and* its matching wiki domain together (launched from the umbrella
dir), so a wiki-only worktree would fragment that work. Revisit only if sessions
must edit the *same* subfolder concurrently or need isolated builds.

## Current claims

> Copy this file to `active-work.md` (gitignored) and replace the example row
> below with your own. Delete the example. One row per active session.

| Session | Repo / domain | Scope (path globs) | Status | Since | Notes |
| --- | --- | --- | --- | --- | --- |
| _example-session-label_ | `<repo>` + `wiki/<domain>` | `wiki/<domain>/**`, `<repo>/src/<area>/**` | active | YYYY-MM-DD | One line on what you're doing + anything another session should know (e.g. "will claim outside this scope HERE first"). Set `paused`/`done` when finished. |

## How to read this

- Two sessions in **different repos** don't collide — the table just makes that
  visible.
- The danger zones are shared files: `wiki/README.md`, `wiki/GridWorks_CLAUDE.md`, `wiki/glossary.md`, this
  file, and any domain a code-refactor session also documents in the wiki. If
  two rows overlap on a path glob, treat it as a conflict to raise.
