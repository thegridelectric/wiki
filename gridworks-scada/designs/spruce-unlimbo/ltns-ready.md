# LTNs ready (spoke)

Status: Draft · Pass 0 · Updated 2026-11-01 · Linear: OPS-392

> What this is: the spruce-unlimbo spoke that gets the LTNs running
> against the new scada code before the fleet is on the production
> broker, and settles what the LTN takes from the scada. Until launch it
> lives here; the LTN work that can wait moves back to spruce-settled
> (OPS-532) when this spoke closes.

## Before td/bruce becomes main (do this next, on a PR)

td/bruce is current main plus Thomas's FLO commits re-applied on top; it
supersedes td/generalized-flo and the paused merge worktree. Fix these on
a PR against it, in this order:

  - REVERT the best-effort publish wrapper which swallows every exception.
     On oak it skips HeatPumpWaterTankParams each run because the payload has no TypeName, so the scada never receives it. That is a non-sema payload at an inter-app boundary.
  - add flo.next.hour.plans v000 and v001 to sema

  - Fix this: load_operational_params is cast through Any to accept LtnSettings. It works because LtnSettings extends the scada paths
    settings, but the cast hides the type.

  -add back the test.
  - Tests are gone. test_ltn.py on td/bruce has zero tests (227 lines, one sample-params helper). Main has one. Running it
    collects nothing.

  - Restore the FLO-boundary shape main had, which the branch removed
    (the note to Thomas below has the particulars):
    - the LTN imports one callable from `bruce` and nothing else; the
      asset build, `find_shortest_path`, `trim_graph_for_waiting`,
      `generate_bid`, `get_next_node_at_price` and the reads off
      `initial_node.next_node` move behind that callable in the FLO
      repo, so the three child workers in `ltn.py` each make one call
      on bytes;
    - the response is `bid.recommendation` again, built on the FLO
      side with the slot name, bidder alias, units and forecast price,
      and complete over prices: each PQ pair also states the next-hour
      plan its edge leads to (expected storage kWh at hour 1, the hourly
      heat pump kWh plan), so the LTN answers the cleared price by
      picking its segment and the plans worker, `get_next_node_at_price`
      and the plan phase leave the LTN side;
    - the request is a sema word the LTN builds through its snapshot;
      `HeatPumpWaterTankParams` in its current forms is the candidate,
      with its house-fact and tuning-knob split settled in this spoke;
    - optimal-flexibility vendors its own sema snapshot and decodes and
      encodes through it.

  - Refactor `wiki/flo/designs/flo-as-a-service.md` (OPS-514) from
    gridflo to bruce: the `Graph` over an `Asset`, the transition-matrix
    cache in place of the supergraph cache, the three-call lifecycle
    with the plan at clearing price, and the request word that replaces
    `flo.params.house0`. The interaction is one request and one reply,
    with the plan per PQ pair inside the recommendation (decided
    2026-11-01, above); the design's "three calls or one" question
    closes on that, and the executor question (resident worker pool
    versus a per-invocation function) is then only about the
    five-minute-cadence reuse and the measured build cost, with no
    per-site state the service must keep between calls. The opening
    measurement moves to a bruce build from oak's real params. Take it
    to Pass 1 before any build session starts.

HeatPumpWaterTankParams becomes a sub-word of operational params, authored
in tlayouts and rolled with roll.sh until ops params are published; the
LTN does not send it to the scada. Pointers: the wrapper is commit
`e1392b6a` (`gw_spaceheat/actors/ltn/ltn.py`, `_message_for_scada_publish`);
the cast is in `gw_spaceheat/ltn_app.py` (`dcbdc1d9`); the word bump is
`packages/gridworks-scada-protocol/src/gwsproto/named_types/flo_next_hour_plans.py`
(`73b45e23`). The HeatPumpWaterTankParams model is not defined in
gridworks-scada; ltn.py imports it from the private `bruce` package,
`optimal-flexibility/src/bruce/graph_optimizer/assets/heat_pump_water_tank/params.py`
(sibling clone of github.com/thdfw/optimal-flexibility, on `main`); the LTN decodes it at ltn.py
lines 112 and 136 on td/bruce. Evaluate it there when writing the
sub-word.

### Note to Thomas: the FLO boundary on td/bruce

