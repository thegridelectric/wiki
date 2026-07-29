# Changelog

A reverse-chronological log of WHY we made each commit **in the
`tlayouts` code repo**. The matching git commit (in `tlayouts`) holds
the WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-07-28 — spruce sema gen added (`0376dc4`)

**What:** `nolan_sema_gen.py` — the Nolan strategy on the sema-native
machinery (`NolanSemaGen` extending `House0SemaGen`): emits the
`scada.board.component.gt` anchor, the Vdc `gpio.relay.component.gt`, the
per-zone opto `gpio.sensor.component.gt`s and the shared thermistor reader
(AdcName `Thermistors`), plus a minted-GNode hook for fresh dev identities,
assembling a `gw.nolan.layout` artifact + ops params.
`honeysuckle_sema_gen.py` — the bench MVP: minted d1 bench trio, four opto
zones exercising all four ADS channels, the Vdc relay, sim meter/tanks;
idempotent against its own output, artifacts validate through the snapshot
(axioms incl. BoardResolution), and the assembled dc loads as
`d1.bench.honeysuckle.scada`. `emit_primary_flow` now emits the bare
channel's capture tuning (ops coverage). Snapshot rides `gw.hydronic` — the
Hydronic block is typed in both layout words, and the gens emit the model
directly. `spruce_sema_gen.py` — the nolan layout on the spruce house, REAL hw1
identity (honeysuckle owns the d1/dev role): the deployed aliases and
GNodeIds verbatim, upgraded to the g.node.gt/005 shape; three new gen
emitters (pico BTU meters, free-standing tank modules, identity derived
channels) carry the deployed content (five zones with the opto-only fancoil,
eGauge incl. hp-ctrl-box@9010, four BTUs, six extra picos);
id reference resolves in code (`resolve_id_reference`, temporary until the
terminalasset registry is the id authority): rclone the spruce pi's live
hardware-layout.json, falling back to the gen's previous output — all 69
channel ids carry over from the deployed layout, and the
assembled dc loads as `hw1.isone.me.versant.keene.spruce.scada` with the
deployed node count (78). (OPS-392)

**Why:** the dev-spruce layout must be authored on the sema contract with
board-anchored components, and the bench MVP is the zero-stakes boot target
for the reader→bus experiment on the pi wired to the gw108.

---

## 2026-07-27 — Board-resident model (`1336c8e`, branch jm/dev-spruce)

**What:** sema snapshot rebuilt against the merged `jm/single-bus-owner`
line: `NolanLayout` rides `spaceheat.node.gt/303` + `data.channel.gt/003`,
and its components union is the board-generic `gpio.relay.component.gt` /
`gpio.sensor.component.gt` (GpioName against the board's native-pin
registry) — the gw108-prefixed words dropped out of the closure. Groundwork
for the Nolan emitters + `gen_spruce_sema.py` (OPS-392).

**Why:** the dev-spruce layout gen must emit the modern shapes from its
first artifact; the snapshot is the gen's type contract, so it moves first.

---
