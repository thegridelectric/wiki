# Positions — identity now, encrypted data later

Status: Draft · Pass 0 · Updated 2026-07-04

> What this is: the plan for launching + populating the MVP registry (on EC2) with
> an **open** API while keeping home locations **private + encrypted**. The move is
> to separate a location's **identity** (assignable now) from its **coordinate data**
> (encrypted, populated later by TaValidator). Companion to
> [`position-point-semantics.md`](position-point-semantics.md) (why gnr enforces
> nothing about positions).

## The goal

Launch + populate the MVP gnr on EC2. The topology (GNodes, aliases, edges, the
forest) is meant to be **as open as possible**. But `PositionPoint`s are **lat/lon
of homes** — the crown jewels (resident physical security) — so they must be
**private and encrypted**. And we want to populate `g_nodes` **before** the
TaValidator work exists.

## The lucky head start: the API never exposes coordinates

`g.node.gt` carries a `PositionPointId` (an opaque UUID ref), and every read
endpoint (`g-node-forest-request`, `g-node-by-id`, `g-node-by-alias`) returns
`g.node.gt`s + edges — **never** `PositionPointGt` (the lat/lon). So the open API
leaks topology (wanted) while geography stays behind an opaque id. Invariant to
hold: **`position_point_id` MUST be a random UUID, never derived from the
coordinates** — else the id itself leaks location.

## Identity vs. data (the staging)

- **`position_point_id` = the location's IDENTITY** — an opaque UUID, **carried in
  the g.node.gt/command** when a GNode is created. It satisfies per-row axiom 2
  (physical ⇒ `position_point_id` not null — the *id*, not the coordinates), it is
  deterministic-by-record (the carried-id case, not handler-minted — see executor
  *Distributed-readiness*), and it leaks nothing.
- **The coordinate DATA (encrypted) is a separate, later, differently-owned
  artifact** — populated by **TaValidator** with the encryption mechanism below.

**Schema consequence (done):** `g_nodes.position_point_id` is a plain `UUID4Str`
column, **not an FK** to `position_points`. An enforced FK from gnr into a table
gnr write-only-populates-later (or doesn't own at all) is the wrong coupling: gnr
owns **identity + topology**; the **(encrypted) geography** is owned elsewhere. The
migrations were squashed to a single FK-free baseline (gnr isn't deployed, so
nothing to migrate). No sema change — axiom 2 stays.

**So for the MVP launch:** populate `g_nodes` with opaque `position_point_id`s,
leave `position_points` **empty**.

## The encryption mechanism (deferred to the TaValidator step)

When positions are populated, protect `position_points`:

1. **Baseline — encryption at rest** (always on): RDS storage encryption, or EBS if
   self-managed on EC2 (both KMS-backed). Protects disks + backups; insufficient
   alone (a DB user / the app still sees plaintext).
2. **The real control — application-level *asymmetric* encryption of lat/lon.** On
   ingest the coordinates are encrypted with a **public key**; only ciphertext is
   stored; gnr **holds no private key**, so a compromised gnr box *or* a leaked DB
   yields nothing. Only a privileged reader (TaValidator / a mapping-analytics
   service) holds the **private key** and can decrypt. This is *gnr is write-only for
   coordinates* — the position-point-semantics principle in the crypto layer. Avoid
   symmetric-key-in-gnr-config (a full-box compromise gets key + ciphertext together).
3. **Never expose coordinates on the open API.** A coordinate read, if ever needed,
   is a separate authenticated surface served by the private-key holder — not gnr's
   open API. Geo-queries (if any) run in that privileged reader.

## Open decisions (settle at the TaValidator/deploy step)

- **`position_points` shape** changes then: `latitude_micro_deg`/`longitude_micro_deg`
  → an **encrypted-coordinate** column (ciphertext + `key_id`/`alg` metadata).
- **Where the coordinates live:** an encrypted column **in gnr's DB**, *or* a
  separate **TaValidator-owned vault** keyed by `position_point_id` (gnr never holds
  coordinates even encrypted — strongest privacy). MVP could start with the former;
  the FK drop keeps both open.
- **Crypto substrate:** `pgcrypto` `pgp_pub_encrypt` vs AWS KMS envelope encryption
  (`kms:Decrypt` gated to the one reader's IAM role).

## Stale PositionPointIds in old tlayout outputs — do not use

The pre-registry `tlayouts/output/*.json` files assign each GNode a
`PositionPointId` that does NOT match the registry's (verified 2026-07-30:
beech LTN is `4f2ce336…` in the live registry, `9756f665…` in
`beech.generated.json`). Neither set carries coordinates — the tlayout ids
are bare identities minted before the registry existed, with no data value
to harvest. When position points get populated (the work above, alongside
the mTLS/validator plane), the registry's ids are the fleet's location
identities; the tlayout ids are historical artifacts to ignore, and any
document or tool still holding one needs re-pointing, not honoring.
