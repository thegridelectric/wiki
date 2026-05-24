# gridworks-ltn — Rebuild Specification (primary)

This is the **faithful-rebuild specification** for the **LTN**
(LeafTransactiveNode), the per-house transactive agent that sits one
hop above each scada in the GridWorks fleet. It schedules the house's
heating against forecasts and prices using a forward-looking optimizer
(FLO).

> Status: Draft · Pass 0 · Updated 2026-05-24
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
`gridworks-scada/gw_spaceheat/actors/ltn/` — eight Python files:

- `ltn.py` — the `LtnApp` PrimeActor, the main entry point
- `cli.py` — the `gws ltn run` typer command (added to scada CLI at
  `gw_spaceheat/cli.py:13,30`)
- `config.py` — `LtnSettings(AppSettings)` (extends gwproactor's
  AppSettings)
- `contract_handler.py` — contract / scheduling state machine
- `data.py`, `dtypes.py` — runtime data structures
- `flo.py` — the Forward-Looking Optimizer integration (calls into
  `gridworks-innovations/gridworks-flo/`)
- `dashboard/` — likely Trogon TUI for ops inspection
- `__init__.py`

**Future home:** a sibling `gridworks-ltn/` repo (does not exist
yet). When it lands, this wiki domain becomes its rebuild spec home
and the code in `gridworks-scada/gw_spaceheat/actors/ltn/` is moved
verbatim, then this `executor/primary.md` is filled out.

## §2 — How it runs in production

**Entry point:** `gws ltn run` (the scada CLI's `ltn` subcommand —
borrowed because the code lives there today).

**Deployment:** **tmux** sessions on the LTN host. There is no
systemd unit (today); the operator attaches/detaches tmux to
observe / restart. (Open: codify the tmux session name + restart
ritual, or migrate to a supervisor.)

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
the messages first (see F-007 in
`../gridworks-base/research/findings.md`).

**Paths:** the LTN already follows the XDG `Paths` convention from
gwproactor (see
`../gridworks-base/research/findings.md` F-005):

- Config dir: `~/.config/gridworks/ltn/`
- Certs:      `~/.config/gridworks/ltn/certs/scada_mqtt/`
- Layout:     `LTN_PATHS__HARDWARE_LAYOUT` env (typically
  `tlayouts/output/<house>.generated.json`)

**Hardware layout:** the LTN reads the same `hardware-layout.json`
shape that scada does — same file, layered for the LTN's view of
the house. The layout is generated from `tlayouts/`.

## §3 — The Forward-Looking Optimizer (FLO)

The LTN's scheduling brain is the **FLO**: it consumes weather
forecasts, price forecasts, and house state, and emits an
energy-instruction schedule for the scada to actuate. The FLO
implementation lives in the **private**
`gridworks-innovations/gridworks-flo/` package (Thomas's code).

- Local glue:  `gridworks-scada/gw_spaceheat/actors/ltn/flo.py`
- Strategy:    `gridworks-innovations/gridworks-flo/` (installed via
  `pip install -e ./gridworks-flo` into the scada venv per
  `gridworks-innovations/README.md`).

The `gridworks-innovations/` monorepo also reserves
`gridworks-price-forecasting/` (not yet present) for future
forecasting strategies.

**Open / cleanup-flagged:**

- This domain (LTN + FLO) is **Thomas's code** and **likely needs a
  lot of cleaning up**. The known concerns to address in the
  cleanup pass: factoring the FLO interface cleanly (so FLO swaps
  don't ripple into ltn.py), nailing down where `dtypes.py` types
  belong (LTN-local vs Sema-vocabulary), and clarifying the
  contract_handler state machine.
- The private/public split (LTN public vs FLO private) is mostly an
  IP-protection boundary, not a technical one — any clarification
  of LTN structure has to keep that split clean.

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
4. **FLO is private.** The optimizer logic stays in
   `gridworks-innovations/gridworks-flo/`; LTN public code consumes
   it as a dependency.

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
| §1–§5 | **primary.md** (this file) | Where the code is, how it runs, FLO dependency, cleanup status, glossary |
| §7 | _Open_ | LTN ↔ scada MQTT protocol (link name, topics, message types) |
| §8 | _Open_ | LTN ↔ rest-of-fleet AMQP protocol (what LTN publishes on `amq.topic`; what it subscribes to) |
| §9 | _Open_ | Contract / scheduling state machine (`contract_handler.py`) |
| §10 | _Open_ | FLO interface and the private/public boundary |
| §11 | _Open_ | Deployment / tmux ritual / operator runbook |
| §12 | _Open_ | Migration plan to a standalone `gridworks-ltn/` repo |

## §7-§12 — Open

See TOC. Each becomes its own sub-spec when the corresponding work
becomes load-bearing. For now the code is the spec — read
`gridworks-scada/gw_spaceheat/actors/ltn/` and the private
`gridworks-innovations/gridworks-flo/` source.

## Cleanup epic — when we touch this domain in earnest

The above is honest about state, not aspirational. The likely first
cleanup commit when this domain becomes active:

1. **Move to its own `gridworks-ltn/` repo** with hatchling + uv +
   pyproject mirroring gridworks-base. Move the eight `.py` files
   verbatim, leave a thin compat shim under
   `gridworks-scada/gw_spaceheat/actors/ltn/` until callers update.
2. **Migrate framework from gwproactor to gwbase.** The LTN is the
   flagship gwbase object — its needs should drive any gaps in
   gwbase. Likely surfaces several findings in
   `../gridworks-base/research/findings.md` (F-004 ServiceSettings,
   F-005 paths, F-007 routing classes) that need to land first or
   alongside.
3. Make the FLO interface a named ABC in `ltn.py` and have
   `gridworks-flo/` provide concrete implementations — so optimizer
   swaps don't ripple through LTN.
4. Sort `dtypes.py` into "LTN-internal" vs "Sema-vocabulary" —
   anything that crosses a boundary (per
   `../sema/primary.md`) belongs in `sema/`, not local types.
5. Codify the tmux ritual or replace with a supervisor.
