---
description: Add or modify a sema word.
---

You are about to add or modify a sema word. You MUST:

1. Read `sema/CLAUDE.md`. If absent, STOP and surface.
2. Read `sema/spec/primary.md` plus the spokes covering the word
   kind (format / enum / type) you are touching: the matching file under
   `sema/spec/registry/` and under `sema/spec/authoring/`. For
   types, also read `authoring/type-semantics.md`.
3. Read `wiki/active-claims.md`. If `sema/` is in another session's
   scope, STOP and raise.
4. Read 2–3 recent entries of the same kind from the registry to
   match format exactly.

Then summarize, for the kind (format / enum / type) you are touching:

1. The registry entry rules
2. The authoring (schema file) rules
3. The dependency rules
4. The axiom and projection rules — if your word will declare them

A faithful summary is the verification that you actually loaded the rules.
If you cannot summarize a section, re-read it.

Before editing, state to the user:
- the word, its kind, and which spec section governs it,
- the registry + vocabulary + index files you will touch,
- the regen command(s) you will run after.

Then WAIT for confirmation.
