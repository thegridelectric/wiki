# terminalasset PR 6 — A simulated plant for House0 and Katahdin houses

Status: Draft · Pass 0 · Updated 2026-11-25 · OPS-721

What this is: the tracking page for the review of
thegridelectric/gridworks-terminalasset#6 (Olly, from fork `ollyw:ow/beech-plant`,
head 685d1a5 on 2026-11-23): what we have looked at, what was asked, and what
is settled. Delete when the PR merges and the settled points have moved to the
executor; the issue keeps the hours and the outcome.

## Hand-off (2026-11-25, session eager-cinder)

**State.** Commit `8dc2f5d` on `jm/intercept-relay`, pushed, PR #7 into
`beech-plant` (a copy of the PR 6 head 685d1a5 in thegridelectric's repo).
PR #7's CI is green (two runs of `ci / 3.12`); the title typo is fixed. The
PR 6 head is still 685d1a5, so every round 2a anchor below is current.
The issue is OPS-721; OPS-711 owns the sema and tlayouts changes and the
fixture commit. Commit `fc0f85e`, pushed, CI green: the opto pin reads
the model's digital call. Commits `1258637` and `0abd0a7`, every ci.sh
step green on the laptop (host 61 passed with live, container 38 fmu
passed, staging check OK): the Beech fixture is tlayouts 5313ab2 `output/beech1-sim` (the registry's
d1 identities, alias `beech1`); and three of the four round 1 asks still
open are done here for Olly to evaluate: the skew log (`SKEW_WARN_MS`),
`actuate(actuation, now_ms)` capped at the plant's clock on the ABC, the
drift model and the FMU model, and ci.sh running the fmu tests in a Linux
container through `scripts/test_fmu.sh`. Round 1's Room plus Circuits
split stays Olly's. The
three models gain a `zoneCall[nZones]` output (unit `1`, the zone valve's
0/1 position); both adapters map a zone's wire channel to `zoneCall` when
its telemetry is `BinaryState` and to `zoneCallPower` when it is a power
reading; `pin_level` takes the call, and `LIVE_WIRE_WATTS` is gone. FMUs
rebuilt.

**Checks.** The FMU binaries are for Linux, so `./ci.sh` cannot pass on an
Apple silicon laptop. Its steps run in a container:

    docker run --rm --network container:gw-dev-rabbit -v "$PWD":/w:ro \
      ghcr.io/astral-sh/uv:python3.12-bookworm sh -c "cp -r /w /tmp/w && \
      cd /tmp/w && rm -rf .venv && uv sync --all-groups --locked -q && \
      uv run ruff check --no-fix --no-cache . && \
      uv run ruff format --check --no-cache . && uv run pyright && \
      uv run pytest -q -p no:cacheprovider -o addopts=''"

Last run: 97 passed, 1 skipped. Run `scripts/build_fmu.sh` first when a
`.mo` file changed.

**Do this next.** Jessica posts every GitHub comment herself; the session
hands her the text. Up: the nine PR #7 comments below (six on the first
two commits, three on the round 1 commit), then the PR 6 comments in round
2a from `src/gwta/outdoor.py:210` down, and replies on the round 1 threads
PR #7 answers (README, pyproject, katahdin_layout, test_katahdin, Beech
fixture, plant.py:168, fmu_model.py:194, ci.sh:30) pointing at it. Still a request to Olly: the `chargeDischarge` rename at
`house0.py:120` (line 112 on the branch). Round 2b stays held.

**Open with Jessica.** None. The 0.5 W threshold question is settled
(below): an opto heat call is digital, so the plant reads the model's
call and no threshold exists.

Reviewed 2026-11-23. Python, tests, packaging and README read closely; the
Modelica physics only for shape (zones, circuits, outdoor air).

## PR #7 comments for Olly (drafted 2026-11-25, not posted)

Anchors are lines PR #7 adds, on head `fc0f85e`. The purpose is a guided
read of our branch: what each piece is and why, so his review of it is
quick and the two PR 6 threads it closes can point here.

**Review body**

Every comment in this review explains a change I made, so you can read
the branch quickly. None asks you for a code change. One thing is for
you: run `scripts/build_fmu.sh` before the fmu tests, because three `.mo`
files changed. Suggested reading order: the fixtures in `tests/config`,
then `relay_effects`, `state_effects`, `plant_layout.py`, `sensing.py`,
and the tests.

