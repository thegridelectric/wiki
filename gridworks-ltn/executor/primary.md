# gridworks-ltn — Rebuild Specification (primary)

This is the **faithful-rebuild specification** for the **LTN**
(LeafTransactiveNode), the per-house transactive agent that sits one
hop above each scada in the GridWorks fleet. It schedules the house's
heating against forecasts and prices using a forward-looking optimizer
(FLO).

> Status: Draft · Pass 0 · Updated 2026-11-02
>
> **Acceptable-minimum bootstrap** for a domain whose code does not yet
> live in its own repo (the production code is in
> `gridworks-scada/gw_spaceheat/actors/ltn/`). Most depth is "Open" on
> purpose; this hub captures where the code is, how it runs in prod,
> what it depends on, and the open cleanup work — so a future Claude
> session (or human) can pick it up without re-discovering all of it.

## §1 — What this is, and where it lives today

An LTN is the **parent GNode** of a scada: for a scada at
`hw1.isone.me.versant.keene.elm.scada`, the LTN's GNodeAlias is
`hw1.isone.me.versant.keene.elm` (the scada alias minus the `.scada`
suffix). One LTN per scada in production; the LTN is the
"thinking" half of the pair (the scada actuates).

**Production code path today:**
`gridworks-scada/gw_spaceheat/actors/ltn/`:

- `ltn.py` — the `Ltn` PrimeActor, the main loop and the FLO call
- `cli.py` — the `gws ltn run` typer command
- `config.py` — `LtnSettings` (`LTN_` prefix)
- `contract_handler.py` — contract / scheduling state machine
- `flo_request.py` — builds `flo.params` from the house's facts; the
  slot arithmetic; the previous run
- `market.py` — the slot name, the latest-price topic, the clearing rule
- `data.py` — runtime data structures
- `dashboard/` — the operator TUI

**Future home:** a sibling `gridworks-ltn/` repo (does not exist
yet). When it exists, this wiki domain becomes its rebuild spec home
and the code in `gridworks-scada/gw_spaceheat/actors/ltn/` is moved
verbatim, then this `executor/primary.md` is filled out.

## §2 — How it runs in production

**Entry point:** `gws ltn run` (the scada CLI's `ltn` subcommand —
borrowed because the code lives there today).

**Deployment:** one systemd unit per house, `gwltn@<house>`, on the
`ltn` box, from a clean checkout of a pushed SHA at
`~/ltn-<house>/gridworks-scada`; a house's LTN and scada run the same
branch at the same SHA and move together by `scripts/roll.sh`
(`gridworks-infra/ltn/instance-README.md`; scada executor `running.md`
"Rolling a house between lines").

**Framework:** **gwproactor**, not gwbase. The LTN is a `PrimeActor`
(`gwproactor.PrimeActor`) with `LinkSettings` (`gwproactor.LinkSettings`),
`MQTTClient` config (`gwproactor.config.MQTTClient`), and
`CodecFactory` (`gwproactor.CodecFactory`). This differs from
gwbase actors (ear, journalkeeper) which are pika/AMQP-native. The
LTN is **MQTT-side** for its link to the local scada.

**AMQP publishing:** the LTN publishes on the rabbit **`amq.topic`**
exchange (the default RabbitMQ topic exchange), NOT directly on the
custom `*_tx` fabric (`ear_tx`, `tn_tx`, `atomictnode_tx`, etc.). But
this **does still reach the audit tap**: there is an exchange-to-exchange
binding `amq.topic → ear_tx` with routing key `#`, so every message
published on amq.topic is fanned into ear_tx (verified via the
production broker mgmt API on 2026-05-24, in
`../gridworks-journalkeeper/research/refactor-to-base-0.4.2.md`'s
Stage 5a notes). Same pattern for every `*mic_tx → ear_tx` binding.
A gwbase journalkeeper binding `#` on ear_tx therefore CAN see LTN
traffic — provided ActorBase's `RoutingClass` parser doesn't drop
the messages first (tracked by the gridworks-base design
`must-accept-current-ltn-messages`).

