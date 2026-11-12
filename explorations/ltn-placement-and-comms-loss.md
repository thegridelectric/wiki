# LTN placement and comms-loss resilience

Status: Draft · Pass 0 · Updated 2026-11-11

> What this is: a working evaluation of where the LTNs should run (OPS-667
> moves them to Hetzner Helsinki) against dispatch latency and the
> comms-loss scenarios, with the standby options costed and a
> recommendation. Decoupled from the control-plane sketch in
> `fleet-planes-pets-to-livestock.md`; that file states where the LTN
> runs and why, this one works the outage and standby questions.

## 1. The fastpath, as built

Every scada and every LTN talks to one broker, `rmqbot` on `hw1-1` in AWS
us-east-1 (`gridworks-infra/platform-inventory.md:23`). A scada never
addresses its LTN directly; a dispatch is a message to the broker and a
message from the broker. So the element whose location sets dispatch
latency is the broker. The LTN's location adds one leg between the broker
and the LTN.

Legs, one way (the Helsinki figure is this session's measurement; the
others are general knowledge for East Coast paths):

| Leg | One way |
|---|---|
| Millinocket Pi → us-east-1 broker | about 15 to 30 ms |
| us-east-1 broker → Helsinki LTN | about 55 ms (110 ms RTT measured) |
| us-east-1 broker → a US LTN (same region) | under 2 ms |

The hour begins with the price. The MarketMaker (`mm`, hel1) publishes
the price through the broker; the LTN receives it, runs the FLO (the
`flo` box, hel1) and sends the scada its contract for the hour; the scada
acks. Nothing goes to the scada before the price is in hand. With the LTN
in Helsinki the chain is mm → broker → LTN → flo → LTN → broker → scada:
four transatlantic legs of about 55 ms plus the FLO run, so well under a
second of transport before the FLO's own seconds. From us-east-1 the LTN
legs are under 2 ms each and the mm and flo legs stay transatlantic
either way, since both boxes are in hel1. The control loop's own
timescales are far above that: offers are created inside ten
seconds of the top of the hour (`scada-ltn-link-state.md:127`), the
contract heartbeat is every 60 s (`:78`), the proactor ack timeout is 5 s
(`:25`), the link ping fires after 60 s of quiet (`:29`), and the heat pump's
ramp and wind-down are up to 62 s at spruce (`magic-thresholds.md:42`). The
extra 100 ms is two percent of the ack timeout and invisible to the hour.

Co-location starts to matter when dispatch becomes sub-second (frequency
response, fast ramping on an ISO signal). At that point the broker and the
LTN both have to sit near the houses, and the broker is the bigger move.

## 2. What the scada does when the LTN disappears

Nothing is emitted live on a link drop; both sides store the comm event
until the link is back (`scada-ltn-link-state.md:308`). The contract
heartbeat has no silence deadline of its own; the only time-based rule is
contract expiry (`:83`). When the hour's contract ends and no new offer
arrives, the scada is in LocalControl with no contract and takes the next
offer when one comes (`dispatch-gate.md:189`). So an LTN outage of
any length degrades the house to local time-of-use control at the end of
the current hour. Heat continues. Market participation pauses.

That is graceful degradation, and it holds whatever the LTN's location.
What is lost during an LTN outage is bidding, settlement and the
optimizer's plan. Nobody gets cold.

## 3. Comms-loss scenarios

| Scenario | Realism | What happens today |
|---|---|---|
| (a) EU to US severed, US intact | Rare on its own. Transatlantic capacity is many cables on many landings; a full severance with the US internet intact implies a political act, which is scenario (e). | LTN in hel1 drops off. Houses go local at the hour. The flo box in hel1 is unreachable anyway, with or without the LTN move. |
| (b) us-east-1 down (the broker) | The realistic one. us-east-1 has had multi-hour region outages. | Every scada and LTN loses the broker. Houses go local at the hour. LTN location is irrelevant. |
| (c) hel1 down | Plausible, same order as (b). | LTN and FLO both gone. Houses go local at the hour. Today only the FLO is lost. |
| (d) Millinocket ISP or the house line down | The most frequent in practice. | That house goes local. Nothing a cloud placement can change. |
| (e) Account closed, provider exits, sanctions, company fails | Slow and visible, days to months of notice in most forms; abrupt closure of an account is the sharp case. | Whatever is on that provider is gone until rebuilt elsewhere. Rebuild time is the metric. |
| (f) Broad internet fragmentation | The vision's premise case. | Only what runs inside the fragment that holds the houses keeps working. |

