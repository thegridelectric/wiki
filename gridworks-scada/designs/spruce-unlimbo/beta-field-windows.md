# Beta field windows

Status: Draft · Pass 0 · Updated 2026-09-21 · Linear: OPS-392

> What this is: the recurring field test of the `jm/spruce-unlimbo` code.
> After roughly each spoke the branch runs in a bounded window on one house
> of each layout family. This spoke says how a round runs, how its record
> is kept, and what the rounds have taught about running them. It is not a
> workstream in the hub's ordered list; it runs between them.

## Why rounds, and why now

The suite, the sim driver and the tlayouts twins agree with a layout by
construction. None of them says a real house boots on the generated pair,
that the actors needing hardware start, or that the relays end up where
the log says they did. A window on the box does. Running one after each
spoke keeps the distance between a change and its first contact with a
house to one spoke, so a field failure points at a small diff.

## Houses

One house per layout family per round:

- **spruce** for `gw.nolan.layout`, `ActuationAuthority` Active. In the
  heating season the winter hack is the plant controller and
  `NolanLocalControl` holds zones off and turns the heat pump off, so a
  spruce *test* window is short and always bounded. Field support is the
  exception: there the window scada is what lets heat calls reach the heat
  pump while someone works on it, so the window is deliberately long
  (hours) — still bounded, so the winter hack auto-restores if the session
  ends.
- **beech** for `gw.house0.layout`, `ActuationAuthority` Standby. Beech
  carries the siegenthaler loop; a loop left fully closed while the heat
  pump runs trips the heat pump, so relay positions are checked against
  the bus, not only against the log.
- **one of fir / oak** for `gw.house0.no.sieg`, from the round after
  `house0-no-sieg-layout.md` ships its word and gens.

A round MAY skip a family the spoke could not have touched; the round's
logbook line says which families ran.

## A round

1. **Read the folder README's "Process" section** and the mysteries it
   lists. Pick the ones this round can shed light on and decide what
   evidence would do it, before anything is switched on.
2. **Pre-flight.** `./<house>_window.sh status` on each house. Push the
   scada head and pull it on the box; regenerate the window pair if the
   spoke changed a gen and place it with `put_layout.sh <house> <change>`.
   `on` refuses when the box checkout or the window pair is behind, so a
   refusal is the pre-flight doing its job.
3. **Start the captures first**, then `./<house>_window.sh on <minutes>`.
   Watch with `gwa watch <house>`.
4. **Close** with `off` if the bound has not already closed it, and check
   `status` shows the recorded plant services running again.
5. **Record in the same sitting**, per the `experiments/README.md`
   conventions: evidence with provenance headers, a `gw.experiment.run`
   instance per house, a logbook line, and the README brought current.
6. **Route what the round found.** A defect goes to the spoke that owns the
   code, or to `odds-and-ends.md` when none does. An executor claim the
   round verifies gets its `Reviewed` pointer at the folder.

## The record

Every round adds to one folder,
`experiments/2026-09-18-beta-field-windows/`. Evidence files and instances
accumulate, named by house and window stamp. The README does not
accumulate: it states what is known now and what is still a mystery, and
each round rewrites it. A mystery a round resolves leaves the list and
its answer joins what is known; how the understanding got there is in git
history and the logbook.

While the branch is off `main` the README carries a temporary **Process**
section: the round steps above in runnable form, the distillation rule,
and the current mystery list. A PreToolUse hook on Bash commands matching
`_window.sh on` prints that section into the session before the window
opens, so a round cannot start without it. The section and the hook are
removed when `deployment.md` completes.

## What the rounds have taught

- **Bracket the actuation with the bus capture.** In round one the beech
  port samples started after the sieg move and nothing sampled spruce's
  gw108 register, so neither relay transition was witnessed on the bus.
  The capture starts before `on` and runs past the last expected
  actuation.
- **Prove the broker-side subscriber connects before `on`.** Round one's
  `mosquitto_sub` on `localhost:1885` was refused for a bad user, and the
  upstream link never found a peer, so the window's events exist only on
  the boxes and in the folder.
- **Two clocks.** The box clocks run about 70 s behind the laptop. Event
  filenames are UTC, log lines are box-local ET, and a timeline written on
  the laptop is laptop time. State which clock every stamp is on.
- **Relay state is not a reading.** Relay-state channels are absent from
  `ChannelReadingList` because a report carries them in `StateList`; the
  absence is not missing data.
- **Count channels against both lists.** A layout's `DataChannels` and
  `DerivedChannels` together are the names a report can carry.