**Paths:** the LTN already follows the XDG `Paths` convention from
gwproactor (see the XDG file locations in
[`../../gridworks-base/executor/actors.md`](../../gridworks-base/executor/actors.md) §5.5):

- Config dir: `~/.config/gridworks/ltn/`
- Certs:      `~/.config/gridworks/ltn/certs/scada_mqtt/`
- Layout pair: `hardware-layout.json` and `operational-params.json`
  in the config dir, the committed tlayouts pair of the house's line,
  the same two files its scada reads.

## §3 — The Forward-Looking Optimizer (FLO)

The LTN's bidding brain is a FLO: given the house's facts, the
forecasts and the store's state it answers a bid curve complete over
prices, with the plan behind each pair. The LTN reaches it through one
call, a `flo.params` out and a `flo.recommendation` back, and holds
nothing of the FLO's between calls. The contract, the sources of every
input, the slot and the tests are
[`flo-boundary.md`](flo-boundary.md). The FLOs themselves, the
`hw1.flo` service and the bruce optimizer, are the FLO domain
(`../../flo/executor/primary.md`).

## §4 — Cross-cutting invariants

(Few committed today; mostly Open. Articulate as the rebuild spec
matures.)

1. **GNode identity.** LTN alias = scada alias minus `.scada`. One
   LTN per scada.
2. **Framework.** Today: gwproactor (PrimeActor). **Decided
   2026-05-24:** the LTN SHALL be migrated to gwbase. The LTN is the
   flagship gwbase object — it's the per-house transactive agent
   that gwbase exists to support. Migration to gwbase is now part of
   the cleanup epic below.
3. **AMQP exchange.** `amq.topic`, with the broker's
   `amq.topic → ear_tx` exchange-to-exchange binding making LTN
   traffic visible to ear-tx-bound consumers. No change planned;
   LTN keeps publishing on amq.topic.
4. **The FLO is behind one call.** The LTN and its FLO share the
   vocabulary and nothing else; the optimizer is a tagged dependency
   from the public GridWorks fork (`flo-boundary.md`).
5. **Three command surfaces, each declared.** Down to the scada (the
   dispatch contract), across from admin, and out to the homeowner. The
   LTN is the single writer of dispatch and mode to the scada; every
   other party's intent reaches the scada by the LTN translating it.
   Pattern: [`../../command-surface.md`](../../conventions/command-surface.md).

## Homeowner command surface

The setpoint, and how the system responds to it while the LTN is in
charge, is the contract between the LTN and the homeowner. A setpoint
change from the homeowner's app is a command on the surface the LTN
offers the homeowner, and the LTN's reply is what it is now bound to do.
It is not a reading the LTN may ignore, and it is not a command on the
scada.

- **Declaration.** The LTN publishes, per zone, the commands the
  homeowner may send and their allowed values: the setpoint, and the
  comfort band the homeowner grants around it. The app renders from the
  declaration; it never learns the house another way. The band is the
  flexibility the homeowner grants the LTN, exercised day to day; the
  trading-rights grant is the same principle at the contract level
  (`../../vision/data-meaning-sovereignty.md`).
- **Reply.** Every command gets a contractual ack or a nack with a
  reason. Ack states the setpoint the LTN will hold, by when, and within
  what band. A request outside the contract is refused, not silently
  clamped.
- **What ack binds the LTN to.** The FLO plans the zone temperature
  inside the band, treating the house mass as a second, bounded store
  alongside the water tanks, and dispatches the scada to deliver it. The
  scada-side mechanism is the zone circuit's governance machine
  (`ScadaThermostatic` with the planned setpoint); under a live contract
  an optimized circuit is never left deferring to its wall stat.