Honest summary: (a) alone is rare, and in every scenario except (c) the
broker's location decides the outcome. Moving the LTN to Helsinki adds
(c) to the list of outages that pause bidding and changes nothing else.

## 4. The terms

- **Cold standby**: a recipe and backups, built on demand. Rebuild in hours.
- **Pilot light**: the box exists and is configured, services stopped.
  Minutes to start.
- **Warm standby**: box running, software current, not connected. Seconds
  to a minute, after a human or a gate says go.
- **Hot standby, active-passive**: running and connected, taking over
  automatically on a failure signal.
- **Active-active**: both serve at once. Ruled out for a GNode principal by
  the FIS lease.
- **Graceful degradation**: what the scada already does at the hour.
- **Islanding**: the grid analogy. A local segment keeps running on its own
  resources when the connection to the wider system is lost, and
  resynchronises later. The software version is a local broker plus local
  bidding.

The FIS gate leases a cert to one running process; a connect with a new
instance id supersedes the lease, kills the old holder and refuses it for
life (`gridworks-infra/fis/README.md:81`). So for an LTN the only safe
standbys are pilot light and warm, with an explicit handover step. Hot
standby would need the gate to know about a designated successor, which it
does not today.

## 5. Options

| | Option | Monthly | Protects against | Dependence |
|---|---|---|---|---|
| i | LTN in hel1, no standby (OPS-667 as filed) | $7 | nothing new; (b) and (d) already degrade gracefully | Hetzner for LTN and FLO, AWS for the broker |
| ii | i plus a warm standby in the US: a t4g.small in us-east-1 or a cpx11 in Ashburn with the six checkouts and certs staged, units stopped | $16 to $21 | (c), and a fast rebuild path for (e) on Hetzner | adds AWS or Hetzner US |
| iii | LTN on the house Pi (the home-assistant-ltn direction) | $0 | (a), (c), and the LTN half of (e); the Pi still needs the broker for the market | the broker only; FIS identity provisioning on the house box is open (`explorations/home-assistant-ltn.md:45`) |
| iv | Millinocket island: a local broker and LTNs on a small box in town, cloud broker upstream by shovel | $50 to $100 with a business line, or $7 at a volunteer site | (a) through (c) and (f) for everything local; the market needs a local MarketMaker to mean anything during an island | a local site and its ISP; no large provider in the local loop |
| v | Distributed broker: a second broker on another provider, federation or shovels, the FIS gate replicated | $40 to $60 | (b) and (e) for the broker, today's single point | two large providers instead of one |

On the vision's premise: options i, ii and v move dependence between large
providers. AWS and Hetzner are both corporations under their own
governments. Option iii removes the LTN from the cloud entirely. Option iv
is islanding, and is the only shape in which the houses keep trading with
each other when the wide internet is gone. The MarketMaker in that shape
has to be local too, and the registry has to be readable from a cached
copy. That is the same shape the vision describes: a market that works at
the scale of a town.

## 6. Recommendation

Do OPS-667 as filed. Add one line to it: the LTN box is pilot-light
rebuildable from `ltn/instance-README.md` and a pushed SHA, and no second
LTN process is ever started while the first holds its lease. Hold the
scada-side fact in the ltn executor's open items: an LTN outage degrades
the house to local control at the hour and the broker's location is the
fastpath.

Do not build a warm standby now. The scenario it covers, hel1 down with
us-east-1 up, costs an hour of bidding per house and heats nobody's home
less. Its $20 a month buys more as a second broker later.

Option iii is out. The LTN stays in the cloud for three reasons stated in
`fleet-planes-pets-to-livestock.md` "Control Plane": the LTN changes far
more often than the scada and a cloud box redeploys in minutes; houses go
offline far more often than cloud boxes, and the LTN is the house's
representative in the market and has to outlive the house being offline;
the code path to a cloud box exists and the Pi update path (OPS-401) does
not.

Decide the next step on two triggers. The first is dispatch cadence: when
a contract moves from the hour to minutes, or an ISO fast-response product
is in play, the top-of-hour chain (price → LTN → FLO → contract → scada)
repeats per slot, and the broker, the MarketMaker, the FLO and the LTNs
move to one US location together. The second is the first cluster outside
Millinocket, or the MarketMaker launch: at that point the local island
(option iv) is a design hub, with the local MarketMaker and a cached
registry as its two open questions. The vision argues for iv as the
eventual shape. Nothing in OPS-667 moves away from it.

## Open

- Scenario (e), a provider or account closure, has no rehearsed
  rebuild. A timed rebuild of one platform box from its instance-README
  on the other provider would put a number on it.
- The local island's MarketMaker and registry cache are undesigned.
