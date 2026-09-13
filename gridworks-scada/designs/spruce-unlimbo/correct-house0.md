# Correct House0 (spoke)

Status: Draft · Pass 0 · Updated 2026-09-13 · Linear: OPS-392

> What this is: House0 made right, in three strands that only close
> together. **tlayouts:** the House0 fixture pair comes from the
> sema-native gen and passes `sema validate`, never kept by hand.
> **scada code:** the House0 references in the scada (the H0N/H0CN
> aliases, the direct name reads) are corrected and retired, carried
> through the two hydronic actor files the partition rope still owes a
> review, since every name decision changes the gen, the fixtures and
> the word at once. **sema:** the House0 layout word's requirements for
> nodes and channels are brought to the shape the Nolan word already
> has. Runs after `house0-zero-ten-outputs.md`, which gives the three
> `*-010v` nodes their per-output components; the gen, not the
> fixtures, is the thing to get right, because the pair regenerates
> again for the fall installs.

## Where it stands (2026-09-10)

The real fixture `tests/config/gw.house0.layout.json` was sema-invalid
before the relay decommission touched it: an old meter `Exponent`,
channels carrying `InPowerMetering`, and hubitat component shapes that
predate their words. The decommission's hand surgery (per-relay
components in, Krida component and `relay-multiplexer` out) left the
error count unchanged, so the new components added none. Krida rung 3
closes on its beech witness (`experiments/2026-09-10-beech-krida-witness/`,
dev rung PASS on all nine checks, the box run pending); the one clause
of its definition of done it hands here is "`sema validate` on the
real fixture", which only this regen can meet. The sim fixture
validates today.

`house0_sema_gen.py` in tlayouts is sema-native already (the
hardware-layout-pass-one port) but does not yet emit the beech-shaped
real fixture: the sieg surface, the LG nameplate parts and the
Honeywell-via-Hubitat zone circuit were hand-authored into the fixture
as a sanctioned interim while the gen was blocked
(`layout-word-axioms.md` "Fixture / generator moves").

The names retirement stands at 423 `H0N.` and 105 `H0CN.` references on
the branch. The principle is settled (partition primary "Names grilling
decisions"): a names class is vocabulary, requiredness lives in the
layout word's axioms; each settled name lands as one unit, constant in
its disjoint class, alias deleted, call sites repointed, fixture
renamed. `actors/hydronic/house0.py` (896 L) and `shared.py` (273 L)
hold the bulk of the House0 references and have never had a review or
a test.

The House0 word `gw.house0.layout/000` carries fourteen live axioms,
among them `CommandNodesExistenceAndActorClass`, `RequiredSensing`,
`RequiredActuators`, `RequiredHeatpumpEquipment`, `CommandableHeatPump`
and `ActuatorLeaves`. Known gaps against the Nolan shape:
`RequiredSensing` lacks `dist-flow` and `store-flow`;
`RequiredActuators` pins the three `*-010v` nodes by Name and
ActorClass only; there is no `ComponentBinding` (every Component
referenced by exactly one ShNode), and its test is skipped on the
House0 pair; and axiom statements still name pre-rename constants
wherever a retired alias was the name in the fixture.

## The three strands

**1. The gen emits the pair.** `house0_sema_gen.py` emits both
`gw.house0.layout.json` (beech: the sieg family, real shape, LG
nameplate, Honeywell zone circuit) and `gw.house0.sim.layout.json`,
and `sema validate` passes on both. The hand-edited pair the relay
decommission and the 0-10V shift leave behind is the contract the gen
reproduces byte-for-byte; after that the fixtures are never edited by
hand. On regen the vendored closure copy in gwsproto refreshes in the
same wave (the layout-closure mirror maxim).

**2. The scada code: names retired and references corrected, through the hydronic reviews.** The two
partition-rope chunks fold in here as the walk-through that carries
the House0 name decisions:

- `actors/hydronic/shared.py` (~250 L; estimate 2h): zone-circuit relay
  helpers, the vdc pair, onpeak/setpoint judgment, `latest_temps_f`.
  The shared bar is "every layout we can imagine has this"; a helper
  that assumes a buffer tank, an iso valve or store tanks is House0's,
  not shared.
- `actors/hydronic/house0.py` (~990 L; estimate 2h): choreography and
  judgment; the judgment methods (`is_buffer_*`, `is_storage_*`) are the
  thinnest coverage in the repo and each needs a functionality
  conversation, not just a test.

Each file review gives the H0N/H0CN references in that file their tier
decision and repoint, per the tandem rule, and the gen and fixture
carry the rename in the same commit. First-ever tests per file, per
the single scada focus. Names no reviewed file holds get one
end-of-review sweep.

**3. The sema requirements for nodes and channels.** The House0 word (staging, so edited in
place under the word-gate ritual: read `sema/spec/primary.md` and the
registry/authoring spokes, post the summary, wait) gets: the
`RequiredSensing` gaps closed; `RequiredActuators` carrying the
per-output ComponentIds the 0-10V shift created; `ComponentBinding`
added and its House0 test un-skipped; and every statement re-read
against the post-rename fixture so no axiom pins a retired name. The
mirror is `gwsproto`'s `check_axiom_<n>` validators, regenerated, and
the conformance test.

## Sequencing

1. `house0-zero-ten-outputs.md` lands (the per-output components exist).
   Its fixture surgery is hand-patched, as krida rung 3's was: the
   House0 gen's `emit_dfr` (still the legacy type-key, the DFR
   component, multiplexer node) is brought to the per-output shape
   here, with the board record and the ops-params list.
