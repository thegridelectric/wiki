# starter-scripts — executor spec

Status: Draft · Pass 0 · Updated 2026-08-23

> What this is: the fast primer on the `starter-scripts` repo as it is
> used today — the hand-run and systemd-run scripts that operate the
> spruce gw108 while the scada relay port is still being built. Read
> this before touching anything on the spruce pi. Board facts
> (expander map, signal chains) live in the scada design spokes; the
> per-home field log is Linear GRI-11; experiment records are the
> `experiments` repo.

## Overview

`starter-scripts` began as provisioning and fall-back test scripts for
the GSCADA1 (the repo README is that era's human doc). Today its live
role is **spruce's summer control plane**: a systemd service
(`spruce_summer_hack.py`) owns the gw108's two TCA9555 expanders and
runs the TOU cooling schedule, and a small set of hand tools read or
restore the board. Everything runs on the spruce pi from
`~/starter-scripts` with `venv/bin/python` — the alias `st` (in
`bash_aliases_spruce`) activates that venv and `cd`s there; MQTT creds
come from `~/starter-scripts/.env` via `starter_settings.py`
(pydantic-settings; nothing hardcoded). Working branch `jm/spruce`; the
only path onto the box is commit → push → `git pull` on spruce (no
hand-copies).

## Invariants

- **One writer per expander.** `spruce-summer-hack.service` owns 0x20
  (zone holds) and 0x21 (plant relays) while it runs. Any script that
  writes either chip — a test, the interactive `gw108_test_code.py`,
  `sick_spruce.py` — runs only with the service **stopped**
  (`sudo systemctl stop spruce-summer-hack`, restart after). Two
  processes doing read-modify-write on one register clobber each other.
- **Importing `gw108_test_code.py` clears both expanders** (its import
  does clear-then-configure). The hack therefore never imports it and
  heals the clear on its next enforce pass; `spruce_hack.py` (winter
  elements) does import it.
- **Clear-then-configure on init.** TCA9555 POR leaves outputs 0xFF
  with pins Hi-Z; configuring as output before clearing would energize
  every relay at once. Every init in this repo writes regs 2,3 = 0
  before 6,7 = 0.
- **Failsafe posture = hp call open, secondary pump off.** Iso valve
  stays commanded open; zone holds (1, 2, 4 failsafe energized + scada
  relay 0) stay latched across service stops. Exit paths and field
  tools converge on this posture.
- **Readback is the input register, not the output flip-flop.** After a
  POR, output-register reads lie (flip-flops hold while pins float);
  health = config regs 6/7 == 0 and input reg == commanded.

## The spruce summer hack (`spruce_summer_hack.py`)

- Schedule: weekends HP ON; weekdays ON 00–07 / 12–16 / 20–24, OFF
  on-peak (07–12, 16–20). NOTE (2026-08-23): the Samsung is currently
  running its own internal schedule and **ignoring the hp-call
  contact**; the hack's hp-call still follows the TOU schedule.
- Per state change: iso open → DAC volts (dac2 channel_c, 65 % via the
  Grundfos UPMS 20-78 curve, never zeroed) → secondary pump relay →
  hp-call, with `STEP_PAUSE_S = 2` between steps.
- Every 300 s: detect the 0x21 POR signature (config regs nonzero,
  confirmed by a second read 0.5 s later), `AUTO_REPAIR` = re-init +
  re-assert with a CRITICAL register snapshot; drift-correct every
  relay; pin readback; semantic check of `secondary-flow` against the
  pump command; zone-opto heartbeat.
- Living-room fan-coil thermostat (zone 5 via 0x20 bit 4) is in the
  code but **disabled** since `ea9ae85` (2026-08-20).
- Log: `~/.local/state/gridworks/starter/spruce-summer-hack.log`
  (rotating). `grep "EXPANDER RESET"` is the reset history.

## Hand tools (all on the pi)

| script | writes? | purpose |
| --- | --- | --- |
| `spruce_status.py` | no | every expander register, optos, mux channel; "all healthy" line — the SessionStart hook runs it |
| `hp_state.py` | no | named relays: commanded vs pin level |
| `snap_watch.py` | no | snapshot channel ages — watch picos come back |
| `sick_spruce.py` | 0x20/0x21 | restore cooling posture by hand (hack stopped) |
| `charge_valve_test.py` | 0x21 | 2026-08-16 charge-valve leg test (superseded by on-site result, below) |
| `program_dac_eeprom.py` | DAC EEPROM | one-time power-on defaults |
| `watchdog_power_cycle.py` | GPIO (watchdog pi) | full power removal of the primary pi |
| `gw108_test_code.py` | clears both expanders on import | the authored board map; interactive use only, hack stopped |

## Field state (what is known, 2026-08-23)

- **Charge valve** (silk "DISCHARGE VALVE", 0x21 port 1 bit 3; to be
  named charge valve in scada): **energized = flow path through the
  store tank** — confirmed on site 2026-08-20. Earlier software runs
  (2026-08-16) were void: the relay was not wired to the valve. With
  the charge valve energized the secondary pump always has a path, so
  it cannot dead-head against a closed iso valve.
- **Iso valve**: energized = OPEN, fails closed (field-verified
  2026-07-16).
- **0x21 resets** (OPS-452 lineage): the 2026-08-23 relay-stress
  experiment (`experiments/2026-08-23-spruce-relay-stress/`) found the
  trigger: **energizing the iso-valve relay while fewer than two other
  0x21 coils are energized** (66 % of energizes reset it with none on,
  2 in 15 with one, 0 with two or more; the secondary-pump relay never
  resets it). The hack's start sequence clears every coil and then
  energizes iso first, alone — hence "resets within seconds of a
  service start". Command spacing is irrelevant. Software rule until
  the board is fixed: switch the iso relay only with ≥ 2 other 0x21
  coils already energized (pump → hp-call → iso at start; the store
  scripts follow it). Hack change not yet made.
- **dac3 i2c is dead** (2026-07-30); secondary speed moved to dac2
  channel_c. ADS 0x49 healthy since 07-31.
- Secondary-btu pico drops out for 13–14 min stretches; judge
  `secondary-flow` by its own read time, never receipt time.

## Glossary

- **POR signature** — TCA9555 config regs 6/7 nonzero (reverted to
  inputs): the chip lost power and came back; pins float.
- **Hold (zone)** — failsafe relay energized + scada relay 0: scada
  owns the zone and asserts no call.
- **Posture** — the set of relay states the hack converges to: cooling
  posture (iso open, pump on, call closed) or failsafe posture.

## Open

- Store charge / discharge by hand: `charge_store.py` and
  `discharge_store.py` ready for first use (uncommitted).
- Summer hack start order (pump → hp-call → iso last; skip the clear
  when healthy) — not yet changed.
- The manifold state tables live only in the two scripts' docstrings;
  the durable home is the scada executor once the relay port lands.
