# Data glitches — where the journal's labels lie

Status: Draft · Pass 0 · Updated 2026-11-21

What this is: the register of windows in which journaled readings do not
mean what their channel row says. The eventstore is the record, so a
glitch is never rewritten in the journal; it is described here, and a
reader that must mask one does so by this table. One row per glitch.
This is the Glitches table of the gridworks-data executor; a sema word a
reader can look up and mask by retires the hand-kept table.

## Glitches

| Houses | Channels | Window (UTC) | Label says | Integers are | Detected by | Readers affected |
|---|---|---|---|---|---|---|
| beech, oak | the 16 tank and buffer depths (`buffer-depth1..4`, `tank1..3-depth1..4`) | beech from within 2026-01-07, oak from late 2026-01-08, both until the 2026-01-09 layout renamed the unit (beech 00:25, oak within the first hour) | `spaceheat.telemetry.name` `WaterTempCTimes1000` | Fahrenheit × 100 | the raw integers run continuously across the rename (beech buffer-depth1 daily mean 14761 on 01-08, 14899 on 01-09 as `FahrenheitX100`) while the labelled temperature jumps from ~15 °C to ~69 °C; elm, fir and maple show no such window, their 01-08 means being 54757–67313 | every reader that scales by the channel row: the hourly tank columns show ~55–60 °F for those hours; a per-channel boundary is findable from the raw discontinuity |
| oak, maple | every temperature channel the 013-era scada reported (`hp-lwt`, `hp-ewt`, `dist-swt`, `dist-rwt`, `buffer-hot-pipe`, `buffer-cold-pipe`, `store-hot-pipe`, the zone temperatures and setpoints) | oak 2026-10-23 05:45:29 to 07:14:57; maple 2026-10-23 07:15:01 to 07:19:56; to the second, from the first and last `CelsiusTimes100` row of the day at each house | `spaceheat.telemetry.name` `CelsiusTimes100` | Celsius × 1000 | the 013 build ran without the scaling code the later main has; 286 of oak's 770 and 130 of maple's 423 `CelsiusTimes100` rows in the window read above 150 °C (a 44 °C pipe as 44332), while spruce's 2254 rows in the same window are all below 61 °C; the rows below 150 °C are not separable from × 100 by value | every reader that scales by the channel row: oak's hourly `hp_avg_lwt` reads 385 °F for 05:00 and 426 °F for 07:00; the old-spelling row of the same channel reported correctly through the window, so a per-second reader shows the two rows interleaved |

## Rules

- A row states the window to the finest boundary read from the data,
  and says how fine that is.
- A reader that masks a glitch cites the row; a reader that does not,
  shows the labelled value. Neither rewrites the journal.
