# Spruce relay control — chunk A execution (spoke)

Status: Draft · Pass 0 · Updated 2026-08-11 · Linear: OPS-392

> What this is: spruce-unlimbo spoke — get the scada actuating spruce's i2c relays, with
> the heat pump under a single reliable on/off relay. Design-side record only. Everything
> Samsung-generic — wiring, configuration, service procedures — lives in the Drive doc
> **"PRIMARY — Samsung AE055 EHS mono control interface"** (Samsung AE055 folder, which is
> PUBLIC: no site or homeowner mentions there). Spruce install specifics + the immutable
> field log live on **[GRI-11](https://linear.app/gridworks/issue/GRI-11/spruce)** (the
> per-home issue; field events = comments).

## State (2026-08-10)

**The reader→bus build is verified on the bench and on the box**
(bench run logs below; the spruce window 2026-08-11,
`experiments/2026-08-10-ads-declared-rate/`). The continuation — the
relay + DAC actuation path and the hack takeover — is sequenced in
[`summer-local-control.md`](summer-local-control.md) and modeled in
[`zone-relays-and-thermostat-model.md`](zone-relays-and-thermostat-model.md).
This spoke keeps the code-survey pins, the bench/boot reproducers, the
relay roster, and the spruce-window safety arrangement that work rides
on.

The honeysuckle boot harness works (run log below) — the reader's ADS
reads run over `I2cBus` ops (the single-bus-owner build, sharpened
in the scada lane below), re-running the same bounded bench boot after each
step as the verification. Two routes to real temperature values: wire bench
thermistors (or divider jumpers) on honeysuckle, or a spruce box window —
spruce's thermistors are wired. The spruce experiment keeps the REAL spruce
identity (hw1 aliases, not dev-ified — it is actually spruce); isolation is
credential-structural: the experiment `.env` carries dev-broker credentials
only, never `hw1`, with the upstream host the localhost tunnel, so the
words cannot reach the prod broker. The cli-run universe guardrail would
refuse hw1 on localhost; the experiment boots through the bounded harness,
inside the guardrail's designed test-boot exemption. Prepared on the box:
`~/envs/prod.env` (preserved copy) + `~/envs/dev.env`. The deployed
`actual-spruce` scada must be stopped for the window — one ADS reader at a
time.

The bench-boot checklist that got the harness up (kept as the reproducer;
artifacts on the pi at `~/.config/gridworks/scada/hardware-layout.json`
+ `hardware-layout/gw.house0.operational.params.json`, identity
`d1.bench.honeysuckle.scada` — verbatim the tlayouts `output/honeysuckle/`
files, md5-checked 2026-07-29):

1. `jm/spruce-unlimbo` is pushed (tip `7b734d85`, 2026-08-10); on
   honeysuckle: fetch + checkout that branch in `~/gridworks-scada`.
2. Venv: the pi's existing venv imports gwproactor/gwproto cleanly
   (checked 2026-07-29); rebuild only if the branch's requirements
   diverge — `tools/mkenv.sh gw_spaceheat/requirements/dev.txt
   install_admin no_flo` (third arg skips the private gridworks-flo
   editable, which is LTN-side).
3. Create the pi's `.env` (`SCADA_` prefix, dev creds only — none exists
   yet). Broker as localhost: from the laptop,
   `ssh -R 1885:localhost:1885 honeysuckle` forwards the local
   `gw-dev-rabbit` MQTT port to the pi; the universe guardrail passes
   (`d1` ⇔ localhost).
4. Boot; first prize is the thermistor reader resolving `Thermistors`
   against the board record and publishing on all four ADS channels
   (bench inputs may be floating unless thermistors are wired — raw
   microvolt channels still prove the bus path). `/usr/sbin/i2cdetect -y 1`
   sanity first (full path — not on the non-interactive PATH):
   0x48/0x49/0x20/0x21/0x70 (re-verified 2026-07-29).
5. Log findings here (EDD: the harness run is the verification).

