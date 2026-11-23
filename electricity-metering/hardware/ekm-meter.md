# EKM Omnimeter

Status: Draft · Pass 0 · Updated 2026-11-22

> What this is: the EKM Metering Omnimeter GridWorks has (an Omnimeter
> Pulse UL v.4 class with EKM clamp-on CTs), what it is certified for,
> how it communicates, and where it fits. The full acceptance research
> is `../research/ekm-omnimeter-acceptance.md`.

## What it is

A universal 120/240 V, Class 200 submeter with external CTs at a 26.6 mA
secondary, about $200 at single-unit retail. EKM's own spec sheet rates
it accuracy class 0.5. EKM sells it as a submeter: "Submetering is the
practice of installing revenue grade meters 'behind' the utility meter".

## What it is certified for

- **California CTEP Certificate 5645(c)-25** (CDFA Division of
  Measurement Standards, 2025-09-03): "for use as a watt-hour metering
  system in legally sub-metered electric service applications", tested
  from 3 to 50 A at unity and 0.5 power factor. The certificate's Table 1
  lists EKM's CTs by model with an accuracy class: the solid-core BCT line
  and the split-core ESCT-015-200UL, PSCT-019-200, SCT-025-200UL,
  ESCT-025-400UL, ESCT-055-600 and ESCT-055-800 at class 0.1, and the
  large 1500 to 5000 A split-core models at class 0.2. This is a
  weights-and-measures approval of the meter plus those CTs as a system
  for billing a tenant. It is the strongest third-party evidence we hold
  that a clamp-on CT system can be revenue grade at the submetering tier.
- **UL test report R11054177-ANSI** (2016): the ANSI C12.20-2010 load
  performance and power factor tables met at class 0.2 and 0.5, on one
  form, with two solid-core BCT-013-200 CTs as "the only CTs covered
  under the scope of this investigation". Two sections of C12.20, not
  the standard; the report disclaims being a certification.
- **UL Listed for safety** under UL 61010-1 (certificate E343191). The
  CTs are UL Recognized Components (E519066).
- Not on the New York approved-meter list; no utility, PUC or ISO
  acceptance for billing or settlement found. Measurement Canada approval
  is claimed by EKM without an approval number.

## Where it fits for us

- **Not the settlement meter.** OP-18 Appendix C's Energy Billing column
  wants a 0.2-class meter with C57.13 class-0.3 CTs; the Omnimeter is
  class 0.5 by its own sheet and its 26.6 mA CTs have no C57.13 class.
  The DRR 2.0 allowance is closed to GridWorks by decision
  (`../README.md` "The chosen architecture").
- **Evidence for the MarketMaker's good-enough bar.** The CTEP approval
  is a regulator saying a clamp-on CT system is accurate enough to bill a
  person for electricity, at the sub-metering tier, outside any ISO or
  utility relationship. That is the standard the in-house markets set,
  and the certificate is a citable precedent for it.

## Communications

RS-485 serial, EKM's own protocol, half-duplex multi-drop so several
meters share one bus; EKM's v.4 meters return the full register set
(kWh forward and reverse per tariff, volts, amps and watts per line,
power factor, frequency, pulse counts, relay state) on each request. The
read rate from a host and the register list are to be confirmed against
the meter in hand before it is relied on. RS-485 is a serviceable
interface for a reader on the same board; it is not the MQTT-once-a-
second surface the settlement meter should have (`../lexicon.md`).
