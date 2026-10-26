# report-send-jitter

Status: Draft · Pass 0 · Updated 2026-10-25 · Linear: OPS-620

**EDD: yes** verified on hw1 over one five-minute mark with the change
deployed to every house: the journal's `report.event` rows for the mark
have send times spread across the offset window by house, each report's
`SlotStartS` and reading timestamps unchanged, and the journalkeeper's
persist lag per report is within one second of its send.

> What this is: every scada sends its `report.event` at the top of the
> five-minute period, so the journalkeeper, one consumer, gets the whole
> fleet's reports in the same second and everything else journaled that
> second waits behind them. This design moves each house's send time to
> a fixed offset inside the period. It spreads the burst; it does not
> shrink it. The per-report cost itself is OPS-616 in the journalkeeper.

## Why

The scada's report loop sleeps until 1.2 s before the next multiple of
`seconds_per_report` and sends from there
(`gw_spaceheat/actors/scada.py` `state_tracker`, `next_report_second`).
Five houses' reports of the 2026-10-25 20:25Z mark reached the broker
within 35 ms of each other and the last was persisted 6.8 s after it
was sent; the shape is the same at every mark. A second cause of
stacking is independent of the keeper's speed: a boot storm after a
power event, or a `layout.lite` republished across houses, falls on the
same second as the reports.

Spreading the sends is what telemetry fleets do as a matter of course,
and it costs a few lines here. It is worth doing on its own because it
keeps the burst from stacking with other fleet-wide events, whatever
OPS-616 does to the per-report cost. It is not a fix for that cost: a
hundred houses at 1.5 s a report is 150 s of keeper time in every 300,
offset or not.

## Mechanism

- A fixed offset per house, in seconds from the top of the period,
  derived from the scada's GNode alias (a hash onto `[0, max_offset_s)`)
  so it is stable across boots and needs no coordination and no new
  config per house. `max_offset_s` is a `ScadaSettings` field with a
  default well inside the period (60 s is the proposal), so a report is
  still "the report of the mark" to anything that reads it that way.
- The report's content is untouched. `SlotStartS` and `SlotDurationS`
  stay the period boundaries (`scada_data.py` `make_report`), the
  readings' timestamps are the sensing times, and `_last_report_second`
  is still the nominal period. Only the moment of the send moves.
- Snapshots (`seconds_per_snapshot`, 30 s) are not in scope unless the
  measurement in OPS-616 shows them stacking too.

## Check before building

- What reads a report as "fresh at the top": the visualizer's live view
  reads snapshots, the alerter's projections read the journal; confirm
  neither keys on the report's arrival second.
- Whether the LTN's cadence or the dispatch contract expects the report
  at the top. The report is the scada's record of the past period; the
  LTN works from the snapshot and its own clock.
- The OPS-616 witness is defined on the burst at one mark; its "before"
  measurement is taken before this ships, or its witness is restated in
  terms of per-report lag.

## Out

- The journalkeeper's per-report cost and its consumer count (OPS-616).
- The report's size or content.
- Randomized rather than fixed offsets: a fixed offset is predictable
  in the journal and reproducible in a test, and the fleet is small
  enough that a hash gives a good spread.

## Open

- `max_offset_s`: 60 s keeps every report within the first minute; a
  wider window spreads further and makes "the report of 20:25" arrive
  at 20:28. The hundred-home case decides.
- Whether the offset also applies to the `MachineStates` the loop sends
  with the report (it should; they go together).

## Plan

1. Settings field and the offset function, with a unit test that two
   aliases map to different offsets and the same alias always to one.
2. The loop sleeps to the top plus the offset; a test with the
   simulated clock asserts the send second and the unchanged
   `SlotStartS`.
3. Deploy to one house, then the fleet; the witness at one mark.

Estimate at the Plan: about 2 h (1 to 4).
