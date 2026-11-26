# Metering architecture

Status: Draft · Pass 0 · Updated 2026-11-25 · Linear: OPS-719

**EDD: yes** one transaction is settled between two parties on a metered
reading, and a third party re-derives the amount from the record alone.

> What this is: what "revenue grade" means for a GridWorks MarketMaker,
> the MarketMaker's place as counterparty to every trade, the parts that
> make a settlement on a metered reading sound, the open questions on
> contracts and accounting, and the parts no design covers yet. The two metering products are their own
> designs (the boundary meter, OPS-707; the voltage beacon, OPS-706).
> This design is the frame they sit in.

## Do this next

State the first bar. Take one sub-metered load that already has a
reference beside it, the spruce secondary pump on a Gw108 CT against
the eGauge (OPS-703 has the captures), and write the terms a
MarketMaker would publish for it: the quantity, the interval, the
accuracy claimed, how the claim is checked and how often. One page. It
is the first instance of "The published bar" below, and writing it
shows which of the other parts it cannot be written without.

## Revenue grade is relative

Decided 2026-11-25. A measurement is **revenue grade** when it is good
enough to settle a financial transaction under a contract between two
consenting parties. The grade belongs to the contract. A meter has an
accuracy; a contract says what accuracy it settles on.

Two consequences:

- **A GridWorks MarketMaker defines revenue grade for its own markets.**
  It publishes the bar, and a party that bids has consented to it. No
  outside body grants the grade for a market GridWorks runs.
- **The ISO's bar is one contract among others.** Settling with ISO New
  England means meeting the bar its tariff sets, OP-18 Appendix C's
  Energy Billing column, because that is the contract on that side
  (`../research/revenue-grade-requirements.md`). The boundary meter
  meets it. The same meter is also the audit reference for the bar
  GridWorks sets underneath it.

## The MarketMaker is the counterparty

Decided 2026-11-25. A GridWorks MarketMaker is a counterparty to every
trade in its market. No participant trades with another participant.

- **Upward, the MarketMaker has the contract.** It is the party
  responsible to the ISO and the utility, and it meets their bar with
  the boundary meter. A top-level MarketMaker faces the ISO; a
  MarketMaker below it faces its parent MarketMaker the same way.
- **Downward, the MarketMaker sets the standard.** Because it alone
  answers upward, it is free to publish its own bar for its own
  participants. A participant consents to that bar and never deals with
  the ISO's.
- **The difference between the two is the MarketMaker's risk.** What it
  settles upward on the boundary meter and the sum of what it settles
  downward on the sub-meters differ by the sub-meters' error and the
  unmetered remainder. The MarketMaker absorbs that difference, so the
  bar it publishes is a risk it prices, and the continuous audit
  (part 5 below) is how it measures that risk.

The bar is ours to set, and it has to be sound. Banks and utilities
each run settlement at scale, and the practices that make their
settlement trustworthy were worked out by engineers and are largely
public. "Practices to learn from" lists the ones to study.

## What makes a settlement on a reading sound

Six parts. A transaction is revenue grade when all six are in place for
it.

1. **The published bar.** The MarketMaker's terms say what is measured,
   over what interval, to what accuracy, and how that accuracy is
   checked. Third parties bid into these markets, so the terms are
   public and versioned, and a transaction names the terms it settled
   under.
