# Spruce un-limbo (design seed)

Status: Draft · Pass 0 · Updated 2026-06-10

> What this is: the **hub seed** for un-limboing the spruce scada
> integration — Jessica's 2026-06-09 brain-dump plus same-night verified
> facts, written as a tight anchor for a fresh session to turn into a
> verified analysis, task list, and Linear issues. Everything not marked
> *verified* is Jessica's statement awaiting code-level confirmation.
> Mirrors the launch-new-simple-marketmaker seed pattern.

## The commitment (the deadline driver)

**July 15: air conditioning at Matt Polstein's, with pride in the scada
code.** The promised shape: AC runs off-peak, plus pre-cooling the room a
bit during the afternoon shoulder. Constraints:

- Cooling uses the **fan coil units directly from the heat pump**. NOT the
  radiant floor and NOT the store tanks (that would require reversing water
  flow).
- Suspicion to validate: **long cooling bouts** are more efficient.
- Later option, eyes open: use the thermal store for cooling accepting that
  the water mixes — no stratification, very limited capacity.

## Current state (mix of verified and reported)

- *Verified 2026-06-10:* branches `jm/spruce` and `jm/spruce-new` both exist
  locally; only `jm/spruce` has an origin remote; the working tree sits on
  **`jm/spruce-new`**, whose tip is `2b603cc0` (2026-04-01, "Bump channel
  config versions for RelayActorConfig and I2cThermistorChannelConfig" —
  adds `ChannelConfigBase`, bumps relay/thermistor/layout-lite config
  types). `jm/spruce-new` is the progressed branch; untouched since April 1.
- *Reported:* the spruce branch line has diverged from dev and runs on
  spruce **observation-only**, while a **starter-scripts hack operates the
  resistive elements on a clock**. The **derived channels** are more
  nuanced on the branch than on dev. (Locate the hack; diff the derived
  channels — fresh session.)
- *Reported:* the "obvious progression" lives in
  `packages/gridworks-scada-protocol/names/` on one of the spruce branches,
  and those names are used in **layout generators** there.
- *Verified:* sema holds a draft **`gw.nolan.layout`** type — the WIP spruce
  layout, first instance of **different-layouts-as-complex-Sema-types**.
  Linear: OPS-334 ("80% done", in doing since 2026-04-10), OPS-219 (Nolan
  House control: i2c bus actor + i2c relay board actor + initial local
  control; in doing since 2026-01-20).
- Tanks: **two installed (buffer + store), team conviction is one tank**,
  whose job is to "top up" the radiant floor; if it doesn't fully, that's a
  tiny temperature swing. The design should assume the one-tank model.

## Chunk hypothesis (Jessica's, to verify and refine)

- **Chunk A — i2c relays (independent).** The i2c bus actor + relay board
  actor must exist before any scada control of spruce, AC included. Gates
  everything physical; on the July-15 critical path. (OPS-219's checklist;
  `2b603cc0`'s config bumps are adjacent groundwork.)
- **Chunk B — layout pipeline (hub of the rest).** `names/` progression →
  layout generators using those names → `gw.nolan.layout` as a complex Sema
  type. Jessica's stated preference: **finish the spruce layout before
  running scada controls.**
- **Chunk C — branch reconciliation.** Pick the canonical branch (likely
  `jm/spruce-new`), reconcile the more-nuanced derived channels with dev,
  merge, retire the starter-scripts hack. Coordinate with the live gwbase/
  LTN cluster (noisy-iris) — the same repo is mid-debug.
- **Chunk D — Nolan local control scheme.** New in cool ways: electric
  resistive backup, a heat exchanger (so an extra pump), radiant floor +
  fan coil units not used before — a bunch of heat-management complexity.
  Plus: mechanical thermostats + wired thermistors (the only site without
  Honeywell Z-Wave/Hubitat), sensed via opto/white-wire; Thomas's setpoint
  calculation. Same in spirit as House0's "simple method for staying warm,"
  but radiant floors behave very differently from tanks of water; expect
  partial reuse, not a copy. **Written against the ShNodeActor capability
  surface from day one** — see the capability-protocol-and-verify design
  (OPS-394); the maple standby incident (OPS-393) is what relay-level
  control does when a new layout arrives. Input data: Thomas's nolan-layout fixture
  sketch (`bb3a6ec6`, decoded in OPS-392's update note) — mine it, then
  delete it when the generated layout lands.
- **Chunk E — minimal AC path by July 15.** The smallest subset of A–D that
  honors the commitment. Tension to resolve explicitly: Jessica wants B
  (layout) done before controls run, and July 15 is fixed — the analysis
  must either show B fits before the deadline (OPS-334 is "80% done") or
  propose what minimal layout suffices for AC-only control.

## The meta-goal (why this is vision-grade, not a chore)

We are still finding the best designs for different scenarios — new-build
green homes (Matt) vs old median homes in northern Maine. The system must
let us **reason like this brain-dump and adjust on the fly to new
configurations**: control schemes parameterized by layout
(layouts-as-complex-Sema-types), not hand-coded per house. Spruce is the
first proof.

## For the fresh session

1. Claim `wiki/gridworks-scada/` (taking over from sunny-lichen) and
   coordinate before touching `gridworks-scada/` code — noisy-iris holds it.
2. Verify every *Reported* item above against the branches (read-only git:
   `git diff dev...jm/spruce-new`, `git show`, no checkouts — the working
   tree is shared and live).
3. Turn chunks into a task list with the July-15 critical path explicit;
   fold OPS-219 + OPS-334 in; propose the Linear issue set (design tag on
   this hub when Accepted).
4. Reconcile this seed with what you find; everything here is Open.
