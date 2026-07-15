# broker-topology-canonical-in-gwbase

Status: Draft · Pass 0 · Updated 2026-07-15 · Linear: OPS-425

**EDD: no** build-out — verified by the prod broker booting from gwbase-generated
definitions with the suite green, not a standalone experiment.

> What this is: make the broker **topology** (vhosts, exchanges, queues,
> bindings) declared as **code in gridworks-base**, with the boot-time
> definitions JSON **generated** from it by a CLI — never hand-edited. Retires
> the hand-maintained `rabbit_definitions.json` in gridworks-infra. Absorbs the
> topology concern formerly bundled with broker identities.

## Why now

The definitions drift when hand-edited, and the current state proves it — five
definitions files across two repos, in two exchange-naming eras:

| File (repo) | vhost | naming era |
|---|---|---|
| gwbase `dev_definitions.json` | `d1__1` | current (`ltn_tx`, `mm_tx`, `ta_tx`, …) |
| gwbase `hybrid_definitions.json` | `hw1__1` | current |
| gwbase `rabbit_analytics_definitions_hybrid.json` | `hw1_analytics` | `earmic_tx`, `journalkeeper_tx` |
| gwbase `rabbit_definitions_hybrid.json` | `hw1__1` | legacy (`atomictnode_tx`, `gnode_tx`, …) |
| infra `rmqbot/rmq-docker/config/rabbit_definitions.json` (deploy path) | `hw1__1` | legacy variant (`ps_tx`, `tn_tx`, …) |

The prod broker boots from the legacy-era file; gwbase's code speaks the
current naming. The RabbitMQ 4.x upgrade (OPS-424) is the moment to load a
clean generated topology rather than reconcile by hand twice. gwbase already
declares exchanges/queues/bindings as code (`provision_topology` does this for
dev); this extends it to be the canonical source for every deployment.

## Scope — topology only

Identities and permissions are **not** here — they go to FIS (OPS-420). This
design is vhosts + exchanges + queues + bindings:

- gwbase declares the topology as code (the rabbit-actor contract).
- **A gwbase CLI outputs a definitions JSON** from that declared topology.
  Vhost is a parameter, default `d1__1`; customers are dev (`d1__1`), prod
  (`hw1__1`), and the analytics vhost (`hw1_analytics`).
- **Deployed copies are generated artifacts**: the file in infra's deploy path
  is committed with a generated-from-gwbase header and never hand-edited.
- **A drift test** proves every committed definitions artifact matches what
  the CLI generates from current gwbase — the enforceable form of "no
  hand-edited definitions".
- **The five-file cleanup**: which of the definitions files above survive
  (as generated artifacts), which are deleted.
- **The dev conf's vhost is corrected to `d1__1`**: today
  `gridworks-base/rabbit/rabbitconfig/rabbitmq.conf` says `hw1__1` in both
  `default_vhost` and `mqtt.vhost`, contradicting `dev_definitions.json` in
  the same directory. Dev is the `d1` universe.
- The binding table remains the authoritative "who may route to whom"
  ([`../../gridworks-base/executor/transport.md`](../../gridworks-base/executor/transport.md)).

## Conf standard (shared with OPS-423)

Confs are deployment posture and keep separate homes (dev conf in gwbase, prod
conf in infra — parameterized there by OPS-423). The standard across them:
**every difference between deployment confs is a declared parameter or a
documented reason** — no silent drift. Definitions get the stronger
identity-by-generation guarantee above; confs get this one.

Option, decided at execution: the broker-contract harness from OPS-423
(`gridworks-infra/rmqbot/rmq-docker/tests/`) could read its expectations from
the generated topology instead of hardcoding them — a live conformance check
to complement the file-level drift test. Live drift is real: runtime-created
users (e.g. `analytics.ear.reader`) exist only in the broker's data store,
invisible to any definitions file.

## Done-when

- The prod broker boots from gwbase-generated definitions.
- No hand-edited `rabbit_definitions.json` remains in the deploy path.
- The drift test is in gwbase CI.

## Sequencing

Land with / right before the RabbitMQ 4.x upgrade (OPS-424) so the 4.x broker
comes up on the generated definitions. Runs after OPS-423 (encryption-only
TLS, which is decoupled and ships first on 3.9.13). Cross-design sequencing is
tracked in Linear.
