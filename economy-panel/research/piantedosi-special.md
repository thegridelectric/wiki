Status: Draft · Pass 0 · Updated 2026-06-07

> Research note (not normative). Summary of the
> Service-Entrance Overload Protection ("Piantedosi Special")
> design — the engineering substrate for the Economy Panel's
> analog-failsafe layer (see
> [`../executor/primary.md`](../executor/primary.md)).

## Origin

Designed and deployed by **Matt Piantedosi** — master electrician
and Project Manager for Utilities Systems at the Massachusetts
Port Authority (MassPort), Logan Airport. Source document calls
it "well-suited for transactive thermal storage heating."

## The problem it solves

Thermal-storage heating systems can draw up to 27 kW (112 A) of
resistive load when electricity is abundant. This dwarfs typical
residential service-entrance ratings, but most homes only use a
few kW most of the time — there are tens of kW of spare capacity
available *if* the transactive load can be guaranteed to cut out
when the rest of the house draws.

Two options:
1. **Overbuild the service entrance.** Wasteful, expensive,
   forecloses retrofit deployment.
2. **Electromechanical overload protection.** Sense total load
   on the house; cut the transactive load when total approaches
   the service-entrance limit. Software-independent.

The Piantedosi Special is option 2.

## NEC grounding

- **NEC 220.70** — "If an energy management system (EMS) is used
  to limit the current to a feeder or service in accordance with
  750.30, a single value equal to the maximum ampere setpoint of
  the EMS shall be permitted to be used in load calculations for
  the feeder or service. The setpoint value of the EMS shall be
  considered a continuous load for the purposes of load
  calculations."
- **NEC 750.1** — defines "Energy Management System": "a
  monitor(s), communications equipment, a controller(s), a
  timer(s), or other device(s) that monitors and/or controls an
  electrical load or a power production or storage source."

The Piantedosi Special qualifies as an EMS under 750.1 and uses
the 220.70 provision to allow full use of existing service-
entrance capacity, with the transactive load counted only as a
setpoint rather than a separate continuous load.

## Bill of materials (~$331)

| Qty | Part | Make / Model | Cost | Notes |
| ---: | --- | --- | ---: | --- |
| 1 | AC current switch | AcuAMP ACS200-CA-S | $109 | Up to 200 A, relay switches 240 V, normally closed |
| 1 | Time-delay relay | Finder 80.11.0.240.0000 | $56 | NO/NC, timer 0.1–20 min |
| 3 | Definite-purpose contactor | BDP2P40A24V | $90 ($30 each) | 2-phase, 40 A, 24 V coil |
| 1 | NEMA enclosure | Vevor NemaBox 16×12×8 | $76 | Fiberglass, NEMA UP66 waterproof |

All UL-listed, off-the-shelf, assemblable by any qualified
electrician.

## Design philosophy

From the source:

> Logic that won't fail if some piece of software has a bug,
> and never risks changing with a firmware download. The
> system is easy to understand and its uninstalled cost is
> around $300.

This is the structural contrast with smart-panel competitors
(Span, Lumin, Stepwise, Leviton Load Center, Schneider Square
D Energy Center). Those products are $3k+ with proprietary
firmware in the safety path. The Piantedosi Special separates
**safety** (electromechanical, immutable, inspectable) from
**intelligence** (software, evolving, transactive).

## Why GridWorks cites it

Matt Piantedosi's design is the existence proof that an
NEC-compliant, $300-class analog overload protector is
buildable today. The Economy Panel architecture is built on
this foundation; the transactive intelligence (TaReader,
optional panel-MarketMaker) layers on top without ever sitting
in the path of the safety enforcement.

## Open questions for the hardware spec

- Industrialization of the BOM — can the parts be sourced
  reliably at the $331 price point at moderate scale?
- Service-entrance ampacity range — the spec'd parts cover up
  to 200 A; coverage for 100 A and 400 A service entrances?
- Form-factor integration with the rest of the Economy Panel
  (per-TA sub-meters, TaReader hardware) — single enclosure
  or separable?
- Installation labor cost — uninstalled is ~$300; what does
  total installed cost look like in typical residential
  retrofit conditions?

These belong in [`../executor/hardware.md`](../executor/hardware.md)
(Open) when that spoke is seeded.