2. Strand 2, one file at a time, each review its own commit; the gen
   and fixture move with each rename.
3. Strand 1: the gen reproduces the pair; `sema validate` green on both.
4. Strand 3: the axiom edits, one sema sitting, with the gwsproto
   mirrors and the closure refresh.
5. `sema validate` green on the real House0 fixture, the clause krida
   rung 3 handed here.
6. Line item, last: **DeviceType as the enum in gwsproto.** The words
   leave `DeviceType` a string so other organizations can use the
   schema; inside our repo every value comes from the closed list we
   own, enforced today only at the authoring points and by string
   equality at bind time, so a stale name in a layout binds to nothing
   and fails late in the loader. Typing the twins with the enum moves
   the failure to construction (sema gravity one level down). Six
   device-type twins declare `DeviceType: PascalCase` (scada, electric
   meter, hp, hp control box, ads111x, ads channel config) plus the
   component twins that carry one (board, relay, meter, BTU and flow
   modules, tank modules, hubitat, web server, dfr). Real and simulated
   values live in `DeviceType` and `SimDeviceType`: the field type is a
   union of the two, or the enums merge (a decision to take first).
   Fixtures, generator output and the vendored records already carry
   house values, so they pass unchanged and the suite says so; the
   conformance test stays green as long as sema's canonical examples
   use house values, so the examples get a look. gwsproto-wide, so
   stated before touched and the full suite after.
7. Line item: **delete `boiler-scada-ops-relay`.** A reserved-slot name
   from the 2024 House0 design (Krida position 10, the "scada ops" half
   of a failsafe/ops pair with relay 8, the aquastat control, as the
   failsafe half) that never got a relay wired, a node in any layout,
   a generator row or a caller. No tlayouts output, scada fixture,
   derived beech pair or deployed layout carries it; the fleet's boiler
   is controlled by relay 8 alone. Decided 2026-09-11: a phantom, not a
   reserved slot. Four lines in gwsproto go together:
   `House0NodeNames.boiler_scada_ops` (`names/house0/node_names.py`)
   and its `Literal` twin in `data_classes/house_0_names.py`, the
   channel-name constant and its H0N-derived alias in
   `names/house0/channel_names.py`, and the `HydronicLayout.boiler_scada_ops`
   property. If a fall house gets a direct boiler-call relay, the name
   returns with its generator row and a caller in one change.

## Do this next

Open the word-gate discussion for strand 3 while strand 2 starts on
`shared.py`: list which H0N/H0CN members `shared.py` holds and the tier
each goes to.

## Open

- Whether `HydronicLayout`'s essential-nodes check should name
  five-v-boss and the cycler, or stay a minimal list with the layout
  words as the requirement.
- Whether this becomes its own flat Linear issue (title `correct-house0`): two pieces of work
  depend on it (the 0-10V shift's fixture regen, the fall installs'
  regen), which is the shared-dependency rule's case.
- The gwsproto multichannel relay component and `RelayActorConfig` (the
  twins of `i2c.multichannel.dt.relay.component.gt:004` and
  `sim.relay.component.gt:000`, plus `LayoutLite.I2cRelayComponent`)
  retire in the sema wave that drops them from the House0 word's
  Components union, with the House0 `BoardResolution` axiom (mirror of
  Nolan axiom 2). Scada stopped using them 2026-09-10; the vendored
  closure registry and the conformance test are what keep them.
- Beech's real tank picos post a `TankModuleParams` the current word
  rejects (older firmware).
- `H0N.tank` / `H0N.zones` instantiated machinery: home undecided.
- `DeviceType` and `SimDeviceType`: one enum or a union, for line item 6.
