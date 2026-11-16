# Price stages

Status: Accepted · Pass 1 · Updated 2026-11-16 · Linear: OPS-684

**EDD: yes** for a window that spans a weekday on-peak start, the journal
shows the MarketMaker's `Provisional` price for the slot within 5 s of
the top of the hour and its `Final` price when ISO-NE posts the hour's
first five-minute interval; the house's heat pump call drops at the top
of the hour on the provisional clearing and no turn-on precedes the
final price; and a reader with the two READMEs and no GridWorks access
reproduces every number in both prices from ISO-NE and the Versant
tariff sheet.

> What this is: the MarketMaker states a slot's price in two stages, so
> the house can act at the top of the hour on what is already certain
> and bind on what the ISO posts; the LTN acts on a provisional price
> only toward less consumption; and the two price services say in their
> READMEs exactly which outside sources they use and how to check them.
> The interim structure for a market that will one day take the ISO's
> own dispatch, built so only the maker's source for the provisional
> stage changes then.

## Why

The maker's price for a slot was the previous hour's :55 five-minute
LMP, fetched 20 s before the hour and published at the top of it. A
check of 2026-11-15 against ISO-NE's posted prices for Keene Rd found
every published wholesale part equal to that sample and the first hour
20 USD/MWh under ISO-NE's hourly price. The market's real-time hourly
price is defined as the hour's first five-minute LMP, the interval that
begins as the slot opens, and ISO-NE posts it 21 to 34 s into the
interval (five boundaries measured 2026-11-15; the log is
`scratch/isone-posting-latency.csv` in the umbrella). A house that waits
for it runs its heat pump into the first half-minute of every on-peak
hour, at 588.5 USD/MWh winter on-peak delivery against 58.6 off-peak,
and a heat pump that holds its state five minutes once switched turns a
wrong turn-on at the top of the hour into five minutes of on-peak
running. ISO-NE's own resources never wait on the published price: they
follow a MW Desired Dispatch Point sent before the interval
(`regulatory/isone/real-time-dispatch/primary.md`). The delivery part
of our price is certain a day ahead and the wholesale part is known
within a few dollars from the interval before, so the house's clearing
is known at the top of the hour in nearly every slot and beyond doubt
at an on-peak boundary.

## Decisions

- **The maker states the price at every stage.** The maker owns the
  market's statement of price, its adjustments and its settlement with
  the ISO. It reads nothing from the price-forecast service; its only
  outside sources are ISO-NE and the tariff sheet.