## Do this next

Round three (2026-09-19) found five scada defects and one layout change;
the fixes are written and tested and have not run on a house.

1. **Put the spruce layout on the box.** Once the scada and tlayouts
   changes are pushed and the box has pulled the scada head:
   `experiments/put_layout.sh spruce floor1-out-of-service`. The only
   change in the window pair is floor1's component `Enabled: false`.
2. **Run round four: a window of five minutes or more on each house,
   `--debug`.** Spruce stays bounded at five minutes, since the winter
   hack is what heats the house. What each window should show:
   - spruce: zones 1 and 2 publish `-opto-input` and `-heat-call` at boot,
     not at the 300 s capture boundary;
   - spruce: the pico bank is no longer power-cycled every ~65 s on
     floor1's account, and floor1 has no `single.pico.state` row;
   - spruce: `fancoil-depth3` and `pipes1-depth3` give one
     `open-thermistor` Warning glitch each and no `gridworks.event.problem`;
   - beech: `zone1-down-heat-call` and `zone2-up-heat-call` get values
     from whitewire power through the power meter;
   - beech: the `no-ta-deed` warning appears in the box log as
     `Warning Glitch: no-ta-deed`;
   - beech: a pico-cycler reboot inside the window, to see whether beech's
     picos post params at all and whether the older-firmware
     `TankModuleParams` is refused;
   - both: the capture's provenance sidecar carries its `Probe:` line and
     an `Opened:` line per window with the scada SHA.
3. **Channel integrity is in.** The four channel axioms
   (`DerivedChannelCreatorResolution`, `DataChannelNodeResolution`,
   `DerivedChannelInputsAcyclic`, `ChannelNameUniqueness`) are in both
   words with sema runtime tests, the tlayouts snapshot and the gwsproto
   mirrors, and the three loader checks they replace are out of
   `hydronic_layout.py`, each behind a load-path test
   (`tests/test_misc/test_layout_word_guards_the_loader.py`).
4. **Port the older layout axioms to sema-side tests**, on sema
   `jm/layout-axiom-tests`: Nolan 1-15 and House0 1-19 have scada tests
   only, and the generated runtime is the authority. Same shape as the
   tests there now: copy the vanilla layout, break one thing, match
   anchored on `axiom N \(` plus the clause label. Fill what has no
   rejecting test anywhere: House0 1 (`GlobalIdUniqueness`) and 5
   (`PrimaryFlowSourceChannelAgreement`); `TransactivePowerChannel`'s
   not-PowerW input; `SystemModelEnergyChannels`' creator, Strategy and
   EnergyModel conjuncts; `BoardResolution`'s DeviceType mismatch; Nolan
   `RequiredActuators` clause b beyond the empty list; House0 core-nodes
   duplicate name and handles.
5. **Anchor the existing scada axiom matches.** `match="Axiom 2"` is an
   unanchored regex and is satisfied by Axiom 20-23; move the older tests
   in both layout test files to the anchored form.
6. **Axiom candidates to put to the human:** a Nolan `GlobalIdUniqueness`
   (the loader's duplicate-Id checks have no Nolan axiom behind them);
   the strategy-specific checks still in `validate_derived_channels`
   (identity takes one input and OnTrigger, affine needs a Calibration);
   the renumbering in `layout-word-axioms.md` "Axiom order". *What may
   take a disabled pico's channel as input* stays deferred, below.
7. **Then refactor this file.** "Do this next" has grown into a build
   log. Move what rounds one to three taught into "What the rounds have
   taught", cut this section back to the next move, and put back the
   three moves an earlier rewrite dropped: the experiment folder cleanup
   (README onto `experiment-README-template.md`, scripts speaking sema
   through the `gwexp` snapshot, the Process section, round one distilled
   into known and mystery), the window-open hook, and running the round
   that follows `cold-house-derived-setpoint.md`.

## Open

- How rounds are told apart in instance filenames. The window stamp as the
  condition field (`spruce-20260918.192107-gw.experiment.run-000.json`) is
  the candidate; round one's two files carry no condition.
- Whether a round that finds nothing still rewrites the README or leaves
  only a logbook line.
- **Disabled-component channels as control input.** A disabled pico's
  channels stay in the layout with no data; identity deriveds (spruce's
  floor temps) want that. Whether a control-relevant strategy (buffer
  depth, store layer, heat-call source) may sit behind a disabled
  component is undecided — deferred 2026-09-20 until a house0-no-sieg or
  slab layout exists, since those installs drop whole sensor groups by
  design and may clarify the real shape needed.