When it is merged into `beech-plant`, please bring `beech-plant` into
`ow/beech-plant` so PR 6 has it. The remaining PR 6 comments are for you,
on top of this.

**`src/gwta/fmu_model.py:79`** (`def relay_effects`)

One table form for both families. A `StateEffect` names the FMU input a
relay drives and the value in each of its two states, by the state's name.
Which state is energized is read here from the layout's
`relay.control.config`, so the table never says it. A layout with no config
for a relay the model needs, or whose two states are not the ones the table
names, is refused by name. This is what the `katahdin.py:83` and
`katahdin.py:136` comments on PR 6 asked for; those threads now point here.

**`src/gwta/katahdin.py:90`** (`def state_effects`)

The Katahdin table in the House0 form. Every valve relay takes `VALVE`
(`ValveOpen` 1, `ValveClosed` 0) because larch gives each one a
`valve.open.or.closed` config, and `gw.katahdin.layout` axiom 34 ties V4
and V5 to the backup kind, so the `has_boiler` branch, `OPEN_WHEN_POWERED`
and `CLOSED_WHEN_POWERED` are gone. Two absences are deliberate: the
boiler's intercept relay switches nothing the model has (the model's boiler
fires on its own aquastat), and there is no `hp-failsafe-relay`, since a
Katahdin has none.

**`src/gwta/plant_layout.py:70`** (`HEAT_CALL_STRATEGY`)

A Katahdin's zones are read by the board itself: temperatures on the
Gw108's thermistor ADC, heat calls on its opto pins. So a channel is the
plant's to show when its sensor is a simulated device, or an input of a
board of a simulated type (`BOARD_INPUTS`), and the plant also reads the
ADC behind each thermistor channel and the heat call's `Interpretation`
behind each pin. These two constants are hand-kept: `derived.channel.gt`
has `Strategy` and `Parameters` as free text, and a word for a heat call's
derivation retires them. If the scada reads these channels some other way
than I have assumed, this is the place to say.

**`src/gwta/sensing.py:70`** (`def pin_level`)

