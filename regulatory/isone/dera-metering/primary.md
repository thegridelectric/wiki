Status: Draft · Pass 0 · Updated 2026-05-30

> What this is: the FERC-approved **ISO-NE Tariff Section III.6.4**
> on **Metering and Telemetry Requirements for Distributed Energy
> Resource Aggregations (DERAs)**, strategic implications

## Sources

| Date | Filing / Order | Docket | What's in it | Direct PDF |
| --- | --- | --- | --- | --- |
| **May 23, 2024** | FERC rehearing order **187 FERC ¶ 61,100** — sustained the policy that the DER Aggregator (not the host utility) is responsible for providing metering information to ISO-NE | **ER22-983-006** | [PDF](https://www.iso-ne.com/static-assets/documents/100011/order_on_rehearing_er22-983-006.pdf) | |
| Sept 13, 2024 | ISO-NE MRWG slide deck — paraphrases the AMR-designation rule + confirms Nov 1, 2026 effective date | informational | [PDF](https://www.iso-ne.com/static-assets/documents/100015/20240913-mrwg-a07-order-2222-overview-and-update.pdf) | |
| Mar 30, 2026 | ISO-NE establishment-of-service filing — confirms Nov 1, 2026 effective date for new Section III.6 | — | [PDF](https://www.iso-ne.com/static-assets/documents/100033/rev_related_to_establishment_of_service_for_der_participation.pdf) | |

**ISO-NE Tariff Section III.6 hub:**
https://www.iso-ne.com/participate/rules-procedures/tariff/market-rule-1

**Note:** Section III.6 in the *currently effective* public tariff
PDFs still reads *"Local Second Contingency Protection Resources."*
The new III.6 (DERA Metering and Telemetry Requirements) replaces
this on **November 1, 2026**.


## Caveats

- **As the Host Participant Assigned Meter Reader** Versant may NEED to be involved to correctly allocate losses and unmetered load. If indeed Versant must be involved, they won't act without state-regulator cost-recovery
  approval (MPUC must approve associated capex). They may also take a long time.
- **Federalism question:** the ISO Tariff is FERC-jurisdictional;
  the EDC compliance is state-regulated. **No formal mechanism if
  an EDC refuses.** 

## Operational checklist

1. **Register GridWorks (or an affiliated entity) as a
   Distributed Energy Resource Aggregator** at ISO-NE.
2. **Qualify ourselves (or an agent) as Assigned Meter Reader** —
   subject to ISO-NE Operating Procedure No. 18 (Metering and
   Telemetering) and Manual M-28 (Market Rule 1 Accounting).

3a. **See if ISO NE can work creatively on losses/unmetered load with us**. If Versant uses its OWN bonus meter and submits it to ISO NE and it is an order of magnitude CLOSER to what GridWorks submits, then this does two things. It validates GridWorks' metering. And it means Versant can use its metering. Is there a way this could work??

3b. **Enter a coordination agreement with Versant** (subsection
   f.2) covering:
   - Adjustments for losses / residual unmetered load.
   - Coordination of data transmittal.
   - Protection of retail customer information.
4. **Confirm metering location** with Versant in writing per
   subsection (e) — Versant must certify that "appropriate
   metering and associated system upgrades are in place to support
   load and generation reporting and any necessary reconstitution."
5. **Set up data feeds** — to Versant by 0800 next business day; to
   ISO-NE by 1300 second business day.
6. **Retain meter data for 6 years** (subsection g).

Independent of the DERA AMR work, **a qualified Competitive
Electricity Provider (CEP)** needs to be in place as the supplier
of record for the cohort under MPUC Chapter 305.

WORKING WITH VERSANT:
  What Versant already does for industrial customers

  Maine industrial sites (Sappi, ND Paper, etc.) take service under T-1 / D-4 with revenue-grade interval metering. Two patterns are already in production:

  1. Versant-read industrial meters. Versant has revenue-grade interval AMI on the boundary meter for these customers and feeds those reads through its MDMS / settlement pipeline to ISO-NE as interval
  data (not profiled). The MDMS-to-CIS-to-ISO-NE interval path exists today for these accounts.
  2. Non-IOU MRSP industrial meters. For sites with a qualified non-IOU Meter Reader / MRSP, the meter is read by the third party and submitted to ISO-NE directly via the Meter Reading Web Services Data
   Exchange. Versant also accepts those reads back for retail-side billing reconciliation — i.e., Versant's CIS already has a path to ingest external interval data for billing purposes, not just for its
   own AMI.

## Full ISO-NE Tariff Section III.6.4 (per the Jan 31, 2024 compliance filing in ER22-983-005)

> ### III.6.4 Metering and Telemetry Requirements
>
> Distributed Energy Resource Aggregations must meet the following
> metering and telemetry requirements.
>
> **(a)** Distributed Energy Resource Aggregations participating
> as a Generator Asset, Binary Storage Facility, or Continuous
> Storage Facility, must comply with the metering and telemetry
> requirements in Sections III.3.2.1 and III.3.2.2.
>
> **(b)** Distributed Energy Resource Aggregations participating
> as an Alternative Technology Regulation Resource must comply
> with the metering and telemetry requirements in Section
> III.14.2.
>
> **(c)** Distributed Energy Resource Aggregations participating
> as Demand Response Resources or Demand Response Distributed
> Energy Resource Aggregations must comply with the metering and
> telemetry requirements in Section III.3.2.2. The metering and
> communication equipment associated with each participating
> Distributed Energy Resource must meet the requirements in
> Section III.3.2.2 and ISO New England Operating Procedure
> No. 18, Metering and Telemetering.
>
> **(d)** Metering for each Distributed Energy Resource
> participating in a Distributed Energy Resource Aggregation
> shall meet all applicable state and Host Utility requirements
> and be located at, a Retail Delivery Point, or point of
> interconnection as applicable. A Distributed Energy Resource's
> point of interconnection may be located behind a Retail
> Delivery Point to the extent that the pertinent Host
> Participant Assigned Meter Reader can accommodate such a
> configuration.
>
> **(e)** If a Distributed Energy Resource's point of
> interconnection is located behind a Retail Delivery Point it
> shall be reported such that its output or load does not impact
> the load reported for the Retail Delivery Point. A Distributed
> Energy Resource Aggregator may only propose a metering location
> behind a Retail Delivery Point if the Host Utility confirms in
> writing to the Distributed Energy Resource Aggregator that the
> appropriate metering and associated system upgrades are in
> place to support load and generation reporting and any
> necessary reconstitution. Proof of such written confirmation
> from the Host Utility should be provided as part of the
> attestation as referenced in Section III.6.7(c)(i)2.
>
> **(f)** A Distributed Energy Resource Aggregator, as the entity
> responsible for providing any required metering information to
> the ISO, **may designate itself, an agent acting on its behalf,
> or the Host Utility to act as the Assigned Meter Reader** for
> Distributed Energy Resource Aggregations that include Generator
> Assets or Load Assets. Where the Distributed Energy Resource
> Aggregator designates itself or an agent acting on its behalf
> as the Assigned Meter Reader, the Distributed Energy Resource
> Aggregator or its agent shall:
>
> 1) be subject to all obligations applicable to an Assigned
> Meter Reader that is not the Host Participant, as detailed in
> the ISO's Tariff and other Operating Documents, including, but
> not limited to Operating Procedure 18 – Metering and Telemetry
> Criteria and Manual M-28 – Market Rule 1 Accounting, where such
> requirements may differ for Distributed Energy Resource
> Aggregations that include Generator Assets or Load Assets, and
> which may include adjustments for losses and/or residual
> unmetered load as appropriate; and
>
> 2) enter into applicable coordination agreements with the
> relevant Host Utility, which may include, but need not be
> limited to agreements required by the Host Utility or the
> relevant electric retail regulatory authority regarding:
> i) specific requirements related to adjustments for losses
> and/or residual unmetered load for any Load Asset metering
> data; ii) coordination of data transmittal; and iii) protection
> of retail customer information.
>
> Where a Distributed Energy Resource Aggregator designates
> itself or an agent acting on its behalf as the Assigned Meter
> Reader for its Distributed Energy Resource Aggregation, it
> shall provide, or cause to be provided, all data necessary for
> settlement **(1) to the Host Participant Assigned Meter Reader
> by 0800 of the next Business Day following the Operating Day or
> at a later time as mutually agreed, and (2) to the ISO by 1300
> on the second Business Day after the Operating Day.** If the
> data provided includes any Profiled Load Asset data, as
> determined by the Host Participant, the Host Participant
> Assigned Meter Reader shall submit the Profiled Load Asset
> meter data directly to the ISO for settlement after appropriate
> adjustment for losses and/or residual unmetered load.
>
> **(g)** The Distributed Energy Resource Aggregator shall retain
> metering data for each participating Distributed Energy
> Resource for a period of six years for purposes of auditing.

