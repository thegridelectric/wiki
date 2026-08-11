# Changelog

A reverse-chronological log of WHY we made each commit **in the
`tlayouts` code repo**. The matching git commit (in `tlayouts`) holds
the WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-08-11 — Spruce window variant artifact + async-delta knobs (`94369b3`)

**What:** on `jm/spruce`. `NolanSemaGenConfig` gains
`thermistor_temp_async_delta` (default 50) and
`thermistor_microvolts_async_delta` (default 5000) — the buried
zone-thermistor async-capture deltas lifted to visible, overridable
config values; the spruce gen grows an `emit(config, out_dir,
reference)` split (the honeysuckle shape) and emits a second artifact
pair to `output/spruce-async1/` with both deltas at 1, same identity
and id reference as the primary.

**Why:** the ads-declared-rate spruce window needs every 1 Hz zone
sample published to the broker for noise-floor evidence; at the
operating deltas (50 c°C / 5000 µV) the measured noise floor
(sd ≈ 214–450 µV) never trips async capture, so almost no per-sample
data would leave the box. The window variant makes the capture path
publish each sample; the primary artifact keeps operating tuning.

## 2026-08-10 — Honeysuckle 16 SPS / 2 Hz variant artifact + poll-period knob (`312f558`)

**What:** on `jm/spruce`. `NolanSemaGenConfig` gains
`thermistor_poll_period_ms` (default 1000 — the buried constant lifted
to a visible, overridable config value); the honeysuckle gen emits a
second artifact pair to `output/honeysuckle-16sps-2hz/`
(`thermistor_data_rate_sps=16`, 500 ms zone-thermistor polling) from
the same minted identity and id reference as the primary, so only the
pairing differs.

**Why:** the bench experiment runs both pairings — the settled
8 SPS @ 1 Hz and the 16 SPS @ 2 Hz fallback — to anchor the stashed
sweep-fits-poll axiom's constants at both operating points; each
pairing needs its own bootable artifact.

## 2026-08-10 — Hardware-words snapshot + declared data rate + spruce pico removal (`65cbd4d`)

