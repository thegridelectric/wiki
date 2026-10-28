# Changelog

A reverse-chronological log of WHY we made each commit **in the
`tlayouts` code repo**. The matching git commit (in `tlayouts`) holds
the WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-10-28 — beech gen spells names from gwsproto; the pair is gw.house0.layout.json <!-- pending commit --> (jm/beech-main, OPS-628)

Beech's generator takes elm's shape: names and enum values from
gwsproto and the snapshot, zones composed from one list, the pair
written as `gw.house0.layout.json` and `gw.house0.operational.params.json`
(the names `roll.sh` looks for on `main`). The sieg loop stays on
HoldFullSend. The sieg-btu pico records MicroPython 1.26.1 from the
2026-10-25 census; every other field of the pair is unchanged.
`zone<N>-<zone>-gw-temp` and `sieg-btu` keep literal names: gwsproto
has no member for either yet.

## 2026-10-27 — tweaking elm's settings (`1a2a44f`, main, OPS-628)

First Arctic run under scada command (20:28 ET, from Admin). The
secondary pump drew 10 to 13 W on register 9002 while `secondary-flow`
read 5.3 to 5.9 gpm, so the 20 W `ThresholdW` on `secondary-pump-running`
never saw the pump answer; 5 W fits the signal the meter shows. The
compressor sat at a reported 2126 W for the whole run because the 300 W
capture delta hides everything inside that band; 100 W shows the ramp.
The house-side pump's DAC default goes from 3.5 V to 4.0 V for more flow
through the exchanger.

## 2026-10-27 — elm gen spells names and enum values from gwsproto and the snapshot (`816451d`, main, OPS-628)

A name-by-name audit of elm's running (legacy) layout against the
no.sieg one, after the Krida address, found three more values that came
in with `472fee6` from oak's template and one that moved: the ADS open
voltage is 5.0 (oak's is 5.05); the oil-boiler and whitewire eGauge
capture deltas are 2 W; the hp-odu nameplate is 9660 W, the Arctic's
`hp_max_kw_el`; and the secondary pump's CT is on register 9002, the
one the primary pump's held, while `primary-pump-pwr` (disabled,
required by the word) keeps 9008, which stays in the eGauge table for
the CT that attaches later. Krida 7's thermistor-common relay stays out
(relay 2 does the job) and relay 12 is NormallyOpen as the hack relay.

The Krida address, in the same commit (`main` was squashed to
`816451d` before the push):
The first roll of elm onto the no.sieg layout with local control alive
(19:55 ET) could not write a zone relay: the layout put the second Krida
board at 0x23 and the board answers at 0x21, as the legacy layout the
house runs has it. The address came from `472fee6` (2026-09-17), when
oak, fir and elm were authored from one template and oak's second board
really is at 0x23. `elm_gen.py` names 0x21 and the pair is regenerated
with that one change. `fir_gen.py` has the same 0x23 against a legacy
0x21.

And the names pass, which the commit is titled for:
`elm_gen.py` had 27 dashed string literals where the vocabulary has a
name: node and channel names that exist on `HydronicSpaceheatNodeNames`
and `HydronicSpaceheatChannelNames`, the four zone whitewire channels
the zone name classes compose, `oil-boiler` (added to gwsproto in the
same wave), and enum values (`ServiceMode`, `SeasonalStorageMode`,
`StandbyPosture`, `ZoneEmitterType`, `ZoneSetpointSource`,
`ThermostatKind`, `PrimaryPumpOwner`, `RefrigerantCycle`,
`PrimaryFlowSource`) typed as strings. Each now reads the constant or
the snapshot enum; the zones, their stat device ids and whitewire
registers are three lists the names compose from. The gate was the
regenerated pair byte-identical to the committed one (md5 before and
after). The remaining literals are the g-node ids and the Hubitat
token. `test_elm_no_sieg.py` catches up with the committed gen: the
primary flow is measured on pico_5a5127 and `store-flow` is the
disabled node. The other House0 gens take the same pass later, each
under its own byte-identical check.
In the same commit, the four tank modules are PicoRaspberryWifi2040:
elm's buffer and three store-tank picos posted that board at the first
`jm/arctic` boot and the layout said Unknown, one warning glitch each.
The gen names the board and the pair is regenerated; the hall flow
picos post no board, so Unknown stays for them.

## 2026-10-27 — secondary_pump_hack_relay_idx: the relay 12 stand-in at elm and hazel (`797d52f`, jm/arctic, OPS-628)

**Why.** The no.sieg word requires `secondary-pump-hack-relay` under
hp-boss until elm's primary-pump failsafe contacts are wired out of the
secondary pump's feed. The House0 gen takes its Krida position as a
third no.sieg axis beside the pump relay's, checked with the other two,
and emits it as a normally-open relay under hp-boss; elm and hazel sit
it on 12.


## 2026-10-27 — elm on gw.house0.no.sieg (`7e51e44`, jm/arctic, OPS-628)

**What:** `elm_gen.py` authors elm on the sieg-less word: hp-odu alone as
`ArcticMAHRW030ZA`, the unit owns the primary pump (the Krida 11/12
primary-pump relays and `primary-010v` leave), `secondary-pump-relay` on
Krida 11 under hp-boss, an hp-watch node, `secondary-pump-running` at
20 W over `secondary-pump-pwr` (eGauge register 9008, the one
`hp-idu-pwr` held). `secondary-flow` is the hall pico pico_3e9a28;
`secondary-lwt` and `secondary-ewt` are ADS terminals 3 and 4, disabled
until wired; `primary-flow`, `hp-lwt` and `hp-ewt` sit on `primary-btu`,
a disabled meter on a pico that does not exist; `primary-pump-pwr` keeps
register 9002, disabled. The DAC output on Dfr1 B that drives the
house-side pump is `secondary-010v`. The pair is written to
`output/elm/gw.house0.no.sieg.json` and its ops word, and `output/elm/`
is tracked.

**Why:** OPS-628 step 4. The word requires every channel of the hp side
and the secondary surface; elm measures the secondary flow and nothing
else there yet, so the unmeasured channels exist disabled where their
sensors will go (ADS for the secondary thermistors, a BTU for the hp
side) rather than as a second fake flow meter beside the real one.

## 2026-10-27 — elm: registry g-node ids, BufferOnly, the deed; hp-lwt and hp-ewt live on the ADS (`268a3cf`, jm/arctic, OPS-628)