## Interpretation

### Subsection (f) is the unlock

The key phrase is *"the Distributed Energy Resource Aggregator … **may
designate itself, an agent acting on its behalf, or the Host Utility**
to act as the Assigned Meter Reader for Distributed Energy Resource
Aggregations that include Generator Assets or Load Assets."*

A storage-controlled residential cohort qualifies as a DERA with
**Load Asset** participation (the heat pumps consuming controllable
electricity to charge thermal storage). The aggregator (us) may
designate itself as the AMR. **No further regulatory ask is needed
on the meter-reading side.**

### The data flow

```
       Cohort homes (each with Versant A-1 + bonus meter)
                            │
                            │
              ──────────────┴──────────────
              │                            │
              ▼                            ▼
    DERA Aggregator (us, as AMR)    Versant continues to read each
    reads each home's interval      home's residential meter for
    data per ISO OP No. 18           Rate A-1 delivery billing
              │
              │ we provide data:
              │
       ┌──────┴──────────────────────────┐
       ▼                                 ▼
  Versant (Host AMR)                  ISO-NE
  by 0800 next BD                     by 1300 second BD
  for retail-billing allocation       for wholesale settlement
```

Per Henry: *"the Host Participant Assigned Meter Reader [Versant]
also needs the meter data of any separately metered and settled
Generator or Load Asset located within its footprint (i.e., its
'meter domain'). The Host Participant Assigned Meter Reader needs
this data to accurately allocate all of the energy consumed in
its meter domain by interval among the various retail energy
suppliers serving customers in its meter domain for wholesale
settlement purposes."*

