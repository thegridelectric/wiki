# stand-up-ltn-on-gwbase

Status: Draft · Pass 0 · Updated 2026-06-26 · Linear: OPS-435

**EDD: yes** verified by a real gwbase-native LTN dispatching a SCADA over the
prod broker — a contract established, dispatch flowing, the heartbeat live — not
code review.

> What this is: stand up the **LTN as a gwbase-native cloud service**, extracted
> from gridworks-scada (where it lives today as `actors/ltn/` — `ltn.py`,
> `contract_handler`, the FLO integration). **"The LTN goes gwbase" is an axiom**
> under the proactor makeover
> ([OPS-428](https://linear.app/gridworks/issue/OPS-428)) and the trust/auth
> plane. The current LTN spec is [`../executor/primary.md`](../executor/primary.md).
> A **big job with substantial refactoring** — a rebuild, not a port.

## Why

The LTN is the SCADA's **parent GNode and "thinking half"** — the single writer of
dispatch + mode, and the party that holds the SLA. Today it runs as actors
embedded in the scada repo (real wall-clock). Three forces make it a gwbase-native
cloud service:

- **proactor makeover** ([OPS-428](https://linear.app/gridworks/issue/OPS-428)) —
  the redone link mechanism (AllyLink) requires the LTN be gwbase / rabbit-native;
  FULL AllyLink lives in gwbase.
- **FIS auth** ([OPS-420](https://linear.app/gridworks/issue/OPS-420)) — the LTN is
  a FIS-authed principal on the prod broker, not an embedded scada subprocess.
- **app-comms** ([OPS-408](https://linear.app/gridworks/issue/OPS-408)) — the web
  frontend brokers mode/params **through** the LTN, which presumes a real LTN
  service with an API.

## Scope (a refactor, not a port)

- **Extract** the LTN from gridworks-scada (`actors/ltn/`) into its own gwbase
  service (ActorBase, `uv`, Sema types).
- **The dispatch contract** — rebuild the `SlowDispatchContract` lifecycle +
  dispatch (`FsmEvent` / `AnalogDispatch`) on the gwbase transport. This is the
  bulk of the refactor.
- **Pin the LTN↔fleet AMQP protocol** — today Open
  ([`../executor/primary.md`](../executor/primary.md) §8): what the LTN
  publishes/subscribes on the broker. The proactor-makeover's `gw` envelope +
  contract-tier heartbeat ride here.
- **FLO stays a called dependency** — the optimizer lives in private
  gridworks-innovations; the gwbase LTN calls it (the `flo.py` integration point),
  it is not embedded.
- **The LTN as broker** — single writer of dispatch + mode; the app-comms surface
  and the runtime mode-change path route through it.

## Sequencing / relates

- Pairs with **proactor makeover**
  ([OPS-428](https://linear.app/gridworks/issue/OPS-428)) — the LTN side of
  AllyLink *is* the gwbase LTN; develop in tandem.
- **FIS** ([OPS-420](https://linear.app/gridworks/issue/OPS-420)) — the LTN
  authenticates as a FIS principal.
- **MarketMaker** ([OPS-431](https://linear.app/gridworks/issue/OPS-431)) — the LTN
  bids into the market; both are gwbase services.

## Open

- How much of today's `actors/ltn/` carries vs is rebuilt (the `contract_handler`
  is the hard part).
- The LTN↔SCADA contract's shape under the new transport (the `gw` envelope, the
  contract-tier heartbeat).
- Deployment (cloud-side, alongside FIS and the other gwbase services).
