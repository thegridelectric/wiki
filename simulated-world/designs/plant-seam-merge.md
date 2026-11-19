# plant-seam-merge

Status: Draft · Pass 0 · Updated 2026-11-18 · Linear: OPS-692

**EDD: yes** Verified when a real house has run the merged branch for a
bounded window with its devices behaving as before, and a simulated
Beech started from the merged code runs a day with its scada reading
every channel from the plant and actuating its relays.

> What this is: the steps that take gridworks-scada PR 618 (device
> actors reach their hardware through a plant) from an open draft to
> code that has run in a real house, and the terminal asset PRs that
> follow it. The decisions it works under are in
> [`../primary.md`](../primary.md).

## Do this next

PR 630 (`jm/plant-seam`) supersedes 618: main merged in twice, the sema
snapshot regenerated from sema `dev` cfa2b66 with axiom 6 of
`gw1.scada.device.type.gt` as BusUniqueness, and all five differences
under "Before it merges to main" fixed or kept with a test; `ci.sh`
green (2069 passed, 18 skipped, 2026-11-18). The branch boots locally
against spruce's committed pair and routes its 28 real devices, and
`roll.sh spruce check` shows spruce and its LTN on main 7e8e52f4 with
the pair matching tlayouts main, which the branch also pairs with.
Next: `scripts/roll.sh spruce to jm/plant-seam` for a bounded window,
watching the glitch stream for `relay-actuation-failed`,
`relay-report-failed`, `i2c-bus-init-failed`, `gpio-read-failed` and
`actor-raised`, then record the outcome here. Honeysuckle is not a bench
yet: its gen is commented out (axiom 8 lacks eight sensing channels),
its output is at an old data-channel version; the pi itself works.

## The branches

| Repo | Branch | PR | Note |
| --- | --- | --- | --- |
| gridworks-scada | `ow/plant-seam` | 618 | 14 commits, forked from main 2026-11-09 |
| gridworks-scada | `jm/plant-seam` | 630 | cut from its tip; main merged in twice; the five differences fixed or pinned; supersedes 618 |
| gridworks-scada | `jm/price-stages` | 627 | waits until this merge is done |
| gridworks-terminalasset | `katahdin-layout` | 2 | base of the four below; merges to `dev` first |
| gridworks-terminalasset | `ow/plant-seam`, `ow/katahdin-fmu`, `ow/beech-components`, `ow/beech-plant` | 3 to 6 | a stack, each containing the one before |
| experiments | `ow/plant-seam` | 1 | the plant experiments and the compose reproducer |
| wiki | `ow/katahdin-fmu` | 2 | changelog entries; merges when the code does |

## The merge

Main has nine commits since the fork. A comparison of both sides found
no code on main that uses anything PR 618 moved or renamed. Two
resolutions are needed:

1. **`actors/sieg_loop/strat_protect.py`: take main's.** PR 618 adds a
   log line that reads `hp_turned_off_time`, which the homing change on
   main removed; merged as text it raises `AttributeError` the first time
   the loop goes blind. Main already logs the blind reason at the same
   place. The PR's test `test_strat_protect_logs_why_it_goes_blind`
   asserts the removed behaviour and goes with the line.
2. **The sema snapshot: regenerate.** Both sides changed
   `sema_seed_request.yaml` and no word was changed by both. The seed
   requests merge as text; the snapshot tree is then rebuilt with
   `scripts/regen_sema_snapshot.sh`.

After the merge: all of `tests/actors/test_sieg_loop.py` (the homing
tests on a `ScadaApp` that builds a plant),
`test_dist_energy_from_scada2.py`, `tests/named_types`, then `ci.sh`.

## Before it merges to main

PR 618 reshapes the device path, so the scada protocol's rule for a
sculpt applies: every behaviour difference is listed, the list is
checked by a reader who did not write the change, each difference gets a
test, and the change runs on a bench Pi.

An independent comparison found the I2C sequences unchanged, real houses
routed to real drives, and five differences the PR does not list:

