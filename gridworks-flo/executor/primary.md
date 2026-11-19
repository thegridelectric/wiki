# FLO — the house optimizer

Status: Draft · Pass 0 · Updated 2026-11-14

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
  LTN inside gridworks-scada is an MQTT client: its request
  arrives wrapped (`gw`) on `amq.topic`,
  `gw/<ltn-alias-hyphenated>/to/flo/flo-params`, where the service's
  queue binds `gw.*.to.flo.flo-params`, and its reply goes back wrapped
  on `gw.<flo-alias-hyphenated>.to.ltn.flo-recommendation`. An LTN keeps
  a reply whose `BidderAlias` is its own and whose first path's
  `StartUnixS` is the slot it is bidding. There is no correlation id.
  Both words reach the ear through the class taps.
- **The service is a GNode.** `FloActor` is a `GridworksActor`: a
  `g.node.gt.json` on the box names its registry row, `<universe>.flo` at
  the universe root (`hw1.flo`), class `Flo`, and the FIS principal's
  cert CN is that GNodeId. An LTN finds its FLO by walking the forest
  from itself up to the universe root: the first node with a Flo child
  names it, else `<universe>.flo`.
- **Each build is a subprocess of its own** behind the actor, the
  request on its stdin and the reply on its stdout, `GWFLO_WORKERS` at
  once; it shares nothing with the service but its pipes.
- **A request the service cannot serve is answered with `flo.refusal`**
  in place of the recommendation, in the kind the request came, with a
  Reason from `flo.refusal.reason`: no optimizer for the tuning, no
  cached matrix for the plant shape, a build that raised, a worker lost
  under it, or a recommendation built later than
  `GWFLO_REPLY_DEADLINE_S`, which the LTN has bid its fallback without
  by then. Answered or refused is discriminated by TypeName.
- **The plant-shape matrix is never built in the request path.** bruce
  loads a cached transition matrix per plant shape from
  `~/.config/bruce/graph_optimizer/`; a request whose shape has none is
  refused (`NoMatrix`). Matrices are generated as a separate step and
  placed on the box: a cold generation on one core takes minutes for a
  one-tank shape and hours for the three-tank shape.

## Invariants

1. Every instance across the boundary is a listed word at its listed
   version, encoded and decoded through the vendored snapshot
   (`gridworks-flo` `src/gwflo/sema`; bruce's own at `src/bruce/sema`).
2. A request is answered from its own bytes and the plant-shape matrix;
   the graph is built, solved and discarded per request. The one fact that
   spans slots, the previous cleared path, travels in the request.
3. The reply is complete over prices: pairs descend from the request's
   `PriceMaxUsdMwh`, the first pair at that ceiling, one path per pair.
4. A request the service cannot serve (no matrix, a tuning no FLO
   answers, a build that raised, a build killed under the memory cap or
   at the deadline, a reply built past `GWFLO_REPLY_DEADLINE_S`) is
   answered with `flo.refusal` in place of the recommendation, and the
   service logs it. A body the snapshot refuses gets no answer.
5. The service holds no per-site state and nothing to back up; it is
   rebuilt from the box README.
6. The reply annotates every path with the optimizer's own account of
   it, and the path itself stays generic. `flo.optimal.path` names a heat
   pump and a store's energy and nothing else. `flo.recommendation` 001
   adds two optional lists parallel to `OptimalPathList`:
   `StoreStateList`, a oneOf over store-model words
   (`flo.tank.store.path`: layer count, top, middle and bottom band
   temperatures, two thermocline layer indices, `EmptyStoreWh` and
   `FullStoreWh`), and `PathPenaltiesList`, a oneOf over optimizer
   penalty words (`flo.path.penalties.bruce`: the four penalty series per
   step, `TerminalCostEmptyStoreUsd`, `PathCostUsd`). Every path gets
   both, since the FLO publishes before the market clears. The optimizer
   states its own bounds and totals; no reader runs its formulas. The
   path the optimizer takes at its forecast price is the one with the
   lowest `PathCostUsd`.
7. The clearing is a word. After a slot clears the LTN publishes
   `flo.previous.run` (the cleared pair's path, the pair and its index,
   the next slot's forecast price as an integer times 1000 in a
   `PriceUnit`) and reads it back as the previous cleared path of the
   next request.

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
- [`recommendation-example.md`](recommendation-example.md) — one real
  `flo.recommendation` annotated field by field: the bid, the paths,
  the store, and what `PathCostUsd` sums.
- [`sema_seed_request.yaml`](sema_seed_request.yaml) — the service's
  seed, a verbatim copy of `gridworks-flo` `main`'s.
- [`traces/2026-11-18-beech-1900et/trace.yaml`](traces/2026-11-18-beech-1900et/trace.yaml)
  — production, beech's 19:00 ET slot: `flo.params` 003 with the
  previous slot's plan in it, `flo.recommendation` 002 with the on-pair
  at $24/MWh, `flo.previous.run` with the slot cleared off; the bodies
  beside it, verbatim, the ones `recommendation-example.md` reads.
- [`traces/2026-11-18-oak-penalty-on-bid/trace.yaml`](traces/2026-11-18-oak-penalty-on-bid/trace.yaml)
  — production, `flo.params` 003 to `flo.recommendation` 002 to
  `flo.previous.run`: the unmet-load penalty on, the on-pair at
  $103/MWh, the on-peak slot cleared off; the bodies beside it,
  verbatim.
- The executor tables (the rulebook form in
  `../../conventions/executor-CLAUDE.md`): Open.

## Open

- The matrix seam as a sema word, a manifest beside each cached array
  ([OPS-656](https://linear.app/gridworks/issue/OPS-656)).
- The graph as arrays in bruce, which takes the largest build from
  gigabytes to tens of megabytes
  ([OPS-655](https://linear.app/gridworks/issue/OPS-655)).
- The FLO's reply reaches every LTN, not the one that asked: an LTN
  drops every other house's recommendation each hour (one dropped
  message per house per hour, growing with the fleet). A reply to the
  requesting LTN alone (a per-bidder routing key or a reply-to) is the
  fix; parked on OPS-665 until the rollout issue exists.
- Two price conventions in the flo words: integer times 1000 with a
  `PriceUnit` (`flo.recommendation`, `flo.previous.run`, the market
  words) and float USD per MWh with the unit in the field name
  (`flo.params`, `gw.stopgap.price.forecast`). The market maker and
  price forecast words settle which the request takes.
- `flo.optimal.path` does not state what zero `StoreWhList` is measured
  from (bruce: energy from absolute temperature, about 1.7 MWh for a
  three-tank store). The page needs only `EmptyStoreWh` and
  `FullStoreWh`, which share that reference; a reader wanting absolute
  store energy needs the reference stated, a `flo.optimal.path` 001.
- `EmptyStoreWh` is the store at 70 F, a constant in bruce; the word's
  prose names 70 F, and another tank-store optimizer could mean a
  different floor.
- bruce merges first-step quantities within 0.01 kWh into one pair, so
  in that corner the stored path can differ from the forecast-cheapest
  one. Not seen in the field.
- The dev harness runs orange1 (`d1.isone.ct.newhaven.orange1`), a
  house no registry source knows, so the dashboard's house list cannot
  show it; either the harness registers it or runs a seeded house.
