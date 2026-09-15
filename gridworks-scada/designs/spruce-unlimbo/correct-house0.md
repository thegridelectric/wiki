# Correct House0 (spoke)

Status: Accepted · Pass 1 · Updated 2026-09-15 · Linear: OPS-539

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
   so edited in place) is brought to the shape the Nolan word already has. Every House0 layout — simulated or real —
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

4. ✅ DONE (2026-09-15) **The three gens emit their layouts.** All from the shared
   family-gen machinery (`layout_gen.py` + `src/tlayouts/hardware/`):
   - ✅ DONE (2026-09-15; tlayouts `26401c5`, scada `61022bc6`) **two sim pairs
     from the gens** — the scada suite's House0 fixtures, one per sieg-flow
     pattern: `orange_sim_gen.py` → `gw.house0.orange.*` (Measured primary,
     `sieg-send-flow` by difference) and `willow_sim_gen.py` →
     `gw.house0.willow.*` (DerivedSiegSum: `sieg-send-flow` measured,
     `primary-flow` by sum), a second little house with its own GNode identity.
     Both all-`SimDeviceType`, `sema validate` green, booted in-process; the
     hand-kept hodge-podge fixture (944 validate errors) deleted. The sim sensor
     actor now feeds the derived generator whenever a DerivedChannel consumes one
     of its channels, and the suite's first end-to-end derived-flow test runs on
     both pairs. Fixed on the way: `emit_sim_power_meter` minted its component id
     twice (held only while a reference carried the id); the scada layout loader
     lacked the `difference` case the actor had.
   - ✅ DONE (`7c2db53`) **`beech_gen.py` → the real beech deployment layout**
     (real Krida panel, LG Multi V split HP, Honeywell-via-Hubitat zones, DFRobot
     outputs). `sema validate` green, id-preserving against the deployed layout.
     A box artifact, not a scada fixture.
   - ✅ DONE (2026-09-15; tlayouts `155d4e0`, scada `e398dc57`, sema `8e56c4e`)
     **`maple_gen.py` → the real maple deployment layout** (Mitsubishi Ecodan
     WUZ-SA48NMZ + ERSF-NM6E hydrobox, sieg-btu + store-btu, dist and sieg-send
     Hall picos, `oat` on the ADS). `sema validate` green, id-preserving. Maple is
     the first house to DERIVE primary-flow, which settled the sieg flow identity
     `primary-flow = sieg-send-flow + sieg-flow`: the send-line meter takes the
     `<position>-flow` grammar (`sieg-send-flow`, replacing bare `sieg-send`; the
     gwsproto constant had no readers), `FlowSpec.position` is an open
     `SpaceheatName`, and the derived generator gains a `difference` strategy so
     beech (measures primary) derives `sieg-send-flow` while maple sums. House0
     axiom 8 no longer requires `sieg-flow-hz` — a BTU-sourced or derived flow has
     none. For the sieg-requirements spoke: `sieg-send-flow` is required as a
     DataChannel OR DerivedChannel, node not required, no `-hz`.

   Oak, fir and elm are the sieg-less family and wait for `gw.house0.no.sieg`;
   `oak_gen.py`, a House0-shaped config for a no-sieg house that raises at the
   stub, retires into that family's generator when its word exists.

   Shared-gen work this rung needs (Nolan+sim regen byte-identical; oak flips
   Reed→Hall) — ✅ ALL BUILT for beech (`7c2db53`), each byte-verified against
   spruce+sim; maple reuses them. As-built notes vs the spec below: the second
   dist meter is the **`dist2` position** (not a `node` override), the Hall meter
   type is **`SaierFlowSensor`** (not `SaierSenhzg1Wa`), and `TankSpec` gained
   asymmetric depth-1/3 calibration + `sensor_order`:
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

   Known: the real beech Krida record carries an older DisplayName than the
   vendored record.

