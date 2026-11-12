# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-ltn` code repo** (currently `gridworks-scada/gw_spaceheat/actors/ltn/`
until the LTN extracts to its own repo). The matching git commit
holds the WHAT (the diff). Each entry's date and one-line title
mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-11-11 — ltn box is now on Hetzner (gridworks-infra `02aa453`, main, OPS-667)

The six house LTNs run on a Hetzner cx23 in hel1 (`ltn.electricity.works`,
2.29.33.23) beside the flo and mm boxes; the AWS c5.large is stopped and
is terminated after a day of clean acks. The box costs $7 a month against
$62. The LTN only talks to the broker: its RSS is about 110 MB a house and
its CPU idle, and the broker round trip from Helsinki is about 110 ms
against a 5 s ack timeout, so the sizing and the latency were both
measured before the move. Each house moved by stopping and disabling its
old unit, copying `.env`, the layout pair, the cert and `.local/` state,
and starting the new unit; each came up with its mqtt link active and
layout received within ten seconds, and the running hour's contract
resumed its heartbeat. All six are on `main` at da268051; maple's
`jm/sieg-init-homing` is re-rolled by hand. gridworks-infra:
`ltn/instance-README.md` is the build-from-nothing recipe and the
non-repo state list (login `ubuntu` kept because the unit, the `.env`s
and `roll.sh` name `/home/ubuntu`; sudo for the units only; journald
capped at 200 MB), `ltn/README.md`, `platform-inventory.md`,
`fleet-inventory.md` and `authority/ssh-access.md` say where the LTNs
run.

## 2026-11-10 — Snapshot at the flo plot words with the store's bounds and the path cost (`3c9528f`, jm/hello-world, OPS-665)

Snapshot at sema `58a55b4`, the published flo plot words.
`flo.tank.store.path` 000 has `EmptyStoreWh` and `FullStoreWh`, and
`flo.path.penalties.bruce` 000 has `TerminalCostEmptyStoreUsd` and
`PathCostUsd`, all required, so the LTN decodes a recommendation from a
bruce that fills them and refuses one from a bruce that does not. No LTN
code reads the new fields; the dashboard does. The LTN's seed still
reaches other staging words, so its staging index stays. `ci.sh` green,
53 passed.

## 2026-11-09 — fix logic in latest price rejection (`2676c92`, jm/hello-world, OPS-665)

The check that a maker's `latest.price` arrived at the top of the hour
was written as "minute is not zero and second is five or less", the
inverse of the log line beside it: it refused a price in the first five
seconds of any later minute and accepted every other time in the hour,
so a price at 14:20:10 cleared the bid and started a contract twenty
minutes into its slot. It also read the wall clock, which the sim rung
of the FLO harness does not move. The rule is now one function in
`market.py`, `latest_price_is_on_time`, on the plant clock: a price
within `LATEST_PRICE_WINDOW_S` (5 s) of the slot start clears the bid;
later leaves the bid held and nothing decided. A price before the slot
still discards the bid as stale, as before. Tests: the rule's
breakpoints in `test_market.py`, and the actor on a `ManualClock` in
`test_latest_price_window.py` (clears at 0, 3 and 5 s; holds at 6 s,
7:03, 10:10 and 59:59; discards before the hour). The contract handler's
own ten-second gate on contract creation is unchanged. The scada's MQTT
LTN has the same inverted check and is left as is; this repo is the
line that goes forward.

## 2026-11-09 — LTN keeps its cleared run as flo.previous.run. Uses flo.recommendation.001 (`acd5e1e`, jm/hello-world, OPS-665)

What the LTN keeps after a slot clears is one
word, `flo.previous.run` 000 (sema `6cb4f8d`, staging): the cleared pair
and its index, the path at that index, the request's wholesale plus
distribution forecast for the next slot as an integer times 1000 in the
recommendation's price unit, and the clock. It is saved to disk as the
word's bytes in place of the hand-made JSON, sent to the scada in place of
the bare path so the broker journals which path cleared, and read back
into the next request, which divides the price by 1000 for its float
field. Snapshot regenerated with `flo.recommendation` 001 and
`flo.previous.run` 000. OPS-665.

## 2026-11-08 — The LTN hears flo.refusal, logs in Maine time, and reads one clock (`d1e948a`, jm/hello-world, OPS-514)

Three ports in one commit, all to the gwbase actor.

**flo.refusal.** The scada-repo LTN's handling (gridworks-scada
`2703d6fb`). Snapshot regenerated from sema `dev` with `flo.refusal`
000 seeded. A refusal arrives direct over the Flo-to-LeafTransactiveNode
edge like the recommendation, on the same wildcard binding. One for the
open request is copied to the scada for the record and raised as a
Warning glitch so the fleet sees why the slot has no FLO bid; the LTN
then bids as it does when no answer comes. One for another bidder or
slot is dropped. Tests: the seam test publishes a refusal with no
request open (dropped, nothing reaches the scada) and one for a held
request (the copy and the glitch reach the stand-in scada, no bid goes
out).

**Maine time.** gridworks-base 0.7.3 renders log timestamps in the
service's `log_tz` with the UTC offset on every line; the LTN pins it
and its `.env` template sets `GWLTN_LOG_TZ=America/New_York`, since the
people reading the ltn box's logs are in Maine. The stdout stream
(journald) takes the same gwbase line format and zone as the actor's
file log, so the two agree on the hour; the same shape as gridworks-flo's
`d33e7b1`.