A zone's opto channel is digital: the Gw108 reads whether the thermostat
circuit is closed, and the scada's derivation is `DigitalZeroIsActive` on
larch. So the pin follows the model's own call, the new `zoneCall[nZones]`
output (the zone valve's 0/1 position) in all three models, and no
threshold exists on this path. The adapters pick the variable by the wire
channel's telemetry: `zoneCall` for a `BinaryState` pin, `zoneCallPower`
for a `PowerW` reading, where the scada's `GreaterThanThreshold` and its
`Threshold` are in the layout as before. Run `scripts/build_fmu.sh`: all
three `.mo` files changed.

**`src/gwta/plant.py:70`** (`SKEW_WARN_MS`)

The skew log from the PR 6 comment at `plant.py:168`, as asked: every
actuation is logged with its stamp's offset from the plant's clock, and an
offset over 2 s is a warning. Under the flux period the physics cannot
show it, so the threshold sits there. `test_plant.py` has the two cases.

**`src/gwta/fmu_model.py:231`** (`def actuate`)

The PR 6 comment at `fmu_model.py:194`: the model runs to the actuation's
instant or to the plant's clock, whichever is earlier, so a scada whose
clock is ahead cannot run the plant into the future. `now_ms` is on the
`PlantModel` ABC and on `DriftModel`, which has nothing to run forward and
ignores it, and the plant passes the clock it already read for the skew
log. The new fmu test stamps an actuation an hour ahead and checks the
model's time stays put while the relay's input is set.

**`ci.sh:34`** (the fmu step)

The PR 6 comment at `ci.sh:30`: the host run takes `-m "not fmu"` and the
fmu tests run in a Linux container through `scripts/test_fmu.sh`, since an
FMU's binary loads on Linux only. The script joins the dev broker's
container network when `gw-dev-rabbit` is running and the host's network
otherwise, so the one test marked both fmu and live reaches the broker on
a laptop and in CI alike. The README's ci paragraph says the same.

**`tests/test_katahdin.py:79`** (`def adjusted`)

Replaces `larch()` and the generator. A test house that differs from larch
(no boiler, two circuits) is larch's JSON adjusted and decoded again
through `gw.katahdin.layout`, the way the scada's layout tests vary a
house, and the word refuses an adjustment that leaves a node, channel or
component behind. What changes for a reader of these tests:
`hp-scada-ops-relay` rests open on larch, so with every relay at rest the
heat pump is not called and the bench has no `scada_in_charge` switch; the
bench speaks of valves as open or shut; larch has BTU meters and no
pulse-rate channels, so the pulse assertions are gone and
`pulse_microhertz` keeps its own test.

**`modelica/KatahdinComponents.mo:339`** (`heatPump.scadaControl = 1`)

`hpScadaControl` is gone from `Katahdin.mo` and `KatahdinComponents.mo`.
The only line that drove it was derived from the boiler's failsafe relay,
which a Katahdin does not have, so the heat pump's call is `hpEnable`
alone. The `HeatPump` block in `Hydronic.mo` keeps its `scadaControl`
input because Beech wires it (the failsafe relay hands the call to the
buffer aquastat there); here it is pinned to 1 with the reason in the
string. `scripts/build_fmu.sh` before the fmu tests, since both `.mo`
files changed.

## Settled between us (not yet in any spec)

- **Structure from the layout, quantities two owners.** The plant reads the
  shape of a house from the layout words it decodes: zones, circuits and
  `ServesZone`, circulator roles with their channel names, tank counts, relay
  control configs. Its physics coefficients (`CAir`, `CFabric`, conductances,
  pump curves, heat-pump tables) are its own. It does not read a quantity the
  scada estimates or controls with (`KwhPerDegF`, the FLO house parameters, a
  learned setpoint), so a wrong scada belief stays testable. For comparison:
  `CAir` is J/K (Beech 3 MJ/K down, 0.9 MJ/K up); `KwhPerDegF` converts at
  1 kWh/°F = 6.48 MJ/K (Beech down: 1.0, so about 6.5 MJ/K, one lump where the
  plant has two).
- **A Zone is a Room plus Circuits.** Room: air, fabric, heat loss to other
  spaces including the outdoors. Circuit: stat, valve, emitter. A room takes
  any number of circuits. The spruce living room (slab plus fan coil) is the
  worked example.
- **Every sim layout is a tlayouts gen.** No layout generator outside tlayouts.
  The Beech twin wants `beech_sim_gen.py`; Katahdin wants a
  `katahdin_sema_gen.py` family gen with `larch_sim_gen.py` (and cedar) as
  drivers. Fixtures in terminalasset are byte copies of committed tlayouts
  output, with stable ids through the id map. A test variant (no boiler,
  another zone list) is a small delta on a committed fixture, round-tripped
  through the layout word so it validates, as the scada's tests do; never a
  second generator.
- **The sim twins stay `d1`.** A `d` universe is all-simulated and keeps
  no data, on a laptop or on a shared box, and `hw2` is not a universe
  (decided 2026-11-25). The Beech twin is
  `d1.isone.me.versant.keene.beech`, `.ta`, `.scada`.
- **No time coordinator this round.** Track skew instead: the plant compares
  each actuation's `ActuationTimeUnixMs` to its own clock, advances the model
  only to its own clock, keeps last/min/max/count, logs over a threshold and
  at each flux. The scada's journal (`timestamp` vs `persisted_at`) gives the
  other side after the run.
- **An opto heat call is digital.** A Gw108 opto input reads whether the
  thermostat circuit is closed; there is no trip level to state anywhere.
  The plant feeds the pin from the model's 0/1 call (`zoneCall`), never
  from the wire's power through a threshold. The wire's power stays for
  the House0 "power" source, where the scada's own `GreaterThanThreshold`
  derivation and its `Threshold` are in the layout (settled 2026-11-25).
- **Plant parameters as a sema word: later.** A typed record for the overrides
  now, with a note naming the missing word; a `sim.plant.params`-shaped word
  when a second consumer appears. It never `$ref`s a scada belief.

## Review round 1 (submitted 2026-11-25 14:50Z as "Comment")

Nine comments, written by hand, on head 685d1a5. The Beech fixture comment
says "Aliases stay d1", so nothing posted needs withdrawing.

| Anchor | Ask |
|---|---|
| `README.md:166` | layouts from tlayouts only; `katahdin_sema_gen.py` + `larch_sim_gen.py`; fixture a byte copy; cedar waits on the same gen |
| `pyproject.toml:16` | `ta-katahdin-layout` goes with `katahdin_layout.py` |
| `src/gwta/katahdin_layout.py:1` | drop with the port to tlayouts |
| `tests/test_katahdin.py:58` | `larch()` goes; variants as deltas on the committed fixture |
| `tests/config/gw.house0.beech.layout.json:1` | `beech_sim_gen.py` in tlayouts derived from `BEECH`; aliases stay d1 |
| `modelica/Hydronic.mo:488` | Room + Circuits split; layout states the shape |
| `src/gwta/plant.py:168` | log the skew; `SKEW_WARN_MS = 2_000` |
| `src/gwta/fmu_model.py:194` | never advance past the plant's clock: `actuate(actuation, now_ms)` |
| `ci.sh:30` | `-m "not fmu"` on the host run; `pytest -m fmu` inside the container |

Both tlayouts halves of the layout ask now exist. `katahdin_sema_gen.py`
and `larch_sim_gen.py` are on tlayouts main with `output/larch-sim/`
committed. `beech_sim_gen.py` and `output/beech-sim/` are on tlayouts
main too (c23bb77). PR #7 does eight of the nine: all but
`modelica/Hydronic.mo:488`, the Room plus Circuits split, which is the
model's own structure and stays with its author.

## Round 2a: ready to post (independent of round 1)

Every item was read against the source at 685d1a5 on 2026-11-25; line
numbers are on that head and each anchor is a line the PR adds. Each
entry is the comment text, ready to paste. Ranked.

**Review body**

Smaller findings, none of them tied to the layout or zone work. The sema
boundaries here are a pleasure to read: the actuation decode is narrowed
with `expect=`, the layout dispatch is by `isinstance`, and every
`sensing.py` constant names the word that retires it.

**`README.md:166`** (reply on the round 1 thread)

The tlayouts half of this now exists, so no generator is needed from you.
`katahdin_sema_gen.py` and `larch_sim_gen.py` are on tlayouts main, with
the output committed at `output/larch-sim/gw.katahdin.layout.json`. Please
make the fixture here a byte copy of that file. It differs from the one in
this PR in ways the adapter and tests will see: the board is a sim Gw108
in place of the Krida panel; flow comes from `dist-btu`, `primary-btu` and
`store-btu` BTU meter nodes and there are no `-flow-hz` channels; the
zones are `zone1-living-rm`, `zone2-kitchen`, `zone3-bedrooms` and
`zone4-upstairs`, each with `-gw-temp`, `-gw-microvolts` and `-opto-input`
where this file has `-temp` and `-whitewire-pwr`; there is no
`hp-failsafe-relay`; and the backup is `gw.boiler.backup` 001, so the
snapshot here wants a regen before the copy decodes.

**`tests/config/gw.house0.beech.layout.json:1`** (reply on the round 1 thread)

tlayouts now has `beech_sim_gen.py` on main, with its output
committed at `output/beech-sim/`. It is `dataclasses.replace(BEECH, ...)`
and keeps this fixture's three GNodeIds and d1 aliases for now. The
registry's dev seed gives the same three aliases other ids, and we are
settling on that seed as the one source of d1 GNodeIds, so expect the ids
in the copy to change once. The layout has the
same nodes and channels as this file plus Beech's `oil-boiler-pwr`, and
its ops are Beech's own (HoldFullSend, KeepBufferFull, Beech's curves)
where this sim had orange's. One thing is needed on this side before the
copy decodes: tlayouts emits `gw.boiler.backup` 001 and the snapshot here
is on 000, so the snapshot wants a regen. With only that version set back,
`load_plant_layout` reads the new file and the six non-fmu tests in
`test_house0.py` pass against it.

