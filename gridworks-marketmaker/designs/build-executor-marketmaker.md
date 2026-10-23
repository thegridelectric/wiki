# Build the marketmaker executor

Status: Draft · Pass 0 · Updated 2026-10-22 · Linear: OPS-617

**EDD: yes** the trace replay is the verification: the marketmaker
executor reaches Verified when every clause has a vector and every
trace replays green against the built service over the dev broker.

> What this is: the first executor for `gridworks-marketmaker`, in the
> table-shaped recipe (`../../conventions/executor-CLAUDE.md`). The
> domain today is the stopgap maker, one service that publishes
> `latest.price` for the Keene constraint market at the top of every
> hour and drops bids; the full maker (bids, acks, clearing, the
> storefront) is OPS-431 and extends the same executor. The stopgap's
> locked decisions are below as the content the port starts from.

## Where it stands

- `../executor/` does not exist. The repo has the service, its tests
  (`ci.sh` green), `template.env`, `service/`, and the vendored sema
  snapshot with its seed.
- The stopgap is deployed and Verified: `experiments/2026-10-22-stopgap-mm/`.
- The maker is a counterparty of the LTN (scada executor) and a source
  for the journal (journalkeeper executor) and the settled-price series
  the web backend will read; those are its Boundaries rows.

## The stopgap, distilled

What the service does now, carried into the executor's rows.

1. **Identity.** The registered GNode `hw1.isone.me.versant.keene`
   (`GNodeClass: MarketMaker`, GNodeId
   `e6adb372-62ad-412c-bb2d-77fc428e3aac`), on its own box `mm` with one
   FIS principal and cert; the identity file is the registry's served
   record. Slot names are
   `e.rt60gate5.<maker alias>.<slot-start-s>`: the market is real-time
   on purpose, since the houses respond to real-time volatility and the
   day-ahead series the price-forecast service serves is a forecast of
   it.
2. **The publication.** One `latest.price` v000 per hour, at the top of
   the hour, broadcast on the maker's mic exchange with routing key
   `rjb.<hyphenated maker alias>.mm.latest-price`; `FromGNodeAlias` the
   maker, `PriceUnit` `USDPerMWh`, `PriceTimes1000` the energy price the
   house pays for the slot, `MarketSlotName` the slot that just opened.
   A maker that boots mid-slot publishes nothing until the next top of
   hour: one price per slot.
3. **The price at the gate.** ISO-NE's current 5-minute real-time LMP at
   the Keene Rd node (`fiveminutelmp/current/location/43790`,
   `LmpTotal`), fetched seconds before the hour so the publish is inside
   the LTN's five-second window, plus the Versant delivery price for the
   hour from a tariff table copied from the price-forecast service
   (retired by OPS-610's tariff vocabulary).
4. **Without a fresh price, the last one and a glitch.** If ISO-NE does
   not answer in time the maker publishes the most recent price it
   fetched and sends a `glitch` at `Critical`: a stale price is
   preferred to no contract, and someone is paged.
5. **How the LTN hears it.** gwbase's fabric bridges `mmmic_tx` to
   `amq.topic` on `rjb.#`; the LTN subscribes on its MQTT link to
   `rjb/<hyphenated maker alias>/mm/latest-price` and feeds the decoded
   word to its contract handler.
6. **Bids are dropped.** The maker binds its queue like any maker and
   answers no bid; the ack is the binding contract and arrives with
   OPS-431.

Open from the stopgap, for the executor's Open rows: a final settled
price per slot after the hour (this word or a new one; OPS-431 or
OPS-437) and the read façade that serves the series; the maker's GNode
is `Pending` in the registry; the LTN's bids reach `amq.topic` and the
fabric has no binding from there into `mm_tx`, decisive for OPS-431.

## Plan

1. **Seed copy.** The maker's `sema_seed_request.yaml` into
   `executor/`, byte-identical.
2. **Port.** Hub Axiom 1 is the sema axiom; the one-price-per-slot
   rule, the gate timing and the stale-price fallback become hub
   axioms with clauses; the publication, the gate fetch and the bid
   drop become Concerns; the registry record, the broker fabric, ISO-NE
   and the tariff table are Boundaries rows.
3. **Traces.** The hw1 first hour is the first trace: the published
   word in `experiments/2026-10-22-stopgap-mm/instances/` is its
   expected output.
4. **Adversarial pass**, per Concern and at the Domain, then Accepted.
