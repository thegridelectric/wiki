# The real-time page

Status: Draft · Pass 0 · Updated 2026-10-28

> What this is: the real-time page of the web-frontend, the live system
> graph of one house drawn from the gateway's snapshots: the words it
> reads, how a reading becomes a displayed number, and what the layout
> decides on the page. The page is
> `gridworks-web-frontend/src/real-time/RealTimeStatusPage.tsx`.

## The words

The page reads these words, each a zod schema under
`gridworks-web-frontend/src/sema/` with its static type inferred from
the schema, PascalCase wire names, `Sema: <schema_url>` as the only
docstring, and the word's axioms as refinements named `checkAxiom<n>`
after the sema axiom numbers:

- `layout.lite` 013 as the whole word, with `data.channel.gt` 004 and
  `derived.channel.gt` 003; 011 and 012 through readers of the fields
  the page uses (`src/sema/types/old_versions/`). The union of the three
  is `AnyLayoutLite` (`src/sema/types/AnyLayoutLite.ts:7`).
- `snapshot.spaceheat` 003 and `single.reading` 000, as the gateway
  forwards them in its `mqtt_message` envelope.
- The enums `spaceheat.telemetry.name` and `gw1.unit`, as zod enums.

The house's layout reaches the page in the installation summary
(`gw.house.summary` `Layout`), which the api fills from
`gridworks.layouts`, the row the gateway also seeds from. The page parses
it once (`RealTimeStatusPage.tsx:138`); a layout that fails to parse
leaves the page with none, and a layout that arrives while the page is
open reaches it at the next load.

Each schema has tests under `src/sema/__tests__/`: a recorded instance
from the fleet parses, a removed field, a wrong `TypeName`, a wrong
`Version`, a wrong primitive type and an enum value outside the enum
each fail with the failing path named, and the instance round-trips.

## A reading's unit is the layout's

A `single.reading` names its channel by name and sends an integer. The
page resolves the name in the house's layout: a DataChannel's
`TelemetryName` or a DerivedChannel's `OutputUnit`
(`src/sema/layoutUnits.ts:9`). One table maps a unit value to its
display value and hover format, keyed by the two enums
(`src/sema/units.ts:13`); the visualizer converts through the same
table. The page converts every reading in the snapshot once
(`src/sema/displayReadings.ts:20`, `RealTimeStatusPage.tsx:195`) and
the diagram and the tables read the converted readings.

A channel the layout does not declare, or whose unit has no table row,
keeps its raw integer and is shown with the raw marker
(`displayReadings.ts:34`); the page never guesses a unit from a name.
The pump table shows watts from the table's kilowatts
(`RealTimeStatusPage.tsx:128`).

Tests: the resolver returns the declared unit for a data channel and a
derived channel and nothing for an undeclared name; every temperature,
flow, power and energy value of both enums has a table row; 2998
CelsiusTimes100 displays 86.0 F, 10441 FahrenheitX100 104.4 F, 29980
WaterTempCTimes1000 86.0 F; the raw marker appears for an undeclared
channel and for a declared unit outside the table.

## What the layout decides on the page

- **The sieg loop** is present when the layout declares a `sieg-flow`
  data channel (`src/sema/plantLoops.ts:16`); the diagram's sieg
  vertical and the pump table's two sieg rows follow it. With the loop,
  the primary loop counts as flowing from 0.5 GPM of `sieg-send`;
  without it, from any `primary-flow` (`plantLoops.ts:32`).
- **The secondary loop** is present when the layout declares a
  `secondary-flow` data channel (`plantLoops.ts:21`); the pump table's
  Secondary row follows it (`RealTimeStatusPage.tsx:600`).

## Open

- The diagram's family (the two-tank picture with the exchanger column
  against the three-tank one), the secondary temperatures on the diagram
  and the resistive-element table key on the house alias containing
  "spruce" (`RealTimeStatusPage.tsx:588`). Each is a fact the layout
  states (`HardwareLayoutTypeName`, the channels declared), and the
  diagram keys its parts on those once a third family is in the fleet.
- The zone table: the gateway's `thermostat_names_from_layout`
  (`gridworks-web-backend/gateway/state.py:113`) regexes channel names
  into thermostat names and the browser filters names ending in `-gw`
  (`RealTimeStatusThermostatTable.tsx:95`); the spruce branch groups
  zones by a name prefix (`RealTimeStatusThermostatTable.tsx:30`). Every
  stored layout since 011 has `ZoneList`, which both read instead.
- The gateway's envelopes (`status`, `mqtt_message`,
  `zone_whitewire_series`) are hand shapes with no word; the browser
  types `status` and `mqtt_message` by hand and drops the series.
- A backend-to-browser word that names a channel by Id; nothing needs
  it yet.