**`README.md:166`** (second reply, once tlayouts main has the rename)

One more change to that file before you copy it: the backup's
`AquastatCtrlRelayName` is now `InterceptRelayName` (`gw.boiler.backup`
001, renamed in place while it is staging), and at a Katahdin the node it
names is `boiler-intercept-relay`. "Aquastat control" described the
House0 buffer-tank aquastat, which a Katahdin does not have. The House0
node keeps the name `aquastat-ctrl-relay`, so the Beech fixture changes
only in the field name. Both are on tlayouts main now, and the snapshot
regen here picks up the field.

**`src/gwta/katahdin.py:136`**

This is the one relay in the function whose meaning comes from a constant
where the others come from the layout's `relay.control.config`. It was a
symptom of the House0 derivation: a Katahdin has no heat pump failsafe
relay. The boiler fires on its own aquastat, the scada's intercept relay
(`boiler-intercept-relay`) can hold it off, and with the scada dead the
heat pump is off. tlayouts now says so: `gw.boiler.backup` 001 makes
`FailsafeRelayName` optional, and `output/larch-sim/gw.katahdin.layout.json`
has a backup with only `InterceptRelayName`, so on that fixture
`backup.failsafe_relay_name` is None here. Please drop this line with the
move to the tlayouts fixture and take the intercept relay's meaning from
its control config like the rest. `gw.katahdin.layout` axiom 35 now
requires that config's de-energized state to be `Boiler`.