- **Feedback.** The circuit's governance report, published on change, is
  the "setpoint changed" event. It is distinct from the ack and may lag
  it by an hour or never come when the plan already satisfies the band.
  The app receives it as a server-sent events stream from the LTN's read
  façade, never by polling the LTN.
- **Carrier.** The phone has no broker. The app commands over the LTN's
  HTTPS surface, the one foreign-contract exception to writes-ride-rabbit
  (`../../api-pattern.md` "Foreign-contract exceptions"). In-home
  sources (a wall dial's learned setpoint, a comms stat) reach the LTN
  upward through the scada as readings; the LTN merges both.
- **Auth.** A setpoint inside the band is low-impact and uses a normal
  app session. Changing the band or the contract terms needs the
  step-up assertion.
- **When the LTN is absent.** LocalControl honors the last accepted
  setpoint as a plain thermostat.

Build: the web → LTN leg under
[OPS-408](https://linear.app/gridworks/issue/OPS-408); the scada-side
governance command under
[OPS-392](https://linear.app/gridworks/issue/OPS-392); the FLO house-mass
model in the private repo.

## §5 — Glossary

- **LTN** — LeafTransactiveNode. Per-house scheduling agent.
  Historically also written **TN** (transactive node) on the wire.
- **scada** — the LTN's child GNode (one per house). Actuates the
  schedule the LTN computes.
- **FLO** — Forward-Looking Optimizer. The scheduling brain;
  private code.
- **PrimeActor** — `gwproactor.PrimeActor`; the proactor framework's
  top-level actor class (analogous to gwbase's `ActorBase` /
  `GridworksActor`).
- **`amq.topic`** — the default RabbitMQ topic exchange. LTN
  publishes here today; gwbase actors publish to the custom
  `<routing-class>_tx` exchanges instead.

## §6 — Map of the spec (TOC)

| Sections | File | Covers |
| --- | --- | --- |
| §1–§5 | **primary.md** (this file) | Where the code is, how it runs, FLO dependency, the homeowner command surface, cleanup status, glossary |
| §7 | _Open_ | LTN ↔ scada MQTT protocol (link name, topics, message types) |
| §8 | _Open_ | LTN ↔ rest-of-fleet AMQP protocol (what LTN publishes on `amq.topic`; what it subscribes to) |
| §9 | _Open_ | Contract / scheduling state machine (`contract_handler.py`) |
| §10 | [`flo-boundary.md`](flo-boundary.md) | The LTN ↔ FLO contract: the one call, the words, the slot, the previous run |
| §11 | _Open_ | Operator runbook (the unit, the aliases, the roll) |
| §12 | _Open_ | Migration plan to a standalone `gridworks-ltn/` repo |

## §7-§12 — Open

See TOC. Each becomes its own sub-spec when the corresponding work is
live. For now the code is the spec: read
`gridworks-scada/gw_spaceheat/actors/ltn/`, with the FLO contract in
`flo-boundary.md`.

## Cleanup epic — when we touch this domain in earnest

The above is honest about state, not aspirational. The likely first
cleanup commit when this domain becomes active:

1. **Move to its own `gridworks-ltn/` repo** with hatchling + uv +
   pyproject mirroring gridworks-base. Move the eight `.py` files
   verbatim, leave a thin compat shim under
   `gridworks-scada/gw_spaceheat/actors/ltn/` until callers update.
2. **Migrate framework from gwproactor to gwbase.** The LTN is the
   flagship gwbase object — its needs should drive any gaps in
   gwbase. Likely surfaces several gwbase designs that need to ship
   first or alongside:
   the three-tier actor model — ServiceSettings / XDG-paths /
   Sema-validate-init-JSON, shipped in gwbase 0.5.0
   ([`../../gridworks-base/executor/actors.md`](../../gridworks-base/executor/actors.md))
   — and the gridworks-base design `must-accept-current-ltn-messages`.
3. Move the FLO call's transport from the child process to the
   broker round trip with the `hw1.flo` service (OPS-514); nothing
   else at the seam moves.
