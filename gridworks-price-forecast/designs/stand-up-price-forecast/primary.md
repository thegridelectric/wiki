# stand-up-price-forecast

Status: Draft · Pass 0 · Updated 2026-08-13 · Linear: OPS-437

**EDD: yes** the bar is real-broker price-forecast delivery in
production, consumed by a real LTN FLO and/or the MarketMaker —
claims reach Verified only through experiments against a real
broker, same bar as the weather standup.

> What this is: stand up the price-forecast service (electricity
> price / LMP forecasts) as a gwbase-native cloud GNode — parallel to
> the LTN, FIS, MarketMaker, TimeCoordinator, and to gwwf, the weather
> service this design is modeled on (its rebuild spec:
> [`../../../gridworks-weather-forecast/executor/primary.md`](../../../gridworks-weather-forecast/executor/primary.md)).
> Spun up 2026-08-13 as a scaffold, reusing what the weather standup
> already proved out — this is a placeholder until a real design
> session settles the price-forecast message shape, cadence, and
> source. Not to be confused with the legacy `PriceDb` AWS box
> (`54.205.80.28`) — that's market/backoffice settlement data, a
> different system entirely.

**▶ Active spoke: none yet — this design is not started.**

## What ports directly from the weather standup (settled by precedent)

- **Deployment posture.** Shares the `forecast` Hetzner box with gwwf
  (settled when the box was built, 2026-08-12) — own login `price`,
  own on-box Postgres container claiming the next `543x` port
  (`5437`), per-person keys (`forecast-{jessica,thomas,joe}` open
  every login on this box, no per-service split — see
  [`gridworks-infra/forecast/instance-README.md`](../../../../gridworks-infra/forecast/instance-README.md)).
- **The create-command round.** Records enter by a human act whose
  request crosses the wire as a sema word — one command word with a
  closed `oneOf` Record slot, ack/nack twins, mirroring
  `g.node.create.cmd`. Proven design; port the shape, not the
  vocabulary.
- **GNode registration, done BEFORE minting anything.** The lesson
  from 2026-08-13 (weather's identity was self-asserted and never
  actually registered until caught late): check `gnr` for an
  existing registration at the intended alias FIRST
  (`/gnr/g-node-by-alias/<alias>`), verify gwbase's vendored
  `g.node.gt` supports the registry's current schema version,
  register for real via `gnr create` if absent, and always write the
  local `g.node.gt.json` FROM the registry's served record — never
  hand-authored. (See the weather primary.md's Identity bullet for
  the full incident.)
- **JK capture pattern.** Journal every message type from first
  broadcast (messages-table-only to start); if price has an
  observed/current-price analogue the way weather has observed vs.
  forecast, the same bundle-triggered auto-create-pseudo-channel
  mechanism (`WeatherBundlePersistor`'s pattern) likely applies —
  confirm once the vocabulary settles whether price actually has that
  duality (LMP is arguably always a forecast/settlement pair, not an
  observation like weather's KMLT reading).
- **`service/bash_aliases` from day one** — `pricestart` /
  `pricestop` / `pricerestart` / `pricestatus` / logs, wired into the
  box's login the same way `weatherstart` etc. are, not bolted on
  after a deploy confusion (that cost real time on the weather side).

## What does NOT port — genuinely open, needs a real session

- **Auth posture.** OPS-437's own stub note says "FIS-authed on the
  broker" — a real divergence from weather, which runs on plain
  `smqPublic` with no FIS involvement. This is a first-class open
  question, not a detail: does price need FIS because of who
  consumes it (the LTN's FLO, MarketMaker — both plausibly
  higher-trust surfaces than a public read API), and what does
  "FIS-authed" concretely change about the actor's broker connection
  and the create-command round's authority story?
- **The vocabulary.** No `gw.price.*` words exist. Quantities, units,
  cadence, forecast horizon/slice shape, source (ISO-NE day-ahead?
  real-time? both?) — all open.
- **Source posture.** Unlike weather (NWS is free, public,
  well-understood), ISO-NE market data access terms, cost, and
  latency are unresearched.
- **Whether price has an "observed" series at all**, or whether it's
  forecast-only until ISO-NE settlement data arrives on a different
  path — this decides whether the weather word-shape (one
  observation word + one forecast word + a bundle) is even the right
  model, or whether price needs something structurally different.

## Spokes

None written yet. When this design actually starts: `/grill-me` first
(per the design-loop convention), then draft `vocabulary.md` and
`delivery.md` before any code, mirroring the weather standup's own
sequencing (word-gate closes before `build.md` starts).
