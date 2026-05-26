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

Once the user confirms, BEFORE making any edit:

1. Verify your `wiki/active-claims.md` row covers `sema/`. If not,
   claim it (one row update). Touching `sema/` files without a matching
   claim is a violation of the active-claims protocol.
2. Create a new feature branch in `sema/`:

   ```
   git -C sema checkout -b <handle>/<short-topic>
   ```

   Use the convention `<handle>/<short-topic>` — e.g. `jm/weather-v000`,
   `jm/add-glitch-axiom`. The handle is the user's; default to `jm` for
   Jessica. The `git checkout -b` triggers the multi-session
   PreToolUse hook (`wiki/tools/precheck-claims-on-branch.sh`), which
   re-injects the umbrella CLAUDE.md's Multi-session section + the
   current active-claims.md — a natural re-read of the protocol at
   the right moment.
3. Only after the branch is created may you edit files in `sema/`.

This branch-first step exists because per-word ritual edits should land
on a feature branch (not directly on `dev` or `main`), and the hook
re-read is the structural reinforcement of the active-claims protocol
that the in-Claude prose can't supply on its own.
