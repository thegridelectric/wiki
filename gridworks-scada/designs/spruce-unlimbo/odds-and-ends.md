# Odds and ends (spoke)

Status: Draft · Pass 0 · Updated 2026-09-18 · Linear: OPS-392

> What this is: a spoke of [`primary.md`](primary.md) holding the small
> launch items that do not earn a file each: one problem, one change,
> one test apiece. An item leaves when its commit lands and the executor
> says the new behavior.

## Unobserved row offers every command (decided 2026-09-14)

- **Problem.** The admin panel offers a row's commands from its observed
  state (`gridworks-admin/executor/primary.md` "The capabilities
  contract", "What a row offers"); a row with no observed state offers
  nothing. hp-boss reports only on a transition, so after a boot its row
  reads `?` and on the 2026-09-08 spruce window the heat pump could not
  be commanded from the panel until LocalControl moved it. An unreported
  node is exactly the one the operator needs to reach.
- **Change.** `packages/gridworks-admin/src/gwadmin/watch/widgets/relay_widget_info.py`
  `offered_commands`: when `state is None`, return every command in the
  interface in vocabulary order instead of `[]`; docstring with it. A
  row with no commands (an owned relay) still offers nothing. The
  two-button binding takes the first two offers, so an unobserved
  five-v-boss shows TurnOff and TurnOn for the seconds before its state
  arrives.
- **Test.** `tests/test_misc/test_admin_five_v_boss_row.py`: the
  five-v-boss row with `state=None` offers all three; with `PicoCycler`
  it offers TurnOff and RebootPicos. hp-boss unobserved offers TurnOn
  and TurnOff.
- **On landing.** Drop "pending in gwadmin" from the admin executor
  paragraph.

## hp-boss reports its state at start

- **Problem.** `HpBoss.__init__` sets `state = HpOn` and only reports on
  a transition, so the snapshot's `LatestStateList` never carries
  `hp.boss.state` until the first command, and the assumed HpOn
  disagrees with the plant when the ops relay is open (2026-09-08
  window). The cycler reports every cycle, which is why its row fills.
- **Change.** Boot state HpOff and a `report_state()` in `start()`, the
  rule every machine follows (`control-strategy-selection.md`
  "Decisions": each machine announces its state in `start()`). Rides
  the relay's boot pin-adoption for the real answer. On the branch
  (`hp_boss.py` boots `HpOff` and reports in `start()`).
- **Test.** Still owed: hp-boss on both fixtures reports `HpOff` at start
  before any command; `tests/actors/test_machine_state_announce.py`
  gains the row.

## Dst-routing test for the LTN gw-wrap (OPS-387 interim)

- **Problem.** The LTN addresses its outbound messages instead of
  broadcasting (`gw_spaceheat/actors/ltn/ltn.py`, the four
  `HACK (interim)` comments: "Revert to a real rjb broadcast once the
  LTN is a gwbase actor"). Proved out in the spruce window, no test; the
  revert should be a deliberate, visible change, not a silent drift.
- **Change.** A test only. Assert the bid publishes with `Dst="mm"` and
  the FloNextHourPlans, the forwarded price/params payload and the
  flo_params publishes (`process_ltn_message`, `main_loop`, `run_d`)
  go to `self.scada.name`; nothing still says `Dst="broadcast"`. Reuse
  the capture harness of `tests/actors/test_five_v_boss.py` and
  `test_dispatch_replies.py` (`(dst, payload)` tuples off published
  messages, `dst == H0N.<node>`). If standing up the whole LTN
  (aiohttp session, BidRunner) is disproportionate, assert at the
  narrowest seam, the Dst on the publish call. Docstring names OPS-387
  so the gwbase-actor revert finds it.
- **Test.** The test is the change; it fits the single scada focus as
  coverage on a real spruce-window behavior.

## Admin panel client queues connects on CONNACK refusal

- **Problem.** The admin panel's own MQTT client (`constrained_mqtt_client.py`)
  queues a connect on each CONNACK refusal — the same flaw fixed in gwproactor
  `3e5087f` (`v4.1.13+jm2`) for the scada. With a wrong password the broker
  refuses every CONNACK while the panel appears connected and nothing it sends
  can arrive. Found on the 2026-09-05 dac-output bench
  (`experiments/2026-09-05-dac-output-bench/` README "Side findings",
  reproducer `test_connect_refused.py`).
- **Change.** Mirror the gwproactor fix: a refusal rides a `mqtt_connect_failed`
  edge with its reason logged, no re-queued connect on the closing socket.
- **Test.** Against a password-gated mosquitto, a wrong password surfaces the
  refusal instead of a false "connected".

## Sema prose review of the House0 words

Two lenses, on every word the Correct House0 work (OPS-539) added or
edited. First, a word names another sema word only in its `extended_description`; `description` and field descriptions say
what the word and the field mean by themselves, and the `$ref` carries
the relation. Second, no over-explained context: what a consumer does
with a value, which actor reads a flag, how artifacts pair at load, and
where a fact lives elsewhere are not the field's meaning. Each finding
is an in-place edit of a staging word, discussed before it is made
(the spec is change-controlled), then the tlayouts snapshot and the
closure mirror refresh in the same wave.

Start with `gw.operational.params` 000. Read 2026-09-18:
- `ScadaAlias`: "The layout is the registry of record for the full
  GNode; the consumer checks this alias names the paired layout's
  Scada." Consumer behavior and a fact about another word; the field is
  the alias of the Scada these params tune. (The scada loader does make
  this check; that is the loader's business and its test's.)
- The type `description`: "The third SCADA artifact alongside deployment
  config and the static hardware layout", the paragraph on how the
  consumer decodes `FamilyParams` through the paired layout's family,
  and the authority-dominates sentence, which the `ActuationAuthority`
  and `ServiceMode` field descriptions each say again.
- `FamilyParams`, `Tariff` and the curve fields are worth the same read.

Then, in this order: `gw.house0.family.params` and
`gw.nolan.family.params` (both descriptions name `gw.operational.params`
and a layout word; `KeepBufferFull` narrates the leaf ally, the LTN, the
FLO and local control), `gw.tou.tariff`, `gw.primary.flow.source`
(value descriptions name beech and maple), the two sim pico words,
`PicoBoardVariant` / `MicropythonVersion` on the three pico component
words, `flow.hall.params` 200, `flow.reed.params` 101, House0 axioms 16
and 17 (17 carries a parenthetical on where the invariant lives), Nolan
axiom 2, `layout.lite` 013 `KeepBufferFull`.

The spec states the first lens before the review starts. Approved
wording (2026-09-18), for `sema/spec/authoring/types.md` "Schema Header
Requirements", after "`description` MUST describe structural meaning":

> A type's `description` and its property descriptions SHALL NOT name
> other vocabulary words; a `$ref` carries the relation.
> `extended_description` is the only prose that MAY name other words.

The enum and format authoring spokes take the same sentence for their
descriptions, and `authoring/type-semantics.md` "`extended_description`"
gains one line saying it is where other words are named. The edit goes
on a `jm/` branch off sema `dev`, alone, never folded into a word edit.

## Whitewire heat-call threshold: measure before pinning

The House0 gen pins 10 W in each zone's heat-call derived channel and
the retiring scada setting says 20 W; neither has been checked against real
readings. Analyse the `zone{i}-{label}-whitewire-pwr` history for every
house that has one (journal DB; beech, maple, oak, fir, elm, the older
spruce data) to see what a calling and an idle zone actually draw, then
decide whether one uniform threshold serves every house or the value
belongs per zone in the hardware layout. Until then the 10 W pin stands
as an assumption.

## Pico params words and flow picos outside the checks

- The four pico params words (`tank.module.params`,
  `async.btu.params`, `flow.hall.params`, `flow.reed.params`) are in no
  vendored closure, so the conformance test does not see their gwsproto
  twins; a hand-run `sema validate` is their only check. Whether they
  join a closure is undecided.
- `flow.reed.params` 101 (published) has no gwsproto twin;
  `actors/api_flow_module.py:38` holds local `FlowHallParams101` and
  `FlowReedParams` models with bare `str` fields.
- No gen emits a flow pico into a sim fixture (the sim pairs read flow
  through `SimSensorActor`), and `ApiFlowModule` does not run over
  `sim.pico.flow.module.component.gt`; its only tests patch a House0
  pair in the test.
- `PicoBtuMeterComponentGt` is `use_enum_values=True`, alone among the
  pico component twins, so its enum fields are strings at runtime.
- The BTU actor's params answer sets every layout-held field except
  `GallonsPerPulse`, which goes back as the pico posted it; to confirm
  that is intended.

## What `data.latest_temperatures_f` values are

`data.latest_temperatures_f` is a different thing from a channel
reading (rounded, implausible store layers scrubbed, missing ones
filled from below, about seventy readers in the House0 control
code); whether its values become `Temperature` is a decision to take
before touching it.
