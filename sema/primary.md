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
| `sema/effortless_CLAUDE.md` | the **committed, team-shared** ERB-lens working rules (rulebook-as-SSoT, `effortless build` discipline). |
| `sema/CLAUDE.md` (gitignored) | **per-developer personal lens** — typically the dev-branch sema-vocabulary frame (`spec/primary.md`, `/make-sema-word`, axiom/registry invariants). The two-lens pattern is intentional; see [`research/concerns/two-claudes.md`](research/concerns/two-claudes.md). |
| `sema/README.md` | repo landing page, including the "Why this matters" motivation that used to live in `sema/docs/motivation.md`. |
| `wiki/sema/research/` | GridWorks-specific context that used to live in `sema/docs/`: `where-meaning-lives-in-gridworks.md`, `sema-and-domain-protocols.md`. |

## Why this wiki domain exists at all

(a) record the **WHY** of notable sema changes in
[`changelog.md`](changelog.md) (the in-repo commits hold the WHAT); (b) be
the resolution target for cross-domain links to "sema"; (c) hold ratified
design-specs in [`designs/`](designs/) and open architectural questions
in [`research/concerns/`](research/concerns/) — per
[`../designs-process.md`](../designs-process.md). Design *depth* for the
in-repo spec stays in `sema/`; the wiki holds GridWorks-side intent and
investigations that don't belong in the language spec itself.

## Cross-references for common gotchas

Sema concepts that consumers regularly trip over (each defers to the
canonical definition in `sema/spec/`):

- **`LeftRightDot` format word** governs `GNodeAlias` and any "grid
  address" string — see [`../glossary.md`](../glossary.md) for the
  one-line grammar; canonical definition in `sema/spec/`.

## Cross-links

- The gridworks-base **codec layer** is the Sema runtime in the actor framework;
  the `gw` / `gridworks.header` envelope types live in sema and are consumed
  there → [`../gridworks-base/executor/codec.md`](../gridworks-base/executor/codec.md).
- SCADA boundary types (`gwsproto`) follow Sema rules →
  [`../gridworks-scada/research/concerns/sema-style.md`](../gridworks-scada/research/concerns/sema-style.md).
- Legacy naming `ASL` → Sema → [`../glossary.md`](../glossary.md).
