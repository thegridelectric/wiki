# gridworks-terminalasset — executor hub

Status: Draft · Pass 0 · Updated 2026-06-11

What this is: the rebuild spec for `gridworks-terminalasset`, the repo
holding terminal asset GNode actors — simulated terminal assets first
(the comms rig for the scada simulation harness, seed of the live
hybrid fleet). Most of the spec is Open; this hub records what the
hello-world increment ([OPS-404](https://linear.app/gridworks/issue/OPS-404), shipped 2026-06-11) settled.

## Overview

A terminal asset is the GNode avatar for a real-world transactive
device. This repo's actors are built on gridworks-base
(`GridworksActor`), AMQP-native on the rabbit routing fabric. The
first inhabitant is `gwta.hello` — a heartbeat-only actor proving the
comms plumbing; simulated sensor emission arrives with the scada
simulated-test-environment design.

## Settled facts (verified by the hello-world live run, 2026-06-11)

- **Naming.** PyPI/repo `gridworks-terminalasset`, module `gwta`,
  console script `ta-hello` — following the gridworks-base → `gwbase`
  precedent. uv project, src layout, Python `>=3.12,<3.14`.
- **Dependency.** `gridworks-base>=0.5.2` from PyPI; no pin (gwbase
  `dev` == `v0.5.2` at adoption).
- **Transport.** `TransportClass.TerminalAsset` exists in gwbase's
  closed taxonomy; routing class short name `ta` (consume exchange
  `ta_tx`, publish `tamic_tx`). Verified live against `gw-dev-rabbit`
  (the dockerized dev broker, AMQP 5672): connect, passive assert of
  `ta_tx`, per-instance queue, `heartbeat.a` broadcast
  (`gwta/hello.py`).
- **Identity.** TerminalAsset is a *physical* GNode class: its
  `g.node.gt.json` carries `BaseClass: TerminalAsset` + a
  `PositionPointId`. Dev runs self-mint a throwaway identity
  (`ensure_g_node_json`); real assets get provisioned. Binding
  invariant: `GNodeGt.alias == settings.service_alias` (enforced by
  gwbase at boot).
- **Provisioning.** The exchange fabric is declared idempotently from
  the public `gwbase.topology` specs (`provision_topology` in
  `gwta/hello.py`) — no dependence on gwbase test stubs.
- **Config.** Standard gwbase env settings (`GWBASE_` prefix,
  `GWBASE_RABBIT__URL` for broker coordinates); `service_name`
  `terminalasset` puts the identity file under XDG
  `~/.config/gridworks/terminalasset/`.
- **Tests.** Offline smoke tests by default; broker-needing tests are
  marked `live` and deselected unless `pytest -m live`.

## Open

- The simulated terminal asset proper (synthetic channels, comms-test
  knobs, sema words for simulated sensor data) — specified in the
  scada `simulated-test-environment` design; distills back here as it
  ships.
- GNode registry: when a terminal asset stops self-minting and gets a
  real provisioned identity (carried from the hello-world design).
