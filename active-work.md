# Active work — multi-session coordination

Jessica runs **2–4 Claude sessions at once** across the GridWorks repos (and
this wiki). This file is the **well-known place to declare who is editing
what**, so sessions don't collide. It is the single coordination point across
*all* repos — git worktrees isolate within one repo, but only this registry
makes cross-repo work visible.

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
- **Shared root files** (`primary.md`, `glossary.md`, `active-work.md`) are the
  one real conflict zone: pull first, keep edits small, commit + push
  immediately.

Worktrees are intentionally **not** used for the wiki: a session typically edits
a code repo *and* its matching wiki domain together (launched from the umbrella
dir), so a wiki-only worktree would fragment that work. Revisit only if sessions
must edit the *same* subfolder concurrently or need isolated builds.

## Current claims

| Session | Repo / domain | Scope (path globs) | Status | Since | Notes |
| --- | --- | --- | --- | --- | --- |
| scada-wiki-bootstrap | `wiki/` + `gridworks-scada` | `wiki/gridworks-scada/**`, `wiki/primary.md`, `wiki/glossary.md`, `wiki/active-work.md`, `gridworks-scada/CLAUDE.md` | active | 2026-05-21 | Wiki bootstrap + process design; CLAUDE.md change pending Jessica's commit |
| gridworks-base-refactor | `gridworks-base` + `wiki/gridworks-base` | `gridworks-base/**`, `wiki/gridworks-base/**` | active | 2026-05-21 | Transport/codec decouple + drift-proof rabbit topology. uv migration committed (`a64b3c0`); `gwbase/topology.py` done; executing actor_base passive-declare + broadcast/scada helpers + definitions generator/CI/GHCR image. Will claim any folder outside this scope HERE before editing it. (Earlier this session, before this file existed, I also created unclaimed cross-domain docs: `wiki/{ear,rmqbot,gridworks-proactor}/`, `wiki/heating-system-design/research/`, top-level `CLAUDE.md` — left as-is, up for grabs.) |

## How to read this

- Two sessions in **different repos** don't collide — the table just makes that
  visible.
- The danger zones are shared files: `wiki/primary.md`, `wiki/glossary.md`, this
  file, and any domain a code-refactor session also documents in the wiki. If
  two rows overlap on a path glob, treat it as a conflict to raise.
