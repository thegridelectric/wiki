# Harden dfr i2c recovery

Status: Draft · Pass 0 · Updated 2026-06-22 · Linear: OPS-59

**EDD: yes** confidence comes from a fault-injection experiment (a mock
`smbus2` that goes dead mid-run) showing the bus self-recovers rather than the
actor dying; not from code reading.

> What this is: harden the dfr (DFRobot 0-10V DAC) i2c path against bus failure
> — the OPS-56 Elm mode where an undervoltage wedges the i2c bus and the actor
> dies with no recovery. **Minimal Draft** — intent + the gate, depth deferred.

## Gate

**Gated by the scada i2c-bus rework (tracked in Linear).** The hardening targets
the *new* i2c model, not today's per-actor `smbus2.SMBus(1)` code: all i2c is
routed through the central `I2cBus` actor
(`gw_spaceheat/actors/i2c_bus.py`) using the gwsproto i2c language
(`i2c_write_bit` / `i2c_read_bit` / `i2c_result`). Do this hardening **at the
same time as the dfr→I2cBus port** — recovery belongs in `I2cBus` (one
serialized executor, benefiting relays + dfr at once), not bolted onto code
that's about to be deleted.

`I2cBus` is **not yet fully fleshed out** — today it has only bit-level verbs
(for relays); it has no recovery loop and no word-level ops. The dfr DAC needs
**word** writes (`write_word_data`), so the port also requires extending the
i2c language with a word verb. All of that lands in / after the i2c-bus rework;
keep this design thin until then.

## Problem (verified against code 2026-06-22)

- `i2c_zero_ten_multiplexer.py` `__init__` L61-71 raises on any startup i2c
  failure → actor dies, all DAC/pump control lost, no recovery (and re-`raise`s
  drop the cause). `I2cBus.__init__` already does the right thing instead
  (degrade to `i2c=None` + a `Glitch`).
- Recovery can't heal a *wedged* bus: `set_level` flips `resend_dfr=True` and
  `maintain_dfr_states` retries every ~2 s, but only ever rewrites to the same
  dead `self.bus` — nothing re-creates `smbus2.SMBus(1)` or re-runs
  `initialize_range`. (The issue's "~5 min" was the periodic refresh; the real
  gap is bus-not-rebuilt.) The watchdog keeps getting patted while the bus is
  dead, so it won't force a restart either.

## Open

- **Recovery shape** in `I2cBus`: detect wedged bus → rebuild `SMBus(1)` →
  re-init → resume; vs. stop patting the watchdog and let the proactor
  kill+restart the bus actor. Decide once `I2cBus` is fleshed out.
- **Word verb** in the gwsproto i2c language for the DAC (range-set +
  level-set). Shape TBD with the dfr→I2cBus port.
- **Fix-while-here correctness bugs** (carry into the port, where the dispatch
  path may move): `i2c_zero_ten_multiplexer.process_message` L205-215 returns
  `Err` even on a handled dispatch; `zero_ten_outputer.process_analog_dispatch`
  L29-34 logs "ignoring" but is missing `return` on AboutName-mismatch and
  Value-out-of-range, so it forwards anyway.
- **Scope split:** does the dfr→I2cBus port live in the i2c-bus rework and this
  design own only the recovery hardening, or does this own both? — ask.

## EDD experiment (when unblocked)

Inject an `smbus2` stub that succeeds, then starts raising mid-run (the wedge),
then recovers. Assert `I2cBus` degrades (no crash), rebuilds, and resumes
driving the dfr to its last commanded level — the re-runnable reproducer behind
the eventual `Verified` stamp.
