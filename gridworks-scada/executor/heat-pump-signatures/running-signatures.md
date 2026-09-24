Status: Draft · Pass 0 · Updated 2026-09-24

# Running signatures

What this is: what a heat pump looks like in the scada's channels while
its compressor runs steadily, per model: power, flow and lift once the
start is over. Steady running for the Ecodan and the LG is in
[`startup-signatures.md`](startup-signatures.md).

## Samsung AE055FEYMCG (spruce)

Read from the journal DB, 2026-09-21 16:00 to 2026-09-24 16:00 ET: 45
runs of the Samsung's water pump with the compressor on.

- `hp-odu-pwr` median per run 2.4–7.1 kW for runs longer than two
  minutes, highest reading 7.5 kW. Charging the buffer from 93 °F on
  2026-09-23 it peaked at 6.9–7.4 kW in each 10 minutes from about 20
  minutes in.
- `primary-flow` 11.5–11.7 gpm.
- `hp-ctrl-box-pwr` about 100 W (per-run medians 36–98 W on 5-minute
  samples).
- `hp-lwt` up to 144 °F.
- The secondary pump at 65 % of max gives 7.6–7.9 gpm of
  `secondary-flow`.

## Open

- Self-stops and the running/stopped thresholds for the Samsung (see
  [`startup-signatures.md`](startup-signatures.md) "Running and stopped,
  from power").
- Lift against buffer temperature and outdoor temperature.