- **Two stages, the maker's stages of commitment**, in a new enum
  `price.stage` 000: `Provisional` (the maker's statement of the slot's
  price at the top of the hour, before the ISO's price for the interval
  exists; a bidder acts on it only toward less consumption) and `Final`
  (the maker's binding price for the slot; the contract binds at it).
  The stage names the maker's commitment and says nothing about where
  the number came from. ISO-NE's later verified five-minute price is
  the maker's settlement with the ISO and is not a stage of this
  market's price. The enum's default is `Provisional`: a reader meeting
  a stage it does not know treats the price as not yet binding.
- **`latest.price` 002 adds one required field, `PriceStage`.** Slot
  name, parts and tariff are unchanged, so the journal, the backend
  route and the panel keep reading it; the panel draws the stages
  apart. The upgrade from 001 assigns `Final`: every 001 price was the
  price the contract settled at. The 001 prose that calls the price the
  one a contract settles at is dropped in 002, since with stages that
  is true of `Final` alone.
- **Provisional at exactly the top of the hour**: the last wholesale
  parts the maker published, which are the previous slot's first
  interval, plus the tariff's delivery for the hour. The maker has both
  in hand and fetches nothing. When the maker is a DARD and receives a
  Desired Dispatch Point before the interval, the provisional value
  becomes the price that dispatch implies, under the same stage name,
  and nothing downstream changes.
- **Final when ISO-NE posts the hour's first interval**: the maker asks
  every second from the top of the hour and publishes on the first
  answer that is the slot's own interval. At `fetch_deadline_s` (240 s)
  without it the maker publishes `Final` at the provisional value with
  a critical fault. One `Final` per slot; a later ISO posting changes
  nothing for that slot. Built on maker branch `jm/price-at-slot-open`
  (2026-11-15), before the stage field.
- **The rule of this market when no Final is published**: if the maker
  publishes no `Final` within 240 s of the top of the hour, the
  `Provisional` is the `Final` and the contract binds at it. The rule
  is written in the marketmaker executor; the LTN implements it by
  treating the provisional as binding at 240 s with no final.
- **The LTN acts on a provisional price toward less consumption only.**
  At the top of the hour it reads its bid curve at the provisional
  price. A running heat pump, or a reading of zero, is offered the
  reading; a heat pump that is off is offered 0 W, since a turn-on the
  final would reverse costs five minutes of locked state. At the final
  it reads the curve again and amends the contract once where the
  reading differs. With no final by the terms' 240 s the provisional is
  the final and a held-back offer is amended to its reading. The 240 s
  is read from the dispatch terms constant; the 5 s window is gone.
- **The LTN reconciles a desired offer against the contract the scada
  holds.** The LTN keeps two records for the slot: the desired offer
  (the bid's reading and the stage it was read at) and the
  observed contract (the scada's last heartbeat). A price event only
  changes the desired offer: the Provisional sets it under the
  less-consumption rule, the Final replaces it, the deadline promotes a
  Provisional to Final. One reconcile step runs on every event and on
  each heartbeat tick and sends the one message the difference calls
  for: completion when the previous slot's contract is still held past
  its end, Created when the slot has a desired offer and no contract,
  Amended when the acked body differs from the desired offer and the
  terms allow it, a resend of the same Amended while it is unacked, else
  the ordinary heartbeat. The scada acks an Amended whose body equals
  the contract it already holds, so a resend is harmless. Both records
  persist, so a restart between the stages resumes the slot. Nothing in
  the LTN waits on a reply, and no flag records where in the hour the
  LTN thinks it is. This is the first part of the LTN's loop rebuilt the
  way the LTN as a whole is to be rebuilt (the LTN executor's cleanup
  epic); the rest of the loop keeps its form for now.
- **The Created does not wait on the previous slot's completion.** The
  reconcile step at the Provisional sends the completion of an expired
  held contract and the new slot's Created together; the scada takes a
  Created while it holds an expired contract, wrapping the old and
  starting the new, and the completion reply closes the old record only.
  A Created is stamped within 10 s of `StartS` (`slow.contract.heartbeat`
  axiom 1), so a slot with no Created inside those 10 s gets no contract
  and the LTN says so in a glitch.
- **The scada answers a resent Created with the heartbeat it holds**, as
  it answers a resent Amended with Active, so an LTN whose ack was lost
  obtains it on the next resend.
- **The amendment goes Active at once.** SuitUp is the ally's once-per-wake
  statement, and an amended contract reaches an ally already dispatching
  under the same ContractId, so there is no SuitUp to wait for. The
  refusal gate is re-read before the body goes to the ally and before
  the amendment is taken; a scada that has given the contract up answers
  with the refusal, not an ack.
- **The LTN does not dispatch oil.** Fuel substitution was off on every
  LTN and its threshold a constant tuned to a delivery price the tariff
  no longer has, so the LTN's fuel-substitution settings and rule are
  removed with the rebuild, and `slow.dispatch.contract` 001 states
  electrical power only: `OilBoilerOn` and its axiom are gone from the
  word, the twin and the allies' reading of a contract. The allies'
  non-electric backup state stays with nothing entering it from a
  contract. When fuel substitution returns it is an operational
  parameter of the house, with a COP-aware comparison against the served
  tariff, and the contract gains the flag then.
- **The slot stays on the clock hour.** Everything it settles against
  is on the clock hour: ISO-NE's hourly LMP and the tariff's periods.
  The honest statement is when the slot's price is known, not a shifted
  slot start.
- **Outside sources are explicit in the READMEs.** Each of
  `gridworks-marketmaker` and `gridworks-price-forecast` names every
  outside source it reads (the ISO-NE Web Services endpoints with
  location 43790 LD.KEENE_RD44, the Versant A-1 sheet with page and
  revision), links it, and gives the how-to a reader outside GridWorks
  follows to reproduce a published number: which ISO Express report,
  which row, which tariff line, and the arithmetic. The bar is a
  teammate checking a day's prices without asking anyone.

## Plan

**Do this next:** the dev-stack provocation run in simulated time, both
the sim scada and the LTN on `clock_source: Timestep` with a coordinator
publishing `sim.timestep` and a harness publishing the slot's Provisional
and Final: lost completion reply, Final before the ack, restart between
the stages, no Final by 240 s, a second-hour contract acked at once. The
maker publishes `PriceStage` on `jm/price-at-slot-open` (step 2 below).
The reconciler is on scada `jm/price-stages` against the difference list
below, each item with its test; the scada's contract path reads the
plant clock, so the run's hours pass in seconds. The run goes on the
laptop hand-stack (`experiments/dev-stack-recipe.md`; the June sim-time
bridge harness publishes the timesteps) and does not wait for the docker
dev universe, which has no date and no coordinator in its plan. The
harness is written to the dev-stack contract so the docker universe
inherits it: every broker coordinate from settings under the service's
own prefix, the coordinator's broker its own setting, no hardcoded
localhost; one foreground command per process, logging to stdout;
readiness by probe, never a sleep; state and identity files under the
service's config home; the LTN restart through one function; a fresh
broker and fresh identities assumed each run. The run is also where sim
timesteps first drive a scada and an LTN, so it delivers three things
beyond the scenarios, with no change to its estimate: the time
coordinator as its own process, one foreground command with its broker
from settings, so it becomes a compose service unchanged; a record of
what in the scada follows the Timestep clock and what still reads wall
time, as found (the simulated plant's own timers are known not to); and
the same record for the LTN, what it took to run it on the Timestep
clock. The two records are the input to OPS-40, the plant on
coordinator time. While the PRs are open, the traces, the README notes
and the rules of engagement in words are kept in this folder as the
draft of the executor, and move to the marketmaker executor, the scada
executor's contract-lifecycle sub-spec and the two repo READMEs at
merge.

*Differences, each with the test that pins it
(`tests/actors/test_ltn_offer_rule.py` unless named):*

1. The desired offer and the observed contract are two persisted
   records keyed by slot; `provisional_wh`, `final_received`, `amended`
   and `next_contract_energy_wh` are gone. Test: a restart between the
   stages resumes the slot (held-back offer amended at the Final after a
   reload); a restart after the amendment makes no second one.
2. The Provisional sets the desired offer under the ReduceOnly rule
   (reading when the heat pump runs or the reading is zero, else 0 W)
   and records the reading; the reconcile step sends completion for an
   expired held contract and the Created in the same step. Test: a
   Provisional with the previous contract still held sends both, and the
   completion reply does not create a second contract.
3. The Final replaces the desired offer, whether or not a contract is
   acked yet; the amendment goes when the ack is in. Test: Final before
   Received, then Received, yields one Amended after the Received.
4. A Final the LTN cannot read (no bid, stale bid) leaves the desired
   offer as it was, and the deadline promotes the Provisional. Test:
   stale bid at the Final, deadline amends to the Provisional reading
   with the no-Final cause.
5. The deadline is a plant-clock time (`StartS` + `FinalDeadlineS`)
   checked by the reconcile step, not a wall-time sleep; it runs only
   for a slot with a desired offer. Test: a deadline tick at 239 s does
   nothing, at 240 s promotes; no desired offer, no promotion.
6. An Amended is resent unchanged (same `MessageCreatedMs`, same body)
   until acked, as a Created is; an Amended the scada refused (no reply,
   count exceeded) is not resent past the hour. Test: two ticks with no
   ack resend the same heartbeat; a scada Active with the amended body
   stops the resend.
7. The amendment checks the price's slot against the held contract's
   and the contract's expiry, on both sides. Tests: a Final for another
   slot amends nothing; `tests/actors/test_contract_amendment.py`: an
   Amended for an expired contract is ignored.
8. The committed heartbeat loop's completion resend at 60 s stays; the
   reconcile step also runs on every scada heartbeat, so a lost reply
   is retried at the next tick rather than only at 60 s. Test: a lost
   completion reply is resent on the next tick.
9. `hp_is_off` before the first Report: the Ltn starts it `False` (heat
   pump counted on) and the handler `True`. The reconciler reads one
   value with a stated start. Test: a Provisional before any Report
   offers under the stated start.
10. The Provisional abort moved from "seconds 0 to 5 of minutes 1 to
    59" wall time to "more than 10 s after the hour" on the plant
    clock, so an 11 s late Provisional makes no offer (axiom 1 above).
    Test: a Provisional at 11 s sends nothing and a glitch.
11. `keep_cleared_path` runs before the abort (committed behaviour,
    kept). Test: the cleared path is kept at an aborted Provisional.
12. `Confirmed` stays in the handler's active states (committed) but no
    path produces it: it is an LTN status by heartbeat axiom 2a and the
    LTN never sends it. Nothing to pin; the tick test uses Received.
13. The scada's amendment goes Active at once, with no SuitUp wait, the
    refusal gate re-read (Decisions). Test,
    `tests/actors/test_dispatch_refusal_gate.py`: an Amended under a scada
    that has gone blind is answered with TerminatedByScada and its reason,
    and the amended body is never held.
14. The scada acks a Created at once when the ally is already awake, and
    a resent Created with a fresh heartbeat at the held status. Reading
    the scada found this is the normal path, not the lost-message case:
    the ally suits up once per wake and goes dormant only at an
    auto-state change, so every hour's contract after the first brought
    no SuitUp and the scada never acked it; the LTN ran those hours with
    its contract at Created. Tests, `tests/actors/test_contract_amendment.py`:
    a resent offer is acked again with a fresh heartbeat. The scada-level
    wiring (ack at once in LeafTransactiveNode state) is pinned in the dev
    stack run.
15. The scada answers an amendment it does not take (count exceeded,
    unknown terms) with a fresh heartbeat at the body held, so the LTN's
    record converges on the scada's and the hour completes on one body.
    Tests, `tests/actors/test_contract_amendment.py`: a second amendment
    and one under unknown terms are answered with the body held.

Then the backend and panel step: the latest-prices route returns the
stage and the panel draws `Provisional` and `Final` apart.

1. **Sema**: `price.stage` 000; `latest.price` 002. Vendor into the
   maker, the LTN, the backend, the journal.
2. **MarketMaker**: publish `Provisional` at the top of the hour from
   the last published wholesale parts plus delivery; publish `Final`
   from the gate as built; the deadline publish is `Final` at the
   provisional value with the fault. The no-Final rule in the executor;
   rows and traces.
3. **LTN**: the reconciler, built on scada `jm/price-stages`; the spec
   goes to the scada executor's contract-lifecycle sub-spec, to be
   opened.
4. **Backend and panel**: the latest-prices route returns the stage;
   the panel draws `Provisional` and `Final` apart.
5. **READMEs**: the outside-sources section in both repos, with the
   verification how-to; a teammate runs it on one day's prices.
6. **The verifying window** on `tsdb_tap`, spanning a weekday on-peak
   start.

The Keene product cutover to `rt60gate1` and its verifying window stay
with OPS-666.

## Spokes

The draft of the executor, held here while the PRs are open:

- [`contract-notes.md`](contract-notes.md): the traces by scenario, the
  README notes, the rules of engagement in words.
- [`dispatch-terms-agreement.md`](dispatch-terms-agreement.md): the
  draft legal agreement the first dispatch terms constant names.
- [`clearing-price-vs-iso-participation.md`](clearing-price-vs-iso-participation.md):
  the maker's clearing price to its aggregation against its
  participation in ISO-NE's markets on the aggregation's behalf.

## Open

- The posting lag across a full day and in stressed conditions, from
  the running log.
- What the house is in ISO terms for the DARD path (the standing in
  `regulatory/isone/real-time-dispatch/primary.md` "Open").
