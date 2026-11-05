# flo-as-a-service

Status: Accepted · Pass 1 · Updated 2026-11-04 · Linear: OPS-514

**EDD: yes** the opening experiment is a measured bruce build from oak's
plant facts (peak RSS, wall time per phase, trimmed-graph size), done
2026-11-01 and recorded below; the service is Verified when one house's
bids from the service match its in-process bids over a day on the real
broker.

> What this is: move FLO compute out of the LTN process into its own gwbase
> service on its own box. LTN boxes are then sized for LTN-only; FLO memory
> lives in one measured, contained place. Time-box target: under 20 hours.

## Why

- LTN boxes were sized by crashing: the 2025–26 season grew them until the
  crashing stopped, at c5.large (4 GB) per two to four houses. The FLO's
  CPU cost is small; its memory had never been measured.
  `gridworks-infra/ltn/README.md` "Box sizing" has the operational fact.
- The memory shape, as measured on td/bruce: a child per FLO step built
  the full graph, solved, trimmed and pickled the trimmed graph back
  through a queue for the parent to unpickle. Since PR #600 the LTN runs
  one child per slot (`_flo_worker`) that builds, answers and exits; the
  peak is the same build, once. Six houses' hourly peaks are not
  synchronized.
- The LTN box is sized for LTN-only once the builds leave it.
- OPS-491 (five-minute FLOs) multiplies the build cadence by 12; a service
  absorbs the cadence in one place.

## What exists already

- The optimizer is `bruce`, the one repo `thdfw/optimal-flexibility`
  (MIT). The service installs it editable from the sibling checkout
  `../optimal-flexibility`, on the laptop as on the box, the same
  pattern as the LTN boxes: the sibling tracks `main` with no pin, a
  bruce update is a pull of the sibling, and every recommendation
  records the commit that answered (`FloGitCommit`). The lock resolves
  only with the sibling present, so CI clones it. The as-built service,
  its words, transport and invariants are `../executor/primary.md`;
  bruce's model is `../executor/bruce-flo.md`.
- The LTN edge is step 3 of "Shape" below: one callable whose transport changes
  from a child process to the broker round trip, with its existing
  timeout and no-FLO fallback bid. The LTN runs on gwsproto over MQTT and
  the service is a gwbase actor on AMQP; the same broker joins them, and
  the request and reply words exist as gwsproto twins on the LTN side
  until the proactor port (OPS-435) removes them.
- The words (`flo.params/001`, `flo.tuning.bruce/001`,
  `flo.recommendation/000`, `flo.tuning.alice/000`,
  `flo.optimal.path/000`) are published in the sema registry; the
  service's snapshot, bruce's and the scada's speak the same versions.
  This design authors none.

## Hosting

A thin gwbase actor on its own box owns the request and reply with every
LTN on the production broker; builds run in a bounded local worker pool.
The measurement below settled the two questions this turned on: the
built graph does not need to stay resident between runs (1.8 GB per
three-tank house held, against a sub-second solve and a 43 s rebuild),
and overlapping bursts are queueing, `N` workers under one memory cap on
a box sized for `N` peaks. A provider function stays viable as overflow
because the service is stateless per request and the matrix cache is
tiny; it is not V1.

## The opening measurement (2026-11-01)

Laptop, `/usr/bin/time -l`, the bruce package at `optimal-flexibility`
`2711f59`, oak's plant facts from `tlayouts/output/oak` and
`actors/ltn/flo_tuning.py`, forecast arrays stand-ins shaped like a
November weekday under the Versant A-1 windows. Oak runs `BufferOnly`
today, so its live FLO is one tank: 9 layers, 120 gallons, 1890 states ×
461 actions. The build used the matrix copied from the LTN box
(`heat_pump_water_tank_2b6a76e0`), which the same params hash to.

| phase | wall | peak RSS so far |
| --- | --- | --- |
| interpreter + imports | | 109 MB |
| asset (available-actions cache) | 2.0 s | 160 MB |
| graph: load matrix, nodes, edges (185 k nodes, 348 k edges) | 2.5 s | 315 MB |
| find_shortest_path | 0.1 s | 323 MB |
| trim + pickle trimmed graph (7.0 MB) | 0.2 s | 323 MB |
| bid child: unpickle, generate_bid, next node | 0.1 s | 201 MB |

