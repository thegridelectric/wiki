# analytics-broker-shovel

Status: Draft · Pass 0 · Updated 2026-05-27

> Stand up a second RabbitMQ broker — the **analytics broker** —
> separate from the production control broker (`hw1__1`). All audit /
> analytics consumers (journalkeeper, dashboards, partner exports) move
> to the analytics broker. The prod broker shovels its `ear_tx` traffic
> there. The prod broker locks down to control-plane participants only.

## Why

The prod broker `hw1__1` carries the real-time grid control plane:
SCADAs, LTNs, AtomicTNodes, the market-maker, time coordinator. **Any
consumer connected to that broker is one bug or one credential leak
away from disrupting the grid.** Today the journalkeeper consumes
directly from `ear_tx` on the prod broker — it does no harm, but the
trust boundary is wrong: an analytics-or-UI consumer should not have
admission to the same authentication realm as the controllers.

The architecture has been agreed on for a while
([`../../ear/executor/broker-tap.md`](../../ear/executor/broker-tap.md),
broker-todos Phase 1) — this design captures the concrete plan.

## The shape

```
prod broker (hw1__1)              analytics broker (NEW)
  └─ ear_tx (universal tap)         └─ ear_tx (mirror)
      └─ rabbitmq shovel  ────►       └─ consumers:
                                           - gridworks-journalkeeper
                                           - dashboards / Grafana
                                           - partner / external exports
                                           - any future analytics service
```

**One-way** shovel: prod → analytics. No consumer on the analytics
side can write into prod. No analytics service holds prod broker
credentials.

## Invariants

1. **No analytics consumer authenticates to prod broker.** The shovel
   is the only connection from analytics → prod, and it is configured
   on prod to push to analytics (not pulled).
2. **`ear_tx` on analytics has the same shape as `ear_tx` on prod.**
   Same exchange type, same routing-key grammar. Consumers don't know
   which broker they're on by inspecting the topology.
3. **The shovel is lossy-on-disconnect by design** — analytics can be
   down without affecting prod. The shovel re-establishes when
   analytics recovers; messages buffered on prod up to its retention
   limit get delivered (best-effort), older messages are lost. This is
   acceptable because `ear_tx` is the audit-tap stream, not the
   control plane.
4. **Cred separation.** The shovel credential on prod is its own
   identity (`shovel.ear.analytics` or similar) with publish-only
   rights to `ear_tx`. Analytics consumers authenticate to the
   analytics broker with their own (per-consumer) credentials.

## Scope of work

Three landable chunks:

1. **Stand up the analytics broker.** New container / VM. Same
   RabbitMQ version as the upgraded prod (post-4.x). Same generated
   definitions shape (per `identities-in-definitions`). Distinct
   hostname (`analytics.electricity.works` or similar). TLS from day
   one (no "encryption only" phase like prod has had).

2. **Configure the prod-side shovel.** RabbitMQ `shovel` plugin (or
   `federation` — evaluate during execution). Source: `ear_tx` on
   prod. Destination: `ear_tx` on analytics. Authenticated with the
   dedicated `shovel.ear.analytics` credential.

3. **Migrate consumers to analytics.** Order:
   1. **gridworks-journalkeeper first** (this is the immediate
      forcing function). Switch `GJK_RABBIT__URL` to point at the
      analytics broker; verify the same flow we ran on dev rabbit
      2026-05-26 works against analytics→ear_tx with prod-shovelled
      traffic.
   2. Dashboards / Grafana (if any consume directly today).
   3. Partner exports (if any).
   4. Lock down the prod broker: remove all non-controller user
      credentials, audit remaining consumers, document the new
      "controllers only" rule.

## Dependencies

- **`prod-tls-fix`** must land first (analytics-bound traffic
  shouldn't go plaintext from prod). Strictly: the shovel link itself
  needs TLS.
- **`prod-4x-upgrade`** SHOULD land first or simultaneously so prod
  and analytics run the same RabbitMQ major.
- **`identities-in-definitions`** — the analytics broker's definitions
  follow the same generated shape; new identities (shovel,
  per-consumer) get added there.

## Open questions

- **Shovel vs federation.** RabbitMQ supports both. Federation tracks
  publisher confirms and is more durable; shovel is simpler. The
  audit-tap pattern is one-way and lossy-tolerant, so shovel is
  probably the right pick — confirm during execution.
- **Where the analytics broker lives.** Same AWS account as `hw1-1`?
  Different account for blast-radius separation? TBD with ops.
- **Retention on the analytics-side `ear_tx`.** Today the prod broker
  doesn't retain `ear_tx` messages — they fly past. The analytics
  side can choose to queue-with-retention to give consumers a replay
  window. Coupled with the
  [scale-strategy](../../gridworks-journalkeeper/concerns/scale-strategy-starter.md)
  question about test-isolation discipline.

## Cross-refs

- [`../../ear/executor/broker-tap.md`](../../ear/executor/broker-tap.md) — the universal audit-tap design this builds on.
- [`prod-tls-fix.md`](prod-tls-fix.md) — prerequisite.
- [`prod-4x-upgrade.md`](prod-4x-upgrade.md) — prerequisite.
- [`identities-in-definitions.md`](identities-in-definitions.md) — shovel identity sits here.
- [`../../gridworks-journalkeeper/executor/primary.md`](../../gridworks-journalkeeper/executor/primary.md) — first migrating consumer.
