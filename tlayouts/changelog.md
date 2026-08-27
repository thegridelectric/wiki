# Changelog

A reverse-chronological log of WHY we made each commit **in the
`tlayouts` code repo**. The matching git commit (in `tlayouts`) holds
the WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-08-22 — comment out old gen files (`687bfd4`)

The pre-sema per-house generators (`gen_almond.py`, `gen_beachrose.py`,
`gen_beech.py`, `gen_elm.py`, …) are commented out: the sema gens
(`house0_sema_gen` / `nolan_sema_gen`) are the live path, and the old files
no longer run against the current vocabulary. Kept in-tree, inert, as
reference for house-specific facts not yet re-encoded.

## 2026-08-23 — sema scripts and clear descriptions (`13831a1`)

tlayouts vendored its Sema snapshot with no seed or regen script in-repo —
refreshing meant hand-running the sema CLI. Adds the standard
`scripts/regen_sema_snapshot.sh` (instance of sema's
`template_regen_snapshot.sh`, `--allow-staged` while the layout closure
stages) and a **minimal seed**: the two layout words plus
`gw.house0.operational.params` — everything else the repo touches
(components, channels, `g.node.gt`, enums) arrives through dependency
closure. Drops the previously-seeded heads (`gw1.simple.sim.layout`,
component words) as direct targets; any still referenced by the layouts
re-enter via closure, the rest leave the snapshot. The repo also gains its
first README — what tlayouts is, the `./output` destination, the standard
Sema paragraph (canonical language + boundary-scoping sentence), and the
remaining-scada-coupling note. That coupling shrinks in the same commit:
the two board descriptors (`krida_double_relay_board_16_device_type`,
`gw108_device_type`) stop importing from gwsproto python constants and
become vendored `gw1.scada.device.type.gt` instances under
`src/tlayouts/device_types/`, decoded through the snapshot at import — so
what remains of the scada-venv dependency is the `gwsproto.names`
constants only (tracked against the scada renovation's names outcome).

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
