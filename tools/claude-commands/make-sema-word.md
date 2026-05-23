---
description: Add or modify a sema word — loads sema's sub-CLAUDE.md and ritualizes the registry/index discipline
---

# /make-sema-word — protocol-loading slash command

> **Scaffold.** The exact protocol is canonicalized in `sema/CLAUDE.md` by the
> upcoming sema/ERB-integration design session. This command's job is to
> *force the load* and *ritualize the discipline* so Claude-in-other-repos
> does not skip steps.

You are about to add or modify a **sema word**. Before any edit:

1. **Read `sema/CLAUDE.md`** (or `sema/draft_CLAUDE.md` if the canonical file
   is not yet committed) and follow its protocol verbatim. **If neither file
   exists or it is silent on the operation you're about to perform, STOP and
   surface that to the user — do not invent the protocol.**
2. **Read the sema specifications hub** (`sema/docs/sema-specifications.md`)
   to know which spec the word belongs under.
3. **Check `wiki/active-claims.md`** — if `sema/` is in another active
   session's scope, stop and raise it.

**Universal discipline (per the failure modes the user has observed):**

- Edit through the **registry** — never bypass it by writing a raw file.
- After registry changes, **rebuild any dependent indexes**. Do not assume
  they regenerate automatically; check `sema/CLAUDE.md` for the exact
  commands.
- Match the **format of existing words exactly** — confirm by reading 2–3
  recent entries before drafting yours.
- Stage only your own paths when committing (see `GridWorks_CLAUDE.md`
  "Commit suggestions"). Never `git add -A` in sema.

**Before editing**, state to the user:
- the word you intend to add or modify,
- which sema specification it falls under,
- what registry + index files you'll touch,

and wait for their confirmation.
