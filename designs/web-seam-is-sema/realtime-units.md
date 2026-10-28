# Real-time units from the layout

Status: Accepted · Pass 1 · Updated 2026-10-28

> What this is: the first build slice of the web seam. The real-time page
> converts every reading through the unit the house's `layout.lite`
> declares for that channel, the words it reads are hand-written zod
> schemas in the browser, and a Vitest suite proves each schema accepts
> the word's instances and rejects malformed ones. The hand-written
> schemas are the fixture the TypeScript emitter reproduces
> (`typescript-emitter.md`).

## The fault this slice removes

The gateway forwards `snapshot.spaceheat` 003 to the browser unchanged,
and each `single.reading` 000 in it has a channel name and an integer
value. The browser decides the unit by channel name
(`gridworks-web-frontend/src/real-time/RealTimeStatusSystemDiagram.tsx`
`tempValueToFahrenheit`): a regex marks the derived depth channels and the
floor temps as `FahrenheitX100`, and every other temperature is divided
by 1000 as `WaterTempCTimes1000`. The thermostat table
(`RealTimeStatusThermostatTable.tsx`) divides zone temperature and
setpoint by 1000 and labels the result Fahrenheit.

The layouts on scada `main` declare temperature DataChannels in
`CelsiusTimes100` and the derived depth channels in `FahrenheitX100`, so
on elm (2026-10-28) hp-ewt at 2998 displayed as 37.4 F in place of 86 F,
and a zone at 1778 displayed as 1.8 F in place of 64 F. The visualizer
and the csv read the unit from `reading_channels` and were right.

## Decisions

- **`single.reading` names the channel by name.** It is the scada's
  word. The browser resolves the name against the house's most recent
  `layout.lite`: a DataChannel's `TelemetryName` or a DerivedChannel's
  `OutputUnit`. A name the layout does not declare is shown unconverted
  and flagged, never guessed.
- **One unit table.** The conversion to display units is the visualizer's
  `UNIT_CONVERSIONS` (`src/visualizer/DefaultVisualizerPlot.tsx`), moved
  to a shared module and keyed by the enum values of
  `spaceheat.telemetry.name` and `gw1.unit`. The real-time page and the
  thermostat table call it; `tempValueToFahrenheit` and the hand divides
  are deleted. A test asserts every temperature, flow and power value of
  both enums has a row.
- **zod for the browser's words.** Each word the real-time page reads is
  a zod schema in `src/sema/`, with its static type inferred from the
  schema, so a word is defined once and checked at runtime. Fields keep
  the sema PascalCase wire names. These replace the hand `.d.ts` for the
  same words.
- **Vitest for the browser's tests.** The repo has `tsc` and eslint and
  no test runner; Vitest is added and runs in the repo's CI entrypoint.
- **The layout the page uses.** The page reads the house's `layout.lite`
  from the session's installation summary (`HouseSummary.Layout`), which
  the backend fills from `gridworks.layouts`, the same row the gateway
  seeds from and keeps current from the live message. A `layout.lite`
  that arrives while a page is open reaches the page at its next load;
  the websocket's hand envelopes are the state seam's work and stay
  as they are here.

## The words, hand-written

Versions are the ones the backend's gateway snapshot speaks
(`gridworks-web-backend/gateway/sema/types/`):

- `layout.lite` 013, with `data.channel.gt` 004 and
  `derived.channel.gt` 003; 011 and 012 as the readers of the houses
  still on those versions, each with the fields the page reads.
- `snapshot.spaceheat` 003 and `single.reading` 000.
- The enums `spaceheat.telemetry.name` and `gw1.unit` at the snapshot's
  versions, as zod enums.

Each schema's docstring is `Sema: <schema_url>` and nothing else. Axioms
the page depends on are zod refinements named `checkAxiom<n>` after the
sema axiom numbers.

## Tests

For each word, under `src/sema/__tests__/`:

1. A recorded instance from the fleet parses (elm's `layout.lite` 013
   and a snapshot from its broker; a beech 011 layout).
2. A field removed, a wrong `TypeName`, a wrong `Version`, a value of the
   wrong primitive type and an enum value outside the enum each fail to
   parse, with the failing path named.
3. The instance round-trips: parse, serialize, parse, equal.

For the lookup and the table:

4. The unit resolver returns `CelsiusTimes100` for a DataChannel,
   `FahrenheitX100` for a DerivedChannel, and the undeclared marker for a
   name the layout lacks.
5. 2998 `CelsiusTimes100` displays 86.0 F; 10441 `FahrenheitX100`
   displays 104.4 F; 29980 `WaterTempCTimes1000` displays 86.0 F.

## Do this next

**▶ Do this next.** Step 5, the page check against elm on the dev stack
(`experiments/dev-stack-recipe.md` first): hp-ewt, hp-lwt, dist-swt,
tank1-depth1 and zone1 read within a tenth of a degree of the same
channels in the visualizer, and the pump table shows the Secondary row.
Steps 1 to 4 are on `jm/realtime-units` of gridworks-web-frontend
(57 tests under `src/sema/`); step 4 is uncommitted there.

## Build order

1. Vitest into `gridworks-web-frontend` and its CI entrypoint, with one
   trivial test.
2. zod; the enum schemas; the `single.reading` and `snapshot.spaceheat`
   schemas; the `layout.lite` family. Tests 1 to 3 per word.
3. The shared unit table and the layout unit resolver. Tests 4 and 5.
4. The real-time diagram and the thermostat table convert through the
   resolver and the table; the name-matched function and the hand
   divides go. The gateway's status envelope is untouched.
5. A page check against elm on the dev stack: hp-ewt, hp-lwt, dist-swt,
   tank1-depth1 and zone1 read within a tenth of a degree of the same
   channels in the visualizer.

Out of scope: the websocket envelopes, the zone table's regex and the
spruce family switch (the hub's "The real-time page"), and the
journal's hourly unit literals (OPS-630).
