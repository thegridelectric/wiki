# gridworks-protocol (`gwproto`)

Status: Draft · Pass 0 · Updated 2026-05-26

> What this is: the rebuild spec for `gridworks-protocol`, the PyPI package
> historically known as `gwproto`. Acceptable-minimum; depth lives in
> `research/`.

## What it is today

`gridworks-protocol` (`gwproto`) is a Python package providing pydantic
boundary types and MQTT-flavoured message plumbing used by
`gridworks-proactor` and (transitively) by every service that runs on top
of the proactor — primarily `gridworks-scada`, plus the small helper
services `gridworks-uploader` and `gridworks-ingester`.

Concretely, on `dev` today the package contains:

- **`gwproto.message` + `gwproto.messages`** — the `Message`, `Header`,
  and `Ack`/`AnyEvent`/`EventBase`/`ProblemEvent`/etc. event family that
  the proactor uses as its on-the-wire envelope.
- **`gwproto.decoders` + `gwproto.default_decoders`** — `MQTTCodec`,
  `create_message_model`, and the cac/component decoder registry.
- **`gwproto.topic`** — `MQTTTopic`, `DecodedMQTTTopic`.
- **`gwproto.named_types`** — 53 Sema-style pydantic types (versioned
  with axioms, hand-edited, no longer code-generated).
- **`gwproto.enums`** — 34 Sema enums.
- **`gwproto.data_classes`** — `HardwareLayout`, `ShNode`, the
  `components/` family, etc.
- **`gwproto.type_helpers`** — `WebServerGt`, `RESTPollerSettings`,
  `URLConfig`, and friends.

It is hand-edited; the in-repo `CodeGenerationTools/` and `code_gen/`
directories were removed (commit `934dc77`, local on `dev`). New types
land via `/make-sema-word` discipline (see `sema/CLAUDE.md`).

## Why it exists — history

`gwproto` predates the current Sema discipline. It was Andrew's
**vertical packaging** for what used to be called an "Application Shared
Language" (ASL): one PyPI package shipping all the typed message
contracts a SCADA-AtomicTNode pair needed to talk. The repo's `README.md`
still uses ASL language — that framing is **legacy**; ASL has been
replaced by **Sema** everywhere else in GridWorks (see
`wiki/glossary.md` and `wiki/sema/`). The README needs an update; tracked
as a finding (see `research/`).

Over the past year nearly every Sema-governed type in `gwproto` has been
**ported to `gwsproto`** (the `packages/gridworks-scada-protocol`
package inside `gridworks-scada`), which is now the canonical home for
SCADA-side boundary types. What remains in `gwproto` is essentially a
mix of (a) the transport plumbing the proactor needs and (b) historical
content whose import sites in scada were never flipped to gwsproto.

## Categorization

Per the GridWorks repo-categorization vocabulary (3 axes):

- **Foundational-to-vision:** *low*. Not on the transactive-mechanism
  critical path. Marketmaker/LTN do not import it. Its role is plumbing
  for the proactor pathway.
- **Tool / package:** *yes, narrowly*. It is a published PyPI package
  (`gridworks-protocol`, currently 1.0.2) consumed as a dependency by
  proactor, scada, uploader, ingester. It is not a snapshot-source the
  way `sema` and `gridworks-base` are.
- **Battle-tested:** *yes, via proactor*. The proactor has run with 6
  heating systems in the field for 2 years; gwproto rides along on that
  track record because proactor depends on it.

## Relationship to its neighbours

- **`sema`** — Sema is the *discipline* (vocabulary, axioms, versioning,
  named formats). `gwproto` is *a consumer* of that discipline, like
  `gwsproto` is. Sema does not depend on `gwproto`.
- **`gwsproto`** — `gwsproto` is the SCADA-side Sema-governed boundary
  package and is the **long-term home** for the bulk of the types
  currently in `gwproto`. The split today is largely historical, not
  designed; `gwsproto` is where new SCADA-side types are added.
- **`gridworks-proactor`** — the primary consumer of `gwproto` today.
  Proactor's `Link`/transport machinery uses `Message`, `Header`,
  `MQTTCodec`, etc. from `gwproto`. The proactor itself has known issues
  (single-downstream `Link`, no direct-to-GNodeAlias addressing — see
  `wiki/gridworks-scada/research/concerns/transport-and-links.md`) and a
  larger refactor is anticipated.
- **`gridworks-scada`** — the largest consumer by import count (153
  files), but most of those imports point at types that **already exist
  in `gwsproto`** and only need their import path flipped. See
  `research/removing-unused-sema-from-gwproto.md` for the cleanup plan.

## Invariants

- Every type added to `gwproto` follows Sema discipline:
  `TypeName` + 3-digit `Version`, CamelCase JSON field names, named
  formats from `property_format` instead of inline primitive constraints,
  literal/versioned enums, append-only enum evolution. New types go
  through `/make-sema-word` (see `sema/CLAUDE.md`).
- `gwproto` is hand-edited. There is no live code-generation pipeline in
  this repo; legacy `CodeGenerationTools/` and `code_gen/` were removed.
- `gwproto` does not import from `gwsproto`. The dependency direction is
  one-way only (services depend on `gwproto`; `gwsproto` is independent).

## Forward path

The near-term forward path is **shrink, don't grow.** Most of what's in
`gwproto` either belongs in `gwsproto` (and is already there — just needs
scada to flip imports) or is provably dead. See
`research/removing-unused-sema-from-gwproto.md` for the keep/migrate/
delete plan and sequencing.

The longer-term question — what happens to the remaining
proactor-scoped surface when proactor itself is refactored — stays
**Open** until the proactor work is scoped. Possibilities include
absorbing the residual surface into proactor itself, into a renamed
package, or leaving it as a stable small `gwproto`.

## Glossary

- **gwproto** — this package; `gridworks-protocol` on PyPI.
- **gwsproto** — the SCADA-side companion at
  `packages/gridworks-scada-protocol` inside `gridworks-scada`.
- **ASL** — "Application Shared Language", the legacy name for what is
  now Sema. The `gwproto` README still uses this term; the rest of
  GridWorks does not.
- **Sema** — the vocabulary/axiom discipline that `gwproto` and
  `gwsproto` both follow. Lives in the `sema` repo.

## TOC

- `research/removing-unused-sema-from-gwproto.md` — full keep/migrate/
  delete plan based on import audit of proactor + scada (2026-05-26).
- (Open) `research/asl-to-sema-rename.md` — capture the README update +
  any in-code legacy ASL references.
