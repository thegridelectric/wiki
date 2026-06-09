# Vision vs. existing repo — evaluation notes

Status: Draft · Pass 0 · Updated 2026-06-09

> What this is: a **spoke** of the [launch design](primary.md) — background
> evaluation a design-agent leans on, not the plan itself. A first-pass read of
> the existing `gridworks-marketmaker` code held up against the **vision** for
> the launch MarketMaker. Two halves — the **Vision** we are building toward, and
> the **Existing** repo as it stands.
> Companion intent:
> [`../../explorations/launch-intentions.md`](../../explorations/launch-intentions.md);
> Sema modeling of products + uniform messages:
> [`../../explorations/market-product-and-uniform-bids.md`](../../explorations/market-product-and-uniform-bids.md).

## Vision

We are designing something **new** — the launch MarketMaker — from the vision
below, **not** porting the first-pass simulation code. The existing repo (see
*Existing*) never ran in production and the market-making machinery was **never
tested in reality**; it is a reservoir of design *intent*, not a template. Where
this vision and the legacy implementation conflict, the vision wins.

- **The maker is the authoritative advertiser of its own markets and their
  rules.** Each maker is the source of truth for which markets it runs and the
  rulebook of each (slot duration, gate timing, settlement, dispatch, penalties,
  price formation). See launch-intentions.
- **Bids are fast and cumulative.** A bidder streams cheap, incremental bids;
  the maker accumulates them. Because bids are cumulative, **arrival
  mis-ordering does not matter** — a delayed or out-of-order message cannot
  corrupt the bid state. This is a deliberate design goal: tolerate the network
  rather than fight it.
- **The MarketMaker's queue is the authority on ordering.** Not the bidder's
  send time, not wall-clock — the order in which the maker's own queue *receives*
  bids defines truth. That is exactly what makes mis-ordering a non-issue.
- **The maker's ack is the binding contract.** A bid is not binding when sent;
  it becomes binding the moment the MarketMaker **acks** it. The ack — not the
  bid — is the contract. The ack carries a cryptographic signature and a
  `ContractId`; the binding is real, not advisory.
- **Cryptographic veracity is distributed and non-hijackable — and core, not
  optional.** Trust in who-can-bid, what-was-cleared, and whose meter read is
  authoritative rests on a distributed cryptographic chain that **no single
  organization can capture.** The MarketMaker is not its own root of trust: it
  sits inside the **TaReader** authority chain and accepts no participation
  outside it, and identities/credentials trace to **TaValidator** (third-party,
  never GridWorks) attestation. The full architecture is specified in
  [`../../../economy-energy-markets/executor/primary.md`](../../../economy-energy-markets/executor/primary.md)
  (invariants 4, 8, 13, 14) — this doc does not restate it. **MarketMakers
  themselves need authentication too:** the envisaged path is a third party
  (and/or the maker self-attesting how it reads its constraint, the GPS, and its
  ability to read it) followed by a **commentary period** — the TaValidator
  attestation pattern extended from assets to makers.
- **Trust substrate is an open choice — blockchain a strong candidate, not
  over-committed.** Per economy-energy-markets invariant 14 the Participation-
  Requirement evidence mechanism is framework-agnostic (signed certs, public
  ledgers, …). The deepest argument *for* a chain is not throughput but
  **anti-capture**: a distributed, tamper-evident ledger with no single owner
  *is* the "non-hijackable by any one organization" property the whole trust
  design reaches for. Two distinct roles, likely different answers:
  - **Credentials / rights — NFT-like.** TaDeeds and TaTradingRights are
    naturally **non-fungible tokens** (identity + delegable rights): low-
    frequency, high-value, exactly what a chain secures well.
  - **The market machinery itself — a web of smart contracts.** Running the
    markets could naturally be a *massive distributed collaborative set of
    interactive smart contracts* (fractal makers, a micro-contract per slot) —
    the original *Redefining Demand Response* vision.

  The counter, and why **not** to over-commit: putting the **high-frequency,
  cumulative bid stream** on-chain fights "fast + cheap + cumulative" (fees /
  latency at 5-min × thousands of nodes). So the real question is *layering* —
  which layers go on-chain (binding ack / settlement / deeds / rights) vs stay
  off-chain (the live bid stream) — not chain-or-not. Keep the contract /
  credential model substrate-independent and **do not lock to Algorand (or any
  chain) prematurely.** The legacy Algorand code is plumbing to discard; the
  signed-contract principle it served is to keep.
- **Adoption is by published rules, not bilateral deals.** The maker advertises
  *"here is the market and here are the rules — go"*; participants join by
  adopting the open tools, not by negotiating leverage. The maker is the concrete
  embodiment of this stance — but the stance itself (and why it works against
  greed/competition) is *vision*, not maker spec: see
  [`../../../vision/adoption.md`](../../../vision/adoption.md).
- **Emergent market semantics live in type upgrades + axioms, not clever
  vocabulary.** New meaning is added as versioned fields on the `market.product`
  Sema type or as axioms on `market.slot.name`. See
  market-product-and-uniform-bids.
