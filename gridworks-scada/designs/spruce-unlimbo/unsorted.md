# Unsorted (spoke)

Status: Draft · Pass 0 · Updated 2026-09-05 · Linear: OPS-392

> What this is: a drop-box for things that show up mid-work that we
> deliberately don't think through yet. Items graduate to a real spoke,
> the cleanup queue, or the trash — they don't get designed here.

- **No heartbeat between admin and scada (found 2026-09-05, bench run
  4).** The admin link is one-way in practice: the admin client publishes
  a dispatch and watches for a few seconds; the scada holds Admin until
  its own timeout and never learns whether the operator is still there,
  and the operator never learns whether the scada is still listening. On
  run 4 the laptop's tunnel had died silently and the first dispatch went
  nowhere; nothing on either side said so. An operator can believe they
  are controlling a scada they are absolutely not controlling, and the
  scada can sit in Admin, its auto machine Dormant, for the whole timeout
  with no operator attached. Matters before any spruce window where a
  human is holding the pump; it graduates with the on-box sender move
  (dac-output.md "Do this next") or into `admin-for-nolan.md`.

  What the scada experienced (`experiments/2026-09-05-dac-output-bench/
  boot-2026-09-05-run4.log`, pi time; the client disconnected eight
  seconds after its send, and between 23:01:37 and 23:03:32 the scada
  logged nothing at all):

  ```
  22:59:42.197 admin:  awaiting_setup_and_peer -- mqtt_suback --> awaiting_peer
  23:01:29.244 admin:  awaiting_peer -- message_from_peer --> active
  23:01:37.182 [scada] Message from Admin! top_state Admin
  23:01:37.183 [scada] AutoGoesDormant: LocalControl -> Dormant
  23:01:37.199 [lc] TopGoDormant: Normal -> Dormant
  23:01:37.201 [scada] Admin Wakes Up
  23:01:37.205 [secondary-010v] Dispatch from admin: volts x10 55 -> code 2200
  23:03:32.021 [scada] Trouble with SendLayout: 'NoneType' object has no attribute 'component'
  23:03:37.205 Shutting down due to ShutdownMessage, [Signal received: SIGTERM (15)]
  23:03:37.287 [scada] Admin timed out! Auto
  23:03:37.287 [scada] AutoWakesUp: Dormant -> LocalControl
  23:03:37.310 [lc] Set auto.lc.n command tree
  ```

  The admin link never left `active`. The only thing that ends Admin is
  a fixed 120 s timer from the last admin message, and here it fired
  after SIGTERM had cancelled the tasks, so the auto machine woke and
  rewrote the command tree during teardown. The link has a
  `send_ping<admin>` task but no peer-liveness rule behind it.

  **Preferred shape: `heartbeat.a`** (verified in sema 2026-09-06,
  `sema/definitions/types/heartbeat.a/000.yaml`): `MyHex` required,
  `YourLastHex` optional, both `hex.char`, names sender-relative so one
  type serves both directions. Its extended description scopes it to
  "supervisor-tier liveness, not a contract instrument … within a
  single trust domain … peers identified by alias and no signing or
  non-repudiation is implied", which is exactly what admin↔scada is: an
  operator tool and the scada it drives, no money, no umpire. So unlike
  the scada↔LTN case (below) the canon needs no amendment. Sketch: the
  client beats every N s with a fresh `MyHex` echoing the scada's last;
  the scada answers in kind; a missed beat on the scada side releases
  Admin (Dormant -> LocalControl the same way the timer does today, but
  in seconds, not two minutes); the client shows the link as live only
  while its own echo comes back, never "sent". `heartbeat.a` has no
  gwsproto mirror yet (`slow_contract_heartbeat.py` is the only
  heartbeat there).

  **What the wiki already says about scada↔LTN heartbeats** (the
  improvements in mind; this admin item is the small sibling):
  - `executor/scada-ltn-link-state.md` "The contract-tier heartbeat is a
    separate, unfinished story": `SlowContractHeartbeat` (60 s while a
    contract is live) "is a first rough attempt at what is really
    wanted: a contract-tier heartbeat in the `heartbeat.a` shape"; it
    "has no silence deadline of its own"; the sema wrinkle is that
    `heartbeat.a`'s canon names scada↔LTN contract liveness as "a
    distinct, heavier mechanism … not modeled by this type", so amend
    the canon or mint a sibling (pending, sema-side).
  - `research/principles.md`: "A heartbeat that demonstrates liveness
    must be between the SCADA and the LTN", because a cloud operator can
    fake liveness and "an offline SCADA means the contract is broken".
  - `explorations/liveness-and-sla.md` "Two heartbeat layers — keep them
    separate" (transport ping vs contract-tier) and "Is application-level
    SCADA↔LTN heartbeating sound? — Yes, conditionally".
  - `research/findings.md` F-008 (Joe's unpublished `heartbeat.a/001`
    that deleted the hex pair; decision "Do NOT rename MyHex→SuHex", the
    names are sender-relative) and F-009 (`MyDigit` "is too weak to be
    umpire-grade", a single decimal digit; the hex echo plus signing is
    the umpire-grade path).
  - `wiki/designs/proactor-makeover.md` (OPS-428): echoing the peer's hex
    "is a strong proof that, at the application level, the message was
    fully received"; the makeover "may extend `heartbeat.a` or coin a new
    versioned word"; `harden-mqtt-half-open.md` defers "the scada↔LTN
    heartbeat" to it.
  - `gridworks-ltn/designs/stand-up-ltn-on-gwbase.md`: the contract-tier
    heartbeat rides the gwbase LTN's `gw` envelope.
  - Vision (`transactive-grid.md`): "price and weather move through the
    system as a shared heartbeat", a different sense of the word.
- **`SendLayout` fails on a Nolan layout (found 2026-09-05, run 4 log
  23:03:32):** `Trouble with SendLayout: 'NoneType' object has no
  attribute 'component'`. Same family as the `control_capabilities`
  House0-node lookup in `admin-for-nolan.md`; find the node it assumes.
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