**What:** `elm_gen.py` takes the three g-node ids (elm, elm.ta,
elm.scada) from the registry's records at gnr.electricity.works; the
authored ids did not match it. The ops word selects BufferOnly with
Standby off. `output/elm/ta-deed.json` is elm's hand-authored `ta.deed`
(ValidatedRealAssetAndGps, validator `hw1.validator.gridworks`, TaId the
registry's elm.ta id), validated with `sema validate`; the roll to
`main` needs it beside the layout on the first pi.
`elm_gen.py` keeps `hp-lwt` and `hp-ewt` on ADS terminals 3
and 4, enabled; `secondary-lwt` and `secondary-ewt` take terminals 9 and
10, disabled until wired. `primary-flow` sits on a hall pico that does
not exist (`pico_000002`), disabled with `primary-flow-hz`, in place of
the `primary-btu` placeholder. `elm.uploaded.json` is refreshed from the
pi, which now runs the legacy layout with `secondary-flow`. The elm test
checks the terminals and that neither hp channel is disabled.

**Why:** a deed binds only the layout's own terminal asset, so the
layout's ids must be the registry's; spruce's already are. BufferOnly
because elm's primary loop is suspected of a leak and a low-pressure
fault, so the stores stay out of the season's operation for now. The
two thermistors are wired and reading air, and are about to
go back on the unit's leaving and entering pipes, so the layout keeps
them live where the legacy layout has them. A BTU placeholder needs
three channels; with the thermistors on the ADS, the unmeasured primary
flow is a placeholder flow pico, as fir and oak author theirs.

## 2026-10-27 — legacy elm has correct secondary-flow (`b982150`, legacy, OPS-628)

**What:** `gen_elm.py` on legacy names pico_3e9a28's node `secondary-flow`
(the legacy `H0N` has no name for it, so the gen spells the string). The
node, its hall component and its two channels (`secondary-flow`,
`secondary-flow-hz`) take new ids; nothing else in the layout changes.
`output/elm/hardware-layout.json` is the committed record of the layout
elm runs on `legacy`, the first for elm, so `scripts/roll.sh elm to
legacy` can verify and install it.

**Why:** OPS-628. Elm's plate heat exchanger puts that pico on the house
side, where the secondary pump runs, so the name `primary-flow` would
report the wrong loop while elm waits on `legacy` for the `main` roll.
The rename on the pico itself is the starter-scripts
`ActorNameByHwUid` entry (`3a08dad`), applied by `pico_cycle_census.sh`
on the pi once this layout is on the box. The legacy scada's two readers
of `primary-flow` (`flowing_from_hp_to_house`, `primary_flow_gpm`) see a
missing channel and answer false or None, which only the sieg loop and
the dashboard's flow row use; neither matters at elm on `legacy`.

## 2026-10-27 — WIP house0.no.sieg (`1eaf9de`, jm/arctic, OPS-628)

**What:** the snapshot takes `gw.house0.no.sieg` 000 as sema `10faa2b`
has it (no `hp-idu` in axioms 7, 10, 11 and 31). `hazel_sim_gen.py`
drops its hp-idu part, the `hp-idu-pwr` meter channel and hp-idu from
the transactive about-nodes, so the pair has no hp-idu node; the
regenerated pair is copied to the scada fixtures. The House0 gen's
`hp_parts` message says hp-odu always, hp-idu on a split system.

**Why:** a home on the no.sieg word has a heat exchanger and one unit
beyond it, so the sim home that stands for elm has no indoor unit to
meter.

## 2026-10-26 — fix tank1 pico at elm (`68399a5`, legacy)

**What:** `gen_elm.py` on legacy: tank1's pico is `pico_1d2c34`
(was `pico_287d2b`).

**Why:** the tank module at elm was replaced; the legacy layout the
house runs names the pico that is actually on the tank.

## 2026-10-27 — hazel sim gen, house0 gen declares its word (`6784efb`, jm/arctic, OPS-628)

**What:** the tlayouts snapshot takes `gw.house0.no.sieg` 000 and the
Nolan word's command classes without SiegLoop; `hazel_sim_gen.py` is
the sieg-less House0 sim home (secondary pump on Krida 11, running
threshold 20 W). `House0SemaGenConfig` declares `word`
(`gw.house0.layout` or `gw.house0.no.sieg`) in place of a
`has_sieg_loop` flag; `has_sieg_loop` is a property read from the word,
and `HOUSE0_WORDS` maps the word to the sema type the gen builds. Every
House0 gen names its word; the eight outputs are unchanged. `elm_gen.py`
and `fir_gen.py` take their ids from the pi's running layout and then
their previous output, as beech and oak do. On the sieg-less word the
House0 gen emits an hp-watch node, since hp-boss runs the secondary pump
from hp-watch's sensed running state, and its ops artifact names
`gw.house0.no.sieg.family.params` (KeepBufferFull, SeasonalStorageMode):
`sieg_loop_strategy` is None on a sieg-less home and a strategy on a
`gw.house0.layout` home, and the gen refuses the other pairing. The
snapshot takes the family word, the ops word's third branch and the
no.sieg word's HpWatchNode axiom. The hazel pair is regenerated and
copied to the scada fixtures.

**Why:** whether a plant has a Siegenthaler loop is a fact of its
layout word, so a home declares the word and nothing else. Fir and oak
(and elm until its Arctic layout) stay on `gw.house0.layout` with the
sieg surface disabled: the loop is in the word, and the house has not
built it yet. Elm and fir had no id reference at all, so every node,
channel and component id was minted fresh on each run: two runs of the
same gen disagreed on every id, and a layout rolled to the box would
have broken every reading's continuity with the next roll.

## 2026-10-25 — beech: 4 BTU picos replace the primary BTU and the hall flows (`ce1926d`, legacy)

**What:** the same pico swap as the `jm/spruce` entry below, in main's
`gen_beech.py` and `output/beech/hardware-layout.json`: primary-btu
`pico_286e35`, dist-btu `pico_328036` (dist-flow, dist-swt, dist-rwt),
store-btu `pico_9c7736` (store-flow, store-hot-pipe, store-cold-pipe),
sieg-btu `pico_579030` (sieg-flow, sieg-hot, sieg-cold). Out: the old
primary-btu pico, the three hall flow picos and their `-hz` channels,
the `Pico Flow Hall` cac, the two ADS store-pipe terminals, and the
commented-out dist and sieg tank-module blocks. The gen takes its ids
from the committed `output/beech/hardware-layout.json` (the maple
pattern) instead of the pi's live layout, which is now a `jm/spruce`
sema layout and no id reference for main. Main's BTU component word has
no board or MicroPython fields, so those facts live only on `jm/spruce`.

**Why:** beech rolls back to main by `scripts/roll.sh beech back`, which
verifies the box against this file; the layout the box would fall back
to must name the picos that are in the house. Every kept node,
component, channel and GNode keeps its id.

## 2026-10-25 — new btu picos at beech (`a3630bd`)

**What:** `beech_gen.py` declares four pico BTU meters, one per loop:
primary-btu `pico_286e35` (primary-flow, hp-lwt, hp-ewt), dist-btu
`pico_328036` (dist-flow, dist-swt, dist-rwt), store-btu `pico_9c7736`
(store-flow, store-hot-pipe, store-cold-pipe) and sieg-btu `pico_579030`
(sieg-flow, sieg-hot, sieg-cold), the first three Pico W boards on
MicroPython 1.23.0 and the sieg meter the one Wiznet. Out of the layout:
the old primary-btu `pico_7a4d2b`, the three hall flow picos, the dist
and sieg pipe-thermistor tank modules with their identity deriveds and
disabled lists, and the two ADS store-pipe channels the store meter now
reads. `BtuSpec` gains an optional `micropython`, emitted as the word's
`MicropythonVersion`; `tests/test_btu_micropython_version.py`.

**Why:** the picos were swapped on site 2026-10-25 and beech moves to
`jm/spruce-unlimbo`, whose roll verifies the box against this branch's
committed JSON. Every kept node, component and channel keeps its id; the
four pipe temperatures that were deriveds become data channels with
fresh ids.

## 2026-10-22 — a data channel's id follows its telemetry; fir and elm take oak's fake sieg (`a701eb8`, OPS-392)

**What:** `LayoutIDMap` records each data channel's `TelemetryName` beside
its id and hands the id out only for a channel of the same telemetry
(`channel_id_for`); `LayoutGen.channel_id` takes the telemetry and every
emitter passes it. `tests/test_channel_id_stability.py`. Every gen
that builds is rerun: spruce and spruce-async1 (23 channels each),
beech (23), maple (28) and oak (27) get fresh ids for the channels
whose telemetry differs from the pi's layout, all of them temperatures
now in `CelsiusTimes100` that the pi reports as `WaterTempCTimes1000`,
`AirTempFTimes1000` or `AirTempCTimes1000`; nothing else in those files
changes. spruce-sim picks up `secondary-pump-ct` in
`DisabledChannelNames`, which the gen already said. The fir and elm gens
take oak's fake-sieg pattern: a `sieg-btu` BTU meter on a pico that does
not exist (`pico_000001` fir, `pico_000002` elm; oak keeps
`pico_000000`), the meter node and its `sieg-flow`, `sieg-hot`,
`sieg-cold` and `sieg-send-flow` channels disabled, in place of the
pretend ADS `sieg-cold` channel and `sieg` flow meter that failed axiom 8
(`SiegManifoldChannels`, no `sieg-hot`). Their outputs stay fixtures
(gitignored, ids minted each run).

**Why:** the id lookup keyed on the name alone, so a channel whose
telemetry changed kept the id of the channel it replaced, and a reader
joining readings by id across the two layouts would mix values in
different units under one identity. A channel with new telemetry is a
new channel. Derived channels still key on name alone; an output-unit
change there has the same shape and is not handled yet.

## 2026-10-22 — oak: eGauge pump and white-wire channels report on a 1 W change (`4209a3a`, OPS-392)

**What:** `gen_oak.py` sets `AsyncCaptureDelta=1` on the eight
non-metering eGauge channels (the three pumps, the oil boiler, the four
zone white wires); `output/oak/hardware-layout.json` regenerated.

**Why:** oak2 has run these channels at 1 W since its file was last
placed, and the gen's default of 2 W is what the committed record said.
The box's value is the one wanted, so the record moves to it; the
regenerated file's sensed part matches oak2's file exactly, and the
primary oak pi's file now differs from the record by these eight values
until it is rolled.

## 2026-10-22 — spruce: disable secondary-pump-ct (`786dfed`, OPS-392)

**Why.** The secondary-btu pico's CT channel posts a constant (168, 1.67 V)
whatever the secondary pump draws, seen again in the 2026-10-21 window,
and the scada has no reader for the signal yet. Disabled in the spruce
roster until one exists; the channel stays declared. Both spruce outputs
regenerated.

## 2026-10-22 — main: commit the layouts the House0 boxes run (`4a113cf`, OPS-392)

**What:** `output/<house>/hardware-layout.json` for beech, maple, oak and
fir; `.gitignore` admits those folders (and elm's, whose box was
unreachable on 2026-10-22). Beech, oak and fir are the files their gens
emit and are byte-identical to the files on the boxes. Maple is its
gen's output and is ahead of the box by the sieg loop's
`hp-keep-seconds-x-10` derived channel and the `Strategy` and
`SynthChannels` keys; `gen_maple.py` reads its ids from this committed
file so a re-run is byte-identical. `main` held no JSON before this.

**Why:** `main` is the roll-back line for every House0 box while
`jm/spruce-unlimbo` runs under the service. A roll back verifies the
box's layout against the committed JSON of the matching tlayouts
branch, so the branch has to hold what the boxes run, and a gen and its
JSON are one authority only if the gen reproduces the file. Maple's gen
needs the scada `main` fix of the same date to run.

## 2026-10-22 — actual-spruce: spruce's layout under its output folder (`17279a6`, OPS-392)

**What:** `spruce.json` moves to `output/spruce/hardware-layout.json`
(it is byte-identical to the file on the box); `.gitignore` admits the
folder.

**Why:** the roll script reads every branch's record at
`output/<house>/`; `actual-spruce` is spruce's roll-back line.

## 2026-10-21 — secondary pump reports to HpBoss (`edaad57`, OPS-392)

**What:** `nolan_sema_gen.py` gives `secondary-pump-relay` the handle
`auto.hp-boss.secondary-pump-relay`, as the call relay has; the sema
snapshot regenerated for `gw.nolan.layout` axiom 30; the spruce pairs
regenerated.

**Why:** hp-boss owns the secondary pump (gridworks-scada changelog,
same date): a plant with a heat exchanger runs its pump whenever the
heat pump runs, whoever holds the tree.

## 2026-10-21 — fix the three flow pico types (`1bdc455`, OPS-392)

**Why.** Oak's two beta windows on 2026-10-20 never heard its three flow
picos (`pico_436531`, `pico_836d31`, `pico_974532`): missing from the
first poll, flatlined, Zombie after five 5 V cycles, while `main`
journals all six flow channels. The picos are EKM pulse meters on reed
picos, as the uploaded layout says, but the oak gen's three `FlowSpec`
lines gave no `kind`, and `kind` defaults to hall. The branch layout
therefore declared hall picos, the actor registered only the hall
routes, and the reed posts got a silent 404. With `kind="reed"` the
regenerated components match the uploaded layout on every tuning value;
only the three components change. The `FlowSpec` docstring drops its
`dist2` example: that meter left beech some time ago and no gen names
it.

## 2026-10-20 — oak gen: registry GNode ids, Wiznet tank picos (`91f902dd`)

**Why.** Oak's first beta window (2026-10-20) raised two warning
glitches at boot. `ta-deed-wrong-asset`: the gen authored three GNode
ids that are in no registry; gnr.electricity.works has the TA as
`0a39d45d…`, the LTN as `b759f5bb…` and the scada as `fbbea6a1…`, which
the deed on the box already names, so the gen takes the registry's ids
(the other three houses' gens already match the registry). Four
`PicoBoardVariant differs from the layout` glitches: the oak tank picos
are Wiznet on Gw100 boards (`gridworks-infra/pico-fleet-firmware.md`),
so the gen says `PicoWiznetEth2040` for them as beech's does.

## 2026-10-19 — component ids now fixed, oak has a fake sieg BTU (`59ce33d`, OPS-392)

**A component id minted in a run is minted once.** `component_id` returned a fresh uuid for a key absent from the
reference and the previous output, and did not remember it. A Honeywell
thermostat is looked up twice, for its node's component and for its
zone circuit's `Thermostat.ComponentId`, so with no reference the two
differed and the layout failed `ReadThermostatChannels`. Every House0
house with Honeywells (beech, maple, oak, fir, elm) did this; beech and
maple built only because their reference already had the thermostat
ids. A minted id now goes into the gen's id map, the one place lookups
read, so a run keeps one id map. The board's
"never call it twice" workaround comment goes with it. The test builds
beech with no reference and checks each circuit's thermostat against
its stat node; it failed before the change. Beech, maple, spruce and the
sim pairs regenerate byte-identically after it.

**Oak is a House0 home with a fake sieg BTU meter and takes its ids from its pi.** Oak has no siegenthaler loop, and its gen failed the House0
`SiegManifoldChannels` axiom (no `sieg-hot`), so it could not produce a
layout for a beta window. One disabled sieg BTU meter (`sieg-btu`, pico
`pico_000000`, which does not exist) now supplies `sieg-flow`, `sieg-hot`
and `sieg-cold`; it replaces the pretend sieg flow pico and the pretend
`sieg-cold` thermistor. The meter node is in `DisabledNodeNames`, so the
scada neither watches its pico nor cycles picos for its absence; the
pretend flow pico it replaces was enabled, and a window would have done
both. The four sieg channels are disabled, `sieg-send-flow` included
because `EnabledDerivedChannelsHaveLiveInputs` rejects an enabled derived
channel on a disabled input. The sieg loop runs on relays 14 and 15,
which nothing at oak is wired to. Ids come from the oak pi's running
layout, then the gen's previous output, as at beech and maple, so a
regen gives the same bytes. All four zones are `FromThermostat`, as
`181df2d` set them; the old output from 09-20 predated that.

**The record is committed.** `output/` was gitignored, so no deployed layout was in git and an
id minted for a name the pi lacks lived only on one laptop and the box it
was put to; a gen run from a fresh clone minted it again. `.gitignore`
now ignores `output/*` and names the folders that are the record: beech,
maple, oak, spruce, spruce-async1 and the three sim pairs, each checked by
regenerating and comparing bytes before the commit. Each house folder
includes its `<house>.uploaded.json`, the last fetched pi layout, which is
the id reference a gen falls back to when the pi cannot be reached. Elm
and fir stay out: their gens fail the House0 sieg axiom, so their output
is stale and would not match its gen. Two strays that no gen writes were
deleted (a house0 ops file in `spruce-async1/`, a 2024 `Users/...` copy
that the unanchored `output` pattern had hidden). This is step 1 of the
interim record (OPS-392, toward OPS-471); the drift test is next.

## 2026-10-18 — Every house gen names the moose weather bundle (`d42da29`, OPS-597)

**Why.** The weather service abandoned the
`us.me.millinocket.forecast.nws.hourly96` bundle with its first word
versions; `us.me.millinocket.moose` is its successor on the new words
(96-hour NWS temperature and wind), and the scada's weather source now
reads only those words. The ops word's `WeatherBundleName` is the one
place a house says which bundle it pulls.

## 2026-10-17 — temporarily take oak living room out of critical zone (`354c21c`)

The living-room thermostat at oak is being held off (no heat call on its
white wire) with the zone well under setpoint. A critical zone judged cold
is what lets the cold latch bring in the oil boiler, so the living room
comes off `critical_zone_list` in `gen_oak.py`; gear-rm and upstairs
stay. The same edit was made by hand to the deployed
`hardware-layout.json` on oak and oak2 (dated `-pre-drop-living-rm-critical`
copies beside them), since `gen_oak.py` does not currently run against the
laptop's scada venv (`FlowManifoldVariant` is a `main`-only gwsproto enum).

## 2026-10-17 — make sure sema snapshots are published on main (OPS-473, `cade8d7`)

The test no longer looks the snapshot's words up in a sema checkout or a
registry index: the snapshot's own `definitions/registry.yaml` has the
status of every word and version it ships, so it reads that and nothing
outside the repo, and runs the same on a laptop and on GitHub (where a pull
request is judged by its target branch). The earlier form self-skipped on
GitHub, where no sema checkout exists.

## 2026-10-17 — make sure sema snapshots are published on main (OPS-473, `648eead`)

`tests/test_sema_snapshot_published.py` looks every word in the
snapshot's expanded seed up in the sema registry index
(`SEMA_PUBLIC_REGISTRY`, else the sibling checkout's
`indexes/public_registry.yaml`) and fails on `main` when one is not
published; off `main` it reports the words and skips, and with no
registry it skips. It reads the registry rather than the snapshot's own
staging marker, so a hand-built snapshot with no marker is caught, as
is a withdrawn word. It is the test gwbase has, with this repo's
snapshot path and release branch. On `main` it fails while the snapshot has
staging words (89 on `jm/spruce` today). PyYAML joins the dev group.

## 2026-10-16 — The snapshot regenerates onto sema 1c52df0: channel words at data.channel.gt 004 and derived.channel.gt 003 (`2cb606b`)

What: `scripts/regen_sema_snapshot.sh` off sema `1c52df0`; the gens
emit `data.channel.gt` 004 and `derived.channel.gt` 003 (enum
reference bumps only, no field changes). The beech pair is regenerated
and placed on both pis.

Why: the scada seed pins those versions since 2026-10-15, and a layout
at 003/002 fails its load (103 literal version errors). The 2026-10-16
beech window could not open until the pair matched.

## 2026-10-16 — beech in BufferOnly; accepts dispatch (`c3aa85d`)

What: `operator_hold` goes false in `BEECH_OPS`; the pair is
regenerated. BufferOnly and the rest of the ops word are unchanged.

Why: the beta windows now exercise the dispatch contract itself: an
LTN offer taken, then ended from admin (`InAdmin`) and by the cold
watch. Held out of dispatch, every offer is refused with `OperatorHold`
before any of that can run.

## 2026-10-14 — Beech disables dist-depth3-device (`0e01a2c`)

What: `dist-depth3-device` joins beech's `disabled_channel_names`; the
pair is regenerated. The `micro-v` channel stays, so the fault remains
visible.

Why: the thermistor is open. The 2026-10-14 beech window read 3.3 V,
the pico rail, on it (`open-thermistor` glitch), so its temperature is
not a reading. Nothing derives from it.

## 2026-10-14 — Beech out of Standby, BufferOnly, held out of dispatch (`115027e`)

What: `beech_gen.py` sets `standby=False` and
`seasonal_storage_mode="BufferOnly"`; `operator_hold=True` stays, so
the ops word's `DispatchHold` keeps the house out of dispatch and the
LTN sees `OperatorHold`. The pair is regenerated.

Why: the first beta window where branch code runs beech's heat. No
LTN runs FLOs yet, so the hold stays on every house gen for now.

## 2026-10-14 — The energy channels are House0's; snapshot on sema 275bb41 (`63a1bfc`)

What: `usable-energy` and `required-energy` move out of the shared
derived-channel emitter into the House0 gen (`emit_energy_channels`), so
a Nolan layout emits neither. The sema snapshot is regenerated on sema
`275bb41` (`gw.nolan.layout` without SystemModelEnergyChannels); the
spruce sim pair is regenerated and the scada's Nolan fixture is copied
from it.

Why: the layered energy models are House0's, so a Nolan layout
declaring their channels promised a value nothing sends.

Also in this commit: ops params say DispatchHold; snapshot on sema
550b57a; beech holds full send.
The ops word no longer states `AcceptsDispatch` and a reason, which were
a copy of a derived answer; it states the hold the file places on
dispatch, `DispatchHold` (`gw.dispatch.hold`: `OperatorHold`,
`ServiceContractBroken`). `layout_gen.py` builds it through the
snapshot's `DispatchHold` class from two `OpsSpec` booleans. Beech
(Standby) and spruce (its Nolan ally is not built, so the operator holds
it out) say `operator_hold=True`; every other house and the sim gens,
spruce-sim included, say both false. `NoAggregator` is gone with the
enum value. Beech's gen said `StratProtect` with Standby true; axiom 5
on the ops word (Standby with a House0 family requires
`SiegLoopStrategy` `HoldFullSend`) fails that pair at generation, so
beech names `HoldFullSend`, as maple does, until the StratProtect
test-drives begin. Snapshot regenerated on sema `550b57a`
(`gw.dispatch.hold`; the refusal enum leaves the snapshot, since no
layout word references it now). Outputs regenerated for beech, maple,
spruce, spruce-async1, spruce-sim, orange-sim and willow-sim; elm, fir
and oak still fail the House0 layout's `SiegManifoldChannels` axiom
(`sieg-hot` missing), unchanged by this wave.

## 2026-10-10 — gwsproto OperationalParams mirrors axiom 6: Standby holds a House0 loop at full send (OPS-392, `82620c5`)

Snapshot regenerated on sema `b1d5c70`: the vendored
`gw.operational.params` 000 carries axiom 6 (Standby with a House0
family requires `SiegLoopStrategy` `HoldFullSend`) and its axiom
dependency on `sieg.loop.strategy`. The commit title is the scada
mirror's; the diff is the snapshot alone.

## 2026-10-10 — fix beech pico board variants (OPS-392)

The four beech TankSpec rows said `PicoWiznetEth2350`; the picos post
`PicoWiznetEth2040` (buffer, tank2, tank3) and `PicoRaspberryWifi2040`
(tank1), so every window boot on beech raised four Warning glitches
`<node> pico PicoBoardVariant differs from the layout`
(`experiments/2026-10-09-nolan-local-control-windows/` run 2). The rows
now name what each pico posted; the regenerated beech layout differs
only in those four fields.

## 2026-10-07 — Every house names the Millinocket 96-hour weather bundle (OPS-392)

`OpsSpec.weather_bundle_name` (required) carried into `WeatherBundleName`
on every generated ops word; each house generator sets
`us.me.millinocket.forecast.nws.hourly96`, the one bundle gwwf publishes.
The orange sim carries it too although the house is in New Haven; a
second bundle is a gwwf mint, not a generator change. Snapshot regenerated
against the sema commit that added the field.

## 2026-10-06 — Spruce's buffer elements are in service (OPS-392, `48a0818` on jm/spruce)

`spruce_gen.py` declares `buffer_element_backup(in_service=True)`: the
two buffer elements are wired, and the scada holds them off outside
`InBackup`. The ops word keeps `UsesBackupWhenCold` false, so spruce
does not go to them this winter.

## 2026-10-06 — Layouts declare their backup; every layout carries cold-override (OPS-392, `4778d3c` on jm/spruce)

The snapshot is regenerated from sema `6da94a4`. `LayoutGenConfig`
gains a required `backup` (a `BoilerBackup`, an `ElementBackup`, or
None), so every house declares the backup it has rather than inheriting
one; `house0_sema_gen.boiler_backup` and
`nolan_sema_gen.buffer_element_backup` name each family's relays. The
family gens put it in `Hydronic.Backup`, emit the `backup` node only
when there is one, and always emit `cold-override`. The ops flag is
`uses_backup_when_cold`. The House0 houses declare an in-service boiler
and go to it when cold, as they did; spruce declares its two buffer
elements, not in service, and does not use backup. The elm, fir and oak
gens are edited to the new config but not run: they fail House0 axiom 8
(`sieg-hot`) on the clean tree too, and their layouts change next.

## 2026-10-06 — The snapshot carries InBackup (OPS-392, `54af504` on jm/spruce)

The snapshot is regenerated from sema `2be3031`, where
`gw2.lc.top.state` 000 (staging, edited in place) replaces
`UsingNonElectricBackup` with `InBackup`; the two layout words' prose
for the `backup` node follows. `LcTopState` changes; no generated
layout does.

## 2026-10-06 — Every layout carries the standby command node (OPS-392, `b38b980` on jm/spruce)

The snapshot is regenerated from sema `8c1feec`, whose layout words
require a `standby` command node at `auto.lc.standby`, and both
generators emit it beside `n`, `backup` and `scada-blind`. A layout
without the node fails both words' `CommandNodesExistenceAndActorClass`,
so every house's layout is regenerated before its next scada start on
`jm/spruce-unlimbo`.

## 2026-10-06 — Nolan layouts carry the hp-watch actor; the snapshot seeds gw2.lc.top.state (OPS-392, jm/spruce)

The snapshot is regenerated from sema `9ad04ab`, which renames the
`HpSensor` actor class to `HpWatch` and its node to `hp-watch`; the Nolan
generator emits the node under the new name and class. The seed adds
`gw2.lc.top.state`, which no layout word references, so that the
registry the scada vendors carries it and its gwsproto twin is checked.
`gw2` joins the stripped prefixes, giving the local class `LcTopState`.

## 2026-10-05 — Layouts carry the water store as its own word (OPS-392, jm/spruce)

The snapshot is regenerated from sema `2a222f6`, which adds
`gw.water.store` 000. The House0 and Nolan generators emit
`Hydronic.WaterStore` with the house's tank count in place of
`Hydronic.TotalStoreTanks`. **Why:** a house's store is not always water
tanks. One of the fall layouts stores heat in a cement slab under the
floor, and it has no tanks to count. The tank count now belongs to a word
that a layout includes only when its store is water tanks. Beech, maple,
spruce and the three sim pairs regenerate. Elm, fir and oak still fail
their axiom 8 check (`SiegManifoldChannels`) until `gw.house0.no.sieg`
exists.
`LayoutIdMap` no longer parses `TotalStoreTanks`. Nothing read it, and
the store's tank count comes from the generator config.

## 2026-10-05 — Circuits carry their temperature and setpoint, zones name a primary circuit, every layout has a cold-watch node (OPS-392, jm/spruce)

`beech_gen.py`, `maple_gen.py`, `elm_gen.py`, `oak_gen.py` and
`fir_gen.py` declare `SetpointSource` `FromThermostat` on every zone
circuit. **Why:** each circuit said
`Learned` beside a `HoneywellViaHubitat` thermostat whose `-set` channel
the hub poller reports. The scada's cold judgment branches on
`SetpointSource`: a `Learned` zone is cold only while it calls, against
a recorded setpoint, and a `FromThermostat` zone is judged against the
thermostat's own report with the on-peak-start protection. Left as
`Learned`, a House0 house whose thermostat was raised during on-peak
would read as cold. The two sim gens (willow, orange) keep `Learned`:
their thermostats are `MechanicalDial`, which the circuit word's axiom 2
does not allow beside `FromThermostat`.

The vendored snapshot is regenerated from sema `ec35d40`, which moves
temperature and setpoint channels onto circuits and has each zone name
a primary circuit. **Why:** the generators author against the snapshot,
so it comes first; they do not validate until they author the new
fields.

The generators author the new fields. Both families emit the
`cold-watch` node (`ColdWatch`, `s.cold-watch`, no handle). A House0
circuit is named after its zone, is the zone's primary, and names the
thermostat's own `zoneN-…-temp` and `-set` channels; the choice of the
ADS `gw-temp` channel for a zone's temperature is gone, so beech and
maple are judged on the Honeywell's reading. A Nolan circuit's place in
`zone_call_circuits` is its `CircuitPosition`: `ZoneCallCircuitSpec`
drops `position`, carries `opto_idx` (the gw108 terminal, used for the
whitewire input and the relay pair) and `primary` (required on one
circuit of a zone that has several), and
`thermistor_circuit_positions` replaces `thermistor_zone_idxs`. A
thermistor circuit carries its `gw-temp` channel and a derived setpoint;
spruce's fancoil circuit carries neither and the living room's primary
is circuit 2. A `Learned` setpoint is a `simple-falling-edge-setpoint`
derived channel in every family through one shared helper, so the
House0 sim sensor no longer carries a `-set` channel. The generators
refuse a circuit named after a zone it does not serve, and a Honeywell
circuit declared `Learned`. **Why:** the layout words now require
these fields, and the setpoint and temperature belong to a thermostat
rather than a zone. Regenerated: spruce, its async1 variant, spruce-sim,
willow-sim, orange-sim, beech and maple. Elm, oak and fir still stop at
layout axiom 8 (`sieg-hot`) before writing an output, as before this
change.

## 2026-10-04 — Nolan layouts carry the hp-sensor actor; honeysuckle gen commented out (OPS-392, `80e7cbb` on jm/spruce)

The Nolan builder's `hp-sensor` becomes an `HpSensor` actor
(`s.hp-sensor`, no Handle), and the vendored snapshot takes sema's
`gw1.actor.class` 014 `HpSensor` and the matching axiom 32, by hand
edits that mirror the sema change file for file. `honeysuckle_gen.py` is
commented out under a note that honeysuckle is going to be a new scada
for the Stoneman microgrid. **Why:** the actor that runs the heat-pump
threshold machine is the node the machine reports under. Honeysuckle
fails `gw.nolan.layout` axiom 8 (RequiredSensing) and will not carry a
Nolan layout.

## 2026-10-04 — Nolan layouts carry hp-sensor; snapshot follows gw.nolan.layout axiom 32 (OPS-392, `d8da83c` on jm/spruce)

The Nolan builder emits a `NoActor` ShNode `hp-sensor` with no Handle,
and the snapshot regenerates for `gw.nolan.layout` axiom 32
(HpSensorNode), ActuatorLeaves clause c on both layout words, and the
renamed `spruce.hack.hp.state` values; the spruce and spruce-sim
layouts regenerate. **Why:** the scada's heat-pump threshold machine
reports its sensed state under `hp-sensor`, kept apart from `hp-odu`,
and every Nolan layout must carry the node.

## 2026-10-04 — Seed the two Nolan state-machine enums into the snapshot (OPS-392, `65ead19` on jm/spruce)

The seed request lists the enums `gw1.nolan.lc.buffer.only.state` 000 and
`spruce.hack.hp.state` 000, and the vendored snapshot regenerates from
sema `6f7d5ea`. **Why:** the scada mirrors this snapshot's registry as its
sema closure, and the state-machine enums should reach consumers such as
JournalKeeper through the layout vocabulary. No layout names its state
machines yet, so dependency closure cannot reach them; they are seeded
directly as the first of them.

## 2026-10-04 — Nolan ops author SeasonalStorageMode BufferOnly (jm/spruce, `044d64f`)

`spruce_gen.py` and `honeysuckle_gen.py` author
`seasonal_storage_mode="BufferOnly"`. **Why:** the scada's loader has a
Nolan machine only for BufferOnly (`NolanBufferOnlyTou` for Heating,
`NolanBufferOnlyCoolingTou` for Cooling); a Nolan ops word authoring
AllTanks selects no machine and the scada raises at boot.

## 2026-10-02 — beech: sieg and dist tank modules commented out (`e75cd0f` on jm/beech-sieg-off, off main)

`gen_beech.py`: the `dist` tank module `pico_37a237` is commented out:
on scada main `ApiTankModule.__init__` accepts only the buffer and
tankN names and raises StopIteration for any other, which took
gwspaceheat down at every start on 2026-10-02 15:47; the unlimbo branch
carries free-standing modules and the window layout keeps it. Beech
reports dist-flow and no dist temperatures until that merge. The `sieg`
tank module `pico_605430` is commented out,
its depth mapping kept in the comment (depth1 sieg-hot, depth2
sieg-cold, depth3 hp-lwt2). The beech 5 V supply sits at 4.85 V with
the rest of the fleet and sags to 4.7 V with this pico added, so it is
unplugged; a layout that still names it would carry a permanently
missing pico. Production pair put on beech (`scada/`) and beech2
(`scada2/`), both scadas left stopped.

## 2026-10-02 — beech window layout: dist and sieg pipe-thermistor modules as identity deriveds (OPS-392, `313af9d` on jm/spruce)

`beech_gen.py` mirrors the production change on main: the dead dist-btu
`pico_47352a` goes; dist is a Hall flow pico `pico_1d3b35` and a tank
module `pico_37a237` whose depths 1 and 2 feed `dist-swt` / `dist-rwt`;
sieg-flow stays the Hall pico `pico_4e6e35`; a sieg tank module
`pico_605430` carries `sieg-hot` (depth 1), `sieg-cold` (depth 2) and
`hp-lwt2` (depth 3, beside the primary-btu's hp-lwt well), all as
identity DerivedChannels over the `-device` channels; the ADS board
loses sieg-hot (9), sieg-cold (11) and buffer-well (12). The sieg
module is unplugged (the 5 V bus sags from 4.85 V to 4.7 V with it on),
so `sieg` is in DisabledNodeNames with its nine channels and three
deriveds in DisabledChannelNames (axiom 28 requires every channel a
disabled node captures to be listed). To author that, the gen library
lifts `extra_tank_modules`, `extra_identity_deriveds` and
`emit_identity_deriveds` from the Nolan gen to the shared
`LayoutGenConfig` / `LayoutGen`, and the House0 build emits both. The
production gen (`gen_beech.py` on main, `jm/beech-sieg-off`) comments
the sieg module out instead, since scada main has no disabled roster.
Window pair put on beech and beech2 (`scada-experiment/`).

## 2026-10-02 — Add sieg tank module and new dist flow pico and new dist tank module (`f86b447` on main; `cfb1c80` "new dist btu (wifi)" is the intermediate commit)

`gen_beech.py`: the dist-btu gw101 rev C is broken and there are no
spares, so dist is a tank module "dist" on `pico_37a237` (dist-depth1 =
supply, dist-depth2 = return) plus a hall flow meter dist-flow on
`pico_1d3b35`. Beech reports the raw `dist-depth1-device` /
`dist-depth2-device` channels and no dist-swt / dist-rwt: scada main has
no way to derive one channel from another (its DerivedChannelGt names no
input and its derived-generator has no strategy handlers). When beech
moves to the unlimbo branch the pair comes back as identity deriveds
over the device channels, the way spruce declares fancoil-swt over
`fancoil-depth1-device`. sieg-flow stays
a hall flow module (`pico_4e6e35` until the replacement pico is flashed)
a sieg btu on `pico_605430` was
tried on 2026-10-01 while a working gw101 was thought to exist, and the
pico never posted in the 2026-10-02 census. That pico is reflashed as
the tank module `sieg` (fw `6a713e1`), three pipe thermistors on the
sieg loop: depth1 is the heat-pump supply beside the primary-btu well
(hp-lwt2), depth2 sieg-hot, depth3 sieg-cold. The meaning lives in a
comment in the gen, since scada main cannot name a derived channel's
input; the device channels are `sieg-depthN-device`. The multipurpose
board loses terminals 11 (sieg-cold) and 12 (named `buffer-well`, which
the buffer tank module's depth 2 reads; on 2026-10-02 it carried the
hp-lwt comparison Amphenol, which tracked the primary-btu's hp-lwt
about 3 F high on `snap_ads.py`). That board is a three-year-old i2c
ADC prototype on solderless breadboards whose contact resistance drifts,
the same failure the solderless tank modules showed in fall 2025, so its
remaining channels (store-hot-pipe, store-cold-pipe, buffer-hot-pipe,
zone1-down-gw-temp, zone2-up-gw-temp) are untrusted; GRI-6 tracks it.

## 2026-10-01 — update the dead primary reed flow meter at fir (`39a4148` on main)

`gen_fir.py`: the primary-flow reed pico is `pico_994b32`, a bare Pico W
on the breadboard, replacing `pico_1b5636`, found hot with its label tape
discolored during the fir 5 V bus repair. Main only; `jm/spruce` carries
the same change once fir is healthy. Regenerated with ids seeded from the
layout fir ran, so only the HwUid and the three flow ComponentIds differ
(the flow ids regenerate on every run: `layout_gen/flow.py:94` tests the
`component_display_name` method without calling it).

## 2026-09-30 — Nolan ops authors the buffer band thresholds (OPS-392, `75e53fb` on jm/spruce)

The vendored snapshot regenerates from sema `dev` (`ebde45d`),
where `gw.nolan.family.params` 000 carries `BufferFullF` and
`BufferChargeF`; the Nolan `OpsSpec` gains `buffer_full_f` and
`buffer_charge_f` and every Nolan generator authors 130 and 90.
**Why:** the Nolan heating machine gates the heat pump call on the
buffer band, and the band's thresholds are a tunable of the house, so
the ops word carries them.

## 2026-09-30 — ops authors Standby, its posture and relays, and AcceptsDispatch in place of actuation authority (OPS-392, `8d06151` on jm/spruce)

`OpsSpec` loses `actuation_authority` and gains `standby`,
`standby_posture`, `energized_standby_relays`, `accepts_dispatch` and
`dispatch_refusal_reason` (spelled `None` when accepting); every generator
authors them. Beech is the one Standby house (refusing with reason Standby);
House0 houses list `hp-failsafe-relay` and `aquastat-ctrl-relay`, Nolan
houses list nothing. The vendored snapshot regenerates from sema
`jm/operating-status`. **Why:** the sema pass retired
`gw1.actuation.authority`; the scada mirror reads these fields. Elm, fir,
oak and honeysuckle generators fail on the layout's sieg-hot channel
(axiom 8) before and after this change.

## 2026-09-28 — maple's hp-lwt and hp-ewt report on 0.05 C; ADS channels carry their own async delta (OPS-392, `8ad61ac` on jm/spruce)

The Siegenthaler loop reads the heat pump's leaving and entering water
off two ADS thermistor channels, and their capture tuning earned an
async reading only on a 0.5 C change, so the loop's strip stepped by
0.9 F while a start was under way. `AdsChannelSpec` gains `async_delta`,
defaulting to `ADS_ASYNC_DELTA_DEFAULT` (50, named at the top of
`thermistor.py`); a gen names a delta only where a channel needs a finer
one, and maple's `hp-lwt` and `hp-ewt` name 5 (0.05 C, five to twelve
noise standard deviations on the EMA channels per the 2026-08-06
ads-noise experiment). The default moves down
once the fleet shows 0.5 C is not the noise floor.

## 2026-09-27 — maple's send-line pico keeps its name; the grammar name is an identity over it (OPS-392, `3b3af5e` on jm/spruce)

In the 2026-09-25 maple window `sieg-send-flow` never reported: the pico
identifies itself as `sieg-send`, the name its production layout gives
it, and the window layout named the node `sieg-send-flow` through the
`<position>-flow` grammar, so its posts reached no node and the derived
`primary-flow` never fired (basic-sieg change 4d). Renaming the pico
means old firmware of unknown version, so the layout carries the name:
`FlowSpec` takes an optional `node_name` for a pico that posts outside
the grammar; its node and flow channel take that name, its Hz channel
`<node_name>-hz`, and `<position>-flow` is emitted as an identity
DerivedChannel over the flow channel, so the rest of the layout reads
the grammar name. Maple's spec sets it; the `RENAMED` table, whose only
entries mapped `sieg-send-flow` onto the deployed `sieg-send` ids, goes,
and renames are per house through the config's `renames`. A one-off:
every new sieg house names its meter `sieg-send-flow`. Test: maple's
generated layout keeps the deployed node and channel ids under
`sieg-send`, emits the identity, and sums the grammar name.

## 2026-09-25 — test with Maple at HoldFullSend (OPS-392, `50efea8` on jm/spruce)

The maple beta window drives the sieg valve from the admin panel with
the loop holding full send (basic-sieg change 2's last sub-step), so
the gen selects `HoldFullSend`; it goes back to `StratProtect` when the
StratProtect test-drives begin. `max_ewt_f` was 170 while maple's
running scada reports 145, a heating-curve change riding along unasked;
the gen takes the field value. Pair placed on maple with
`put_layout.sh maple hold-full-send`.

## 2026-09-25 — snapshot on sema 5ca82f8; House0 gens declare a sieg_loop_strategy (OPS-392, `50dc0f7`)

The vendored snapshot picks up `sieg.loop.strategy` and the family params
that carry it. The House0 gen config takes a required keyword-only
strategy in place of the boolean: beech, maple and both sim houses on
`StratProtect`, the three no-sieg fixtures on `HoldFullSend`. Elm, fir
and oak still fail the has-sieg layout word's axiom 8 at generation, as
before this change; they wait on `gw.house0.no.sieg`.

## 2026-09-25 — snapshot follows sema d11ba68: gw1.scada.device.type.gt axiom 6 SingleBus (OPS-392, `382d7e1` on jm/spruce)

Regenerated snapshot; the record word now holds its `BusList` to one
entry. All three board records already declare one bus, so no layout
changes.

## 2026-09-25 — snapshot follows sema ab309a2: no sim.relay / sim.dac.writer words, gw1.sim.device.type without SimRelayBank and SimDac (OPS-392, `65d978a` on jm/spruce)

Regenerated snapshot after sema dropped the two dead sim actuator words
and their enum values; `device_types` loses the two mirrored names. A
sim relay or 0-10V output is the real component word under a sim board,
which the gens already emit, so no layout changes.

## 2026-09-24 — snapshot follows sema c6c23ab; the gens name no component Enabled (OPS-392, `204aca9` on jm/handles-wave)

Snapshot regenerated from sema `c6c23ab`: House0 axiom 34 and Nolan 31
`HeatCallChannelBelongsToCircuit`, the restated `DisabledNodesAreSensors`
and `TransactivePowerChannel`, the six pico component words without
`Enabled`, `WebServer.Serve`, `hubitat.poller.gt/001` and
`maker.api.attribute.gt/001`. The gens follow: `Enabled=` leaves the pico
component and Hubitat constructors, the web server is `Serve=True`, and
the `enabled` flag on `FlowSpec`, `BtuSpec` and `ExtraTankSpec` goes with
its only reader (beech's dead `dist-btu` is already in
`disabled_node_names`; the spruce sim override goes with it). Spruce's
`secondary-pump-pwr` leaves the transactive-power set. Why: the layout's
disabled lists are the one place a missing sensor is declared, and the
metered boundary is the heat pump and the resistive elements, never a
pump.

## 2026-09-24 — gens declare hp-boss and sieg-loop under auto with their fixed relays nested (OPS-392, `7f0cdc4` on jm/handles-wave)

Snapshot regenerated from sema `jm/handles-wave`: House0 axiom 33 and
Nolan 30 `CommandNodeHandles`. Both family gens declare `hp-boss` (and
`sieg-loop` in House0) directly under `auto`, and the fixed relays under
the interior node that owns them: `hp-scada-ops-relay` under hp-boss,
the two loop relays under sieg-loop, the vdc relay under the cycler as
before. Every other actuator stays `auto.<Name>`. Why: the authored
handles are the initial command tree, and until now they were half
claimed by local control (`auto.lc.n.hp-boss`) with two of the three
fixed sub-trees missing; the scada's first rewrite hands the plant to
`lc` and the published tree stays the run-time authority.

## 2026-09-24 — every gen declares the primary-pump owner and refrigerant cycle; maple's primary-pump actuators leave (OPS-392, `d38bf49` on jm/spruce)

Snapshot regenerated from sema `e54adcd` (`jm/hp-facts-hydronic`):
`gw.hydronic` requires `PrimaryPumpOwner` and `RefrigerantCycle`, House0
axioms 31 `PrimaryPumpActuators` and 32 `PrimaryPumpRecordAgreement`,
Nolan 29. `LayoutGenConfig` takes `primary_pump_owner` and
`refrigerant_cycle` with no default; the House0 gen emits the
primary-pump relay pair only when the scada owns the pump. Beech, oak,
fir, elm, orange and willow: Scada / Cascade; spruce, honeysuckle: HeatPump
/ Single. Maple: HeatPump / Single, `primary-010v` and the relay pair
gone, `primary-pump-pwr` disabled. Why: maple's heat pump is now a
single-compressor Ecodan whose hydrobox runs the primary pump, so the
scada has nothing to drive there and its CT is off the pump until the next
visit; the facts are declared per home because both scada control paths
and the optimizer's COP model branch on them.

## 2026-09-24 — snapshot carries ActuatorChannels (OPS-392, `8c01ce7` on jm/spruce)

Snapshot regenerated from sema `02490b9` (`jm/actuator-channels`): House0 axiom 30
and Nolan axiom 28, and the trimmed `SiegManifoldChannels`. No gen
changes; every generated pair already carried each actuator's channel.

## 2026-09-24 — snapshot follows sema `0cf5f28` (OPS-392, `01464b1` on jm/spruce)

Snapshot regenerated from sema `0cf5f28` (`jm/flow-hall-params-210`):
the registry `last_updated` stamp and `seed_expanded` generation time
only, since `flow.hall.params` is not in the layout closure. Why: the
scada closure copy is a byte-for-byte copy of this registry, and the
stamp records which sema the snapshot was built from.

## 2026-09-24 — spruce disables its dead thermistors; beech drops the prototype dist2 meter; FlowSpec gains enabled (`f99011d`)

Spruce disables `store-hot-pipe`, `store-cold-pipe` and
`fancoil-depth3-device`: the `store-btu` and `fancoil` picos are live
(2026-09-24 pico census through the starter-scripts API) and post nothing
for these; the store thermistors sit at the 3.3 V rail and at 0 V, fancoil
depth 3 at the rail. Beech loses the `dist2` flow pico (`pico_2a7e22`, the
Omega reed meter on a breadboard with no protection board): it was an
in-series meter on a prototype, it pulled the 5 V bus down on 2026-09-22
and was disconnected, and it never posted in the census. Its node, its two
channels and the `dist-flow2` renames go with it; `dist-btu` stays disabled
awaiting the Rev C board. Beech's ADS pipe channels and Hubitat zone
channels stay enabled: the journal shows the production scada reading every
one of them all day. `FlowSpec` gains `enabled` (default True), carried to the flow component's
`Enabled` the way `BtuSpec` already does, so a fitted-but-dead flow pico can
be taken out of service without leaving the layout; no gen sets it yet. Why:
a layout states what the house can serve today; a prototype meter that is
gone is removed, and a sensor that is fitted but dead is disabled so the
field visit has its list.

## 2026-09-23 — layout words at the axiom tables: snapshot, emitter types, disabled lists (`e37a2bc` on jm/spruce)

Snapshot regenerated from sema `9326dde` (`jm/layout-word-axioms`, off
`jm/spruce`). The gens follow the words: `ZoneCircuitSpec` /
`ZoneCallCircuitSpec` carry `emitter_type` (`Other` everywhere; spruce
1/2/4 `RadiantSlab` with their `floor_temp_channel_name`, 3 and 5
`FanCoil`); `LayoutGenConfig` carries `disabled_node_names` /
`disabled_channel_names` (beech: `dist-btu` and its three channels plus
`sieg-hot` on ADS terminal 9; oak: `store-cold-pipe` on terminal 6;
spruce: the three pump powers at eGauge 9012/9020/9022 out of the
transactive set, and `buffer-cold-pipe` derived from
`pipes1-depth3-device`, both disabled); the Nolan gen emits `backup` and
`scada-blind`; the House0 sims emit sim sensors for the whole pipe
surface and the sim meter carries the pump powers. Honeysuckle is noted
as the Stoneman microgrid scada, not a house layout. Elm, fir and oak
still fail `SiegManifoldChannels` until the no-sieg word takes them.
Why: the word now states what the code reads, so a layout that lacks a
required name is refused at gen time instead of failing in the field.

## 2026-09-23 — minor: spruce floor and fancoil derived channels return (`c434529` on actual-spruce)

`gen_spruce.py` (actual-spruce) emits the seven identity derived channels
again: fancoil-swt, fancoil-rwt, floor-swt, floor-rwt and the three
zone floor temps, each passing its `*-device` capture through unchanged.
They were commented out on 2026-08-10 when the pipes1 and floor1 picos
were unplugged; the 2026-09-09 commit that brought the picos back
(`9c75b40`) left the list commented, and `spruce.json` carried the seven
as stale content until `91cc434` (2026-09-21) regenerated it and they
vanished from the wire. The comment block naming the floor1 pico says
`pico_27432a`, the WiFi pico fitted on 2026-09-21. Ids come from the
loaded `spruce.json`, so the seven keep their ids.

## 2026-09-23 — patch egauge delta (GRI-6, `be8f37a` on main)

`gen_beech.py` (main) states `AsyncCaptureDelta=1` on dist-pump, primary-pump,
store-pump, oil-boiler and the two whitewire eGauge channels. The box has run
with 1 W since the layout was last placed; the scada `layout_gen` default is
2 W, so a regen silently moved them. Declared, the regen reproduces the
deployed file. Found while regenerating beech's production layout to drop
the dead dist-btu (GRI-6); that regen also exposed the flow-module
ComponentId re-mint fixed in scada `layout_gen/flow.py`.

## 2026-09-22 — beech tank1 is pico_81a436; dist-btu out of service (GRI-6, `f143d02` on jm/spruce, `f1fa3fd` on jm/beech-pico-uids)

On both gens: `beech_gen.py` (jm/spruce, the window gen) and
`gen_beech.py` (main, the production gen, on branch `jm/beech-pico-uids`).

tank1 is `pico_81a436`, not `pico_0efd3c`. The pico was swapped in the
field on 2026-02-14 and the box's production `hardware-layout.json` was
hand-edited that day; `3b7be19` (2026-02-17) carried the swap into
`gen_beech.py` on jm/spruce but never reached main, and the 2026-09-14
rewrite of the window gen (`7c2db53`) started from the old UID again. A
window scada booted from that pair would refuse tank1's posts.

dist-btu (Gw101 Rev B, `pico_47352a`) is dead: 5 V at J1, 0 V at the
protection chip's output after repeated input cycles. A Gw101 Rev C
replacement is on order. `beech_gen.py` keeps the meter with its pico UID
and sets `enabled=False`, so the layout keeps the dist-flow / dist-swt /
dist-rwt channels and the scada neither polls the pico nor cycles for it;
`BtuSpec` gains the `enabled` flag (default True) that `ExtraTankSpec`
already has, and `emit_btu_meters` writes it to the component. The
production gen `gen_beech.py` drops the dist-btu block outright.

## 2026-09-21 — Update the spruce floor1 pico (`e9818b0` on jm/spruce)

floor1's tank-module pico was an ethernet (Wiznet) board, `pico_71156b`,
whose MicroPython firmware was lost (a bench check in Thonny showed no OS) —
it flatlined in the field and sent nothing. It is replaced with a WiFi pico
that registered as `pico_27432a`. Both spruce gens set floor1 to the new UID
and re-enable it: `gen_spruce.py` (the actual-spruce production layout, shipped
in `cd92920`) and `spruce_gen.py` (the jm/spruce beta-field-window gen). The
"out of service / bricked" comment on the window gen is removed — floor1 is
back in service.

## 2026-09-20 — improved layout testing (OPS-392, `35000c4` on jm/spruce)

Sema `2f7c0d1` gives both layout words `DerivedChannelCreatorResolution`,
`DataChannelNodeResolution`, `DerivedChannelInputsAcyclic` and
`ChannelNameUniqueness`. The snapshot regenerates so every gen's
validation gate runs them. Every house's output already satisfied all
four, so no layout changes.

## 2026-09-20 — spruce floor1 is out of service (OPS-392, `7118622` on jm/spruce)

The spruce floor1 pico was bricked by a remote firmware download and sends
nothing, and the scada rebooted the whole pico bank every ~65 s on its
account. `ExtraTankSpec` takes a required `enabled`, emitted as the
component's `Enabled`; spruce declares floor1 `enabled=False`. The module's
nodes, its six channels and the three zone floor-temp identity deriveds stay
in the layout, so the channel set matches what the Nolan word's axioms will
ask for, and the scada neither watches the pico nor cycles for it. The note
in the gen says the pico needs resuscitating or removing.

## 2026-09-18 — snapshot takes the two circuit channel axioms (OPS-539, `fab0b52` on jm/spruce)

Sema `73d6eb6` gives both layout words `CircuitWhitewireChannelResolution`
and `CircuitHeatCallChannel`, the House0 word's per-zone
`ZoneHeatCallChannel` giving way to the per-circuit statement. The snapshot
regenerates so every gen's validation gate runs them, and the gens rerun
against it.

## 2026-09-18 — a Nolan layout derives one heat call per zone-call circuit (OPS-539, `89db516` on jm/spruce)

The heat-call derived channels were emitted per zone. Spruce's living
room is one zone served by two circuits, each with its own thermostat
and whitewire, so the fancoil circuit's call
(`zone5-living-rm-fancoil-heat-call`, which the pi derives today) had no
derived channel in the generated layout; only its raw opto input was
reported. The Nolan gen names its heat calls from the circuit list. The
other four spruce heat calls and every House0 heat call keep their names
and ids, since those circuits are one to a zone. No word changes:
`gw.house0.layout` states its heat-call axiom per zone and
`gw.nolan.layout` states none.

The same commit sets beech's ops params to Standby. The beech house runs in Standby, and its gen emitted `ActuationAuthority`
`Active` with `SeasonalStorageMode` `AllTanks`, so a scada booted on the
generated pair would have loaded the all-tanks TOU control and actuated.
The gen states what the house runs; the move to local control is a
deliberate ops change, made in the gen when that run happens.

## 2026-09-18 — a house declares its renames; a renamed object keeps the pi's id (OPS-539, `56448a9` on jm/spruce)

The names retirement renamed objects the pis still hold under their old
names, and the gen finds a pi id by name, so each renamed object was
minted a new id: the four spruce heating elements and their power
channels (`elt-buffer-top` to `buffer-top-elt`, `elt-store-top` to
`tank1-top-elt`; the store elements sit in tank 1), spruce
`vdc-relay-gpio-23` to `vdc-relay`, and beech's second dist meter
(`dist-flow2` to `dist2-flow`, with its `-hz`). A channel that changes id
splits its journal history. `LayoutGenConfig.renames` carries a house's
(new name, deployed name) pairs; with the fleet-wide `RENAMED` they now
apply to node ids and node-bound component ids as well as channel ids,
which also moved maple's `sieg-send-flow` component onto the pi's id.

## 2026-09-18 — deployed gens take ids from the pi, then their own previous output (OPS-539, `3cb3f5a` on jm/spruce)

A deployed house's layout carries names the pi's running layout lacks
(spruce's unlimbo nodes, channels and components; the House0 names the
retirement changed), and a name absent from the single reference was
minted with a fresh uuid on every run. A box file checked byte-identical
to the gen output then stopped matching at the next regen. `LayoutGen`
takes a second map, the gen's own previous output, consulted after the
reference and its rename index and before minting; a previous-output id
the reference already assigns to another name is skipped. The spruce,
beech and maple gens fetch the pi's layout over rclone (agent key use
off per call, so the fetch does not depend on the ssh-agent holding the
fleet key) and fall back to the last fetched copy. The test runs a gen
twice against a reference that lacks names and requires identical ids.

## 2026-09-18 — snapshot takes SimDac; SimDeviceType lists every sim value (OPS-539, `0c3a7cd` on jm/spruce)

The snapshot regenerated from sema with `gw1.sim.device.type` carrying
`SimDac`. The generators' own `SimDeviceType` value list
(`device_types/__init__.py`) lacked `SimRelayBank` and gains it with
`SimDac`, so it names every value of the enum.

## 2026-09-18 — snapshot takes the pico BTU component axioms (OPS-539, `146ef3f` on jm/spruce)

The snapshot regenerated from sema with `pico.btu.meter.component.gt` and
`sim.pico.btu.meter.component.gt` carrying `ReadCtVoltageIffCtVoltsDelta`
and `ReadCtVoltageIffCtChannelName`, so every BTU component a gen emits is
checked against them at the driver's decode.

## 2026-09-18 — temperature DataChannels in CelsiusTimes100; Nolan zones carry a derived setpoint (OPS-539, `26badee6` on jm/spruce)

Sema requires `TempChannelName` on every HVAC zone and resolves it in both
layout words (`ZoneTempChannelResolution`), and a temperature DataChannel is
what a sensor measured, encoded `CelsiusTimes100`. Every gen — sim and house
alike — carries the same encoding now; the ADS board's per-channel telemetry
override is gone (`AdsChannelSpec.telemetry` deleted), so there is no lever
left to leave one channel on the old encoding.

- The snapshot regenerated at sema `8bc9fc4`: `gw1.hvac.zone` with
  `TempChannelName` required, `ZoneTempChannelResolution` as
  `gw.house0.layout` axiom 18 and `gw.nolan.layout` axiom 13, `gw.hydronic`
  without its axiom 3.
- Capture deltas scale with the encoding: tank device temperatures 2000 to
  200 (`tank_module.py`, the extra tank modules included), ADS channels 500
  to 50 (`hardware/thermistor.py`), sieg-cold 2000 to 200
  (`house0_sema_gen.py`). The ADS device-type record's `TelemetryNameList`
  is `CelsiusTimes100` alone, which the scada's tsnap driver checks its
  channels against.
- `hydronic_zones()` returns a `ZoneCore` record (`layout_gen.py`) and each
  family gen builds its own `HvacZone` from it, so each names its zone's
  temperature channel. A Nolan zone with no thermistor raises.
- `nolan_sema_gen.py` `emit_zone_setpoints` writes one DerivedChannel per
  zone (`zone{i}-{label}-set`, strategy `simple-falling-edge-setpoint` over
  the zone's gw-temp and heat-call, `FahrenheitX100`). Spruce has no
  thermostat the scada can read, so the setpoint the cold-house judgment
  compares against is inferred from where the temperature stands when a
  heat call ends.

## 2026-09-18 — Simulated BTU meters emit the sim pico BTU word (OPS-539, `6b3d8c5` on jm/spruce)

A simulated home's BTU meters were the generic sim sensor, so no sim pair
booted the scada's `ApiBtuMeter`. The emitter now gives a simulated home
`sim.pico.btu.meter.component.gt` under an `ApiBtuMeter` node, with the
home's `SimLifeS` / `SimRebootS` and a `sim-<node>-pico` HwUid, the way the
tank emitter does; the component fields are shared between the two words.

## 2026-09-17 — Snapshot regen: one ops word with a family block and a tariff; pico boards authored; oak, fir and elm as House0 fixtures (OPS-539, `472fee6` on jm/spruce)

- Snapshot regenerated from sema `7928618`: `gw.operational.params` with
  `FamilyParams` replaces the two family ops words (the seed now targets
  it; the orphaned `dfr.component.gt` leaves the seed, no gen builds it);
  `gw.tou.tariff`, `iana.timezone.str`, `gw.primary.flow.source`,
  `pico.board.variant`, the two sim pico words, and the three pico
  component words with `PicoBoardVariant` + `MicropythonVersion`.
- `OpsSpec` carries `keep_buffer_full` and a `TariffSpec` (alias, display
  name, tz zone, on-peak windows); `build_ops_kwargs` emits the shared
  block and each family gen adds its `FamilyParams`
  (`UseSiegLoop`/`KeepBufferFull`/`SeasonalStorageMode` for House0,
  the latter two for Nolan). Every gen names the Versant TOU rate from
  the tariff word's example; the alias is a guess to confirm.
- `TankSpec`, `ExtraTankSpec`, `BtuSpec`, `FlowSpec` take a required
  keyword `board` (`PicoBoardVariant`), authored per pico like the
  HwUid. First pass: beech and maple tank modules are Wiznet Pico 2
  boards on the `gridworks-pico/firmware` build, their other picos Pico
  W; spruce is all Pico W until the window says which tank module is the
  Wiznet; oak, fir, elm and the bench sims are `Unknown`.
  `MicropythonVersion` is left absent everywhere: not yet known.
- `ZoneCallCircuits` is required on `gw.hydronic`, so the base gen
  returns the zones (`hydronic_zones`) and each family builds `Hydronic`
  with its circuits; a gen with none declared raises.
- Oak, fir and elm are sema-authored as House0 fixtures on purpose
  (no sieg loop in the houses; the word requires the sieg surface, so
  each carries a pretend sieg flow pico `pico_000000` and a `sieg-cold`
  ADS channel, marked PRETEND). They run with no reference layout
  (`reference=None` mints ids; g-nodes authored in the gen) and beech's
  LG pair standing in for unrecorded heat-pump make/model. The commented
  `old_gen_{oak,fir,elm}.py` specs and the `house0_no_sieg_sema_gen.py`
  stub are deleted: translated, nothing imports them.
- A House0 sim zone's sim sensor emits the zone's `-set` channel beside
  `-temp` (`AirTempFTimes1000`), so the hydronic actors' setpoint memory
  has a channel behind it on the orange and willow pairs. The Nolan sim
  pair emits none: what the Nolan cold-house rule reads is undecided.

## 2026-09-17 — Tank name helpers by index; House0ChannelNames is constants only (`99b6f4d` on jm/spruce)

The scada retired `helpers.Tanks` and the `House0ChannelNames` instance
part (a layout now answers its own tanks). The tank-module and
calibration emitters build `TankNodeNames(i)` / `TankChannelNames(i)`
for `1 .. total_store_tanks` directly, and the base gen's `cn` is the
class. Both sim pairs regenerate byte-identical.

## 2026-09-15 — House0ChannelNames takes the tank count only (`584121b` on jm/spruce)

The gwsproto `House0ChannelNames` lost its `zones` instance part with
the scada's zone-roster retirement; the base gen's `cn` property passes
the tank count alone. No output changes.

## 2026-09-15 — House0 zone failsafe relays emit ZoneCallSource; hubitat node from the hydronic tier (`634c159` on jm/spruce)

The House0 gen realized each zone's failsafe relay with the
`heatcall.source` pair while the Nolan gen used `zone.call.source`; one
relay kind now serves both families and the heat-call kind is deleted.
The hubitat emitter read `hubitat` off the family names class, which
broke `beech_gen` and `maple_gen` once the scada moved that name to the
hydronic tier (`65262e85`); it reads the hydronic tier now. All four
House0 layouts regenerate; the sim pair is copied into the scada
fixtures, the beech and maple outputs are box artifacts. The import
alias for `HydronicSpaceheatNodeNames` / `HydronicSpaceheatChannelNames`
is `HSNN` / `HCN` throughout, matching the scada repo (`Hyd` / `HydC`
retired); no output changes.

## 2026-09-15 — sim gens emit sim extra tank modules; secondary pump through its names (`6126a44` on jm/spruce)

`emit_extra_tank_modules` ignored `tank_kind` and emitted real
`pico.tank.module` components for fancoil, floor1 and pipes1 even in the
spruce sim gen, so the scada's sim pico tests could not take the fresh
fixture. It now branches like the buffer and tank emitter: sim config,
`sim.pico.tank.module` with a `sim-<name>-pico` uid. The real spruce
output is unchanged. `spruce_gen.py` names the secondary pump's power
channel through `HydronicSpaceheatChannelNames.secondary_pump_pwr` and
its node through `HydronicSpaceheatNodeNames.secondary_pump`, both new in
gwsproto, instead
of bare strings.

## 2026-09-15 — gens declare every actuator flat under auto (`c1772e6` on jm/spruce)

The scada rewrites the command tree at boot (`set_command_tree(n)` in
`Scada.__init__`) and reparents every actuator under the live boss, so a
layout's declared actuator handle is a placeholder. The House0 gen declared
relays under `auto.lc.n` and 0-10V outputs under `auto`; the Nolan gen
declared both under `auto.lc.n`. Both now declare every relay and output
flat under `auto` (`i2c_relay.declared_handle`), the shape the deployed
beech and fir layouts already had for their outputs; vdc-relay keeps its
place in the five-v-boss subtree. Every output regenerated, handle lines
only; the spruce and honeysuckle box copies need republishing to stay
byte-identical to the gen.

## 2026-09-15 — beech, maple, oak gens: ShortCycleBuffer true (`684d956` on jm/spruce)

The three House0 field houses run the leaf ally with `ShortCycleBuffer`
true, as the control design intends: the buffer cycles on its bottom
sensor and the LTN counts none of it as storage, so the FLO plans on the
store alone. The sim pairs and the Nolan houses stay false. Oak's gen
still raises at the `gw.house0.no.sieg` stub, so its stale output keeps
false until that word exists; beech and maple regenerated (ops params
only, one field). The box copies need republishing.

## 2026-09-15 — willow: the second simulated House0 pair, derived primary-flow (`26401c5` on jm/spruce)

The scada suite gets a House0 fixture per sieg-flow pattern. `orange_sim_gen.py`
(was `house0_sim_gen.py`; the little orange house) measures `primary-flow` and
derives `sieg-send-flow` by difference, beech's pattern. New `willow_sim_gen.py`
is the same all-simulated skeleton with `DerivedSiegSum`: a sim flow sensor on
the sieg send line, `primary-flow` derived as the sum, maple's pattern. Willow
is a second little house with its own GNode identity, and its ids are minted
from an empty reference on the first run so none collide with orange's; each
driver's stable-id reference is its scada fixture copy, since `output/` is not
committed. `emit_sim_plant_sensors` places the sim sensor on the identity's
measured addend (primary when Measured, sieg-send when DerivedSiegSum). Fixed
on the way: `emit_sim_power_meter` minted its component id twice, which held
only while a reference layout already carried the id and failed
ComponentBinding on a first run. Rung 4 of correct-house0 (OPS-539).

## 2026-09-15 — sieg-send-flow and the derived sieg flows; maple gen (`155d4e0` on jm/spruce)

The sieg send line's flow meter takes the `<position>-flow` grammar every
other flow meter follows: position `sieg-send` → `sieg-send-flow` /
`sieg-send-flow-hz`, replacing the deployed bare `sieg-send`; a `RENAMED`
table (new → old) lets a regenerated layout inherit the deployed UUIDs, the
way the relay-idx rename does. `FlowSpec.position` opens from a closed
`Literal` to a `SpaceheatName` — a position is any name the grammar
composes, not a closed set — and `primary_flow_source` is typed as the sema
enum `House0PrimaryFlowSource` instead of a bare string.

`emit_primary_flow` now carries the sieg-loop flow identity
`primary-flow = sieg-send-flow + sieg-flow`: a house that measures
primary-flow and has a sieg-flow channel derives `sieg-send-flow` by
`difference` (beech); a house on `DerivedSiegSum` derives `primary-flow` by
`sum` (maple). The difference branch keys on the sieg-flow channel's
presence, so non-sieg families regenerate unchanged.

`maple_gen.py` authors the real Keene Maple `gw.house0.layout` (Mitsubishi
Ecodan WUZ-SA48NMZ + ERSF-NM6E hydrobox, sieg-btu and store-btu, dist and
sieg-send Hall picos, an outdoor air temp on the ADS) as a deployment
artifact, mined from `old_gen_maple.py`; `sema validate` green, id-preserving
against the deployed layout. The vendored snapshot regenerates on sema
`8e56c4e` (House0 axiom 8 no longer requires `sieg-flow-hz`, which maple's
BTU-sourced sieg-flow cannot produce). Rung 4 of correct-house0 (OPS-392).

## 2026-09-14 — beech real deployment layout from the sema House0 gen (`7c2db53` on jm/spruce)

`beech_gen.py` authors the real Keene Beech `gw.house0.layout` — a sieg-loop
House0 home with two Honeywell-via-Hubitat zones, an LG Multi V split heat pump,
an eGauge, four pico tank modules, two BTU picos, three standalone flow picos, and
an ADS analog-temp board — as a deployment artifact (`output/beech/`), id-preserving
against the deployed layout and `sema validate` green. It replaces the hand-kept
beech real shape that `gw.house0.layout.json` used to carry.

Getting there needed the House0 real path built out on the shared gen, all with
spruce + sim output byte-identical:
- `btus` moves to `LayoutGenConfig` and `emit_btu_meters` runs in the House0 build
  before `emit_flow`, so a BTU pico's flow channel satisfies the bare-flow emit.
- `DeviceType` is now the gwsproto enum (the local name), replacing tlayouts' partial
  hand-kept mirror — the words still type the field as a string; the enum supplies it.
- `FlowSpec` gains a Hall/Reed `kind` axis (Saier default; Ekm/Omega reed) and the
  `dist2` position, fixing the Reed-hardcode; names route through FlowNodeNames/
  FlowChannelNames.
- `AdsChannelSpec` gains a thermistor make/model axis (Tewa default, Amphenol for the
  zone air-temps); a House0 zone's temperature reads the ADS `gw-temp` where one exists
  and falls back to the Honeywell temp otherwise.
- `TankSpec` gains asymmetric depth-1/depth-3 calibration and a sensor order, matching
  beech's tank3 (B −108/−481) and tank2/tank3 reverse order.

## 2026-09-14 — Family-neutral base generator and the hardware modules (`5347f3c` on jm/spruce)

`NolanSemaGen` subclassed `House0SemaGen`, so a Nolan driver imported
its DAC spec and board emitter from a module named for another family,
and every hardware realization (relays, DAC outputs, the meter, tank
modules, thermistor readers) lived in whichever family wrote it first.
Now `layout_gen.py` holds what every family shares (`LayoutGen`,
`LayoutGenConfig`: the id map, the accumulators, the stable-id helpers,
the ops kwargs, and the emitters no layout word varies: GNodes, web
server, heat-pump parts, pico flow meters, primary flow, derived
channels, the hydronic core), and `hardware/` holds one module per
kind with its spec beside its realizer (`board`, `i2c_relay`,
`dac_output`, `thermistor`, `tank_module`, `power_meter`, `gpio_relay`,
`gpio_sensor`, `btu_meter`, `hubitat_zone`), each a function that
appends to a gen. House0 and Nolan are siblings on
`LayoutGen` and own only their plant roster. The two families' i2c
relay and DAC emitters collapse into one each, the family fact (the
node's handle, the channel caption) a parameter; the relay wiring and
event/state bundles are typed `RelayKind` constants. `DeviceType` and
`SimDeviceType` move to `tlayouts.device_types`, the vocabulary home.
Nolan's redundant `__init__`, `emit_gnodes`, `emit_heat_pump_parts` and
duplicated config fields go. Drivers repoint their imports. A move, not
a redesign: spruce, spruce-sim, spruce-async1, honeysuckle (both
variants) and house0-sim regenerate byte-identical. Rung 3 of
correct-house0 (OPS-539).

## 2026-09-14 — beech's house0 layout generates automatically (`400e858` on jm/spruce)

`House0SemaGenConfig` now carries the board (equipment node name,
device-type record file, its simulated twin, bus addresses, display)
and the 0-10V outputs as `DacOutputSpec`s against that board, with
gw108 rev B as the default; `emit_board` and `DacOutputSpec` move from
the Nolan gen to the base, and the Nolan subclass loses its copies
(spruce, spruce-sim, spruce-async1 and honeysuckle regenerate
byte-identical). The two existing House0 homes declare their krida
panel and DFRobot outputs in their drivers (the sim, oak). Why gw108
is the default: it is what every install from here on uses, no new
krida or DFRobot panel will be built, and beech's panel may itself be
replaced by a gw108. "Which board" is now a one-axis swap, the
hardware-decoupling shape. The sim House0 pair's three 0-10V captions
take the Nolan form (`Dist Pump 010V`, channel `… Level`) in place of
the hardware-named `Dist DFR`; ids unchanged. Rung 2 of correct-house0
(OPS-539).
The board axis is the change the title names: House0's real layout can
now be generated on its own board declaration. Also: the six commented-out legacy generators renamed `old_gen_<house>.py`,
contents untouched; the live drivers renamed to `<house>_gen.py` (`spruce_gen`,
`spruce_sim_gen`, `honeysuckle_gen`, `house0_sim_gen`, `oak_gen`; sema is
implied for every live generator), with the drivers' and the component-id
test's imports following the rename.

## 2026-09-14 — House0 gen: relays and 0-10V outputs on the board record; the DFR multiplexer gone (`06368c7` on jm/spruce)

`house0_sema_gen.py` had fallen two retirements behind the scada
fixtures it is meant to emit: it still read the deleted
`relay_multiplexer` name (the sim gen would not run) and emitted the
orphaned `dfr.component.gt` / `dfr.config` pair with the
`zero-ten-multiplexer` node. `emit_relays` now emits the shape krida
rung 3 hand-patched in: the board record and its
`scada.board.component.gt` anchor bound to the `krida` node, the
`i2c-bus` actor node, and one `i2c.relay.component.gt` per relay
against the record's RelayName, each relay-state channel captured by
its own node. `emit_dfr` becomes `emit_dac_outputs`: one
`i2c.dac.output.component.gt` per output (Dfr1 A/B, Dfr2 A) with a
wiring-only `dac.output.config`, the power-on level in
`ZeroTenPowerOnList` (config field renamed
`zero_ten_power_on_volts_times_ten`, the old name was volts times a
hundred in name only). The simulated board record
`SimKridaDoubleRelayBoard16` is vendored as a device-type file
(`sim.krida-…`) beside the real one, since its DACs are `Mcp4728`
twins rather than an identity swap. The sim gen's output is now
semantically identical to the scada sim fixture pair with every id
preserved; the fixtures are replaced by the gen's output in the same
wave (scada). Rung 1 of correct-house0 (OPS-539).

## 2026-09-13 — Snapshot regen: House0 layout axiom 10 clause c and axiom 15 ComponentBinding (`44050b1` on jm/spruce)

The vendored snapshot follows the sema commit that adds the 0-10V
component binding clause and `ComponentBinding` to `gw.house0.layout`;
no generator change, the sim House0 gen already emits per-output
components and the web-server node.

## 2026-09-10 — snapshot regen: RelayEnergizedLevel on the board records (`c4c026a` on jm/spruce)

The vendored snapshot regenerated from sema `7d58bd1`: `gw1.scada.device.type.gt`
with its required `RelayEnergizedLevel` and axiom 5. The two vendored board
records declare their relay drive: `gw108.revb` 1 (NPN low-side driver, a
high pin energizes), `scada.krida` 0 (active-low; power-on all-high leaves
every relay off). The snapshot registry is mirrored into the scada closure
copy in the same wave.

**Why:** the House0 relay decommission drives Krida relays through the same
relay actor as gw108's, and the two boards energize on opposite pin levels;
the relay actor translates from the record instead of hand-mapping by
DeviceType (sema changelog, same date).

## 2026-09-10 — snapshot regen: i2c.expander.type, ExpanderType on board records, SimKridaDoubleRelayBoard16 (`dd7fd0a` on jm/spruce)

The vendored snapshot regenerated from sema `f1e551c`: the new
`i2c.expander.type` enum, `i2c.expander` with its required `ExpanderType`,
and `gw1.sim.device.type` with `SimKridaDoubleRelayBoard16`. The two
vendored board records declare their chip: `gw108.revb` Tca9555, `scada.krida`
Pcf8575. The snapshot registry is mirrored into the scada closure copy in the
same wave.

**Why:** the House0 relay decommission drives Krida relays through the
same bus actor as gw108's, and the two expander chips speak different bus
protocols; the board record now says which (sema changelog, same date).

## 2026-09-12 — snapshot regen: zero.ten.power.on in the ops words, dac.output.config wiring only, Gp8403 DACs on the House0 board record (`6d28e10` on jm/spruce)

The vendored snapshot regenerated from sema `9cdeec5`: `zero.ten.power.on`
arrives, `dac.output.config` loses its EEPROM fields, `i2c.dac.type` gains
`Gp8403`, `i2c.dac.vref` leaves the closure. The seed lists
`dfr.component.gt` explicitly with a note: it is orphaned in sema and out
of `gw.house0.layout`'s union, so closure no longer reaches it, and
`house0_sema_gen.emit_dfr` still emits it until the gen moves to
per-output components. The House0 gen turns its three DFR levels (20, 40,
0 volts times ten; the DFR field name says times 100 and is wrong) into
`ZeroTenPowerOnList` entries; the Nolan gen's `DacOutputSpec` carries
`power_on_volts_times_ten` instead of a raw code and the DAC output config
drops the three fields; spruce and honeysuckle move from code 3020 (7.55 V)
to 76 (7.6 V). The `scada.krida` record gains two `i2c.dac.capability`
entries (`Dfr1`/`Dfr2`, `Gp8403`, 94 and 95, two channels each): the
board record is the bus population, and House0's I2C bus carries the
Krida expanders and the two DFRobot modules. The spruce gen validates
through the snapshot; tlayouts tests pass. The gens import `gwsproto`,
which the tlayouts env lacks: run them with the scada venv's python.

## 2026-09-09 — spruce: egauge port 05 meters the secondary pump (secondary-pump-pwr replaces dist-pump-pwr) (`60d4e11` on jm/spruce, titled "add egauge for secondary-pump-pwr"; actual-spruce commit pending)

The gw108 CT chain could not give a conclusive secondary-pump-on signal
(the 2026-09-07 bench: three of four ADC inputs tied, the CT picking up
the store pump), and the dist flow meter's port on the eGauge had a CT
with nothing useful behind it. George moved the eGauge CT to the
secondary pump, reconfigured port 05 as a 5 A CT named
`05-secondary-pump`. Both lines: the power channel at address 9008 is now
`secondary-pump-pwr` about a `secondary-pump` node (80 W nameplate,
5 W capture delta); `dist-pump-pwr` and its node are gone. Box layouts
replaced from these artifacts in the same window.

## 2026-09-09 — spruce: floor1 tank module is pico_71156b (`91ce50e` on jm/spruce; `e47b4d1` on actual-spruce)

The floor1 board on site is a fresh WIZnet (ethernet) pico, `pico_71156b`;
the layouts still named `pico_586e36`. `jm/spruce`: `spruce_sema_gen.py`
takes the new HwUid (commit titled "update pipes1"; the diff is the floor1
id). `actual-spruce`: `spruce.json` and the commented `gen_spruce.py` block
take the same HwUid. Both box layouts were replaced from these artifacts in
the same window. The board still has no ethernet cable, and when a pico with this id first
posted (after the 11:51 unlimbo restart) it identified itself as
store-btu, so it is being reprogrammed as floor1 before it can post.

## 2026-09-09 — spruce: fancoil, floor1 and pipes1 tank modules back in both lines (`b326578` on jm/spruce; `9c75b40` + merge `138c28e` on actual-spruce)

Two commits, one per branch, plus a merge on actual-spruce that only absorbs a re-authored duplicate of the July CT-notes commit. `jm/spruce`: `spruce_sema_gen.py` restores
the three `ExtraTankSpec` entries and their seven identity deriveds.
`actual-spruce`: `gen_spruce.py` restores the three `add_tank3` blocks,
drops the duplicate second registration of the pipes1/floor1 pair, and
takes the secondary-btu HwUid to `pico_108a2b` (the swap the box already
ran with, hand-edited there on 2026-08-10 and recorded on `jm/spruce` in
`50cf8df`, never on this branch); `spruce.json` is the pre-removal
artifact with that one HwUid fix, checked equal to the running box file
plus the three modules.

**Why:** the three wifi picos were physically disconnected on 2026-08-10
and are being re-powered; both scadas on spruce need to see them at
their next restart. The jm/spruce regeneration used the running
scada-experiment layout as its id reference, extended with the three
modules' ids from the actual line, so every existing node, channel and
component keeps its id and the restored channels carry the ids they had
before August in both lines.

## 2026-09-08 — one seed, one regen script (`3118aa7`)

**What:** `src/tlayouts/sema_seed_request.yaml` is the only seed: the nine
targets and the `local_names` rule moved in from the root-level
`tlayouts_seed_request.yaml`, which is deleted together with
`build_tlayouts_snapshot.sh`. The snapshot is rebuilt through
`scripts/regen_sema_snapshot.sh`; only its seed-copy indexes change.

**Why:** two seeds and two build scripts had drifted apart: the root pair
was the one recent commits used, while the README and the snapshot's own
banner pointed at the pair every other consumer has, sema's template
(`scripts/regen_sema_snapshot.sh` reading `src/<pkg>/sema_seed_request.yaml`).
One seed, one path, the one an LLM is pointed at from inside any snapshot.

## 2026-09-08 — five-v-boss in both sim gens; snapshot at sema a241693

**What:** both gens (`house0_sema_gen.py`, `nolan_sema_gen.py`) emit a
`five-v-boss` node (ActorClass `FiveVBoss`, handle `auto.five-v-boss`) and
reparent the pico cycler under it: `auto.five-v-boss.pico-cycler` and
`auto.five-v-boss.pico-cycler.<vdc relay>`. Snapshot rebuilt at sema
`a241693`: `gw1.actor.class/014`, `spaceheat.node.gt/303`, and both layout
words' command-node axiom name `FiveVBoss` as an interior node.

**Why:** the pico-cycler-command chunk of the `sh_node_actor` partition
puts a command node between the cycler and the 5 V relay, so admin asks the
boss to hold the picos' supply off instead of seizing the relay while the
cycler keeps running. The layouts have to carry the node before the scada
side can be tested on either sim fixture.

## 2026-09-08 — swap out spruce secondary btu pico

**What:** `spruce_sema_gen.py` names `pico_108a2b` as the secondary-btu
BTU meter's HwUid (was `pico_1c3c31`).

**Why:** the secondary BTU pico was replaced on site on 2026-09-08. The
scada accepts a pico's params only when its HwUid matches the layout,
so the uid has to change at the source. The two layout files on the
spruce box (the deployed scada's legacy file and the window scada's
`gw.nolan.layout` copy) were patched by hand the same afternoon; the
regenerated pair supersedes them at the next layout upload.

## 2026-09-07 — sim tank picos carry a liveness script; snapshot at sema fc741c2

**What:** `House0SemaGenConfig` gains `sim_pico_life_s` / `sim_pico_reboot_s`
(None = absent on the word); the sim tank emission passes them as
`SimLifeS` / `SimRebootS`. Both sim configs (house0-sim, spruce-sim) set
120 / 20. Snapshot rebuilt from `tlayouts_seed_request.yaml` at sema
`fc741c2`; the only vocabulary change is the two fields on
`sim.pico.tank.module.component.gt/001`.

**Why:** the sim picos have to die and reboot for the scada's pico-cycler
loop to be witnessed on a sim layout; 120 s life puts a flatline and a
cycle inside the five-minute dev-broker rung. `scripts/regen_sema_snapshot.sh`
and `src/tlayouts/sema_seed_request.yaml` are a stale pair (that seed drops
six words the gens use); `build_tlayouts_snapshot.sh` with the root seed is
what reproduces the committed tree.

---

## 2026-09-18 — drop hubitat zone state (OPS-539, `905eb5e` on jm/spruce)

The Hubitat `thermostatOperatingState` reading has unstable values, no names
class carries it, and nothing reads it for heat call or control; a zone's
heat call is its derived `heat-call` channel. `hardware/hubitat_zone.py`
emits temp and setpoint only, so beech, maple, oak, fir and elm lose one
`zone{i}-{label}-state` channel, poller attribute and capture tuning per
zone. A deployed house takes the regenerated layout only after the web
frontend's thermostat table stops reading `-state`.

## 2026-09-06 — patch linear.one.dimensional.calibration snafu (`0a051f9`)

The affine depth calibration in `house0_sema_gen.py` was a hand-built
dict pinned at `linear.one.dimensional.calibration/001`, a version sema
squashed away on 2026-08-13; every real-tank artifact since (spruce,
oak) failed to boot on the scada, unseen because the word sits outside
the layout closure (the derived-channel word types `Parameters` as a
bare object). Now the word is seeded into the tlayouts snapshot
(`tlayouts_seed_request.yaml`, with the reason) and the gen builds the
calibration through `LinearOneDimensionalCalibration(...).to_dict()`,
so its version is the snapshot's and the closure registry carries it
for the scada mirror check. The `tank_kind == "real"` gate on the
calibration is gone: a tank with a spec calibrates whether real or sim,
so the spruce sim pair (the scada's Nolan fixture) exercises the affine
path the real artifact boots with. Honeysuckle declares no tanks and is
unchanged. Snapshot rebuilt at sema `d6f59e7`.

---

## 2026-09-04 — correct power meter for honeysuckle (`56dbcd1`)

`honeysuckle_sema_gen.py` set `power_meter_kind="sim-egauge"`, a value
the config's `Literal["sim", "egauge"]` refuses, so the layout had not
generated since the config annotation landed. Honeysuckle is the pi on
a real gw108 at the Stoneman microgrid, not a simulated home, and the
site has a real eGauge (`eGauge14875.local`, hardware id `GC14050323`,
read off input register 100 the way `starter-scripts/egauge.py` does),
so the meter is `egauge` with that identity. The channel surface stays
the spruce twin: the eGauge's own register configuration ("Boost Power",
"Pump Power") is stale and its CTs are attached to nothing, so the nine
spruce registers read zero until the meter is reconfigured; the gen
docstring says so. The `sim-egauge` branches in `house0_sema_gen.py`
had no other caller and are gone.

---

## 2026-09-04 — snapshot at sema d6f59e7: writer trio out of the closure (`335e946`)

Snapshot rebuild after the sema layout-word edit (`d6f59e7`): the two
layout words dropped `i2c.dac.writer.component.gt` and
`sim.dac.writer.component.gt` from their Components unions, so those and
`i2c.dac.channel.config` leave the closure; Nolan axiom 5 gains the
`secondary-010v` clause. The seed request drops its explicit
`i2c.dac.writer.component.gt` line, listed before any layout referenced
the writer; with it gone nothing keeps the trio in the closure. The
Nolan sim pair regenerates byte-identical to the scada fixture, which
already carried the node.

## 2026-09-04 — Nolan gen emits DAC outputs, not the chip writer (`d6a995e`)

`emit_dac_output` replaces `emit_dac_writer`: the config axis is a list
of wired outputs (node name, DAC, channel, power-on code), each emitting
one `i2c.dac.output.component.gt` bound to its `ZeroTenOutputer` node
under local control, a `VoltsTimesTen` channel captured by that node,
and its capture tuning. Unwired channels no longer carry EEPROM defaults
in the layout, matching the word (an unwired channel has no component
and its EEPROM is never touched). Spruce and honeysuckle declare only
channel C as `secondary-010v`; spruce, spruce-sim and honeysuckle
regenerate. Honeysuckle does not: its config value `power_meter_kind=
"sim-egauge"` fails the generator's `Literal["sim", "egauge"]` (the code
paths handle the value; only the annotation refuses it), a pre-existing
break; a TODO on the config records it with the home's real identity
(the pi on a gw108 at the Stoneman microgrid, eGauge on site — the fix
is the egauge kind with that meter's identity, not a sim knob).

---

## 2026-09-03 — snapshot on the layout tree axioms (`447207b`)

Snapshot rebuilt at sema `818fa11` (the vendored layout words gain
PrefixClosedHandles and ActuatorLeaves): `gw.hydronic` gains optional
`HpCommandNodeName` and loses `Strategy` (the family is the layout
word); the vendored layout words carry the CommandableHeatPump axioms;
`new.command.tree` is not in the seed. The sim pairs regenerate
byte-identical to the scada fixtures.

## 2026-09-03 — generators drop Hydronic.Strategy (`541da84`)

The House0 and Nolan gens and every script stop passing a strategy
label; the family is the layout word.

---

## 2026-09-03 — House0 gen emits UseSiegLoop on the ops artifact; snapshot on the sieg split (`1741a26`)

Snapshot rebuilt at sema `7c3e0bd`: `gw.hydronic` without `SiegLoopPlumbed`
and `UseSiegLoop`, `gw.house0.operational.params` with `UseSiegLoop`
(`layout.lite` is not in the tlayouts seed, so its rename does not
appear here). The House0 gen keeps `use_sieg_loop` as
a config axis but emits it on the ops artifact; `sieg_loop_plumbed`
leaves the config (the plumbed sieg surface is what the House0 word
means). The Nolan gen drops both from its hydronic block.

---

## 2026-09-02 — sim-House0 pair authored; House0 gen carries the sieg surface, hp parts and zone circuits (`85e7364`)

`gen_house0_stub_sema.py` becomes `house0_sim_sema_gen.py`: the little
orange house as the all-sim shape of the beech family word, emitting the
scada suite's second House0 pair (`gw.house0.sim.*`). The House0 gen
catches up to `gw.house0.layout` axioms 3, 7, 8, 10 and 11: the
sieg-loop command node, sim sensors (`sim.sensor.component.gt` +
SimSensorActor) behind dist / primary / store / sieg flow and the sieg
cold side, `hp-odu` and `hp-idu` on `device.component.gt` through
`HpPartSpec` (moved here from the Nolan gen, which now imports it), and
per-zone `ZoneCircuitSpec` (actuator, role, setpoint source, thermostat
kind, hub device id) driving both Hydronic.ZoneCallCircuits and the
zone's temperature realization: HoneywellViaHubitat emits the hub
poller, MechanicalDial on a simulated home emits a sim temperature
sensor (`<zone>-temp-sensor`, no name constant yet). Every zone carries
its TempChannelName. `zone_device_ids` retires into the circuit spec;
`minted_gnodes` supplies identity for sema-shaped references; the
thermistor-common relay leaves the table (the fixture dropped it
2026-08-31); the store-pump relay resolves through the hydronic node
tier. Two pre-existing name drifts fixed in passing (backup /
scada-blind moved to the House0 tier). `gen_oak_sema.py` still passes
`zone_device_ids` and stays guarded behind the missing no-sieg word.
The snapshot rebuilt from sema `0496374` rides along so the vendored sim
vocabulary carries `SimHpIdu`.

## 2026-09-02 — snapshot carries gw.house0.layout axioms 10-11 (`cdf531c`)

Snapshot rebuilt from sema `dfe93be`: the vendored `House0Layout` now
enforces `RequiredActuators` and `RequiredHeatpumpEquipment`, so the
House0 stub gen cannot emit a fixture the canonical word rejects. The
gen itself is unchanged and still owes the sieg-surface fold-in (plus
`hp-idu`, the zone circuit and the LG parts the scada fixture now
carries by hand) before its next regen; it currently stops earlier on a
stale `house0-layout.json` diff-and-adopt path.

## 2026-09-02 — sim-spruce pair on the reshaped Nolan word; sim device types (`a36c5ce`)

The Nolan generator emits the per-tank element relays
(`tank1-top-elt-relay` / `tank1-bottom-elt-relay`, board silkscreen
unchanged) and the spruce power channels rename to element-first
(`buffer-top-elt-pwr`, `tank1-top-elt-pwr`, …) with their about-nodes.
Simulated devices come from `gw1.sim.device.type`: the board twin is
`SimGw108`, sim sensors `SimSensor`, the sim meter `SimPowerMeter`, and
the sim-spruce heat-pump parts are `SimHpOdu` (nothing talks to it) and
`SimSamsungAE055FEYMCG` (the control box hp-boss will practise modbus
against), with no device-type records. Snapshot rebuilt to carry the
new words (`i2c.dac.output.component.gt` listed explicitly beside the
writer it replaces; the sim enum listed because nothing $ref-s it).

## 2026-09-02 — component's local unique name now comes from ShNode name (`eaecf42`)

Three layouts exist in the field, and gw.house0.layout now means
has-a-siegenthaler-loop, so the three sieg-less homes cannot be authored
under it. New `house0_no_sieg_sema_gen.py` stub raises
NotImplementedError naming the missing word; the commented gen_elm /
gen_fir / gen_oak translation specs call it live at the top, and
gen_oak_sema.py — which was actively authoring oak as gw.house0.layout —
is guarded the same way. gen_house0_stub_sema.py carries a
fold-in-before-regen note: the scada test fixture it emits was
hand-extended with the sieg surface, and a regen without folding that in
would revert it. The Nolan generator gains the hp-boss command node
(HpBoss, auto.lc.n.hp-boss — required in every layout now) and the
sim-spruce pair regenerates with it; house0_sema_gen catches up to the
scada names commit (House0NodeNames is a flat vocabulary class — the
config's `n` property stops instantiating it, tank node helpers come
from Tanks). The vendored snapshot rebuilt from sema `2649929` (new
layout axioms, HpTwin); the sim pair regenerates clean through the new
validators. Found en route: the four sim.sensor BTU components re-mint
ComponentIds on every regen — the id-map key misses them; FIXED (the
sim branch's DisplayName prefix now matches the id-map lookup;
double-regen verified byte-identical). Both generators are sema-fied:
pydantic dataclasses with snapshot property formats (SpaceheatName /
PascalCase / HhMm / MacAddress / LeftRightDot) on every
vocabulary-shaped spec and config field, Literal for local axes,
`ct_channel` an Optional SpaceheatName (absence is absence, not "").
The board record renames with the enum:
`gw108.revb-gw1.scada.device.type.gt-000.json` with DeviceType
Gw108RevB (rev B named now because the next rev diverges
significantly); the snapshot rebuilt clean from sema `99ffd4f`
(Gw108RevB + Gw101 through the vendored words and samples).

Component identity now keys on ATTACHMENT, never caption — built
test-first (tlayouts' first test, `tests/test_component_id_stability.py`:
mangle every DisplayName in the reference, ids must survive; red under
the old keying). `LayoutIDMap` registers each component id under every
derivable key — `node:<referencing-node>`, board bindings
(`relay:`/`gpio:`/`dac:`/`adc:`), and a `type:<TypeName>#<ordinal>`
fallback — and all 22 `component_id` call sites pass attachment keys.
Migration proof: regen against the shipped pair is byte-identical.

The gw108 board joins the node world: the generator emits a `gw108`
equipment node (NoActor, ComponentId → the board record — the hp-odu
pattern), and the board is a DEFAULT hardware choice, not hardwired:
`board_node_name` + `board_record_file` config axes with gw108-revb
defaults (the hardware-decoupling direction; `gen_alt_nolan.py` — the
Nolan plant on House0-style hardware — is the coming N=2 proof, gated
on the krida retirement). The board component's id survived the
nodeless→node-referenced transition via the adoption keys.

The identity key then simplified to ITS ENDPOINT: the referencing
ShNode's bare Name (ComponentBinding — every component HAD by exactly
one node; ComponentId stays as the replaceable instance uuid under the
name). The web server got its node (`web-server`, a new CoreNodeNames
constant), making the Nolan artifact fully 1:1 (85 nodes); legacy
type-keys remain only for adoption and House0's krida trio (marked in
the gen; they dissolve with the retirement). Tests:
`test_emitted_components_are_node_bound` here, ComponentBinding
fixture tests scada-side (House0's skipped until the retirement).

## 2026-08-31 — sim-spruce: the simulated Nolan pair is authored; gens catch up to ops word + names tiers (`316d3ae`)

New sim variant of the spruce home config: same sensed nodes, simulated
drivers — tanks on `sim.pico.tank.module.component.gt`, BTU meters on
`sim.sensor.component.gt` + `SimSensorActor`, the board component on
`GridworksSimGw108` with the register-twin `gw1.scada.device.type.gt`
record copied from the real gw108 record (so address resolution cannot
drift), aliases `d1.isone.me.versant.keene.spruce.*`. The gen also emits
the pair's ops artifact as `gw.nolan.operational.params` (the family gen
had still emitted the house0-named word). The emitted pair replaces the
scada suite's hand-tended `tests/config/gw.nolan.{layout,operational.params}.json`.

Getting there took two catch-ups the gens owed: the snapshot re-vendored
with `gw.nolan.operational.params` (+ `gw.tou.window` closure) and the ops
assembly rebuilt to the post-08-13 word shape (`OpsSpec` gains
actuation_authority / service_mode / hp_max_kw_el / on_peak_windows;
system_mode and lat/long leave; all four home configs updated — the
house0-family stub/oak configs compile but their gens still point at a
deleted id-reference file); and the committed names tiers
(`local_control_normal` → Core, `vdc_relay` → HydronicSpaceheat). Gens run
against gwsproto at scada HEAD. Also per no-assumed-defaults:
`thermistor_zone_idxs`, `setpoint_source`, `thermostat_kind` are now
required per home/circuit. Entry to be reconciled against the diff at
commit time.

## 2026-08-31 — required Nolan surface: full plant relay set, HP parts, core sensing (`4be7fdc`)

Snapshot re-vendored on sema `44937ad`. `emit_plant_relays` emits the nine
relays axiom 3 forces (charge valve on the "DischargeValve" silkscreen;
store pump; four element relays); the Nolan system-actor skeleton drops
hp-boss / backup / scada-blind (return with the Nolan state-machine and
hp-boss-modbus waves); `emit_heat_pump_parts` + the `HpPartSpec` config
axis put the monobloc and control box into the layout as
`device.component.gt` components (nameplate serial on spruce's ODU) with
their hp device-type records (authored in `device_types/` from the
nameplate photos); the MIM-B19N rides the ctrl-box Description. The bench
carries the full sensing surface: four placeholder-uid BTUs and the new
`power_meter_kind="sim-egauge"` (spruce's channel list, imported from the
spruce config so it cannot drift, on the sim meter driver). All three
homes regenerate and validate; axioms proven to fire on isolated
counterexamples.

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

## 2026-08-14 — minor (`635cf57`): honeysuckle carries the full plant surface

Landed under the title "minor" (verified against the diff: 24 lines in
`honeysuckle_sema_gen.py` — zone-call circuits + plant relays + the
sim-uid `primary-btu` — plus deleting the superseded `-16sps-2hz`
variant artifacts). Original entry:

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
