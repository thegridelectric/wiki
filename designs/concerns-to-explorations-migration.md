# Concerns → explorations migration

Status: Accepted · Pass 1 · Updated 2026-06-08

> What this is: the change plan to rename the wiki's `concerns/` folders to
> **`explorations/`** and **promote them to the domain root** (peer of
> `designs/`), updating every cross-reference. Cross-cutting tooling/convention
> change. Decided with the user 2026-06-08; deferred to a fresh session because
> it's a large, link-fragile refactor that also needs `sema/` coordination.

## Decision (settled)

- Rename `concerns/` → **`explorations/`** everywhere ("exploration" = curiosity,
  not dread).
- **Promote to the domain root**: `wiki/<domain>/explorations/`, a peer of
  `designs/`/`executor/` — *not* under `research/`. Mirrors the cross-cutting
  `wiki/explorations/` (peer of `wiki/designs/`).
- The **research → exploration → design ladder** (already in
  [`../glossary.md`](../glossary.md) "Where content lives"): `research/` =
  learning new things (loose, non-normative); `explorations/` = a question
  heaving into view (named, framed, not yet actionable); `designs/` = becoming
  actionable (ratified change plan).
- **The glossary is already updated to the target convention** (6 homes, the
  ladder, domain-root `explorations/`). This migration moves the *folders +
  links* to match.

## Scope — folder moves (domain root)

| Domain | From | Files |
|---|---|---|
| gridworks-admin | `research/concerns/` | admin-gateway-service, when-to-add-grpc |
| gridworks-base | `research/concerns/` | logging-for-observability |
| gridworks-fleet-index-service | `research/concerns/` | principal-model |
| gridworks-provisioning | `research/concerns/` | principal-kinds-extension |
| gridworks-scada | `research/concerns/` | deeds-and-trading-rights, layout-axiom-complexity, liveness-and-sla, non-gnode-interfaces, sema-style, transport-and-links |
| rmqbot | `research/concerns/` | granular-permissions-and-web-admin, mtls-fis-auth |
| gridworks-journalkeeper | `concerns/` (already root) | scale-strategy-starter |
| observability | `research/concerns/` (empty) | — (just remove the empty dir) |
| **sema** | `research/concerns/` | dashboard-vocabulary-modeling, rulebook-source-drift, two-claudes → into the existing `sema/explorations/` |

Each move: `git mv <domain>/research/concerns/*.md <domain>/explorations/` then
remove the now-empty `research/concerns/`. Leave the rest of `research/` intact.

## The hard part — relative-path depth changes

Promoting out of `research/` moves a file **up one level**, so cross-links must
be recomputed, not blind-replaced:

- **Links from non-moved files at depth 1** (executor/, designs/) using
  `../research/concerns/X.md` → `../explorations/X.md`. Here a substring swap
  `research/concerns/` → `explorations/` is correct (depth unchanged).
- **Cross-domain links *inside* the moved files** lose one `../`. Known cases:
  - `gridworks-admin/.../admin-gateway-service.md` → fleet-index `principal-model`
    (`../../../…/research/concerns/…` ⇒ `../../…/explorations/…`).
  - `gridworks-provisioning/.../principal-kinds-extension.md` → same target.
- **Wikilinks `[[…]]`** in `research/` files resolve relative to `research/`, so
  `[[concerns/X]]` / `[[../concerns/X]]` ⇒ `[[../explorations/X]]`. Cases:
  `gridworks-scada/research/{findings.md, map.md, components/contract-handler.md}`,
  `gridworks-protocol/designs/gwproto-shrink.md`.
- **Bare `concerns/` path refs** (no `research/` prefix): journalkeeper
  `concerns/scale-strategy-starter`, `rmqbot/research/broker-todos.md` `./concerns/`,
  `rmqbot/designs/analytics-broker-shovel.md` → journalkeeper, scada `PROCESS.md`.
  Handle per-case.
- **Prose mentions** of the English word "concerns" (not the folder) — leave
  alone (e.g. `economy-energy-markets`, `ear`, `gridworks-ltn` "known concerns").

## Infra + convention files to update

- `DESIGN_INDEX.md` — `## Concerns` → `## Explorations`; rewrite every entry path;
  **add the cross-cutting `wiki/explorations/` docs** (primary, home-assistant-ltn,
  aris-collaboration — they now fall under the rule).
- `tests/test_doc_health.py` — drift test `_index_drift("Concerns", "concerns")`
  → `("Explorations", "explorations")`; `_fs_under_dir` already finds
  `explorations/` at any depth.
- `GridWorks_CLAUDE.md`, `designs-process.md`, `README.md`, `working-with-llms.md`
  — `research/concerns/` → `explorations/` in convention text.
- `designs/linear-integration.md` (3 refs).

## Coordination caveat — `sema/` (BLOCKER)

`wiki/sema/` is **lush-spruce's active claim** (focus: untangle market.type.name).
Two couplings make sema unavoidable for a *clean* pass:
1. sema has its own concerns to move (3 files; `sema/explorations/` already exists,
   empty).
2. `sema/primary.md:50` links to **scada's** `…/research/concerns/sema-style.md` —
   moving scada's file breaks that link, and only the sema-owner may fix it.

So either: (a) wait until `wiki/sema/` is free and do it all in one pass, or
(b) have the sema session migrate sema's part + fix sema's links in coordination.
Do **not** half-do it across the boundary.

## Execution order (fresh session)

1. Confirm `wiki/sema/` is free (or coordinate with the sema session); `bulk-on`;
   claim all touched domains + the top-level convention files.
2. Move folders (all domains).
3. Rewrite cross-refs: bulk `research/concerns/` → `explorations/`, then fix the
   per-case exceptions above (cross-domain `../`, wikilinks, bare `concerns/`).
4. Update infra/convention files + `DESIGN_INDEX` + the drift test.
5. **Verify**: a link-resolution script (resolve every `](path)` and `[[path]]`
   against the filesystem; report danglers) **plus** the full doc-health suite.
   Iterate until both clean.

## On completion

Distil nothing to `executor/` (this is a pure convention migration). Delete this
design file; the convention lives in `glossary.md` + `designs-process.md`.