**Run log 2026-07-30 — reader→bus verified on the bench.** Same bounded
real boot (scada `09e0f917`, regenerated artifacts with the `i2c-bus`
node): the reader produced the same four floating-input
`i2c-thermistor-broken` verdicts as the blinka-era run, with every sample
now flowing reader → `I2cBus` → serialized block ops, and the ADS
config-readback gate silently passing on every conversion sequence
(~80 in the run). The single-bus-owner precondition for scada-driven i2c
relays holds on real hardware.

**Run log 2026-07-29 — the bench boot happened.** A bounded 30 s real boot
(`is_simulated=false`, artifacts from the pi's default paths, dev broker via
the laptop tunnel) came up as `d1.bench.honeysuckle.scada`: universe
guardrail passed, 18 actors instantiated, 12/42 channels populated.

- **The i2c read path is real:** `I2cThermistorReader` initialized against
  the ADS at 0x49 and read all four channels; each classified
  `i2c-thermistor-broken` — correct, the bench inputs are floating (rail
  voltage = broken/missing thermistor). The glitches are the bus-path
  proof; positive microvolt values need thermistors (or divider jumpers)
  wired on the bench.
- **GPIO both directions:** the four zone opto inputs read 1; the
  pico-cycler actuated `vdc-relay-gpio-23` (energize/de-energize) on the
  real board.
- Boot required: the driver venv (`tools/mkenv-pi.sh` — the dev-requirements
  venv has no blinka/adafruit stack) and `settings.paths.mkdirs()` (the
  event-persister dir; `cli.py run` creates it, a bare `ScadaApp` does not).
- The boot consumes the two authored artifacts directly since scada
  `c755195b` (boot-path assembly; the gap found was `NolanLayout` authored
  but unwired — see the 2026-07-29 changelog entry).

Two lanes behind it:

