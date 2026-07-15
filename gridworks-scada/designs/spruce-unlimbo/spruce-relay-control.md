# Spruce relay control — chunk A execution (spoke)

Status: Draft · Pass 0 · Updated 2026-07-15 · Linear: OPS-392

> What this is: spruce-unlimbo spoke — get the scada actuating spruce's i2c relays (the
> near-term goal now that the monobloc provides the AC). Opens with a code-state survey of
> `jm/spruce-unlimbo` (2026-07-15, single-pass agent read — spot-check file:line pins before
> building on a specific one) and the smallest path it implies.

## ▶ Next move (active spoke)

**The first control behavior is the secondary-pump envelope (George's ask):** stop running the
secondary pump continuously; run it as an envelope around when the heat pump is on. Gate: it
does not ship until there is a **wired** HP-running detection — today the only HP-running
signal is flow read over a **wifi pico**, which is not a control-grade input. So the ordered
front of this spoke is: (1) settle the **wired HP-on detection** (options below — needs JM/
field decision); (2) **the fork** (extend the gw108 path vs pull the pass-two thin relay
components forward); (3) **the deploy path** — spruce runs `actual-spruce`
(= `td/orig-pred-set`, 2026-05-26); the relay work lands on `jm/spruce-unlimbo` per the branch
discipline, so either spruce upgrades to it (98 commits, and the pile needs its ops artifact
placed per the `82caac3e` deploy note) or an interim rides the old line. Then the build steps,
bringing each relay up **through admin first** (`admin-for-nolan.md` — a human operates every
new actuator before any control state does).

### Wired HP-on detection — the options (open)

- **George's temporary CT line (planned):** a CT reading the **Samsung monobloc indoor
  (control) box feed** — which essentially powers the primary pump. Channel naming: name the
  metered circuit, not the proxy — node `hp-ctrl-box`, channel `hp-ctrl-box-pwr` (NOT
  `primary-pump-pwr`; the ≈-primary-pump reading is an interpretation, notable but not the
  name). Caveat for the envelope: this senses the *indoor* feed (pump/box), not the
  compressor — it serves as HP-on only if the box runs the pump only during HP operation
  (itself an FSV pump-control setting; verify before leaning on it).
- **CT inputs on the gw108** — four CT channels on the ADS1115 at `0x48` (`ct1`–`ct4`).
  Earlier attempt failed with a **voltage-out (eGauge-type) CT; try a current-out CT** while
  George is on site.
- **The eGauge line run** — the metering lines from the eGauge across the garage roof to the
  TOU sub-panel have not been run; there is **no power metering for the heat pump** today.
  The run is the real fix (the layout's `hp-odu-pwr` channels and the transactive boundary
  want it), but it is physical work on its own schedule — the envelope should not wait on it
  if a CT can serve.
- **A status contact from the monobloc** — if the unit exposes a run/status output, it reads
  into a spare wired input. Check the control-kit manual.
- Interim note, stated not endorsed: an envelope whose no-signal/stale-signal default is
  **pump ON** fails to today's behavior — a flapping wifi source would cost only the savings,
  not safety. The flap risk is pump short-cycling, so it would still need hysteresis +
  minimum-run times; the wired signal remains the bar for shipping.

### Open investigation — the HP dry contact regression

`set_hp_dry_contact(1)` (with `set_secondary_pump(1)`) does **not** start the heat pump today;
George is fairly sure the contact DID start it **before SmartThings provisioning** (the test
was run after clearing the SmartThings schedule from the indoor box). Hypothesis: pairing
SmartThings flipped the unit's demand/control source in the FSV field settings so the external
contact input is ignored. Test path: get the control-kit install manual into the product-info
folder, read the external-control FSV group on the wired remote, retest with SmartThings
unpaired if feasible. If confirmed, record the lesson: SmartThings and contact control may be
mutually exclusive on this unit.

### HP make/model tracking (proposed, decision with JM — hardware-layout territory)

`gwsproto.enums.HpModel` (4 values, never sema-registered) rides `ScadaSettings.hp_model`
with a silent default (`config.py:58`, `# TODO: move to layout`); consumers branch control
behavior on it. Proposal: retire `hp.model` into the device-type model — mint
`gw1.device.type` values per real model (nameplate-grounded; the monobloc joins from George's
photos) + a specialized `hp.device.type.gt` record family (nameplate kW, refrigerant,
modulation, defrost) that also absorbs `HpMaxKwEl`; the layout carries it (rewiring test —
the operational-params carve-out already settled layout-not-ops). Open sub-choice: thin hp
component on the `hp-odu` node vs a hydronic-block field. Product-info artifacts (nameplate
photos, manuals) live in the team Drive folder; the record holds the machine-readable facts;
wiki holds pointers only. Executes under hardware-layout-pass-one when it resumes.

### While George is on site (field task list)

1. Photograph the nameplates — **outdoor monobloc AND the indoor control box** (settles the
   model designation; the Drive folder name needs correcting to the nameplate truth).
2. Run the temporary CT line on the indoor-box feed.
3. Try a **current-out** CT on the gw108 CT inputs (the voltage-out eGauge-type failed).
4. If time: the dry-contact FSV investigation above.

## Field state — spruce itself (read-only look, 2026-07-15)

- **What runs:** `gws run` (the scada, `~/gridworks-scada` on branch **`actual-spruce` @
  `3c100867`** = `td/orig-pred-set`, up since Jul 08) — it cycles the VDC relay; an
  **interactive `python -i gw108_test_code.py`** session (Jul 08, the manual actuation
  surface); and `nolan_air.py` in the tmux monitor session, a **passive MQTT snapshot
  monitor** printing buffer-depth1 / zone3-upstairs-gw-temp / dist-swt — it does not actuate.
  So AC operation today = scada VDC cycling + hand actuation through the interactive session.
- **Proven by hand from the starter scripts:** the secondary pump, the store pump, and all
  the zone relays actuate. The **HP dry contact is connected to the heat pump but does
  nothing** — not a control lever today. The established starter-scripts pattern is a simple
  script that reads snapshots off local MQTT and actuates over i2c — the hand-run shape of
  the envelope behavior this spoke automates.
- **The wiring map exists: `starter-scripts/gw108_test_code.py`** (local repo
  `~/GridWorks/starter-scripts/`, live copy on spruce). Two TCA9555 expanders on i2c bus 1 at
  fixed addresses **0x20 / 0x21**, output registers 2 and 3, every relay named:
  - `0x20` reg 2 bits 0–5: **zone failsafe** relays (zones 1–6); reg 3 bits 0–5: **zone
    scada** relays (zones 1–6).
  - `0x21` reg 2: bit0 **hp dry contact**, bit1/bit2 **buffer tank upper/lower elements**,
    bit3 boiler-buffer valve, bit4 boiler intercept, bit5/6 misc relays, bit7 **primary pump**.
  - `0x21` reg 3: bit0 fcm misc, bit1 iso-valve failsafe, bit2 iso valve, bit3 discharge
    valve, bit4 **store pump**, bit5 **secondary pump**, bit6/7 **store tank upper/lower**.
  - Native GPIO: **6 zone opto inputs** (BCM 17, 27, 22, 10, 9, 11 — the June survey said 4)
    + shutdown 18; outputs tstat-pwr 4, 5VDC 23 (the vdc relay; off = HIGH, inverted),
    watchdog 24, poweroff 25. Plus ADS1115 at 0x48 (CTs) / 0x49 (thermistors) and three
    MCP4728 DACs behind a TCA9548A mux (per-zone + primary/secondary/store 0-10V).
  - Its `set_tca9555_bit` is exactly the bit read-modify-write `I2cBus._handle_write_bit`
    implements — the script is the hand-run version of the actor path we're wiring.
  - **The gw108 board record already matches the field:** `scada_gw108.py` declares expander
    1/2 at `0x20`/`0x21` on bus 1 (ADCs `0x48`/`0x49`, DAC `0x60`) with per-relay
    expander-relative entries. The board side is encoded; what the layout must add is the
    house semantics — which load sits on which relay position.
- Flag: the monitor script carries the local broker's credentials in plaintext on the pi —
  fine for the LAN bring-up posture, worth a sweep before anything faces outward.

## What the survey found — works today

- **Nolan boots cleanly on the branch.** The layout loads *as* `House0Layout`
  (`Strategy="Nolan"`); no isinstance/command-tree gate blocks it; `tests/conftest.py` pins
  `nolan-layout.json` + its per-home ops fixture, so the whole suite runs against nolan. The
  old `H0N.relay_multiplexer` crash is gone — the lookup returns `None` and the krida-only
  branch is never reached on a gw108 layout.
- **Exactly one relay is scada-actuatable at spruce: `vdc-relay-gpio-23`** (the 5VDC bus /
  pico-cycler relay, gw108 GPIO pin 23). Its path is complete: command → `Relay` actor →
  `_gpio_actuate_and_report` → `RPi.GPIO`, synchronous `FsmFullReport`, clean `is_simulated`
  stub. This matches the June finding — it is still the only nolan relay under scada control.
- **`I2cBus` is a complete executor** (`actors/i2c_bus.py`): serialized `smbus2` bit
  read-modify-write consuming `I2cWriteBit`/`I2cReadBit`, replying `I2cResult`, sim stubs in
  place.
- Branch geography: `jm/spruce-unlimbo` is 98 ahead / 0 behind dev; `origin/td/orig-pred-set`
  still exists (tip `3c100867`, the May line spruce has been running).

## What's missing — the gap list

1. **No i2c relays in the nolan layout.** `add_nolan_relays` emits only the vdc GPIO relay;
   there are no relay ShNodes for HP / fan coils / elements / HX pump (`layout_gen/relay.py:646`
   docstring says exactly this: "will be added when their i2c driver is written"). `hp-odu`,
   `hp-idu`, `store-pump` exist only as `NoActor` nodes + power channels.
2. **`I2cRelayBoard` is a skeleton** (`actors/i2c_relay_board.py`, ~85 lines): no
   `process_message`, no actuation, never builds an `I2cWriteBit`.
3. **Nothing produces `I2cWriteBit`** anywhere in app code — `I2cBus` is an orphan consumer;
   the gw108-i2c write path is not connected end to end.
4. **`I2cBus` / `I2cRelayBoard` are not registered** in `actors/__init__.py`, so a layout
   referencing those ActorClasses cannot instantiate.
5. **`relay.py` has no gw108-i2c branch** — its only i2c path targets the legacy krida
   multiplexer (whose `FsmAtomicReport` return, `relay.py:310-314`, is still commented out;
   that re-enable matters for House0/krida FSM reporting, not for spruce).

## The fork — two ways to wire the write path

- **(a) Extend the gw108 path minimally:** a gw108-i2c relay component in the existing
  component family + a `relay.py` branch (or a fleshed-out `I2cRelayBoard`) that translates
  relay pin events into `I2cWriteBit` toward `I2cBus` and consumes `I2cResult` back to the
  boss. Smallest diff; stays in today's dc shape (pass-one keeps the current component
  decomposition).
