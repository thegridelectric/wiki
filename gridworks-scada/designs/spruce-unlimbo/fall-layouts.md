# Fall 2026 layouts (spoke)

Status: Draft · Pass 0 · Updated 2026-09-01 · Linear: OPS-392

> What this is: the four layouts arriving after House0 and Nolan — one
> simulated, three installed in Millinocket in fall 2026. This spoke holds
> what is known about each so the partition/names work is shaped for N
> families, not 2. Details being filled in with Jessica.

## The third in-field family first: `gw.house0.no.sieg` (not built yet)

Honesty about the fleet: there are already THREE layouts in the field.
`gw.house0.layout` (has a siegenthaler loop — maple, beech),
`gw.nolan.layout`, and the sieg-less house0 topology that **oak, fir,
and elm** actually are — to be authored as **`gw.house0.no.sieg`**. A
sieg loop is a topology change (family), not a variant; whether the
loop is USED is an operational param (`UseSiegLoop` migrates layout →
ops), and hp-boss/sieg-loop sit dormant when unused. Today's
`gw.house0` test fixture has `UseSiegLoop: false` — it has been quietly
modeling this third family and likely becomes its fixture when the
word is authored. Not being built now; the house0 word's
sieg-unconditional tightening waits on it.

## The four

1. **Simulated layout** — *(details to fill: which word — is this
   `gw1.simple.sim.layout`, already queued as the N=3 stress test?)*
2. **Millinocket install A — simplified manifold.** No iso valve, no
   buffer tank. *(details to fill: heat pump, store, zones, sensing)*
3. **Millinocket install B — simplified manifold.** Same simplification
   as A. *(details to fill: what differs from A)*
4. **Millinocket install C — cement store-under-floor.** No water tanks
   at all. *(details to fill: how the slab is charged/sensed, pumps,
   emitters)*

## What this means for the code (known so far)

- Two likely-at-scale layouts have NO buffer tank and NO iso valve — the
  bar that blessed `hydronic/shared.py`: shared means "every layout we
  can imagine has this," not "both current families use it."
- Store-under-floor removes water store tanks entirely: nothing above
  the family tier may assume `total_store_tanks ≥ 1`.
- Flags already captured in the partition spoke (bufferless-fall list):
  `ScadaData.buffer_temps_available` on the base data class, `scada.py`'s
  first-buffer-reading fast-forward, `HydronicSpaceheatNodeNames`'
  buffer-names docstring claim.
- Standing rule: a new family's sim pair ships in the same wave as its
  word.
- **Every layout has a store pump** (Jessica, 2026-09-01) — the
  store-under-floor slab included — so `store-pump-relay` is an
  every-hydronic-plant name (`HydronicSpaceheatNodeNames`), not
  per-family.

## Open

- Everything above marked *(details to fill)*.
- Which of the six name-tier / hydronic-tier structures each new family
  reuses vs owns.
