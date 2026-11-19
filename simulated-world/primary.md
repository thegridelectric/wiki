# simulated-world

Status: Draft · Pass 0 · Updated 2026-11-18

> What this is: the home for the work that runs GridWorks as a simulated
> world on the simulation host. What a World is, and how laptop,
> simulated and hybrid Worlds relate, is in
> [`../world/primary.md`](../world/primary.md); this folder has the
> designs that build one.

## The layers

A simulated world has three layers, and each design here belongs to one.

| Layer | What it is | Designs |
| --- | --- | --- |
| The house | A real scada reaching its devices through a plant seam, with a simulated terminal asset running a Modelica model behind it; the scada's side of the contract is the scada executor's [`plant.md`](../gridworks-scada/executor/plant.md) | `beech-sim-day`, `simulated-test-environment` (OPS-40); flux on change is OPS-672, in the gridworks-terminalasset designs |
| The services | Every cloud service (registry, market maker, price, weather, ear, journalkeeper) started from its repo by one contract, then as a container | `dev-stack-contract` (OPS-614), `prepare-for-kubernetes` (OPS-676) |
| The host | `hw2-1`, the first box built to run GridWorks from compose | none yet; the box's facts are in `gridworks-infra/hw2-1/` |

The designs are in [`designs/`](designs/), and
[`../DESIGN_INDEX.md`](../DESIGN_INDEX.md) lists them with their state.

## Decisions

1. **The first simulated worlds are thrown away.** A full stack comes up
   on `hw2-1`, the ear stores files on the box, and a new experiment
   starts from an empty stack. Nothing is kept for later.
2. **A box's compose file is in `gridworks-infra`**, beside the box's
   instance-README. No service repo has one for a box.
3. **A simulated house looks like production.** The services run the
   record sets and settings production runs, so what is learned on
   `hw2-1` transfers.
4. **The plant runs on wall time first.** Coordinator timesteps follow
   under OPS-40.
5. **Flux and actuation are `gw` messages on `amq.topic`.** They stand
   in for the wires between a scada and its devices, so the broker they
   use is a setting of its own on the scada, and is a different broker
   from the universe's wherever simulated and real houses share a
   universe.
6. **A plant is one compiled model per layout word**, run from the
   house's layout and operational params. The models in hand are one per
   house and are the starting point.
7. **Layouts come from tlayouts.** A plant does not build one layout
   word from another.

## Open

- **Brokers.** Decision 5 gives the plant a broker of its own.
  `../world/primary.md` invariant 1 says a World has one broker. One of
  the two changes.
- **Timesteps.** Whether simulated timesteps stay on the universe
  broker, where the time coordinator has routing edges today
  (`gridworks-base/src/gwbase/topology.py`), or move to the plant's
  broker.
- **As built against decisions 5 and 6.** The plant sends flux on its
  own GNode connection; the scada's plant link is a second MQTT client
  on the scada's upstream broker settings, TLS ignored, so decision 5
  still needs a setting of its own on the scada, the plant's URL naming
  that broker, and a second rabbit on `hw2-1`. The plant's Python is per
  layout family (`house0.py`, `katahdin.py`) and the compiled model per
  house (`Beech.mo` fixes two zones and three tanks, and `house0.py`
  refuses a layout with another count), with `Hydronic.mo` the shared
  parts library. Flux is every channel every 5 s and the model advances
  on the flux timer; OPS-672 changes this.
- **Sema gaps the plant's code notes.** Six relay-state enums absent
  from the terminalasset snapshot (`store.flow.relay`,
  `heat.pump.control`, `aquastat.control.state`, `primary.pump.control`,
  `hp.loop.keep.send`, `heatcall.source`); thermistor divider constants
  and gallons per pulse (`sensing.py`); a way for `sim.plant.actuation`
  to say a 0-10 V level; the spaceheat channel names (OPS-444). The two
  plant words are unsigned in
  `designs/simulated-test-environment/new-sema-words-to-review.md`.
- **Work with no design yet:**
  - the simulated house past the plant seam (scada executor `plant.md`):
    the pico actors' HTTP half has no simulated form and a sim-word actor
    still registers its HTTP routes; `ApiFlowModule` has no simulated
    form; no plant plays pico outages, so pico-cycler recovery on a
    simulated house runs only when the plant stops showing a pico's
    channels; `sim.plant.flux` and `sim.plant.actuation` are staging words
    and the scada's snapshot is regenerated with staging allowed;
  - the `hw2-1` stack: the compose file, the plant broker, one simulated
    house end to end;
  - the plant link's broker as its own setting (decision 5);
  - one model per layout word (decision 6), with the zone structure the
    scada is about to gain under OPS-532;
  - the plant's models against recorded starts (the Siegenthaler valve's
    measured flow curve, the closed-loop rise), so control work can be
    built against them;
  - the model's outdoor temperature input, which nothing sets, so a
    simulated house runs at a constant 268.15 K.

## Loose ends

- **The Siegenthaler valve in the Beech model.** `Beech.mo`
  (gridworks-terminalasset PR 5) models the loop: a three-way valve
  after the primary flow meter, one leg sending to the hot header and
  the other keeping water through a sensed pipe and flow meter to a tee
  on the heat pump's return. A motor driven by the two real relays
  travels 94 s stop to stop, begins keeping at 26 s and keeps everything
  from 56 s, which are maple's positions measured 2026-09-28. Three
  things separate it from a bench for the scada's wait-to-open start:
  - the flow split is linear between 26 s and 56 s, where the real valve
    is steep and non-linear, so the measured curve
    (`experiments/future/sieg-keep-ratio-map/`) has to go in;
  - the pressure drops and thermal coefficients are placeholders, so the
    closed-loop rise is unchecked against the recorded starts (maple
    2026-09-28, beech spring 2025);
  - the heat pump model has not been read for a self-stop at its upper
    limit, which the start's fail-open layers need.

  The positions of `sieg-hot` and `sieg-cold` are a guess, since the
  schematic does not show them.
- **Two experiments commits not yet read** (experiments PR 1, both
  2026-11-16): `5aaed2d`, a plant-loop run on orange with its persisted
  events as evidence, and `f64dddd`, which gives beech-sim-compose a pod
  for kube play, a two-stage scada image and a web server change. The
  second bears on the scada's Dockerfile and on compose against an
  orchestrator for `hw2-1`, so it is read before the `hw2-1` stack is
  designed.