**What:** on `jm/spruce`. (1) Sema snapshot rebuilt from sema
`jm/hardware-words` (`1d02655`) — the board record now carries Muxes /
DAC mux placement / `SupportedDataRatesSps`, and
`i2c.dac.writer.component.gt` is added to the seed's explicit targets
(no layout references it yet, same reasoning as the relay words).
(2) `NolanSemaGenConfig` gains `thermistor_data_rate_sps` (no default;
the gen refuses to write a layout unless it is declared and a member of
the board ADC's menu); spruce + honeysuckle declare 8. (3) Minted
GNodes move to published `g.node.gt/006` (axiom 2 relaxation only —
the 005 instances are valid unchanged). (4) Mirroring actual-spruce
`a71617e`: the fancoil, floor1, and pipes1 pico tank modules commented
out of `spruce_sema_gen.py` (physically disconnected 2026-08-10,
pico-gaps experiment — restore when reinstalled) along with the seven
identity deriveds on their device channels. Both outputs regenerated
and validated through the snapshot (spruce: 66 nodes / 16 components /
48 channels; honeysuckle: 41 / 11).

**Why:** the layout artifacts the ADS-at-declared-rate experiment
boots must say what the box really is: which chips exist (three DACs
behind the mux, not one), what the reader runs at (8 SPS declared, not
an adafruit default), and which picos are physically present — a
layout declaring disconnected picos reads as dropouts, tangling the
very gap statistics the pico experiment measures.

---

## 2026-08-10 — Temporarily remove 3 wifi picos from spruce (`a71617e`, actual-spruce)

**What:** on `actual-spruce`, `gen_spruce.py`'s fancoil, pipes1, and
floor1 `add_tank3` blocks (pipes1/floor1 in both registrations — the
pair is duplicated in the file) and the five pipes1/floor1-sourced rows
in `add_spruce_identity_derived_channels` commented out; `spruce.json`
regenerated without them.

**Why:** all three picos physically disconnected at the 2026-08-10 field
visit (scada pico-cycler confirmed flatlined → zombie); the layout should
stop declaring hardware that is not there — the cycler chases the ghosts
by power-cycling the shared 5V pico rail every ~65s, rebooting the
healthy picos too. Temporary — restore when the picos are reinstalled.

---

## 2026-08-05 — remove floor2 from the jm/spruce sems gen (`5f3a61e`, jm/spruce)

**What:** the floor2 removal mirrored onto `jm/spruce`: the
`ExtraTankSpec("floor2", "pico_43a532")` dropped from
`spruce_sema_gen.py`, and the same `add_tank3` block (plus the stale
`# pico_43a532 = floor2` comment) dropped from that branch's
`gen_spruce.py`.

**Why:** same reason as `20e747e` below — floor2 is long gone; keeping
it in the sema-gen line would carry the dead pico into the next sema
snapshot and re-diverge the branches.

## 2026-08-05 — remove the long-gone floor2 pico from spruce (`20e747e`, actual-spruce)

**What:** the floor2 `add_tank3` block (`pico_43a532`) dropped from
`gen_spruce.py`; `spruce.json` regenerated (−184 lines).

**Why:** floor2 is a permanent zombie — it never reports and never
revives, which kept the PicoCycler's half-hourly zombie-shake VDC
power-cycles running forever, and each shake sent the slow-rejoining
secondary pico through its ~13–14 min wifi rejoin, logging a dropout
per shake (~19/day). Removing the dead pico from the layout is the
discriminator for that feedback-loop diagnosis
(`experiments/2026-08-03-pico-gap-analysis/`): with no zombie in the
roster the shakes should stop and spruce's dropouts collapse.
Deployed to spruce and scada restarted 19:18 ET.

## 2026-08-03 — Updated sema snapshot (`c0e2b69`, jm/spruce)

The whole dev-spruce line, squashed to one commit (author-dated 2026-07-23
from its first piece) and merged to `jm/spruce`: the snapshot rebuild, the
Nolan/spruce/honeysuckle sema gens, the i2c-bus node, and the spruce
channel additions below. This entry carries the newest pieces; the three
entries that follow describe the line's earlier pieces and are stamped
into this same commit.

**What:** `spruce_sema_gen.py` mirrors the deployed
gen's additions (`803a105` + `daec917`): three new eGauge power
channels — `hp-odu-pwr` @ 9014 (nameplate 4300 W, async delta 20, in
power metering) and `economy-energy-l1-pwr` @ 9016 /
`economy-energy-l2-pwr` @ 9018 (4500 W, delta 200, NOT in power metering
— the panel mains sit in front of hp-odu; counting both double-counts
the transactive sum) — the eGauge `HwUid` `BP04165` (verified over
modbus T16 register 100, the same register the scada driver reads), and
the tank1 pico swap (`pico_415b2a` → `pico_9a7935`, field replacement).
eGauge modbus addresses follow the device's register order, not the
register-name numbering.

`house0_sema_gen.py` gains `ensure_power_about_node`: the power-meter
emitters (egauge spec loop AND the sim meter's role nodes) create a
channel's about-node only when no other emitter has, and adopt it
otherwise — setting `NameplatePowerW` when the spec brings one, raising
on conflicting nameplates. Power metering now composes with emitters
that already declare the node (a hydronic hp-odu is metered AND plumbed).
Cosmetic fallout: honeysuckle's hp-odu/hp-idu node DisplayNames become
uniform title-case ("Hp Odu"). Both gens regenerate green — spruce at 82
nodes / 72 channels, honeysuckle unchanged at 41.

Dict-form sweep across the gens: sema-typed dict crossings use the
runtime's canonical `to_dict()`/`from_dict()` (PascalCase-enforced,
validated) instead of hand-rolled `model_dump`/`model_validate`/
`model_copy` — the four gen mains, the minted-GNode decodes, and the
sema-side of the two gwsproto device-type crossings (the gwsproto source
keeps `model_dump(by_alias=...)`; it has no `to_dict`). Spruce and
honeysuckle artifacts byte-identical before/after.

**Why:** the two spruce gens describe the same house; the sema-native
artifact must carry the HP power channel so the unlimbo line has the
behavioral observable (commanded-vs-actual, summer-local-control design)
from its first deploy.

---

## 2026-08-03 — remove l1/l2 from in_power-metering (`daec917`, branch actual-spruce)

**What:** `gen_spruce.py`: `InPowerMetering` False
on `economy-energy-l1`/`l2`; `spruce.json` regenerated.

**Why:** the l1/l2 registers meter the panel MAINS, which sit in front of
hp-odu (and the elts) — with them True the metered set counts those loads
twice. Redeploy to the spruce pi + scada restart required to take effect.

---

## 2026-08-03 — add odu power to spruce (`803a105`, branch actual-spruce)

**What:** `gen_spruce.py` (actual-spruce branch) adds three eGauge
channels — `hp-odu` @ 9014 (NameplatePowerW 4300, the ODU circuit rating;
AsyncCaptureDelta 20), `economy-energy-l1` @ 9016 and `economy-energy-l2`
@ 9018 (4500 W, delta 200), all `InPowerMetering` — fills the eGauge
`HwUid` (`BP04165`, read from the device's `status.xml` and verified over
modbus register 100; was the `"GET THIS"` placeholder), and carries the
tank1 pico swap (`pico_415b2a` → `pico_9a7935`, a field replacement).
`spruce.json` regenerated idempotently on the spruce pi with
actual-spruce-era code (the gen's `layout_gen`/`MakeModel` machinery is
retired on `jm/spruce-unlimbo`); existing IDs stable. eGauge modbus
addresses follow the device's register order — the register-name
numbering (`09-hp-odu`) does NOT map to the address.

**Why:** the eGauge lines crossed the garage roof and the heat pump's
outdoor unit is now directly metered (GRI-11, 2026-07-30) — the
behavioral observable the summer-local-control design's
commanded-vs-actual glitches need, and the first direct HP power channel
in the spruce layout — plus the economy-panel leg registers.

---

## 2026-07-29 — Nolan gen authors the i2c-bus node (in `c0e2b69`)

**What:** `src/tlayouts/nolan_sema_gen.py` (jm/dev-spruce branch) emits an
`i2c-bus` ShNode (ActorClass `I2cBus`, under `s`) in `emit_board`;
honeysuckle artifacts regenerated with it (41 nodes).

**Why:** the scada's single-bus-owner build — the reader resolves its bus
actor from the layout by ActorClass, so the layout must declare the bus
node; registration and layout landed together (scada `bab6a4a0`/`09e0f917`,
spruce-relay-control spoke).

---

## 2026-07-15 — Add some CTs for spruce ... just notes re gw108 CT1 and CT2 for now (`9e1ecc6`)

**What:** comment-only notes (actual-spruce branch): `gen_spruce.py` gets
the gw108 CT facts (CT1 current-type 100 A → 50 mA, store pump; CT2
eGauge-type 20 A, secondary pump); `gen_maple.py` gets the direction note
for the unwired primary-pump relays (relays become optional per home,
present ⇔ physically wired, with the hp-record cross-consistency axiom —
[OPS-450](https://linear.app/gridworks/issue/OPS-450)).

**Why:** capture field facts where the next layout sweep will use them.
(Older actual-spruce commits predate this domain changelog.)

---

## 2026-07-28 — spruce sema gen added (in `c0e2b69`)

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

## 2026-07-27 — Board-resident model (in `c0e2b69`)

**What:** sema snapshot rebuilt against the merged `jm/single-bus-owner`
line: `NolanLayout` rides `spaceheat.node.gt/303` + `data.channel.gt/003`,
and its components union is the board-generic `gpio.relay.component.gt` /
`gpio.sensor.component.gt` (GpioName against the board's native-pin
registry) — the gw108-prefixed words dropped out of the closure. Groundwork
for the Nolan emitters + `gen_spruce_sema.py` (OPS-392).

**Why:** the dev-spruce layout gen must emit the modern shapes from its
first artifact; the snapshot is the gen's type contract, so it moves first.

---