**Branch `jm/intercept-relay` on top of the PR head (2026-11-25, uncommitted
at this writing).** It does what comment 3 (`katahdin.py:136`) and the
`katahdin.py:83` comment below ask, plus the snapshot regen, the four
tlayouts fixtures and the removal of `katahdin_layout.py`. If the branch
goes to Olly, those two comments become a pointer to it. Still a request
to Olly: the `house0.py:120` rename. The branch also removes the undriven
`hpScadaControl` input from both Katahdin models and shows the zone
channels a simulated Gw108 reads itself (thermistor ADC and opto pins).

**`src/gwta/house0.py:120`**

`chargeDischarge` is the one input in this table whose name does not say
what 1 means. `hpEnable`, `storePumpOn` and `siegTowardKeep` each name
the state that is 1; this one names both, so the reader needs
`STORE_FLOW` or the description at `Beech.mo:27` to learn that 1 is
charging. Please rename the Modelica input to say it, `storeCharging`
for example. The table's form is fine as it is: the state names are the
layout's own and the layout says which one is energized.

**`src/gwta/katahdin.py:83`**

The tlayouts Katahdin layout gives each valve relay a
`relay.control.config` with StateType `valve.open.or.closed`, so the
layout now says what a fed valve does, and `gw.katahdin.layout` axiom 34
ties V4 and V5 to the backup kind. That retires what this table keeps by
hand: the `has_boiler` branch, `OPEN_WHEN_POWERED` and
`CLOSED_WHEN_POWERED`, and the "Hand-kept" note. On that fixture the
check at line 122 refuses every valve relay, since their states are
`ValveOpen` and `ValveClosed`. Please move this table to the `house0.py`
form: `StateEffect("v1Position", VALVE)` with
`VALVE = {"ValveOpen": 1.0, "ValveClosed": 0.0}`, and one
`effect_by_relay` for both families.

**`src/gwta/outdoor.py:210`**

Two failures escape this tuple and end the polling thread: an
`AttributeError` from `item.get("Name")` at line 164 when a list item is
not a dict, and `http.client.IncompleteRead` from `response.read()`,
which is not an `OSError`. The only trace is a traceback on stderr; there
is no log line and no retry, and the plant keeps the last points. Could
`_run` catch broadly, log and retry on `RETRY_S`?

**`src/gwta/outdoor.py:35`**

These three and the weather flags at `plant.py:256-264` are service
configuration and belong in `GwtaSettings`. The retiring note at lines
8-9 says the module goes; only the hand-read fields go when the word
exists, so the note could say that.

**`src/gwta/plant.py:90`**

The snapshot has this: `UtcIso8601MillisFormat.from_datetime`
(`gwta/sema/property_format.py:231`), and the function can then return
`UtcIso8601Millis` in place of `str`.

**`src/gwta/plant.py:320`**

`parser.error` exits before the `try` at 325, after `fmu_model(...)` at
301 has unzipped the FMU and instantiated it, so `model.close()` never
runs and the unzipped temp dir stays behind. Checking the arguments
before building the model fixes it; the alias check at 116 and
`plant.start()` at 324 have the same path.

**`src/gwta/plant.py:46`**

The plant imports its broker setup from the hello demo, and
`wait_for_consuming` there reads gwbase's private `_consuming`
(`hello.py:127`). A small module both use would let the demo go without
taking the plant with it. Also the import order here and at
`katahdin.py:15-17`.

**`src/gwta/plant.py:124`**

`super_alias` and `time_coordinator_alias` fall back to the `d1.super1`
and `d1.time` defaults in `config.py`, which predate this PR. Now that a
real service depends on them, could they be required? `service_alias` is
already checked against the layout at 116.

**`src/gwta/plant.py:69`**

`FLUX_TYPE_NAME` is unused; `emit_flux` uses `flux.type_name`.

**`src/gwta/outdoor.py:146`**

`_Body` declares `close`, so this can be `response.close()`. Also the
leading-underscore names in this module (`_Body`, `_pull`, `_run`,
`_lock` and the rest): we use plain names.

