# Disentangle installations from journaldb (hub)

Status: Accepted · Pass 1 · Updated 2026-10-20 · Linear: OPS-473

**EDD: yes** two runs verify it. The dev run proves the mechanism on
the laptop's `d1` stack before anything merges to `main`: a simulated
scada's `layout.lite` goes over a real broker into a `layouts` row that
the summaries and the gateway read, and no response has a person.
Onboarding cedar end to end proves the path in production after launch:
the pending TerminalAsset enters the registry, its customer enters the
PII store minutes later, the dashboard shows the house, and nothing
about a person touches the broker, the persistent store or journaldb.

**▶ Active spoke: [`retire-installations.md`](retire-installations.md)**

> What this is: the hub for taking customer PII and auth credentials out
> of journaldb, retiring the `installations` table, and standing up
> `gridworks-pii`, the private store that is the only place a person is
> linked to a house. Linear OPS-473. Ours to design and deploy, with a
> heads-up to Joe.

## The problem

`installations` in journaldb (six rows, one per house, in the managed
Timescale Cloud service) is the join the dashboard needs, and four kinds
of data with four lifecycles have grown onto it: identity (`g_node_id`,
now owned by the registry projection); engineering config as unversioned
JSONB (`hardware_layout`, `house_parameters`, which sema owns); mutable
ops state without provenance (`scada_ip_address`, `scada_git_commit`,
`alert_status`); and PII and credentials (`address` with latitude and
longitude, the `customers` contact blobs, `installers.info`,
`users.hashed_password`) inside the analytics database whose access model
is handing out read credentials. The deployed schema has no foreign-key
constraints referencing `g_nodes` (verified live 2026-07-30); the models
declare them, production does not have them.

## Principles

- **PII is never on the broker or in the persistent store.** The store's
  defining feature is immutability: witnessed forever, replayable,
  hash-pinned. PII demands the opposite: deletability, access control, a
  retention story. The ears archive the bus immutably, so even a
  ciphertext on the bus could never be retired by a key rotation.
- **The TerminalAsset GNodeId is the only link between a house and a
  person.** No `customer_id` exists anywhere in the open system. The
  customer-to-house relation lives only in gridworks-pii. The TaDeed's
  `TaId` is the same GNodeId (beech: deed and layout agree on
  `7e152072-c91b-49d2-9ebd-f4fe1b684d06`), so the customer record and the
  deed share one anchor, and a record can exist while the TA is Pending.
- **A fifth kind of data.** The data architecture names Sema, the seed
  databases, the persistent store and projections. Private data held by
  the party that owns it is none of these: never on the broker, never a
  sema instance on the wire, rebuildable only from its own encrypted
  backups. The registry's encrypted coordinates are the first instance,
  the customer record the second. This paragraph is owed to
  `gridworks-infra/data-architecture.md` "Where meaning lives" as item 5.
- **Outside the production system.** gridworks-pii is not a broker-native
  microservice, so the one-service-per-database rule does not apply: an
  operator CLI writes, web-backend's read-only role reads, no service in
  front. Its shapes are not sema words; one shared package owns them.
- **No coordinates.** Street address and ZIP are enough. Coordinates are
  the TaValidator's artifact and exist only encrypted in the registry's
  own store; the latitude and longitude in journaldb's address blob are
  deleted, not migrated.
- **Partners never see a GNode alias or GNodeId.** The alias is public
  topology and the journal publishes live telemetry under it; pairing it
  with a person anywhere outside gridworks-pii turns public readings into
  a named household. GridWorks mints partner labels; the mapping is a
  table in gridworks-pii.
- **An installation summary is a read-time composition in web-backend,
  stored nowhere.** No summaries table exists in the TAR, gw_data or
  anywhere else. The TAR holds layouts and operational params and nothing
  about people.

## Spokes, in order

1. [`pii-store.md`](pii-store.md) ✅ — the `gridworks-pii` repo, box,
   record shape, operator CLI, partner labels, seed from journaldb.
2. **[`retire-installations.md`](retire-installations.md)** — gw_data,
   web-backend and frontend branches; the tables go; roles re-key to the
   TA GNodeId; the dashboard's Address and Contact sections go dark
   until OPS-600.
3. [`latest-layout-projection.md`](latest-layout-projection.md) — gjk
   keeps one current layout row per terminal asset in `layouts`, the
   `g_nodes` pattern, filled by `layout.lite` now and by a staging
   `layout.bundle` word (the layout twin of `g.node.forest`) from the
   registry later; summaries, gateway and visualizer read it by key.
4. [`dev-run.md`](dev-run.md) — the EDD run on the laptop's `d1`
   stack: broker, database, gjk, API, gateway, frontend and a sim scada;
   the gate before any branch merges to `main`.
5. [`onboard-cedar.md`](onboard-cedar.md) — the production EDD run, after
   launch: cedar enters the registry and the store through the new path.

## Out of scope, named by their own issues

- The JSONB layout and params copies are deleted here; the durable home
  for layouts is the terminalasset registry (OPS-471), and the
  projection spoke is written so the registry becomes its writer when
  it exists. Nothing here waits on it.
- `alert_status` is dropped here; alert state belongs to the alerting
  rework (OPS-295).
- Scrubbing partner engineering documents (interior photos, EXIF GPS,
  analyst emails on cover pages) before any content reaches an open home.
- The web-backend login hardening and web-backend's read-only role on
  the store (OPS-600). The dashboard's Address and Contact sections stay
  dark from retire-installations until it ships; operators use the CLI.
- Passkeys and per-act step-up for humans (FIS invariant 5); they come
  with a web-based PII write path if one is ever wanted.

## Notes

- Decided in a grill session 2026-10-15; research on partner labels and
  data-sharing practice with sources in
  `scratch/2026-10-15-partner-labels.md`.
