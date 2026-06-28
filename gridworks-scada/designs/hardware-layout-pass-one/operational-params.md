# operational-params — the third SCADA artifact (spoke)

Status: Accepted · Pass 1 · Updated 2026-06-28 · Linear: OPS-407

> What this is: a third SCADA artifact alongside deployment config and the static hardware layout — the
> **operational / optimization parameters** (`operational-params.json`): the tunable state that changes
> *without* rewiring hardware. **Built this pass** — folded in from a would-be sibling design because it is
> too entangled with the `channel.config` reshape to defer (dropping capture params from the layout needs
> their new home *now*). The LTN live-update *transport* stays OPS-408 (its consumer), not this spoke.

## The boundary — the rewiring test

> Can you change it without rewiring hardware? If yes, it's operational, not topology.

By that test, these leave the static layout / config and live in `operational-params.json`:

- **Per-channel report tuning** — `CapturePeriodS`, `AsyncCapture`, `AsyncCaptureDelta` (and possibly
  `PollPeriodMs`) — the capture params that today sit in every component's `channel.config`. (Once they
  leave, the base `channel.config` collapses to just `ChannelName` — see [`layout-boundary.md`](layout-boundary.md).)
- `SystemMode` (in config today), `UseSiegLoop` (the sieg toggle), `CriticalZoneList`,
  `ZoneKwhPerDegFList` (the last two in `gw.house0.hydronic` today).
- FLO knobs (penalties, horizon, COP curve) — though `flo_params` is an **assembled** message, not stored
  config.

## What this spoke builds vs what stays OPS-408

- **This spoke (pass-one):** the `operational-params.json` artifact + the **sema types** for it + the
  `ops_and_sema_to_dc` assembly, and the migration of the fields above **out of** config and the static
  layout into it.
- **OPS-408 (Thomas), the consumer:** the **LTN live-update transport** (web → LTN → SCADA, in Auto,
  SLA-preserving) that *pushes* updates to these params. It is **gated by this spoke** creating the sema
  types (the transport carries types this spoke defines).

## Why nothing breaks (the assemble pattern)

The runtime dc `HardwareLayout` the device actors read is **assembled**, not authored:

```
ops_and_sema_to_dc( static-layout sema ⊕ operational-params.json ⊕ live state ) → runtime dc
```

So moving a field here does **not** change the runtime `channel.config` — device actors still read
`CapturePeriodS`/`AsyncCaptureDelta` off their component, because assembly merged them back. The split is
in **authoring / source-of-truth**. The reshape (`channel.config` → `ChannelName`), the first-pass
`operational-params.json`, and the assembly land **together** — no broken interim. Forward-only: no
`dc_to_sema` / `dc_to_ops` — the fleet is re-authored via the sema gen, which now emits **both** the static
sema and `operational-params.json`. A **live LTN update** → re-assemble → actor reconfig is the dynamic
path (OPS-408's transport drives it).

`ops_and_sema_to_dc` also carries the one genuinely-new validity check — the **assembly** check: *do the
operational params cover every channel the static layout declares?* (Layout-structure validity stays in
the sema axioms; this coverage check is the merge's own concern.)

## Relationship to the FLO

`flo_params` (`gwsproto/named_types/flo_params_house0.py`) is an **assembled message** built from layout
physical facts (tank gallons, HP nameplate) ⊕ operational params (penalties, COP, mode) ⊕ live forecasts/
state — not a stored file. So these operational params are *inputs* to the FLO-params assembly, resolving
the overlap where physical facts (tank gallons, nameplate) appear to live in two places: physical facts
stay in the layout; tunable choices live here; `flo_params` is computed from both.

## Open

- **Which params, exactly** — finalize the field list that crosses the rewiring boundary (esp. the
  `PollPeriodMs` borderline: device cadence vs report tuning).
- **The artifact shape** — one operational-params sema type, or a small family (telemetry/capture vs
  control/optimization sections)?
- **Re-assembly + actor reconfig** — the live-update mechanics when OPS-408 pushes a change. **Testing
  this end-to-end needs the simulated environment** (a SCADA on a sim layout + a live LTN to push the
  update + observe it applied) — the sim-test-environment rig ([OPS-40](https://linear.app/gridworks/issue/OPS-40)).
- **Sequencing within the pass** — the capture-tuning extraction + `ops_and_sema_to_dc` ride the
  `channel.config` reshape (forced); the `SystemMode`/criticality/thermal-mass migration can follow within
  the pass.