2. **Energy read from the meter's register.** The settled quantity is
   energy, read from the meter's cumulative register. Integrating power
   samples puts the sampling error into the settled number
   (`../../gridworks-scada/explorations/metering.md` "Energy is
   primary, and it's metered — not integrated").
3. **A declared boundary.** One declaration names what is metered: the
   CT set, the direction of each, and the meter they are bound to. The
   auditor meters the same boundary and compares like with like (same
   exploration, "The invariant that MUST hold — auditor legibility").
4. **A committed record.** The reported readings are signed by the
   device that made them and chained, so a reading cannot be changed
   after the fact and the auditor knows whose record it is. The
   signature commits the reporter to a record. It does not make the
   record true.
5. **A continuous audit.** Truth comes from an independent check. Inside
   a house the boundary meter is that check: the sub-metered loads and
   the unmetered remainder reconcile against its class 0.2 reading
   (`../README.md` "The chosen architecture"). A validator's spot
   metering is the check on the boundary meter itself.
6. **A path for a dispute.** When the two parties' numbers differ by
   more than the bar allows, the terms say who decides and from which
   record. A party independent of both reads the committed record.

## Contracts and accounting: questions

The six parts say how a reading becomes trustworthy. These questions are
about what is put in place for the agreement and the money. None is
answered yet except where marked.

Contracts

1. Who are the parties on the participant side of a trade: the
   homeowner, the LTN or aggregator, a third-party provider? The
   MarketMaker is always the other side (decided above).
2. What is the binding instrument: a signed text, a sema record, or
   both, and which governs when they differ? OPS-686 has the signed
   text for the first terms.
3. How is consent given and recorded, and which version of the terms
   governs a slot?
4. What do the terms say happens on a breach or a disputed reading?
5. Who is the legal person behind a MarketMaker, and what does it sign
   with the ISO, the utility and the Assigned Meter Reader?
6. A participant billed on a sub-meter under our bar: which state rules
   on sub-metering for billing apply? Not checked for Maine or New
   Hampshire.

Accounting

7. A counterparty to every trade has custody of money and credit
   exposure to every participant. What does that require: collateral,
   limits, a licence?
8. What is the unit of account, and when do real dollars move: per
   slot, or netted on a monthly invoice?
9. Where is the ledger, who is its authority, and what does a third
   party need to audit it?
10. When is a trade final: at clearing, or after settlement against the
    metered quantity, with a true-up between them?
11. How is the upward settlement reconciled against the sum of the
    downward ones, and where is the difference booked?
12. Whether a blockchain is used, and when. The principle kept from the
    Algorand first pass is a neutral witness and cryptographic
    attestation (`../../conventions/base-CLAUDE.md` "Legacy first-pass
    code: vision, not how"), and the substrate question as a whole is
    parked in OPS-391. For settlement it is a narrower question: which
    of the committed record (part 4), the ledger (question 9) and the
    reader in a dispute (part 6) needs a party that no participant
    controls, and whether a chain, a transparency log with independent
    witnesses or the ear's archive provides it. The MarketMaker as
    counterparty sharpens it, since the party that keeps the ledger is
    also a party to every entry in it.

Scope

13. What is the minimum of all this for the first day of `w`?

## Gaps

Parts above that no design covers. Each becomes a spoke here or its own
design when it is taken up.

- **The published bar has no text and no word.** `lexicon.md` defines
  the good-enough bar and nothing states one. Where it is published is
  open; the MarketMaker's dated terms word in OPS-686 is the candidate.
- **Metered energy is read at one house.** OPS-642 reads the eGauge's
  cumulative registers at elm. No channel is the settled energy of a
  house, and no CT node reports a register.
- **The committed record is not designed.** The signing identity is the
  device's provisioned cert. The chain, where it is kept and who can
  read it are open.
- **The reconciliation is not designed.** What the boundary meter's
  reading is compared against, how the unmetered remainder is treated,
  what difference raises a flag and who is told.
- **The MarketMaker on the beacon is not designed.** OPS-706 lists the
  spoke and it is not opened.
- **The dispute path is not designed.** The umpire (OPS-501) keeps the
  record of contract state between a scada and its LTN; whether it also
  reads metering records is open.
- **Acceptance on the ISO side.** What evidence the Assigned Meter
  Reader wants for a class 0.2 claim on a meter the utility does not
  own. OPS-707 has the question; nothing has been asked yet.
- **The deed's part.** The record that attaches a meter to an asset is
  OPS-574. What it has to say about a sub-meter, as distinct from the
  boundary meter, is open.

## Practices to learn from

Named from general knowledge and not read for this design. Each is a
candidate to study before the matching part is designed; quotes not
captured, read before citing.

From how money is settled:

- **Double-entry, append-only ledgers.** Every transfer debits one
  account and credits another, entries are never edited, and a
  correction is a new entry. The open-source ledger databases are the
  reference implementations.
- **Two-phase transfers.** A transfer is reserved, then posted or
  voided. This is the shape of a bid that clears and later settles on
  the metered quantity.
- **Idempotent transfers.** Every transfer has an id the sender
  chooses, so a retry cannot pay twice.
- **Reconciliation as a routine.** Two independently kept records are
  compared on a schedule, and a difference is an item someone owns.

From how readings are made trustworthy:

- **Transparency logs.** Merkle-tree logs in which anyone can verify
  that an entry is included and that the log has not been rewritten.
  Certificate Transparency and the software-signing logs are the public
  examples, and they fit part 4.
- **The meter test points.** ANSI C12.20 states accuracy at named load
  and power-factor points. A published bar that names its test points
  the same way can be checked by anyone with a reference meter.
- **Validation, estimation and editing.** Utilities check interval data
  against the register, fill gaps by stated rules and mark every
  estimated value. The marking is the part to keep: a settled number
  says whether it was measured or estimated.
- **Open measurement methods.** Published, versioned methods for
  computing a settled quantity from meter data, with open-source
  reference code, so two parties compute the same number from the same
  readings.

## Open

- Whether the bar is one number or a table by load and power factor.
- Whether a load with no reference meter beside it can be revenue grade
  at all, or only loads the boundary meter can reconcile.
- How much of this the first `w` universe needs on its first day.
