# Electricity metering

> What this is: the entry point for electric power and energy metering in
> GridWorks. Heat metering (the BTU picos) is not here.
> Metering is the measurement a transactive grid-balancing system settles
> on, so this folder is a design area rather than a repo: it corresponds to
> a Linear project, and its designs touch the scada, sema, tlayouts, the
> pico firmware and the MarketMaker. Start here, then follow the pointers.

## The three tiers

**Settlement-grade metering at the transactive-load boundary.** One meter
sees all of a house's transactive load and settles with the ISO: a
third-party revenue-grade meter, or a UL-listed meter of our own. The
regulatory shape of that settlement (CSF, DARD, DERA, the DRR-zone node)
is in [`../regulatory/isone/dera-metering/primary.md`](../regulatory/isone/dera-metering/primary.md).

**Good-enough sub-metering for the in-house markets.** Inside the house,
the MarketMaker runs its own markets across the sub-metered loads and
deems a measurement good enough to settle a financial transaction. The
MarketMaker allows third-party providers to bid into these markets, so
the bar is a published one. A regulator has already drawn such a bar for
clamp-on systems: California's CTEP type approval of the EKM Omnimeter
with its split-core CTs for billing a tenant
([`hardware/ekm-meter.md`](hardware/ekm-meter.md)). Trust comes from audit, not prevention: the
reported stream is signed and tamper-evident, and a validator spot-meters
and reconciles after the fact
([`../gridworks-scada/explorations/metering.md`](../gridworks-scada/explorations/metering.md)
"The trust model"). The deed that attaches a meter to an asset is the ta-deed work
(OPS-574).

**Indicator metering.** Signals that tell whether a load is on, not how
much it draws: white wires through Gw108 opto-couplers, and circulator
pumps through CTs. The spruce secondary pump (Grundfos UPMS 20-78) draws a
pulsed current with one maximum per cycle; other ECM circulators (Bell
and Gossett ecocirc) are expected to show three or four. Indicators feed
control and the derived channels, never settlement.

## The chosen architecture

Decided 2026-11-21. One 0.2-class meter at the economy panel boundary,
and clamp-on CTs underneath it.

- **The boundary meter** reads the whole economy panel. It is the
  settlement meter for any Load Asset or DARD participation in the
  wholesale energy market, because OP-18 Appendix C's Energy Billing
  column (a 0.2-class Wh meter with 0.3-class CT and VT) is the only bar
  a Load Asset's meter can meet, and no utility billing path accepts a
  split-core CT. One device per house, so its cost is paid once.
  **GridWorks never registers as a Demand Response Resource.** OP-18
  Appendix C allows a DRR a 2.0 overall metering accuracy, and that
  allowance does not apply to us: the DRR is not the wholesale pathway,
  and it settles curtailment against a baseline, which is the
  event-curtailment model the vision rejects
  ([`../vision/transactive-grid.md`](../vision/transactive-grid.md)).
  The Energy Billing column is the bar, with no fallback.
- **The boundary meter's gold standard** beyond its class: MQTT, every
  reading once a second, a good API.
- **Clamp-on CTs under it** meter the individual loads. Each does the
  best it can at low cost: per-unit calibration where that is cheap,
  otherwise best effort, with the published good-enough bar for the
  in-house markets. A careful revenue-grade split-core gets about ±0.5%
  at full load and ±1% at 10% of rating; a cheap clamp about ±3% and
  worse at low current. The circulator indicators are the low end of
  this tier.
- **The boundary meter audits the clamps.** The sub-metered loads plus
  the unmetered remainder reconcile against the 0.2-class reading, so
  the in-house markets have a continuous spot-check without a
  validator's instruments.

**Decided 2026-11-22: the boundary meter is our own, built as two
products, and a bought meter bridges until ours is listed.**

1. **The voltage beacon**, first. A low-voltage device: it reads a
   listed Class 2 adapter for the mains voltage, keeps the drumbeat
   for every CT node (`lexicon.md`), takes UTC and location from GPS,
   publishes the voltage model every CT node needs (frequency, phase at
   a reference time, RMS, the low harmonics, all on the drumbeat),
   computes power from CT waveforms sent to it or lets the CT node compute from the model, and
   hosts the economy market maker. No mains on the board, so no listing
   of its own, and it reaches the field in weeks. Its voltage input is
   designed to be swapped for the metering front end below.
2. **Our own class 0.2 boundary meter**, second. A mains front end
   (dividers and CT burdens into a metering chip, both legs) behind an
   isolation barrier, with the beacon module on the other side as its
   processor, clock, publisher and MarketMaker host. It takes the UL
   listing and the ANSI C12.1 class 0.2 testing, a year or more.
3. **A bought class 0.2 meter** beside the beacon settles with the ISO
   until ours is listed, read locally over Modbus or HTTP into our box
   (`hardware/existing-meters.md`).

The accuracy case for the split is
`research/split-voltage-current-accuracy.md`. No purchasable meter
exposes a voltage phase and a shared timebase at a sane price, and none
hosts user code, which is why the beacon is ours whichever meter is
bought. The economy market maker lives on the beacon, the one per-house
device every CT node depends on.

## Where the system does it today

- **The scada reads the eGauge** as the house power meter
  (`gridworks-scada/gw_spaceheat/actors/power_meter.py`, drivers under
  `drivers/power_meter/`), one device type for every house
  ([`../gridworks-scada/executor/components.md`](../gridworks-scada/executor/components.md)
  "EgaugePowerMeter"). Per-channel register placement and the first-pi rule
  are in [`../gridworks-scada/executor/hardware-layout.md`](../gridworks-scada/executor/hardware-layout.md).