| Where | Difference | Disposition |
| --- | --- | --- |
| `relay.py:329` | GPIO actuation runs as an added task. The drive's own write error becomes a Critical glitch, which is better than main's `actor-raised`; an exception raised after the write died in the task unseen. Spruce has the one GPIO relay. (Each command also adds a task object the proactor never removes; main's I2C relays do the same, so that is OPS-694, not this merge) | fixed on `jm/plant-seam`: the reporting after the write runs under one catch that sends a Critical `relay-report-failed` glitch; two tests in `tests/actors/test_relay_gpio_actuation.py` |
| `relay.py:363`, `gpio_sensor.py:73` | log lines no longer name the pin | fixed on `jm/plant-seam`: a device prints where it is (`GPIO 22`, `plant relay vdc-relay`) and the log lines use it; test in `tests/test_plant.py` |
| `gpio_sensor.py:91` | after a failed read, the next good read is published as a first reading whatever `AsyncCapture` says | kept: main had no failed read (a raising read ended the sensor's task); already asserted in `tests/actors/test_gpio_sensor.py` |
| `relay_drives.py:170` | a bus result of success with no value counts as a failed read. On main it raised a `TypeError` on an active-low board | kept: the branch is right; pinned with the refused op and the timeout in `tests/test_plant.py` |
| `scada_app.py:74` | routing resolves every node in the layout, including nodes this process does not run, so bad board data on such a node fails the boot | fixed on `jm/plant-seam`: `route_devices` takes the scada node it routes for and routes only the nodes under it; the primary passes `s`, the secondary `s2`; three tests in `tests/test_plant.py` |

Two paths have no test: `GpioRelayDrive` and the real eGauge path. Not
checked: Katahdin (no layout exists in the scada or tlayouts),
honeysuckle and house0-sim (their tlayouts outputs are stale and fail to
load), and whether the layouts on the boxes match the tlayouts outputs.

What the comparison confirmed (code read on 2026-11-12, suite not run,
nothing on a Pi):

- The I2C sequences are unchanged: the relay expander's
  read-modify-write, timeouts and retry backoff; DAC writes, EEPROM
  verify and reprogram; ADS1115 config readback and conversion; the
  eGauge driver file.
- Real and simulated are chosen per node from the layout. A plant link
  and its MQTT client are built only when the layout has a simulated
  component, so the `plant_link` default does nothing on a real house.
- The tlayouts outputs for beech, fir, maple, oak, elm and spruce all
  route to real drives.
- The tests were ported with their assertions kept, several tightened.

## What the PR is

- It rewrites the real device actors (`Relay`, `ZeroTenOutputer`,
  `I2cThermistorReader`, `GpioSensor`, `PowerMeter`). Chip code moves
  out of the actors into `relay_drives.py`, `dac_drives.py`,
  `thermistor_inputs.py` and `pin_inputs.py`, and each actor asks a
  router, `Plant`, for its device.
- Its description lists eight deliberate behaviour changes on real
  hardware and says "This is speculative work for review, not for merge
  as it stands: nothing here has run on a Pi."
- For simulated layouts it deletes the self-faking values, so a
  simulated scada needs a plant on the broker. With default settings a
  dev run gets no sensor values unless a plant is running or
  `plant_link=Standing` is set; a `StandingPlant` covers the suite.
- **The seam is one level lower than the one OPS-40 decided.** That
  design has a `Sim*` device type with its own flat actor branch and
  leaves the real actors alone. Here the real actor runs in simulation
  too and only the device under it is swapped. More real code is tested
  in simulation, and every production device actor is touched.

## As built, against the simulated-world decisions

- **Broker (decision 5).** The plant sends flux on its own GNode
  connection (`GWTA_RABBIT__URL`). The scada's plant link is a second
  MQTT client built from `settings.gridworks_mqtt` (`scada_app.py`), the
  broker settings of its link to the LTN; it ignores TLS settings and
  logs "dev-broker-only". The decision needs a setting of its own for
  the plant link's broker on the scada, the plant's URL naming that
  broker, and a second rabbit on `hw2-1`.
- **Models (decision 6).** The Python is per layout family: `house0.py`
  serves any House0 layout with a Siegenthaler loop, `katahdin.py` any
  Katahdin layout, and tank and zone channels are built by looping over
  the layout. The model is per house: `Beech.mo` has
  `constant Integer nZones = 2`, three store tanks and Beech's pipe and
  tank parameters, array sizes are fixed when the FMU is compiled, and
  `house0.py` refuses a layout whose zone or tank count differs.
  `Hydronic.mo` is the shared parts library.
- **Flux cadence.** Every channel every 5 seconds, with the model
  advancing only when the flux timer fires. OPS-672 changes this.
  Unchecked: whether the simulated tank module and BTU meter path, which
  takes each flux as a pico post, depends on the steady rate.

## Sema

- The PRs add no sema words. `sim.plant.flux` and `sim.plant.actuation`
  were already staging words; each repo takes them through its seed
  request and `regen_sema_snapshot.sh`, and the scada has hand-written
  twins for the two (`gwsproto/named_types/sim_plant_flux.py`,
  `sim_plant_actuation.py`).
- The two words are still unsigned in the sim vocabulary tracker
  (`simulated-test-environment/new-sema-words-to-review.md`).
- Words the plant's code notes as missing: six relay-state enums absent
  from the terminalasset snapshot (`store.flow.relay`,
  `heat.pump.control`, `aquastat.control.state`, `primary.pump.control`,
  `hp.loop.keep.send`, `heatcall.source`); thermistor divider constants
  and gallons per pulse (`sensing.py`); a way for `sim.plant.actuation`
  to say a 0-10 V level; the spaceheat channel names (OPS-444).

## The wiki record to correct

- The OPS-40 hub still tells sessions to keep the plant as simple as
  possible (constant COP, 160 °F), and nothing in it mentions Modelica
  or an FMU. A session reading it is told the opposite of what the
  terminal asset PRs contain.
- `build-plant.md` and `simulated-actors.md` disagree on which actor
  sends actuation.
- `three-family-plants.md` says one plant body with rosters read off the
  layout; as built it is one Python body per family and one compiled
  model per house.

## The bench and the field

1. A bench Pi with a gw108 board runs `jm/plant-seam`: relays actuate,
   thermistors and GPIO sensors read, the power meter reports.
2. One house rolls to the branch with `scripts/roll.sh` for a bounded
   window and rolls back. Which house is open; spruce has the one GPIO
   relay in the fleet.
3. PR 618 merges to main.

## After the scada

The terminal asset PRs merge in stack order onto `dev` once
`katahdin-layout` is in, then the experiments PR and the wiki changelog
PR. `ta-katahdin-layout`, which builds a Katahdin layout from a House0
one, does not go in (simulated-world decision 7).

## Open

- **Devices under `s2`.** Each scada routes devices for the nodes under
  its own node, so the secondary can own devices. Three things stop a
  relay or gw108 reader under `s2` today: every I2C device talks to the
  one `I2cBus` node, which sits under `s`, and a device in the secondary
  process would send to an actor it does not run; a relay's bosses all
  run in the primary, so a relay under `s2` has nothing to command it or
  take its reports; and the secondary has no plant link, so a simulated
  device under `s2` fails its boot. A GPIO sensor under `s2` works. The
  multi-bus design (OPS-532 spruce-settled, `multi-bus-layouts.md`)
  binds each bus node to its bus and resolves devices by bus name; the
  command path across processes has no design yet.
- Which house takes the field window, and who runs the bench Pi.
- Whether the plant link's broker becomes its own setting before PR 618
  merges or directly after (simulated-world decision 5).
- Whether the five differences are fixed on `jm/plant-seam` or returned
  to the PR's author as review comments.