**Field (spruce, with George):** hardware completion, in order: (1) replace the blown
control-box fuse (details in the PRIMARY doc); (2) land the RIB contact (dead-work
procedure, PRIMARY doc) and set the one Samsung config value that hands on/off authority
to the contact; (3) witness the close/open pair — the running schedule service makes
every TOU boundary a free witnessed test. Then: the ctrl-box CT lands (channel
`hp-ctrl-box-pwr`) and the spruce layout regen picks it up (gen_spruce.py in tlayouts).
Queued field items (2026-08-04): the eGauge register-map fix is its own design
([OPS-483](https://linear.app/gridworks/issue/OPS-483)). Same visit: restore FSV
2091=1, swap the secondary-BTU pico. (The secondary-pump 0-10V re-landed on
the Z6 DAC output — dac2 channel_c — 2026-08-10, EEPROM defaults written.)

**Scada (the I2cBus build, on `jm/spruce-unlimbo`):** the single-bus-owner data model is
landed (sema `e9b050f`, scada `75746bfe` — the board record owns the physical facts; the
reader resolves via `AdcName`).
What remains is the bus-op path itself, sharpened by the 2026-07-22 code survey:

- `I2cBus` already consumes `I2cWriteBit`/`I2cReadBit` and echoes `TriggerId` on
  `I2cResult`, but the reply is hardcoded to `primary_scada`
  (`actors/i2c_bus.py:91-105`) — reply-to is a **rerouting** change (read
  `Header.Src`), not a new reply path.
- The reader still reads blinka/adafruit-direct
  (`actors/i2c_thermistor_reader.py:72-77`); moving it onto `I2cBus` ops is the
  build (decide: raw reg-ops from the reader vs an ADC-read primitive on the bus
  actor — lean primitive, every ADC consumer repeats the same sequence).
- `I2cBus` and `I2cRelayBoard` exist as `ActorClass` values but are NOT registered
  in `actors/__init__.py` — a layout declaring a bus node fails to instantiate
  until registration lands; move layout and registration together.
- No actor-level i2c tests exist (only named-type serialization) — the reader→bus
  build brings the first.
- The OPS-452 init-guard + input-register readback fold into the bus actor.

**Verification: reader→bus experiments run directly on spruce, ADC path only** (JM
2026-07-21; decided when the home bench gw108 would not power up — since revived,
see the 2026-07-23 update below). The arrangement that keeps this safe:

- **Broker isolation.** The experiment scada (`jm/spruce-unlimbo` code + the ops
  artifact) runs in its own environment on the spruce pi with NO production-broker
  credentials — dev broker only, real spruce identity (not dev-ified; the
  isolation is credential-structural, per the `.env` note above). This keeps the
  staging layout tier inside its dev-brokers-only boundary. Prod-affecting steps on the pi (stopping services, placing env files) are
  JM's to execute; the session preps commands + a watch-list.
- **Window protocol (simplified 2026-08-10): stop EVERYTHING that touches
  the bus.** The deployed `actual-spruce` scada (+ its restart watchdog)
  AND the summer hack are stopped for the window — nothing shares the
  bus, so no coexistence machinery is needed. The hack's exit failsafe is
  the safe posture (contacts open, HP off, zone holds latched); cooling
  pauses for the window, and the transient failsafe timer restores both
  services even on a dropped connection. (The earlier hack-coexistence
  arrangement with an owned-address allowlist was retired as overcareful;
  the allowlist idea survives re-scoped as layout-address validation on
  `I2cBus` — a next-version addition in `summer-local-control.md`.)
- **The experiment env MUST set its own paths name, not just its own
  layout path** (2026-08-11 window catch). Overriding only
  `SCADA_PATHS__HARDWARE_LAYOUT` leaves the event persister shared with
  the deployed scada (`~/.local/share/gridworks/scada/event/`): with no
  LTN on the dev broker the window's events queue there, and the
  deployed scada uploads them to the PROD broker as its own on restart —
  a hole in the credential-structural isolation. The window's events
  were archived to the experiment folder and removed from the box before
  restart; future window envs separate the paths root.
- **Relay-path actuation experiments do NOT ride this arrangement.** They need
  deliberate, scheduled hack-off windows (failsafe direction is safe: contacts open,
  HP off, cooling pauses) or a working bench board; the OPS-452 half-2 induced-reset
  reproducer is parked on the same condition.

Then the relay path rides the same bus actor, gated on that windows/bench decision.

**Update 2026-07-23 — the bench gw108 is alive** (the fuse was loose) and wired to
the pi `honeysuckle` (tailscale `100.118.30.38`, key-only ssh since 2026-07-23).
That reopens the bench option the 2026-07-21 arrangement assumed away: relay-path
actuation and the OPS-452 induced-reset reproducer can run on the bench with zero
cooling stakes, and the reader→bus path can shake down there before any spruce
window. **i2c scan (2026-07-23): the bench board matches the standard gw108 map**
— ADS1115s at 0x48 and 0x49 (config regs fingerprinted), expanders at 0x20/0x21,
the TCA9548A mux at 0x70 (DACs behind mux channels 1–3). The two ADCs are
role-distinct, exactly as the device type models them
(`gwsproto/data_classes/device_types/scada_gw108.py`): 0x49 is the thermistor ADC
(`ThermistorAdcs`, `I2cThermistorInterfaceCapability`, divider parameters), 0x48
is the **CT ADC** (`CtAdc`, plain `I2cAdcCapability`, ct1–ct4 per
`starter-scripts/gw108_test_code.py` — a current-sensing circuit, not a divider).
The `gw108_nolan_zones.py` single-thermistor-ADC guard stays valid; CT sensing is
a separate capability, which is where the actual-spruce CT1/CT2 notes land in the
port. Bench readiness is the Next-move checklist at the top of this spoke.

### Readiness — the spruce + honeysuckle layouts and the boot ladder

The identity split (settled 2026-07-28): **the honeysuckle bench owns the dev
role** — `honeysuckle_sema_gen.py` mints a `d1.bench.honeysuckle` trio, and
the bench pi (wired to the bench gw108) is where the reader→bus experiment
boots against a dev broker. **The spruce layout carries the real identity**:
`spruce_sema_gen.py` emits the deployed `hw1.isone.me.versant.keene.spruce`
aliases and GNodeIds verbatim (upgraded to `g.node.gt/005` shape), with all
69 channel UUIDs carried from the deployed layout — the artifact for the
eventual spruce deployment, not a dev variant. Sim-booting the spruce layout
on a dev broker goes through `sim_layout.devify_aliases`. Identity comes
wholly from the layout (`MyScadaGNode` etc. — `scada_app.py:142-146`). The layout is the scada's local
authority for its GNode trio — the same role the sema-validated `g.node.gt.json`
artifact plays for a gwbase service (`gwbase/gridworks_actor.py`); the fleet
authority stays the grid-node-registry, and FIS reconciles the two (the
mtls-fis-auth design binds cert CN to the immutable GNodeId and checks the alias
against the registry). The universe guardrail passes because `localhost ⇒ d1`
(`universe.py:32-37`); the broker the pi sees must present as localhost — SSH
tunnel to the laptop's `gw-dev-rabbit` for the first window; a rabbit container on
the pi if windows become routine (open choice).

**The layout machinery lives in tlayouts on `jm/spruce`** (sema-native;
the dev-spruce working branch squashed into it 2026-08-03, pushed to
origin). The ladder is built: the sema snapshot is rebuilt post-merge
(`jm/single-bus-owner` landed on sema dev,
`c1cab63`), the Nolan emitters are ported, and both gens exist —
`honeysuckle_sema_gen.py` (the `d1.bench.honeysuckle` trio; its
`output/honeysuckle/` artifacts are the ones on the bench pi) and
`spruce_sema_gen.py` (the deployed identity + carried deployed-gen content:
hp-ctrl-box eGauge register 9010, gw108 CT notes, zone-5 fancoil cooling
zone, identity derived channels, real pico HW uids; UUID stability via
`LayoutIDMap` keyed off the deployed `spruce.json`). The `actual-spruce`
`gen_spruce.py` rides the retired scada `layout_gen` machinery and the
single-artifact format; the scada repo's own spruce gen (`scratch2.py`) is
broken scaffolding — neither is the path.

**Boot ladder, cheapest gate first:** suite green on `jm/spruce-unlimbo` (conftest
pins the nolan fixture + its ops artifact, `tests/conftest.py:34-58`) → gen-time
validation (the gen refuses to write a layout that does not decode; `sema validate`
for hand-written gwsproto types) → **sim-boot the dev-spruce artifacts on local
`gw-dev-rabbit`** (the oak precedent) → the box window.

**Known blockers for unlimbo code on the box:**

- The deployed `spruce.json` does not decode on unlimbo gwsproto (the
  CaptureTuning reshape, reader `/003` board-record resolution, DeviceType `/001`)
  — regeneration is mandatory, not optional.
- The ops artifact is a boot requirement since `82caac3e`
  (`SCADA_OPERATIONAL_PARAMS_PATH`; default is the sibling dir of
  `SCADA_PATHS__HARDWARE_LAYOUT`, itself defaulting to
  `~/.config/gridworks/scada/hardware-layout.json`).
- The layout must carry the gw108 board record for `AdcName` resolution.
- The `hw1` hardcodes sit in the LTN (`ltn.py` P_NODE constants, price-service
  URLs) — inert while the experiment runs scada-only.
- Fresh checkout + venv on the pi (`tools/mkenv.sh`), its own `.env`, dev
  credentials only.

## Experiment result — noise floor vs poll rate + smoothing (2026-07-30)

Run on spruce's four wired zone thermistors (canonical record +
reproducer: `experiments/2026-08-06-ads-noise/`). The
baseline reader configuration (single-shot 128 SPS, 1 Hz, raw) measures
**0.011–0.012 °C stddev** — ~45× below the 0.5 °C async threshold, so the
reader needs no change for zone temps. The sample-to-sample noise measured
mostly white (the 5 Hz + EMA mode's ~2–3× reduction matches the √5
prediction), so future averaging can be sized by arithmetic rather than
re-measured; smoothing trades lag (~1 s as configured) and bus occupancy
(~30 % at 5 Hz × 4 channels) for a reduction the zone temps don't need.
Zone3-upstairs carries a low-frequency component smoothing can't remove —
the one channel worth a closer look.

Open from the same thread — single-sample trust: the reader publishes each
in-band sample as truth, so one garbled-but-plausible read publishes a
wrong value (a single garbled i2c read must not be believed — the
confirm-re-read lesson). Candidate closures: require two consecutive
in-band samples before an async publish, or the EMA above, which absorbs
single-sample glitches by construction. The measured noise floor says
this is about glitch robustness, not noise.

**To finish the experiment record (pick-up notes):**

- The 2026-07-30 run persisted SUMMARY STATISTICS ONLY — the raw
  per-sample series (the convention's "raw bundle") was never captured.
  The distilled numbers survive in the experiments-logbook entry; the
  summary JSON copies (`/tmp/ads_noise_results.json` on spruce, a session
  scratchpad copy) are ephemeral.
- To close it: (1) amend the harness to dump the raw per-sample series
  (timestamp + µV per channel, all three modes; ~150 KB JSON, ~30 KB
  zipped); (2) re-run — needs a spruce window with the deployed scada
  STOPPED (one ADS reader at a time; ~7 min for all three modes);
  (3) store the zip out of git — team Drive, or the proposed public
  experiments repo if that lands — and point at it from the logbook
  entry; (4) DONE 2026-08-03: the harness + summary live in
  `experiments/2026-08-05-ads-noise/` (the experiments repo).
- The harness reads the thermistor ADS at 0x49 only, big-endian block ops
  with the config-readback gate — safe alongside the summer hack, never
  alongside a running scada.

## The control design (settled 2026-07-15)

- **One gw108 expander relay is the heat pump's on/off line** — the spruce realization of
  the fleet-wide `hp-scada-ops-relay` role. The relay drives a normally-open RIB whose
  contact asserts the control box's external cool-call input, configured as the sole
  compressor on/off authority (Samsung-side step, PRIMARY doc). Closed = HP runs, open =
  stops. No zone machinery involved.
- **A second relay adds the independent heat call** (winter). Candidate functional names:
  `hp-cool-call` / `hp-heat-call`. **Software interlock mandatory: never both closed**
  (manufacturer constraint — PRIMARY doc).
- **Failsafe direction is HP-off, forced by the iso valve:** control system dead →
  contacts open → no call → HP off. HP-off is the only sensible failsafe while the iso
  valve fails CLOSED — on a board/power failure the valve relay de-energizes and the
  valve closes (energized = open, field-verified 2026-07-16), so a heat pump left
  running would push against a closed valve. A dead controller stranding the house
  without cooling is the cost; changing it requires changing the iso valve's failsafe
  position first (a normally-open valve), at which point call-closed-on-failure
  (autonomous HP keeps serving the house) becomes the better direction. The unit keeps
  its own protections (defrost, min cycle times, water limits) while commanded on —
  the ctrl-box CT is the behavioral verification that it actually ran.
- **Later, supersedes contact control:** Samsung's MIM-B19N Modbus module, if it reaches
  the US channel (`../../research/awhp-control-box-landscape.md`).

## Deployed and verified (2026-07-15)

- **`starter-scripts/spruce_summer_hack.py` runs under systemd on spruce**
  (`spruce-summer-hack.service`, enabled at boot; the winter twin
  `spruce-service/spruce.service` runs `spruce_hack.py`, disabled for summer). Schedule:
  weekends on; weekdays on 00-07/12-16/20-24, off on-peak. Sequencing per state change:
  iso valve commanded open → secondary-pump 0-10V (60% of max via the Grundfos UPMS 20-78
  curve, OPS-27 field data) → pump relay → HP call; failsafe open on exit (SIGTERM-safe);
  5-minute drift enforcement on the three relays + DAC (heals an accidental
  `gw108_test_code` import, which clears the expander).
- **First live transition witnessed 20:00:17 ET**: iso open → 7.20 V → pump CLOSED →
  hp-call CLOSED, correct order and timing. Schedule side is production-verified; the HP
  side goes live with the hardware completion above.
- MQTT creds moved out of script source into a pydantic-settings `.env`
  (`starter_settings.py`); all starter-script work now flows through git (local edit →
  JM commit/push → pull on spruce).
- Incident note: the control-box fuse blew during live RIB attachment (display went dark;
  fuse identified and replacement specced — PRIMARY doc). Dead-work procedure is the rule.

## What the code survey found (2026-07-15, `jm/spruce-unlimbo`)

**Working:** nolan boots cleanly as `House0Layout` (`Strategy="Nolan"`); the suite runs
against it; exactly one scada-actuatable relay exists — `vdc-relay-gpio-23` (5VDC/
pico-cycler, gw108 GPIO 23), wired end to end. `I2cBus` (`actors/i2c_bus.py`) is a
complete serialized smbus2 bit read-modify-write executor with sim stubs.

**Gaps for scada-driven i2c relays:** (1) no i2c relay nodes in the nolan layout
(`layout_gen/relay.py:646` — "added when their i2c driver is written"); (2)
`I2cRelayBoard` is a skeleton; (3) nothing produces `I2cWriteBit` — `I2cBus` is an orphan
consumer; (4) `I2cBus`/`I2cRelayBoard` unregistered in `actors/__init__.py`; (5)
`relay.py`'s only i2c branch targets the legacy krida multiplexer. The summer hack
bypasses all five (direct expander writes); the scada-actor path is the build that
retires it.

**The fork (resolved 2026-07-19): pull pass-two's thin `i2c.relay.component.gt` model
forward, scoped to the nolan/gw108 slice.** The alternative (extending the gw108
component family minimally) would mint a third relay-modeling scheme and another
hard-coded `relay.py` branch — the axis-3 leak the hub's conceptual model exists to
remove. The sema vocabulary is already authored (2026-07-03/09), so the remaining cost
is actor wiring either way; the single-bus-owner prerequisite below already routes ADC
reads through `I2cBus`, and the OPS-452 hardening (expander init-guard, input-register
readback) gets built once, in the durable actor. The slice: `Gw108Adc` device-type
value + thermistor-reader `/003`, `I2cBus` wiring with reply-to, i2c relay nodes in the
nolan layout gen on `i2c.relay.component.gt`, and a `relay.py` path resolving
`RelayName` against the board record. The krida decommission and the House0 layout
migration stay pass-two
([`../hardware-layout-pass-one/i2c-board-components.md`](../hardware-layout-pass-one/i2c-board-components.md)).
Deploy note: spruce runs `actual-spruce` (= `td/orig-pred-set`); the scada-actor build
lands on `jm/spruce-unlimbo` per branch discipline — upgrading spruce to it requires the
ops artifact placed first (`82caac3e` deploy note).

**Prerequisite (JM 2026-07-15): single bus owner before scada-driven i2c relays.** The
deployed thermistor reader (`i2c_thermistor_reader.py`, blinka/ADS1115, direct at its own
address) does raw i2c on the same physical bus the relay commands use. Before the scada
controls i2c relays, its ADC reads must move onto the serialized **`I2cBus` actor** —
the executor decision the i2c-board-components spoke already carries (its step 4) —
so exactly one actor owns `/dev/i2c-1` inside the scada. Cross-process note: the kernel
serializes individual i2c transactions, and per-device state keeps the running summer
hack and the scada's ADS reads from corrupting each other today; the one genuinely
shared-state device is the **TCA9548A DAC mux** (channel select is global bus state), so
while the hack runs, manual DAC use from a second process (the interactive
`gw108_test_code` session) is the collision to avoid.

## The spruce relay roster (hack parity, 2026-08-11)

The relay nodes the layout gen must emit for the scada to take over
`spruce_summer_hack.py`, named without any invented board index (the
component record carries chip/port/bit — `gw108-board.md`):

- **Zone pairs (0x20), wired zones 1–5:** `zone<n>-<name>-failsafe-relay`
  (port 0 bit n−1) + `zone<n>-<name>-ops-relay` (port 1 bit n−1),
  function enum `ZoneCallSource` (`WallThermostat | Scada`, the
  season-neutral rename). Zone 6 unwired ⇒ no nodes; the board record
  still carries the position. Hack parity commands holds on 1/2/4
  only.
- **`hp-scada-ops-relay`** (0x21 port 0 bit 0) — fleet role name kept
  verbatim; the season-neutral call contact.
- **`iso-valve-relay`** (0x21 port 1 bit 2, energized = OPEN, fails
  closed) — needs a valve-flavored function enum (open/closed, not
  generic relay-closed); name open. OPEN: is `iso-valve-failsafe`
  (port 1 bit 1) field-wired at spruce? Wired ⇒ node; unwired ⇒
  board-record-only.
- **`secondary-pump-relay`** (0x21 port 1 bit 5) — the pump on/off
  authority; speed is the DAC writer (dac2 channel_c), never zeroed.
- **OPEN — wired inventory for the rest of 0x21** (buffer/store
  elements, boiler-buffer-valve, boiler-intercept, primary-pump,
  store-pump, discharge-valve, fcm-misc, misc-relay1/2): each needs a
  wired-or-not fact (JM/George) before the gen emits it; only-wired
  positions get nodes.

Per-relay config rides the existing staging words
(`i2c.relay.component.gt` + the `relay.actor.config` family).

## Field facts (GridWorks side)

- **CT sensing wants its own device-type vocabulary.** The gw108 `CtAdc`
  (0x48) will carry physically different CTs per channel — spruce's notes: CT1
  is a current-output CT (100 A → 50 mA, external burden on the board), CT2 an
  eGauge-style voltage-output CT (20 A, internal burden, mV out). A future
  sema word (e.g. `ct.device.type.gt`) should record OutputKind
  (CurrentOutput | VoltageOutput), rated primary amps, and rated output
  (mA or mV), with the CT-ADC channel config referencing it per channel —
  mirroring how `AdsChannelConfig.ThermistorDeviceType` works. Not part of the
  dev-spruce layout (the deployed layout has no CT channels yet); the notes
  ride as comments in `gen_spruce_sema.py` until the word exists.
- **The gw108 expander map** is authored in `starter-scripts/gw108_test_code.py` (two
  TCA9555 expanders, all relays named; zone opto inputs ×6; ADS1115 CTs + thermistors;
  three MCP4728 DACs behind a TCA9548A mux). The board's `gw1.scada.device.type.gt`
  record matches it. DAC observation: 10 V at raw ≈4000, linear.
- **Power sensing:** no HP power metering until the eGauge lines cross the garage roof.
  Interim: George's CT on the ctrl-box feed → channel **`hp-ctrl-box-pwr`** (named for
  the metered circuit; ≈ primary-pump power is an interpretation). The gw108 CT inputs
  need a **current-out** CT (a voltage-out eGauge-type read nothing).
- The tmux monitor (`nolan_air.py`) prints snapshot channels; the secondary pump is a
  **Grundfos UPMS 20-78 with 0-10V control** (curve + type-key analysis in the OPS-27
  design, `../circulator-pump-0-10v-models.md`).

## HP make/model tracking

Canonized 2026-07-17 into the hardware-layout design:
[`../hardware-layout-pass-one/hp-device-types.md`](../hardware-layout-pass-one/hp-device-types.md)
is the single source — the two record families, the three primary-pump facts,
the enum values, layout carriage, open decisions, and the execution checklist.

## Provenance

Read-only agent survey of `jm/spruce-unlimbo` + on-site work with George (2026-07-15).
Key pins to re-verify when building: `relay.py:196-282`, `i2c_bus.py:70-144`,
`layout_gen/relay.py:646-649`, `actors/__init__.py`.
