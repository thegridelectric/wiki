# Is the EKM Omnimeter a utility-accepted revenue meter

Status: Draft · Pass 0 · Updated 2026-11-22

> What this is: a research note on whether an EKM Omnimeter with EKM's
> clamp-on CTs, the unit GridWorks has, can be presented to a utility or
> to ISO New England as energy-billing-quality metering under OP-18
> Appendix C. Read from EKM's own documents, the UL and California
> certificates and the NY approved-meter list on 2026-11-22 by a research
> agent; quotes are verbatim. Not normative.

## Verdict

No. What EKM has is a California weights-and-measures approval as a
tenant submeter, a UL safety Listing, and a partial ANSI C12.20 accuracy
test run with solid-core CTs. No utility, PUC or ISO acceptance for
billing or settlement was found. OP-18's 2.0 overall allowance for
metering installed only for a DRA would admit a ±0.5% system claim, with
no acceptance documented even there, and GridWorks never registers as a
DRR (`../README.md` "The chosen architecture"), so that allowance does
not apply.

Outside the ISO and utility scenarios the picture is the reverse. The
California CTEP approval is a regulator accepting a clamp-on CT system
for billing a person for electricity at the sub-metering tier, which is
the standard the MarketMaker sets for its own markets. The certificate is
citable evidence for that bar (`../hardware/ekm-meter.md`).

## What the ANSI C12.20 test covers

UL LLC report R11054177-ANSI, 2016-01-06 (the EKM-hosted PDF):

- CTs: "two 200A CT (solid core, BCT013200…) … These are the only CTs
  covered under the scope of this investigation." No split-core CT was
  tested; every results row reads "Omnimeter Pulse UL v.4 with BCT013200
  200A CT's".
- Class: "met the customer requested performance requirements of ANSI
  C12.20-2010, 0.2 and 0.5 Accuracy Classes", for two tests only,
  5.5.4.3 Load Performance and 5.5.4.4 Power Factor. One Form (120/240 V,
  Class 200), 23 °C, three samples, worst error 0.15%. Temperature,
  surge and EMC were not evaluated.
- The report "shall not be used to claim, constitute or imply product
  certification, approval, or endorsement by NVLAP, NIST, A2LA…".
- EKM's own spec sheet rates the meter "Accuracy Class 0.5".

## UL status

- Meter: UL Listed for safety only. Certificate 20131212-E343191,
  "Standard(s) for Safety: UL 61010-1 AND CSA C22.2 NO. 61010-1".
- CTs: UL Certificate E519066 (2021) makes them Recognized Components:
  "UL Recognized components are incomplete in certain constructional
  features or restricted in performance capabilities". UL 2808 appears
  nowhere in EKM's documents.

## Regulators and approved lists

- **California CTEP Certificate 5645(c)-25** (CDFA Division of
  Measurement Standards, 2025-09-03): "Universal meter for use as a
  watt-hour metering system in legally sub-metered electric service
  applications." Covers the Omnimeter with listed solid- and split-core
  CTs; "tests from 3 amps to 50 amps at both unity and 0.5 power
  factors." A landlord-submetering approval.
- **New York** DPS Approved Meter List, 2024-08-21: EKM does not appear.
- **Measurement Canada**: EKM's Canada spec sheet claims approval; no
  approval number was found, so unverified.
- No utility, PUC (CA, MA, ME, TX) or ISO/RTO list naming EKM was found,
  and no forum report of a utility or ISO accepting or rejecting it.

## The split-core CTs

EKM's split-core spec sheets (SCT-013-200UL, ESCT-015-200UL,
SCT-025-200UL, ESCT-055-600UL): "Accuracy: ± 0.1% accurate. When used in
conjunction with our Omnimeters, the installation will have an accuracy
of ± 0.5%." No sheet gives a C57.13 metering class at a stated burden;
these 26.6 mA-output CTs do not fit the C57.13 classes, which assume a 5
A secondary. OP-18 §VIII.A asks that "Instrument transformers shall
conform to ANSI standard C57.13" and Appendix C asks for class 0.3.

## What EKM says about itself

"Submetering is the practice of installing revenue grade meters 'behind'
the utility meter…" (solutions page). California Type Approval means
accurate enough "for revenue purposes, like submetering rental units for
example" (certifications FAQ). Staff forum post: "You can install any of
our submeters… behind your utility meter without having to get permission
from the utility."

## Tested against approved

A C12.20 test report says the tested samples met the accuracy tables
under lab conditions. Approval for utility or settlement use is a
decision by a utility, PUC or ISO to accept the meter type, usually with
its own acceptance testing, sealing and programs. EKM has the first, for
two tests, one Form and solid-core CTs, plus a state approval as a tenant
submeter. It has no utility or ISO acceptance that was found.

## Not opened

UL Product iQ (403), EKM product pages (rate-limited; help pages and PDFs
used instead), the Measurement Canada approval database, any utility or
ISO acceptance records.

## Sources

- UL report R11054177: documents.ekmmetering.com/Omnimeter-Pulse-UL-v4-UL-ANSI-C12.1-C12.20-Certification.pdf
- CTEP 5645(c)-25: documents.ekmmetering.com/California-Type-Approval.pdf
- UL CoC E343191: documents.ekmmetering.com/UL_Certificate_of_Compliance.pdf
- UL CoC E519066 (CTs): documents.ekmmetering.com/UL_Certificate_of_Compliance-Additional_CTs.pdf
- Spec sheets: EKM-Omnimeter-Pulse-UL-v4-Spec-Sheet.pdf, EKM-SCT-013-200-CT-spec-sheet.pdf, EKM-ESCT-015-200UL-CT-spec-sheet.pdf, EKM-BCT-013-200-CT-spec-sheet.pdf (same host)
- NY DPS Approved Electric Meter List, 2024-08-21
- EKM certifications FAQ (help.ekmmetering.com article 6000068358), solutions page, forum post p=6728
