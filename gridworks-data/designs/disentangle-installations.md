# Disentangle installations from journaldb

Status: Draft · Pass 0 · Updated 2026-07-30

**EDD: no** build-out/migration; verified by the suite plus row-level
checks against the live database at each step, not a standalone
experiment.

> What this is: split the `gridworks.installations` table's four kinds of
> data into their right homes, retire the JSONB copies, and stand up the
> remote PII database that customers link to by opaque id. Ours to design
> and deploy, with a heads-up to Joe (he is transitioning from database
> work to heat pump + electronics).

## The problem

`installations` (6 rows, one per house, in journaldb — the managed
Timescale Cloud service) is the join point the dashboard needs, and four
kinds of data with four lifecycles have grown onto it:

1. **Identity/topology** — `g_node_id`. Right idea, now with an
   authoritative upstream: the registry projection (`g_nodes` via
   `g.node.forest`, OPS-386's fan-out).
2. **Engineering config as unversioned JSONB** — `hardware_layout`,
   `house_parameters`. Sema owns this meaning; hardware layout and
   operational params are being sema-fied right now
   (hardware-layout-pass-one, OPS-407), with the terminalasset-registry
   (OPS-471) as the durable home. A second schemaless copy is semantic
   drift by construction.
3. **Mutable ops state without provenance** — `scada_ip_address`,
   `scada_git_commit`, `alert_status`. State-without-events; stale the
   moment a box pulls. `alert_status` is the home-specific alert data
   OPS-295 already says should not live where it lives.
4. **PII and credentials** — `address` (JSONB blob), `customers`'
   contact blobs, and `users.hashed_password`: auth credentials and
   customer PII inside the analytics database whose access model is
   handing out read credentials.

Schema fact (verified live 2026-07-30): the deployed `gridworks` schema
carries NO foreign-key constraints referencing `g_nodes` — the models
declare them, production does not have them.

## Why PII does not go to the persistent store

The store's defining feature is immutability: witnessed forever,
replayable, hash-pinned. PII demands the opposite — deletability, access
control, a retention story. Emitting contacts and addresses into an
immutable store converts a privacy obligation into a permanent
liability. The house pattern is already established by gnr's position
points: **opaque identity in the open system; sensitive data held
separately by the party that owns it, encrypted, deletable.** Customers
get the same treatment: an opaque `customer_id` in gw_data, the person
behind it in a remote PII database.

## Target

- **`installations` retired from journaldb.** What survives in gw_data
  is the join the dashboard needs: `g_node_id` (projection-owned) ↔
  `customer_id` (opaque) ↔ `installer_id` (opaque), plus
  `display_name`. Whether that is a slimmed `installations` or a view
  over `g_nodes` + a small link table is an open call for pass one.
- **Hardware layout + operational params**: consumed from their sema
  words once the sema-fication lands; the JSONB columns are deleted, not
  migrated (the words are the truth; history is in the persistent
  store).
- **New seed / PII database for customers.** Small, remote, its own
  access control and backup story; holds contacts, addresses,
  service-relationship data; keyed by the opaque `customer_id`.
  Gate: starts after the hardware-layout/operational-params
  sema-fication completes (in flight now).
- **Auth out of gw_data**: `users` / `hashed_password` /
  `user_installation_roles` move to the web-backend's own identity
  store. Read credentials to the analytics database must never include
  password hashes again.
- **`alert_status`** moves with the alerting modernization (OPS-295 and
  the gwalert/alert-manager rework) — its state belongs to the alerting
  system, not the journal.
- **Ops facts** (`scada_ip_address`, `scada_git_commit`): dropped here;
  the fleet inventory and (eventually) provisioning own them.

## Sequencing

1. NOW (short-run fixup, precondition shared with OPS-386 item #5): re-id
   the six January-seeded `g_nodes` rows to the registry's GNodeIds and
   update `installations.g_node_id` to match — no FK blocks it; script in
   the gjk repo.
2. gw_data schema alignment (with OPS-386 item #5): drop declared FKs the
   deployment never had (position_point_id coupling included), add the
   sent-time columns.
3. After sema-fication lands: stand up the PII database; migrate
   customers/contacts/address; swap `installations` to the slim join;
   delete the JSONB columns; move auth to web-backend.
4. Each step lands with a row-level check against the live database
   (counts + spot joins), and the dashboard keeps working throughout —
   the web api reads are the compatibility constraint to walk carefully.

## Open

- Slim-table vs view for the surviving join.
- PII database concrete shape (managed Postgres vs something smaller) and
  its encryption-at-rest posture.
- Installer records: same PII treatment as customers, one tier lighter.
