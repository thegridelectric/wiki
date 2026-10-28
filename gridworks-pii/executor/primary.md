# gridworks-pii — rebuild spec

Status: Draft · Pass 0 · Updated 2026-10-27

> What this is: the faithful-rebuild hub for `gridworks-pii`, the private
> customer store, the only place a person is linked to a house. Private
> repo; box and runbook in `gridworks-infra/pii/instance-README.md`.

## What the repo is

One package, `gwpii`: the `pii` schema and its migrations, the record
shapes, partner-label minting, the store operations and the operator
CLI. No service runs in front of it. The CLI runs on an operator's
laptop against an ssh tunnel to the box's loopback Postgres, as the
`pii` login; web-backend's read-only role is the only other reader
(OPS-600). The repo README is the operator's guide and stands alone.

## Cross-cutting invariants

- **A person is never on the broker, in the persistent store or in
  journaldb.** The store's defining property is deletability and access
  control, the opposite of the eventstore's witnessed-forever record, so
  nothing here is a sema word and no instance travels on the wire
  (`gridworks-infra/data-architecture.md` "Where meaning lives", item 5).
- **The TerminalAsset GNodeId is the only link between a house and a
  person.** It is the primary key of every record, with no foreign key
  anywhere. No customer id exists outside this store, and a record can
  exist while the TerminalAsset is Pending. It is the same id the
  registry, the roles table and the journal's projections key on.
- **No coordinates, ever.** Street address, city, state, ZIP and country
  are enough. Coordinates are the TaValidator's artifact and exist only
  encrypted in the registry's own store.
- **Partners never see a GNode alias or GNodeId.** The alias is public
  topology under which the journal publishes live telemetry; pairing it
  with a person turns public readings into a named household. GridWorks
  mints a label per partner and the pairing lives only here.
- **Every write is recorded.** An append-only change record (who, when,
  table, key, before, after) is written with each change. A deletion is
  a real delete plus that record. Audit rests on the database itself.

## The record

One schema, `pii`, five tables:

- `customers` — keyed on `ta_g_node_id`; first and last name, email and
  phone (optional), street, city, state, ZIP, country, an optional
  second contact, the installer reference, created and updated stamps.
- `installers` — the installing business: name and optional contact
  name, email and phone.
- `partner_labels` — `ta_g_node_id`, partner, label, issued date; unique
  per (partner, label). As sensitive as the address.
- `partner_label_schemes` — per partner: prefix, digit count and the
  shuffled unissued draw list. Labels are drawn at random without
  replacement and never reused, so a label never says when a house was
  enrolled, which a sequential number would through public install
  dates. The label scheme and the labels themselves are never written
  into the wiki or any repo.
- `changes` — the append-only record above.

## The CLI

Commands are shaped as the operations a later web-based write surface
would expose: `add-scheme <partner>`, `add-customer <ta-g-node-id>
--partner <partner>` (prompts for the fields, mints the label, records
the change, prints the label to hand to the partner), `show
<ta-g-node-id>`. The entering operator is the person who created the
pending TerminalAsset minutes earlier with the registrar; the GNodeId is
copied from its output. A development store (`docker-compose.yaml`,
deterministic bogus households) takes its URL on the command line so it
can never read the operator `.env`.

## Onboarding a house

1. The operator creates the pending TerminalAsset in the registry; it
   mints the GNodeId and a random `position_point_id`. Nothing about a
   person enters the open system.
2. Minutes later the operator runs `add-customer` with that GNodeId. The
   label is handed to the partner; the partner's folder for the house is
   named by the label and contains no alias.
3. The scada and LTN GNodes, the layout and the rest of provisioning
   follow, none of it touching the store.

What pass looks like: the pending TA is in the registry's read façade
with no position; `show` returns the customer, installer and label with
one change row; the dashboard lists the house by its registry display
name; neither the customer's name nor the street appears in the
journal's `messages` table, the ear's archive window or any `gw_data`
table.

## The box

AWS `t4g.micro` in `us-east-1`, Postgres 16 bound to loopback, the root
volume EBS-encrypted, nothing inbound but ssh. US because the records
are US households; AWS because encryption at rest comes with the volume.
Nightly `pg_dump` on the box; the off-box copy is an EBS snapshot. The
web-backend identity database (OPS-600) goes on the same box.

## Open

- The future TaValidator reads the address from this store to produce
  coordinates. A validator is a production actor, so that is the store's
  first reader from inside the system; whether it reads through a role,
  a human handoff or a `gwpii` service is decided when the validator is
  designed.
- Passkeys and per-act step-up for operators come with a web-based write
  path, if one is ever wanted.
