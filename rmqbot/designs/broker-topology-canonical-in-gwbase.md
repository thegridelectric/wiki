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
clean generated topology rather than reconcile by hand twice.

The dev half of this design is already built in gwbase:
`for_docker/gen_definitions.py` generates definitions from the declared
topology (`--vhost`, default `d1__1`; `--check` drift mode), guarded by
`tests/test_definitions_drift.py`, a pre-commit hook, and the broker-image
workflow; `dev_definitions.json` and `hybrid_definitions.json` are generated
artifacts today, and the dev broker image (`for_docker/dev_rabbitmq.conf`,
RabbitMQ 4.1) already runs vhost `d1__1`. This design extends that machinery
to be the canonical source for every deployment.

## Scope — topology only

Identities and permissions are **not** here — they go to FIS (OPS-420). This
design is vhosts + exchanges + queues + bindings:

- gwbase declares the topology as code (the rabbit-actor contract);
  `gen_definitions.py` generates the definitions JSON from it (built).
- **Extend the generator's target set to prod and analytics**: prod
  (`hw1__1`) and the analytics vhost (`hw1_analytics`) join dev + hybrid as
  generated outputs.
- **Prod's deployed copy becomes a generated artifact**: the file in infra's
  deploy path is committed with a generated-from-gwbase header and never
  hand-edited, and the existing drift check extends to cover it.
- **Legacy cleanup**: retire the two hand-edited legacy-era files
  (`rabbit_definitions_hybrid.json`, `rabbit_analytics_definitions_hybrid.json`)
  and decide the fate of the `rabbit/` deploy kit (`broker_arm.yml` + the
  `hw1__1` conf at `rabbit/rabbitconfig/rabbitmq.conf` — the only remaining
  consumers of the legacy files).
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
- No hand-edited definitions file remains in any deploy path.
- The existing drift check covers prod's committed artifact.

## Sequencing

Land with / right before the RabbitMQ 4.x upgrade (OPS-424) so the 4.x broker
comes up on the generated definitions. Runs after OPS-423 (encryption-only
TLS, which is decoupled and ships first on 3.9.13). Cross-design sequencing is
tracked in Linear.