What works: the bruce optimizer builds, bids and plans on oak, and the
three-child-process split from main (build, bid, plans, each in its own
forked process with the trimmed graph pickled between them) came through
the port intact. That was the hard part.

The line the branch crosses is the FLO boundary ("The FLO boundary"
below): the LTN hands the FLO one serialized sema message and gets one
sema message back, so the FLO can run as a service for many LTNs with
nothing shared but the words. Main had both halves in place; td/bruce
removes both.

- **Request side.** `flo.params.house0/007` is no longer built. The
  bytes handed to the build child are
  `HeatPumpWaterTankParams.model_dump_json()`, a pydantic class in the
  private bruce package, snake_case, with no `TypeName`. The publish to
  the scada skips it every run for that reason.
- **Response side.** `BidRecommendation` is no longer returned. The bid
  child sends back a bare list of `{"price_mwh", "quantity_kwh"}` dicts,
  and the LTN assembles the market slot name, bidder alias, units and the
  x1000 conversion itself. The FLO's answer has no name, and the market
  facts that were in the FLO's reply now live in LTN code.

The pickle between phases is unchanged from main and stays: it is one
process's memory handed to its own child.

What we ask, in order:

1. **optimal-flexibility vendors a sema snapshot.** It has none today.
   The snapshot holds the words the optimizer speaks: the request word and
   the response word. How: `sema/README.md` "Vocabulary Snapshots" and
   "Vocabulary Selection and Snapshot Generation"; copy
   `sema/template_seed_request.yaml` and `sema/template_regen_snapshot.sh`
   into the repo and fill in the seed. The scada's
   `packages/gridworks-scada-protocol/sema_seed_request.yaml` and
   `scripts/regen_sema_snapshot.sh` are a filled-in instance to copy
   from.
2. **The response comes back as a sema word.** `bid.recommendation` is
   registered in sema beside `bid` (today it exists only as a gwsproto
   twin) and the bid child returns an instance of it, built through the
   snapshot class, with the slot name, bidder alias and units filled by
   the FLO as on main. Since `generate_bid` takes a forecast price and
   clips to the bid price bounds, the word should record the forecast
   price the recommendation was built against.
3. **The request is a sema word.** `HeatPumpWaterTankParams` is
   registered in sema in its current forms (floats stay floats) as the
   per-run request the LTN sends. Its house facts keep coming from
   `gw.operational.params`; its tuning knobs become a sub-word of that
   word; which field is which is settled in this spoke. The LTN
   constructs it through the snapshot class and the optimizer decodes it
   through its own.

**For the LTN executor (draft, moves there when this spoke closes).**
The FLO is a sibling repo installed into the LTN's venv as an editable
package. That is a stepping stone: the FLO's destination is a service on
the broker that runs FLOs for many LTNs, and the sibling install exists
so the LTN can run today with the same shape it will have then. Three
bright lines keep the transition to a one-line change:

- The LTN imports nothing from the FLO repo except the one callable it
  invokes. Every call across it is a remote procedure call in all but
  transport: bytes in, bytes out, no shared objects, no reaching into
  the FLO's graph, state or settings from the LTN side.
- The bytes in each direction are a sema word, serialized with
  `by_alias`: a request word the LTN builds from its own snapshot and a
  response word the FLO builds from its own. The two repos share no
  Python types; they share the vocabulary.
- The market facts in the response (slot name, bidder alias, units,
  the price it was built against) are the FLO's to state. The LTN
  copies them into its bid and adds nothing of its own.
- The FLO never sees the real-time price. The recommendation is
  complete over prices: every PQ pair states the plan its edge leads
  to, and the LTN reads the cleared price's segment off the
  recommendation it already holds. One request, one reply, no FLO state
  between them.

When the service exists, the callable's transport changes from a child
process to the broker and nothing else in the LTN moves.

## Launch note

The LTNs need to run before we are on the production broker. The first
job is to test locally, and use that test to find the minimal updates
to the LTN that get it working. The spoke text is worked in-process
with the spoke itself: the local run says what the LTN needs, and that
is what gets written here.

The split is roughly: what do we need so that the reports are acked
and the LTNs do not crash. The LTNs do not have to work well with their
FLOs yet. Once the launch part is done, this file moves back over to
spruce-settled with whatever LTN work can wait until after launch.