- **Aggregate power goes to the LTN** as `PowerWatts` under the dispatch
  contract, and energy under contract is integrated from it; the fault
  ranking of that path is
  [`../gridworks-scada/executor/sensing-hierarchy.md`](../gridworks-scada/executor/sensing-hierarchy.md).
- **Energy, not just power.** The eGauge keeps cumulative registers that
  are not read yet; `elm-energy-metering` (OPS-642) makes a cycle's
  watt-hours a journal fact. Heat energy comes from the BTU picos
  ([`../gridworks-pico/`](../gridworks-pico/)).
- **The vocabulary** is sema: `power.watts`, `electric.meter.component.gt`
  with `electric.meter.channel.config`, `egauge.register.config`,
  `gw.adc.waveform` (one burst of raw ADC conversions, for seeing a CT as
  a waveform), `i2c.ct.interface.capability` on the board record. Search
  `sema/definitions/` before coining a word.
- **The journal** persists readings in the `readings` tables
  ([`../gridworks-journalkeeper/executor/primary.md`](../gridworks-journalkeeper/executor/primary.md));
  how to pull them is `experiments/spot-check-recipe.md`.
- **The board.** The Gw108 Rev C has a CT ADS1115 behind the TCA9548A mux;
  the bench facts (SCT-013 on a 470 Ω burden, 0.235 V RMS per amp) are in
  the Gw108 Rev C design under `gridworks-scada/designs/` (OPS-701) until
  it distills to the device record.

## Architecture it answers to

- Demand response here is continuous transactive load, not event
  curtailment, and every metered device has a node that speaks for it:
  [`../vision/transactive-grid.md`](../vision/transactive-grid.md).
- Energy is primary and is metered, not integrated; the metered object is
  a mechanism, not a sensor; the auditor must be able to read the
  measurement: [`../gridworks-scada/explorations/metering.md`](../gridworks-scada/explorations/metering.md).
- Metering topology, placement evolution and cost targets for a market
  home: [`../economy-energy-markets/executor/metering.md`](../economy-energy-markets/executor/metering.md).
  The panel that would house a revenue-grade meter and a panel-level
  MarketMaker: [`../economy-panel/executor/primary.md`](../economy-panel/executor/primary.md).

## Open questions of the larger project

- Can high-quality energy metering be built by digitally combining a CT's
  current samples with voltage samples from a different chip?
- Does the MarketMaker live in the device that reads voltage?
- Are there devices like this already on the market?
- Is a GPS chip the right clock for the voltage stream, so that
  digitization error sits an order of magnitude under CT-placement error,
  with location verification as the second benefit?

## Education

Short notes that answer a question with numbers, written to be pointed
at. One question per file.

- [`education/voltage-stays-a-sine.md`](education/voltage-stays-a-sine.md):
  why the voltage stays a sine wave when the current does not, and where
  that stops holding (weak sources, microgrids).

## Hardware

Third-party metering hardware in hand or under evaluation:
[`hardware/`](hardware/).

- [`hardware/current-transformers.md`](hardware/current-transformers.md):
  the two YHDC class 1 clamps we have (SCT013 100 A at spruce, SCT006
  20 A spare), and how they differ from the CTs EKM ships.
- [`hardware/ekm-meter.md`](hardware/ekm-meter.md): the EKM Omnimeter,
  its California submetering type approval, its partial C12.20 test, its
  RS-485 interface, and where it fits.
- [`hardware/existing-meters.md`](hardware/existing-meters.md): the
  purchasable meters surveyed as boundary-meter candidates, split into
  those that might meet the ISO bar and those that cannot, with prices,
  and the short list to suggest when a utility lets us choose.

## Lexicon

[`lexicon.md`](lexicon.md): names for the new concepts here: boundary
meter, voltage beacon, economy market maker, CT node, the tiers. All in
flux and allowed to merge.

## Research

- [`research/split-voltage-current-accuracy.md`](research/split-voltage-current-accuracy.md):
  what accuracy is possible when voltage and current are read by different
  processors; the timing budget, what delivers it, the CT floor.

- [`research/revenue-grade-requirements.md`](research/revenue-grade-requirements.md):
  what ISO New England, ANSI C12.20, PJM and CAISO require of a
  residential DER aggregator and of a large generator, for energy
  settlement and regulation telemetry, with the numbers and quotes.

- [`research/line-loss-and-settlement-error.md`](research/line-loss-and-settlement-error.md):
  distribution-loss attribution, baselines, profiles and UFE against a
  0.2% meter, per home per hour; the hypothesis that revenue-grade
  accuracy is more onerous than helpful for residential settlement.

- [`research/snap-on-ct-errors.md`](research/snap-on-ct-errors.md):
  split-core CT error by construction, conductor position, neighbours,
  low current, burden and phase; whether a snap-on CT can be revenue
  grade; the 5 A CT answer for a 2 A circulator.

- [`research/ekm-omnimeter-acceptance.md`](research/ekm-omnimeter-acceptance.md):
  the EKM Omnimeter with clamp-on CTs is a California tenant submeter
  with a partial C12.20 test on solid-core CTs, not a utility-accepted
  revenue meter.

## Designs

Designs live in `designs/`, one Linear issue each, listed in the wiki's
`DESIGN_INDEX.md`; Linear is the authority on status.

- **hello-gw108-ct** (OPS-703): the Gw108 CTs as an indicator for
  Grundfos circulator pumps. The short-term design.
- **voltage-beacon** (OPS-706): the low-voltage voltage beacon, the
  first product.
- **boundary-meter** (OPS-707): our own class 0.2 boundary meter, the
  second product, and the bought meter that bridges.

Related work in other domains, by issue: elm energy metering (OPS-642),
eGauge read glitches (OPS-629), the terminal-asset deed (OPS-574), the
Gw108 Rev C board (OPS-701).
