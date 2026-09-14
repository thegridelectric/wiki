# stand-up-ltn-on-gwbase

Status: Draft · Pass 0 · Updated 2026-09-13 · Linear: OPS-435

**EDD: yes** verified by a real gwbase-native LTN dispatching a SCADA over the
prod broker: a contract established, dispatch flowing, the heartbeat live. Not
code review.

> What this is: stand up the **LTN as a gwbase-native cloud service**,
> extracted from gridworks-scada (`actors/ltn/`: `ltn.py`, `contract_handler`,
> the FLO integration). "The LTN goes gwbase" is an axiom under the proactor
> makeover ([OPS-428](https://linear.app/gridworks/issue/OPS-428)) and the
> trust/auth plane. The current LTN spec is
> [`../executor/primary.md`](../executor/primary.md). A rebuild, not a port,
> and the FLO leaves the process first
> ([OPS-514](https://linear.app/gridworks/issue/OPS-514)): what remains is
> the house's I/O and contract keeper, and that is the service this design
> stands up.

## Why

The LTN is the SCADA's parent GNode and "thinking half": the single writer of
dispatch and mode, and the party that holds the SLA. Today it runs as actors
embedded in the scada repo, on the proactor, over one MQTT link. Three forces
make it a gwbase-native cloud service:

- **proactor makeover** ([OPS-428](https://linear.app/gridworks/issue/OPS-428)):
  the redone link mechanism (AllyLink) requires the LTN be gwbase / rabbit
  native; full AllyLink lives in gwbase.
- **FIS auth** ([OPS-420](https://linear.app/gridworks/issue/OPS-420)): the LTN
  is a FIS-authed principal on the prod broker, not an embedded scada
  subprocess.
- **app-comms** ([OPS-408](https://linear.app/gridworks/issue/OPS-408)): the
  web frontend brokers mode/params through the LTN, which presumes a real LTN
  service with an API.

A fourth arrived with flo-as-a-service
([OPS-514](https://linear.app/gridworks/issue/OPS-514)): once the optimizer is
a service, the LTN no longer needs a box sized for graph builds, and its
remaining work is all input and output. That makes the port smaller and
tells us what to build well.

## The LTN's role once the FLO is out

Every hour (and, later, every five minutes,
[OPS-491](https://linear.app/gridworks/issue/OPS-491)) the LTN assembles what
the FLO needs, asks, and acts on the answer. The assembling and the acting
are the LTN. Its inputs:

- **Weather**, from the weather-forecast service as broadcasts
  (`../../gridworks-weather-forecast/executor/delivery.md` "Fleet delivery
  shape"): the LTN consumes the blessed forecast bundle and relays it down
  its scada pipe; the scada caches the last forecast and pulls from the
  gwwf API only as fallback. Today the LTN fetches weather.gov itself over
  aiohttp (`ltn.py:1528`), keeps a hand-built `oat`/`ws` dict
  (`ltn.py:1562-1571`) and a `weather.json` on disk. All of that goes; the
  service exists.
- **Prices**, from the price-forecast service over its read façade
  (`ltn.py:1667`, parsed by raw key into a CSV, `ltn.py:1671-1699`), and the
  live price from the MarketMaker. The fake in-process market maker
  (`ltn.py:855-858, 1774-1806`, hard-coded P-node at `ltn.py:458`) goes.
- **House parameters and the working store**
  ([OPS-531](https://linear.app/gridworks/issue/OPS-531)): the fitted thermal
  parameters as a sema file beside the layout, and one bounded, rebuildable
  SQLite store per LTN holding the three-week window of readings, forecasts
  and prices plus the live bid and contract. The six ad-hoc state files the
  LTN writes today (`flo_next_hour_plans.json`, per-slot reports, per-event
  JSON, `weather.json`, `price_forecast.csv`, `slow_dispatch_contract.json`)
  become projections in that store.
- **The homeowner's setpoint and band**, through the homeowner command
  surface (`../executor/primary.md` "Homeowner command surface") with the
  web leg under [OPS-408](https://linear.app/gridworks/issue/OPS-408). This
  is the thermostat interface: the LTN declares what may be commanded,
  acks what it will hold, and the app hears the result over the read
  façade's event stream.
- **The scada's readings and states**: layout lite, reports, snapshots,
  power, params, contract heartbeats and rejections, over the ally link.

Its outputs: the dispatch contract and its heartbeat to the scada, the FLO
params and next-hour plans to the scada, the bid to the MarketMaker. These
inputs and outputs are one coherent build: the LTN's I/O is its primary
role, and OPS-531, OPS-408 and the weather consumption are spokes of it,
not neighbours.

## Scope (a rebuild, not a port)

- **Extract** the LTN from gridworks-scada into its own gwbase service
  (GridworksActor, own env prefix, XDG paths, systemd unit per the gwbase
  deployment pattern, `uv`, sema types).
- **The dispatch contract**: rebuild the `SlowDispatchContract` lifecycle and
  dispatch on the gwbase transport. The bulk of the refactor; the contract
  handler is the hard part.
- **Pin the LTN↔fleet AMQP protocol**, today Open in
  [`../executor/primary.md`](../executor/primary.md) §8. The proactor
  makeover's `gw` envelope and contract-tier heartbeat ride here.
- **The FLO is a service** ([OPS-514](https://linear.app/gridworks/issue/OPS-514)),
  not a called dependency. The seam is already bytes in, bytes out: build
  the graph from FLO params, recommend a bid from updated params, plan the
  next hour from a price (`ltn.py:93-143`); the two blocking events in
  `BidRunner` (`ltn.py:184-395`) are exactly where a broker request/reply
  replaces an in-process wait. The LTN keeps the params assembly (`run_d`,
  `ltn.py:933-1094`) and the consumption of the results; the fork, pickle
  and watchdog machinery goes with the FLO.
- **The I/O role above**: weather from gwwf, prices from the price service
  and the MarketMaker, house params and the working store, the homeowner
  surface.
- **The LTN as broker**: single writer of dispatch and mode; the app-comms
  surface and the runtime mode-change path route through it.

## Sequence

Labels: *design* = stated in a wiki design; *inferred* = read off the code
(2026-09-13).

1. **Cut the FLO seam, LTN still on the proactor** (*design*, OPS-514
   "Shape"). Replace `BidRunner`'s three children with a request/reply to
   the FLO service, same timeout and the existing no-FLO default-bid
   fallback; `run_d`, the main loop, the contract handler and the MQTT link
   untouched. Verify: one house on the service beside in-process for a
   day, bids compared. This removes the process management before the port
   carries any of it.
2. **Move the MarketMaker face to AMQP** (*inferred*). The live price in and
   the bid out never touch the scada, so they are the first gwbase surface.
   Verify on the dev broker: a harness injects prices, the ear witnesses
   the bid.
3. **Stand up the gwbase LTN shell** (*design*, this issue; the envelope
   shape is Open here and paired with OPS-428): the ported contract handler
   and the scada message set over the MQTT-plugin path. Verify with the sim
   scada on the dev broker through a full contract lifecycle, Created to
   Completed, heartbeat live.
4. **The I/O role** (*design*, OPS-531 and the gwwf executor; the homeowner
   leg under OPS-408): weather consumption from the broadcasts and the relay
   down; the price service as the one price-forecast path; the working
   store replacing the six disk files; the parameter surface; the homeowner
   surface. Verify each by its own design's EDD clause.
5. **Then five-minute FLOs** (OPS-491).

Sequencing 1 before 3 is inferred, supported by the box-sizing motive in
OPS-514; this issue and OPS-428 develop in tandem.

## Clean-up debt in `actors/ltn/` (carry nothing of this)

Observed 2026-09-13; each is a reason the rebuild does not copy the file.

- `BidRunner._clear` (`ltn.py:363-375`) nulls the logger, the events and
  the send callable; `stop` (`ltn.py:386`) and `get_bid` (`ltn.py:378`) on
  a finished runner raise. The worker thread also mutates
  `self.bid_runner` from outside (`ltn.py:1095-1100`).
- `ltn.py:1011` assigns the forecast list to `flo_horizon_hours` where the
  sibling branches assign its length.
- Weather and price forecasts are hand-built dicts feeding a sema word
  (`ltn.py:1562-1571, 1604-1605, 1671-1675`).
- `LtnData` duplicates fields the actor also holds (`data.py:16-23` against
  `ltn.py:469-470, 483, 520`); one is dead.
- The P-node is hard-coded twice (`ltn.py:458`, `flo.py:11`), the
  MarketMaker destination once (`ltn.py:608`); the market slot name is
  formatted by string in both.
- The FLO's own revision is fetched by shelling out to git from the LTN
  (`ltn.py:146-170`); on a service boundary it belongs in the reply.

## Sequencing / relates

- **proactor makeover** ([OPS-428](https://linear.app/gridworks/issue/OPS-428)):
  the LTN side of AllyLink is the gwbase LTN; develop in tandem.
- **flo-as-a-service** ([OPS-514](https://linear.app/gridworks/issue/OPS-514)):
  step 1 above; its "Constraint" section still assumes a gwsproto LTN edge
  translating between the two vocabularies, which this rebuild removes.
- **house-params-and-working-store** ([OPS-531](https://linear.app/gridworks/issue/OPS-531))
  and **ltn-brokered-app-comms** ([OPS-408](https://linear.app/gridworks/issue/OPS-408)):
  the I/O role, step 4.
- **FIS** ([OPS-420](https://linear.app/gridworks/issue/OPS-420)): the LTN
  authenticates as a FIS principal.
- **MarketMaker** ([OPS-431](https://linear.app/gridworks/issue/OPS-431)):
  the LTN bids into the market; both are gwbase services.

## Open

- The LTN↔SCADA contract's shape under the new transport (the `gw`
  envelope, the contract-tier heartbeat).
- Whether the FLO seam is three requests (build, recommend, plan) or one
  request returning recommendation and plan; the graph stays resident on
  the service side either way (OPS-514 "Reuse across the 5-minute cadence").
- The sema words the seam still lacks: the bid recommendation and the
  next-hour plans have no registry hit as of 2026-09-13 (`flo.params.house0`,
  `bid`, `latest.price` exist); check before coining.
- Deployment (cloud-side, alongside FIS and the other gwbase services).
