# Simulated actors: relays + i2c thermistor reader

Status: Accepted · Pass 1 · Updated 2026-06-11 · Linear: OPS-40

> What this is: simulated-test-environment spoke — simulated relays and a
> simulated i2c thermistor reader so the Nolan scada runs fully locally
> (and the House0 case after it), exercising Thomas's setpoint evaluation
> in test mode. Began life as a spruce-unlimbo spoke (OPS-392), executed
> there for momentum; moved here 2026-06-11 when the simulation harness
> was elevated to the top. Still serves spruce-unlimbo's merge gate
> (testing green for both layouts).

## Live baseline (verified 2026-06-10)

`gws run` against **`gw-dev-rabbit`** (MQTT 1885, TLS off, smqPublic),
nolan layout, `SCADA_IS_SIMULATED=true`, on `jm/spruce-unlimbo`:

- **Runs.** Links connect (`gridworks_mqtt` reaches `awaiting_peer` — an
  LTN would complete the pair); per-zone `GpioSensor` actors and the
  `DerivedGenerator` run ("Preparing for a morning onpeak + afternoon
  onpeak"); LeafAlly keepalive alive.
- **First wall:** `LocalControlTouBase.main` dies at startup —
  `AttributeError: 'NoneType' object has no attribute 'handle'` — a
  House0 relay node (`H0N.*` lookup returning None on the nolan layout).
  Pin the exact node next; this is where layout-aware capability
  binding meets reality.
- Cosmetic: a stale persisted `SlowContractHeartbeat` v000 is rejected
  by the now-v001 literal and ignored loudly (old state dir, harmless).

## Scope (first increment)

1. **Simulated zone-temperature reader** standing in for
   `i2c_thermistor_reader.py`: constant **70 °F** on each zone's gw-temp
   channel, cheat-mode (no broker); value source built as a seam with a
   stubbed **broker-listen hook** for later synthetic-telemetry mode.
2. **Simulated relays**: the Gw108 GPIO path already no-ops under
   `is_simulated` (relay.py logs "Simulated relay actuation; skipping
   GPIO") — extend so simulated actuation *reports state* (FSM completes,
   relay-state channels update) instead of merely skipping, so admin and
   control states see coherent state. Krida-multiplexer sim follows for
   the House0 case.
3. **Scriptable heat-call** (sim GpioSensor square wave or direct
   injection) — required for the falling-edge setpoint eval to actually
   learn (constant 70 °F alone proves plumbing, not learning).
4. Fix/route around the LocalControl crash so the full actor set runs on
   the nolan layout locally.

House0 side reuses the existing `SimPicoTankModule` path — don't
duplicate.

## Definition of done

- `gws run` on the nolan layout reaches steady state with zero dead
  actor coroutines; derived setpoint channels emit learned values under
  a scripted heat-call.
- The same harness boots the House0 layout (sim Krida) — the merge
  gate's "both cases" at the simulated level.
- Distillate ported: simulated-test-environment design updated (scope
  items 1/4 partially delivered), durable facts to
  `executor/` (likely `running.md` + a future `simulation.md`).

## Open

- Where the sim seam lives: MakeModel-dispatch drivers (the
  `GRIDWORKS__SIMPM1` precedent, needs sema words) vs `is_simulated`
  branches in actors (no sema, less structure). First increment may use
  `is_simulated` branches and graduate to sim MakeModels at the
  simulated-test-environment level.
- Whether the relay-state reporting in (2) is the same change that
  un-comments the House0 FsmAtomicReport path (probably adjacent, not
  identical).