5. **▶ The hydronic reviews + the H0N/H0CN names retirement.** One file at a time,
   each review its own commit; the gens and fixtures move with each rename;
   first-ever tests per file. Names no reviewed file holds get one end-of-review
   sweep.
   - `actors/hydronic/shared.py` (~270 L): zone-circuit relay helpers, the vdc
     pair, onpeak/setpoint judgment, `latest_temps_f`. The bar for a name or
     helper staying in the hydronic tier is NOT "every layout has it": most
     layouts have store tanks (all but the slab house) and two have a buffer.
     A thing leaves hydronic only when it is potentially confusing across
     families — the core example is the iso valve and the charge/discharge
     relay, wired differently in `gw.house0` and `gw.house0.no.sieg`. (Bar to
     confirm; stated 2026-09-15.)
     First tests: `tests/actors/test_hydronic_shared.py`, both sim pairs
     (relay lookup, the four zone-relay commands from the boss and from a
     non-boss, the vdc pair, setpoints, `is_system_cold`, the TOU clock).
     Found and fixed: `stat_ops_relay` raised a bare `Exception` naming the
     wrong method where its docstring promised `DcError`. What the review
     left in the file is rung 8.
   - `actors/hydronic/house0.py` (~890 L): choreography and judgment.
     First tests: `tests/actors/test_hydronic_house0.py`, both sim pairs —
     all twenty plant commands from their boss and from a non-boss, the
     sieg-loop node gate, the energy/power/defrost readers, the store-flow
     predicates, and the temperature pass. Found and fixed:
     `discharging_store` / `flowing_from_hp_to_house` crashed
     (`None.State`) before the charge/discharge relay had reported a state;
     they now answer False. Untested and waiting on a functionality
     conversation each: `is_buffer_empty`, `is_buffer_full`,
     `is_buffer_charge_limited`, `is_storage_colder_than_buffer` (rung 8
     lists what the read surfaced).

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
     `gw.nolan.layout` in-place edit (staging) + tlayouts
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
   - `api_flow_module.py` forwards readings to the derived generator only when
     `self.node.name == "sieg-flow"` (two sites), so on a real house the sum or
     difference fires only on sieg-flow readings. The sim sensor's rule (forward
     when a DerivedChannel consumes one of your channels) is the name-free
     replacement.
   - Do this next: the three open rung 8 house0 items — buffer judgment on a
     bufferless House0, the magic thresholds, the 0-10V outputs under `auto`
     on the sim pairs — then tests for `is_buffer_empty`, `is_buffer_full`,
     `is_buffer_charge_limited` and `is_storage_colder_than_buffer` on both
     sim pairs. The scada tree holds one uncommitted cluster (the pending
     changelog entry names it); commit it before the next move.

6. **Sema work.** Bring the House0 word's axioms to the Nolan shape, and
   rename the buffer flag —
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
   - **`ShortCycleBuffer` → `KeepBufferFull`**, in place (all three carriers
     are staging): `gw.house0.operational.params` 000,
     `gw.nolan.operational.params` 000, and `layout.lite` 013 (its
     `BufferShortCycling`, the copy the scada sends the LTN). With it the
     gwsproto twins, the `_gen.py` config field and every gen call site, the
     sim fixtures, the scada read site and the LTN attribute, then regen. The
     field's description, both ops words:

     > When true, the buffer is kept near full rather than used as storage.
     > The leaf ally cycles it on its bottom sensor, charging when depth3 is
     > below the required return-water temperature and stopping when it is
     > above, so only a small slice of the tank swings between heat pump
     > runs, and the LTN reports zero buffer-available kWh. The FLO then
     > plans on the store alone, at the cost of the buffer's volume and more
     > frequent heat pump cycling. When false, the buffer drains from its top
     > sensor before a recharge and its energy counts toward what the FLO can
     > use. Local control does not read this flag.

     `layout.lite` carries the one-line form: "The running scada's
     `KeepBufferFull` setting; the LTN counts no buffer energy when true."

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

