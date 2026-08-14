# Changelog

A reverse-chronological log of WHY we made each commit **in the
`sema` code repo**. The matching git commit (in `sema`) holds the
WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-08-14 — harmonize scada operational params (`d2b163f`)

`gw.house0.operational.params` and `gw.nolan.operational.params` now
carry identical field sets. Both are `staging`, so this landed in
place: no version bump, no new `created`.

The two words had diverged along family lines — House0 held the
store/optimization knobs (`SeasonalStorageMode`, `HpTurnOnMinutes`,
`ShortCycleBuffer`, `LoadOverestimationPercent`, `OilBoilerBackup`,
`HorizonHours`) and Nolan held the cooling-season schedule
(`OnPeakWindows`, `HeldCircuitPositions`). That looked right, and it
made a Nolan home unbootable: surfaces that still run for *every*
family read the House0 knobs — the LeafAlly strategy selection, and
`layout.lite`, which requires `SeasonalStorageMode`, `Ha1Params` and
`BufferShortCycling` outright. A Nolan scada could not emit a
`layout.lite` at all.

So the store knobs join the Nolan word as deliberate, temporary
scaffolding. Nolan has no thermal store to season; they are there
because the functional code has not yet been moved off them, and they
come back out as it is. The Nolan word's `extended_description` says
so, so the next reader does not mistake convergence for intent.

`OnPeakWindows` moves the other way, onto the House0 word (with the
matching `PerDayWindowNonOverlap` axiom), and `HeldCircuitPositions`
is dropped — a hardcoded `HELD_CIRCUIT_POSITIONS` in Nolan local
control is the live authority, so the field was vocabulary that
nothing read.

`HpMaxKwEl` is new on both, as `positive.float`. It was a scada
deployment-config setting (`ScadaSettings.hp_max_kw_el`, defaulted to
9.66 and carrying a `# TODO: move to layout`), which put a
per-home hardware fact in the one artifact that is neither authored
nor per-home. `ha1.params` types it as bare `number`; the named
format is used here instead, per the authoring rule that primitive
constraints ride formats rather than inline keywords.

## 2026-08-13 — squash staging types (`c80eba8`)

A mid-process defect had spread across the vocabulary: a field change
against an already-`staging` (unpublished, still-mutable) version
kept minting a *new* version instead of editing the existing one in
place, so several types carried two or more staging versions where
one would do — `i2c.multichannel.dt.relay.component.gt` had 004 and
005 both staging, `spaceheat.node.gt` had 302 and 303, and so on.
Since staging is exempt from immutability, none of that duplication
was protecting real wire data; it was just drift. The fix is the same
recipe everywhere: take the later version's additional change, fold
it into the earliest staging version, delete the later version's
registry entry / schema file / axiom+upgrade templates, and repoint
every dependent (registry `direct_dependencies` *and* the schema's
actual `$ref` — the two drift independently, and only the `$ref`
breaks codegen) down to the surviving version number.

Squashed this way: `gw1.device.type` (enum, 000+001→000),
`ads.channel.config` (000+001→000), `dfr.config` (000+001→000),
`electric.meter.channel.config` (000+001→000),
`electric.meter.component.gt` (001+002→001),
`gw108.gpio.sensor.component.gt` (001+002→001),
`gw108.vdc.relay.component.gt` (001+002→001, folding forward the
already-squashed `relay.actor.config:003` dependency below),
`i2c.multichannel.dt.relay.component.gt` (004+005→004, leaving
published 002/003 untouched), `linear.one.dimensional.calibration`
(000+001→000), `pico.btu.meter.component.gt` (000+001→000),
`spaceheat.node.gt` (302+303→302), `web.server.component.gt`
(001+002→001). Same move already landed in this commit for
`relay.actor.config` (004→003) and `scada.control.capabilities`
(002→001) — both drop Unit/Exponent/capture-tuning fields, same as
the `*.channel.config` family above.

`i2c.thermistor.channel.config` (000/001/002→000) and
`i2c.thermistor.reader.component.gt` (000/001/002/003→000) got the
same squash despite `000` having been reinstated 2026-08-06 on a
"deployed layouts emit Version 000" wire-evidence claim: since only
`layout.lite` currently reaches rabbit, and `layout.lite` never
referenced either thermistor type, that evidence couldn't have come
from a live broker capture and the premise doesn't hold up — treated
as an ordinary duplicate instead, per Jessica's call.

`layout.lite` had accumulated three staging versions (013, 014, 015)
that never crossed a real wire — verified against `actual-spruce`
(still on the published `/012`, confirmed by a fresh fetch this
session) and the repo's own 2026-08-12 status-partition entry, which
found the same for the sibling unlimbo-line types. They collapse into
a single staging `013` carrying `/015`'s content verbatim (cac-free
`DeviceType` component versions — pico.tank.module 012,
sim.pico.tank.module 001, pico.flow.module 001,
i2c.multichannel.dt.relay 004 (post-squash) — plus spaceheat.node.gt
302 (post-squash), data.channel.gt 003; the 012→013 upgrade template
merged to context-dependent, combining the cac migration reason with
the field split below). `gw.nolan.layout` and the ops words already
ride this dependency set on `jm/layout-axioms` — `layout.lite` was the
one type still behind, exactly the drift the 2026-07-04 conformance
sweep flagged and nobody closed.