**`src/gwta/katahdin.py:71`**

The depth suffixes are also `DEPTH_SUFFIXES` at `house0.py:49`, and
`KELVIN_AT_0_C` is defined in both `fmu_model.py:29` and `outdoor.py:26`.

**`tests/test_outdoor.py:82`**

The three tests cover interpolation, hold and the happy pull. Missing:
the poller's failure and retry path, the refusal of a non-Fahrenheit
unit, and `next_flux` setting `TOutdoor`.

**`README.md:161`**

"the four the FMU is generated with" repeats `nZones = 4` from
`modelica/Katahdin.mo:51` and will go stale with it.

Dropped after the check: "how-to-test paragraph deleted" (it was
rewritten at `README.md:302-307`), `TOutdoor` set at interval end (a few
hundredths of a kelvin at this cadence), unbounded `DriftModel.actuations`
(a test probe that grows by one per actuation), and "ruff `I` rule off"
(the repo has no ruff config at all, before and after this PR).

## Round 2b: wait until round 1 is addressed

These change shape with the Room + Circuits work and the fixture move; a
comment now would have him fix code that is about to change.

- **Channel mapping by name pattern.** `house0.py:23-49, 84-97`,
  `katahdin.py:22-42, 64-74`: hardcoded channel names, built strings,
  private `BUFFER_DEPTHS = 3`. `Hydronic.Circulators` and the sensing
  components state most of it. Hand table only for facts no word states,
  each with a note. The zone path already follows the layout's
  `ZoneCallCircuits` in both adapters, and `plant_layout.py` picks board
  inputs by board. Channel names are the layout generator's, so a board
  change alone (Beech is expected to be refitted with a Gw108 Rev C and
  stay a House0) renames nothing; the tables matter when a gen names a
  channel differently or a house senses something another way. Post when
  the Room + Circuits split is settled. Comment text, anchored on
  `house0.py` `variable_by_channel`:

  The depth and flow channels here are matched by name (`buffer-depth1`,
  `-hz`, `-device`, `-micro-v`), so the plant refuses a layout whose
  generator names one of them differently. Please take them from the
  layout the way the zone channels already come from `ZoneCallCircuits`:
  `Hydronic.Circulators` and the sensing components state most of it. A
  hand table is for a fact no word states, with a note naming the missing
  word. The same applies to `katahdin.py`.
- **Circuit index as zone index.** `house0.py:98-102, 132-136, 177`,
  `katahdin.py:75-79, 149`. Python half of the Room/Circuits comment;
  resolved by it or not.
- **`variable_by_channel` duplicated** across `house0.py:77-103` and
  `katahdin.py:58-80`. Both adapters change with the shape work; ask for
  one shared core after.
- **Katahdin test coupling.** `test_katahdin.py` imports `Listener` from
  `test_plant`; move to a conftest when the fixture tests are reworked.

## Open

- The PR body cites `experiments/2026-11-11-beech-sim-compose/` for the
  13.5 h run. Not in the PR, the experiments repo, or any checkout here. Ask
  where it lives and what broker, vhost and aliases the run used.
- How the sim scada's `ta-deed.json` was handled in that run.
- (Settled 2026-11-23) The scada stamps `ActuationTimeUnixMs` at send time from its
  `Clock` (`gw_spaceheat/plant_link.py:365` on scada main, PR 630), not at the
  relay actor's confirm. Scada PR 618 was Olly's version, closed in favour of
  630. The scada's `Clock` can name the time coordinator, but the migration is
  partial: other scada paths still call `time.time()`, so a coordinated run is
  not possible yet. Today both halves of the seam are on wall time, in both
  directions (the scada takes the plant's `ScadaReadTimeUnixMs` as its
  readings' read time, `plant_link.py:354`). One clock for the pair is a later
  design, after the scada finishes its own move.
- The design slug for the layout/plant contract, if these points outlive the PR.

## What is good (lead with it)

Sema at the boundaries: narrowed actuation decode (`expect=`), layout
dispatch by `isinstance`, flux through `to_dict()` in a `gw` wrap, no staging
word on the wire. Interior records are typed NamedTuples with docstrings. The
plant takes aliases, disabled channels, simulated device types (via
`gw1.sim.device.type`) and relay semantics from the layout and refuses by
name a relay whose states it does not state. Physics behind a transport-free
seam with a step cap. `sensing.py` constants each name the word that retires
them. Wrong-shape refusals are tested; energy balance is tested in every mode.