Build child total 5.4 s wall; the LTN box reports the same shape ("Built
and solved in 14.2 seconds", 7.3 MB trimmed, with 9 s of child start-up
and pickling around it).

The same run at the all-tanks shape (27 layers, 360 gallons, 15 876
states, cached matrix):

| phase | wall | peak RSS so far |
| --- | --- | --- |
| asset (available-actions cache) | 27 s | 558 MB |
| graph: load matrix, nodes, edges (1.56 M nodes, 2.96 M edges) | 12 s | 1852 MB |
| find_shortest_path | 0.9 s | 1924 MB |
| trim + pickle trimmed graph (59 MB) | 1.6 s | 1924 MB |
| bid child: unpickle, generate_bid, next node | 0.7 s | 876 MB |

All-tanks build child total 43 s wall, 2.0 GB by `/usr/bin/time`. Six of
these overlapping on a 4 GB LTN box is the crash the design opens with.
With the bid sweep fixed, the all-tanks bid is two pairs: nothing at the
ceiling, 7.71 kWh at 105 $/MWh and below.

Cold matrix generation, laptop, one core: 8 minutes for the 9-layer
shape (peak RSS unchanged at 330 MB; the file regenerated is the one on
the LTN box, byte for byte; a second run of the same shape at horizon 12
took 16 minutes, so budget a quarter hour) and three and a half hours for the 27-layer all-tanks shape: 461 actions from 16 s each at the
start to 76 s each at the end, for a 9.5 MB file. The
all-tanks build sizes the worker cap.

**Finding, for OPS-392:** every oak bid on `td/bruce` is one PQ pair by
construction. `Graph.generate_bid` sweeps trial prices upward and appends
a pair only when the quantity *rises* by more than 0.01 kWh; the hour-0
quantity falls with price (oak: 6.32 kWh up to ~121.6 $/MWh, then 0), so
only the first pair, at the floor price, is ever recorded. The penalties
do not flatten it: all four switched off give the same single pair.
gridflo's sweep (`gridflo/flo.py:552`) records a pair when the quantity
*drops* by more than 10 Wh; bruce inverted the comparison in the port.
The fix is `optimal-flexibility` `9ecc3aa` (branch `jm/flo-as-service`)
with `tests/test_generate_bid.py`, a 12-hour half-charged-store build that
checks the bid curve and is the smallest end-to-end bruce invocation: the
base for the service's build-time harness. With it, the per-pair path in
`flo.recommendation` has work to do.

## Shape

**Do this next**, three pieces that fit together and can go in
parallel:

1. **The LTN edge** (step 3 below). `_flo_worker` in
   `actors/ltn/ltn.py` is the one callable: `flo.params` bytes in,
   `flo.recommendation` bytes out. Its transport becomes a broker round
   trip to `hw1.flo`, same timeout, same no-FLO fallback bid; nothing
   else in the LTN moves. The LTN speaks gwsproto over MQTT and the
   service is a gwbase actor on AMQP; the same broker joins them.