The LTN and the scada always run from the same code at launch. When the
fleet starts publishing to the rabbit broker, the cloud-box LTN gets the
cert and the matching code. So a heartbeat version change on the scada
branch is not a wire break to build around: the LTN runs on the laptop
from the same branch against the dev rabbit broker, and there is nothing
to build now.

The cloud LTN will decode several versions of a word one day, the scada
never will. That decoder arrives when the LTN moves out of scada into
gridworks-base, not before.

## The two FLOs

- **Maple.** A new FLO that uses the house's resistive elements and
  accounts for the wider COP variation of the Mitsubishi heat pump (last
  season maple ran a two-stage Samsung). Its parameters are not the
  current `flo.params.house0/007` shape; expect a `008` or a new word.
- **Spruce.** A FLO and a parameter word for the Nolan house; none
  exists today. What it optimizes over (the buffer-less plant, the
  time-of-use windows already on `gw.nolan.operational.params`) is the
  design question.

## What the LTN takes from the scada

Owned here once the two LTNs run, not before, because each question is
answered by what the running LTN actually reads:

- What each LTN needs that the layout and ops words do not carry, and
  whether `flo.params.house0` gets a new version for the House0 fleet or
  a Nolan twin for spruce.
- The strategy selector and sieg-loop facts the LTN reads
  (`../spruce-unlimbo/control-strategy-selection.md` decision 4).
- Whether `layout.lite` is reshaped once more or replaced by the raw
  layout + ops words (`publish-layouts-and-operational-params.md`).
  The LTN reads `BufferShortCycling`, `TotalStoreTanks` and `Ha1Params`
  off it; `AcceptsDispatch`, `ServiceMode` and `SeasonalStorageMode`
  come from `gw.house.operating.status` (`ltn/ltn.py:767-776`).

**State machines are keyed by ShNode `Name`, not handle** (2026-10-22).
`layout.lite/013` lists the machines a running scada hosts in
`StateMachines`, one entry per hosting node, each with the node's `Name`
(`spaceheat.name`), its state enum and that enum's version. The report
side still names a machine by `MachineHandle`, the boss chain, which moves
when the tree changes (hp-boss went under the local control). A reader
resolves a handle to its declaration by the handle's last dotted segment,
which is the node's `Name`. A GNodeAlias plays no part: a scada's ShNodes
have none of their own.

## What the scada takes from the LTN

- **The weather forecast.** The LTN relays gwwf's `gw.weather.forecast`
  to its scada over the existing LTN→scada pipe, and the scada stops
  pulling weather itself (gwwf `executor/delivery.md` "LTN relay is
  primary"; the scada keeps the last-received forecast on disk as the
  same word and falls back to the gwwf API only when the relay goes
  quiet). Until the LTNs run, the scada's interim pull from gwwf is
  `executor/weather-forecast.md`.

## The FLO boundary

The direction is FLO as a service: the LTN hands the FLO its parameters
as one serialized sema message and gets a sema message back, so the FLO
can run in another process or on another machine with nothing shared
but the words. Work on the LTN is judged by whether it moves toward
that boundary.

**Review `td/generalized-flo` against it.** The branch (off `dev`,
eight commits to 2026-10-02) swaps the gridflo optimizer for the generic
one in `optimal-flexibility` and rewrites most of `ltn/ltn.py` and
`tests/actors/test_ltn.py`. A first look, not yet a review:

- The LTN builds and bids in a child process and passes the parameters
  as bytes, which keeps a serialized boundary.
- The bytes are the optimizer's own `HeatPumpWaterTankParams`
  (snake-case fields, `model_dump_json`), not a sema word. Whether
  `flo.params.house0` is still built and reported, and what the audit
  trail of a bid is without it, is the first review question.
- `ltn/flo.py` on the branch is a stub typed on `FloParamsHouse0` that
  raises at construction.
- The branch and `jm/spruce-unlimbo` share no history since 2026-06-10
  and both rewrite `ltn/ltn.py` (the operating-status reads on one
  side, the optimizer swap on the other), so the review includes
  bringing the branch onto the launch line.

## The heat pump's electrical bounds

Two FLO inputs describe the heat pump's electrical envelope, and until
2026-10-14 neither reached the FLO from the house.

