# Correct House0 (spoke)

Status: Accepted · Pass 1 · Updated 2026-09-14 · Linear: OPS-392

> What this is: House0 made right — the House0 layout correct across three
> representations that close only together: the **sema word** carries the right
> node/channel requirements, **three gens** emit the layouts from it (a
> simulated fixture for the scada suite, real deployment layouts for beech and
> maple), and the **scada code** reads House0 correctly (H0N/H0CN aliases
> retired, direct name reads corrected). Flat work issue OPS-539 (hours and
> scope there; the hub is OPS-392). The gens — not any hand-kept file — are the
> thing to get right, because the layouts regenerate again for the fall installs.

## The three strands (key context)

Every name decision changes the word, the gens, the fixtures and the code at
once, so the strands close together, not in isolation.

1. **The sema word carries the requirements.** `gw.house0.layout/000` (staging,
   so edited in place under the word-gate ritual: read `sema/spec/primary.md`
   and the registry/authoring spokes, post the summary, wait) is brought to the
   shape the Nolan word already has. Every House0 layout — simulated or real —
   validates against it. It carries fourteen live axioms;
   [rung 6](#rungs) lists the gaps against Nolan.

2. **Three gens emit the layouts**, all from the shared family-gen machinery
   (`layout_gen.py` + `src/tlayouts/hardware/`), never hand-kept:
   - **`sim_house0_gen` → `gw.house0.layout.json`, simulated parts, `sema
     validate` green.** This is the scada suite's House0 fixture — all
     `SimDeviceType` components, so the scada boots it in-process with no real
     hardware. The scada repo carries *only* this simulated layout.
   - **`beech_gen.py` → the real beech deployment layout** (real Krida panel,
     LG nameplate, Honeywell-via-Hubitat zone circuit, DFRobot outputs). A box
     artifact, generated and deployed, not a scada test fixture.
   - **`maple_gen.py` → the real maple deployment layout**, on the same config
     class.

   On regen the vendored gwsproto closure copy refreshes in the same wave (the
   layout-closure mirror maxim).

3. **The scada code reads House0 correctly.** The two hydronic actor files carry
   the bulk of the House0 references and have never had a review or a test. Each
   file review gives its H0N/H0CN references a tier decision and repoint, and the
   gens and fixtures carry the rename in the same commit; each file gets its
   first tests, per the single scada focus.

**Names retirement is the cross-cutting thread** — not a strand of its own. Each
settled name moves the word, the gens, the fixtures and the code together. The
settled principles ([rung 5](#rungs) holds the live inventory):

- A names class is **vocabulary**, not a required-set — "if a layout has the
  thing, this is its name"; requiredness lives in each layout word's axioms.
- Each settled name lands as **one unit**: constant in its disjoint class →
  H0N/H0CN alias deleted → call sites repointed (through `self.layout.X` where a
  property exists) → fixtures renamed. **Liveness is judged over the alias
  union** — a disjoint-class constant with no direct readers is not unused while
  an H0N/H0CN member carries the same name.
- **No `Literal` in names classes** — bare assignments throughout
  `gwsproto/names/`; the annotation narrows nothing a signature demands and
  doubles every rename (H0N keeps its until deleted).
- **Store-tank element names go per-tank** (`tank1-top-elt`, `-pwr`, `-relay` +
  bottoms, via `TankNodeNames` / `TankChannelNames`); buffer elts stay flat
  hydronic-tier; store-loop names (`store-flow`, `store-btu`, `store-pump-relay`,
  pipes) are circuit names and keep `store-*`.
- **`backup` / `scada-blind` are House0 names** for now; they may return to a
  shared tier once the Nolan state machine and its local control are worked
  through, not before.
- **hp-odu**: for monoblocs, hp-odu *is* the heat pump; device identity is the
  layout's device-type records' job (node → component → DeviceType).

## Rungs

In sequence; ✅ done, **▶ active**. Each name-bearing rung moves the word, the
gens, the fixtures and the code together.

1. ✅ DONE (2026-09-14) **Sim pair from the gen.** `house0_sema_gen.py` emits
   the board record and its `krida`-bound anchor, the `i2c-bus` node, per-relay
   and per-output components against the record, the power-on levels in the ops
   word; the sim board record is vendored as `device_types/sim.krida-…json`.
   Output semantically identical to the hand-patched pair, every id preserved
   (scada `0944df35`, `293b0215`).

2. ✅ DONE (2026-09-14) **The board as a config axis, gw108 the default.** The
   gen takes its board from config (node name, record file, simulated twin, bus
   addresses) and its 0-10V outputs as specs against that board. Default gw108
   rev B (what every install from here on uses; beech's krida panel may itself
   be replaced by a gw108). Beech, maple and the sim declare krida plus DFRobot
   explicitly. "Which board" becomes a one-axis swap (`layout-word-axioms.md`).

3. ✅ DONE (2026-09-14) **Family-neutral hardware modules.** `layout_gen.py` is
   the base generator (id map, accumulators, emit helpers) with House0 and Nolan
   as siblings; `src/tlayouts/hardware/` realizes one kind per module (board,
   i2c relay, DAC output, thermistor channel, tank module, power meter, gpio
   relay, gpio sensor, BTU meter, hubitat zone) against the board record, spec
   beside realizer; a family gen owns only the plant roster its word requires.
   A move, not a redesign: the outputs regenerated byte-identical. Drivers are
   `<house>_gen.py`; the six commented legacy generators are `old_gen_<house>.py`
   (after tlayouts `400e858`).

4. **▶ The three gens emit their layouts.** All from the shared family-gen
   machinery (`layout_gen.py` + `src/tlayouts/hardware/`), in this rung:
   - **`sim_house0_gen` → `gw.house0.layout.json`** — the scada suite's House0
     fixture: a House0-shaped layout (sieg loop, buffer, store tanks) with every
     component `SimDeviceType`, `sema validate` green, booted in-process. Today
     this file is a hand-authored hodge-podge of real and simulated devices
     assembled to run a test, and fails validate with 944 errors — the symptom of
     an ad-hoc fixture where a cleanly generated simulated layout belongs, not a
     worklist; this rung replaces it with generated sim output.
   - ✅ DONE (`7c2db53`) **`beech_gen.py` → the real beech deployment layout**
     (real Krida panel, LG Multi V split HP, Honeywell-via-Hubitat zones, DFRobot
     outputs). `sema validate` green, id-preserving against the deployed layout.
     A box artifact, not a scada fixture.
   - **▶ `maple_gen.py` → the real maple deployment layout**, same config class —
     the next gen. Like beech but DERIVES primary-flow (`DerivedSiegSum`) rather
     than measuring it.

   Oak, fir and elm are the sieg-less family and wait for `gw.house0.no.sieg`;
   `oak_gen.py`, a House0-shaped config for a no-sieg house that raises at the
   stub, retires into that family's generator when its word exists.

   Shared-gen work this rung needs (Nolan+sim regen byte-identical; oak flips
   Reed→Hall):
   - `emit_flow` hardcodes Reed — a bug: fleet flow picos are **Hall** (Saier,
     `ConstantGallonsPerTick` 0.0009), and it mis-generates oak. Give `FlowSpec`
     a `kind` axis (`hall` default / `reed`), an optional explicit `node` for a
     non-standard meter (`dist-flow2`), and a `flow_meter_type` override
     (`SaierSenhzg1Wa` for Hall; `OmegaFtb8010FlowMeter` for `dist-flow2`). Hall
     sets `PublishEmptyTicklistAfterS` / `PublishTicklistPeriodS`; Reed keeps
     `PublishAnyTicklistAfterS` / `PublishTicklistLength`.
   - `btus` → `LayoutGenConfig` base; `emit_btu_meters` before
     `emit_primary_flow` (beech's `primary-flow` / `dist-flow` come from the BTU
     picos, so the bare-`primary-flow` emit correctly skips).
   - `AdsChannelSpec` gains a thermistor-make-model axis (default Tewa) for
     beech's Amphenol zone air-temps.
   - Zone temp truth: `Zone.TempChannelName` → `zone{i}-{zone}-gw-temp`
     (`CelsiusTimes100`, about the zone node, captured by `analog-temp`) — the
     accurate ADS sensor, as spruce uses its gw-temp; the Honeywell stays the
     setpoint/state read.
   - The sieg surface: `sieg-cold` via the ADS, `sieg-flow` + `sieg-flow-hz` via
     a Hall flow pico (`FlowSpec` position `sieg`); no `DerivedSiegSum` (beech
     measures `primary-flow`).

   Done when `sema validate` is OK on all three outputs and the scada suite is
   green against `gw.house0.layout.json`. Known already: the real beech Krida
   record carries an older DisplayName than the vendored record.

5. **The hydronic reviews + the H0N/H0CN names retirement.** One file at a time,
   each review its own commit; the gens and fixtures move with each rename;
   first-ever tests per file. Names no reviewed file holds get one end-of-review
   sweep.
   - `actors/hydronic/shared.py` (~250 L): zone-circuit relay helpers, the vdc
     pair, onpeak/setpoint judgment, `latest_temps_f`. The shared bar is "every
     layout we can imagine has this" — a helper that assumes a buffer tank, an
     iso valve or store tanks is House0's, not shared.
   - `actors/hydronic/house0.py` (~990 L): choreography and judgment; the
     judgment methods (`is_buffer_*`, `is_storage_*`) are the thinnest coverage
     in the repo and each needs a functionality conversation, not just a test.

   The live inventory: **423 `H0N.` and 105 `H0CN.` references remain**; three
   members retired so far (`store_pump_failsafe`, `thermistor_common_relay`,
   `House0RelayIdx`). Every remaining member needs a tier decision + call-site
   repoint. Concretely still open:
   - system-actor names, the rest of the relay roster, ~40 H0CN channel aliases,
     `ScadaWeb`.
   - **Every layout has a store pump** (all five, slab included), so
     `store-pump-relay` is `HydronicSpaceheatNodeNames`' name — the Nolan
     duplicate is deleted and House0's `store_pump_failsafe` was repointed. HSNN's
     buffer-names docstring still claims "every hydronic plant" — false once the
     bufferless fall families arrive.
   - `tank1-elt` execution (its own commit): the per-tank element rename +
     `gw.nolan.layout` in-place edit (staging; word-gate ritual) + tlayouts
     sim-pair regen + gwsproto literals + code repoints.
   - `ZoneNodes` ≡ `HydronicSpaceheatZoneNodeNames` duplication (`relay.py`
     still builds `ZoneNodes` in `initialize_fsm`).
   - `HeatcallSource → ZoneCallSource` (`WallThermostat | Scada`) at
     `relay.py:466-472` + the roster-named `NolanZoneNodeNames` relay
     constants (move with their actor call sites) — season-neutral; pairs
     with the staged `ZoneCallSource` vocabulary (the zone-control model,
     OPS-532). Routed here from the relay-actor split, 2026-09-14.
   - Actor↔layout name duplication and Nolan-wrong direct name reads —
     `operational-params-cleanup.md` items 4-5 (the lists live there).
   - Buffer-side elt load-node ordering: `elt-buffer-top` deployed vs
     `buffer_top_elt` in HSNN — renames in the coordinated regen.
   - Un-audited corners: the `simple_sim` tier, `House0ChannelNames.__init__`,
     `names/*/helpers.py`.

6. **The sema word sitting** (word-gate ritual): bring the House0 word's axioms
   to the Nolan shape —
   - `RequiredSensing` — add the missing `dist-flow` and `store-flow` channels.
   - `RequiredActuators` — carry the per-output ComponentIds the 0-10V shift
     created (today it pins the three `*-010v` nodes by Name + ActorClass only).
   - `ComponentBinding` — add it (every Component referenced by exactly one
     ShNode) and un-skip its House0 test.
   - **Axiom 2 — command-tree bones**: it requires s/ltn/la/lc/derived-generator
     but not `n`, `auto`, `admin` or their handles that Nolan's
     `RequiredCommandNodes` pins and the command-tree machinery assumes. Extend
     it to the Nolan shape.
   - Re-read every axiom statement against the post-rename fixtures so none pins
     a retired name.

   The mirror is gwsproto's `check_axiom_<n>` validators, regenerated, plus the
   conformance test. Sequenced after the fixtures validate (rungs 4-5), because
   every axiom is run on the fixtures by the loader — the word tightens only once
   they pass.

7. **Line items.**
   - **DeviceType as the enum in gwsproto.** The words leave `DeviceType` a
     string so other organizations can use the schema; inside our repo every
     value comes from the closed list we own, enforced today only at authoring
     points and by string equality at bind time — so a stale name binds to
     nothing and fails late in the loader. Typing the twins with the enum moves
     the failure to construction. Six device-type twins declare
     `DeviceType: PascalCase` plus the component twins that carry one; real and
     simulated values live in `DeviceType` and `SimDeviceType` (a union, or the
     enums merge — a decision to take first). Fixtures, generator output and
     vendored records already carry house values, so the suite passes unchanged.
     gwsproto-wide: stated before touched, full suite after.
   - **Delete `boiler-scada-ops-relay`.** A reserved-slot name from the 2024
     House0 design (Krida position 10) that never got a relay wired, a node, a
     generator row or a caller; the fleet's boiler is on relay 8 alone. A
     phantom (decided 2026-09-11). Four lines in gwsproto go together:
     `House0NodeNames.boiler_scada_ops` + its `Literal` twin in
     `house_0_names.py`, the channel-name constant + its H0N alias, and
     `HydronicLayout.boiler_scada_ops`. Returns with a generator row and a caller
     if a fall house gets a direct boiler-call relay.

## Open / what we learned

- **The scada repo holds only simulated layouts.** The real beech/maple layouts
  are deployment artifacts (real hardware), generated per-house and deployed to
  the box — never scada test fixtures. `gw.house0.layout.json` is the *simulated*
  House0 fixture; the 944 validate errors under the current file were the symptom
  of a hand-authored hodge-podge of real and simulated devices sitting where a
  cleanly generated simulated layout belongs, cleared by rung 4, not a worklist.
- `H0N.tank` / `H0N.zones` instantiated machinery: home undecided.
- Whether `HydronicLayout`'s essential-nodes check should name five-v-boss and
  the cycler, or stay a minimal list with the layout words as the requirement.
- The gwsproto multichannel relay component and `RelayActorConfig` (twins of
  `i2c.multichannel.dt.relay.component.gt:004` and `sim.relay.component.gt:000`,
  plus `LayoutLite.I2cRelayComponent`) retire in the sema wave that drops them
  from the House0 word's Components union, with the House0 `BoardResolution`
  axiom (mirror of Nolan axiom 2). Scada stopped using them 2026-09-10; the
  vendored closure registry and the conformance test are what keep them.
- Beech's real tank picos post a `TankModuleParams` the current word rejects
  (older firmware) — a case where the real layout is right and the *word* must
  change, not the fixture.
- `DeviceType` and `SimDeviceType`: one enum or a union, for the line item.

## Open naming question

The real beech/maple deployment layouts need instance filenames distinct from
the simulated `gw.house0.layout.json` (they share the `gw.house0.layout`
TypeName but are different instances). Not yet decided — flagged here rather
than guessed.
