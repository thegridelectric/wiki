# Sieg semantic harmonization (design — stub)

Status: Draft · Pass 0 · Updated 2026-06-10 · Linear: OPS-400

> What this is: get the **correct constructs in place and tested** for the
> sieg loop on both Beech and Maple. Companion to `sieg-summer-posture`
> (OPS-395, shipped as scada `e6ba4f51` / PR #570) — the broader
> evaluation that fix surfaced. Stub; the evaluation is the design work.

## Why now

The summer-posture fix is correct and surgical, but it exposed that the
sieg loop carries a single, implicit "default behavior when the heat pump
is off" — and that default is actually **per-heat-pump**, plus there's a
semantic/observability seam worth closing.

## Findings to evaluate

### 1. Weakened invariant + observability gap (OFI from #570)

Before #570, `SiegControlState.HpOff` mapped 1:1 to a valve posture
(`full_keep`, closed). After #570 it maps to **either** `full_keep`
(closed) **or** `full_send` (open) depending on `settings.system_mode`.
So control state no longer uniquely determines actuator output — and
nothing in telemetry disambiguates: the valve-state `SingleMachineState`
is still commented out (`sieg_loop.py`, the `# TODO: add a new node for
the valve` block). The deciding input is a static startup global read
inline in the posture decision. Candidate fixes: emit valve-state
telemetry; and/or route posture through explicit, observable state rather
than a hidden config read.

### 2. Default-when-off is per-heat-pump, not global

- **Maple (Mitsubishi):** primary pump runs *all the time* → full keep
  when HP off, to protect stratification.
- **Beech (LG):** primary pump runs for a window before startup, then
  shuts off (duration TBD — test to find it). Genuinely different
  default-when-off, *even at the same LocalControl state (e.g.
  BufferOnly)*.

The code bakes in one default; it should be parameterized per heat pump /
per house.

### 3. Flow-meter location asymmetry

- **Beech:** the flow meter that originally read primary pump speed sits
  *inside* the sieg loop — still reads primary pump speed directly.
- **Maple:** that flow meter sits *outside* the sieg loop — so primary
  pump speed became a **derived channel**.

Any sieg logic that depends on the primary-pump-speed signal could behave
differently per home. Evaluate where this matters.

### 4. Broader HSM-state evaluation

Inventory all kinds of "state" the sieg loop and its neighbors carry —
SiegControlState / SiegValveState, HpBossState, LocalControl top-state,
and SystemMode (static `settings.system_mode` here vs the LTN's runtime
`layout.SystemMode` from LayoutLite) — and assess how they hang together
and where the seams are.

## Carried-forward Opens from sieg-summer-posture

- The hydraulic *why* of open-in-summer, written down.
- Interaction with the July fan-coil cooling path (Nolan AC; Maple if it
  cools): does valve position affect cooling flow anywhere?
- Fleet sweep: which homes are sieg-plumbed ("what about Beech?").
- Return-position contract with `sieg-valve-exercise` (its sweeps must end
  at the posture position).

## Bar for done

Correct constructs in place **and tested** on both Beech and Maple.
Distillate lands in `executor/`.