- **(b) Pull the pass-two thin relay components forward:** the sema vocabulary is already
  authored and waiting (`i2c.relay.component.gt/000` + `relay.control.config/000`, the
  `i2c.*.capability` + `i2c.expander` board words — hardware-layout-pass-one
  `i2c-board-components.md`). Aligned with where the model is going (board as single source of
  physical truth), but it drags gwsproto type work and layout migration into the AC window.

Leaning (a) for the window, with the `I2cWriteBit → I2cBus → I2cResult` message shape chosen so
(b)'s later migration keeps it — but this is the decision to make with JM before coding.

## Build steps (draft — after the two inputs land)

1. Layout: gw108-i2c relay component + relay ShNodes for the spruce loads in
   `add_nolan_relays`; regenerate the nolan fixture (`layout_gen/genlayout.py`).
2. Actor: the i2c write path (fork decision) — relay pin event → `I2cWriteBit` → `I2cBus` →
   `I2cResult` → report to boss. Register `I2cBus` (+ board actor if used) in
   `actors/__init__.py`.
3. Sim-boot the nolan layout with the new relays (`is_simulated` stubs exist on both `I2cBus`
   handlers); suite green.
4. On spruce hardware: exercise each relay by hand **through admin** (gwa against the nolan
   scada — also the first data for `admin-for-nolan.md`'s open "does admin render nolan?"
   question).
5. The AC shape (off-peak + afternoon-shoulder pre-cool) as operated practice via admin first;
   control-state automation rides chunk D / the capability surface, not this spoke.

## Provenance

Read-only agent survey of `jm/spruce-unlimbo` (2026-07-15) + the June-10 both-cases survey.
Key pins to re-verify when building: `relay.py:196-282` (dispatch + both paths),
`i2c_relay_multiplexer.py:191-210` (pins from the krida record), `i2c_bus.py:70-144`
(bit read-modify-write), `layout_gen/relay.py:646-649` (nolan relay scope),
`actors/__init__.py` (registry).