- **5-minute slots; bid + offer curves cross to a clearing price.** Markets on a
  5-minute grid (founding VCharge thesis; matches ISO real-time dispatch). The
  clearing model is supply (offer) curve × demand (bid) curve → clearing price.
- **Built on gwbase + Sema.** Transport/actor on the **current gwbase**
  `ActorBase`; all wire/storage types in **Sema**. (No `asl/`, no XSLT codegen,
  no Algorand-*specific* plumbing — see *Existing*. The cryptographic trust
  fabric above is retained; only its vendor binding is open.)

> The fast/cumulative-bids, queue-as-ordering-authority, and ack-as-contract
> points are newer than launch-intentions and should propagate there when that
> doc is next revised.

## Existing — first-pass evaluation of the repo

**Provenance.** VCharge-era distillate, exercised in the Algorand simulation
(~2 years ago). It captures real learning from running several **thousand**
co-optimized systems — but the **market-making machinery itself was never
tested in reality**, and the repo has never run in production. Read it for
intent; do not port the *how*.

> **Uncommitted WIP present (do not build on it).** The working tree is
> mid-migration: `src/gwmm/enums/` and `src/gwmm/types/` are deleted and an
> untracked `src/gwmm/asl/` seed is added, with imports only half-repointed
> (`gwmm.asl.enums` but still `gwmm.types`) — so the tree does not import
> cleanly. This `asl/` (Application Shared Language) seed is **legacy: Sema is
> the target.** Flagged, not touched — it is foreign in-flight work.

### The clearing engine is hollow

`market_maker.py` is a **price replayer, not a market**. `solve_for_clearing_price`
only implements the `Dev` branch, which returns a precomputed value from
`input_data/dev_prices.csv` (`hack_clearing_price`, 8760 hourly rows). The real
paths are stubs: `create_market_contracts` is `pass`, the non-Dev clearing is
`NotImplementedError`, and `clear_market` / `update_slot_books` /
`real_broadcast_latest_prices` are commented out of the live timestep. The
legacy `g-node-registry/src/gnr/market_maker.py` is the same shape — both were
copied from a common ancestor and **neither contains a working bid-crossing
algorithm.** Bidder credentialing (`check_market_creds`) is a hardcoded 200.

### Where the real Algorand-sim distillate actually lives

The genuine market artifact is the **`r.mm.marketslot.bidoffercurves`** report
in the older `gw-platform-python` / `gw-atn-spaceheat` message-maker world: a
payload carrying `OfferPriceQuantityPairs`, `BidPriceQuantityPairs`, and a
`ClearingPrice` — i.e. the aggregated supply and demand curves and their
crossing. That schema is the durable shape worth carrying into the vision
(curves cross → clearing price). Even there, the message maker only *packages* a
clearing price computed elsewhere; the actual curve-crossing / co-optimization
math is not present in the surviving actor repos. **Do not invest in
reverse-engineering it** — rebuild the crossing from the vision.

### The bid side is alive in scada; the maker is the missing counterparty

Contrary to first expectation, the **bidder side is modern and live in
`gridworks-scada`** (the LTN). `actors/ltn/ltn.py`
(~2100 lines, pydantic v2) runs a `BidRunner` that drives a multi-process
**FLO (Forward-Looking Optimizer) / Dijkstra co-optimization** over
day-ahead / LMP / regulation prices (`dp/lmp/reg_usd_per_mwh`) — the living
descendant of the VCharge co-optimized-participation thesis. `flo.py`
`generate_recommendation()` returns a **`bid.recommendation`** carrying `PqPairs`
(the bid curve). The flow is: FLO → `BidRecommendation` (internal, no fee/sig) →
LTN → **`bid`** (adds `SignedMarketFeeTxn` + wire identity) → MarketMaker →
**`market.maker.ack`** (`ContractId` = BidId, `Signature`, `AckTimeMs`).
`gridworks-scada-protocol` already defines `Bid`, `MarketMakerAck`, and
`BidRecommendation` (axiom bodies are stubs). **What does not exist is the
MarketMaker counterparty** that receives these curves, aggregates them, crosses
them, and returns the ack + clearing price. That counterparty is exactly what
this launch rebuilds.

### Old `bidoffercurves` ideas worth carrying / reconsidering

Comparing the legacy report against today's Sema (`bid/000`,
`latest.price`, `price.quantity.unitless/001`):

- **Publish the aggregate curves + clearing price, not just a scalar.** Today the
  maker publishes only `latest.price` (a scalar). `bidoffercurves` published the
  *whole slot picture* — aggregate demand curve + maker offer curve + the
  clearing price. Worth reconsidering a **`market.result` / `market.book` report**
  type: it gives transparency/auditability (each LTN can see where its curve sat
  relative to clearing) and is valuable now that the **ack is the binding
  contract** (settlement/dispute evidence).