2. **Journal both words** ([OPS-657](https://linear.app/gridworks/issue/OPS-657)). The journal DB
   holds no `flo.params` and no `flo.recommendation` today; the
   journalkeeper persists a type only when it is in its snapshot and in
   one of the persistor's tables. With both journaled, the cutover's
   comparison reads from the journal, and the service's reply is on the
   record from its first slot.
3. **Oak's day on the service.** Oak's LTN on the service beside
   in-process for a day, the bids compared slot by slot; the first real
   round trip (the request on the bus, the service's log showing the
   build answered, the reply beside it) is the domain's first trace.
   Then the rest of the fleet.

Stand-up record (`gridworks-infra/new-platform-service.md` and the box's
`flo/instance-README.md`):

1. **Broker fabric** (done 2026-11-01): rmqbot runs gwbase 0.6.2's
   definitions; `flo_tx` and `flomic_tx` exist on `hw1__1`, drift check
   in sync.
2. **Registry row, principal and cert** (done 2026-11-04): `hw1.flo`
   in the registry (class `Flo`, GNodeId
   `ae4be0c3-6dd0-42de-b267-543e61c11c89`), the identity file on the
   box written from the served record, a GNode cert whose CN is that id
   (the Service principal `a4991bea…` of 2026-11-01 revoked and
   suspended), recorded in `flo/instance-README.md` and
   `authority/cert-inventory.md`. The registry write needed its own
   operator principal on the gnr box, `hw1.gnr-operator`, since the
   gate admits no password connect.
3. **Checkout and unit** (done 2026-11-02; sibling pattern 2026-11-03):
   `gridworks-flo` main on the box, bruce editable from the sibling
   `~/optimal-flexibility` (`thdfw` main), `.env` for hw1 over mTLS,
   oak's matrices, `flo-rabbit` enabled and running.
4. **First-start check** (done 2026-11-04 as the GNode: principal Active
   on FIS, the connection on the broker as `ae4be0c3…` with the GRIDWORKS
   mechanism, the queue bound on `amq.topic` with
   `gw.*.to.flo.flo-params`).

1. **Measure** (done above).
2. **Service** (built and running: `gridworks-flo`, spec in
   `../executor/primary.md`).
3. **LTN edge:** the one callable's transport changes from a
   child process to the broker round-trip, same timeout and the existing
   no-FLO default-bid fallback, so a service outage degrades rather than
   breaks. Nothing else in the LTN moves.
4. **Cutover:** oak on the service in parallel with in-process for a
   day; compare bids; then the rest.

## Open

The graph in memory is [OPS-655](https://linear.app/gridworks/issue/OPS-655/graph-as-arrays): arrays in place of node and edge objects
cut the build's peak from gigabytes to tens of megabytes. The three
items below are [OPS-656](https://linear.app/gridworks/issue/OPS-656/flo-matrix-manifest-generation-command-cached-back-half-of-the-graph).

- Caching the back half of the graph's arrays per house and refreshing
  only the front, so a five-minute cadence (OPS-491) is not twelve full
  builds an hour. Not needed at the hourly cadence.
- Where matrices are generated: a CLI on the service box against the
  committed tlayouts ops instances, or on first sight of a new plant
  shape with the request refused until it exists. Either keeps generation
  out of the request path.
- **The matrix seam is sema, as soon as possible.** Today a matrix is a
  bare `.npz` whose meaning is its filename, a hash of nine plant-shape
  fields only bruce's `TransitionMatrixParams` can reproduce, and the
  loader checks the array's shape and nothing else. The seam wants a word
  as the manifest beside the array: the plant shape spelled out, the
  state and action counts the array must have, the bruce commit and time
  that generated it, and a checksum of the array. The FLO loads a matrix
  only through its manifest; the generation step emits the manifest; the
  array stays binary beside it (the 27-layer one is 7.3 million
  integers). The fields are bruce's, so the word is bruce vocabulary,
  decoded through the optimizer's vendored snapshot; the missing word is
  the one thing the service hand-codes around until it is coined.
- **The FLO knows no market** (decided 2026-11-01). The request gives
  it a step grid and price bounds as numbers; its answer is electricity
  against price for that plant on that grid. `flo.recommendation` states
  no slot name and no sign convention; those are the bidder's facts, and
  the LTN adds them when it makes the bid. `BidderAlias` and the paths'
  `StartUnixS` pair a reply with its request.
- A refused request (no matrix for the plant shape, a tuning no FLO
  answers) is logged on the service and nothing goes back; the LTN bids
  its fallback. A glitch word for the refusal, so the fleet sees it, is
  the next step on this path.
- **Action item: nodes and edges as NumPy arrays in bruce.** The
  all-tanks build's 1.8 GB and 43 s are 1.56 million node objects and
  2.96 million edge objects; the numbers on them fit in a few arrays
  (cost-to-go and next-node per state per layer, edge costs per state and
  action per layer, index arrays for the ragged available actions). That
  representation would bring every build to tens of megabytes and
  seconds, shared plant shape or not, and the matrix is already an
  array. It is a rewrite of the inside of `Graph` in Thomas's repo, so
  it is sequenced after the callable and the day of matched bids: those
  give the golden set of saved requests against which the rewrite must
  reproduce every `flo.recommendation` byte for byte before it merges.
  Two steps, so the asset layer he tunes in (states, actions, the COP
  curve, the penalty functions) reads as it does now: first storage
  only, the build still calling each cost function per state, action and
  step and writing the answer into an array, which removes the memory
  and leaves the time; then each penalty vectorized over a layer, one
  at a time, each against the golden test. `Node` and `Edge` stay as
  views built on demand for the visualizer and for debugging. Its home
  is a design in this domain when it starts.