Same move: `SystemMode` drops from `layout.lite` (its sole reverse
dependency across every version 008–015 — confirmed via
`indexes/reverse_dependencies.yaml`) in favor of the `ActuationAuthority`
× `ServiceMode` pair minted earlier this session, closing the
conflation `gw1.system.mode` never resolved (Heating doubling as "full
authority"). `gw1.system.mode` stays published at `000`, untouched,
`replaced_by` already pointing at the two successors.

Same cluster: `gw.nolan.operational.params/000` gains `CopCurve` +
`HeatingCurve` (Jessica's call — Nolan's heat pump needs them same as
House0's; store knobs stay off since Nolan has no thermal store to
season). The two ops words now share six fields (`ScadaAlias`,
`CaptureTuningList`, `ActuationAuthority`, `ServiceMode`, `CopCurve`,
`HeatingCurve`) — no sema-side change for that (sema words don't
inherit), but gwsproto factors them into a shared
`OperationalParamsCoreBase` Python base class purely for code reuse,
matching the existing `ComponentBase` precedent; each word's own
schema stays flat.

Two pre-existing defects surfaced and got fixed along the way, not
just re-squashed: `electric.meter.component.gt/001`'s embedded
`ConfigList` example still carried `electric.meter.channel.config`'s
old (pre-squash) fields, caught by the round-trip validation test; and
`pico.btu.meter.component.gt/001` had a stray top-level
`extended_description` key outside `x-gridworks`, which the spec only
permits nested — folded into the correctly-placed one instead of
carried forward.

A separate, older wrinkle flagged before the squash pass started: unlike
the duplicates above, `scada.control.capabilities/001`'s
`I2cRelayComponent` field was pinned to
`i2c.multichannel.dt.relay.component.gt/002` — a `published`, cac-UUID-based
version carrying per-channel capture fields (`AsyncCapture`,
`CapturePeriodS`, `Exponent`, `PollPeriodMs`, `Unit`) directly on
`relay.actor.config`. It was never a squash target because `002` was never
a duplicate `staging` version; it just predated the type's move to
`DeviceType`/`I2cBus` at `004` and was left stale. Repointed the `$ref`
(and the embedded example) to `004`, editing `scada.control.capabilities/001`
in place since it is itself `staging`.

## 2026-08-12 — promote the gw.weather command round (`8d6ea57`)

`gw.weather.create.cmd/000`, `gw.weather.cmd.ack/000`, and
`gw.weather.cmd.nack/000` flip staging → published (hash-pinned in
`published_hashes.yaml`), clearing the weather service's step-7 prod
deploy: the create round was witnessed on the dev broker against the
released fabric (gwbase 0.5.9 self-edge) — empty boot, referential
refusals, six acks, record broadcasts in the delivery shape, and
emissions resuming on the minted records' schedule.

Squashed in: `snapshot prepare` now refuses before touching
`output/`. A prepare refused by the staging gate had already cleared
`output/`, leaving an empty snapshot dir where the previous build
stood — and a consumer's mirror step (`rsync --delete`) then guts
its vendored snapshot with no error of its own. The seed now expands
to a temp location and the staging closure validates there;
`output/` is cleared only after every refusal path has passed. (The
clean-checkout gate already ran first with a nonzero exit — the
hazard was the staging gate specifically.) A guardrail test pins
refusal-leaves-output-intact.

## 2026-08-13 — nolan ops word round: gw.nolan.operational.params + hh.mm / day.of.week / gw.tou.window + ScadaAlias; gw1.system.mode splits into actuation.authority x service.mode; gw.house0.operational.params slims in place (`c9fa26f`)

The operational-params cleanup round (spruce-unlimbo
`operational-params-cleanup.md`): the Nolan family gets its own ops
word instead of tuning itself through a house0-named artifact.
New vocabulary — `hh.mm` format (24-hour wall-clock minute,
published: formats never stage), `day.of.week` literal enum
(staging), `gw.tou.window/000` (staging: Start/End hh.mm + explicit
Days, so "weekends have no on-peak" is mechanical absence, not
prose), `gw.nolan.operational.params/000` (staging:
CaptureTuningList, OnPeakWindows, HeldCircuitPositions — so the TOU
constants can leave nolan.py in the scada follow-through; no store
knobs, curves join when Nolan heating control needs them). `gw1.system.mode` splits along its two
conflated axes instead of gaining Cooling as a fourth sibling (its
Heating value doubled as "full authority"; the spruce artifact said
Heating all summer while the hack cooled): new staging enums
`gw1.actuation.authority/000` (Active/Standby/MonitorOnly — default
MonitorOnly, so an unrecognized value degrades to non-actuation,
not full authority) and `gw1.service.mode/000` (Heating/Cooling,
inert outside Active — authority dominates). Both ops words carry
the pair as ActuationAuthority + ServiceMode; system.mode 000 stays
published with `replaced_by` pointing at the two. `gw.house0.operational.params/000` slims in
place (staging): GNodes out (identity is the layout's; nothing read
it), Latitude/Longitude out (site facts, back to scada settings
until TaValidator). Both ops words then gain required `ScadaAlias`
(left.right.dot) — a stored or emitted instance self-identifies
without its filename or envelope; one identity pointer, not the
dead three-GNode mirror, and the consumer can check it names the
paired layout's Scada ("right family, wrong house"). Ops↔layout family pairing is enforced by the
consumer decoding ops through the layout family's word — a
two-artifact invariant, so it lives in the scada load path, not an
axiom.

## 2026-08-12 — gw.nolan.layout axiom 3 LocalControlPlant: the plant surface is forced at decode (in `c15cb2d` "WIP")

Crash prevention moves from runtime cleverness into the layout
contract: a Nolan layout that cannot run Nolan local control is now
INVALID at decode. Axiom 3 (in place on staging 000) requires ShNodes
named iso-valve-relay / secondary-pump-relay / hp-scada-ops-relay and
non-empty Hydronic.ZoneCallCircuits with every circuit's
failsafe/ops relay node present. The NODE NAMES are the contract —
deliberately not the board-record RelayNames (hardware realization,
the axis-3 leak); gwsproto/names mirrors these constants, with the
sema word as the authority. First move of the names-into-sema thread
(chunk B): the vocabulary now owns required names; the full
names/venv-decoupling design is queued.

## 2026-08-12 — update spaceheat.node.gt to use the updated actor class (`91385fe`)

Correcting the 2026-07-07 initial status partition (`059f6ad`) where
its blanket "everything non-layout → published" default diverged from
its own first principle (published is owed to the broker archive —
wire-reached words): `spaceheat.node.gt/302+303`,
`new.command.tree/002`, and `scada.control.capabilities/002` were all
created on the unlimbo line (dev brokers only, bounded windows) and
have never crossed a real wire — the deployed lines emit
node.gt 300/301, command.tree 001, capabilities 000 (verified against
`main`/`dev`/`actual-spruce` mirrors). All four flip published →
staging (a human-sanctioned one-off against the one-way status
ratchet, sanctioned by Jessica 2026-08-12; nothing published
references any of them, so the published-closure rule holds) and
their sha256 pins drop. With 303 staging-mutable, its ActorClass
`$ref` moves to `gw1.actor.class/013` in place — layouts can now
declare `I2cDacWriter` nodes with no new node.gt version. Expected
ahead (not in this commit): NEW `new.command.tree` and
`scada.control.capabilities` versions as functional-scada surfaces
(the OPS-394 capability work) before the epic-end promote freezes
the closure.

## 2026-08-12 — gw.weather create command round: create.cmd + cmd.ack/nack (`b64e3dd`)

The weather service's write pattern (OPS-436 step 7): every record is
created by a human act whose request crosses the wire as a sema word,
on the gnr write pattern (`g.node.create.cmd` + twins). One common
command word — `gw.weather.create.cmd/000`, whose `Record` slot is a
closed oneOf over the four published record words (one create act
over four kinds; a fifth kind is a version bump, not a fifth word) —
plus `gw.weather.cmd.ack/000` / `gw.weather.cmd.nack/000`,
discriminated by TypeName and correlated by the command's content
hash. gnr's twins are not reused: their contracts bind the hash to
the registry's append-only command log. `Proof` stays the optional
authority-substrate placeholder. All three staging (dev-broker use;
`sema promote` gates prod, sequenced with the JK MVP in the design).
No axioms at 000.

## 2026-08-12 — i2c DAC ops vocabulary: write.byte + read.bytes, result/001, actor.class/013 (`1883372`)

The vocabulary the DAC-writer leg of spruce-unlimbo needs to ride the
I2cBus single owner. The published reg-op quartet cannot express the
TCA9548A mux select (a register-less byte write) or the MCP4728
EEPROM verify (a bare multi-byte receive, no register pointer) — the
3-byte DAC value write itself already fits `i2c.write.reg/000`. New
words `i2c.write.byte/000` and `i2c.read.bytes/000`;
`i2c.operation/001` appends WriteByte + ReadBytes;
`i2c.result/001` moves its Operation $ref to 001 and adds the
optional `Bytes` list for multi-byte reads (the $ref change forces
the version by rule; one result channel stays one word — settled
over a forked result vocabulary). `gw1.actor.class/013` appends
I2cDacWriter — the actor is registered in scada code but no layout
node could declare it. All new versions staging (in-process actor
payloads; promote rides the epic end). Runtime + indexes
regenerated; i2c.result/000 gains its upgrade path per the
superseded-version discipline.

## 2026-08-12 — Add GridworksSimGw108 to gw1.device.type; Mark I2cRelayBoard defunct in gw1.actor.class (`3524b73`)

Two small vocabulary touches from the spruce-unlimbo lane, landed as
one commit.

**GridworksSimGw108 on `gw1.device.type/001`** — in-place staging
addition (001 is staging — mutable, dev brokers only; settled over
cutting an 002). The simulated GW108 board gets its own device-type
value so sim boots declare it honestly instead of impersonating the
real board: the register-level sim backend rides the same board
record shape, and address resolution runs unchanged. Registry
`added_values` for 001 grows in place; the public-registry/versions
indexes and the canonical runtime enum regenerate mechanically
(`build_indexes.sh`, `regenerate_runtime.sh`).

**I2cRelayBoard defunct note on `gw1.actor.class/012`** — a
`value_descriptions` note on the published schema: the value was
never realized by an actor (the relay path landed as relay actors +
the I2cBus single owner instead), and additive-only evolution means
it can never leave the enum — a steering note is the only
instrument. Prose-only clarification on a published version per the
house allowance; the sha256 pin is re-recorded via
`python -m sema.tools.published_hashes --rewrite` in the same commit
(the reviewable-diff path for human-sanctioned corrections). The
block deliberately carries only this one entry — descriptions for
the other 25 values are a separate authoring task if ever wanted.

## 2026-08-12 — promote the gw.weather vocabulary to published (`c7be5ab`)

The eight-word closure behind the gwwf prod deploy flips staging →
published, dependency-leaves first: `gw1.quantity/002` (001 +
WindSpeed), `gw.weather.forecast.fidelity/000`, and the six
`gw.weather.*` type words at 000. Publication is the spec's prod
gate — staging vocabulary runs on dev brokers only, and gwwf's next
stop is the hw1 broker from its new box. Immutability begins here:
any further change to these words is a new version. sha256 pins land
in `published_hashes.yaml` and the public registry index regenerates
(`sema promote`; `created` untouched).

## 2026-08-12 — emission schedule moves to the bundle (`91b43f6`)

`EmitPeriodS`/`EmitOffsetS` leave `gw.weather.forecast.channel.gt`
and land once on `gw.weather.forecast.bundle.gt` (both staging,
edited in place): the bundle is the emission unit, so the schedule is
its fact — the SharedEmissionSchedule axiom dissolves into structure
and EmitOffsetBound moves to the bundle. The forecast-channel word
slims to series identity (name/target/forecaster/method/locator) +
slice structure, which is what skill-scoring needs from it;
observation channels keep their own schedule (observations remain
location-stream emissions).

## 2026-08-12 — weather messages hard-code quantities; bundle word (`f9c32d3`)

The gw.weather forecast vocabulary reshaped for its actual consumer
(all staging — edited in place / added / retired without version
ceremony). `gw.weather.forecast` becomes the FLO-curated contract:
hard-coded `TempChannelName`/`TempValues` +
`WindSpeedChannelName`/`WindSpeedValues` (a new quantity is a version
bump — the right ceremony for "the FLO's inputs changed"), one
message-level `FirstSliceStart`, `BundleName` in the payload (the
routing key's radio channel does not survive archival — the eventstore
key grammar drops it, so the stream identity must ride the payload),
and the two-clock split replacing the ambiguous `ForecastCreated`:
`SourceUpdatedTime` (the external service's underlying-data revision;
NWS's updateTime today) vs `MessageCreatedMs` (gwwf's emission stamp,
the report/glitch convention). The word speaks in the GridWorks
service's voice — gwwf IS the fleet's forecaster; upstream providers
are ingested sources named on channel records for skill-scoring.
`gw.weather.forecast.entry` retires (staging, removed outright).
`gw.weather.observation` gets the same treatment for symmetry of
ceremony: hard-coded `TempChannelName`/`TempValue` +
`WindSpeedChannelName`/`WindSpeedValue` (wind value optional — KMLT
sometimes reports none; absence is absence), `LocationAlias` in the
payload (same archival-honesty argument as BundleName), a
LocationNaming axiom (channel names begin with the location — the
swap-protection analog), and `gw.weather.reading` retires with it.
NEW `gw.weather.forecast.bundle.gt`: the sign-up record — embeds all
four channels as full subtypes (Temp/WindSpeed × Forecast/Observation)
plus a top-level LocationAlias, making every cross-fact an in-type
axiom (shared grid, shared schedule, target binding, quantity
targeting, location consistency, and Name = LocationAlias +
".forecast." + slug — the explicit observation↔forecast stream link:
the bundle slug extends the location alias that names the observation
broadcasts). `Name` is verbatim the broadcast radio channel; gwwf
still checks embedded copies against its canonical records at
seed/boot. One message per bundle per emission is the wire unit.

## 2026-08-11 — valve words (`9632077`)

The state/event vocabulary pair for two-position valves:
`valve.open.or.closed` (ValveOpen | ValveClosed) +
`change.valve.state` (OpenValve | CloseValve), literal, staging.
`change.valve.state` matches the legacy gwproto word of the same name
exactly (values and default), so the proactor port meets no collision.
States and events speak valve position, never actuator energization —
which position de-energized yields is deployment wiring data in the
relay's `relay.control.config` (`DeEnergizedState`, `WiringConfig`),
so an NC→NO valve rewire is a layout data edit, not a vocabulary or
actor change. First consumer: a hydronic isolation valve driven by a
board-resident i2c relay in the layout gen.

## 2026-08-11 — Snapshot-safe axiom templates: string comparisons over runtime imports (`47290f5`)

The gw.hydronic axiom-4 and gw1.zone.call.circuit axiom-2 validators
imported `sema.runtime.enums` method-locally for enums outside their
field set. Inside a restricted snapshot the package is the consumer's
(`tlayouts.sema`), the absolute import does not rewrite, and decoding
any instance raises ModuleNotFoundError — found by the first tlayouts
snapshot carrying the words. String comparisons replace the imports
(the enums are str-valued); axiom behavior unchanged.

## 2026-08-11 — Zone-call circuits in gw.hydronic; layout admits i2c relays and DAC writer (`b957c0d`)

The layout side of the zone/circuit model. `gw.hydronic/000` gains
optional `ZoneCallCircuits` (list of `gw1.zone.call.circuit`) plus two
axioms: CircuitResolution (every circuit's ServesZone names a zone in
Zones; positions distinct) and LearnedNeedsTempChannel — the
cross-record "Learned ⇒ the served zone has a temperature channel"
lands here because both lists live in this type, making the axiom
self-contained. Optional rather than required so House0 layouts stay
valid until their 1:1 circuits are generated (required at the epic-end
promote, under the both-cases bar). `gw.nolan.layout/000`'s Components
union admits `i2c.relay.component.gt` and `i2c.dac.writer.component.gt`
(the board-resident relay/DAC model the seed request pre-vendored). New
literal enum `change.zone.call.source` (SwitchToWallThermostat |
SwitchToScada) — the failsafe relay's event enum; published
`change.heatcall.source` is immutable, so the season-neutral pair
completes with a new word.

## 2026-08-11 — zone words (`1744a71`)

The zone/circuit/thermostat model from the spruce-unlimbo
zone-relays-and-thermostat-model spoke lands as vocabulary, all
staging (the promote holds to the epic's end). New enums: the circuit
FSM pair (`zone.call.circuit.event/.state`), the governance pair
(`zone.circuit.governance.event/.state`), `zone.call.source`
(season-neutral successor to published `heatcall.source`, which is
immutable and cannot be renamed), `setpoint.phase` (elevated from the
`derived_generator.py` embryo), and the circuit-record support enums
(`zone.actuator.kind`, `zone.circuit.role`, `zone.setpoint.source`,
`thermostat.kind`). New types: `gw1.zone.call.circuit` (the
stat→whitewire→relay-pair→actuator chain record),
`gw1.zone.thermostat` (promoted to a named type rather than inline
because the FromThermostat axiom must reference its Kind — axioms
cannot reach into inline objects), `zone.circuit.governance.cmd`
(SetGovernance, fsm.event-shaped + SetpointF), and `setpoint.belief`
(Phase ⇔ value presence). In-place staging edits: `gw1.hvac.zone/000`
gains optional `TempChannelName`; `gw1.scada.device.type.gt/000`
gains required `SupportsPinReadback`. Runtime regenerated with the
axiom validators implemented in the Jinja templates; the
gw1.scada.device.type.gt axiom fixtures gain the new required field;
indexes rebuilt.

## 2026-08-11 — Promote experiment words; add i2c hardware and gw.weather words (`1fccb23`)

One commit, three workstreams squashed at land time (the
hardware-merge repair plumbing folded in, invisible in the linear
history).

**Promotion —** `gw.experiment.run`, `gw.channel.gap.stats`,
`gw.channel.jump.stats`, `gw.channel.noise.stats`, and `gw.readings`
promoted staging → published (`sema promote <word> 000` ×5): status
flipped, schema sha256 pinned in `definitions/published_hashes.yaml`,
public registry regenerated — the schemas are now immutable; any
future change is a new version. The semafy-experiments design's
promotion gate is met: the folder set is done and multiple experiment
kinds exercise the words (ads-noise, the postmortem, the gap-analysis
re-run). The i2c family and `layout.lite/013` stay staging with the
scada thread, so consumer snapshots keep `--allow-staged`.

**Weather words —** `gw1.quantity` 002 (adds WindSpeed); new enum
`gw.weather.forecast.fidelity` (Unknown default as coercion target;
Live | Stored | SeasonalTemplate); new staging types
`gw.weather.channel.gt`, `gw.weather.forecast.channel.gt`,
`gw.weather.location.gt`, `gw.weather.observation` (+
`gw.weather.reading`), `gw.weather.forecast` (+
`gw.weather.forecast.entry`). Runtime and indexes regenerated; the
thirteen axiom validators implemented with counterexample fixtures.
This is the stand-up-weather-forecast design's vocabulary
(`wiki/gridworks-weather-forecast/designs/stand-up-weather-forecast/vocabulary.md`,
Accepted Pass 1) — the fresh `gw.weather.*` namespace replacing the
retired legacy `weather` / `weather.forecast` words.

**Hardware words —** six new staging words: `i2c.mux` (a
bus multiplexer as a first-class board-record entry) + `i2c.mux.type`
enum; `i2c.dac.writer.component.gt` + `i2c.dac.channel.config` (a DAC
writer component carrying per-channel EEPROM power-on defaults:
value/vref/gain) + `i2c.dac.channel` and `i2c.dac.vref` enums.
In-place staging additions: `i2c.dac.capability` gains
`MuxName`/`MuxChannel` (+ MuxPairing axiom);
`i2c.thermistor.interface.capability` gains required
`SupportedDataRatesSps` (the chip's conversion-rate menu);
`i2c.thermistor.reader.component.gt/003` gains required `DataRateSps`;
`gw1.scada.device.type.gt` gains `Muxes` + the MuxConsistency axiom
(membership, channel bounds, bus equality) and folds muxes into
BusMembership + BoardIdentifierUniqueness. Two coupling axioms
(ThermistorReaderMenuMembership, ThermistorSweepFitsPoll — the
SPS↔poll arithmetic with measured overhead and slack bound) join the
`gw.nolan.layout` axiom stash. Runtime/indexes regenerated; axiom
validators implemented with counterexample fixtures; created-stamp
cascade forward-bumped through both layouts.

The spruce-unlimbo takeover needs the layout to say
everything the summer hack knows. The gw108's three MCP4728s share
address 0x60 behind a TCA9548A, so without the mux the board record
cannot distinguish them — "the secondary pump is on dac2" was
unsayable. DAC EEPROM defaults are persistent, readable chip state
the scada verifies at startup, so they belong on a component record;
the ADS data rate is the opposite (a per-conversion config word), so
it rides the reader component with the capability menu and axioms
keeping choice, menu, and poll rate mechanically consistent
(decision + arithmetic: `wiki/hardware/gw108-provisioning.md`).

## 2026-08-10 — add gw.channel.gap.stats (`208cf81`)

**What:** on `jm/gap-stats-word`. New staging word
`gw.channel.gap.stats/000` — reporting-gap statistics for one fleet
channel over one archive window (silence counts/durations against a
cadence-aware threshold max(AbsGapS, MedianMult × MedianCadenceS),
whole-house-silence exclusion counted separately) — the
`gw.channel.jump.stats` sibling for the dropout canary. Schema +
registry entry + regenerated runtime/indexes + the three axiom
validators (WindowOrder, NonNegativeDurations, GapAccounting a/b).

**Why:** the pico-gap-analysis re-run's per-channel gap rows were
kind-specific JSON with no contract; gap statistics are channel
statistics the same way jump statistics are, with multiple consumers
ahead (gap-analysis folder, dropout canary view, rejoin/link-census
verifications), so they earn vocabulary.

---

## 2026-08-10 — codec expect= narrowing (SemaCodec.from_dict/from_file) (`03e068b`)

**What:** on `jm/channel-noise-stats`. The codec template's `from_dict`
gains an `expect: type[T]` keyword (typed via overloads: passing it
returns `T`, narrowing at the call site; omitting it keeps the
`SemaType | DegradedSemaType` union) and raises with both type names on
mismatch; a `from_file(path, expect=...)` convenience joins it. The
existing decode logic is untouched, renamed `_decode` behind the
wrapper.

**Why:** make the safe idiom the shortest idiom. Consumers currently
write decode + `assert isinstance(x, Word)` in two steps or skip the
narrowing (the exact failure the experiments repo's pyright gate keeps
catching); `codec.from_file(path, expect=GwReadings)` is one line that
cannot skip it. Companion to the GridWorks_CLAUDE sema-aligned coding
maxim.

## 2026-08-07 — add gw.readings (`12ff3ee`)

**What:** on `jm/channel-noise-stats`. New staging type `gw.readings/000`:
a self-contained archive pull — the terminal asset, the window, the
channel words themselves (oneOf data.channel.gt/derived.channel.gt), and
their channel.readings — so pulled data travels WITH its semantics and
no consumer ever reads meaning off database columns. Axioms: window
order; every readings entry's channel appears in Channels.

**Why:** the database is storage, not truth. pull_readings reconstitutes
rows into sema objects at ingress and emits one gw.readings instance;
units and display conversion derive only from the carried words.

## 2026-08-07 — gw.channel.noise.stats/000 (staging) (`7f27e04`)

**What:** on `jm/semafy-experiments`. One new staging type:
`gw.channel.noise.stats/000` — noise statistics (sample count, mean,
sd, peak-to-peak) for one fleet channel over one measurement window,
paired with the channel's own sema object via
ChannelTypeName/ChannelVersion and speaking its serialized units, with
an optional ConditionLabel tying the stats to a kind-specific condition
(e.g. an ads read mode) whose meaning lives in the experiment README.
The bench-stats sibling of gw.channel.jump.stats, same pairing pattern.

**Why:** retires the last dict-shaped result data in the experiments
repo — the ads-noise bench summaries become validated instances (µV
stats paired with the -gw-microvolts channel, temperature stats with
the -gw-temp channel, so both speak an existing channel's units and no
unit vocabulary is invented). Deliberately NOT emitted for the
postmortem window: reported-value variation there is real thermal
signal, and labeling it noise would misdescribe it.

## 2026-08-07 — reinstate field-emitted 000s: i2c.thermistor.reader.component.gt/000 + i2c.thermistor.channel.config/000 (`318e743`)

**What:** on `jm/semafy-experiments`. Two historical staging versions added
BELOW their lineages, `created` backdated to just before the 001s: the
fleet's deployed layouts (spruce, since the July deploy) emit
`Version: "000"` records for both words, disproving the 001 summaries'
"never-emitted sema 000 was dropped" belief — the archive is the truth
the word must describe. Both 000s are field-for-field identical to their
001s (pure version restamps), so the 000→001 upgrades are Version-only;
the 001 summaries' stale clause is corrected. Examples derived from the
archived spruce layout record.

**Why:** the experiments snapshot (gwexp) can now decode today's deployed
layouts typed — the ads-noise harness's legacy dict-walk fallback dies,
and every consumer of pre-registry layout records gets schema+format
validation instead of raw dict access.

## 2026-08-06 — experiments vocabulary: gw.experiment.run + gw.channel.jump.stats (staging) (`56f9883`)

**What:** on `jm/semafy-experiments`. Two new staging type words for the
semafy-experiments design (OPS-490): `gw.experiment.run/000`
(experiment result metadata: kind slug as spaceheat.name, host GNode
alias, wall-clock window, optional code ref) and
`gw.channel.jump.stats/000` (jump/spike statistics for one fleet channel
over one archive window — the canary element). The stats word declares
no units of its own: it pairs with the channel's own sema object via
ChannelTypeName/ChannelVersion (data.channel.gt's TelemetryName implies
the wire unit; derived.channel.gt's OutputUnit declares it) and speaks
that channel's serialized units.

**Why:** experiment results become validated sema instances instead of
ad-hoc JSON (pilot: ads-noise at spruce; the archive canary flagged the
board three days before its late-July chip failures). Vocabulary policy
settled in the design: only words serving multiple experiment kinds,
gw-prefaced, staging until a second experiment kind exercises them;
units are never restated where a channel word already declares them. A
gw.display.unit enum was drafted and withdrawn pre-commit (no consumer
under the pairing design; parked on OPS-489 as display()'s codomain).

## 2026-08-06 — position-point lifecycle: g.node.gt/006 + referrer sweep (`9e3c684`)

**What:** on `jm/position-point-lifecycle` (authoring + promotion squashed
to one commit). Four new versions, authored staging then `sema promote`d
dependency-first to **published** (sha256 pins in
`definitions/published_hashes.yaml`; the three staging layout referrers
stay staging). Promoted ahead of the gw_data-side review by explicit
decision: publishing unblocks the consumer-refresh cascade, and review
disagreement, if any, arrives as new versions. The versions:
`g.node.gt/006` — axiom 2 (*PhysicalGNodeLocations*) becomes
activation-conditioned ("If Status is Active and BaseClass != Logical,
PositionPointId SHALL NOT be null"), PositionPointId description reworded
to the lifecycle (null until a location is registered), new
Pending-physical example. `g.node.forest/002` — Nodes rebind to :006,
`SendTimeMs` joins `required`, prose trimmed to the field's own meaning.
`g.node.create.cmd/001` — rebind + new axiom 1 *LocationlessAtCreation*
(`NewNode.PositionPointId SHALL be null`); composed with g.node.gt/006
axiom 2, physical GNodes enter Pending. `g.node.reparent.cmd/002` —
rebind only. Staging referrers rebound in place (`gw.house0.layout/000`,
`gw.house0.operational.params/000`, `gw.nolan.layout/000` + embedded
example versions), their `created` stamps forward-bumped to the 006
sitting (dependency-timestamp ordering). Indexes + runtime regenerated;
new-version upgrade/axiom implementations ported (forest 001→002 upgrade
refuses without SendTimeMs; create.cmd 000→001 refuses when a
PositionPointId is carried — an upgrade never fabricates or drops); new
v006 fixtures (Pending-locationless default; Active-locationless axiom-2
counterexample). g.node.gt/006's extended description records the
composition with create.cmd/001: activation requires holding a position
point, and a Pending node may hold one — registration and activation are
separate acts on separate planes.

**Why:** the position-point-lifecycle design (OPS-488): position-point
presence becomes an activation invariant instead of a creation invariant,
clearing the way for gnr's encrypted location store with a real FK, and
the forest bump doubles as the sender-time required-flip (OPS-472's first
adopter finishing the adoption).

**Why:** The api-types review exposed two enforcement gaps. First, the
runtime generator silently degraded a metaschema-illegal construct
(`type: [{$ref: …}, "null"]`) to `list[Any | None]`, so a format
mismatch stayed invisible. Second, gjk and gridworks-web-backend store
enum states as positional indexes — a scheme resting on the spec's
append-only enum-order rule (`spec/authoring/enums.md` "Evolution
Rules"), which was declared but not mechanically enforced. Four
guardrails: (1) every schema file under `definitions/` must validate
against the JSON Schema 2020-12 metaschema — a registry test plus a
build gate at the top of runtime regeneration, so an illegal schema
fails the build instead of generating garbage (new `jsonschema`
dependency); (2) the generator's bare-`Any` fallbacks (unresolvable
$ref, un-narrowable type list, unknown construct) now raise naming the
schema and property — the deliberate open-object `dict[str, Any]`
mapping stays, it is a faithful rendering; (3) each versioned enum
version's `enum` list must start with the previous version's list
verbatim (append-only, enforced across versions; published-hash
pinning only froze each version's own file); (4) generated runtime
enum classes must carry values in exactly the definition file's order
(artifact-level check that catches generator reordering bugs the
prefix test cannot); (5) every property key in a type schema —
recursively through inline objects — must be PascalCase (spec Principle
2, previously unenforced: the existing name tests police lowercase
dotted word names, not the wire field names). A coverage audit found
the other suspected gaps already closed (enum default membership,
examples decoding through the generated runtime). Negative tests
(`tests/test_guardrails_fire.py`)
prove each guard actually fires on the original illegal construct —
they also documented that non-canonical $ref URLs were already rejected
by `normalize_ref` before the generator's new check (kept as
defense-in-depth).

## 2026-08-05 — PR changes to synced.readings.bundle and operating.state.sequence (`e071165`)

**Why:** Review of the jds/api-types PR against field data (beech report
`f32945f7`, 2026-02-10) showed `operating.state.sequence/000` could not
carry real machine states: values are PascalCase enum values, which
`spaceheat.name` rejects (masked because the invalid
`items: {type: [$ref, "null"]}` union generated `list[Any | None]` —
nothing was enforced), and real transitions arrive milliseconds apart
(12 ms in the beech report), so `utc.iso8601.seconds` timestamps
collide. Revised in place (staging): ValueList → `pascal.case`,
TimestampList → `utc.iso8601.millis`, new strictly-increasing axiom,
extended_description reframing the type as a projection of
`machine.states` into an analytics channel — with a verbatim beech
example on a curated analytics channel
(local-control-all-tanks-state) and a note that debugging a failed state change
means going back to the reports' `machine.states` (the projection drops
StateEnum and the chain-of-command MachineHandle). The
extended_description also pins the gap decision: unknown-state spans are
expressed by absence, and `None` is deliberately not a defined value
(field reports re-assert every machine's state each slot, so gaps only
mean the SCADA wasn't reporting — window-shaped information, not a
sentinel's job).
`synced.readings.bundle/003`: described LatePersistenceTimePeriodList
(windows whose readings were persisted late/backfilled) and added axiom
6 well-formedness (exactly-two elements, ordered, within the bundle
span); fixed stale `ChannelDefinitions` references left from an older
shape, scoped the "rectangular, time-aligned" language to
ChannelReadingsList (state sequences are event-form, not grid-aligned),
and gave the bundle example a non-empty
OperatingStateSequenceList (the beech local-control sequence rebased
into the example's window, real millisecond digits kept). Runtime tests
added for both.

## 2026-08-04 — Remove CLAUDE.md; move contributor mechanics into README (`a8d75af`)

**Why:** The repo shipped a tracked `CLAUDE.md` that presumed a specific
AI-assisted setup — a `/make-sema-word` slash command and umbrella-wiki
machinery that don't exist in this repo — and its Universal MUSTs restated
what the spec already governs. A public repo should not presume
contributors' tooling; the spec stays canonical for all vocabulary rules.
The durable contributor mechanics moved to `README.md`: the
topic-branch-off-`dev` convention (Contributing) and the new-type-version
delta discipline (the three coupled places + the nested-upgrade lift
rule). Also dropped a private-wiki pointer from `snapshot_lint.py`'s
docstring — repo files stand alone; the follow-up reference now points at
the in-repo snapshot spec.

## 2026-07-29 — g.node.forest/001: optional SendTimeMs, published (`6f910aa`)

**What:** New version 001 of `g.node.forest`:
optional `SendTimeMs` ($ref `utc.milliseconds`) — the sender's clock at
forest assembly, per the sender-time standard (wiki sema design, OPS-472).
The word's description records the invariant: the registry stamps
wall-clock; it is a notary and is never simulated. Registry entry
(latest 001, utc.milliseconds joins structural deps), upgrade template
000→001 (dump → version bump → validate; docstring mirrors summary),
indexes + runtime regenerated, promoted to published (hash pin).

**Why:** first adopter of one uniform name for
time-as-the-sender-understands-it — the created-at field zoo
(CreatedMs/TimeCreatedMs/UnixMs/…) converges on SendTimeMs as words
naturally version. Immediate consumer value: gjk's registry projection
gains an order-aware guard input; hybrid-universe sim-time analytics get
a uniform slot.
**Verified:** registry validation + full sema suite green.

## 2026-07-28 — snapshot CLI: clean-checkout guard; no repo-tree writes (`e161c90`)

**What:** two pieces, squashed to one commit. (1) New executable
`template_regen_snapshot.sh` at the repo root, beside
`template_seed_request.yaml`: the generic form of a consumer repo's
`scripts/regen_sema_snapshot.sh` (prepare + build + rsync-mirror), with
three CHANGEME facts (package name, seed path, vendor dir) and a loud
refusal while unedited — the seed template covered what a snapshot
contains, but each new consumer repo reinvented the wiring script; the
pair now travels together. (2) `cli/snapshot.py`. `sema snapshot
prepare`/`build` refuse to run from a dirty sema checkout (SystemExit
listing the dirt; skipped gracefully outside a git checkout). `prepare`
computes the public registry in memory instead of rewriting
`indexes/public_registry.yaml` in place — the snapshot path now writes
nothing into the repo tree (`output/` only) — and refuses when the
committed index is stale against `definitions/registry.yaml` (fix:
`scripts/build_indexes.sh`). `build_indexes.sh` and `sema promote` keep
writing the index; that is their job. The three snapshot test files drop
their monkeypatches around the old in-place write.

**Why:** a consumer regen (gjk, 2026-07-28) showed the in-place write
riding a branch switch and getting swept into an accidental commit
alongside concurrent WIP. A snapshot must be reproducible from a commit
hash and leave the repo exactly as it found it; consumer regen scripts no
longer need their own guard/restore choreography.
**Verified:** suite 393 passed + 1 xpassed; ruff check + format clean on
the four touched files.

## 2026-07-28 — gw.hydronic: the hydronic block is strategy-shared (`6d496b1`)

**What:** `gw.house0.hydronic` renames to `gw.hydronic` (staging, in place —
single referrer, no independent artifacts): nothing in it was
house0-specific (Zones, TotalStoreTanks, UseSiegLoop, SiegLoopPlumbed,
PrimaryFlowSource, and Strategy — whose job is distinguishing House0 from
Nolan). `gw.house0.layout` re-points its Hydronic `$ref`; `gw.nolan.layout`'s
Hydronic goes from open object to the typed `$ref` — Nolan is a hydronic
heating system and now says so in the contract.

**Why:** the names hierarchy already shares the hydronic layer across
strategies; the layout words now match it.

---

## 2026-07-27 — Board-resident model + description-placement sweep: BoardComponentId anchoring, scada.board.component.gt, CT capability (`f6f5462`)

**What (this cluster, 7/23 + 7/27):** the board-resident component model lands
whole. New words: `scada.board.component.gt/000` (the physical board instance
that device components anchor to), `i2c.ct.interface.capability/000` (CT
sibling of the thermistor interface; circuit facts land as extracted from the
schematic), `gpio.sensor.component.gt/000`. In-place staging reshapes:
`gpio.sensor` and `gpio.relay` and `i2c.thermistor.reader/003` gain required
`BoardComponentId` and lose `DeviceType` (TypeName is the kind; the board
component carries board identity); `SendToDerived` dropped from
`gpio.sensor.component.gt` and `i2c.thermistor.channel.config/002` (derived
routing is computable from DerivedChannel InputChannelNames);
`gw1.scada.device.type.gt` gains axiom 3 (BoardIdentifierUniqueness — one
silk-screen namespace per record) and its CtAdc re-types to the CT capability;
`gw.nolan.layout` union gains the board component and axiom 2
(BoardResolution: BoardComponentId resolves, board record matches, named
pin/ADC exists). Deleted outright: `i2c.adc.capability` (staging-only, single
referrer, no independent artifacts — the gw108.gpio.relay-placeholder
precedent); `replaced_by` on the two gw108-prefixed words.

Also in this cluster: `i2c.relay.component.gt` reshaped the same way
(required BoardComponentId, no DeviceType), and the description-placement
sweep — property descriptions and top-level word descriptions no longer
reference other sema words informally; those pointers moved to
`extended_description` (33 words touched; formal `$ref`s untouched).

**Why:** function belongs to the board's pin registry and node/channel names,
never the vocabulary word; silk-screen names are only unique per board, so
resolution must run through an explicit board instance; overlapping layout
information is legible when axioms enforce its consistency; prose references
in descriptions drift, so informal cross-word pointers live only in
`extended_description`. Decided with Jessica 7/26-27.

**What:** new staging word `gpio.sensor.component.gt/000` (the native-GPIO
input sibling of `gpio.relay.component.gt`: GpioName against the board's
NativeGpioInputs, SenseMode, SendToDerived, no ConfigList); `replaced_by`
markers on `gw108.vdc.relay.component.gt` (→ gpio.relay.component.gt) and
`gw108.gpio.sensor.component.gt` (→ gpio.sensor.component.gt); the
`gw.nolan.layout/000` components union swaps to the two board-generic words;
indexes + runtime regenerated.

**Why:** parallel structure — function (Vdc) belongs to the board's pin
registry and the node/channel names, never the vocabulary word; the modern
mechanism-named pair already existed with board-record pin resolution, and
the gw108-prefixed words were the odd ones out on both axes. Decided with
Jessica ahead of the dev-spruce layout gen so the first artifact emits the
modern shapes.

---

## 2026-07-23 — bump data channel and g node in gw.nolan.layout (`ea08ebb`)

**What:** in-place staging update of `gw.nolan.layout/000`: the `sh_nodes`
and `data_channels` `$ref`s move from `spaceheat.node.gt/302` and
`data.channel.gt/002` to `/303` and `/003`; registry deps + summary updated;
indexes and runtime regenerated.

**Why:** the word pinned the pre-InPowerMetering-fold versions while its own
axiom 1 declares that flag replaced by the transactive-power channel — and
the consumer already runs post-fold (scada's `nolan-layout.json` fixture is
303/003; gwsproto NolanLayout uses latest). Staging words are mutable in
place; this aligns the contract with demonstrated reality ahead of the
dev-spruce layout gen (OPS-392).

---

## 2026-07-21 — g.node.cmd.ack + g.node.cmd.nack v000, published (`a663914`)

**What:** the registry's write-command reply words. `g.node.cmd.ack/000`
(`CommandHash`) and `g.node.cmd.nack/000` (`CommandHash`, `Reason`) — success
vs refusal discriminated by TypeName, never a field; correlation by the
command's content hash (an opaque string — the hashing scheme stays
registry-internal per the content-address exploration). Both promoted to
published in the same change.

**Why:** the write path was fire-and-forget, so a refusal was silence — the
operator learned of it by a 20-second poll timeout, and the reason lived only
in the registry's journal. With typed replies riding the bus, the sender gets
an instant verdict and the ear's capture makes every refusal a first-class
audit record with its reason attached.
**Verified:** sema suite 393 green (incl. both words' generated round-trip
tests); promote closure checks.

## 2026-07-21 — g.node.reparent.cmd/001: optional Proof, published (`c4b3536`)

**What:** new version 001 adds optional `Proof` (opaque authorization
artifact, mirroring `g.node.create.cmd`'s field); 000 untouched. Upgrade
template is a pass-through version lift; promoted `staging → published` in
the same change (pin recorded). Runtime regen rebinds the versionless class
to 001 and adds the explicit `GNodeReparentCmd000`.

**Why:** the registry's stop-gap write authorization hash-verifies a Proof on
every write command; create already carried the field, re-parent did not. A
new version rather than an in-place edit — 000 was published (2026-07-20) and
published means immutable, even at one day old with zero wire traffic.
**Verified:** sema suite 391 green (incl. the generated 001 round-trip +
upgrade tests); promote's closure check.

## 2026-07-20 — Publish g.node.create.cmd v000 (`f1155e4`)

**What:** `sema promote g.node.create.cmd 000` — `staging → published`,
schema sha256 pinned in `definitions/published_hashes.yaml`, public registry
regenerated. No schema content change.

**Why:** the grid-node-registry deploys to the `hw1` broker, and staging
words are dev-broker-only; with this flip every word the gnr snapshot vendors
is published, clearing the word-status gate for the deploy.
**Verified:** promote's own closure check + full sema suite 389 green.

---

## 2026-07-19 — Gw108Adc + i2c.thermistor.reader.component.gt/003: board-resident ADC (`e9b050f`)

**What:** on `jm/single-bus-owner` (off dev post-merge). `Gw108Adc` appended in place to
staging `gw1.device.type/001` (board-resident ADC category, the `Gw108I2cRelay` pattern).
New `i2c.thermistor.reader.component.gt/003` (staging): drops `Bus`, `AdcAddress`,
`AdcReferenceVolts`, `SeriesResistanceKOhms` — all facts on the board record's
thermistor-interface capability entries — and adds required `AdcName` naming that entry
in the board's `ThermistorAdcs`; `DeviceType` value becomes the ADC's own (`Gw108Adc`,
was the board's). The `002→003` upgrade is context-dependent
(`upgrade_requires_context`, same as this type's `001→002`): `AdcName` derives from
matching `AdcAddress` against the board record, which a standalone payload doesn't
carry. Delta recorded in the three coupled places; axiom 1 (ChannelNameUniqueness)
ported to the 003 axiom template. `gw.nolan.layout/000` (staging, in place, the reader's
only referrer) moves its Components oneOf to `:003`, with the created-stamp
forward-bump the dependency-ordering rule requires; no embedded example to re-emit.
Suite 390 passed.

**Why:** the single-bus-owner prerequisite (spruce-relay-control spoke) and step 2 of
the pulled-forward i2c-board-components plan: the board record is the single source of
physical truth, so the reader component stops carrying physical facts and the scada's
ADC reads can move onto the serialized `I2cBus` actor. Companion scada work follows
(twin alignment, reader actor off blinka/adafruit onto bus-ops).

## 2026-07-19 — adding examples to the new hp-related device types (`2925363`)

**What:** on `jm/i2c-relay-capability`. `examples:` added in place (staging) to
`hp.device.type.gt/000` and `hp.control.box.device.type.gt/000`, with real Samsung AE055
nameplate data from the Drive transcription doc ("Nameplate data — AE055FCYDCG +
AE055FEYMCG (transcribed)"): ODU 54,600 Btu/h heat & cool, compressor 18.9 A, R32,
MCA/MOP 32/40; box water pump 0.9 A, BackupHeaterKwList [2, 4]. `MaxKwEl: 4.35` is
derived (18.9 A × 230 V), not a nameplate line — JM to confirm or correct. Box example
omits Mca/Mop (nameplate lists them per backup-heater config — wrinkle captured in the
hp-device-types spoke). Suite 388 (each example now decodes through the generated
runtime).

**Why:** the examples are the conformance fixtures: the scada `gwsproto_sema_conformance`
sweep decodes each word's canonical example through the gwsproto twins — with them, both
hp words moved to fully conformant (36 → 38). Companion gwsproto commit adds the twins.

## 2026-07-19 — hp device-type families; SamsungAE055 values; .gt seed-coupling notes (`69bcac8`)

**What:** on `jm/i2c-relay-capability`. Two new staging record families, flat,
`DeviceType`-keyed (the `ads111x.based.device.type.gt` pattern): `hp.device.type.gt/000`
(compressor-bearing units — required DeviceType, MaxKwEl, HeatingCapacityBtuHr,
CoolingCapacityBtuHr + the three primary-pump facts; optional Refrigerant,
CompressorRatedAmps, Mca, Mop, ProductInfoUrl, DisplayName) and
`hp.control.box.device.type.gt/000` (control boxes — the monobloc's indoor unit:
hydraulics, control electronics, local touch-screen, ODU comms; required DeviceType + the
three pump facts; optional WaterPumpRatedAmps, BackupHeaterKwList, Mca, Mop,
ProductInfoUrl, DisplayName). `ProductInfoUrl` (plain string, both families) links the
publicly accessible product-info folder — the GridWorks pattern of a public Drive folder
per device category with manuals, nameplates, wiring diagrams, controls notes. The `.gt`-convention
`extended_description` note (`.gt` = coupled bijectively with a canonical-seed table;
position doc: `wiki/vision/where-meaning-lives-in-gridworks.md`) swept across all 30
seed-coupled `.gt` words (latest non-draft versions), each naming its seed database —
terminalasset registry for layout words, grid node registry for `g.node.gt` +
`connectivity.edge.gt`, FIS for `g.node.instance.gt`. Excluded as not seed-coupled
(embedded value objects, `.gt` by naming inertia): `position.point.gt`, `hubitat.gt`,
`hubitat.poller.gt`, `maker.api.attribute.gt`; also excluded: the two `replaced_by` CAC
words and the draft `gw108.gpio.relay.component.gt`. The 7 published words in the sweep
were re-pinned via `published_hashes --rewrite` (JM-sanctioned; prose-only, no validation
change). The three primary-pump facts
(PrimaryPumpFactoryInstalled / PrimaryPumpOverridable / PrimaryPumpAlwaysOn) are REQUIRED
on both — no assumed defaults. Staging `gw1.device.type/001` appended in place:
`SamsungAE055FCYDCG` (spruce ODU) + `SamsungAE055FEYMCG` (spruce control box). Indexes +
runtime regenerated; suite 386 passed; new-type round-trip smoke-checked.

**Why:** hardware-layout-pass-one (OPS-407), the hp-device-types spoke: retire
`gwsproto.enums.HpModel` + `ScadaSettings.hp_model`'s silent default into the device-type
model — heat pumps need exact-designation identity because control code branches on model,
and the maple pump-doctor defect (OPS-450) is the running cost of the pump facts having no
structured home. Enum values appended in place per JM decision (a); nameplate-grounded
mints for the legacy four HpModel values follow as nameplates are confirmed. Scada-side
follow-on (gwsproto twins, consumer call sites, thin `hp-ctrl-box` components) is its own
gating.

## 2026-07-13 — cop.curve + heating.curve; operational-params control block (`7657167`)

**What:** on `jm/i2c-relay-capability`. Two new staging words: `cop.curve/000` (Intercept,
OatCoeff, LwtCoeff, Min, MinOatF — COP = Intercept + OatCoeff·OatF + LwtCoeff·LwtF, floored at
Min below MinOatF) and `heating.curve/000` (AlphaTimes10, BetaTimes100, GammaEx6 heat-loss
coefficients + the intermediate and design-day anchor points + MaxEwtF).
`gw.house0.operational.params/000` (staging, in place) gains the control/optimization block —
SystemMode (`gw1.system.mode`), SeasonalStorageMode (`gw1.seasonal.storage.mode`), CopCurve,
HeatingCurve, HpTurnOnMinutes, ShortCycleBuffer, LoadOverestimationPercent, OilBoilerBackup,
HorizonHours, Latitude, Longitude — all REQUIRED (no assumed defaults); description, example,
and extended_description rewritten to present tense. Created-stamp cascade bumps ops-params to
the new words' stamp. Indexes + runtime regenerated; suite 386 passed.

**Why:** hardware-layout-pass-one (OPS-407), the operational-params spoke's post-boot step: the
tunable state that changes without rewiring hardware moves out of scada deployment config into
the authored third artifact. The two curves get their own words because they are reusable
concepts (`flo_params` assembly is the eventual DRY consumer). The hydronic-sourced trio
(UseSiegLoop, CriticalZoneList, ZoneKwhPerDegFList) is deliberately NOT added yet — it moves
when `gw.house0.hydronic` strips, so every value has exactly one authored home at every commit
point. Companion gwsproto + tlayouts commits.

## 2026-07-09 — capability words: i2c.relay.capability + i2c.expander; board record reshaped (`3c7e3fb`)

**What:** on `jm/i2c-relay-capability`. Five new staging words + one staging reshape.
`i2c.relay.capability/000` replaces `i2c.relay.config` — RelayName (the device's physical
marking), ExpanderIdx, RegisterIndex, BitIndex, SupportedWiringConfigs; no I²C address.
New `i2c.expander/000`: one GPIO expander on a board — ExpanderIdx, I2cBus, and exactly one of
`I2cAddress` (soldered) / `AllowedI2cAddressList` (DIP-selectable), axiom-enforced. The three
staging siblings rename for the same reason: `i2c.adc.config` → `i2c.adc.capability`,
`i2c.dac.config` → `i2c.dac.capability`, `i2c.thermistor.interface.config` →
`i2c.thermistor.interface.capability` (old staging words deleted). `gw1.scada.device.type.gt/000`
(staging, in place) gains `Expanders`, re-points its refs to the capability words, extends Axiom 1
BusMembership to Expanders and adds Axiom 2 ExpanderMembership, and swaps its giant gw108 example
for a minimal krida-flavored one. Published `i2c.relay.config/000` stays frozen with word-level
`replaced_by: [i2c.relay.capability]`; `i2c.bit.address` stays published (the bus-op words use it).
Created-timestamp cascade forward-bumps `gw1.scada.device.type.gt:000` and the two layouts
(`gw.house0.layout:000`, `gw.nolan.layout:000`) to the new words' stamp. Axiom validators
implemented in the templates (the expander stub + the reshaped board axioms); the
gw1.scada.device.type.gt counterexample fixture rewritten to the new shape + an Axiom 2
counterexample added. Indexes + runtime regenerated; suite 384 passed.

**Why:** hardware-layout-pass-one (OPS-407), prompted by the gw108-at-beech board swap. Two words
both named "config" meant opposite things — `relay.control.config` is the *chosen* configuration,
`i2c.relay.config` the *offer*; "capability" says what is possible. The DIP-switch reality forced
the address out of the per-relay entry: allowed addresses are a board-type fact (the expander
entry), the chosen address a deployment fact (the component's `I2cAddressList`, index-aligned with
Expanders). Supersede-not-demote keeps published history immutable — nothing ever moves published →
staging in a commit. The record's RelayNames carry physical markings (`Relay1`–`Relay32` on the
krida panel) so field support can identify relays from the record; the panel's first-bank inversion
becomes declared pin data instead of `gw_to_pin` driver arithmetic (scada-side instance in the
companion `gridworks-scada` commit).

## 2026-07-08 — g.node.create.cmd v000: registrar-facing create (staging) + branching note (`24fdd1f`; re-landed on dev-lineage 2026-07-20 as `29af7e8` — the authoring branch had strayed from the no-long-lived-vocabulary-branch rule its own branching note states)

**What:** new type `g.node.create.cmd/000` (`status: staging`) — `NewNode` =
`g.node.gt/005` + optional opaque `Proof` string; registry entry + indexes +
runtime regen. `CLAUDE.md` gains a Branching section (topic branches off `dev`,
PR back; no long-lived vocabulary branch — new with the staging tier).

**Why:** the grid-node-registry populate step requires every row born as a
command (`command_log` from birth), and creation had no word. One generic
registrar word, one node per command, parents-first — the multi-party
certification ceremony (TaValidator plane) arrives upstream later and *feeds*
this word rather than replacing it (legacy review in the gnr
create-words-and-validation-stubs exploration). `Proof` mirrors
`g.node.forest`'s seam: opaque until the authority substrate fixes a format.
Staging while the write surface converges; promotion to published gates the
EC2 deploy. **Verified:** sema suite 382 passed; vendored into gnr
(`--allow-staged` dev-only snapshot), gnr suite 41 passed.

## 2026-07-08 — governance: promotion is owner-on-a-branch via PR (`4c6545e`)

**What:** `spec/governance.md` gains a "Promotion (staging → published)" section: the word's
owner promotes on a branch (`sema promote`) and opens a PR; the diff — flipped status line, hash
pin, regenerated public registry — IS the promotion record; validation gates the merge; clusters
promote bottom-up on one branch.

**Why:** OPS-445 built the mechanism but left the workflow implicit; this pins who promotes and
how it is reviewed, decided 2026-07-08. Spec edit sanctioned in conversation.

## 2026-07-07 — staging word status: required statuses, hash pins, published-only snapshots, sema promote (`059f6ad`)

**What:** the OPS-445 staging tier, whole stack. Every registry entry now carries an explicit
`status` (250 lines written; absence is a validation error): types + versioned enums per version
`draft|staging|published`; versionless types + literal enums word-level three-tier; formats
word-level `draft|published` (never stage). Initial partition per the reviewed derivation —
published is owed to the broker archive (wire-reached broker-crossing words + their `$ref`
closure + everything non-layout); the layout-work cluster and anything using it is staging (110
published / 62 staging type versions, 7 staging enum versions + `i2c.adc.channel`).
`build_public_registry` builds the ACTIVE surface (staging + published), requires statuses,
enforces formats-never-stage and the published-closure rule (published may not `$ref`
staging/draft). New `definitions/published_hashes.yaml`: sha256 pin per published schema file,
suite-enforced (`test_published_hashes.py`) — editing a published file fails CI. `sema snapshot
prepare` defaults to published-only (fails listing staging offenders); `--allow-staged` builds a
dev-only snapshot marked machine-readably (`indexes/staging.yaml`) and with a "PLEASE ONLY USE IN
DEV" README banner. New `sema promote <name> [version]`: verifies the closure is published, flips
the one status line (never touches `created`), records the pin, regenerates the public registry.
Spec updated to match (structure.md Status Field rewrite incl. promotion-never-rewrites-`created`;
primary.md publication paragraph + glossary; snapshot.md published-only section; consequential
status lines in registry/types.md, enums.md, formats.md). `build_gwta_snapshot.sh` passes
`--allow-staged`.

**Why:** the vocabulary is in real cross-repo use (tlayouts, gwta, scada) while the layout words
are still being reshaped — draft-vs-published had no honest place for that. Staging names it:
mutable, snapshot-consumable, dev brokers only. The strength of sema is that published means
trustably immutable, so the tier comes with teeth rather than an honor system — hash pins, the
published-only snapshot default, and closure coherence. Suite green (381 passed); runtime regen
zero-diff; promote exercised live (error paths + a real flip, restored).

## 2026-07-06 — retroactively register new.command.tree/001 (the spruce wire version) (`4529883`)

**What:** `new.command.tree/001` registered mid-chain between the existing 000 and 002:
`ShNodes` as a single `$ref spaceheat.node.gt/301` (no oneOf), same FromGNodeAlias/UnixMs/axiom 1
(PrefixClosedHandles, validator ported from 000's template). Its `created` is **backdated** to
`2026-06-26T03:35:00Z` (same sitting as 002, ordered before it, after every dependency) so the
spec's version-order/created-order SHALL holds untouched — a deliberate one-off against the
real-wall-clock timestamp maxim, sanctioned for this bootstrap catch-up; the 001 schema description
records the retroactive story and the backdate. Upgrade chain re-split: `000_to_002` template
deleted, `000_to_001` (lift nodes to 301) + `001_to_002` (lift 301→303) added; 002's registry
summary re-mirrored to the new 001→002 delta. Indexes + runtime regenerated (new
`NewCommandTree001` old-version class). No spec or test changes.

**Why:** the gwsproto↔sema conformance sweep surfaced gwsproto pinning `new.command.tree/001` —
a version sema never had. Archaeology: the scada protocol bumped 000→001 on 2026-01-28
(`46739eaa`, spaceheat.node.gt 300→301 gaining BoardComponentId), and the spruce scada
(`actual-spruce`) has emitted `"Version": "001"` with 301 nodes ever since — real wire data with
no describing word (the archive is the truth the word must describe). Mainline dev emits 000/300
(covered by 000's oneOf); jm/spruce-unlimbo's "001" had silently drifted to 303 nodes and is
relabeled 002 scada-side (`25d8249e`). **Verified:** suite green (379 passed, 1 xpassed — includes
the all-examples runtime decode of 001's example at own version); witnessed chain: 000 example
auto-upgrades → 002; 001 example decodes at own version and `upgrade()` reaches 002 with nodes
at 303.

## 2026-07-04 — LayoutLite010: Allow Ha1Params v004 LayoutLite011: Allow Ha1Params v004,v005 (`1b8a6ca`)

**What:** (Joe, PR `jds/import-fixes`) `layout.lite/010` `Ha1Params` widened in
place from `$ref ha1.params/005` to `oneOf[004|005]`, and `011` from `/006` to
`oneOf[004|005|006]`, with the matching registry `direct_dependencies`/summary
updates, index rebuild, runtime regen (the `Ha1Params004|005(|006)` unions in
`old_versions/layout_lite_*.py`), and upgrade-template adjustments (the
009→010/010→011 per-step ha1 lifts drop; 011→012 walks ha1 to 006).

**Why:** a **sanctioned in-place mutation of published versions** — the ruling:
the already-published wire data is the source of truth, and the fleet genuinely
shipped `layout.lite:010/011` messages carrying `ha1.params:004/005` payloads
(the S3 archive holds them), so the published schemas misdescribed reality and
correcting the word beats minting a new version that the historical data could
never carry. Unblocks the journalkeeper ingesting those archives (gjk PR #169
vendors this — its snapshot now regens identically from this branch).
**Verified:** full sema suite 177 passed incl. the round-trip gate and the
upgrade-summary↔template mirror; gjk regen + suite green downstream.

## 2026-07-04 — all examples decode through the runtime; stash stale gw.house0.layout example (`0ac441f`)

**What:** on `jm/example-runtime-validation` (off `jm/sim-vocab`).
`tests/runtime/test_example_runtime_validation.py` drops its grown-as-touched allowlist and now
decodes **every** non-draft type example through the generated runtime at the example's **own
version** (`auto_upgrade=False`, the snapshot round-trip gate's semantics) — 133 example-bearing
versions covered. Draft versions are skipped (no generated runtime class); a non-draft version whose
example can't find a runtime class fails. The one stale example this surfaces —
`gw.house0.layout/000`, broken by the in-place channel-config reshape (3399 runtime errors) — is
**stashed**: moved out of `000.yaml` into the type's `stash_axioms.md` as the structural reference
until the tlayouts generator authors the reshaped layout (the generated instance becomes the fresh
example). The `x-gridworks` axioms block stays in `000.yaml` untouched.

**Why:** an example that doesn't decode through the current runtime is a broken contract advertised
as a worked example; it should fail the main suite the moment a reshape lands, not later at a
consumer's snapshot build. Design: OPS-442. **Verified:** full suite green (377 passed, 1 xpassed);
ruff check + format clean; index + runtime regen are no-ops.

## 2026-07-04 — layouts reference g.node.gt v005 (`b901ee1`)

**What:** the three unpushed layout-family types that carry GNode identity —
`gw.house0.layout/000`, `gw.nolan.layout/000`, `gw.house0.operational.params/000` — bumped their
`g.node.gt` `$ref` `004` → `005` **in place** (no version bump; all three are unpushed → mutable).
Registry: the three `direct_dependencies` entries → `g.node.gt:005`, their `created` forward-bumped
to `2026-07-04T14:50:00Z` (dependency ordering — `005` was created 2026-07-03; the cascade stops at
these three, nothing references them), `metadata.last_updated` same stamp. The six embedded example
GNode instances (3 in house0.layout, 3 in operational.params; nolan has none) bumped to
`"Version": "005"` — their aliases already satisfy the new axiom 6 (≥2 dotted words). Indexes +
runtime regenerated.

**Why:** `g.node.gt/005` (`e5f4141`) canonized "the universe segment is a namespace, not a
GNodeAlias" (axiom 6, ≥2-word alias); the layouts we are actively authoring should bind to that
contract rather than pre-axiom `004`. `fis.authority.manifest/000` deliberately stays on `004` —
FIS-domain, not this pass's to move. gwsproto `GNodeGt` catch-up (add `check_axiom_6`, docstring →
`/005`) is the scada-side follow-on. **Verified:** suite green after regen (267 passed, 1 xpassed).

## 2026-07-03 — Board-resident relay vocabulary: relay.control.config + i2c/gpio relay components (`fae8d27`)

**What:** three new type words for the board-resident, one-relay-per-component model, plus a
migration marker. `relay.control.config/000` = `relay.actor.config/004` **minus the positional
`RelayIdx`** (same three relay event/state axioms, ported), for relays identified by name against
their board rather than by index. `i2c.relay.component.gt/000` and `gpio.relay.component.gt/000` —
board-**generic** thin per-relay components: `{ComponentId, DeviceType, RelayName|GpioName,
ConfigList:[relay.control.config] (axiom ExactlyOneConfig), DisplayName?, HwUid?}`, referencing the
board's `I2cRelays` / `NativeGpioOutputs` map (`gw1.scada.device.type.gt`) by `pascal.case` name; the
board stays the single source of the physical address. `relay.actor.config` gains
`replaced_by: [relay.control.config]` (advisory migration marker; not frozen — still in service for
the legacy `i2c.multichannel.dt.relay.component.gt` multiplexer until krida becomes a board device
type). Registry entries + runtime axiom templates ported + regen. Suite green (267).

**Why:** hardware-layout-pass-one board-resident relay model (OPS-407). The relay decommission
(i2c-board-components spoke, previously pass-two): retire the positional multiplexer for one relay per
component, identified by name against the board. Authored ahead of the layout/actor migration so
future work needs no further sema round — `RelayIdx` is obsolete once krida is also a
`scada.device.type` with named `I2cRelays`, at which point `relay.actor.config` fully retires. Pairs
with `gw1.device.type/001` (`Gw108I2cRelay`/`Gw108GpioRelay`, `11be3be`).

## 2026-07-03 — gw1.device.type/001: add Gw108I2cRelay + Gw108GpioRelay (`11be3be`)

**What:** additive version bump of the `gw1.device.type` versioned enum (v000 → v001),
appending two board-resident relay device categories — `Gw108I2cRelay` and
`Gw108GpioRelay` — to the end of the value list (the existing 20 values unchanged and in
order; default `EgaugePowerMeter` unchanged). Registry `latest_version` → `001` with the
`added_values` entry; `last_updated` → 2026-07-03T19:45:00Z; regenerated `indexes/` +
runtime (`gw1_device_type.py` gains the two `auto()` members; `old_versions/gw1_device_type_000.py`
frozen). Suite green (267).

**Why:** hardware-layout-pass-one / the board-resident relay model (OPS-407). The
board-resident per-relay components being authored next (`i2c.relay.component.gt`,
`gpio.relay.component.gt`) each carry their own coarse `gw1.device.type` value — a relay
on a gw108 board is its own device category, distinct from the board itself
(`GridworksScadaGw108`), which the node reaches via `BoardComponentId`. Minting the enum
values first (nothing `$ref`s the enum — components carry `DeviceType` as an open
`pascal.case` string, so the bump does not cascade) lets those component types land without
a second sema round. Next: `relay.control.config` (= `relay.actor.config` − `RelayIdx`) +
the two component types.

## 2026-07-03 — Forest topology vocabulary + g.node.gt v005 (≥2-word alias) (`e5f4141`)

**What:** the Grid Node Registry's topology vocabulary reworked to the
**forest** model (OPS-419). `g.node.gt` **v004 → v005** adds axiom 6
`GNodeAliasHasBody` (`Alias` — and `PrevAlias` when present — SHALL have ≥2 dotted
words; the universe segment is a namespace, not a GNodeAlias) with its identity
upgrade template. **Retired** the flat `g.node.topology.broadcast` (unpushed) in
favour of one reused **`g.node.forest`** payload (`Roots` as `left.right.dot` +
`Nodes` as `g.node.gt/005` + `Edges` as `connectivity.edge.gt` + an optional `Proof`
seam), plus a **`g.node.forest.request`** read query (`Roots` + `RequestId`).
`g.node.reparent.cmd`'s `NewNode` `$ref` bumped to `g.node.gt/005` in place; `created`
stamps forward-bumped where dependencies shifted.

**Why:** the forest is the registry's scaling unit — one payload for the change
broadcast, the chunked snapshot, and the API read-response — so a million assets
never move as one message (see the grid-node-registry standup design + executor). The
≥2-word axiom canonizes "the universe token is a namespace, not a GNode." **Verified:**
(pending) regen + snapshot round-trip gate green.

## 2026-06-30 — Add gw.house0.operational.params/000 (the operational-params artifact) (`41e0a12`)

**What:** new versioned type `gw.house0.operational.params/000` (`literal`, owner gridworks-energy):
`GNodes` (a `List[g.node.gt/004]` — the home identity, **mirroring the hardware layout**) +
`CaptureTuningList` (a `List[capture.tuning/000]`); one axiom `CaptureTuningChannelUniqueness` (ChannelName
unique across the list). Registry entry + `check_axiom_1` template + regen; `metadata.last_updated` →
2026-06-30T22:55:00Z. Added to the runtime-validation allowlist. Suite green (264).

**Why:** hardware-layout-pass-one (OPS-407). The per-channel capture params left the static layout (the
channel-config family strip, `543ff2c`); this type is their **authored home** — the third SCADA artifact
alongside deployment config and the static layout. Pass-one scope is `CaptureTuningList` only (the control
/ optimization sub-types — `cop.curve`, `heating.curve`, mode, criticality — land in a later version when
those fields leave config). It carries the layout's `GNodes` so the two pair unambiguously, and its
`extended_description` spells out the **TerminalAsset-vs-Scada** distinction (the asset itself vs. the GNode
that controls it — a known point of confusion). Next: the `ops_and_sema_to_dc` assembly + the oak boot.

## 2026-06-30 — Drop ConfigList from bare-base components; orphan channel.config (`0507d3a`)

**What:** removed the `ConfigList` field — and its `required` entry, example entry, `channel.config:001`
dependency, and the now-obsolete `ChannelNameUniqueness` / `EmptyConfigList` axiom — from the 9 components
that carried only a bare `channel.config` ConfigList: `gw108.gpio.sensor/002`, `hubitat/000`,
`hubitat.poller/000`, `pico.btu.meter/001`, `pico.flow.module/001`, `pico.tank.module/012`,
`sim.pico.tank.module/001`, `sim.sensor/000`, `web.server/002`. Remaining axioms renumbered
(`pico.tank` / `sim.pico.tank` / `pico.flow`); `extended_description`s preserved (`hubitat`, `web.server`).
All 9 added to the runtime-validation allowlist. Suite green (263). In place — all unpushed/mutable.

**Why:** hardware-layout-pass-one (OPS-407). A bare `{ChannelName}` ConfigList is information-free: the
channel→component binding is carried by `DataChannel.CapturedByNodeName`, and channel-name uniqueness is a
layout-level invariant (`ChannelBindingIntegrity`), subsuming the per-component `ChannelNameUniqueness`
axiom. So components with no per-channel hardware binding carry no ConfigList; only the specialty
`*.channel.config` types do. `channel.config` is now referenced by no live type — **orphaned, not deleted**:
`channel.config/000` is published, so immutability forbids removing it; it stays in the registry,
referenced only by its own frozen historical component versions.

## 2026-06-30 — Strip capture params from the channel-config family (→ capture.tuning) (`543ff2c`)

**What:** removed `CapturePeriodS` / `AsyncCapture` / `AsyncCaptureDelta` / `PollPeriodMs` from the 5
specialty channel-config types **in place** (unpushed → mutable): `ads.channel.config/001`,
`dfr.config/001`, `electric.meter.channel.config/001`, `i2c.thermistor.channel.config/002`,
`relay.actor.config/004` — leaving `ChannelName` + hardware-binding only. `dfr`'s
`CaptureAndPollingConsistency` axiom dropped (now on `capture.tuning`); `relay`'s two capture axioms
dropped and its remaining relay axioms renumbered 1–3. The prev→latest upgrade templates drop the capture
fields; registry summaries + the `electric.meter` dep (`positive.int`) reconciled. 7 component examples
shed the stripped fields from their `ConfigList` items. New
`tests/runtime/test_example_runtime_validation.py` runtime-decodes a growing allowlist of examples (closes
the JSON-only gap). Suite green (254).

**Why:** hardware-layout-pass-one operational-params reshape (OPS-407). Per-channel capture params are
operational, not topology, so they leave the static channel-config family for operational-params
(`capture.tuning`, `c57df6e`); the specialty types keep only per-channel hardware binding. Next: drop
`ConfigList` from the 9 bare-base components and **orphan** `channel.config` (`000` is published → cannot
be deleted, so it stays in the registry, unreferenced).

## 2026-06-29 — Add capture.tuning/000 (per-channel operational capture tuning) (`c57df6e`)

**What:** new versioned type word `capture.tuning/000` (`literal`, owner
gridworks-energy): `ChannelName` + `CapturePeriodS` + `AsyncCapture` +
optional `AsyncCaptureDelta` + optional `PollPeriodMs`; one axiom
`CaptureAndPollingConsistency` (a: if `PollPeriodMs`, `CapturePeriodS`×1000 >
`PollPeriodMs`; b: when sub-10×, must be an integer multiple) — moved here from
`dfr.config`'s axiom 1, reshaped conditional on the now-optional `PollPeriodMs`.
Registry entry + `check_axiom_1` runtime template + regen; `metadata.last_updated`
bumped to 2026-06-29T19:40:00Z. Suite green (241).

**Why:** first word of the hardware-layout-pass-one operational-params reshape
(OPS-407). The per-channel capture params are *operational*, not topology — a
channel's poll/report cadence changes without rewiring — so they leave the static
`channel.config` family and live in operational-params as this per-channel
sub-type. The hardware floor stays on the device type (`MinPollPeriodMs`); the
`PollPeriodMs ≥ MinPollPeriodMs` check is an assembly-time concern
(`ops_and_sema_to_dc`), not an axiom here. Next: strip the capture params from the
specialty `*.channel.config` types and remove the bare `channel.config` base.

## 2026-06-29 — Release g.node.reparent.cmd + g.node.topology.broadcast (draft → released) (`7743882`)

**What:** flipped both words from draft to released — `$id` and registry
`schema_url` `/draft/types/…` → `/types/…`, removed `status: "draft"` — and
regenerated `indexes/` + runtime (released types now get their per-type runtime
classes). No change to the schema contract (fields/axioms/deps unchanged).

**Why:** the gnr snapshot build excludes draft words, so the registry could not
vendor or use them. Releasing (status only; the schema is identical) lets the
snapshot include them. They remain locally mutable until pushed to origin
(immutability tracks the push), so this is reversible until release.

## 2026-06-29 — Add gnr command words: g.node.reparent.cmd + g.node.topology.broadcast (`8a6202b`)

**What:** two new **draft** versioned type words (v000) on `jm/gnr-commands` for
the Grid Node Registry's mutation contract — `g.node.reparent.cmd` (`NewNode:
g.node.gt/004` + `MovedChildGNodeIds: [uuid4.str]`) and
`g.node.topology.broadcast` (`UpdatedNodes: [g.node.gt/004]`). Kept minimal for
now (edge retire/create set deferred). Plus registry entries (draft status,
`gridworks-energy` owner, `created` 2026-06-29T04:50Z, `direct_dependencies.structural`
= `{g.node.gt:004, uuid4.str}` / `{g.node.gt:004}`), `last_updated` bump, and
regenerated `indexes/` + runtime (`validate.py`; drafts get no per-type runtime
class in the main repo — they generate into the consumer snapshot).

**Why:** build step 5 of the grid-node-registry standup (OPS-419) — the two
Sema messages a re-parent mutation rides on (command in, topology broadcast out),
authored extremely-simple first, to be fleshed out with the handler core. The
example round-trip is exercised when these are vendored into the gnr snapshot.
**Verified:** `pytest` green (177 passed) incl. registry validation.

## 2026-06-29 — Ignore per-consumer snapshot build tooling (`6759f9f`)

**What:** `.gitignore` — generalized the existing `seed_request.yaml` ignore to
`*_seed_request.yaml` + `build_*_snapshot.sh`.

**Why:** per-consumer snapshot build tooling (e.g. `build_gnr_snapshot.sh` +
`gnr_seed_request.yaml`, tracked in the consumer repo) leaves stray artifacts in
a sema checkout when run from here; ignoring them keeps the sema tree clean.

## 2026-06-28 — connectivity.edge.gt ids-only; position.point.gt footprint + immutable semantics (`565d9d0`)

**What:** `connectivity.edge.gt` — dropped `FromGNodeAlias` / `ToGNodeAlias`
(and the now-unused `left.right.dot` dependency); edges carry only the immutable
`From/ToGNodeId`. `position.point.gt` — `extended_description` now prescribes
accuracy by intent (a point falls within the footprint of the GNode's building),
declares the point **immutable** (a location change is a TaValidator
re-certification, not an in-place edit), and notes a per-fix R95 accuracy field is
deferred to the TaValidator/deed machinery. Indexes + runtime regenerated;
`pytest` green (241). Both types are draft/unpushed, so edited in place (no bump).

**Why:** the grid-node-registry standup grill ([OPS-419](https://linear.app/gridworks/issue/OPS-419))
converged the registry's data model: edges key on the **immutable** id and derive
alias on read (a pure rename then touches zero edges and the edge-alias-consistency
invariant disappears); and a GNode's location anchors its TaDeed/TaTradingRights, so
it must be immutable with corrections handled as a certified re-visit.

## 2026-06-26 — Add transactive-power axioms to layout words (`0946021`)

**What:** Added the `TransactivePowerChannel` axiom to both layout words — `gw.house0.layout`
(axiom 5) and `gw.nolan.layout` (axiom 1, its first): exactly one DerivedChannel with Strategy
`transactive-power`, whose `InputChannelNames` resolve to existing `PowerW` DataChannels each of
whose about-node carries `NameplatePowerW`. Executable validators ported into the axiom templates
(no `NotImplementedError` stub left), and the house0 embedded example gained a transactive-power
DerivedChannel so it satisfies the axiom. Regen green (241).

**Why:** Once `InPowerMetering` was dropped from `spaceheat.node.gt`, its `⟹ NameplatePowerW`
obligation had nowhere to live — it folds into this layout-level axiom, which also makes the metered
transactive set singular and auditor-legible. Mirrors the gwsproto
`check_transactive_metering_consistency`. ([OPS-427](https://linear.app/gridworks/issue/OPS-427).)

## 2026-06-26 — Channel-config overhaul: drop Unit/Exponent + InPowerMetering (`1920240`)

**What:** Sema half of the channel-config-overhaul ([OPS-427](https://linear.app/gridworks/issue/OPS-427)),
items 2 + 3. New versions dropping the redundant `Unit` + `Exponent` from every
ChannelConfigBase-family config: `channel.config/001`, `ads.channel.config/001`,
`i2c.thermistor.channel.config/002`, `electric.meter.channel.config/001`, `dfr.config/001`, and
`relay.actor.config/004` (the sixth config-family type — a flat sibling that the channel.config
reverse-dep closure missed). New versions dropping `InPowerMetering` + its axiom:
`spaceheat.node.gt/303` (drops `InPowerMeteringRequiresNameplate`, keeps `NameplatePowerW`) and
`data.channel.gt/003` (drops `PowerMeteringConstraint`). Most referrers repointed in place (unpushed,
no version bump): the 15 component `ConfigList` `$ref`s, the 4 relay components, `layout.lite/015`,
`new.command.tree/002`, and `gw.house0.layout/000` (embedded-example rewrite of 83 nodes / 76 channels /
6 configs / 16 relay configs). `gw.nolan.layout/000` left as-is. **`scada.control.capabilities`** is the
exception: it is published-immutable per its owning design (admin-for-nolan / OPS-394), so instead of an
in-place repoint it gets a clean new **`scada.control.capabilities/002`** (RelayNodes/DacNodes →
`spaceheat.node.gt/303`, ControlChannels → `data.channel.gt/003`); `/001` is restored to `/300`+`/001`
and backfilled with the now-required superseded example.
22 referrer `created` stamps moved forward to satisfy the dependency-timestamp ordering rule. Axiom
validators ported to the new versions; upgrade templates added (`*_to_*`, each dropping the retired
keys); runtime regen deterministic; 240 sema tests green. `egauge.register.config` (modbus register
descriptor) and `maker.api.attribute.gt` (the functional Hubitat scaling exponent) deliberately left
out of scope.

**Why:** a channel's unit and scaling are carried by its identity — `TelemetryName` (data channel) or
`OutputUnit` gw1.unit (derived channel) — so the per-config `Unit` (the old `spaceheat.unit` enum) and
`Exponent` are redundant, and a survey confirmed no driver reads them to scale a reading. `InPowerMetering`
was a source-side copy of routing the consuming transactive declaration owns; it goes from
`spaceheat.node.gt` and `data.channel.gt`. Done now while the carrying component versions are still
unpushed, so the configs are clean version bumps and the components are cheap in-place repoints. Item 4
(the first-class transactive audit-declaration word that replaces `InPowerMetering`'s role) is deferred to
a later pass. The gwsproto/scada side (ChannelConfigBase + RelayActorConfig + SpaceheatNodeGt +
DataChannelGt + ScadaControlCapabilities bumps, removing the two `config.Unit` validation readers, and
computing metering routing from `InputChannelNames`) follows in the scada repo. ([OPS-427](https://linear.app/gridworks/issue/OPS-427).)

## 2026-06-23 — house0 layout axiom 3 → ZoneHeatCallChannel (`b716f75`)

**What:** Replaced `gw.house0.layout/000` axiom 3 `ZoneWhitewirePwrChannel` with `ZoneHeatCallChannel`:
each zone SHALL have a `zone{i}-{name}-heat-call` DerivedChannel (Strategy `heat-call`) plus a per-zone
source DataChannel — `whitewire-pwr` (power-sourced) or `opto-input` (opto-sourced). Schema statement
updated; runtime jinja2 `check_axiom_3` template + regen to follow in this cluster.

**Why:** require the semantic signal (heat-call) the control logic needs, not a specific sensor —
parallel to heat-pump-power and the PrimaryFlowSource agreement. The source is a per-zone hardware
choice (power ⇒ eGauge whitewire, opto ⇒ gw108), so whitewire-pwr drops from always-required to
required-only-when-power-sourced. `gw.house0.layout/000` is unpushed → mutable in place. ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-22 — gw108 board example + BusMembership counterexample (`1a1e031`)

**What:** Added the validated gw108 board as the `examples` of `gw1.scada.device.type.gt/000` — the exact
payload the hand-written gwsproto `ScadaDeviceTypeGt` emits, confirmed by `sema validate`. Added a
`BusMembership` (Axiom 1) counterexample fixture + test: a minimal board whose relay references an
`I2cBus` name absent from `BusList`, asserted to be rejected by the runtime codec.

**Why:** closes the Batch 3 (board) leg of the gwsproto→sema conformance sweep — the example pins what a
conformant board looks like, the counterexample pins that the runtime enforces bus membership (accept +
reject, both sides). Indexes regenerated. `pytest` green (232 passed, 1 xpassed). ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-22 — add axiom tests and more examples (`bf41287`)

**What:** Added axiom counterexample fixtures + tests for the i2c bus-op types — one
fixture per axiom, each an otherwise-valid payload with a single field mutated to violate
exactly one axiom, asserted to be rejected by the runtime codec:
`i2c.write.bit` (Axiom 1 `BitValueRange`, Value=2), `i2c.read.reg` (Axiom 1 `NumBytesRange`,
NumBytes=3), `i2c.write.reg` (Axiom 1 `NumBytesRange` NumBytes=3, Axiom 2 `ValueFitsNumBytes`
NumBytes=1/Value=300), `i2c.result` (Axiom 1 `ErrorIffFailure`, Success=false with no Error).
Also added gwsproto-validated `examples` to the four config schemas
(`i2c.relay.config`, `i2c.adc.config`, `i2c.dac.config`, `i2c.thermistor.interface.config`).

**Why:** the counterexamples are the other half of the EDD bar — the example proves the runtime
*accepts* a conformant payload, the fixture proves it *rejects* one that breaks the axiom, so each
schema axiom is pinned from both sides. Mirrors the `check_axiom_n` methods on the hand-written
gwsproto producers (a gwsproto axiom dropped → sema still catches it). `pytest` green (231 passed,
1 xpassed). ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-22 — add i2c examples, registry alphabetized (`15d94e7`)

**What:** Added gwsproto-validated `examples` to the i2c.* type schemas (Batches 1–2 of the
gwsproto→sema conformance sweep: `i2c.bit.address`, `i2c.reg.address`, `i2c.read.bit`/`write.bit`,
`i2c.read.reg`/`write.reg`, `i2c.result`, `i2c.relay.config`, `i2c.adc.config`, `i2c.dac.config`,
`i2c.thermistor.interface.config`) — each example is the exact payload its hand-written gwsproto type
produced, confirmed by decoding it through the sema runtime (`sema validate`). Also alphabetized the
entries within each section (`formats`/`enums`/`types`) of `definitions/registry.yaml` by key — the
i2c.* words now cluster correctly (they had been inserted in the "g" area); a pure byte-for-byte
reorder, indexes regenerated.

**Why:** the examples document the wire form and are exercised by the snapshot round-trip; the registry
alphabetization is hygiene (entries findable by name). `pytest` green (226). ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-22 — sema validate: CLI + API (`40f7643`)

**What:** Added a first-class validation surface. API: `sema.runtime.validate.validate(data)`
→ `ValidationResult{ok, type_name, version, error}` — wraps `default_codec.from_dict` and
returns a structured result instead of raising, so callers can branch; `expected_type=` asserts
the decoded `TypeName`. CLI: a `sema validate [file]` subcommand (file or stdin; exit 0 valid /
2 invalid; `--type` to assert), registered alongside reverse/runtime/snapshot. 6 tests.

**Why:** validating a payload against the Sema vocabulary should be a first-class, shell-usable,
cross-venv operation — decode-through-the-runtime *is* the validation, and Sema is the source of
truth (not a downstream codegen'd copy). This is the per-type tool for the gwsproto→sema
conformance sweep (gwsproto emits JSON → `sema validate`), replacing the indirect gwta-snapshot
proxy. Built on `jm/cli` off `dev` so it merges independently of the in-flight vocab work.

## 2026-06-22 — pin strict-lint test to a committed seed fixture (`1da1c7b`)

**What:** `tests/test_snapshot_strict_lint.py` pointed `prepare_snapshot` at the
repo-root `seed_request.yaml`, which is gitignored (a locally-generated artifact),
so the test raised `FileNotFoundError` on any fresh checkout that lacks it. Copied
the production seed targets into a committed fixture
`tests/fixtures/strict_lint_seed.yaml` and repointed the test at it.

**Why:** The strict-lint guard needs to run for everyone, not just on a machine
that happens to have generated `seed_request.yaml`. The fixture pins the same
targets (notably `scada.params` all-versions, the enums hitting the legacy
GwStrEnum index API, and the typed-map types) so the regression paths the guard
protects stay exercised. Reported by Joe.

## 2026-06-22 — adjust axioms for all the components (`2823a2b`)

**What:** Added the `ChannelNameUniqueness` axiom (axiom 1: "Channel names SHALL be
unique across the ConfigList") to every `*.component.gt` schema + its runtime axiom
template, matching the gwsproto runtime. The 11 axiom-free components got it as their
sole axiom; the 5 with existing axioms had those renumbered up by one
(`ads111x` OpenVoltageByAdsRange→2; `i2c.multichannel` ActorAndRelayIndexUniqueness→2;
`pico.flow` HwUidPattern→2; `pico.tank`/`sim.pico.tank` the three Pico axioms→2,3,4).
`web.server.component.gt` is the exception — it's a software service, not telemetry
hardware, so instead of ChannelNameUniqueness it got an `EmptyConfigList` axiom
(`ConfigList` enforced empty at decode, since the runtime ignores `maxItems`) plus a
"dangler" note in `extended_description`. `electric.meter` already had the axiom. 47
files; runtime regenerated; `pytest` 220 passed.

**Why:** sema is the source of truth for the component axioms, so the schemas must
declare what the gwsproto runtime enforces — Channel-Name uniqueness on every
component's ConfigList. Surfaced that `web.server` is a misuse of the component
concept (no channels) and constrained it honestly. ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-22 — gw108 board descriptor + generic i2c bus vocabulary (`dc6800e`)

**What:** Built out the gw108 board descriptor (`gw1.scada.device.type.gt/000`) and a generic `i2c.*`
hardware vocabulary. New types: `i2c.bit.address`, `i2c.reg.address`, `i2c.bus`, `i2c.relay.config`,
`i2c.adc.config`, `i2c.thermistor.interface.config`, `i2c.dac.config`, `i2c.read.bit`, `i2c.write.bit`,
`i2c.read.reg`, `i2c.write.reg`, `i2c.result`, and `gw.native.gpio.pin`; new enums `i2c.adc.type`,
`i2c.dac.type`, `i2c.operation`. The board descriptor gained `BusList`, `NativeGpioInputs`/`Outputs`,
`I2cRelays`, `CtAdc`, `ThermistorAdcs`, `Dacs`, `TelemetryNameList`, and a `BusMembership` axiom (every
device `I2cBus` ∈ `BusList`). String→int maps became typed arrays; silk-screen names are `pascal.case`,
addresses are bus-relative `non.negative.int`. Bus ops compose the address words and carry the `I2cBus`
actor name; `i2c.result` widens `Value`, correlates by `TriggerId`, and enforces `ErrorIffFailure`;
`i2c.read.reg`/`write.reg` enforce `NumBytes ∈ {1,2}` and value-fits-in-NumBytes. Also added the
`ChannelNameUniqueness` axiom to `electric.meter.component.gt` and folded in in-flight `ads111x`/`dfr`
edits. 52 files; runtime + indexes regenerated; `pytest` 220 passed.

**Why:** Make the board the single source of physical truth (resolved via `BoardComponentId`) and give
the I²C layer a generic, composable vocabulary, so board-resident components stay thin references and
all bus traffic can route through one serializing `I2cBus` actor. `i2c.*` is generic; only the board
descriptor and the Broadcom-pin word are `gw*`. Full design + rationale live in the
hardware-layout-pass-one design ("The Sema I²C vocabulary" section). Words authored/edited in place
(unpushed, mutable). ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-16 — gw.house0.layout: require all collections + Hydronic (`dc7877f`)

**What:** Promote every collection field (`GNodes`, `ShNodes`, `DataChannels`, `DerivedChannels`,
`Components`, `DeviceTypes`) plus the `Hydronic` block from optional to `required` in
`gw.house0.layout/000` (unpushed → mutable in place, no version bump). Drops the v000 "optional-first
bootstrap" allowance, mirroring the sibling `gw.nolan.layout/000` which already requires all nine
fields. Updated the schema description + registry version summary to match, regenerated runtime
(`g_nodes: list[GNodeGt]` … `hydronic: GwHouse0Hydronic`, no more `| None = None`) and rebuilt indexes.

**Why:** A layout is a complete, deployable artifact, never a partial one — the optional-first shape
was scaffolding to keep the round-trip green while the collections were populated, and they now are.
The codegen was faithfully emitting `Optional[List[...]] = None` because the schema's `required` block
still listed only `TypeName` + `Version`; making the fields required is the real fix, not a codegen
patch.

## 2026-06-16 — start adding house0 layout axioms (`899f79b`)

**What:** Added axiom 2 `Cardinality` to `gw.house0.hydronic/000` (unpushed → mutable in place, no
version bump): (a) `1 ≤ TotalStoreTanks ≤ 6`, (b) `1 ≤ |Zones| ≤ 6`. Implemented `check_axiom_2` in
the runtime axiom template (`templates/axioms/gw_house0_hydronic_000.py.jinja2`) and regenerated
runtime + indexes; aligned the `TotalStoreTanks` field description (was "0..6") to the enforced
1..6.

**Why:** first slice of hardware-layout pass-one Task a — porting the scada dc loader's structural
validations (`house_0_layout.py:100–103`, the 1–6 tank/zone guards) into sema axioms so sema is the
source of truth. Bare `minimum`/`maxItems` are forbidden by sema's primitive-constraint rule, so an
axiom is the carrier. Verified: sema suite green (220 passed), and all five House0 fleet layouts
(maple/beech/elm/oak/fir) still round-trip scada→gwta→scada unchanged with the axiom enforced. A
generated counterexample test (proving the axiom *catches* a violation) is owed once the sema-native
layout gen (Task b) lands. ([OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-15 — fixing local names and patching derived channel (`14fdfbc`)

**What:** (1) **Local names** — replaced the snapshot CLI's clobbering local-names writer with a
declarative mechanism. The seed request now carries a `local_names` block (`strip_prefixes` +
per-type `overrides`); `prepare` materializes `local_names.yaml` from it via
`render_local_names_yaml` (with collision detection), instead of a private `_write_local_names_yaml`
that unconditionally overwrote the file. `prepare` also now records the original `seed_request.yaml`
in the snapshot for provenance. README updated to the new flow. (2) **Derived channel** — reconciled
the in-place `/002` edit (see `4adb357`): registry `direct_dependencies` `gw1.quantity:000 → :001`,
fixed the `gw1.qauntity` summary typo, and made the `001 → 002` upgrade-template docstring mirror the
summary; regenerated indexes + runtime.

**Why:** the old `prepare` reimplemented the local-names emitter and dropped the idempotent helper's
preserve-if-exists guard, so every rebuild clobbered hand-edited local names — the gwta de-prefixing
never survived. Declarative rules in the seed request express the intent (drop `gw1.`/`gw.` prefixes;
keep `gw108.*`) without hand-editing and survive regeneration. The derived-channel reconciliation makes
the kept in-place `/002` internally consistent — the full sema suite is green (220 passed).

## 2026-06-15 — patch derived channel (`4adb357`)

**What:** Repointed `derived.channel.gt/002`'s `OutputUnit` `$ref` to `gw1.unit/001` and
`OutputQuantity` to `gw1.quantity/001` (was `/000` for both) — an **in-place edit of `/002`**.
(The registry/index/upgrade-template reconciliation this required landed in `14fdfbc`.)

**Why:** the scada↔gwta layout round-trip (`maple.json → dc → sema → gwta → scada`) was
silently degrading the sieg `hp-keep-seconds-x-10` channel: scada emits `OutputUnit=SecondsX10`
→ `OutputQuantity=Time`, but `gw1.unit/000`/`gw1.quantity/000` (the versions `/002` originally
pinned) lack `SecondsX10`/`Time`, so gwta decoded them to `Unknown`. Pointing the fields at the
v001 enums (which carry the time values) makes the round-trip lossless.

**Why in-place rather than a new `/003`:** `/002` had been pushed to `origin/dev`, which our
push-based immutability rule treats as frozen — but that freeze is considered premature, and the
schema is **not published** anywhere (nothing resolves on `schemas.electricity.works` yet), so
there is no live contract to protect. A clean `/003` would have cascaded version bumps across the
layout types that embed the channel, for no pre-publication benefit. The edit is also temporally
clean: `gw1.unit/001` and `gw1.quantity/001` share `/002`'s exact `created` stamp
(`2026-03-04T19:00:00Z`), so dependency ordering already holds. Decision: **keep `/002`.** One
carry-forward: this branch's `/002` now differs from `origin/dev`'s; reconcile that at merge.

## 2026-06-15 — freeze and replace spaceheat.make.model (`9430e8c`)

**What:** Marked `spaceheat.make.model` frozen in the registry — added `replaced_by:
[gw1.device.type]` and `frozen_at: "2026-06-15T20:05:00Z"`, and noted the supersession in its
description. Advisory metadata only (no validation/lifecycle/closure change); the enum's published
versions are untouched. `metadata.last_updated` bumped; indexes rebuilt.

**Why:** `MakeModel` is being retired across summer 2026 (the `jm/delete-cac-id` work); device
identity moved to the open `DeviceType` (`gw1.device.type`). The `replaced_by`/`frozen_at` markers
make that migration legible to humans + tooling while keeping `spaceheat.make.model` as frozen base
vocabulary. Part of the wiki MakeModel→DeviceType sweep. `pytest` green (220).

## 2026-06-15 — minor adjustment gw.house0.layout (`70c3dab`)

**What:** Brought the `gw.house0.layout/000` example up to the versions/shape its schema
`$ref`s so the gwta snapshot round-trip gate (`mode="strict"`) passes: (1) the Hubitat `Poller`
sub-objects' keys snake_case → PascalCase (they `$ref` `hubitat.poller.gt` / `maker.api.attribute.gt`,
which require PascalCase — the example was simply wrong); (2) `DeviceTypes` rebuilt from 11 legacy
`cac.gt` / `component.attribute.class.gt/002` stand-ins down to the 2 real specialized records the
schema's `oneOf` allows (`ads111x.based.device.type.gt/000` for the TSnap board with real
`AdsI2cAddressList`/`TotalTerminalBlocks`/`TelemetryNameList`, `electric.meter.device.type.gt/000`
for the eGauge); per the model the other 9 device categories carry no specialized record (their
`DeviceType` lives on the component); (3) the 14 `derived.channel.gt` instances upgraded `001 → 002`,
adding the required `OutputQuantity` (`Temperature` for the FahrenheitX100 depth channels, `Energy`
for the WattHours energy channels, per the unit→quantity projection). Also guarded axiom 2
`EssentialNodesExistence` to skip when `ShNodes` is empty — so the optional-first minimal layout
(`TypeName`+`Version` only) the round-trip script sends validates, while real layouts still enforce.

**Why:** the snapshot round-trip gate (and the scada↔gwta `layout_roundtrip.py`) demand a fully
conformant example; the example had been lagging the schema's referenced versions (a known scaffold).
With this, the gwta snapshot builds and the house0 + simple.sim round-trips are green. `pytest` green
(220). (hardware-layout pass-one, [OPS-407](https://linear.app/gridworks/issue/OPS-407).)

## 2026-06-15 — add gw1.hvac.zone and gw.house0.hydronic (`32540ef`)

**What:** Promoted `gw.house0.layout`'s freeform `Hydronic` block (`additionalProperties: true`)
into typed sema vocabulary, and made the measured-vs-derived `primary-flow` topology explicit:
- **`gw1.hvac.zone/000`** (new shared type) — one heating zone (`Name`, `Critical` bool,
  `KwhPerDegF`); replaces the former parallel `ZoneList` / `CriticalZoneList` /
  `ZoneKwhPerDegFList`, so their subset / equal-length invariants are now structural.
- **`gw.house0.primary.flow.source/000`** (new versioned enum) — `Measured` | `DerivedSiegSum`.
- **`gw.house0.hydronic/000`** (new type) — typed hydronic: `Zones` (list of `gw1.hvac.zone`),
  `TotalStoreTanks` (`non.negative.int`), `UseSiegLoop`, `SiegLoopPlumbed` (replacing the bare
  `FlowManifoldVariant`), `PrimaryFlowSource` (`$ref` the enum), `Strategy`; axiom 1
  `SiegLoopControlImpliesPlumbed` (`UseSiegLoop ⟹ SiegLoopPlumbed`).
- **`gw.house0.layout/000`** — `Hydronic` now `$ref`s `gw.house0.hydronic`; the unconditional
  hand-axioms (old 2 `HydronicStructure`, 5 `FlowTopologyDeclaration` shape) became structural;
  axioms renumbered to 1 `GlobalIdUniqueness`, 2 `EssentialNodesExistence`, 3
  `ZoneWhitewirePwrChannel` (now over `Zones`), 4 `PrimaryFlowSourceChannelAgreement`
  (`Measured ⟺ a primary-flow DataChannel`; `DerivedSiegSum ⟺ a primary-flow `sum`
  DerivedChannel`). `TankTempCalibrationMap` dropped from the layout (derived channels are the
  calibration source of truth). Runtime + indexes regenerated. v000 edited in place (unpushed).

**Why:** the measured-vs-derived `primary-flow` choice is a real physical-topology fact (a flow
meter at the primary pump or not) that was implicit in which gen builders ran. Making it explicit —
and typing the hydronic block — follows the sema rule that a known, axiom-constrained shape belongs
in the schema, not in a freeform object + hand-axioms (`spec/authoring/types.md` Inline Objects /
Open Containers). `gw1.hvac.zone` is shared so Nolan can adopt it when its hydronic is promoted
(hardware-layout pass-one, [OPS-407](https://linear.app/gridworks/issue/OPS-407)). `pytest` green (220).

## 2026-06-15 — gw1.tank.temp.calibration + .map → v001 (integer B in FahrenheitX100) (`efeafc0`)

**What:** Bumped `gw1.tank.temp.calibration` and `gw1.tank.temp.calibration.map` to v001, mirroring
`linear.one.dimensional.calibration/001`: `Depth{1,2,3}B` changes `number → integer`, where `B` is
now an offset in the consuming derived channel's OutputUnit (FahrenheitX100) scaling rather than a
°F float. Added the 000→001 upgrade templates (the upgrade is the `round(B × 100)` reinterpretation,
°F → FahrenheitX100; the map lifts its nested Buffer/Tank via their own `.upgrade()`), examples on
the now-superseded v000 schemas, and bumped `metadata.last_updated`.

**Why:** the in-field tank calibration `y = M·x + B` is applied in the FahrenheitX100 output domain
(see `wiki/gridworks-scada/executor/hardware-layout.md` "In-field tank-temp calibration"); making
`B` an integer in that domain removes the float/°F ambiguity that had `B` mis-scaled across the
dev → jm/spruce transition. `pytest` green (220).

## 2026-06-15 — WIP: enforce gw.house0.layout axioms (4 + validator template + beech example) (`3422ca9`)

**What:** WIP toward axiom enforcement on `gw.house0.layout/000`: lifted 4 of the stashed axioms
(GlobalIdUniqueness, HydronicStructure, EssentialNodesExistence, ZoneWhitewirePwrChannel) into
`x-gridworks.axioms`, authored the validator template
(`templates/axioms/gw_house0_layout_000.py.jinja2`), and embedded a real bijection-generated **beech
example** (~3.6k lines) so the snapshot round-trip can validate the axioms.

**Why:** subset-first proof of the sema→gwta→scada axiom-enforcement loop. **Caveat — incomplete:**
this is the active axiom-loop WIP; the snapshot build is currently **blocked** by this embedded
example until the bijection adapter serializes the poller with `by_alias` (the on-disk fixtures are
already PascalCase). Resume here for the axiom loop.

## 2026-06-15 — Stash gw.house0.layout axioms; gitignore gwta snapshot tooling (`273815e`)

**What:** Added `definitions/types/gw.house0.layout/stash_axioms.md` — the gw.house0.layout axiom
catalog (22 axioms), ported from the live `gwsproto/data_classes/house_0_layout.py` +
`hardware_layout.py` validations (GNode set, id uniqueness, device-type membership, hydronic
structure, essential + required topology nodes, tank-temp-calibration, system-model energy channels,
sieg manifold, base-layer integrity) plus zone axioms (MVP per-zone whitewire-pwr channel; a
connect-everything zone structure adapted from the nolan stash, using gwsproto/names house0 naming).
Kept as a stash (markdown, deferred enforcement) like gw.nolan.layout. Also gitignored the local-only
`gwta_seed_request.yaml` + `build_gwta_snapshot.sh`.

**Why:** the goal for gw.house0.layout is to carry the data-class validations as sema axioms; this
records the full catalog ahead of wiring enforcement (which needs a real bijection-generated example).

## 2026-06-15 — Add gw.house0.layout + gw1.simple.sim.layout; lay out House0 shape (`470d6db`)

**What:** Created two new layout vocabulary types — `gw.house0.layout` and `gw1.simple.sim.layout`
(`gw.nolan.layout` already existed), with registry entries + `direct_dependencies`. Both began as
minimal `TypeName`+`Version` stubs; then `gw.house0.layout/000` was laid out with the full property
set mirroring `gw.nolan.layout` (new DeviceType model): GNodes, ShNodes, DataChannels,
DerivedChannels, a `Components` oneOf for the House0 set (eGauge `electric.meter`, `ads111x.based`
TSnap, Krida `i2c.multichannel.dt.relay`, `dfr`, `pico.flow.module`, `pico.tank.module` +
`sim.pico.tank.module`, `hubitat.component` + `hubitat.poller.component`, `web.server`), a
`DeviceTypes` oneOf, and a freeform `Hydronic` block — optional-first (only TypeName+Version
required). Indexes + runtime regenerated; `metadata.last_updated` bumped. (The snapshot tooling
`gwta_seed_request.yaml` + `build_gwta_snapshot.sh` — prepare → remap the three layout local names
to `House0Layout`/`SimpleSimLayout`/`NolanLayout` → build → copy to gwta — is kept as local,
untracked tooling in the sema repo, deliberately out of this commit.)

**Why:** Sema is the source of truth for the three mutating layout types; this lays the House0 shape
down so it can be built up bit by bit and round-tripped against scada. `pytest` green (218).

## 2026-06-15 — Add mac.address format; ads OpenVoltageByAdsRange axiom (`abbc250`)

**What:** Added a `mac.address` format (six lowercase hex octet pairs, colon-separated;
`^([0-9a-f]{2}:){5}[0-9a-f]{2}$`) + its runtime validator template, and pointed
`hubitat.gt`'s `MacAddress` at it (`type: string` → `$ref formats/mac.address`, edited in place
— pushed to git but not web-published, so still mutable this session). Added an
`OpenVoltageByAdsRange` axiom to `ads111x.based.component.gt` (each element in [4.5, 5.5]) and
implemented its template. Bumped the `created` of `hubitat.gt` + `hubitat.component.gt` (dep
ordering) and `metadata.last_updated`; added `mac.address` to the property-format test map.
Regenerated; `218 passed`.

**Why:** closes the two "sema looser than gwsproto" divergences from hardware-layout-pass-one —
MacAddress now carries the lowercase-hex constraint (was a plain string), and the OpenVoltageByAds
"near 5V" range is a sema **axiom** (rather than a gwsproto-only Near5 validator or a speculative
format). gwsproto mirrors both (it already used a strict MacAddress type; the Near5 field-validator
became `check_axiom_1`). Snapshot not rebuilt — gwta will be re-snapshotted as a batch.

## 2026-06-15 — Un-draft device-type records + gw.nolan.layout; stash nolan axioms (`7d4f634`)

**What:** Un-drafted the three specialized device-type records (`ads111x.based.device.type.gt`,
`electric.meter.device.type.gt`, `gw1.scada.device.type.gt` — they were never meant to be
drafts) and `gw.nolan.layout/000`. Moved the layout's ~40 axioms into
`gw.nolan.layout/stash_axioms.md` (a markdown file the yaml-globbing tooling/tests skip) and
stripped them from `000.yaml`, so the type generates a runtime **without** axiom validators.
Dropped the `gw108.gpio.relay.component.gt` placeholder from the layout's Components oneOf (the
real relay is `gw108.vdc.relay`, already present), rewrote `direct_dependencies` to the actual
schema $refs (no axiom-only / transitive deps), and bumped `created`. Regenerated; `216 passed`.
`gw.nolan.layout` now has a sema runtime class.

**Why:** the hardware-layout-pass-one branch is building the full layout types now (axioms
implemented later — `gw1.simple.sim.layout` + `gw.house0.layout` to follow the same pattern).
Immutability is push-to-origin this session, so these unpushed un-drafts are still mutable.
`gw1.scada.device.type.gt` stays a partial stub by design (built out as we go). Next: add the
layouts to the gwta snapshot + gwsproto.

## 2026-06-14 — Guard test: every superseded upgrade is defined (no stubs) (`b38e628`)

**What:** Added `tests/runtime/test_superseded_upgrades_defined.py` — for every superseded
published type version that carries an example, decoding it with `auto_upgrade` must reach the
latest version or deliberately raise `UpgradeRequiresContext`; a `NotImplementedError` fails
the test. 44 cases (21 real upgrades, 23 context-dependent refusals). Full suite `216 passed`.

**Why:** an audit prompted by the hardware-layout version bumps found **no** dangling/stub
upgrades — every transition has a defined `upgrade()` (real, or an explicit
`upgrade_requires_context` for cac→DeviceType / FlowMeterType / layout aggregates that need the
source layout). But the scaffold tool seeds new upgrade templates as `raise NotImplementedError`
stubs and nothing caught a left-behind one. This guard closes that gap — the same way examples
and axioms are now enforced. Companion to the gwsproto version-alignment work ([OPS-407](https://linear.app/gridworks/issue/OPS-407)).

## 2026-06-14 — Fix 2 example values to round-trip through gwsproto (`698b1b3`)

**What:** `hubitat.gt` + `hubitat.component.gt` example `MacAddress` `"example"` →
`"34:e1:d1:82:22:22"`; `ads111x.based.component.gt` example `OpenVoltageByAds` `[0.0]` →
`[4.95]`. Non-normative (example-only); no version bump. Regenerated runtime; `172 passed`.

**Why:** sema is looser than gwsproto on these two fields (plain string vs gwsproto
`MacAddress`; bare number vs gwsproto `Near5`), so the auto-generated minimal examples were
sema-valid but gwsproto-invalid. Realistic values let the snapshot's own samples round-trip
through gwsproto unchanged (27/27, no patching). Open question recorded in the
hardware-layout-pass-one design: whether sema should add `mac.address` / `near5` constraints to
close the looseness (that would be a version bump, and gwsproto would follow).

## 2026-06-14 — Implement 6 stubbed axiom validators + add examples to 25 schemas (`a8a7f25`)

**What:** Implemented six axiom-validator templates that were `NotImplementedError`
stubs: `dfr.config`/`ads.channel.config` `CaptureAndPollingConsistency`;
`pico.flow.module.component.gt` `HwUidPattern`; `pico.tank.module.component.gt` +
`sim.pico.tank.module.component.gt` `PicoHardwareIdentityXor` /
`PicoKOhmsConsistency` / `SensorOrderPermutation`;
`i2c.multichannel.dt.relay.component.gt` `ActorAndRelayIndexUniqueness`. Added a
minimal, axiom-satisfying `examples:` entry to 25 schemas (the terminal-asset
snapshot closure) that lacked one. Regenerated runtime + indexes; `172 passed`.

**Why:** the gwta terminal-asset snapshot's round-trip gate could only exercise 2
of 27 types — the rest lacked examples, and 6 also decoded through stub axiom
validators that raise. With the validators implemented (the axiom *statements*
were already published; this only fills in the generator, not a contract change —
permitted as a runtime-consistency fix) and examples added (non-normative,
permitted on published versions), a rebuilt snapshot now reports
"Round-trip OK: 27 sample(s)". `layout.lite/015`'s axiom remains a stub (not in
the terminal-asset closure; its layout-wide invariant is a larger, separate
implementation). The axiom logic is new — flag for JM review against the stated
semantics.

## 2026-06-14 — Add the Hubitat component pair (sema gap-fill complete) (`b7d2cae`)

**What:** Authored the last five beech/house0 component words sema lacked, bottom-up and flat:
`maker.api.attribute.gt/000` (one MakerAPI device attribute → SCADA channel; all `snake_case`
fields re-cased to CamelCase, refs `spaceheat.telemetry.name:007` + `spaceheat.unit:001`);
`hubitat.gt/000` (hub connection settings) and `hubitat.poller.gt/000` (poller settings, a
`ConfigList`-style array of `maker.api.attribute.gt`); and the two flat component shells
`hubitat.component.gt/000` (`Hubitat` → `hubitat.gt`) and `hubitat.poller.component.gt/000`
(`Poller` → `hubitat.poller.gt`), both carrying `DeviceType` (open `pascal.case`) and a
`channel.config` `ConfigList`, mirroring the dfr/ads shells. `MacAddress` modeled as a plain
string (already normalized lowercase-colon at the SCADA boundary; a `mac.address` format was
deliberately NOT added — speculative vocabulary on legacy-only words). Registry + indexes +
runtime regenerated; `172 passed`; the three top-level types decode + re-encode against real
new-shape instances (sema decoder cross-check).

**Why:** closes the component gap-fill — every `*.component.gt` a beech/house0 layout names now
exists in sema. The MakerAPI URL/REST helpers are computed in app code, not serialized, so they
are excluded from the contract and called out in each word's `extended_description` (this
vocabulary serves the five legacy House0 homes with no forward expansion). Shape follows the
migrated sema patterns; the old scada types were a field reference only.

## 2026-06-14 — Begin adding remaining components needed for house0 (`64bce72`)

**What:** Filled four `*.component.gt` types (+ sub-types) that a beech/house0 layout uses but
sema lacked: new `dfr.config/000` → `dfr.component.gt/000`; `ads.channel.config/000` (with
`ThermistorDeviceType` — an open `pascal.case` `gw1.device.type` value, replacing the old
`ThermistorMakeModel` enum field) → `ads111x.based.component.gt/000`; and a new versioned enum
`thermistor.data.method/000` (`SimpleBeta` / `BetaWithExponentialAveraging`). All born flat and
migrated (carry `DeviceType`, no cac). Registry + indexes + runtime regenerated; `172 passed`.

**Why:** Phase 1 added some device-type *records* to sema but missed these *components* and their
channel configs — so a real production (beech) layout could not be fully expressed in the sema
vocabulary. Shape follows the migrated sema patterns; the old scada types are a field reference
only (possibly stale). `near5` deliberately not added as a format (`OpenVoltageByAds` is a bare
number array). Remaining: the Hubitat component pair (needs `snake_case → CamelCase` re-casing).

## 2026-06-14 — Adjusting pico btu and flow meters v 001 (`abc369f`)

**What:** `pico.flow.module.component.gt/001` and `pico.btu.meter.component.gt/001` (both
draft/unpushed — revised in place, no new version): `FlowMeterType` moved from
`$ref spaceheat.make.model` to `$ref formats/pascal.case` (an open `gw1.device.type`
string). Dropped the `spaceheat.make.model` dependency from both `001`
`direct_dependencies`; added an `extended_description` to each; recorded the FlowMeterType
delta in the `000→001` upgrade docstring + the registry summary (kept mirrored);
regenerated indexes + runtime.

**Why:** retiring `make_model` across the hardware-layout vocabulary — device identity is
the readable `gw1.device.type` `DeviceType`. Keeping `FlowMeterType` an open `pascal.case`
string (not an enum `$ref`) keeps the component type version-stable as device types grow;
the enum membership is articulated by the hardware layout that composes the type. Mutated
in place (version `001` preserved) so the aggregate layout words (`gw.nolan.layout`,
`layout.lite`) that compose these types do not rebind.

## 2026-06-14 — Aggregate rebind: gw.nolan.layout DeviceTypeMembership axiom + new layout.lite/015 (cac-free) (`0cd2175`)

**What:** Two aggregate hardware-layout types reconciled to the cac-free `DeviceType`
vocabulary. (1) `gw.nolan.layout/000` (draft): `Components` oneOf rebound to the new
`DeviceType` component versions; `DeviceTypes` swapped from CAC refs
(`component.attribute.class.gt`, `electric.meter.cac.gt`) to the specialized records
(`electric.meter` / `ads111x.based` / `gw1.scada` `.device.type.gt`); the old
`DeviceTypeReferenceIntegrity` axiom reworked into **`DeviceTypeMembership`** (every
Component's `DeviceType` ∈ `gw1.device.type`, and any category needing a specialized record
has a matching `<family>.device.type.gt` in `DeviceTypes`); stale
`DeviceType.ComponentAttributeClassId` dropped from `GlobalIdUniqueness`; `gw1.device.type:000`
added as an axiom dep. (2) **New `layout.lite/015`** — `/014` rebound to the cac-free embedded
component versions (`pico.tank.module` 011→012, `sim.pico.tank.module` 000→001,
`pico.flow.module` 000→001, `i2c.multichannel.dt.relay` 004→005). The `014→015` upgrade is
`UpgradeRequiresContext` (the embedded components migrate cac_id→DeviceType, which needs the
source layout); `/014` gained a compact example (now superseded); the real beech/spruce
upgrade-to-latest tests now assert the context-dependent refusal.

**Why:** [OPS-407](https://linear.app/gridworks/issue/OPS-407), hardware-layout pass one (1.5 tail). The authoritative hardware layout now
expresses the device-type model (components key into specialized records by `DeviceType`,
membership a layout invariant). `layout.lite` needed a NEW version rather than an in-place
rebind: it has a live upgrade chain over real field projections, and the scada emits a
`layout.lite` on boot — `/015` keeps that emission coherent with the migrated components while
old projections (with cac components) refuse to auto-upgrade without context.

## 2026-06-13 — Drop cac_id from all emitted component types → gw1.device.type DeviceType; add draft `<family>.device.type.gt` records (`2d55705`)

**What:** Every emitted component type drops `ComponentAttributeClassId` (the cac UUID)
and gains `DeviceType` (an open `pascal.case` string, a `gw1.device.type` value) as a new
version — `electric.meter` (→002), `gw108.gpio.sensor/relay/vdc.relay` (→002),
`i2c.multichannel.dt.relay` (→005), `i2c.thermistor.reader` (→002), `pico.btu.meter`
(→001), `pico.flow.module` (→001), `pico.tank.module` (→012), `web.server` (→002),
`sim.pico.tank.module` (→001, `SimulatesVersion` 011→012). The two never-emitted sim
types (`sim.sensor`, `sim.relay`) are mutated in place at `/000`. Each new version's
upgrade is `UpgradeRequiresContext` (DeviceType lives on the referenced cac, not the
component); each now-superseded version carries a field-sourced `examples:` block.
Added three **draft** specialized records — `electric.meter.device.type.gt`,
`ads111x.based.device.type.gt`, `gw1.scada.device.type.gt` (minimal stub) — keyed by
`DeviceType`. Froze `component.attribute.class.gt` (`replaced_by: gw1.device.type`) and
`electric.meter.cac.gt` (`replaced_by: electric.meter.device.type.gt`). Also fixed the
generated `new_command_tree` upgrade's mypy typing at its template source.

**Why:** [OPS-407](https://linear.app/gridworks/issue/OPS-407), hardware-layout pass one. Replaces UUID `cac_id` device identity with a
readable `DeviceType`; a plain device is now fully described by its `DeviceType` value +
its own component fields. A CAC that carries real category-level data does not vanish — it
becomes a per-family `<family>.device.type.gt` joined by the shared `DeviceType`.
Immutability is gated on real-world emission in gridworks-scada (spruce/field layouts), so
every emitted type earns a new version; only the never-emitted sim types mutate in place.

## 2026-06-13 — gw1.device.type: drop UnknownDeviceType + GridworksSimMultiTemp, add AbstractWebServer (`d4a3e26`)

**What:** `gw1.device.type/000` now 20 values. Dropped `UnknownDeviceType` (no
"unknown" device type — the scada loudly refuses unknown hardware instead) and
`GridworksSimMultiTemp` (superseded by `GridworksSimSensor`, which is fully configured
from its Component `ConfigList`). Added `AbstractWebServer` — a generic web-server
*service* component (not hardware), replacing the old `UNKNOWNMAKE` web-server hack.
`default` is now `EgaugePowerMeter` — **vestigial**: `DeviceType` is required on every
component, so the enum default is never exercised.

**Why:** [OPS-407](https://linear.app/gridworks/issue/OPS-407). Removing the "unknown" sentinel forces every component to name a real
device type; `AbstractWebServer` keeps the model uniform (every component carries a
`DeviceType`) while honestly marking the web server as a generic service, not a make/model.

## 2026-06-13 — Trim gw1.device.type to referenced device types (47 → 21) (`3c88996`)

**What:** Pruned `gw1.device.type/000` from 47 to 21 values, dropping device types whose
old `MakeModel` had no live reference in `gridworks-scada` (only the CACS tables / enum
def / comments). Kept the device types actually used in `layout_gen` / drivers / real
layouts / tests (incl. both thermistors and `UnknownDeviceType` at that point).

**Why:** [OPS-407](https://linear.app/gridworks/issue/OPS-407) — the enum should carry the device types we actually use, not the full
legacy `spaceheat.make.model` set. Removals verified by searching scada+tlayouts per
make.

## 2026-06-13 — Add gw1.device.type enum (device category replacing make/model-as-CAC) (`a8e0401`)

**What:** New `gw1.device.type/000` enum — 47 PascalCase device-category values (46
device types + an `UnknownDeviceType` sentinel/default), migrated from
`spaceheat.make.model` (each value's description notes its old MakeModel). Registry
`metadata.last_updated` bumped to cover the new `created` date.

**Why:** [OPS-407](https://linear.app/gridworks/issue/OPS-407) (hardware-layout-pass-one) replaces UUID `cac_id` device identity with a
`gw1.device.type` key: a device *category* (PascalCase, the `pascal.case` format), NOT a
make+model — several eGauge models map to one `EgaugePowerMeter`. Components will carry
`DeviceType` as an open `pascal.case` string (version-stable); the hardware layout
enforces membership in this enum. `spaceheat.make.model` is frozen at `/008`. (The
UUID-valued enum + projection was abandoned — sema string-enum values must be Python
identifiers.)

## 2026-06-13 — adjust sema spec rules for enums (`0283544`)

**What:** Added a "String Enum Value Constraints — values are Python identifiers"
section to `spec/authoring/enums.md`.

**Why:** Document the hard constraint the runtime generator already enforces —
`GwStrEnum` sets a string enum's wire value *equal to* its Python member name (via
`auto()` + `_generate_next_value_`), so every value must be a valid Python identifier;
`regenerate_runtime.py` rejects anything else. Surfaced the hard way when a UUID-valued
`gw1.device.type.id` enum + projection (for the device-type bijection) failed to
generate. The note also records the projection corollary (source and target enums must
both have identifier values) and the PascalCase value convention. Lineage: [OPS-407](https://linear.app/gridworks/issue/OPS-407)
(hardware-layout-pass-one), which dropped UUID device ids for a `gw1.device.type` enum.

## 2026-06-13 — Add strict-lint regression test for the generated runtime (`189ec23`)

**What:** New `tests/test_snapshot_strict_lint.py` — prepares the full
`seed_request.yaml` and runs `build_snapshot_runtime("gjk", strict_lint=True)`,
which raises `LintGateError` on any ruff/mypy violation in the generated tree.

**Why:** the existing snapshot-build tests run with the default `strict_lint=False`,
which only *prints* lint violations, so the generator could emit ruff/mypy-dirty
runtime and the suite stayed green — exactly how the gjk-snapshot failures reached a
human (Joe) instead of CI. Verified the guard bites: reverting the three generator
fixes (enum index API, scada.params upgrade typing, typed-map `Any`) makes this test
fail with 7 errors; with them in place it passes. Pairs the three preceding commits
with the test that would have caught them.

## 2026-06-13 — Stop emitting unused `Any` import for typed-map types (`d4b4892`)

**What:** Removed a spurious `ctx.needs_any = True` from the type generator
(`runtime_generation/types.py`) on the typed-`additionalProperties` branch, which
renders `dict[str, <resolved-type>]` (e.g. `dict[str, Gw1TankTempCalibration]`) and
never uses `Any`. Regenerated `runtime/types/gw1_tank_temp_calibration_map.py`.

**Why:** the generator imported `typing.Any` but left it unused for map types, a
ruff `F401`. When the value annotation genuinely needs `Any`, the recursive
`_annotation_for_schema` call sets the flag itself, so the explicit flag was
redundant. Clears the last generator lint violation under the snapshot gate.

## 2026-06-13 — Drop unused `GwStrEnum` index API (`to_index`/`from_index`) (`bf4914c`)

**What:** Removed `to_index`, `from_index`, `_init_index_maps`, and the
`_index_to_value`/`_value_to_index` maps from the generated `GwStrEnum` base
(`runtime_generation/enums.py` literal); regenerated `runtime/enums/gw_str_enum.py`.
Also widened `_missing_(value)` to `object` to match `Enum`.

**Why:** legacy carry-over from gwproto's positional index / symbol wire-encoding —
not part of the Sema enum contract (enums are closed value sets; `spec/authoring/enums.md`
has no index concept) and with zero callers across sema, scada, base, journalkeeper.
Cleared five mypy errors (dynamically-set attrs mypy can't see + the `_missing_` LSP
override). Removes the notion of assigning indices to enum values.

## 2026-06-13 — Type `scada.params` nested-upgrade loop vars as `SemaType` (`863f171`)

**What:** Annotated the `new_params`/`old_params` loop variables in the
`scada.params` 004→005 upgrade template (`upgrades/scada_params_004_to_005.py.jinja2`)
as `SemaType`; regenerated `runtime/types/old_versions/scada_params_004.py`.

**Why:** `scada.params:004` carries `NewParams`/`OldParams` as a `oneOf` of
`ha1.params` 004|005, lifted to 006 via a multi-step `while … .upgrade()` loop (the
only upgrade body that loops). mypy narrowed the loop var to the field union on first
assignment, then rejected the broader `.upgrade()` result. Annotating to the base
`SemaType` (which carries `.version` and `.upgrade()`) lets the polymorphic loop
typecheck. Loop preserved; runtime behavior unchanged — round-trip was always green.
Surfaced only by the snapshot mypy gate.

---

## 2026-06-13 — Draft `MakeModelCacIdConsistency` axiom on `gw.nolan.layout` (`ee9d267`)

**What:** Added a draft (documentation-only) axiom `MakeModelCacIdConsistency` to the
draft `gw.nolan.layout/000`: a DeviceType with a known MakeModel must use that
MakeModel's canonical `ComponentAttributeClassId`; `UnknownMake__UnknownModel` may use
any UUID. No deps added (prose statement); the layout is draft so it generates no
runtime.

**Why:** the in-canon home for the MakeModel↔CAC-id bijection — resolved design:
enforce on the **layout** (self-validating; device-type + components stay
version-stable), not the device-type. Enforcement stays scada-side
(`CACS_BY_MAKE_MODEL`) until the `gw1.cac.id` enum + `gw1.make.model.cac.id`
projection land and the layout publishes. Resolution in
`executor/hardware-layout.md`.

## 2026-06-13 — Reconcile `gw.nolan.layout` draft to the new vocabulary (`38e5129`)

**What:** Updated the (still-draft) `gw.nolan.layout/000` refs to the shared layout
words: `data.channel.gt` 001→002; `i2c.multichannel.dt.relay.component.gt` 003→004;
`pico.tank.module.component.gt` 000→011; the Components `oneOf` now carries the real
nolan set (`gw108.vdc.relay`, `i2c.thermistor.reader`, `sim.pico.tank.module`, plus
the `gw108.gpio.relay` draft); dropped `gw1.scada.device.type.gt` from DeviceTypes;
relay axiom pins `relay.actor.config` 002→003; `heatcall.interpretation` →
`gw1.heat.call.interpretation`. Bumped `created` so it is ≥ its new deps.

**Why:** close the loop on the layout-vocabulary sweep — the draft now references
words that exist. **Kept draft** (publishing/de-drafting deferred; nothing emits a
`gw.nolan.layout` yet).

## 2026-06-13 — Phase-A sim enablers: `make.model/008` + `sim.relay.component.gt/000` (`af2bf49`)

**What:** New enum version `spaceheat.make.model/008` adds `GRIDWORKS__SIM_SENSOR`
+ `GRIDWORKS__SIM_RELAY_BANK` (additive). New non-draft `sim.relay.component.gt/000`
— the flat sim-marker relay component the scada-side `SimRelayActor`'s relay node
uses (`ConfigList` of `relay.actor.config/003`), parallel to
`sim.sensor.component.gt`.

**Why:** Phase-A sema enablers (build-plant "Sema changes needed for Phase A").
Two makemodels because sensor vs relay are distinct device classes (`layout_gen`
dispatch + the `CACS_BY_MAKE_MODEL` bijection key on MakeModel). **Still needed for
sim CACs:** `component.attribute.class.gt/002` (refs `make.model/008`) so a CAC
carrying the sim makemodels decodes — deferred (task #6), along with the complex
`gw1.scada.device.type.gt` (name kept; nested config needs ~5 promoted sub-types).
`pytest` green; no sim-layout fixture yet.

## 2026-06-12 — Add nolan-layout shared vocabulary to sema (flat, non-draft) (`6f73174`)

**What:** Swept most of the shared layout-manipulation vocabulary into sema as
**flat** types — every field spelled out, no base-class inheritance (the gwsproto
`ComponentGt` / `ComponentAttributeClassGt` / `ChannelConfigBase` inheritance is a
flaw, not mirrored; `ConfigList`s compose real config types by `$ref`). New
non-draft words: CACs `component.attribute.class.gt/001` + `electric.meter.cac.gt/001`;
configs `egauge.register.config/000` + `electric.meter.channel.config/000`;
components `electric.meter.component.gt/001`, `gw108.gpio.sensor.component.gt/001`,
`gw108.vdc.relay.component.gt/001`, `web.server.component.gt/001` (inline
`WebServer`), `pico.btu.meter.component.gt/000`, `sim.sensor.component.gt/000` (the
`sim.*`-named simulated-sensor component a SimSensorActor uses); enum
`gpio.sense.mode/000`. `i2c.thermistor.channel.config` and
`i2c.thermistor.reader.component.gt` were **restarted at `001`** — the never-emitted
sema `000`s were dropped (the field only ever emits `001`). `gw108.gpio.relay.component.gt/001`
added as a **draft** placeholder (no gwsproto class). All new types are
**structural-only** (gwsproto axioms deferred).

**Why:** so the plant (`gridworks-terminalasset`) can read and process the *same*
`hardware-layout.json` the scada runs from — the layout's composing types must live
in sema. En route to spruce-unlimbo; reused for sim components.

**Verified (EDD, cross-carrier):** real scada-format instances decode clean through
the sema runtime — `component.attribute.class.gt`,
`electric.meter.{cac,channel.config,component}`, `egauge.register.config`,
`web.server.component.gt` (house0/oak); `gw108.{gpio.sensor,vdc.relay}` +
`i2c.thermistor.{channel.config,reader}` (nolan); `pico.btu.meter.component.gt`
(tlayouts/beech). `component.attribute.class.gt` also confirmed via a **live gwsproto
emit → sema decode**. `sim.sensor.component.gt` has no fixture yet (sema
generated-sample round-trip only). Harness:
`sim-time-experiment/layout_roundtrip_check.py`.

**REVIEW (Jessica):** (1) CACs are structural-only — the `MakeModel↔CAC-id` mapping
is GridWorks deployment policy, not a sema cross-system contract, so the axiom was
dropped. (2) gwsproto emits `null` for absent optionals (sema tolerates it; a design
to stop emitting None is queued). (3) `gw.nolan.layout` draft ref-reconciliation is
still pending. (4) `gw1.scada.device.type.gt` intentionally dropped (CAC→device-type
transition not happening yet).

## 2026-06-12 — Finish the ActorClass cascade + fix an immutability slip (`cc3fac8`)

**What:** New versions `layout.lite/014` and `new.command.tree/002` re-point ShNodes
to `spaceheat.node.gt/302` — `new.command.tree/002` **drops the multi-version
`oneOf`** for a single clean `/302` (upgrade lifts old nodes). **Reverted** the
in-place edit to non-draft `scada.control.capabilities/001` (immutability
violation); its `/302` bump is deferred to the planned admin-for-nolan v002. Added
an `extended_description` "back-dated-traffic anti-pattern" note to 6 old `oneOf`
schemas (`new.command.tree/000`, `layout.lite/009/010/011`, `scada.params/004`,
`report/002`).

**Why:** complete the actor-class ripple through the published embedders while
respecting immutability (non-draft schema = no functional change → new version).
The old `oneOf` unions are flagged as a sema-bring-up lenience, not propagated.

## 2026-06-12 — `spaceheat.node.gt/302` + ActorClass cascade (`2b9e099`)

**What:** New `spaceheat.node.gt/302` re-points `ActorClass` to `gw1.actor.class/012`
(picks up `SimSensorActor`/`SimRelayActor`); trivial 301→302 upgrade, axiom
implementations ported, hand-written tests bumped + a v302 fixture. The two
embedders re-pointed **in place** (unpublished/draft): `scada.control.capabilities/001`
and `gw.nolan.layout/000` → `/302` (their `created` bumped to 2026-06-12 to satisfy
causal-timestamp ordering).

**Why:** the ActorClass cascade — adding the two sim actor classes forces a
`spaceheat.node.gt` bump and everything embedding it. `data.channel.gt` /
`derived.channel.gt` reference nodes by *name*, so they don't ripple. Remaining
embedders `layout.lite` + `new.command.tree` (both published) are separate version
bumps, still pending.

## 2026-06-12 — Add `gw1.actor.class/012` — `SimSensorActor` + `SimRelayActor` (`a7aa496`)

**What:** New enum version `gw1.actor.class/012` appends `SimSensorActor` and
`SimRelayActor` (`011` preserved under `old_versions/`); registry + indexes +
runtime regenerated. (The commit title reads "v011"; the diff adds `012`.)

**Why:** The two scada-side actors of the simulated test environment need
actor-class identities — `SimSensorActor` reads `sim.plant.flux` →
`synced.readings`, `SimRelayActor` sends `sim.plant.actuation`. First step of the
`ActorClass` cascade; the `spaceheat.node.gt/302` bump that picks up `012` follows.

## 2026-06-12 — Mint `sim.plant.actuation/000` + `change.relay.pin/000` enum (`81005bc`)

**What:** New type `sim.plant.actuation/000` — the actuation *event* a SimRelayActor
sends to the plant: `RelayName` + `Action` (Energize/DeEnergize via the new
`change.relay.pin` enum) + `ActuationTimeUnixMs` (sim time) + `ActualTimeUtc`
(human-readable). New string enum `change.relay.pin` (DeEnergize/Energize),
mirroring gwsproto's `ChangeRelayPin`. Regenerated indexes + runtime.

**Why:** The inverse boundary of `sim.plant.flux`: a simulated relay sends its
energize/de-energize event — the i2c multiplexer's atomic pin action, *not* the
closed/open interpretation (which depends on wiring) — into the plant, which
resolves the physical effect from the layout. Modeled as an event, not a state,
because actuation is an event. `change.relay.pin` was minted because sema had only
`change.relay.state` (CloseRelay/OpenRelay = the wiring-dependent closed/open
framing) and `relay.energization.state` (a state).

## 2026-06-12 — Mint `sim.plant.flux/000`, the simulated plant's source emission (`386ea55`)

**What:** New versioned type `sim.plant.flux/000` (+ registry entry, regenerated
indexes/runtime, filled `ListLengthConsistency` axiom template). Fields:
`ChannelNameList` + `ValueList` (index-aligned), `ScadaReadTimeUnixMs` (sim time,
`utc.milliseconds`), `ActualTimeUtc` (wall-clock, human-readable
`utc.iso8601.millis`). No `Simulates*` identity fields. Bumped
`metadata.last_updated` to 2026-06-12.

**Why:** The simulated terminal asset (gwta) emits its physical state as
`sim.plant.flux`; the scada-side sim sensor reads and *interprets* it into
`synced.readings` (and electrical/other derived signals later). It is the
plant-emits/sensor-reads boundary word of the SCADA simulated test environment
([OPS-40](https://linear.app/gridworks/issue/OPS-40)). Two timestamps because under sped-up coordinator time the sim clock
outruns the wall clock — `ActualTimeUtc` is human-readable provenance for CSVs,
not consumed downstream. `Simulates*` was dropped deliberately: the plant's raw
emission must not presume its destination.

## 2026-06-10 — Runtime ruff-clean at source: generator formats, drift guards compare formatted (`cdeba05`)

**What:** `generate_runtime_from_dag` now runs `ruff format` (`format_in_place`)
as its final pass, so the committed `src/sema/runtime` is ruff-clean. The four
`test_runtime_generation_*` drift guards format the generated output before
comparing (so canonical = formatted on both sides). Regenerated the runtime —
45 files reformatted once — and updated `regenerate_runtime.sh`'s header to
state the new canonical (ruff-formatted) and that its `ruff format --check` now
passes clean ("157 files already formatted").

**Why:** Permanently closes the *format* half of the `regenerate_runtime` trap.
Previously canonical was the *raw* generator output, so `ruff format` diverged
from it — the reason an in-place format in the `.sh` broke the drift guards.
Making ruff the single source of style (templates need not match it) means
`--check` is green and the format trap cannot recur; it also unifies the in-repo
runtime with the snapshot path, which already treated ruff-formatted as
canonical. This is the deferred follow-up to `a4a8b83`. The remaining `ruff
check` + `mypy` findings (over-/under-tracked typing imports; pydantic/enum
dynamics) are a *separate* report-only generator-cleanup follow-up, untouched
here.

## 2026-06-10 — new.command.tree/000 axiom: PrefixClosedHandles via effective handle (`668f00f`)

**What:** Rewrite `new.command.tree/000` axiom 1 from `PrefixClosedHierarchy`
(two-part: ShNode `Handle` *and* `ActorHierarchyName` each prefix-closed) to
**`PrefixClosedHandles`** — a single prefix-closure rule over each node's
*effective handle* (its `Handle` if present, else its `Name`). Rewrites the
axiom template + regenerated runtime enforcement, enriches the
`extended_description` (command-authority chain, runtime bossable-actor
`FromHandle`/`ToHandle` checks → `bad_boss` Glitch, dynamic handle reassignment,
dormant/root nodes), and adds a real-world `real_maple.json` fixture + test. The
`ShNodes` `oneOf [200, 300, 301]` widening was already on dev, so this commit is
axiom-only (no registry/index change).

**Why:** Captures what the SCADA↔LTN command tree actually does in the field.
The effective-handle convention lets a root node omit `Handle` on the wire (its
`Name` anchors children) while still participating in prefix-closure, and the
single-rule axiom matches the runtime enforcement bossable actors already
perform. **Modified `000` in place rather than bumping to `001`** — a deliberate
source-precedence call (rule 1, explicit instruction): field reality before sema
was well-structured is the higher truth, overriding the additive/version-bump
MUST, since `000` is pre-production. Faithful replay of `jm/fix-new-command-tree`
onto current dev: that branch forked from an ancient dev (~150-file divergence),
so the substantive delta was replayed on a clean branch + regenerated, not
merged.

## 2026-06-10 — gw1.unit/002 + regenerate_runtime.sh hygiene-report (`a4a8b83`)

Landed as one commit ("Various — gw1.unit/002 from Joe and various cleanups").
Two distinct changes:

**(1) Add `gw1.unit` version 002** (`DollarsX1000`, `MilesPerHourX1000`,
`KilowattHoursX1000`). `registry.yaml` (`latest_version: 002` + the `002` entry)
and the new `definitions/enums/gw1.unit/002.yaml`, then regenerated indexes +
runtime. Additive only; `000`/`001` preserved verbatim (frozen
`runtime/enums/old_versions/gw1_unit_001.py`). The runtime regen wired the new
member into the three types that reference `gw1.unit` (`derived_channel_gt`,
`gw1_unit_quantity_projection`, `synced_readings_bundle`).

*Why:* makes those 3 members canonical, so the gridworks-journalkeeper snapshot
regen ([OPS-386](https://linear.app/gridworks/issue/OPS-386)) no longer drops units its persistors use — they had been
hand-patched into JK's old snapshot. This *replays* Joe's reviewed schema delta
(`jds/dollarsX1000`) onto current `dev` rather than merging his stale branch;
merging the 29-commits-behind branch produced generator/formatting drift (4
`test_runtime_generation_*` failures), whereas replaying the delta and
regenerating with `dev`'s own generator is clean.

**(2) `regenerate_runtime.sh` reports hygiene, never mutates the runtime.**
Change `ruff format` from an in-place rewrite to `ruff format --check` (report
only), alongside the already report-only `ruff check` / `mypy`; `--strict` still
makes any finding fatal.

*Why:* the canonical runtime is the *raw* `regenerate_runtime.py` output — what
the committed tree is and what the `test_runtime_generation_*` drift guards pin.
The in-place `ruff format` rewrote the runtime into a *different* form (it wraps
the over-long `e.compile(...)` line in `property_format.py`), so a regen via the
`.sh` silently diverged from canonical and turned the drift guards red — a trap
that cost real time. Report-only converges the `.sh` with the `.py` (the
generator is deterministic, so no formatting step is needed for zero-diff), so
**either entrypoint is now safe.** Making the generated runtime ruff-clean *at
the source* (so `--check` passes clean and the trap cannot recur) is the next
step.

## 2026-06-09 — Merge pull request #21 — jm/ops-380-snapshot-improvement (`8293b4e`)

**What:** Merge landing the [OPS-380](https://linear.app/gridworks/issue/OPS-380) snapshot-improvement branch on `dev`. The
constituent commits each have their own entries below (`bea9846`, `ee5bd53`,
`0169b47`, `653a152`, `701495c`, `be72b40`, `6f68508`).

**Why:** Collectively: snapshot builds became deterministic (zero-diff regen
via canonical formatting + stable ordering), atomic (failed gate = no-op), and
gated (round-trip over generated samples, with the context-dependent-upgrade
exemption), with the contract canonized in `spec/snapshot.md`. Consumers
regenerating a snapshot no longer fight cosmetic formatter drift — this
resolves the 2026-05-25 finding where ~75% of a gjk snapshot-refresh diff was
ruff-format noise.

## 2026-06-08 — feat: UpgradeRequiresContext for context-dependent upgrades (`701495c`)

**What:** New `UpgradeRequiresContext(SemaError, ValueError)` in the
runtime base (`templates/base.py.jinja2`) + a `SemaType.upgrade_requires_context()`
factory so an upgrade body raises it via the already-imported `SemaType` (no new
per-file import). The three upgrades that legitimately cannot run on a standalone
instance — `scada.control.capabilities/000→001`, `send.layout/000→001`,
`linear.one.dimensional.calibration/000→001` — now raise it instead of a bare
`ValueError`. The shipped round-trip gate (`templates/roundtrip.py.jinja2`) and
the build-time check catch `UpgradeRequiresContext` in the decode-old→upgrade
step and treat it as an **expected pass** (the sample still must round-trip at its
own version). Runtime regenerated; spec `authoring/type-semantics.md` Upgrade
Discipline documents the contract.

**Why:** [OPS-380](https://linear.app/gridworks/issue/OPS-380) thread 4 mandates an example on every superseded version and the
gate upgrades each sample to latest — but some `old→new` transforms need
out-of-band context (layout handles/ids, source message) an isolated message
can't carry, so their `upgrade()` correctly refuses. A bare `ValueError` made
"refuses by design" indistinguishable from "broke." The typed exception lets the
gate exempt exactly those versions from the upgrade round-trip while keeping the
example mandate + decode-own-version coverage (the `atn.bid`-class check) intact.
`scada.control.capabilities/000` (in the thread-4 backfill set) is the version
that forced this.

## 2026-06-09 — drop rolled-back structured-enum residue (`6f68508`)

**What:** `CLAUDE.md` Universal MUSTs — removed the `(for structured enums this
extends to attribute rows/columns…)` parenthetical from the enums-are-additive
bullet. Structured enums were rolled back (`0bf8f0f`), so the clause referenced a
capability that no longer exists.

**Why:** Stale residue left by the structured-enums rollback; surfaced while
closing out the `untangle-market-type-name` design ([OPS-378](https://linear.app/gridworks/issue/OPS-378)). Keeps the operative
instructions honest.

## 2026-06-08 — backfill: examples on 20 superseded versions, flip gate, fold snapshot spoke (`be72b40`)

**What:** (1) A minimal, schema-valid, axiom-consistent `examples:` block on each
of the 20 superseded type versions that lacked one (enumerated by
`tests/registry/test_superseded_examples.py`): `channel.readings/001`,
`flo.params.house0/003-006`, `fsm.full.report/000`,
`i2c.multichannel.dt.relay.component.gt/002-003`, `layout.lite/007-012`,
`report.event/002-003`, `scada.control.capabilities/000`, `scada.params/004`,
`spaceheat.node.gt/200,300`. Each round-trips at its own version and, where the
upgrade is runnable, along `decode-old → upgrade() → decode-current`
(`scada.control.capabilities/000` is upgrade-exempt via `UpgradeRequiresContext`,
`701495c`). Several were mined from existing field/test fixtures (the `layout.lite`,
`report.event`, `i2c`, `spaceheat.node.gt/300` instances); the rest authored
minimal. (2) The `xfail` marker is removed from `test_superseded_examples.py`,
promoting it to a hard gate. (3) Folds the design's durable architecture into a
new language-neutral `spec/snapshot.md` spoke (determinism/zero-diff, atomic
build, `samples/`, the round-trip gate + context-dependent-upgrade exemption),
linked from `spec/primary.md`; Python tool specifics stay in the
`src/sema/tools/` docstrings per the in-repo-spec / wiki-pointer split.

**Why:** [OPS-380](https://linear.app/gridworks/issue/OPS-380) thread 4 — completes the mandate landed in `ee5bd53` so the
snapshot round-trip exercises every old version along the upgrade path where
restricted-snapshot bugs concentrate (the `atn.bid` class; this same pass already
surfaced the `layout.lite/007→008` ShNodes-lift bug fixed in `0169b47`). Folding
the durable architecture into `spec/` is the prerequisite to deleting
`wiki/sema/designs/snapshot-improvement.md` (per designs-process); the design
file is removed once this lands.

## 2026-06-08 — test: enforce upgrade docstring ↔ registry summary mirror (`653a152`)

**What:** New `tests/registry/test_upgrade_summary_matches_template.py` asserts
that for every `templates/upgrades/<type>_<a>_to_<b>.py.jinja2`, the upgrade
docstring equals `registry.yaml` → `types.<type>.versions.<b>.summary` (modulo
whitespace) — true for all 30 upgrade templates today. Plus a `CLAUDE.md`
"Upgrade deltas live in three coupled places" note naming the
template-body+docstring / registry-summary / `direct_dependencies` triple and
pointing at the spec's "Nested Upgrades" rule.

**Why:** The `007→008` ShNodes omission drifted silently because the prose
summary and the upgrade docstring (mirror copies) were maintained by hand with
no gate, while the machine `direct_dependencies` stayed correct. The test turns
that mirror into an enforced invariant — editing one side without the other now
fails CI — and the `CLAUDE.md` note makes the coupling discoverable so a future
session checks the registry when it touches an upgrade.

## 2026-06-08 — fix: layout.lite 007→008 upgrade lifts ShNodes 200→300 (`0169b47`)

**What:** `templates/upgrades/layout_lite_007_to_008.py.jinja2` (and its
regenerated output `runtime/types/old_versions/layout_lite_007.py`) now lifts the
embedded `ShNodes` list through `spaceheat.node.gt` `200 → 300` during the
`007 → 008` upgrade: `data["sh_nodes"] = [node.upgrade() for node in self.sh_nodes]`,
plus the matching docstring line. The same change-line was missing from the
registry's prose record, so `registry.yaml` → `layout.lite.versions.008.summary`
gains `- ShNodes[]: spaceheat.node.gt:200 -> 300` (the version's
`direct_dependencies` already carried `spaceheat.node.gt:300` — only the summary
had drifted); `indexes/public_registry.yaml` + `indexes/versions.yaml` rebuilt to
match. (No version bump — completing a non-normative summary is a permitted
descriptive correction.)

**Why:** `layout.lite/007` declares `ShNodes: spaceheat.node.gt/200`, but
`LayoutLite008` accepts only `300` — the `007 → 008` upgrade bumped the version
and added the new top-level fields yet never lifted the embedded nodes, so any
`007` instance carrying nodes raised a `literal_error` on upgrade. The gap had
gone unnoticed because no old-version `layout.lite` fixture exercised the chain
(fixtures start at v011, whose nodes are already `301`). Surfaced by the [OPS-380](https://linear.app/gridworks/issue/OPS-380)
thread-4 backfill: a realistic `layout.lite/007` example must round-trip
`decode-old → upgrade() → decode-current`, which is exactly the path this gate
exists to protect (the `atn.bid` class). The sibling steps in the chain
(`009→010` ha1 guard, `011→012` sub-type lifts, `012→013` i2c None-guard) were
audited against the per-version field types and are correct.

## 2026-06-08 — spec: superseded type versions MUST carry examples (`ee5bd53`)

**What:** Two spec edits + a new (xfail) enforcement test, no schema/data
changes. `spec/registry/types.md` "Permitted Changes (All Types)": added a
bullet explicitly permitting *addition or improvement of non-normative
`examples`* on a published version (same family as "clarification of descriptive
text" — alters no validation behavior). `spec/authoring/types.md`: retitled
"Examples (Optional)" → "Examples" and added a "Superseded versions" rule — a
type version that has a successor MUST carry at least one `examples:` entry;
latest versions and versionless types stay optional. New
`tests/registry/test_superseded_examples.py` enforces the mandate by walking
`definitions/types/`; marked `xfail` (non-strict) until the one-time backfill of
existing old versions lands ([OPS-380](https://linear.app/gridworks/issue/OPS-380) thread 4), at which point it xpasses and
the marker is removed.

**Why:** Superseded versions exist to be **upgraded**, and the
`decode-old → upgrade() → decode-current` path is where restricted-snapshot bugs
concentrate (the `atn.bid` class). The snapshot round-trip can only exercise a
version it has a fixture for, and the fixture is the authored `examples:` entry
(→ a generated sample). So every superseded version needs an example for
old-version round-trip coverage to be total. Permitting examples on published
versions removes the immutability grey area that would otherwise block the
backfill — examples are non-normative guidance, not validation behavior. Part of
[OPS-380](https://linear.app/gridworks/issue/OPS-380) (thread 4, spec half; the example backfill itself follows separately).

## 2026-06-08 — snapshot: round-trip gate + generated samples + lint-gated atomic build (`bea9846`)

**What:** Reworked `sema snapshot build` (`src/sema/interfaces/cli/snapshot.py`)
to generate into a **staged** tree, gate it, and swap into place only on green —
a failed gate is a no-op (the previous snapshot is left untouched), replacing the
old clear-then-write that could half-write on failure. New gates:

- **`samples/`** ([OPS-380](https://linear.app/gridworks/issue/OPS-380) thread 3) — `src/sema/tools/snapshot_check.py` runs in a
  subprocess against the staged package and, for every type version under
  `definitions/` with an `examples:` block, feeds the first example through the
  snapshot codec (`from_dict → to_dict`) and writes the canonical serialized form
  to `samples/<type.name>[.<version>].json` (old versions included). Writes a
  coverage `samples/README.md`. Samples are the exact wire bytes the runtime
  emits, so they double as the round-trip's expected output and don't churn.
- **Round-trip gate** ([OPS-380](https://linear.app/gridworks/issue/OPS-380) thread 2) — a new shipped, pydantic-only
  `roundtrip.py` harness (`templates/roundtrip.py.jinja2`, emitted by
  `generate_runtime.py`) walks `samples/`, decodes each at its own version,
  re-encodes (deep-equal), and upgrades superseded versions to latest. Run
  build-time over the staged tree (raises → no-op) and re-runnable consumer-side.
  This is the check that catches a word missing only from the *restricted*
  snapshot (the `atn.bid` class). `tests/test_snapshot_roundtrip.py` proves it
  flags a non-decoding sample.
- **Lint gate** ([OPS-380](https://linear.app/gridworks/issue/OPS-380) thread 1) — `src/sema/tools/snapshot_lint.py` runs
  `ruff format` in place (the generator already sorts output, so format makes a
  re-build a zero diff) and reports `ruff check` / `mypy` (fatal only under
  `--strict-lint`, because the generator emits known pre-existing violations
  that are a tracked cleanup). New `scripts/regenerate_runtime.sh` applies the
  same gates to the in-repo runtime.

Stopped vendoring `tests/` into snapshots: removed the `write_tests` path
(`generate_runtime.py`, `formats.py` — deleted `generate_property_format_test`)
and its emission at the build call site; snapshots now ship `samples/` +
`roundtrip.py` instead of generated test code. Updated `test_snapshot_cli.py`
(asserts no `tests/`, presence of `samples/` + `roundtrip.py`) and dropped the
obsolete `write_tests` unit test.

**Why:** Standing up the gridworks-journalkeeper snapshot surfaced four
frictions: formatting-only regen churn that buries real diffs; generated test
*code* leaking into the consumer package; no per-type decode test (the gap that
let the `atn.bid` closure bug ship); and no ready JSON fixtures per type. The
round-trip gate makes "does the emitted runtime decode its own types" a
build-time invariant against the *restricted* vocabulary — exactly where a
sema-runtime test can't see the bug. Atomic staging means a failing gate can
never corrupt a consumer's snapshot. `ruff format` + the generator's existing
sorting make a second regen a zero diff. Part of [OPS-380](https://linear.app/gridworks/issue/OPS-380) (threads 1–3).

---

## 2026-06-08 — drop snapshot.built_at from the restricted registry (`c1d9dad`)

**What:** Removed the wall-clock `built_at` field (and the now-empty `snapshot:`
section) that `build_restricted_registry` injected into the snapshot's
`registry.yaml` (`src/sema/tools/build_seed_definitions.py`); dropped the
now-unused `datetime`/`timezone` import; updated `_is_top_level_sections_mapping`
to expect `[metadata, formats, enums, types]`.

**Why:** `built_at` was non-deterministic — it made every snapshot regen diff on
`registry.yaml` regardless of generated-code formatting, blocking the zero-diff
goal ([OPS-380](https://linear.app/gridworks/issue/OPS-380), thread #1). Nothing reads it; snapshot provenance is already
carried by the copied `metadata.registry_version` + `last_updated`. Dropping the
`snapshot:` key also makes the restricted registry conform to the spec's
top-level structure — `metadata/formats/enums/types`, which has no `snapshot`
section (`spec/registry/structure.md`). Part of [OPS-380](https://linear.app/gridworks/issue/OPS-380).

---

## 2026-06-08 — remove structured enums. market slots must be divisible by 300 (`0bf8f0f`)

**What:** Removed the unpublished structured-enum capability from the prior
commit. Reverted `spec/authoring/enums.md`, `spec/registry/enums.md`, and the
`spec/primary.md` enum-glossary line (drops the "Structured Enums" section +
`value_attribute_schema`/`value_attributes` rules); restored the codegen path
(`src/sema/tools/runtime_generation/enums.py`) and runtime base
(`src/sema/runtime/enums/gw_str_enum.py`) to pre-capability; demoted
`gw.market.product.name` to a plain versioned enum (`value_descriptions` only).
Kept the rest of the untangle — the `market.type.name → gw.market.product.name`
rename, the `market.product` type, the pure-pattern `market.slot.name` format,
and `frozen_at`. Added a one-line clarification to `spec/authoring/formats.md`
that the no-reference rule binds a format's validation behaviour / generated
validator, not just its schema `$ref`. Same cluster, two additions: (1) enrich
`market.product` with the name-encoded fields it now carries as validated data —
`SlotDurationMinutes`, `GateClosingSeconds`, and `QuantityUnit` (`$ref`
`market.quantity.unit`, a power unit so quantities compare across slot
durations); `Timeframe` deferred. (2) Bake the 5-minute grid invariant into the
`market.slot.name` validator (slot start MUST be divisible by 300) — a
vocabulary-free arithmetic check, so it does not reintroduce the format→enum
edge the gjk fix removed.

**Why:** `market.slot.name` became a pure structural pattern (the real gjk fix),
removing the slot-start/period alignment check — the only in-vocabulary consumer
of the structured enum's per-product `slot_minutes`. With no consumer left, the
capability was complexity for nothing: a fragile hand-rolled codegen path (its
integer case stubbed with a `raise`) and a third home for semantics with weaker
guarantees (primitive-only, unvalidated free-text units). Name-decodable
semantics belong on the `market.product` **type** (real `$ref`'d fields) and in
axioms — mirroring the legacy `MarketTypeGt` and the market-product taxonomy's
"name + rich type" verdict. Unpublished, so the rollback is clean. See [OPS-378](https://linear.app/gridworks/issue/OPS-378) +
`wiki/sema/designs/untangle-market-type-name/rollback-structured-enums.md`.

## 2026-06-08 — Untangle market.type.name into structured gw.market.product.name + market.product type (`8190fdb`)

**What:** The complete `untangle-market-type-name` work ([OPS-378](https://linear.app/gridworks/issue/OPS-378)), squashed.
Two reusable Sema capabilities applied to the market vocabulary, while keeping
the universal market messages uniform across makers:

- **Structured enums** (`spec/authoring/enums.md` "Structured Enums") — enum
  values may carry a fixed, typed row of primitive attributes
  (`value_attribute_schema` + `value_attributes`), codegen'd as a frozen
  `…Attrs` dataclass + a `.attrs` accessor (deferred module-level table so the
  Enum metaclass doesn't absorb it). Zero closure edges (attributes are
  primitives, never `$ref`). Authored `enums/gw.market.product.name/000.yaml` —
  GridWorks's product vocabulary; each token decodes to
  `timeframe / slot_minutes / gate_minutes / quantity_unit`; `unknown` is the
  row-less default sentinel.
- **`market.product` type** — an open, maker-agnostic product object
  (`MarketProductId` uuid · `ProductNameEnum` left.right.dot · `Name` bare
  token). It names *which* maker's product vocabulary a token belongs to without
  pinning one, so one shared type scales across thousands of makers; the decode
  is opt-in, consumer-side.
- **`frozen_at` word-status** (`spec/registry/structure.md`) — a word-level
  RFC-3339 marker closing a version lineage (no new versions), orthogonal to
  `replaced_by`. Used to retire-in-place: `market.type.name` →
  `replaced_by gw.market.product.name`; `atn.bid` → `replaced_by bid`. Legacy
  words stay valid and decodable forever; they are not deleted.
- **`market.slot.name` kept maker-agnostic & shape-only** — de-tangled to a
  self-contained, versionless leaf whose single regex enforces commodity
  `[erd]` · a `spaceheat.name`-shaped product token · a `left.right.dot` maker
  alias · 10-digit slot start. It no longer reaches any enum. So `bid` and
  `latest.price` stay **uniform across all market makers** (no per-maker bid
  types); product-token validity and slot-start alignment are decoded opt-in,
  receiver-side, against that maker's structured product enum.

**Why:** `market.type.name` conflated a market *product* (a named, decodable
thing) with the *type of market*, and the legacy `market.slot.name` validator
reached the `MarketTypeName` enum through an edge the dependency closure couldn't
see — the gridworks-journalkeeper `ModuleNotFoundError`. The fix puts product
semantics in a structured enum (decodable in the vocabulary, not a side table),
keeps the shared slot-name format shape-only so it carries no hidden vocabulary
edge (that class of bug is gone **by removal**), and retires the old words in
place via `frozen_at`/`replaced_by` rather than deleting them. Keeping the slot
format maker-agnostic is what lets `bid`/`latest.price` stay a single shared
contract; each market owner instead publishes its own
`<ns>.market.product.name` structured enum (see
`wiki/gridworks-marketmaker/explorations/market-product-and-uniform-bids.md`).

Note: an interim "versioned property formats" approach (a slot-name format
declaring a registry axiom dependency on the product enum) was prototyped and
then reverted in favor of this simpler maker-agnostic shape-only format — it
nets to zero in this squash. `gw.market.product.name`'s `rt60gate30b` row uses
the design's decode (60-min slot / gate 30 / AvgkW); MarketMaker remains the
source of truth — confirm before relying on that token's decode.

---

## 2026-05-29 — Adjust GNodeClass concepts (`b843710`)

**What:** Two enum edits:

- `definitions/enums/gw.g.node.class/000.yaml` — remove
  `TimeCoordinator` from the enum AND its value-description block.
  The enum is unpublished, so removal is permissible (per Sema's
  "enums are additive only" MUST, which binds only after publication).
- `definitions/enums/base.g.node.class/000.yaml` — port the
  `ced7cec` tightening of the `Logical` value-description from the
  `jm/effortless` branch onto `dev`. Replace
  *"purely logical or service-level nodes such as SCADA, forecasting
  services, market-maker actors, simulation nodes, or organizational
  microservices..."* with *"Used by GridWorks for SCADA and forecasting
  services."*

**Why:** Both edits land the same architectural distinction that's
emerging in `gridworks-base`: GNodes are grid entities (physical +
logical) participating in the production control plane; system
services (Supervisor, TimeCoordinator, journalkeeper, ear actor-side)
are NOT GNodes even if they ride the same rabbit+sema toolkit.

TimeCoordinator specifically: its role is "maintaining simulation
time or orchestrated test time across actors." That's a system
service, not a grid entity. The tightened `base.g.node.class/Logical`
explicitly excludes "simulation nodes" and "organizational
microservices." TimeCoordinator fits both excluded categories.
Symmetry with Supervisor (also non-GNode but a control-plane
orchestrator) becomes clean after this change.

The base.g.node.class fix-forward closes a branch-discipline issue:
the tightening was made on `jm/effortless` (which hasn't merged to
dev) but the lexicon-level distinction is dev-applicable.

Supports the in-flight
`wiki/gridworks-base/designs/support-non-gnode-actors/` design —
specifically the `orchestrator.md` (formerly `control-plane-tier.md`)
sub-spec, which lifts the heartbeat + sim.timestep machinery into a
middle `Orchestrator` tier that both Supervisor and TimeCoordinator
can extend without GNode identity.

## 2026-05-29 — ignore top level seed_request.yaml (`ce5e770`)

**What:** Add `seed_request.yaml` to the repo-root `.gitignore`.

**Why:** The repo-root `seed_request.yaml` is a scratch seed for exercising
`sema snapshot prepare` locally (e.g. validating that the
gridworks-journalkeeper closure pulls `market.slot.name` → `market.type.name`).
It is distinct from the canonical per-consumer seed
(`gridworks-journalkeeper/src/gjk/sema_seed_request.yaml`) and the committed
`template_seed_request.yaml`; ignoring it keeps ad-hoc snapshot experiments out
of version control.

## 2026-05-27 — tweak base g node class (`ced7cec`)

**What:** Narrow the `Logical` value description in
`definitions/enums/base.g.node.class/000.yaml`. Replace
*"purely logical or service-level nodes such as SCADA, forecasting
services, market-maker actors, simulation nodes, or organizational
microservices..."* with *"Used by GridWorks for SCADA and forecasting
services."* Removes "market-maker actors", "simulation nodes", and
"organizational microservices" from the named examples.

**Why:** Aligns Sema's lexicon with the architectural distinction
emerging in `gridworks-base`: GNodes (Physical + Logical) are
production control-plane participants; services that use the gwbase
rabbit+sema toolkit without joining the production GNode system
(journalkeeper, ear's actor-side, future analytics consumers) are
explicitly NOT Logical GNodes. The prior description's
"organizational microservices" phrasing invited the journalkeeper-
as-Logical-GNode reading the design is moving away from. Narrowing
to *only* SCADA + forecasting services removes the ambiguity.
Supports the in-flight `wiki/gridworks-base/designs/support-non-gnode-actors/`
design (ServiceSettings vs GNodeSettings split).

Side-effect to track separately: Supervisor and TimeCoordinator —
both in `TransportClass`, both control-plane participants, neither
in `base.g.node.class` — are now also outside Logical's scope. They
were never strictly GNodes, but the design implications surface
during the gwbase refactor (see `wiki/gridworks-base/designs/support-non-gnode-actors/`).

## 2026-05-26 — merge dev (`0d07927`)

**What:** Merge commit `0d07927` bringing `origin/dev` into the local
`ej-dev` line. Brings in a large batch of dev-landed changes:
`active`→`published` lifecycle rename, new format definitions
(`non.empty.string`, `positive.int.as.str`), several type-version
adjustments, the new top-level `spec/` folder, deletion of the old
`docs/` tree (content relocated to wiki), regenerated indexes, and
the dev-branch sema-vocabulary CLAUDE.md.

**Why:** Sync point so the `jm/effortless` work (port move, swap
claudes, eventual web-app refactor) sits on top of current dev rather
than the older ej-dev branch base. Brings the dev-lens authoring
conventions into reach on this branch — required for the two-lens
CLAUDE.md pattern (effortless_CLAUDE.md committed + gitignored
personal CLAUDE.md) to be meaningful.

## 2026-05-26 — swap claudes

**What:** Pure rename (R100, 0 line changes) of the committed
`sema/CLAUDE.md` to `sema/effortless_CLAUDE.md`. The file content — EJ's
ERB-lens framing of sema (rulebook-as-SSoT, `effortless build` discipline,
effortless skill suite) — is unchanged. Done on the `jm/effortless`
branch.

**Why:** sema's `.gitignore` already ignores `CLAUDE.md`, so renaming the
committed copy out of that slot lets each developer keep their preferred
*local* `CLAUDE.md` (a personal working-frame override) without touching
the team-shared recipe. The team-shared recipe for the ERB-pipeline side
now lives at the explicit name `effortless_CLAUDE.md`, and individual
devs (jess, ej, …) can layer their own gitignored `CLAUDE.md` on top —
e.g. jess's local copy uses the dev-branch sema-vocabulary lens (axiom /
registry / `/make-sema-word` discipline). See
the "Integrate the two sema
CLAUDE.mds" for the integration plan.

## 2026-05-26 — move sema-pg from host port 5433 to 5434

**What:** Eight files in sema/ updated to point local Postgres at host port
5434 instead of 5433 (and unify the lingering 5432 defaults that drifted
from the script): `start-db.sh` (PORT + header rationale),
`postgres/init-db.sh` (DEFAULT_CONN), `app/api/db.py` (default fallback),
`app/api/.env.example`, `app/README.md` (rationale paragraph + Docker
snippet + DB-connection blurb), `DEPLOY.md` (two URL references),
`postgres/migrations/README.md`, and `CLAUDE.md` (DB connection line +
note on what occupies 5432/5433).

**Why:** First step of harmonizing ej-dev sema with the rest of the
GridWorks dev fleet. `gw-data-pg` (the analytics TimescaleDB container,
see `gridworks-data/README.md`) holds host port 5433 unconditionally; a
dev who runs both gets a port collision today. The two systems are
sufficiently separate (different code paths, different teams, sema doesn't
need TimescaleDB) that consolidating into one container is the wrong
move — see Brian's earlier pushback. Moving sema to 5434 lets a native
Homebrew Postgres (5432), gw-data-pg (5433), and sema-pg (5434) all
coexist on one dev box. While in there, swept the stale 5432 defaults
that the original f34a4e4 script-add missed.

## 2026-05-22 — add a script for starting postgres in docker

**What:** New top-level `start-db.sh` (+69 lines, no other files touched).
Idempotent orchestration of a local `sema-pg` container (`postgres:16`)
mapped to host port **5433** → container 5432, with `POSTGRES_DB=sema` and
`POSTGRES_HOST_AUTH_METHOD=trust`. Waits on `pg_isready`, then dispatches
to `postgres/init-db.sh` based on flag (default: init if schema absent;
`--no-init` skips; `--reinit` rebuilds). Fails fast if Docker isn't running.

**Why:** Local dev needed a one-command DB bring-up that plays nicely with a
native Homebrew Postgres on 5432 (hence 5433) and is safe to re-run — the
prior workflow was hand-rolled `docker run` invocations, which drifted
between developers and silently re-created containers under varying flags.
Centralising the container shape here also gives the ej-dev/dev
harmonization a single chokepoint to edit when the port or image moves.

## 2026-05-26 — Wrap-up: highlight bijective MD↔ERB thesis (sema-specific) + queue ERB practice finding

**What:** Two wiki/sema/research/ doc updates closing this investigation
as work-in-progress.

`erb-md-mirror.md` — new §"Core thesis (sema-specific)" lifted to the
top of the doc. Makes three properties of the proposed refactor
explicit and load-bearing: *bijective* (round-trip exact, CI-gated),
*code-gen only* (mechanical, no curated translation), and
*sema-specific* (a general ERB-refactor pipeline would be infeasible;
sema's per-word + axioms + upgrades shape admits a clean hub-and-spoke
decomposition that a generic rulebook does not). Adds the motivation:
the load-bearing requirement is **unbounded ability to add new
axioms** (and probably upgrades) over sema's lifetime — axioms-as-
prose-in-28K-JSON does not scale, and a bijective MD mirror keeps
axiom authoring inside the git-native hub-and-spoke workflow without
giving up ERB's queryable DAG. Bumped Updated stamp to 2026-05-26.

`findings.md` — new dated entry: "Practice ERB pair-programming with
Claude before resuming the audit." Action: load full effortless
toolchain (CLI + MCP + Postgres mirror + Postgres GUI) and pair on
small rulebook touches so jess internalizes the ej + Claude rapid-
rulebook loop firsthand before continuing the audit threads (F5, F6,
p, r). Rationale: jess doesn't yet have a firsthand feel for the
workflow that produced ej's 28K-line rulebook so quickly; until she
does, she can't properly calibrate the strong CMCC thesis or judge
whether to drive vs consume ej's pipeline. Entry references the
queued-next-session-effortless-setup memory.

**Why:** The investigation hit a natural pause point with the
`active` → `published` rename landed and the audit's first-pass
findings recorded. Jess's stated next move is to set up tooling and
practice the workflow before pushing further on synergy analysis; the
remaining open audit threads (F5 TypeHelpers alignment, F6 Templates
table, p axiom-DSL feasibility, r round-trip empirical run) are best
re-engaged after that calibration. These two doc updates capture the
sharpest distillation of the thesis we have today (bijective refactor
+ unbounded axioms) and the explicit next-step action (practice
before more theory), so the work picks up cleanly in the next
session.

---

## 2026-05-26 — sema lifecycle: rename `active` → `published` (`fa42333`)

**What:** Replace the lifecycle status word `"active"` with `"published"`
across `spec/` and the Python tooling that reads/writes the `status:`
field. Touches:

- `spec/primary.md` glossary entry (draft vs published, with cleaner
  "mutable vs immutable" framing).
- `spec/registry/structure.md` §Status Field — full section rewritten:
  allowed values, defaults, lifecycle prose, `created`-after-promotion
  rule. Drops "under active development" phrasing (mutability is the
  property that matters, not "active development").
- `spec/registry/types.md` — status field schema and 5 references.
- `src/sema/tools/build_public_registry.py` — `is_active()` →
  `is_published()` (renamed; all 5 call sites updated), `active_versions`
  variable → `published_versions`, docstring updates.
- `src/sema/interfaces/cli/snapshot.py` — comment update.
- `tests/registry/test_registry_status_consistency.py` — `ALLOWED` set,
  `DEFAULT_STATUS` constant, `_schema_status()` default, docstrings.
- `tests/registry/test_registry_schema_file_layout.py` — `_registry_*_status()`
  defaults, `expected_*_id_line()` default-arg values.
- `tests/registry/test_registry_yaml_correctness.py` — literal `"active"`
  occurrences, variable names (`active_version_keys` →
  `published_version_keys`, `active_versions` → `published_versions`,
  `latest_active` → `latest_published`), test function name
  (`..._matches_latest_active_schema` → `..._matches_latest_published_schema`),
  error message strings.
- `tests/registry/test_public_registry_consistency.py` — literals + 2
  comments.
- `tests/registry/test_structural_dependency_consistency.py` — 2 literals.
- `tests/registry/test_identity_consistency.py` — 1 default value.
- `tests/registry/conftest.py` — 2 docstring lines.

`definitions/registry.yaml` and `definitions/*` schema files needed no
edits: pre-rename, no entry carried the literal word `"active"` —
status was always default-via-absence. Post-rename, the default value
is now `"published"` but the registry data is unchanged.

Three sema source files contain `active` in **non-lifecycle**
contexts and are deliberately left alone: `spec/primary.md:11`
("in active context" = LLM working context), `spec/authoring/types.md:384`
("under active schema evolution" = ongoing), and the runtime axiom
templates for `layout.lite/*` and `fis.authority.manifest/000`
("active ActorClass", "active count" = SCADA runtime semantics).

Full `pytest` run: 159 passed, 1 xpassed (pre-existing, unrelated).

**Why:** "Published" is unambiguous (committed to
`https://schemas.electricity.works/...` and immutable). "Active" was
overloaded — read as "currently used," "not deprecated," or "latest"
depending on context, and the spec text already said "active is
published and immutable," which itself signals the better word. The
rename aligns sema's vocabulary with ej's ERB out of the box (his
`TypeVersions.Status` already uses `'published' | 'draft'`), with
industry norms (npm, crates, PyPI, semver tooling), and with the
mutable-vs-immutable dichotomy that is what the lifecycle is actually
*about*. Migration cost was zero in registry data because the old
`"active"` value was default-via-absence — no entry needed touching.
The reason for the full clean (renaming the internal `is_active()`
function, the test variable names, etc.) rather than a literal-only
replacement: leaving `is_active()` as a function name when the value
it tests is `"published"` would be a permanent semantic landmine.

This commit lands per the queued
`queued-sema-active-to-published-rename` memory from the prior
(tame-raven) session.

---

## 2026-05-25 — `new.command.tree/000`: allow union over multiple `spaceheat.node.gt` versions (`3286294`)

**What:** `definitions/types/new.command.tree/000.yaml` —
`ShNodes.items` changed from a single
`$ref → spaceheat.node.gt/200` to a `oneOf` over `/200`, `/300`, and
`/301`. `registry.yaml` structural deps for `new.command.tree:000`
extended to include `spaceheat.node.gt:300` and `:301`. Indexes regen
(`dependency_closure`, `public_registry`, `reverse_dependencies` —
also picks up `gw1.actor.class:009` and `:011` as transitive enum deps
via the new node-gt versions). Runtime regen
(`src/sema/runtime/types/new_command_tree.py`, `reverse_query.py`,
`type_helpers/__init__.py`).

**Why:** `new.command.tree:000` was pinned to a single
`spaceheat.node.gt` version (`/200`) but real-world command-tree
payloads now need to carry nodes spanning multiple node-gt versions
during the SCADA rolling-version window. Widening via `oneOf` rather
than version-bumping `new.command.tree` itself is the right move
because the envelope semantics are unchanged — only the per-item union
shape needs to admit the additional versions. Pre-publication
in-place edit (no version bump) per `feedback_schema_fix_protocol`.

---

## 2026-05-25 — Add weather type v000 (`656c3c0`)

**What:** New `definitions/types/weather/000.yaml` (literal versioning).
`registry.yaml` entry added with `latest_version: 000`, deps closure
(`spaceheat.name`, `utc.seconds`, `non.empty.string`, `unitless.float`,
etc.). Indexes regenerated (`dependency_closure`, `lookup`,
`public_registry`, `reverse_dependencies`, `versions`). Runtime
generated (`src/sema/runtime/types/weather.py`) and an empty axiom
template stub created (`templates/axioms/weather_000.py.jinja2`).
`registry.yaml.metadata.last_updated` bumped to `2026-05-24T17:00:00Z`.

**Why:** Registers the legacy weather observation type (single-instant
outside-air-temperature + wind-speed from a third-party source,
identified by a weather channel name like `weather.gov.kmlt`) so that
journalkeeper can persist messages emitted by the new
gridworks-weather-forecast service. Closes the `queued-sema-add-weather-v000`
memory item. Stub axiom template lands ahead of axiom logic; the type
ships usable without it (the axiom slot is reserved for a future
"WeatherChannelNameInRegistry" or similar constraint, currently empty).

---

## 2026-05-26 — Three new research docs: MD↔ERB mirror + no-degradation audit + findings log

**What:** Three new docs under `wiki/sema/research/`, all Pass 0 Draft.

`erb-md-mirror.md` — proposes a small bidirectional tool that emits the
rulebook schema as a wiki-style hub-and-spoke MD tree under
`wiki/sema/erb-mirror/` and accepts schema-level edits back as JSON
patches against the rulebook. Data rows stay in JSON; only the schema
round-trips. Two-emitter design + CI gate + day-one pilot scope + open
questions. Names the downstream extension: same tooling enables
Karan-style ERB-as-functional-spec convergence on production repos like
gridworks-scada (with the structural-~50% / behavioral-~50% fit caveat).

`erb-no-degradation-audit.md` — catalogs every operation sema supports
today (authoring, indexes, runtime gen, tests, publishing) and
classifies each under the working thesis (ii): YAML-leading, granular
bidirectional, no degradation. Surfaces 6 specific findings for ej
(granular emit not yet implemented; upgrades are a second source-of-truth
in Python modules not in YAML; coverage gap from unfinished migration;
TypeHelpers rule alignment to verify; Templates table empty;
axioms/combinators round-trip as opaque blobs). F3 (lifecycle/publication
Status) was initially scoped as a degradation risk; corrected during
review (jess caught the error — sema does carry explicit `status:`) and
dissolved. Closes with a 9-item acceptance checklist plus 5 open
questions for ej.

`findings.md` — new running log of actions WE (jess + Claude) will take
on sema or sema-adjacent tooling. First entry: drop ERB's `PromotedAt`
column (redundant with sema's `created` per
`spec/registry/structure.md:100-103`). Distinct from the audit, which
lists items for ej to satisfy.

**Why:** The trio forms the load-bearing artifact set for evaluating
ej's ERB integration. The mirror tool addresses how the team and Claude
reason about the rulebook itself (the meta-work case ej's
LLM-friendliness story does not optimize for, per the working
`erb-is-an-llm-interpretation` C-reading: rulebook-as-generative-prior).
The audit converts the abstract "no degradation" goal into a concrete
checklist for ej. The findings log separates *our* action items from
ej-facing recommendations so the audit stays scoped to its actual
audience. Together they surface that several pieces ej presents as
working — notably granular bidirectional emit — are aspirational
rather than current code. Output of `/grill-me` thread item q (audit)
and the MD-mirror brainstorm; sets up p (axiom DSL feasibility) and r
(round-trip empirical run) as smaller follow-on investigations.

---

## 2026-05-24 — Typed Maps construct & applications (`f2472ba`)

**What:** Add `spec/authoring/types.md` §Open Containers and §Typed
Maps; add Composition Rule paragraph permitting multi-version `oneOf`;
add Referencing Other Vocabulary header requiring canonical
`https://schemas.electricity.works/...` URLs for every `$ref`. New
format word `positive.int.as.str` (int-keyed-map blessed key format)
+ registry entry. `gw1.tank.temp.calibration.map/000` Tank restored
to typed-map shape using the new construct; the redundant
`ContiguousTankIndexConstraint` axiom is dropped (subsumed by
structural enforcement; orphan runtime axiom template removed).
`gw.nolan.layout/000` GNodes refactored from
typed-dict-without-propertyNames to a typed array; axiom 1 restated
for arrays. New `test_typed_maps_have_blessed_propertynames` enforces
the binary key-format rule.

This commit also carries the cross-cutting state that earlier commits
in the series deferred: `registry.yaml` reconciliation (adds
`non.empty.string` and `positive.int.as.str` format entries, deletes
the `analytics.channel.gt` type entry, adds typed-map structural deps
for calibration.map), all `indexes/*` regen, runtime regen for
`property_format.py`, `relay_actor_config.py`,
`old_versions/relay_actor_config_002.py`, and
`gw1_tank_temp_calibration_map.py`, plus the new
`positive.int.as.str` runtime template.

**Why:** "Keyed dicts of typed values" is a standard pattern (per
user) and the orig spec was silent on it. Formalizing as the Typed
Map construct gives the pattern a single, mechanically-checkable
shape with a tight binary key-format choice (string XOR int) — wider
than "forbid all typed dicts" but narrower than "any propertyNames
goes." GNodes was the smell case (keys redundant with `GNodeClass`
field on the value); Tank was the legitimate case (keys are tank
indices, genuine semantic content). The new test mechanically
distinguishes them via the propertyNames signal. Open Containers
section codifies the "no unconditional axioms on `type: object`
contents" rule — the conditional-discriminator pattern in
`derived.channel.gt`'s `Parameters` axioms 3+4 remains permitted as
the spec-can't-express exception. Cross-cutting state lands here
because earlier commits intentionally deferred registry/indexes/regen
to keep their own diffs minimal and reviewable; the cost is that the
suite was partially red between commits 3 and 7 inclusive, fully
green again at this commit.

---

## 2026-05-24 — Identity-field consistency tests and title typo fix (`150b01a`)

**What:** New `tests/registry/test_identity_consistency.py` with three
functions: `title` matches the name segment of `$id`; `TypeName.const`
matches the same; Version field shape matches the current
`versioning_strategy` (`const` for the latest of a literal-strategy
type; `type: string` for all versions of a string-strategy type).
`gw1.telemetry.name.quantity.projection/000`: title was
`telemetry.name.quantity.projection` (missing the `gw1.` prefix);
fixed.

**Why:** The existing `test_registry_schema_file_layout.py` checked
the `$id` line against the canonical URL but never compared it to the
schema's inner `title` field. Drift between them was silently OK. The
title typo on `gw1.telemetry.name.quantity.projection` had been
shipped that way; pure metadata typo (runtime gen derives the class
name from `$id`, so zero runtime impact). The strategy-aware Version
check matters because a type whose `versioning_strategy` evolved from
`string` to `literal` keeps the original `type: string` shape on
older versions — a naive "Version must always be const" test would
false-positive on legitimate legacy versions.

---

## 2026-05-24 — Type-schema examples MUST be JSON document strings (and valid JSON) (`ab218db`)

**What:** New `tests/registry/test_example_format.py` with two
functions: entries under `examples:` MUST be strings (not YAML maps),
and if strings MUST parse as valid JSON. Four example blocks fixed:
`channel.readings/002` and `channel.readings.list.item/000` (YAML
maps rewritten as JSON strings); `relay.actor.config/002` example
(missing comma after `WiringConfig`, trailing comma after `Version`);
`derived.channel.gt/002` (missing comma after `OutputUnit`). This
commit also folds in the `relay.actor.config/002` minLength → `$ref →
non.empty.string` swap (parallel to commit 4091454's swap on `/003`),
since the file was already being touched here for the example fix.

**Why:** `sema/spec/authoring/types.md` §Examples already says
"Examples SHALL be serialized JSON documents, not YAML object
representations," but no test enforced it. YAML-map examples
masquerade as valid (they're parseable YAML) while telling consumers
the wrong format. Examples don't affect runtime validation, but they
ARE used by integrators to seed code and as IDE/CI fixtures — wrong
or malformed examples mislead. Folding the `/002` minLength swap into
the same commit avoided touching `relay.actor.config/002` twice.

---

## 2026-05-24 — Extend Primitive Constraint Rule to all string-constraint keywords; add non.empty.string (`4091454`)

**What:** New format schema `non.empty.string` (type: string,
minLength: 1). `tests/registry/test_primitive_constraints.py`
extended to cover all forbidden constraint keywords (`pattern`,
`minLength`, `maxLength`, `multipleOf`), not just numeric ones.
Recursion stops at `propertyNames:` (blessed by Typed Maps). Six
fields swapped from `type: string + minLength: 1` to `$ref →
non.empty.string`: four on `relay.actor.config/003` (event / state
names), two on `fis.instance.authorization.event/000` (peer address,
connection handle). The parallel four-field swap on
`relay.actor.config/002` is folded into commit `ab218db` (the example
fix touched the same file). Runtime tightens `str` → `NonEmptyString`
once commit `f2472ba` regenerates.

This commit ships the format schema YAML only; the corresponding
`registry.yaml` entry (and runtime regen + indexes) land in commit
`f2472ba`.

**Why:** The Primitive Constraint Rule already said primitive
constraints must be wrapped in named formats; the test only enforced
the numeric subset. The minLength fields had been shipped with
inline `minLength: 1` — a workaround for not having a "non-empty
string" format word. Adding the format and enforcing the rule for
ALL constraint keywords closes the gap. Runtime tightening means
empty strings, which the old `str` type accepted, now hard-fail at
deserialization. `non.empty.string`'s `created` is back-dated to
2024-12-31 so dep timestamps order correctly against the older
consumer types it now serves (see
`wiki/sema/research/format-created-must-be-real.md` for the follow-up
rule-tightening proposal).

---

## 2026-05-24 — $ref values must be canonical Sema URLs (`372f73f`)

(Commit subject as recorded by git is ` values must be canonical Sema URLs` —
leading space, missing `$ref` prefix — because the shell ate the `$ref`
substring at commit time. Intended subject was "$ref values must be canonical
Sema URLs"; flagged here for accuracy.)

**What:** New `tests/registry/test_ref_values.py`: every `$ref` value
in a type or enum schema SHALL be a canonical Sema schema URL
(`https://schemas.electricity.works/{formats,enums,types}/...`).
`definitions/types/analytics.channel.gt/000.yaml` deleted (had
`$ref: string` — not a valid URL); references to it removed from
`synced.readings.bundle/{001,002}` prose. `src/sema/tools/build_seed_dag.py`
tightened: `normalize_ref` no longer silently passes through non-canonical
refs (`/types/...`, `types/...`, `enums/...` shorthand branches deleted —
no schema used them); the main DAG loop's `if dep is None: continue`
defensive skip replaced with `raise`.

This commit ships the schema file deletion + prose updates + the
tightening + the new test. The matching `registry.yaml` deletion of
`analytics.channel.gt`'s entry, and the indexes regen that follows,
land in commit `f2472ba`.

**Why:** `analytics.channel.gt` was a draft Joe didn't end up using
(user direction: delete rather than fix). The two defensive
fallbacks in `build_seed_dag.py` existed only to tolerate exactly the
kind of malformed `$ref` that analytics.channel.gt had — with the
test now catching them and analytics.channel.gt gone, both
workarounds are dead code. Hard-raise replaces silent-skip so future
schema authors can't reintroduce the pattern by accident.

---

## 2026-05-24 — Fixture broadens coverage (`0802853`)

**What:** `tests/registry/conftest.py` `all_schemas` fixture now
walks `definitions/{formats,enums,types}/` on disk and loads every
schema file directly. Previously loaded only via
`indexes/lookup.yaml`, which filters drafts and keeps only
`latest_version` per type. Fixture keys switched from `title` to
short canonical id derived from `$id` (`bid:000`, `uuid4.str`);
duplicate keys hard-error.

**Why:** Older immutable versions and draft schemas were silently
out of scope under the lookup-based fixture — a regression edit on
either was invisible to the suite. Walking the filesystem brings
every schema file in scope. The keying change ensures failure
messages include the version (e.g., `relay.actor.config:002`
rather than just `relay.actor.config`) so it's obvious which file
broke. This commit lands ahead of the rule-enforcement commits
below it in the changelog because those rules need the broadened
fixture to see all the schemas they're meant to catch.

---

## 2026-05-24 — Retire orig-spec.md (`6decb38`)

**What:** Delete `spec/orig-spec.md` (the pre-hub-and-spoke
monolithic spec, 2006 lines).

**Why:** Bakeoff complete; the hub-and-spoke spec
(`spec/primary.md` + `spec/registry/` + `spec/authoring/`) is the
canonical source. The orig was preserved per `sema/CLAUDE.md` for
transitional reference; that transition is now done. The orig
content lives forever in git history if needed for archaeology;
keeping it in-tree creates dual-source-of-truth drift risk and
~2000 lines of read-burden for anyone scanning `spec/`.


## 2026-05-23 — Dissolve sema/docs: relocate GridWorks context to wiki, merge motivation into README (`f377e76`)

**Why:** With the spec promoted to `sema/spec/`, `sema/docs/` had no
load-bearing job left — orig-spec.md moved to `sema/spec/`, and the
remaining files were either GridWorks-flavored context (wrong repo) or
overlapped with the README. A single-file `docs/` folder is overhead;
the README is THE standalone landing page per wiki convention and the
right home for motivation.

GridWorks-flavored context moved out (wrong repo):

- `scada-layout-concerns.md` (SCADA-side critique of the
  `gw.nolan.layout` word framed in LLM-comprehension terms — concerns
  *about* a Sema word, not the spec) → moved to
  `wiki/gridworks-scada/research/concerns/layout-axiom-complexity.md`
  with light rephrasing (header, attribution, typo fixes).
- `sema-and-domain-protocols.md` (framing on how Sema relates to OpenADR
  and similar) → moved to `wiki/sema/research/sema-and-domain-protocols.md`
  with a status stamp and a one-line "what this is" opener.
- `where-meaning-lives-in-gridworks.md` (GridWorks-architecture position
  paper naming Sema as the semantic authority, written in the first
  person) → moved to `wiki/sema/research/where-meaning-lives-in-gridworks.md`
  with a status stamp; cross-refs in `wiki/gridworks-scada/research/`
  updated to the new path.

Repo-level reshuffles:

- `motivation.md` merged into `README.md` as a new "Why this matters"
  section (the README already covered most of the framing; the unique
  bits — the four-point benefits list and the vision line — fit cleanly
  there). Also fixed a misplaced-bold typo from the original
  (`i**ndependent teams and organizations**` →
  `**independent teams and organizations**`) en route.
- `index.md` deleted: with everything either in `README.md` or in
  `spec/`, the navigation file was pure overhead.
- `docs/` folder deleted entirely.
- `README.md` also fixed a pre-existing broken link to
  `docs/rules_and_guidelines.md#vocabulary-registration-process` →
  `spec/governance.md#vocabulary-registration-process`.
- `sema/CLAUDE.md`: `docs/orig-spec.md` → `spec/orig-spec.md` (you
  moved orig-spec to spec/ between turns).

## 2026-05-23 — Promote sema/spec/ to the top level alongside definitions/ and indexes/ (`bfc7c21`)

**Why:** Primary motivation is to make the spec **digestible for LLMs** —
a 2006-line monolith forces every AI session to skim or partial-load,
making "Read the spec" a wishful directive rather than a real verification
step. Bundles two moves: (1) split `docs/sema-specification.md` into a
hub-and-spoke layout (`spec/primary.md` + `spec/registry/` +
`spec/authoring/` + `spec/governance.md`) so an agent under
`/make-sema-word` can pull the ~200-line spoke for the kind it's touching
and actually load it in full; (2) elevate `spec/` out of `docs/` to sit
beside `definitions/` and `indexes/` because the spec is the canonical
rebuild artifact, not background reading. The split also let us fold
language-neutral runtime upgrade discipline into the spec
(`authoring/type-semantics.md#upgrade-discipline`, replacing lore that had
been hiding in `sema/CLAUDE.md`) and fix two latent issues in the source:
a duplicated Change Process section and the `report v002`
`Version: const "003"` mismatch with its `$id`/title.

## 2026-05-23 — Update regular sema CLAUDE.md (`87cae7c`)

**Why:** Slimmed `sema/CLAUDE.md` to invariants only — dropped stale
`Coding/...` paths, dropped pydantic-emitter lore that doesn't belong on
every sema session, added the regen commands by path
(`scripts/build_indexes.sh`, `scripts/regenerate_runtime.py`), pointed at
`/make-sema-word` for the per-word ritual. Loaded on every sema work session,
so keeping it dense saves tokens and concentrates attention on the MUSTs
that actually bind.

## 2026-05-21 — Add gw / gridworks.header envelope Sema types; fix Dst; regenerate

**Why:** Register the GridWorks application-layer **envelope** as Sema
vocabulary. `gridworks.header/001` (literal) captures the delivery metadata
(`Src`, `Dst`, `MessageType`, `MessageId`, `AckRequired`) exactly as emitted by
the field-deployed gwproto Header wire format; `gw` (versionless) is the
envelope = header + an opaque `Payload` (any registered Sema type, matched by
`TypeName`). These are the types the gridworks-base **codec layer** wraps for
multi-hop traversal (see
`wiki/gridworks-base/executor/codec.md`). Fixed a schema bug — `gridworks.header/001`'s
`Dst` had no `type` (added `type: string`). Also removed an orphaned
`heartbeat_a_000_to_001` upgrade template left behind by the heartbeat change
below (it referenced the deleted v001 and failed two tests). Full suite green.
The header doc records a deliberate v002 evolution path (drop empty-string
sentinels, drop redundant `MessageType`, constrain `Dst`, add instance
provenance / signing).

## 2026-05-21 — heartbeat.a: delete unpublished v001, revert latest_version to 000, document supervisor use (`359f5b5`)

**Why:** An unpublished `heartbeat.a/001` had *deleted* the `MyHex`/`YourLastHex`
pair. That pair is the supervisor-tier liveness/continuity primitive — the names
are **sender-relative** (`MyHex` = sender's fresh token, `YourLastHex` echoes the
peer's last), so one type serves both the supervisor and the supervised actor;
it must not be dropped, and must not be renamed to a role-specific "SuHex."
Pre-publication revise-in-place is sema-legal, so v001 was deleted,
`latest_version` reverted to `000`, and v000's docs improved to state the
supervisor health-monitoring purpose. This is supervisor liveness, distinct from
the cross-party SCADA↔LTN contract heartbeat — see
`wiki/gridworks-scada/research/concerns/liveness-and-sla.md`.
