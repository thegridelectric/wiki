# broker-topology-canonical-in-gwbase

Status: Draft · Pass 0 · Updated 2026-06-25 · Linear: OPS-425

**EDD: no** build-out — verified by the prod broker booting from gwbase-generated
definitions with the suite green, not a standalone experiment.

> What this is: make the broker **topology** (vhosts, exchanges, queues,
> bindings) declared as **code in gridworks-base**, with the boot-time
> definitions JSON **generated** from it — never hand-edited. Retires the
> hand-maintained `rabbit_definitions.json` in gridworks-infra. Absorbs the
> topology concern formerly bundled with broker identities.

## Why now

The definitions drift when hand-edited, and the RabbitMQ 4.x upgrade is the moment
to load a clean, generated topology rather than re-doing it twice. gwbase already
declares exchanges/queues/bindings as code (`provision_topology` does this for
dev); this extends it to be the canonical source for prod.

## Scope — topology only

Identities and permissions are **not** here — they go to FIS (the `mTLS + FIS
auth` design). This design is vhosts + exchanges + queues + bindings:

- gwbase declares the topology as code (the rabbit-actor contract).
- The prod definitions JSON is generated from it; nothing is hand-edited.
- The binding table remains the authoritative "who may route to whom"
  ([`../../gridworks-base/executor/transport.md`](../../gridworks-base/executor/transport.md)).

## Done-when

- The prod broker boots from gwbase-generated definitions.
- No hand-edited `rabbit_definitions.json` remains in the deploy path.

## Sequencing

Land with / right before the RabbitMQ 4.x upgrade so the 4.x broker comes up on
the generated definitions. (Cross-design sequencing is tracked in Linear.)