8. **Hydronic shared cleanup, with tests.** What the `shared.py` review
   (rung 5) found and did not touch; each item extends
   `tests/actors/test_hydronic_shared.py` on both sim pairs.
   - `get_zone_setpoints` scrapes `latest_channel_values` by substring
     (`'zone' in x and 'set' in x`) and `is_system_cold` builds
     `zone + '-set'` / `'-temp'` by hand. Both are the zone channel-names
     class's job (`ZoneChannelNames`: the `-set` and `-temp` channels by
     zone), the hand-map tell. Repoint, no scrape.
   - `is_onpeak` / `just_before_onpeak` hardcode the Versant peak hours and
     weekdays. A tariff fact, not actor logic: it belongs in the ops word or a
     `names` constant the actor reads. Decide the home, then move it.
   - `heatcall_ctrl_to_scada` carries a dead `command_node is None` branch
     after the default; delete it.
   - `get_zone_setpoints` writes `zone_setpoints` as a side effect that
     `is_system_cold` then reads; the pair's "setpoint at start of on-peak"
     memory is implicit in when the refresh is skipped. Make that state
     explicit when the repoint touches it.

   From the `house0.py` review, the judgment half:
   - ✅ `is_buffer_full` keeps its proxy fall-through (decided 2026-09-15,
     recorded in `control-hierarchy.md` "The node-actor partition"); the info
     glitch now names the proxy channel.
   - ✅ Store temperature pass (agreed 2026-09-15): one shared function
     (`actors/hydronic/store_temps.py`) the scada and the LTN both run on
     every pass; 35–200 F valid range; fill baseline the store cold pipe,
     else the coldest reporting layer, never a constant; nothing filled when
     no layer reports. Oak's summer store (60–65 F every layer, 30 days) was
     the evidence against the old 70 F floor-and-baseline.
   - ✅ `hp_in_defrost` keys on the hp-odu component's `DeviceType`
     (decided 2026-09-15): a hand-kept table in `house0.py`
     (`DEFROST_SIGNATURES`: which draw, idu or idu+odu, and the watt line;
     LG Multi V: total under 8.4 kW; an unlisted unit is never judged in
     defrost) until `hp.device.type.gt` carries the signature (noted in the
     records spoke). `settings.hp_model`, the LTN copy, hp-boss's dead
     assignment, the `HpModel` enum and its allowlist row are gone.
     Fir's Samsung hydro kit is the same `SamsungAE055FCYDCG` odu spruce
     names, so its row (idu under 4 kW) is in. Requiring the record by axiom
     stays sequenced with the fleet records (OPS-532).
   - ✅ One reader pair for the power channels: `odu_pwr` / `idu_pwr`
     deleted with the defrost change; `hp_odu_pwr_w` / `hp_idu_pwr_w` and
     `total_hp_pwr_w` remain.
   - **Buffer judgment on a bufferless House0.** `is_buffer_*` and
     `is_storage_colder_than_buffer` pick their channel by `in
     latest_temps_f` and fall through to pipe proxies, so a house with no
     buffer silently judges from `dist-swt` / `hp-ewt`. The fall installs
     with no buffer need an explicit "no buffer" answer, not a proxy.
   - **Magic thresholds in the judgment:** the 3-hour forecast window, the
     `MaxEwtF - 10` cap, `min_delta_f = 5.4`, `usable_kwh < 0.2`, the 4 kW /
     8.4 kW defrost lines. Each is a control decision; name it (an ops-word
     field or a `names` constant) or leave it with a sentence saying why.
   - `set_010_defaults` sends nothing on the sim pairs: the three 0-10V
     outputs hang under `auto` (`auto.dist-010v`), not under `n`, so they
     are neither `n`'s direct reports nor in `lc`'s actuator set. Check the
     deployed spruce layout puts them where the code expects.

## Open / what we learned

- **The scada repo holds only simulated layouts**: two House0 pairs (orange,
  measured primary; willow, derived primary) plus Nolan. The real beech/maple
  layouts are deployment artifacts, generated per house and deployed to the
  box. A test that needs a real-record detail (the GP8403 DAC arm) edits a
  `tmp_path` copy of a sim layout at the wire boundary, never a real layout.
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

Fixtures are named per little house, `gw.house0.<plant>.layout.json`. The real
beech/maple deployment layouts still need instance filenames distinct from the
fixtures (they share the `gw.house0.layout` TypeName but are different
instances). Not yet decided; flagged here rather than guessed.
