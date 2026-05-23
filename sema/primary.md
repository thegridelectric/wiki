# sema — domain (pointer)

> **Intentionally minimal.** `sema/` is self-describing and **designed as a
> source of truth**, so this wiki domain does not duplicate it — it points back.
> There is **no wiki `executor/` for sema**: the in-repo spec *is* the rebuild
> spec.

## What sema is (one line)

Boundary infrastructure — versioned JSON-Schema contracts for serialized
messages exchanged between independent systems; the **authority over meaning**.
Not a runtime framework.

## Canonical sources — in the `sema/` repo (normative; read these, don't restate)

| Source | Covers |
|---|---|
| `sema/spec/primary.md` | **THE spec hub** — core principles, glossary, TOC. The rebuild spec; spokes live under `sema/spec/{registry,authoring}/` and `sema/spec/governance.md`. The previous monolithic version is archived at `sema/docs/orig-spec.md`. |
| `sema/CLAUDE.md` | working rules for editing sema; regen commands (`scripts/build_indexes.sh`, `scripts/regenerate_runtime.py`). |
| `sema/docs/where-meaning-lives-in-gridworks.md` | the semantic-authority philosophy. |
| `sema/docs/` | motivation, project-structure, sema-and-domain-protocols, scada-layout-concerns. |

## Why this wiki domain exists at all

Only to (a) record the **WHY** of notable sema changes in
[`changelog.md`](changelog.md) (the in-repo commits hold the WHAT), and (b) be
the resolution target for cross-domain links to "sema." Design depth stays in
`sema/`.

## Cross-links

- The gridworks-base **codec layer** is the Sema runtime in the actor framework;
  the `gw` / `gridworks.header` envelope types live in sema and are consumed
  there → [`../gridworks-base/executor/codec.md`](../gridworks-base/executor/codec.md).
- SCADA boundary types (`gwsproto`) follow Sema rules →
  [`../gridworks-scada/research/concerns/sema-style.md`](../gridworks-scada/research/concerns/sema-style.md).
- Legacy naming `ASL` → Sema → [`../glossary.md`](../glossary.md).
