# Positions — identity now, encrypted data later

Status: Draft · Pass 0 · Updated 2026-08-05

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
4. **The ciphertext never rides the bus.** gnr writes normally travel rabbit, and
   the ears archive everything said to the registry in immutable stores — a
   position-registration *command* would immortalize every ciphertext version in
   archives that cannot be rewritten, defeating key rotation and re-encryption.
   The security property depends on it: a leaked private key with no ciphertext
   to apply it to yields nothing. So position registration is the one deliberate
   exception to writes-ride-rabbit: the TaValidator submits ciphertext over a
   narrow authenticated HTTPS surface (the mTLS validator plane), and gnr
   publishes a registration event carrying only the `position_point_id` and a
   hash of the ciphertext, so the bus witnesses the fact while the ciphertext
   stays in a single mutable store. Consequence: gnr's DB backup story
   (encrypted dumps, tested restore) is the location data's durability — the
   only registry data not reconstructible from the bus archives.

## Settled direction (2026-08-05) + what remains open

- **Where the coordinates live: an encrypted column in gnr's DB.**
  `position_points` becomes ciphertext + `key_id`/`alg` metadata (replacing
  `latitude_micro_deg`/`longitude_micro_deg`), the row created when the
  TaValidator registers the location — a row exists iff a registered
  (encrypted) location exists. The separate-vault option is dropped: it adds
  a service and weakens the activation gate to a cross-service attestation,
  while the asymmetric scheme already means a compromised gnr yields nothing.
- **Lifecycle: pending-first.** A GNode is created Pending with NO
  `position_point_id` (constraint on `g.node.create.cmd`, since creation is a
  command); the id + row appear at registration over the HTTPS surface; a
  Pending node MAY hold a registered id (registration and activation are
  separate acts on separate planes); activation of a location-bearing GNode
  requires it. This replaces g.node.gt axiom 2 (`BaseClass != Logical ⇒
  PositionPointId not null`) with an activation-conditioned form —
  a `g.node.gt/006` bump plus referrer cascade (`g.node.forest`,
  `g.node.create.cmd`, consumer snapshot regens). The registrar-minted UUID at
  creation (today's mechanism for satisfying axiom 2) goes away with it.
- **FK restored in the same change:** once a non-null `position_point_id`
  implies its row exists, `g_nodes.position_point_id` becomes a nullable FK
  into `position_points`.
- **Open — the location-bearing predicate:** axiom 2's current test is
  `BaseClass != Logical`, which includes e.g. Scadas. Which classes must hold
  a position to go Active (only the copper — ConnectivityNodes +
  TerminalAssets?) needs settling before the /006 bump.
- **Open — crypto substrate:** `pgcrypto` `pgp_pub_encrypt` vs AWS KMS envelope
  encryption (`kms:Decrypt` gated to the one reader's IAM role).
- **gw_data side (pending discussion with the gw_data maintainer):** drop
  `gw_data.position_points` and its FK; the projection stores the opaque id
  verbatim (the current fan-out nulls it because the FK target row can never
  exist). Ciphertext never reaches gw_data — it consumes the bus interface,
  and the bus never carries ciphertext.

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
