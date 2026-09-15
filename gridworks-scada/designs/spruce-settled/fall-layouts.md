# Fall 2026 layouts (spoke)

Status: Draft · Pass 0 · Updated 2026-09-14 · Linear: [OPS-532](https://linear.app/gridworks/issue/OPS-532)

> What this is: the four layouts arriving after House0 and Nolan — one
> simulated, three installed in Millinocket in fall 2026. This spoke holds
> what is known about each so the partition/names work is shaped for N
> families, not 2. Details being filled in with Jessica.

## The third in-field family: `gw.house0.no.sieg`

There are three in-field layout families, not two: `gw.house0.layout`
(has a siegenthaler loop — maple, beech), `gw.nolan.layout`, and the
sieg-less house0 topology that **oak, fir, and elm** actually are,
authored as `gw.house0.no.sieg`. Authoring that word and its oak / fir /
elm generators is a launch item and moved to OPS-392; this spoke keeps
the per-install physical detail below.

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
- `ShortCycleBuffer` both ways in a House0 sim. The flag changes the
  leaf ally's buffer band (`is_buffer_empty` reads depth3 against
  RSWT minus delta-T, `is_storage_colder_than_buffer` compares the buffer
  bottom to the tank top) and zeroes the LTN's buffer-available kWh; local
  control ignores it. The sim pairs run it false and the field houses now
  run it true, so the leaf ally's true path has no test. Run a House0 sim
  pair with each value and pin both bands.
