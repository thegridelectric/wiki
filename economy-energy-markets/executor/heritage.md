Status: Draft · Pass 0 · Updated 2026-06-07

> What this is: the heritage register for the Economy Energy
> Market System domain. Records concepts from earlier GridWorks
> work (TER Initiative, Redefining Demand Response / Algorand
> grant, G-Node Factory, VCharge) that are part of the
> ecosystem's lineage but are NOT active commitments of the
> current spec. Preserved for provenance and to prevent
> Pass-2-onward batches from re-debating already-triaged items.

## How heritage relates to current architecture

Heritage items fall into two categories:

- **HERITAGE** — the concept is part of the lineage; the
  current spec is silent on the question and importing the
  legacy answer would be making a commitment by the back
  door. Cited here for provenance.
- **SUPERSEDED** — the concept has been *explicitly* replaced
  by a Pass 1 decision. The supersession itself is recorded
  so future readers understand the migration.

## Batch 1 heritage items (Pass 2, 2026-06-07)

Triaged from `legacy/g-node-factory/docs/wiki/ta-deed.md`,
`legacy/gridworks/docs/ta-deed.rst`, and
`legacy/gridworks/docs/ta-validator.rst` — the 2021–2022
ReadTheDocs and G-Node Factory wiki sources for the TaDeed
and TaValidator concepts.

- **TaDeed as Algorand NFT.** HERITAGE. The 2021–2022 design
  expressed TaDeeds as Algorand Standard Assets (ASAs) or
  Smart Signatures, with multi-signature creation between the
  GNodeFactory administrative account and a TaValidator
  account. The current spec (invariant 14) commits to
  *framework-agnostic* Participation Requirements; the
  cryptographic-NFT expression is one mechanism among
  several, not the architecture.
- **"Link of trust" framing.** HERITAGE. The 2021 ReadTheDocs
  source described TaValidators as establishing "links of
  trust" between Transactive Devices and TerminalAssets,
  reducing counterparty risk in market transactions. The
  current spec calls this Participation Requirements
  (invariant 14) plus the three-item architectural
  attestation (invariant 8 / `actors.md`). The 2021 framing
  is the conceptual ancestor.
- **Algorand-specific TaDeed mechanics.** HERITAGE. ASA vs
  SmartSig variants, 32-character GNodeAlias length limit on
  ASA TaDeeds, the Algorand multi-sig conventions. These are
  blockchain-platform implementation details; the
  framework-agnostic commitment (invariant 14) supersedes
  them as the architectural posture.
- **GNodeFactory as central registry.** SUPERSEDED. The
  2021–2022 architecture placed a "GNodeFactory" at the
  center, co-creating TaDeeds with TaValidators via
  multi-signature. The current spec assigns the per-NEPOOL
  trust-anchor role to the **TaReader** (invariants 4 + 5);
  the joint-signature pattern survives in spirit at the
  TaReader ↔ TaValidator boundary.
- **Triangle of Validation** (GNodeFactory ↔ TaValidator ↔
  TaOwner). HERITAGE. Conceptual ancestor of the current
  TaReader ↔ TaValidator ↔ TaOwner trust triangle. The
  topology of the trust triangle is unchanged; the central
  vertex has been redrawn as the TaReader.
- **GNodeFactory-tied attestation items.** SUPERSEDED. The
  2021 TaDeed validation included "parent GNode exists in
  GNodeFactory" and "no intermediate GNodes on the copper
  spanning tree." Both required the GNodeFactory to be the
  canonical GNode registry. With the TaReader as per-NEPOOL
  trust anchor today, copper-tree integrity is a TaReader
  concern, not a per-install TaValidator attestation.
- **Financial assurance via 100-Algos TaMulti funding.**
  HERITAGE (not in current spec). The 2021 design required
  100 Algos to be staked in the TaOwner multi-signature
  account as financial assurance, scaling with monthly
  transaction size. The current spec uses the SLA as the
  contract instrument (invariants 10 + 16) and does not
  have an explicit financial-assurance mechanism at the
  TaDeed level.

## Pending heritage from upcoming Batches

(Reserved for Pass 2 Batches 2+ — TER Initiative PDFs,
Redefining Demand Response / Algorand grant materials,
g-node-factory wiki concepts not yet triaged. See
[`../scratch.md`](../scratch.md) for the source list.)

## See also

- [`../scratch.md`](../scratch.md) — Pass 2 source list and
  per-batch triage memos
- Invariant 14 in [`primary.md`](primary.md) — framework-
  agnostic Participation Requirements (supersedes
  Algorand-specific TaDeed implementations)
- Invariant 4 in [`primary.md`](primary.md) — TaReader as
  trust anchor (supersedes GNodeFactory central-registry
  role)
