# Boundary meter (hub)

Status: Draft · Pass 0 · Updated 2026-11-22 · Linear: OPS-707

**EDD: yes** the prototype's energy is witnessed against a reference
meter at class 0.2 limits across the OP-18 load and power-factor points,
and the bridge meter's local read is witnessed in a house.

**▶ Active spoke: [`bridge-meter.md`](bridge-meter.md)**

> What this is: the hub for the second of GridWorks' two metering
> products (`../../README.md` "The chosen architecture"). Our own class
> 0.2 boundary meter for the economy panel: a mains front end, voltage
> dividers and CT burdens for both 120 V legs into a metering chip,
> behind an isolation barrier, with the voltage beacon module
> (OPS-706) on the other side as its processor, clock, publisher and
> MarketMaker host. It settles with ISO New England under OP-18
> Appendix C's Energy Billing column. GridWorks never registers as a
> DRR. Until it is listed, a bought class 0.2 meter beside the beacon
> settles with the ISO.

## Spokes

- **[`bridge-meter.md`](bridge-meter.md)**: the bought class 0.2 meter
  for the houses that come first, and how our box reads it.
- `front-end.md` (to open): the metering chip (ADE9000 against
  ATM90E32AS against the TI class 0.1 reference), dividers, burdens,
  the CT inputs for class 0.3 solid-core CTs, the isolation barrier.
- `certification-path.md` (to open): UL 61010-1 or UL 2735 listing,
  ANSI C12.1 class 0.2 testing by a lab, Assigned Meter Reader
  acceptance; cost, time and the order of the three.
- `form-factor.md` (to open): the economy panel, the CTs on the feeders,
  both legs, the antenna run, service access.
- `beacon-module-interface.md` (to open): what crosses the isolation
  barrier (SPI from the chip, the sample-ready line the beacon's clock
  stamps), and what the beacon reads from the front end in place of its
  adapter.

## Notes

- Why ours: the purchasable meters that meet the bar deliver a 5 A
  Modbus or HTTP surface and no beacon; the gold standard (MQTT, once a
  second, a good API, a shared timebase, the MarketMaker on board)
  exists only as the device we build (`../../hardware/existing-meters.md`).
- The beacon module stays a low-voltage secondary circuit inside the
  meter. UL evaluates the barrier and the product as a whole; the
  module needs no mains-rated construction and no component recognition
  of its own, and the one listing covers it. Changes to it afterwards go
  through the listing's follow-up program.
- Inside the meter the beacon's adapter input is unwired: the front end
  samples voltage and current together at tens of kSPS and the beacon
  publishes RMS, phase and harmonics from it at class 0.2. The meter's
  own settlement reading is what the better voltage pays for; what the
  beacon publishes to CT nodes improves only marginally.
- Published anecdote for a new UL file: nine to eleven months and
  $40,000 plus. No lab price for C12.1 class 0.2 testing was found.
  Twelve to eighteen months to a listed, class-certified meter is the
  planning figure.
