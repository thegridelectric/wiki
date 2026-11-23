# Revenue-grade metering requirements: energy and regulation telemetry

Status: Draft · Pass 0 · Updated 2026-11-21

> What this is: a research note on the accuracy a residential DER
> aggregator in ISO New England actually has to meet, for energy
> settlement and for regulation telemetry, against what a large generator
> meets. Read from the primary documents on 2026-11-21 by a research
> agent; quotes are verbatim from the sources named. Not normative.

## The answer in one paragraph

For energy settlement as a Demand Response Asset or Demand Response DERA,
each home needs an interval meter at its Retail Delivery Point reporting a
5-minute average to the ISO (1-minute if selling reserves), with homes
under 10 kW pooled to at least 10 kW for telemetry. The accuracy bar is
one of two. Either the utility's billing meter, ANSI C12 revenue grade,
which for a new or upgraded install is a class 0.2 meter with 0.3-class
CT and VT, tested to ±0.2% at full load, ±0.3% at 10% load and ±0.5% at
0.5 power factor lagging. Or, for a Demand Response Asset only, where the aggregator installs its
own meter that the utility does not bill from, a metering system with
2.0% overall accuracy; a Load Asset settled on its consumption has no
such allowance. For regulation as an ATRR the requirement shifts from energy to
power: MW at the delivery point reaches the ISO within 4 seconds of the
RTU scan, through components rated at 0.25 to 0.3% of full scale each,
and the ISO acts only when telemetry drifts more than 4.5% of full scale
from the revenue meter. Regulation telemetry is about ten times looser
than revenue metering and is judged against full scale, not reading.

## The 2.0 allowance is for demand response only

OP-18 §V.B.8 opens with "For DRAs". A Demand Response Asset's product is
a reduction against a baseline, and its meter data never enters the Host
Participant Assigned Meter Reader's allocation of consumed energy among
suppliers; that is why the clause can say the metering "will not be used
for utility billing purposes" and accept 2.0 overall. A Load Asset is the
opposite case: its metered kWh is the quantity settled and allocated.
OP-18 §V.E.1: "Every Load Asset except DRAs shall have a Wh meter or be
determined on an hourly basis as an allocation of Wh meters." Those Wh
meters fall under §VIII.A (ANSI C-12) and OP-18C's Energy Billing column
(0.2-class meter, 0.3-class CT and VT for new or upgraded installs).
OP-18 Rev 25 does not mention Distributed Energy Resource Aggregations at
all, so Market Rule 1 §III.6.4(f)'s "where such requirements may differ
for Distributed Energy Resource Aggregations that include Generator
Assets or Load Assets" points at nothing yet. For wholesale energy
participation on our own meter the gate today is the 0.2 class, plus
§III.6.4(d): metering "shall meet all applicable state and Host Utility
requirements."

## Energy metering: the standards

**ANSI C12.20 defines class as percent of reading**, against a reference
that is itself near zero error. Table 3 heading: "Maximum Deviation in
Percent from Reference Performance". Test currents run from about 1% of
the meter's current class up to class amps; at the lowest point class 0.2
allows ±0.4% and class 0.5 allows ±1.0%; everywhere else ±0.2% and ±0.5%.
At 0.5 lagging power factor (Table 5): light load ±0.5% / ±1.0%, heavy
load ±0.3% / ±0.6%. Source: UL certification report for the EKM
Omnimeter reproducing C12.20-2010 Tables 3 and 5, "0.5 lag ... ±0.6 ...
±0.3". The standard itself is paywalled; C12.20-2015 added class 0.1 and
harmonic tests, and a vendor summary says it merged into ANSI C12.1-2022
(unverified).

**ANSI C12.1 alone is a ±2% in-service standard**: "percent registration
is not less than 98% or more than 102%" (PJM Metering Task Force deck
2015-11-13, quoting C12.1 §5.1.2.2).

**IEC 62053-22 classes 0.2S and 0.5S** are the direct analogue (Table 4):
PF 1 from 0.05 In to Imax ±0.2 / ±0.5; PF 0.5 inductive from 0.1 In
±0.3 / ±0.6; "0,1 In ≤ I ≤ Imax ... 0,5 inductive ... ±0,3 ... ±0,6". The
S suffix is IEC only.

## Energy metering: ISO New England

**OP-18 "Metering and Telemetering Criteria" Rev 25 (effective
2026-11-16)**:

- §V.A.3: "For Demand Response Resources (DRR), MWh per 5-minute interval
  data is required for each Demand Response Asset (DRA)."
- §V.B.8, the key clause: a DRA's 5-minute data "shall be either energy
  billing quality as defined in OP-18, Appendix C" or, "where metering is
  installed specifically for the DRA (and will not be used for utility
  billing purposes), a metering system with an overall accuracy as
  defined in OP-18C may be used."
- §VIII.A: "All AC metering devices used shall conform to applicable
  American National Standard Institute (ANSI) C-12 standards".
- §VIII.B.5: time sync "within an accuracy of +/- 15 seconds" to NIST.
- §X.D.4.a field test points: full load at TA, unity PF "+/- 0.2% error";
  light load at 10% TA "+/- 0.3% error"; TA at "0.5 power factor lag"
  "+/- 0.5% error".

**OP-18 Appendix C "Minimum Accuracy Standards" Rev 11.3**, one table,
"All figures are accuracy class or in percent of the Fiducial Value":

| column | CT | VT | Wh meter |
|---|---|---|---|
| Energy billing | 0.3 | 0.3 | 0.2 |
| DRR metering systems (note 4) | 2.0 | 2.0 | 2.0 |

Note 4: "Demand Response Resources overall metering accuracy required if
energy billing quality equipment is not used." Note 7: frequency data
"+/- 0.01 Hz".

