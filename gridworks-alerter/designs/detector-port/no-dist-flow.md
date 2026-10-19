# no-dist-flow — a heat call ended with no distribution flow

Status: Draft · Pass 0 · Updated 2026-10-19

> What this is: the port of gwalert's `check_dist_pump`
> (`alert_generator.py:827`) as `NoDistFlow`, named for the condition
> a person acts on.

## gwalert today

Reads zone whitewire channels, `dist-pump-pwr` and `dist-flow` by
name. A heat call is a whitewire above a per-house watts threshold
(beech 100, elm 0.9, default 20). A call that lasted at least 15
minutes and ended at least 5 minutes ago counts when the flow (`/100`,
inline) from 5 minutes before the call to its end never reached 0.5
gpm; the alert fires on the third such call. The flow fallback compares
a raw value without the `/100`; `max([])` raises when no flow row falls
in the window; the whitewire values are overwritten in place. Pump
power never gates the alert, only the message wording.

## The port

- **Reads:** heat calls from the zones' heat-call state channels (the
  layout says which channels those are and their unit), the
  distribution flow channel from the layout with its unit and
  exponent, the readings window for the call's span.
- **Fires** when `no_dist_flow_calls` (3) sustained calls (at least
  `heat_call_min_s`, 900) have each ended with the flow never above
  `dist_flow_min_gpm` (0.5) from `flow_lookback_s` (300) before the call
  to its end; **resolves** when a call ends with flow seen.
- **Layout:** a house with no distribution flow meter or no heat-call
  channels has no `NoDistFlow`. A heat call is the layout's heat-call
  channel in its on state, which retires the per-house whitewire
  thresholds.
- **Tests:** three dry calls fire; a wet call resolves; two do not fire;
  a short call does not count; no flow meter is absent.

## Do this next

Confirm the heat-call channel and its unit in the layout word for each
current family, then the pattern in the hub.
