# Content-address & deterministic ids — why the command hash is NOT a sema format

Status: Draft · Pass 0 · Updated 2026-07-03

> What this is: the reasoning behind a deliberate **non-decision** — the registry's
> command content-address (`gnr.ids.command_hash`) stays a **gnr-internal** dedup key
> and is *not* lifted into a Sema format. Recorded so a future agent (tempted to
> "formalize the id-derivation in the shared vocabulary for the blockchain future")
> doesn't bake in a scheme the eventual chain won't use.

## The context

For distributed-readiness (see executor *Distributed-readiness*), `apply_reparent`
is deterministic and appends every mutation to an append-only `command_log`, keyed
by a **content hash** of the command's canonical bytes (`command_hash` = SHA-256 hex
of `cmd.to_bytes()`). The tempting next step was to make that content-address a
**Sema format** (like `uuid4.str` is for GNodeIds), on the theory that on a chain
these ids become a public cross-implementation contract.

## Why we did NOT make it a Sema format

**Transaction/content hashes are chain-specific — different algorithm *and*
encoding — so there is no single "command hash type" to formalize:**

| Chain | Hash of the canonical tx | Encoding |
|---|---|---|
| Algorand | SHA-512/256 | base32 (no padding) |
| Ethereum | Keccak-256 (not NIST SHA3) | hex (`0x…`) |
| Bitcoin | double-SHA-256 | hex (byte-reversed) |

Each chain also hashes a *different canonical encoding* of the transaction (Algorand
msgpack, Ethereum RLP), so even the pre-image bytes differ. A fixed `sha256.hex`
format would presume a hash our eventual chain almost certainly won't use, and
dignify a local implementation detail as a public contract. Premature and likely
wrong.

## What we do instead

- **`command_hash` is a local idempotency / dedup key** for the `command_log`
  primary key on the single-writer Postgres — stable and collision-free *for us*,
  nothing more. It is **not** a chain transaction id and must not pretend to be.
  Stays gnr-internal.
- The **real content-address is defined by whichever chain we pick**, and that lives
  behind the **`AuthoritySource` seam** (the point of the seam is a swappable backing
  store + identity scheme). A chain impl computes tx-ids the chain's way; the
  Postgres impl uses its local key. Adopt the chain's scheme when the chain work is
  actually on the table.
- **`edge_id` is a different animal.** The edge id is a *GridWorks-domain* value
  (`uuid4.str`, chain-independent) that serializes into `g.node.forest`. Only its
  *derivation rule* (derive from the two endpoint GNodeIds so a replicated backend
  computes the same id) is ours to specify — a possible future **axiom** on
  `connectivity.edge.gt`, not a chain concern and not a format. Deferred; the
  derivation currently lives in `gnr.ids` (internal salts, clearly not Sema names).

## The rule this leaves

Deterministic ids that end up in **authoritative state** (edge ids in the forest)
are derived, reproducibly, in `gnr.ids` — that is the load-bearing "shape." The
content-address's *canonical public form* is **machinery of the chosen chain**, so
it is deferred to that integration rather than fixed now. "Shape, not machinery."
