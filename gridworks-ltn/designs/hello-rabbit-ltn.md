# hello-rabbit-ltn

Status: Draft · Pass 0 · Updated 2026-11-04 · Linear: OPS-659

**EDD: yes** verified by a seam test on the dev broker: a paho stand-in
scada on the MQTT face publishes `layout.lite`, the operating status and
an ack-required event, and the gwbase LTN on the AMQP face answers the
ack within the scada's 5 s timer, takes the house's state, keeps an
injected `latest.price`, and hears a stand-in FLO's direct reply. A
second stand-in scada's traffic is asserted undelivered. The contract
heartbeat and the bid are not yet in the test; see "What the code has
beyond this design".

> What this is: the first day of the LTN as a gwbase actor in its own
> repo, `gridworks-ltn`. It is a port: the LTN modules copied
> from `gridworks-scada/gw_spaceheat/actors/ltn/`, the gwproactor
> transport swapped for gwbase, the scada's wire unchanged, the FLO and
> the maker reached as GNodes, proven against the dev broker. The
> vocabulary is the LTN's own sema snapshot and the repo depends on no
> scada package. The rebuild that follows (the I/O role, the layout
> words end to end) is [OPS-435](https://linear.app/gridworks/issue/OPS-435);
> this design is the spike that puts a gwbase LTN on the broker so that
> work has something to rebuild in place.

## START HERE

Add to sema (postponed; the sema read-receipt is in the session that
coins it)

 [ ] Proposed definition.
  - no.new.contract.warning/000: FromGNodeAlias (left.right.dot), ContractId (uuid4.str), GraceEndTimeS (utc.seconds), CreatedMs (utc.milliseconds), all required. Description: the scada's notice that the contract named is ending and no new one has arrived,
    with the end of the grace period after which it dispatches on its own. Owner gridworks-energy, published. The scada adds CreatedMs to its type in the same roll; until then the LTN's local class matches the wire without it.

`send.snap` is not coined: the LTN never asks for a snapshot (`snap()`
has no caller) and lives on the ones the scada sends on its schedule, so
`snap()` and the local `SendSnap` class go, and the store reading's
source is the scada's periodic `snapshot.spaceheat`. The scada keeps its
own handling of the message for other senders.

Until coined, the warning is a local `SemaType` class in `gwltn/words.py`.

## Why a port first

Two things want the LTN on gwbase before the rebuild can be scheduled.
The FLO service answers over `amq.topic` today because the LTN is an
MQTT client, and every gwbase actor that has to hear the MQTT side
binds a hand-chosen wildcard on that exchange: the flo for `flo.params`,
the market maker for `bid`, the journal for everything. With the LTN on
AMQP, those bindings give way to the declared class fabric
(`ltnmic_tx` to `flo_tx` and back, one edge each in
`gridworks-base/src/gwbase/topology.py` `ROUTING_EDGES`), the reply is
addressed to one LTN instead of broadcast to the class, and the ear hears
both legs through the taps it already has. The flo keeps its `amq.topic`
binding beside the edge, answering each request in the kind it came,
until the LTN has fully moved out of gridworks-scada. And the LTN becomes an
Orchestrator with a registry row, which is where the service-discovery
thinking (which flo, which maker, which clock, derived from the forest)
needs it to be.

The three ways the LTN sends, settled by the port:

- **The scada**, the one MQTT-native peer: a wrapped (`gw`) message on
  `amq.topic`, token `s`, the `gw` envelope the scada's codec expects.
  Inbound is the mirror, bound by the scada's alias.
- **A GNode, direct**: a `DirectRoutingEnvelope` on the LTN's mic
  exchange, bare sema bytes, forwarded by the class fabric to the
  receiver's queue, which is bound by its alias. `flo.params` to the FLO
  GNode and `bid` to the maker go this way; `flo.recommendation` comes
  back this way with no header.
- **A GNode's broadcast**: the LTN binds its own queue to the
  publisher's mic exchange. `latest.price` arrives this way.

The honest estimate for the full move is 36 h (22 to 58). One day is
the LTN itself, on the dev broker, with nothing deployed and the scada
repo untouched. The rest is the surroundings: the scada's live-test
harness, six house identities, the roll tooling, deployment. Doing the
day first settles the three seam questions below by experiment before
any of that is spent.

## What the day depends on

`gridworks-ltn/` is scaffolded from `gridworks-flo` (uv, hatchling,
`ci.sh` with the workflow behind it, a `GwltnSettings(GNodeSettings)`
with the `GWLTN_` prefix, a `gwltn` CLI, `template.env`,
`service/gwltn-rabbit.service`, one unit per box today; the per-house
template is a deploy item).

The vocabulary is the LTN's own vendored Sema snapshot (`gwltn.sema`),
seeded at the one version of each word the scada speaks, with local
class names stripped of `gw.`/`gw1.`/`gw2.`, so every field access is
snake_case and every dict is the PascalCase wire form. The repo depends
on no scada package. What the LTN needs beyond the words is small and
lives in the repo: `LtnLayout`, a NamedTuple read once off the sema
layout word (aliases, zones and thermal mass, the water store, which
tanks exist, each temperature channel's encoding); four plant names;
the temperature conversion; and the two uncoined words as local
classes. The snapshot allows staged words because the layout and
operational-params words are staging.

Copied from the scada repo, imports fixed: `ltn.py`,
`contract_handler.py`, `flo_request.py`, `market.py`, `data.py`,
`config.py`, `weather_source.py`, `clock.py` (the wall-clock path; the
MQTT-fed simulated source is dropped),
`load_operational_params` (`actors/scada_data.py:36-48`),
`actors/hydronic/store_temps.py`. Dropped: `dashboard/` (the prod unit
already runs with the GUI off), the typer `cli.py` (an argparse
`gwltn rabbit` entry point stands in), `sema_to_dc.py` and the bid
runner (the LTN runs no optimizer; the FLO GNode answers the request).

Replaced by gwbase:

- `PrimeActor`, `AppInterface`, `LinkSettings`, `MQTTCodec` become
  `GridworksActor` declaring `GwGNodeClass.LeafTransactiveNode`
  (`gridworks-base/src/gwbase/gridworks_actor.py:16-30`).
- `services.publish_message(...)` and `send_threadsafe(...)` become
  `wrap_bytes(...)` plus `self.send(...)` (`gwbase/wrapped.py:25-60`,
  `actor_base.py:745-813`). `send` marshals onto the pika ioloop, so the
  contract handler's thread-safe send callable maps onto it directly.
- `process_mqtt_message` becomes `process_message(envelope, body, header)`
  (`gwbase/orchestrator.py:148-185`); the existing match block survives
  once the inner payload is decoded through the snapshot codec.
- `LtnMQTTCodec` goes: destination validation is the binding key, and
  `latest.price` arrives by `subscribe_broadcast`.
- `start_tasks` and the asyncio main loop run on one daemon thread with
  its own event loop, as the market maker runs its periodic work
  (`gridworks-marketmaker/src/gwmm/market_maker.py:67,96`). The ping and
  the contract heartbeat are tasks on that loop; every inbound word is
  marshalled onto it with `call_soon_threadsafe`, so the LTN's state is
  touched on one thread and pika's consumer is the only other.
- gwproactor `Paths` become gwbase XDG paths, same
  `~/.config/gridworks/ltn/` layout.

Acks, pings and the comm events are sema words (`gridworks.ack` and
`gridworks.ping`, published and versionless; `gridworks.event.comm.*`,
`gridworks.event.startup`, `.shutdown`, `.problem` at 001) and are in
the LTN's snapshot; the scada's own seed request does not list them,
because its proactor speaks them as gwproto control types.
`no.new.contract.warning` and `send.snap` have no sema word (checked
against `sema/definitions/types/` 2026-11-03) and are local classes
until coined.

## The seam

The scada's wire does not change. Its upstream link subscribes
`gw/<ltn-dashed>/to/s/#` (`gw_spaceheat/scada_app.py:260-265`,
`gridworks-proactor/src/gwproactor/links/link_settings.py:42-48`), its
codec requires `Header.Src` equal to the LTN alias and `Header.Dst`
equal to `s` (`gw_spaceheat/actors/codec_factories.py:55-68`), and the
envelope is `{"TypeName":"gw","Header":{Src,Dst,MessageType,MessageId,AckRequired},"Payload":{...}}`
(`gridworks-protocol/src/gwproto/message.py:31-36`). gwbase's
`wrap_bytes` produces that shape exactly
(`gwbase/sema/types/gridworks_header.py:9-13`).

LTN to scada: routing key `gw.<ltn-dashed>.to.s.<type-dashed>` on
`amq.topic`, which the MQTT plugin delivers as
`gw/<ltn-dashed>/to/s/<type-dashed>`. gwbase's `wrapped_envelope`
helper emits the token `scada` for the Scada class
(`transport_encoding.py:54`), which the scada does not hear, so the LTN
builds `WrappedRoutingEnvelope(type_name=..., from_alias=self.alias,
to_class_token="s")` directly; the dataclass takes a raw token and
treats an unknown short one as expected (`transport_encoding.py:270-274`).
`gridworks-ltn` owns `"s"` as a named constant. The bid is a direct
message to the maker named by the ops word, over the
`(LeafTransactiveNode, MarketMaker)` edge; the stopgap maker drops it
today, as it drops everything, so the wire shape is settled before the
full maker reads it.

Acks: every scada message with `AckRequired` true (all events,
`gwproto/messages/event.py:33`; pings, `misc.py:22-25`) is answered with
`{"AckMessageID": <MessageId>, "TypeName": "gridworks.ack"}` wrapped as
`gridworks.ack` on `gw.<ltn-dashed>.to.s.gridworks-ack`, within 5 s
(`gwproactor/config/proactor_settings.py:4`). The proactor does this for
the LTN today (`proactor_implementation.py:731-735`). Without it the
scada's link falls from Active to awaiting-peer on the first 60 s ping
(`links/link_state.py:337-340`), events persist to disk for reupload, and
`layout.lite` is re-sent on every re-activation (`actors/scada.py:1381-1386`).
The ack is sent from `process_message` on the consuming thread before any
other work. The LTN also pings every 60 s, as the proactor does
(`link_manager.py:680-690`); any message from the peer sets the scada's
link Active (`link_state.py:307-310`).

Scada to LTN: the scada publishes `gw/<scada-dashed>/to/ltn/<type-dashed>`
(`links/mqtt.py:355`), on `amq.topic` as
`gw.<scada-dashed>.to.ltn.<type-dashed>`. The LTN binds its queue with
`subscribe_amq_topic(binding_key="gw.<scada-dashed>.to.ltn.#")` from
`local_rabbit_startup` (`actor_base.py:703-721`). It binds by its own
scada's alias; `gw.*.to.ltn.#` would deliver every house's scada traffic
to every LTN. gwbase's parser wants five tokens and a header whose
`MessageType` matches the payload `TypeName`
(`transport_encoding.py:375-386`, `wrapped.py:63-85`); the scada's types
all pass, and `message_id` is a plain string so the proactor's empty
default is fine.

The FLO: `flo.params` is a direct message to the FLO GNode named by
`GWLTN_FLO_ALIAS` over the `(LeafTransactiveNode, Flo)` edge, and
`flo.recommendation` comes back direct over `(Flo, LeafTransactiveNode)`
on the LTN's class queue, which gwbase binds by the LTN's alias
(`orchestrator.py:88-112`); nothing is filtered in the LTN beyond the
sender being its FLO. The reply is paired with the open request by
bidder and the first path's slot (`market.answers_request`); an answer
to any other request is dropped.

`latest.price`: today a hand-subscribed MQTT topic
`rjb/<mm-dashed>/mm/latest-price` (`ltn_app.py:166-172`) fed by the
`mmmic_tx` to `amq.topic` bridge tap. On gwbase,
`subscribe_broadcast(from_alias=ops.MarketMakerAlias,
from_class=TransportClass.MarketMaker, type_name="latest.price")` binds
`mmmic_tx` directly (`actor_base.py:677-701`).

Control plane: an Orchestrator answers the supervisor's heartbeat and
follows `sim.timestep` (`orchestrator.py:186-258`), so the settings take
`super_alias` and `time_coordinator_alias` as the flo's do
(`gridworks-flo/src/gwflo/config.py:22-24`).

## The day, as planned

Step 2 was dropped on the day: the repo depends on no scada package.

1. Scaffold the repo from `gridworks-flo`. 2 h (1.5 to 3).
2. Depend on `gridworks-scada-protocol`; record the debt. 1 h (0.5 to 2).
3. Copy the modules; fix imports. 2 h (1 to 3).
4. Transport swap in `ltn.py`: `LtnActor(GridworksActor)`, the bindings,
   `process_message` feeding the match block, `send_to_scada` with the
   `s` token, `send_to_mm`, the ack and the ping, the main loop on its
   thread, `logging` in place of `ProactorLogger`. 6 h (4 to 10).
5. FLO: the broker round trip to the FLO GNode, the LTN side of
   [OPS-514](https://linear.app/gridworks/issue/OPS-514): the request
   direct, the answer paired by bidder and slot, the bid off it. 2 h
   (1 to 4).
6. Move the unit tests (`test_flo_request.py`, `test_ltn_clearing.py`,
   `test_market.py`, `test_ltn_scada_publish.py`, `test_ltn.py`). 1.5 h
   (1 to 2). Then the seam test above, modelled on
   `gridworks-flo/tests/test_broker.py`. 4 h (3 to 6).

Steps 1 to 4 and half of 6 are the day, 10 to 12 h.

## After the day

- **The scada's live harness.** `ScadaLiveTest` names `LtnApp` as the
  parent app (`tests/utils/scada_live_test_helper.py:158-167`) and 24
  test files use it; four contract tests drive the LTN half of the
  protocol. A stand-in parent modelled on
  `gwproactor_test/dummies/pair/parent.py` keeps them green. 6 h (4 to
  10). The largest single unknown.
- **Identity.** `GridworksActor` refuses to boot without a
  `g.node.gt.json` whose alias equals `service_alias`
  (`gridworks_actor.py:45-80`): six registry rows, six FIS principals and
  certs minted by the owner, six env files. 5 h (3 to 8) plus waiting on
  certs. Before deploying, confirm AMQP reach from the ltn box to the prod
  broker through the FIS gate, and read `rabbit_definitions.build_definitions`
  to confirm `ltn_tx` and `ltnmic_tx` are generated for the class.
- **Roll tooling.** `scripts/roll.sh` becomes a two-repo script (the LTN
  half at lines 40-42, 111-117, 183-203, 249-253, 305-353). 2 h (1 to 3).
- **Deletions in gridworks-scada**, once every house runs the gwbase LTN:
  `gw_spaceheat/actors/ltn/`, `ltn_app.py`, `ltn_app_interface.py`, the
  `gws ltn` registration (`cli.py:13`), `service/gwltn@.service`, the
  bruce editable in `tools/mkenv.sh:30-38`, the LTN half of `roll.sh`,
  `"ltn"` in `tests/conftest.py:85`. 2 h (1 to 3). Staying:
  `HydronicLayout.ltn_g_node_alias` and `CoreNodeNames.ltn` (the scada
  names its upstream peer from the layout), the scada's own contract
  handler and every send to the LTN, `weather_source.py`, `clock.py`,
  `sema_to_dc.py`, `store_temps.py`, and the gwsproto package.
- **Wiki and Linear.** `executor/primary.md` §1 and §2, the changelog,
  `gridworks-infra/ltn/instance-README.md`, the scada executor's roll
  section. 2.5 h (2 to 4).

## The harness, after the day

The next design, named here so the day's choices serve it. A run of the
whole transactive loop on the laptop against the dev broker: a sim
scada, this LTN, the market maker, the weather forecast service, the
price forecast service and the FLO, stepped through a day in minutes by
the time coordinator. That is the EDD bar every design in this domain
asks for and none has yet: the bid, the clearing, the contract and the
dispatch witnessed end to end rather than leg by leg.

What exists: the dev-stack recipe (`experiments/dev-stack-recipe.md`
"The stack, in start order") starts the broker, the registry, the
journal and a sim scada; the FLO answers direct; the weather forecast
service is a GNode on the broker; the LTN's weather source has a `Sim`
kind for a run with no weather HTTP. What is missing, in the order it
is needed:

1. **One clock in the LTN.** gwbase's Orchestrator already follows
   `sim.timestep` (`orchestrator.py:226-229`, `on_simulated_time`), and
   `clock.py` has the `Clock` interface with `WallClock` and a stepped
   clock. The LTN's remaining wall-clock reads in `contract_handler.py`
   and `ltn_actor.py` and its `asyncio.sleep` waits go through
   `plant_clock`, and `on_simulated_time` advances it. The same change
   the sim-time design wants
   (`wiki/gridworks-scada/designs/simulated-test-environment/sim-time.md`,
   "Where two clocks meet"); the scada's side of that clock is its
   own work there. This is also the first step of "Do this next" item
   1, so the FLO leg's test and the harness share it.
2. **A time coordinator that steps.** `gridworks-timecoordinator` is a
   stub (`config.py`, `hello.py`); the harness needs it to publish
   `sim.timestep` on a schedule the run sets.
3. **A maker that clears.** The stopgap maker drops every bid and
   broadcasts one price; the contract leg back to the scada waits on
   the MarketMaker rebuild's clearing (its own design).
4. **The price forecast on the broker.** `gridworks-price-forecast`
   exists; whether the LTN reads prices from it or from a file in the
   run is settled in the harness design, through the sema price words.
5. **The recipe.** One more section in the dev-stack recipe: the five
   services, their env files (the LTN's config pair per house from
   `tlayouts`), start order, and the one capture that proves the loop.

## What the code has beyond this design

A read of every module against this design. The port copied the
scada's LTN whole, so the code has behavior and state this design never
named. Each item is either folded into the rebuild (OPS-435) or gets its
own line in "Do this next".

**Behavior the design does not name.**

- The hour: the main loop wakes every 61 s on the wall clock, requests
  the FLO at minute 57 (hard-coded), and the contract handler creates a
  contract only within 10 s of the top of the hour. Three timing
  constants, none a setting (`ltn_actor.py:228,571-627`,
  `contract_handler.py:239-245`).
- The store reading comes only from `snapshot.spaceheat`, which the
  scada sends on its own schedule; `snap()` has no caller, so the LTN
  never asks with `send.snap` (`ltn_actor.py:499-502,559`). Who sends
  `send.snap`, and when, is unsettled.
- `layout.lite` is a gate only: kept, never read; the tank channels
  come from the boot layout file and nothing checks the two agree
  (`ltn_actor.py:515-527`). `send.layout` goes to the scada 5 s after
  start and again whenever the channel names are unset.
- The heat pump's on/off state is a substring match on
  `hp-scada-ops-relay` over `report.state_list`; tank, buffer and zone
  channels are found by name scraping (`ltn_actor.py:529-538,823,933,
  1123-1143`). The layout word retires these in the rebuild.
- The store model: monotone smoothing then unseeded k-means
  (`ltn_actor.py:916-1060`); the buffer energy uses a hard-coded layer
  mass and falls back to 0 kWh on any error (`:1062-1115`).
- The price forecast is an HTTPS GET to one hard-coded Keene node for
  every house, cached to `price_forecast.csv`, decoded as a raw dict
  (`ltn_actor.py:1172-1268`). `gw.stopgap.price.forecast/000` exists in
  the registry and is not in the seed; the `PriceForecast` NamedTuple's
  no-word note is wrong.
- `flo.params`, `flo.recommendation` and the cleared `flo.optimal.path`
  are each copied to the scada for the record (`ltn_actor.py:455,699,813`).
- Oil fuel substitution: hard-coded weekday peak hours; above
  `fuel_sub_usd_per_mwh` the contract is created with the oil boiler on
  and 0 Wh (`contract_handler.py:300-332`).
- The heartbeat task resends Created every 60 s until answered, sends
  Active mid-contract, and resends the completion until the scada
  answers; a scada heartbeat is accepted only in order and by
  ContractId (`contract_handler.py:172-209,334-366`).
- Weather provisioning is a blocking HTTP call in the constructor with
  a 20 s timeout that raises when neither the cached file nor the
  service answers; under `Restart=always` that is a crash loop
  (`weather_source.py:287-333`). A short or seasonal-filled forecast
  means no FLO and no bid that hour.
- Words the seed lists and the actor drops silently: `ta.deed`,
  `gw.scada.commit`, `heating.forecast`.

**State on disk, none in the sema filename grammar:**
`slow_dispatch_contract.json`, `previous_run.json`, `price_forecast.csv`,
`report/Report.<slot>.json`, `events/<iso>.<type>.uid[<id>].json` in the
data dir; the weather bundle, forecast and seasonal template written
into the config dir at runtime.

**Settings the design does not name:** `timezone_str`, `save_events`,
`fuel_substitution`, `fuel_sub_usd_per_mwh` (490, "hack"),
`contract_rep_logging_level`, `flo_horizon_hours`, `keep_buffer_full`,
`weather_source`, `weather_api_url`, `weather_pull_timeout_s`;
`flo_logging_level` is unused, and `service_alias` has a beech default
that hides a value the box must declare.

**Found in review, each to be reproduced by a test before its fix:**

- On restart with an expired contract the completion is built while
  `latest_hb` is None, raises, is logged, and the contract is dropped
  with no completion sent (`contract_handler.py:107-116`).
- The late-price guard is written backwards: it aborts in seconds 0 to
  5 of minutes 1 to 59 and accepts a price at :00:30
  (`ltn_actor.py:754-761`); the 10 s check in `create_new_contract` is
  what decides.
- `next_contract_energy_wh` is cleared before the 10 s check, so a late
  price throws the energy away (`contract_handler.py:236-245`).
- `state_list[-1]` on an empty list raises on the loop thread, where an
  exception goes to asyncio's default handler, not the actor's logger
  (`ltn_actor.py:534`); the loop needs an exception handler.
- A price-forecast failure sends a glitch at Error, which the house
  convention reserves for a scada fault.
- `heard` grows without bound.

**Dead code:** `get_house_available_kwh`, `snap`, `self.data` written
and never read; `create_termination_heartbeat`, a duplicate heartbeat
constant, `latest_power_w`/`energy_used_wh`/`energy_updated_s` written
and never read, `_stop_requested` never set; `ForecastPair.fidelity_label`;
`Clock.now_ms`/`local_now`/`sleep` with no callers; prose in
`weather_source.py` still about the scada.

**Tests do not cover:** the contract handler's state machine at all,
`main_cycle`, `run_flo`, the clearing to a contract, the store model,
the buffer energy, the price forecast and its CSV fallback, weather
provisioning and the seasonal fill, the 60 s ping, `send_to_mm` and the
matched recommendation. The contract handler takes no clock, and the
main loop decides by `plant_clock` but sleeps on the wall, so a stepped
clock cannot drive it yet.

## Risks, each with how it is settled

- **The `s` token.** The seam test asserts the topic the stand-in scada
  receives; `transport_class_or_none("s")` returns None without raising
  (`transport_encoding.py:87-100`).
- **Ack latency.** The seam test times the ack against the 5 s timer.
  gwbase `send` is fire-and-forget on the ioloop, so milliseconds are
  expected.
- **Fan-in across houses.** The seam test runs a second stand-in scada
  and asserts its traffic is not delivered.
- **Threading.** pika consumes on one thread, the main loop, ping and
  contract heartbeat on another. Settled: every inbound word is
  marshalled onto the asyncio loop with `call_soon_threadsafe` and the
  state is touched there only; sends are safe from any thread by
  gwbase's design. The seam test is the witness.
- **The FLO round trip.** Half settled: the flo's own broker test
  answers a request sent direct over the edge the way the LTN sends it,
  and the seam test here takes a stand-in FLO's direct reply over the
  edge back. Open: the request leg from a live `run_flo`, which needs a
  settable clock and a store reading in the seam test.

## Do this next

The port is built: the vocabulary is the vendored snapshot, no scada
package is imported, the actor is a GNode on gwbase 0.7.2, the FLO and
the maker are reached direct on the class fabric (the LTN–Flo edges are
in the fabric and on the hw1 broker), the flo answers direct or wrapped
in kind, the seam test takes acks, `layout.lite`, the operating status,
a maker's `latest.price` and a stand-in FLO's direct reply on the dev
broker, and `ci.sh` is green with the workflow behind it.

The scada's half of the link is witnessed, on the laptop with a dev
scada and the dev LTN on the Nolan pair
(`experiments/2026-11-03-hello-rabbit-ltn-trace/`): the link goes
Active on the LTN's ack of the scada's first ping, `layout.lite` arrives
on activation, the LTN's 60 s ping and the scada's minutely ack-required
`report.event` keep it Active, and when the LTN leaves the scada's link
falls `active -- response_timeout --> awaiting_peer` 5 s after the next
unacked report, sends one ack-required ping, and says nothing else: its
`gridworks.event.comm.response.timeout` goes to the persister and
reaches the broker only on the reupload when the LTN returns. The LTN
has no state for the link at all: it acks and pings, asks for no acks,
and does not notice the scada leaving. That stays as it is for now: the
LTN's outward behavior on the link is identical to the scada's LTN, and
the link as state on both sides is its own piece of work, specified in
`wiki/gridworks-scada/executor/scada-ltn-link-state.md` ("Link-down
behavior — the gap", "Multiple children — the structural critique").
When it is built, key the LTN's link state by peer alias from the
start, so an aggregating node above the LTNs reuses the shape.

Next:

1. **The FLO leg, end to end.** The request from a live `run_flo` in
   the seam test (a settable clock and a store reading), the stand-in
   FLO answering it, the bid on `ltnmic_tx`, then the bid leg with the
   same clock in the contract handler. The clock work is the one the
   sim-time design wants anyway: `clock.py` has the `Clock` interface,
   and the remaining wall-clock reads in `contract_handler.py` and
   `ltn_actor.py` go through `plant_clock` in one change
   (`wiki/gridworks-scada/designs/simulated-test-environment/sim-time.md`
   names the LTN as the file to migrate whole).
2. **The words.** `no.new.contract.warning` is coined (START HERE) and
   its local class in `words.py` retires; `send.snap`, `snap()` and the
   `SendSnap` class are deleted;
   `gw.stopgap.price.forecast` joins the seed and the price GET decodes
   through it, with the price node per house from the ops word.
3. **The review's findings.** A failing test first for each of the six
   items under "Found in review", then the fix; the dead code goes in
   the same change. The timing constants and the beech default become
   declared settings or `names` constants.
4. **Grill to Accepted Pass 1**, then the deploy items in "After the
   day": identity and certs for the six houses, the roll tooling, the
   per-house unit template, the deletions in gridworks-scada.
5. **The harness design** ("The harness, after the day"), its own
   spoke and Linear issue, with the clock migration from item 1 as its
   first step already done.
6. **The executor, by adversarial rounds.** The review in "What the
   code has beyond this design" was one pass of code against a design
   that did not yet say what the LTN does hour by hour. The executor
   (`wiki/gridworks-ltn/executor/`, to the rebuild bar in
   `executor-CLAUDE.md`: the hour, the contract state machine, the
   store reading, the FLO and bid legs, the files on disk) is built by
   repeating one cycle until a round finds nothing: write or extend the
   executor from the code and this design; hand the executor and the
   code to a fresh reviewer that has read neither, briefed to find what
   the code does that the executor does not say and what the executor
   says that the code does not do; fold each finding into the executor
   as a statement of what is or into "Do this next" as a fix with its
   test. Each round is a changelog-free wiki edit and a stamp bump on
   the executor; the first round is next, from the review above, and
   covers the contract handler first since it has no test and the
   three suspected bugs.
