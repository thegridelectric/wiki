# pii-store — the gridworks-pii repo, box and CLI

Status: Accepted · Pass 1 · Updated 2026-10-15 · Linear: OPS-473

> What this is: the first spoke of the disentangle-installations hub.
> Stand up `gridworks-pii`: a private repo, a small box with a loopback
> Postgres on an encrypted volume, one package that owns the record
> shape, an operator CLI that writes over an SSH tunnel, and the seed of
> the six existing houses from journaldb.

## Do this next

Create the private repo `gridworks-pii` with the package skeleton
(schema, pydantic models, alembic baseline) and the `add-customer` CLI
command against a local Postgres, with a test that a customer record
round-trips and that a second `add-customer` for the same TA GNodeId is
refused. The box comes after the package works locally.

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

The gnr box recipe: its own Hetzner cx23, Postgres 16 in a container on
a LUKS volume auto-unlocked from a root keyfile, bound to loopback only,
nothing inbound but ssh. A nightly `pg_dump` encrypted to a new private
bucket that is not the seed store. Runbook in `gridworks-infra/pii/`
once the gridworks-infra claim is free. The web-backend identity
database (OPS-600) goes on the same box.

## Seed from journaldb

The one-off script reads `installations.address`, `customers` and
`installers` for the six houses, joins each to its TA GNodeId through
`installations.g_node_id`, drops latitude and longitude, and writes the
six customer records plus their installers with a change record naming
the seed. The six houses get HH labels the same day so "House 5" is
retired. Verified by a row-level check: six customers, each with a
label, none with coordinates.

## Open

- The future TaValidator reads the address from this store to produce
  coordinates (onboard-cedar step 4). A validator is a production actor,
  so that is the store's first reader from inside the system; whether it
  reads through a role, through a human handoff, or through the
  not-yet-built `gwpii` service is decided when the validator is
  designed.