**One clock.** The mirror of gridworks-scada `05863872`. Two reads of
wall time were left in the actor: the bid-hour check in
`latest_contract_is_live` and the crop of the saved price CSV when the
price service is down. Both are now pure functions of a `now_s` that the
actor passes from its plant clock (`market.slot_is_current`,
`flo_request.price_forecast_from`), and every glitch and message stamp
is `plant_clock.now_ms()`, so a simulated run under a `ManualClock` sees
one time everywhere and `import time` leaves the actor. Also the mirror
of `a3bac74f`: the posture re-check in the FLO request path logs the
known race and returns, where it sent a Warning glitch.

## 2026-11-05 — The bid goes out GWLTN_BID_LEAD_S seconds before the slot (`a9c5adb`)

The LTN bid at minute 57 of the hour, a literal in the actor. The bid
time is now a setting, `bid_lead_s` (default 180), counted back from the
start of the next market slot, so the same rule serves a 5-minute market
when the slot shortens and a dev run can set the lead short and see a
round trip in minutes. The slot facts the rule needs, an hour long and
starting on the hour, are one hard-coded constant (`MARKET_SLOT_S` in
`market.py`), and the setting must be less than it; a cross-cutting
design moves them to the ops word and to what the MarketMaker posts
about its market. The actor refuses a lead shorter than its loop sleep,
which could pass between two wakes. `minute_of_hour` is gone;
`seconds_to_slot_start` replaces it, with its test and a settings test.

## 2026-11-04 — The LTN as a gwbase actor (`cbbb2aa`)

The LTN's first commit in its own repo, scaffolded from `gridworks-flo`
(uv, hatchling, `ci.sh` as the one gate with the workflow behind it,
`GwltnSettings(GNodeSettings)` with the `GWLTN_` prefix, the `gwltn
rabbit` entry point, a dev identity under `scripts/`). The modules are
copied from `gridworks-scada/gw_spaceheat/actors/ltn/` with the
gwproactor transport swapped for gwbase and the scada's wire unchanged.
`LtnActor(GridworksActor)` declares `GwGNodeClass.LeafTransactiveNode`
on gridworks-base 0.7.2, boots on the house's layout and operational
params (the layout names the scada it serves, so there is no separate
scada-alias setting), binds its scada's `gw.<scada>.to.ltn.#` on
`amq.topic` and the maker's `latest.price` on `mmmic_tx`, decodes each
scada message through the snapshot codec, and runs the ported match
block, main loop, ping and contract heartbeat on its own asyncio loop
thread; every inbound message is marshalled onto that loop, so the
LTN's state lives on one thread and pika's is the only other. Sends to
the scada go out wrapped on the `s` token, the scada being the one
MQTT-native peer: acks on `gw.<ltn>.to.s.gridworks-ack` inside the
scada's 5 s timer, a ping every 60 s. The FLO and the maker are GNodes
on the class fabric: `flo.params` goes to the FLO GNode
(`GWLTN_FLO_ALIAS`) as a direct message over the LeafTransactiveNode-to-
Flo edge, its `flo.recommendation` comes back direct and is paired with
the open request by bidder and slot (`market.answers_request`), the bid
goes off it direct to the maker named by the ops word, and an answer to
any other request is dropped. No bruce, no child process: the LTN runs
no optimizer. Dropped with the host: the dashboard, the typer CLI, the
MQTT-fed timestep clock, the gwproactor debug payloads, and the scada's
own plant checks in the layout loader.

The vocabulary is the LTN's own vendored Sema snapshot (`gwltn.sema`,
seeded by `sema_seed_request.yaml` at the one version of each word the
scada speaks, local names stripped of `gw.`/`gw1.`/`gw2.`, regenerated by
`scripts/regen_sema_snapshot.sh`): snake_case fields, PascalCase wire
form through `to_dict`/`from_dict`, `isinstance` dispatch, acks and pings
as `gridworks.ack`/`gridworks.ping`, the proactor's comm and lifecycle
events as their `gridworks.event.*` words. The snapshot allows staged
words because the layout and operational-params words are staging, so
it is dev-only until they publish. The repo depends on no scada package:
the LTN's view of the layout is `layout.LtnLayout`, a NamedTuple read
once off the sema layout word (the LTN and scada aliases, the zones and
their thermal mass, the water store, which store tanks exist, each
temperature channel's encoding); the four plant names it needs are
`names.py`; the temperature conversion is `temperature.py`; and the two
words with no sema word yet, `no.new.contract.warning` and `send.snap`,
are local `SemaType` classes in `words.py`, each named as retired by the
coined word.

The seam test boots the real actor on the willow test pair against the
dev broker: acks in under 10 ms, `layout.lite` and the operating status
reach the LTN's state, a stand-in maker's `latest.price` on its mic
exchange is kept, a stand-in FLO's direct `flo.recommendation` on
`flomic_tx` reaches the actor over the edge and is dropped with no
request open, and a second house's scada is not heard. The pairing rule
and the bid off a recommendation have unit tests in `test_market.py`.

---

_Earlier: no code commits._