So the structure isn't "we replace Versant as AMR" — it's "we are
AMR for our DERA and we provide Versant the data they need to do
their retail-allocation job."

### What this means for retail supply

The DERA framework gives us **meter-reading rights**. The retail
supply substitution is a separate question — governed by MPUC
Chapter 305 (CEP licensure). The structure is:

- DERA framework → meter-reading rights → settlement-quality
  interval data for the cohort.
- CEP framework (a licensed CEP under MPUC Chapter 305) → retail
  supplier of record → bills customers at a flat retail rate.
  Customer sees a normal flat-rate residential bill. The CEP is
  settled on a profiled-load basis at the wholesale level. The
  DERA captures the load-shifting value (the gap between profiled
  cost and actual interval-LMP cost) via a bilateral arrangement
  with the CEP, brokered by the GridWorks Market Maker. Customers
  receive a rebate from the DERA proportional to the storage-
  shifting their participation enabled.

Both pieces are needed together for the full structure. III.6.4(f)
provides the first; existing Maine CEP licensure provides the
second.

### Wholesale-market participation is a bonus

Once registered as a DERA with our own AMR designation, we can
also bid the cohort into ISO-NE markets for **capacity** (Active
Demand Capacity Resource), **regulation** (Alternative Technology
Regulation Resource per subsection b), and **energy** (Continuous
Storage Facility-style arbitrage to the extent applicable to
thermal stores). These are revenue streams *on top of* the retail
supply pricing benefit.

## References (full list)

- **ISO-NE Tariff — Market Rule 1 (where Section III.6 lives):**
  https://www.iso-ne.com/participate/rules-procedures/tariff/market-rule-1
- **ISO-NE Order 2222 Key Project (compliance summary + filings):**
  https://www.iso-ne.com/committees/key-projects/order-no-2222-key-project
- **ISO-NE FERC Orders index:**
  https://www.iso-ne.com/participate/filings-orders/ferc-orders
- **FERC docket ER22-983** (ISO-NE Order 2222 compliance series;
  September 5, 2024 approval is a sub-docket order within this
  proceeding):
  https://elibrary.ferc.gov/eLibrary/search
- ISO-NE Operating Procedure No. 18 — Metering and Telemetering
  Criteria:
  https://www.iso-ne.com/static-assets/documents/rules_proceds/operating/isone/op18/op18_rto_final.pdf
- ISO-NE Manual M-28 — Market Rule 1 Accounting:
  https://www.iso-ne.com/participate/rules-procedures/manuals
- ISO-NE Meter Reader Working Group:
  https://www.iso-ne.com/committees/markets/meter-reader
- ISO-NE Meter Reading Web Services Data Exchange Specification:
  https://www.iso-ne.com/static-assets/documents/2016/12/meter_reading_web_services_data_exchange_specification.pdf

## Open follow-ups

- **Get the exact FERC docket number** for the September 5, 2024
  approval — Henry's email cited the date but not the docket. The
  filing was likely under ISO-NE's Order 2222 compliance series
  (ER21- and follow-ons).
- **Confirm DERA registration process timing** — how long does
  ISO-NE qualification take? Can we start now and be in force
  by November 1, 2026?
- **Coordinate with Versant** ahead of the effective date — the
  Versant-side system upgrades will require MPUC cost-recovery
  approval. Earlier-stage engagement is better.
- **Reach out to Henry Yoshimura** for industrial-precedent
  examples of non-IOU AMRs in New England — to inform our
  qualification approach.
- **Scoping the cross-utility expansion** — does the same
  registration cover both Versant territories (Bangor Hydro and
  Maine Public), or do we need separate qualifications? What about
  CMP, Eversource, National Grid, etc.?
