# Electricity-metering lexicon

Status: Draft · Pass 0 · Updated 2026-11-23

> What this is: names for the new concepts in electricity metering, so
> the designs and research in this folder use one word per thing. Wiki-
> wide vocabulary and legacy names are in `../conventions/glossary.md`;
> formal types are sema words. An entry here is a working name until a
> sema word retires it.

**Everything here is in flux.** These are working names for concepts
that are still being pulled apart, and, more importantly, MAY be joined
with each other: the boundary meter may be the voltage beacon, the
voltage beacon may host the economy market maker, a CT node may sit
inside the boundary meter. A name here fixes what a thing does today,
not that it stays a separate thing.

## Settled enough to use

- **Boundary meter**: the one 0.2-class meter at the economy panel
  boundary that reads the whole transactive load and settles in ISO
  wholesale markets. Gold standard beyond its class: MQTT, every reading
  once a second, a good API. Ours, built as a mains front end behind an
  isolation barrier with the voltage beacon as its other half; a bought
  class 0.2 meter bridges until ours is listed (`README.md` "The chosen
  architecture").
- **Voltage beacon**: the low-voltage device of ours that keeps the
  drumbeat and measures the mains voltage, and gives every CT node
  what it needs for high-accuracy metering (frequency, phase at a
  reference time, RMS, the low harmonics, all stated on the drumbeat),
  or receives their timestamped samples and does the multiply
  itself. It broadcasts on a schedule, which is what a beacon does. It
  hosts the economy market maker. Standalone it reads a Class 2 adapter;
  inside the boundary meter it is the module behind the isolation
  barrier and reads the metering front end instead.
- **Drumbeat**: the shared "now" the voltage beacon keeps for every CT
  node in its house, so voltage and current samples taken on different
  processors line up to the microsecond. It is relative to the beacon's
  own oscillator and makes no claim about UTC: like a band following its
  drummer, the nodes need to agree with the beacon, and a beacon steady
  but drifting from UTC costs the metering nothing. Interval boundaries
  take UTC from NTP, which is a separate concern. A node is on the
  drumbeat when its offset from the beacon is inside the timing budget
  of the tier it claims (`designs/voltage-beacon/primary.md`, the timing
  budget note). How it reaches a node (a wired pulse in the panel, Wi-Fi
  or Ethernet timestamps for a satellite) is the beacon's clock design.
- **Economy market maker**: the MarketMaker that runs the house's own
  markets across the sub-metered loads behind the boundary meter, deems
  a measurement good enough to settle a transaction, and lets third-party
  providers bid in. Latent inside the economy panel today
  (`../economy-panel/executor/primary.md`, where it is also called the
  panel-level MarketMaker); its natural host is the voltage beacon, the
  one per-house device every CT node depends on.

- **Economy panel**: the sub-panel-shaped enclosure that houses the
  transactive load's protection, the settlement meter and, latently, a
  panel-level MarketMaker (`../economy-panel/executor/primary.md`).
- **Transactive-load boundary**: the point at which all of a house's
  transactive load is metered for the ISO, today a Versant Rate A-1 bonus
  meter on a separate service entrance with our meter in parallel.
- **Settlement tier / sub-metering tier / indicator tier**: the three
  tiers of `README.md` "The three tiers".
- **CT node**: an MCU that samples one or more CTs and either computes
  power from a voltage model it receives, or ships timestamped current
  samples to the device that has the voltage.
- **Good-enough bar**: the accuracy the MarketMaker publishes for a
  measurement to settle a transaction in its own markets. Evidence that
  clamp-on systems reach it at the sub-metering tier: California CTEP
  5645(c)-25 (`hardware/ekm-meter.md`).

## Names considered and not taken

For the boundary meter: master economy meter (the name in the
economy-energy-markets executor; long, and "master" is a word to
retire), settlement meter (reads as any meter the ISO settles on,
including Versant's), economy meter, panel meter. For the voltage
beacon: voltage producer ("producer" reads as a generator to a grid
person), voltage reference (also a chip inside every ADC), mains
reference, line reference, phase reference (undersells RMS and
harmonics). For the drumbeat: timebase (accurate but generic, and does
not say the beat is relative to the beacon), house clock (reads as
wall-clock time), house beat, downbeat.