**Market Rule 1 §III** (effective 2026-11-01): §III.3.2.2(c)(i), DRAs and
DERs in a Demand Response DERA report telemetry "as an average value
every five minutes"; DERs under 10 kW "must aggregate their demand
reduction and energy injection capability to achieve a Maximum Reduction
Capability of at least 10 kW to report telemetry"; reserves "at least
every one minute". §III.6.4(d): DERA metering "shall meet all applicable
state and Host Utility requirements and be located at, a Retail Delivery
Point, or point of interconnection"; (e) behind-the-RDP metering only "if
the Host Utility confirms in writing"; (f) the aggregator "may designate
itself, an agent acting on its behalf, or the Host Utility to act as the
Assigned Meter Reader". §III.3.2.1.1(c)(i): telemetry is replaced by a
flat hourly profile when it differs from the revenue meter by "greater
than 20 percent of the hourly revenue quality meter value and greater
than 10 MW".

**ISO-NE Order 2222 slides (MRWG 2024-09-13)**: "DER sub-metering is
allowed, but only if the Host Utility is able to accommodate metering
configurations that address double-counting."

**FERC Order 2222 §IV.G** sets no accuracy number: "we will not prescribe
the specific metering and telemetry requirements that each RTO/ISO must
adopt"; RTOs must "rely on metering and telemetry data obtained through
compliance with distribution utility or local regulatory authority
metering system requirements whenever possible".

## Energy metering: PJM and CAISO for comparison

- **PJM Manual 01 Rev 51 §5.3.2**: billing devices "should be accurate
  within ±0.3% of full scale"; system "Metering Accuracy: Within ±1% of
  true value", tested "at intervals of two years"; intervals "fifteen
  minutes, thirty minutes, and sixty minutes". No DER-aggregation
  metering clause found.
- **CAISO BPM for Metering v24 §3.2.3.1**: "All metering is of a revenue
  class metering accuracy in accordance with the ANSI C12 standards";
  5-minute intervals; the 2015 PJM deck quotes CAISO v13 Attachment B2
  "They must be revenue quality with a 0.2 Accuracy Class". ERCOT: class
  0.2 at or above 10 MW, C12.1 below. MISO: CT/VT class 0.3.

## Regulation telemetry

- **OP-18 §VI.C.1**: AGC data "which includes unit MW for AGC generators
  and ATRR Regulation Service providers, shall be made available to the
  local ICCP server or ISO CFE within four (4) seconds." §VI.C.2: other
  analogs "within ten (10) seconds of a change"; DRAs "in 5-minute
  intervals"; reserves "at a minimum of every one minute". §VI.A.1.e:
  ATRR MW telemetered at the POI or "at the Retail Delivery Point(s)";
  MVAr only for aggregated ATRRs of 75 MW or more.
- **OP-18C AGC columns** (percent of fiducial value, i.e. full scale): CT
  0.3, VT 0.3, transducer 0.25, digital telemetry 0.15, A/D 0.2. No
  single overall figure; root-sum-square about 0.5 to 0.6% of full
  scale. Ongoing check, OP-18 §X.C.1.b: Watts "+/- 10 MW or +/- 4.5% of
  the largest fiducial value (whichever is smaller)".
- **PJM Manual 01 §5.2.2 Area Regulation**: "Metering Accuracy: Within
  ±2% of true value." "Scan Frequency: 4 sec. or less between scans."
  General telemetry §5.2.6 "Within ±5% of true value". **Manual 12
  §4.3.2**: RegA "will be sent on a two-second scan rate".

## Residential aggregation against a large generator

Identical: the governing documents, ANSI C12 conformance, the 0.2-class
meter with 0.3-class CT/VT for any new billing-quality install, the field
test points, the 5-minute settlement interval. The 2.0% overall allowance
is the one numeric relaxation and applies only to a DRA-only meter the
utility does not bill from.

Different: meter location (generator at the point of interconnection,
DRA at the Retail Delivery Point); interval (generators hourly MWh
minimum, DRAs 5-minute required); telemetry (generators instantaneous MW
through an RTU within 10 s, 4 s on AGC; DRAs a 5-minute average, 1-minute
for reserves, sub-10 kW DERs pooled); who reads the meter (the DERA
aggregator may be its own Assigned Meter Reader). Settlement Only
Resources under 5 MW have "no telemetering requirements" (OP-14 Rev 37
§II.B.3.b).

## Not opened

ANSI C12.20 text (paywalled; tables from the UL report and the PJM deck).
IEC 62053-21 and 62053-22:2020. OP-18 Appendix G (DRA RTU specification,
confidential). ISO-NE Manual M-28. Market Rule 1 §III.14.2. CAISO BPM v24
Attachment B. Verify these before citing them as read.

## Sources

- OP-18 Rev 25: iso-ne.com/static-assets/documents/rules_proceds/operating/isone/op18/op18_rto_final.pdf
- OP-18 Appendix C Rev 11.3: .../op18/op18c_rto_final.pdf
- OP-14 Rev 37: .../op14/op14_rto_final.pdf
- Market Rule 1 §III.1–III.12: iso-ne.com/static-assets/documents/2014/12/mr1_sec_1_12.pdf
- UL report, EKM Omnimeter, "ANSI C12.20-2010 0.2 and 0.5 Accuracy Classes for Static Meter Test Report": documents.ekmmetering.com/Omnimeter-Pulse-UL-v4-UL-ANSI-C12.1-C12.20-Certification.pdf
- PJM Metering Task Force, "ANSI and IEEE Standards for Metering", 2015-11-13
- PJM Manual 01 Rev 51; PJM Manual 12 Rev 57; CAISO BPM for Metering v24
