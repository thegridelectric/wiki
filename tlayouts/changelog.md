# Changelog

A reverse-chronological log of WHY we made each commit **in the
`tlayouts` code repo**. The matching git commit (in `tlayouts`) holds
the WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

<!-- pending commit -->
## 2026-08-12 — honeysuckle carries the full plant surface: circuits, plant relays, sim-uid primary BTU

The bench layout satisfies `gw.nolan.layout` axiom 3
(LocalControlPlant) and runs the TOU cooling loop against the real
board with zero stakes: four floor circuits at positions 1–4
(mirroring the spruce held-zone shape), the plant relays their gate
emits, and a `primary-btu` with a sim placeholder pico id —
`layout.lite` axiom 1 rejects a NoActor-captured channel, and the
bare `emit_primary_flow` fallback produced exactly that (a
bench-only conflict the new suite fixture surfaced; spruce provides
primary-flow from its real BTU). The regenerated artifact doubles
as the scada suite's pinned Nolan fixture, replacing the
legacy-format one.

## 2026-08-12 — DAC writer node emission: dac_channel_power_on_raw axis; snapshot on actor.class 013 (`355045e`)

The tlayouts side of the DAC leg (scada `e551c2e1`/`12d6a1bc`; sema
`1883372`/`91385fe`). The gen gains a `dac_channel_power_on_raw`
config axis — the per-channel EEPROM power-on values become the
house config's declaration instead of values hard-coded in the
emitter — and `emit_dac_writer` emits the actor node beside the
component, gated on that axis rather than on zone circuits (so a
bench layout can carry the DAC path alone). The vendored sema
snapshot rebuilds on actor.class 013 (possible once the partition
correction put node.gt/303 back in staging); both artifacts regen
with the `gw108-dac2-writer` node native.