- **The maker's offer (supply) curve as a first-class object.** `bidoffercurves`
  modeled supply as PqPairs symmetric to bids. Sema has `bid` (demand) but **no
  `offer` type** — the maker's supply side (e.g. the wholesale/ISO price stack it
  faces) is unmodeled. Modeling it as the same PqPairs shape keeps clearing
  uniform (cross two curves of one type).
- **`WExponent` is superseded — no action.** Legacy scaled quantities by
  `10^WExponent` watts; Sema uses fixed ×1000 integer scaling
  (`PriceX1000`/`QuantityX1000`) + envelope unit enums. Float `ClearingPrice` is
  likewise replaced by integer ×1000. Note only that fixed ×1000 trades the old
  exponent's dynamic range for simplicity. `CurrencyUnit` folds into
  `market.price.unit`; `WorldInstanceAlias` was sim-only — discard.

> **Design questions to resolve (flag, not a correction — `bid/000` is the
> user's latest thinking).** The signatures here are **wanted**, not residue:
> `bid.SignedMarketFeeTxn` (admission, axiom 4) and `MarketMakerAck.Signature`
> are exactly the cryptographic-veracity fabric the vision requires. The open
> questions are about *form*, not *whether*:
> - **Substrate, not commitment.** `MarketMakerAck.Signature` is currently an
>   Algorand `algo_sig_` placeholder ("TODO: real Algorand validation"). Keep
>   the signed-contract semantics; keep the **substrate framework-agnostic**
>   (economy-energy-markets invariant 14). Blockchain is a strong candidate
>   (a micro-contract per slot) — evaluate it, don't pre-bind to it.
> - **Fast + cumulative vs per-bid signing cost.** If bids are cheap, streamed,
>   and cumulative, a heavyweight signed fee txn *per bid* fights that. Open:
>   amortize admission (per bidder / per slot / per session) vs per-bid; what
>   exactly the ack signs when bids are cumulative.
> - **Cumulative / ordering semantics are unmodeled.** Neither `bid` nor
>   `market.maker.ack` yet encodes cumulativeness, a per-bidder-per-slot
>   sequence, supersession, or queue-position ordering; the ack maps one-to-one
>   to a single `ContractId`. The "queue is the ordering authority" vision needs
>   this added.

### Transport / actor: old gwbase, raw AMQP

`MarketMakerBase(ActorBase)` already extends gwbase's
`gridworks.actor_base.ActorBase`, but an **old** version, on raw pika/AMQP
(`queue_bind`, `RabbitJsonBroadcast`, `MessageCategorySymbol.rjb`). The whole
clock is a **simulation harness**: a `TimeCoordinator` drives `SimTimestep`s,
the maker `ready()`-handshakes back, time is `self._time` not wall-clock.
"Onto gwbase" = rebuild on the **current** `ActorBase`; drop the sim-time
handshake for real time.

### Legacy naming + scaffolding to drop

- **`ATN` / `AtnBid`** — ATN is legacy for **LTN** (Leaf Transactive Node).
- **Algorand coupling** — `gridworks.algo_utils`, `BasicAccount`, `check_funding`,
  `TaTradingRights` / signed-market-fee binding. Replaced by **ack = contract**.
- **XSLT type/enum codegen** (`CodeGenerationTools/*.xslt`) — superseded by Sema.
- **Hourly (3600 s) granularity hardcoded** and market type `Rt60Gate30B` —
  contradicts the 5-min slot thesis and the `rt60gate5` / `rt5gate5` products.
- A stale log format (`%(sasctime)s` typo) — a small tell that paths never ran.

## Disposition (keep / rebuild / discard)

| Area | Disposition |
| --- | --- |
| Vision: maker-as-advertiser, curves→clearing price, 5-min slots, cumulative bids, ack-as-contract | **Keep** — carry into the new design |
| `bidoffercurves` report shape (offer + bid PQ pairs + clearing price) | **Keep the shape** — re-express in Sema |
| Clearing engine (`solve_for_clearing_price`, contracts) | **Rebuild** — never existed in working form |
| Actor/transport (`MarketMakerBase`, AMQP, SimTimestep handshake) | **Rebuild on current gwbase**, real time |
| Types/enums (`gwmm.types`, `gwmm.asl`, XSLT codegen) | **Discard** → Sema |
| Cryptographic veracity: signed bids/acks, TaTradingRights, TaReader/TaValidator chain | **Keep the principle** — substrate framework-agnostic (econ-markets inv. 14) |
| Algorand-*specific* plumbing (`algo_utils`, `BasicAccount`, `algo_sig_`, fee-txn encoding) | **Discard the plumbing** — re-evaluate substrate (blockchain a candidate, not committed) |
| `ATN` naming | **Discard** → LTN |

## Open threads

- Bind 5-min slots on the maker-agnostic `market.slot.name` format vs. maker-side
  opt-in check (see launch-intentions).
- Exact cumulative-bid semantics: what a "cumulative bid" message carries, how the
  maker folds it, and the ack's content (what the binding ack asserts).
- Adoption tiers — MUST vs. strong-preference vs. don't-care (launch-intentions).
