# Odds and ends (spoke)

Status: Draft · Pass 0 · Updated 2026-09-15 · Linear: OPS-392

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
