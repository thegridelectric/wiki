# FLO — the house optimizer

Status: Draft · Pass 0 · Updated 2026-11-04

> What this is: the rebuild spec hub for the FLO (Forward-Looking
> Optimizer), the per-house bid optimizer. It runs as the `hw1.flo`
> service (`gridworks-flo`), which answers one request word with one
> reply word for every LTN on the broker; the optimizer behind the bruce
> tuning is the `bruce` package in `optimal-flexibility`
> (`bruce-flo.md`). Where it runs: `gridworks-infra/flo/instance-README.md`.

## Overview

One request, one reply, no state on the service between them.

- **The request is `flo.params` and its `Tuning` names the FLO.** The
  bidder's alias, the step grid, the price and weather forecasts, the
  store being modeled and its state at the slot start, the heat pump's
  facts, the market's price bounds, the previous slot's cleared path, and
  `Tuning`, a `oneOf` of `flo.tuning.alice` and `flo.tuning.bruce`. The
  service dispatches on the `Tuning` TypeName and on nothing else.
- **The reply is `flo.recommendation` for every FLO.** The bidder alias,
  the units, the FLO's name, repo and commit, the price-quantity pairs
  descending from the market's price ceiling, and `OptimalPathList` with
  one `flo.optimal.path` per pair at the same index. The FLO states no
  market slot and no sign convention; those are the bidder's facts.
- **alice** is the FLO in the service itself: one pair at the price
  ceiling for no electricity and one path of zero heat pump power. It
  needs no optimizer installed and serves any house whose ops instance
  names it.
- **bruce** is reached through the one callable `bruce.service.recommend`,
  bytes in and bytes out; the service and the optimizer share the
  vocabulary and no Python types. The optimizer is an optional install;
  a service without it answers alice and refuses bruce.
- **The transport** is two ways in, each answered in kind. A gwbase LTN
  sends `flo.params` direct over the LeafTransactiveNode-to-Flo edge of
  the class fabric, addressed to the FLO by alias, and the
  `flo.recommendation` goes back direct over the edge to the bidder. An
  LTN still inside gridworks-scada is an MQTT client: its request
  arrives wrapped (`gw`) on `amq.topic`,
  `gw/<ltn-alias-hyphenated>/to/flo/flo-params`, where the service's
  queue binds `gw.*.to.flo.flo-params`, and its reply goes back wrapped
  on `gw.<flo-alias-hyphenated>.to.ltn.flo-recommendation`. That binding
  goes once the LTN has fully moved out of gridworks-scada. An LTN keeps
  a reply whose `BidderAlias` is its own and whose first path's
  `StartUnixS` is the slot it is bidding. There is no correlation id.
  Both words reach the ear through the class taps.
- **The service is a GNode.** `FloActor` is a `GridworksActor`: a
  `g.node.gt.json` on the box names its registry row, `<universe>.flo` at
  the universe root (`hw1.flo`), class `Flo`, and the FIS principal's
  cert CN is that GNodeId. An LTN finds its FLO by walking the forest
  from itself up to the universe root: the first node with a Flo child
  names it, else `<universe>.flo`.
- **Builds run in a bounded pool** of worker processes behind the actor,
  one process per build, `GWFLO_WORKERS` at once. A reply older than
  `GWFLO_REPLY_DEADLINE_S` when its build finishes is dropped: the LTN
  has bid its fallback by then.
- **The plant-shape matrix is never built in the request path.** bruce
  loads a cached transition matrix per plant shape from
  `~/.config/bruce/graph_optimizer/`; a request whose shape has none is
  refused and logged, and nothing goes back. Matrices are generated as a
  separate step and placed on the box.

## Invariants

1. Every instance across the boundary is a listed word at its listed
   version, encoded and decoded through the vendored snapshot
   (`gridworks-flo` `src/gwflo/sema`; bruce's own at `src/bruce/sema`).
2. A request is answered from its own bytes and the plant-shape matrix;
   the graph is built, solved and discarded per request. The one fact that
   spans slots, the previous cleared path, travels in the request.
3. The reply is complete over prices: pairs descend from the request's
   `PriceMaxUsdMwh`, the first pair at that ceiling, one path per pair.
4. A refused request (no matrix, a tuning no FLO answers, a body the
   snapshot refuses), a lost build (worker killed under the memory cap)
   and a late reply all produce no reply; the service logs each and the
   LTN bids without the FLO.
5. The service holds no per-site state and nothing to back up; it is
   rebuilt from the box README.

## Glossary

- **FLO** — a function from one `flo.params` to one `flo.recommendation`;
  alice and bruce are the two.
- **tuning** — the word inside the request whose TypeName selects the FLO
  and whose fields are that FLO's knobs; at rest it is the ops instance's
  `FloTuning`.
- **transition matrix** — bruce's per-plant-shape cache,
  `next_state_index[action, state]`, keyed by a hash of the shape's
  fields; a bare `.npz` today, its manifest word is open.
- **fallback bid** — what an LTN bids when no recommendation arrives
  by its own deadline; an LTN fact, named here because the service's
  refusals rely on it.

## TOC

- [`bruce-flo.md`](bruce-flo.md) — the bruce asset model: request,
  plant assumptions, costs, response.
- The executor tables (the rulebook form in
  `../../conventions/executor-CLAUDE.md`): Open. They are built once the
  first real request and reply are in the journal, which is the first
  trace.
