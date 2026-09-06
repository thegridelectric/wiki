# Unsorted (spoke)

Status: Draft · Pass 0 · Updated 2026-09-04 · Linear: OPS-392

> What this is: a drop-box for things that show up mid-work that we
> deliberately don't think through yet. Items graduate to a real spoke,
> the cleanup queue, or the trash — they don't get designed here.

- **Honeysuckle layout does not generate (found 2026-09-04).**
  `tlayouts/honeysuckle_sema_gen.py` sets `power_meter_kind="sim-egauge"`,
  which the config's `Literal["sim", "egauge"]` refuses while the
  generator code paths handle the value. Honeysuckle is NOT a simulated
  home: it is the pi attached to a real gw108 at the Stoneman
  microgrid (tailscale `100.118.30.38`), and there is a real eGauge on
  site, so its power meter is `egauge` with that eGauge's identity, not
  a sim knob. Fix when the bench rung of the DAC output actuator needs
  the layout regenerated (`dac-output.md` step 4); until then the
  deployed bench layout is the last good output.
- **Pumps need a type in the layout (2026-09-05).** Nothing in a layout
  says what each pump IS: make and model, and with it the control kind
  (0-10 V, PWM, on/off, fixed-speed) and the curve the control code
  needs. Spruce's secondary pump is a Grundfos UPMS 20-78 F driven by
  the DAC output; the dist and store pumps are not identified anywhere
  either. A device-type record per pump model (the pattern the heat
  pump parts use: a node with a component whose DeviceType names the
  record) is the likely shape; the speed-versus-output curve from
  `experiments/future/spruce-pump-speed-sweep/` is the first fact such
  a record would carry.
- **CT measurement chain for the gw108** (from a conversation with Joe,
  2026-09-02). Three levers set what a CT channel can measure:
  the CT's winding ratio, how many times the power wire loops through
  the CT, and the burden resistor (470 Ω is built into the board; any
  resistor can be connected at the terminals). Encapsulate as
  **`CurrentTransformerMeasurementScale` = resistor × loops / ratio**
  (today: 470 × 1 / 2000 = 0.235; the 2000:1 CT + built-in burden
  measures up to ~540 W — far above our sub-100 W pumps, hence the
  interest in rescaling). Vocabulary this implies:
  - **`BoardBurdenResistors`** — built-in burden resistors, a fact of
    the board record (belongs in the gw108 rev B json).
  - **`AddedBurdenResistors`** — per-instance: what's actually
    connected at the terminals in a given home.
  - A mechanism for attaching WHICH CT is used (specifically including
    its winding ratio) — the MakeModel head-fake for CTs carries
    neither ratio nor type today.
  - A way of capturing HOW it is installed (loop count — e.g. the
    power wire looped twice through the CT).
  - From all of that, the derived `CurrentTransformerMeasurementScale`
    the reading pipeline uses.
- **Is ComponentId redundant on the wire once ComponentBinding holds?**
  Parked: NO for now, deliberately — the node Name is the unique
  identity WITHIN the house, while ComponentId identifies the physical
  instance, so replacement history is trackable (same name, new uuid).
  Revisit only if instance tracking finds a better home.

- **Thermostat chunk: sim thermostat, setpoint discovery, coverage,
  web-listen EDD** (from the Honeywell layout-plumbing read,
  2026-09-02). The read found that Hubitat push events never reached
  the scada: `hubitat_interface.py` used `time.time()` without
  importing `time` and swallowed the NameError, so the field has only
  ever had the periodic MakerAPI poll. The one-line import landed
  2026-09-02 as its own commit; it does NOT by itself revive the path,
  because the stat node runs under `s2` and the hub's web server under
  `s`, so neither finds the other's communicator to register handlers.
  What this chunk covers, as one estimated unit:
  - A **sim thermostat**: a simulated Hubitat/MakerAPI surface the
    poller and web-listen actors run against unchanged (canned refresh
    responses; a POST to the listen path), so the real-shaped House0
    fixture boots and reads in the sim framework. Distinct from the
    sim House0's Nolan-type mechanical dial.
  - **Setpoint discovery cleanup**: LocalControl finds zone setpoints
    by substring-matching channel names (`'zone' in x and 'set' in x`)
    and nothing consumes the circuit's `Thermostat` (kind, ComponentId).
    Resolve setpoint and zone-temp channels through the zone circuit
    declaration instead.
  - **Coverage**: no test constructs `Hubitat` or `HoneywellThermostat`;
    first tests are the poller on a canned refresh response asserting
    the SyncedReadings it emits, and the web handler on a canned event
    (the test that would have caught the import).
  - **EDD**: the web-listen path tried end to end in the sim
    framework, which decides the `s`/`s2` placement question (move the
    stat under `s`, or route registration across the pair) with a
    witnessed event rather than by reading. Reproducer under
    `experiments/`, logbook line, scoped Verified claim.

