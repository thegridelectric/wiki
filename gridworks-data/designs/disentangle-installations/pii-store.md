# pii-store — the gridworks-pii repo, box and CLI

Status: Accepted · Pass 1 · Updated 2026-10-15 · Linear: OPS-473

> What this is: the first spoke of the disentangle-installations hub.
> Stand up `gridworks-pii`: a private repo, a small box with a loopback
> Postgres on an encrypted volume, one package that owns the record
> shape, an operator CLI that writes over an SSH tunnel, and the seed of
> the six existing houses from journaldb.

## Do this next

Done 2026-10-15: the repo, the box and the seed. The six houses are in
the store with their labels, the journaldb side is untouched. The work
moves to the retire-installations spoke. The partner labels are never
written into the wiki or any repo: the label-to-house pairing is as
sensitive as the address and lives only in the store.

## The repo

`gridworks-pii`, private. Holds: the package (`gwpii`: SQLAlchemy models,
pydantic models, alembic migrations), the operator CLI, the one-off seed
script from journaldb, and the tests. Web-backend pins it as a
dependency. Not inside gridworks-data, which is the journaldb projection
schema; this store is neither journaldb nor a projection. The package's
docstring states that these shapes never become a sema word because
their instances never travel on the wire. A `gwpii` service is not
built; it is the wrapper around this package if a second reader or a
web-based write path ever appears.

## The record

One schema, `pii`:

- `customers` — `ta_g_node_id` (the TerminalAsset GNodeId, primary key,
  no foreign key anywhere), first name, last name, email, phone; street,
  city, state, ZIP, country; an optional second contact (name, email,
  phone); installer reference; created and updated stamps. No
  coordinates, ever.
- `installers` — the installing business: id, name, contact name, email,
  phone. One tier lighter than a customer, the same mechanics.
- `partner_labels` — `ta_g_node_id`, partner, label (free text), issued
  date; unique per (partner, label). The only bridge between a partner's
  world and a public alias, which makes it as sensitive as the address.
- `partner_label_schemes` — per partner: prefix, digit count, the
  shuffled unissued draw list. Ridgeline: `HH-` plus three random digits
  drawn without replacement (HH-417), never reused. A sequential number
  would be enrollment order, which public install dates expose. A
  partner with thousands of homes gets its own scheme.
- `changes` — append-only: who, when, which table and key, before and
  after. Audit and deletability rest on the database itself: a deletion
  is a real delete plus this record. Never on the bus.

## The CLI

Runs on the operator's laptop against a tunnel to the box's loopback
Postgres (`ssh -L`), as the `pii` login. Commands are shaped as the
operations a later web-based write surface would expose:

- `add-customer <ta-g-node-id>` — prompts for the fields, mints the
  partner label from the partner's scheme, writes the change record,
  prints the label to hand to the partner.
- `show <ta-g-node-id>` / `find <name-or-label>` — the operator's lookup
  while the dashboard's sections are dark (retire-installations, until OPS-600).
- `update`, `delete`, `add-installer`, `set-password` (OPS-600).

The entering operator is the person who created the pending TA minutes
earlier with `gnregistrar create`; the two commands are run in one
sitting and the GNodeId is copied from the registrar's output.

## The box

AWS t4g.micro in us-east-1, Postgres 16 from the distribution bound to
loopback, the whole root volume EBS-encrypted, nothing inbound but ssh.
A US location because the records are US households; AWS over Hetzner's
US locations because it is half the price there and encryption at rest
comes with the volume instead of a LUKS recipe. Nightly `pg_dump` kept
on the box; the off-box copy is an EBS snapshot, by hand until the
account grants an automation role. Runbook: `gridworks-infra/pii/`. The
web-backend identity database (OPS-600) goes on the same box.

## Seed from journaldb

The one-off script reads `installations.address`, `customers` and
`installers` for the six houses. `installations.g_node_id` is the
house's LeafTransactiveNode GNodeId, not the TerminalAsset's, so the
script maps each to its TA GNodeId through a six-row table read from
the generated layouts and checked against the registry's
`…keene.<house>.ta` aliases. It drops latitude and longitude and writes
the six customer records plus their installer with a change record
naming the seed. The six houses get HH labels the same day so "House 5"
is retired. Verified by a row-level check: six customers, each with a
label, none with coordinates. The journaldb side is read with the
`gw_analyst` login, never the journalkeeper's.

What the data showed: five of six customers have no email and the one
installer is a bare name, so email, phone and the installer's contact
fields are optional in the record.

## Open

- The future TaValidator reads the address from this store to produce
  coordinates (onboard-cedar step 4). A validator is a production actor,
  so that is the store's first reader from inside the system; whether it
  reads through a role, through a human handoff, or through the
  not-yet-built `gwpii` service is decided when the validator is
  designed.
