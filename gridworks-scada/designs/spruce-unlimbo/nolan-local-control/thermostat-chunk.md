# thermostat-chunk (spoke)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: a spoke of the Nolan local-control design; hub
> [`primary.md`](primary.md). Graduated from unsorted 2026-09-07.

**Thermostat chunk: sim thermostat, setpoint discovery, coverage,
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