- **`HpMaxElecKw`** (`flo.params.house0`) is the heat pump's maximum
  electrical draw in kW; gridflo caps each hour's electrical input with it
  and scales the stability penalty by it. The house states this fact once,
  as `HpMaxKwEl` in `gw.operational.params` (9.66 at most houses, 10.0 at
  beech and maple); the scada copies it into `ha1.params`, which its own
  controllers read and which the LTN receives inside `layout.lite`. The
  LTN now copies `ha1.params.HpMaxKwEl`
  into `HpMaxElecKw`. Before, the gwsproto twin's class default of 9.66
  filled the field at every house, so the FLO planned against 9.66 at
  beech and maple while the scada's controllers used 10.0. gridflo's own
  copy of the type has the same 9.66 default; it has never fired, since
  the LTN always sends the field, and it stays for now.
- **`HpMinElecKw`** is the minimum electrical draw while running, in kW,
  negative to represent metered offsets at the lower bound. No layout or
  ops word states it; the LTN passes -0.5 from
  `actors/ltn/flo_tuning.py`, where every FLO input with no house source
  lives (the storage-loss percent, the per-step thermal caps, the two
  penalty families, the constant delta-T).

Cleanup, owned here: each `flo_tuning` constant is either a fact about
the house, which earns a field in `gw.operational.params` and flows
through `ha1.params` as `HpMaxKwEl` does, or a FLO tuning choice, which
stays with the FLO; one name per fact across the three words, so the
`HpMaxKwEl` / `HpMaxElecKw` pair converges when `flo.params.house0`
next versions.

## LTN code that scrapes where the layout answers

The LTN holds the full layout (`ltn_app.py:79`), so each of these is a
lookup:

- **House-available energy by channel-name scraping.**
  `get_house_available_kwh` (`ltn/ltn.py:1480-1512`) picks setpoint
  channels with `'zone' in x and 'set' in x`, derives the temperature
  channel by replacing `-set` with `-temp`, strips a six-character
  prefix, decodes every value with a fixed `/1000`, and skips `zone4` /
  `upstairs` by name. On a Nolan layout the replaced name matches no
  channel, so spruce contributes nothing; a temperature channel in
  another encoding is read wrong; and the skip is one house's special
  held in code. The lookup: each zone's primary circuit by
  `PrimaryCircuitPosition`, its `TempChannelName` and
  `SetpointChannelName` read through the channel registry, weighted by
  the zone's `KwhPerDegF`, with a zone that contributes nothing
  authored as `KwhPerDegF` 0. Test first: a Nolan layout with readings
  in their own encodings gives the right non-zero energy. The value
  feeds the FLO as `house_available_kwh`.
- **The dashboard's zone pattern.** `ltn/config.py:28-37` matches
  `^zone(\d)-(.*)-(temp|set|state)$` and
  `dashboard/channels/containers.py:107`, `:202` rebuild names from list
  order; the circuit's channel names give the same thing. Display only.
- **An orphaned setting.** `LtnSettings.seasonal_storage_mode`
  (`ltn/config.py:53`) is read only by a log line (`ltn.py:993`) that
  prints it in place of the value from the operating status.
- Nothing reads `Thermostat.ComponentId` or `ThermostatKind`
  (`thermostat-and-zone-control.md` "Thermostat chunk").
- **The fuel-substitution hard-code.** `LtnSettings.fuel_sub_usd_per_mwh`
  (`ltn/config.py:46`, default 490, "hack until we account for COP
  etc") is a tariff figure held in a setting: it was chosen to sit just
  above the on-peak delivery price the old hand-built forecast served,
  487.63 USD/MWh. The price forecast now serves the current Versant
  Rate A-1 total-delivery table (`wiki/regulatory/versant/tariffs.md`
  "Rate A-1": winter on-peak 612.10, shoulder 70.34, off-peak 64.26
  USD/MWh), so the threshold no longer means what it meant.
  `fuel_substitution` is off on every LTN, so nothing reads it today.
  Remove both settings and `use_oil_as_fuel_substitute`
  (`ltn/contract_handler.py:281`) rather than retune them; when fuel
  substitution returns it takes the tariff from the served forecast's
  `TariffAlias` and a COP-aware comparison, not a constant.


## Open

- Sequencing against `publish-layouts-and-operational-params.md`: the
  ops words freeze after the fleet runs them, and a FLO parameter word
  may want fields the ops words should own instead.
