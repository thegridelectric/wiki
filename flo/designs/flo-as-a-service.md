# flo-as-a-service

Status: Draft · Pass 0 · Updated 2026-08-30 · Linear: OPS-514

**EDD: yes** the opening experiment is a measured FLO build (peak RSS, wall
time) on a laptop from a real params blob and cached supergraph; the service
is Verified when one house's bids from the service match its in-process bids
over a day on the real broker.

> What this is: move FLO compute out of the LTN process into its own gwbase
> service on its own box. LTN boxes are then sized for LTN-only; FLO memory
> lives in one measured, contained place. Time-box target: under 20 hours.

## Why

- LTN boxes were sized by crashing: the 2025–26 season grew them until the
  crashing stopped, landing on c5.large (4 GB) per two to four houses. The
  FLO's CPU cost is trivial (~5 s per hourly build, from `gridflo.log`); its
  memory has never been measured. `gridworks-infra/ltn/README.md` "Box
  sizing" holds the operational fact.
- The memory shape: `actors/ltn/ltn.py` forks a child per FLO step
  (`_flo_build_worker` → `_flo_recommend_worker` → `_flo_plans_worker`);
  the child builds the full graph from the cached supergraph, solves,
  trims, **pickles the trimmed graph back through a queue**, and the parent
  unpickles it. Peak is a multiple of the graph per house, and six houses'
  hourly peaks are not synchronized.
- OPS-511 downsizes the LTN box on the condition that FLOs do not resume
  there. This design is what lets FLOs resume.
- OPS-491 (five-minute FLOs) multiplies the build cadence by 12; in-process
  that multiplies the unmeasured memory pressure per LTN box by the same.
  A service absorbs the cadence in one place.

## What exists already

- The FLO is already process-isolated with a bytes-in / bytes-out contract:
  `Flo(flo_params_bytes)` → trimmed graph → `generate_recommendation(bytes)`
  → `BidRecommendation` bytes. The service wraps these functions; it does
  not rewrite the optimizer.
- `gridflo/rabbit.py` is a stub (hard-coded `gwflo1.mic` exchange, pika to
  localhost); nothing runs it. Not the pattern.
- Supergraphs cache per params-hash in `~/.config/gridworks/gridflo/`
  (25 MB on `ltn2`); generation ~3 s / ~96 MB peak.
- Sema already has `flo.params.house0` and `bid` / `atn.bid`; check whether
  `bid.recommendation` exists before coining anything.

## Constraint: the LTN is not on gridworks-base

The LTN runs on gwsproto/gwproactor over MQTT; a gwbase actor is AMQP-native.
Same broker (Rabbit MQTT plugin), so a request/reply works, but
`FloParamsHouse0` / `BidRecommendation` exist twice — gwsproto named types
and `gridflo.asl.types` — and the LTN passes `to_bytes()` between them. V1
straddles: the service speaks sema; the LTN edge translates until the
proactor port (the LTN-on-gwbase design, OPS-435) removes the second
vocabulary. The design must work with the
gwsproto LTN as-is.

## Hosting

Two layers, decided separately.

**The broker face is settled:** a thin gwbase actor (`hw1.flo`, its own
Hetzner box under the fleet box-access model) owns the sema request/reply
with every LTN on the production broker. FLO params in and bids out are
fleet claims — witnessed by the ear, under FIS auth, following the house
API pattern; bids are money. The actor does not build graphs itself; it
dispatches builds to an executor and returns the result.

**The executor is decided by the opening measurement.** The resource that
crashed the LTN boxes is memory, consumed in bursts (one build's full
graph, its pickle, the parent's copy, for a few seconds) — and the crashes
came when bursts overlapped. Averages hide that; the design question is
how overlapping bursts are handled.

- *Local bounded worker pool on the actor's box:* N workers, each capped
  with `MemoryMax`, box sized for N × measured peak. Overlap becomes
  queueing; a params set larger than measured kills one worker, not the
  box. Cheap, on-convention, supergraphs warm on local disk, private
  `gridflo` at a pushed SHA. Needs a real peak number and its variance
  across houses; queue depth needs watching at OPS-491's cadence
  (100 homes × 5 min ≈ 1200 builds/hour).
- *Provider function (Lambda-class):* every build in its own memory (up to
  10 GB), no overlap by construction, pay per GB-second — pennies at six
  houses hourly, roughly a large box's price at 100 homes on 5-minute
  cadence. Costs: supergraph fetched from S3/EFS per cold start, private
  code packaged into a provider runtime, a second deploy path.

Because the actor fronts either, the executor can change later without
touching an LTN. The reuse section below tilts V1 to the resident pool;
the measurement records peak RSS per build, resident graph size per
house, and how both vary with house params.

## Reuse across the 5-minute cadence

`solve_dijkstra` (`gridflo/flo.py`) is backward induction: it walks layers
from the horizon down to now, storing on each node a cost-to-go
(`pathcost`) and `next_node`. A layer's solution depends only on later
layers' inputs. Profiling shows where the cost sits — `Created edges 3.2 s
· nodes 0.9 s · Dijkstra 0.1 s` — so the graph build is the burst and the
solve is nearly free. Reuse follows:

- **Within an hour:** the horizon and every forecast beyond the current
  hour are unchanged, so the built graph and all cost-to-go values from
  layer 1 out are valid. A 5-minute run updates current state and
  current-hour price, recomputes layer 0's edge costs, re-solves layer 0,
  locates the initial node, reads the path. Sub-second, no build, no
  burst. OPS-491's twelve runs an hour cost about one run today.
- **On a forecast revision mid-hour:** recompute edge costs and re-solve
  from the earliest changed layer outward; graph structure unchanged.
- **Across hours:** the horizon slides and the terminal layer moves, so
  the backward solve is formally invalidated — a full build once an hour,
  as today. Making the slide incremental (pinned terminal rolled every
  N hours) is Open, not required for cost.

Consequence for Hosting: this works only if the **built, untrimmed graph
stays resident per house** between runs. A per-invocation function rebuilds
it every call and forfeits the saving, so the executor holds per-house
graph state on our box; a function is at most burst overflow for full
rebuilds. The measurement therefore records resident graph size per house
as well as build peak.

## Shape (to be worked)

1. **Measure** (the experiment): one real build under `/usr/bin/time -l`,
   laptop, supergraph + params copied down from `ltn2`. Sizes the service
   box; decides worker concurrency.
2. **Service:** the broker-facing actor above plus the executor the
   measurement selects; supergraphs cached by params-hash; request/reply
   words are sema.
3. **LTN edge:** replace the `multiprocessing.Queue` round-trip with the
   broker round-trip, same timeout and the existing no-FLO default-bid
   fallback, so a service outage degrades rather than breaks.
4. **Cutover:** one house (oak; its params are in the gridflo tests) on the
   service in parallel with in-process for a day; compare bids; then the
   rest.

## Open

- Rolling the horizon incrementally (pinned terminal, roll every N hours)
  so the hourly full build also shrinks.
- Whether the three worker steps stay three calls (graph state held on the
  service between them) or collapse to one request returning
  recommendation + next-hour plan.
- Where the supergraph generator runs (on the service on cache miss, or a
  separate step).
- The gridflo test params hash (`afa1e066`) does not match the committed
  params file (`64f29a7c`); fix before the measurement.
