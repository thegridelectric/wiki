# Krida board liveness

Status: Draft · Pass 0 · Updated 2026-10-01 · Linear: OPS-569

**EDD: yes** a fault-injection run against the relay multiplexer (a PCF8575
that does not acknowledge at startup; one that acknowledges and then goes
dead mid-run) is the verification; the fir field record is the bug report,
not the evidence.

> What this is: the scada's Krida relay path has no notion of a board that
> is absent or lost. Two defects found at fir on 2026-10-01 with board 1
> (`0x20`) off the i2c bus (GRI-8), and the small design that closes them.
> Code read on fir's checkout, `main` `0f623987`,
> `gw_spaceheat/actors/i2c_relay_multiplexer.py`.

## Problem (verified against code and the fir log, 2026-10-01)

**1. A board that does not acknowledge at startup blocks every board after
it, forever.** `initialize_boards` loops `while setup_attempts < 3 and not
setup_done`, but the probe-failure branch (`adafruit_pcf8575.PCF8575(...)`
raising "No I2C device at address") sleeps and `continue`s without
incrementing `setup_attempts`. Only the pin-setup branch counts attempts.
So the loop never exits for an absent board, the `for` over boards never
reaches board 2, and the simulated-pin fallback with its Critical glitch
never fires. Live at fir, 10:39:55 to 10:40:25 ET: 25 "Failed to get board
at 32 for board 1" lines, no "Found board" for board 2, and the
pico-cycler's first reboot dispatch answered "Relay board not initialized
yet. Ignoring dispatch". The scada ran with no relay control on either
board and told nobody.

On 09-30 the same board still acknowledged its address and failed in pin
setup instead ("Trouble initializing board 1! [Errno 5]"), which does count
attempts: three tries, then simulated pins and a Critical glitch. The two
failure shapes of one dead board take two different code paths with two
different outcomes.

**2. A board that acknowledges at startup and dies later is never
detected.** `maintain_relay_states` rewrites every pin each pass with no
error handling, and `_dispatch_relay_pin` returns an `Err` that nothing
logs or reports. The relay-state readings the scada publishes come from
`self.relay_state`, the software state, in both paths. Fir's relay readings
flowed 09-26 to 09-30 while the picos were dark from 09-26 19:30, and the
pico-cycler commanded relay 1 about 230 times a day into a bus that was,
by then or soon after, not moving the relay.

Both are the same gap OPS-452 closed for the gw108 expanders: the scada
believes its own command record and never reads the board back.

## Gate

- A board absent at startup is given up after the same bounded attempts as
  a board that fails pin setup; the remaining boards initialize; a Critical
  glitch names the board and address; its relays run as simulated pins and
  their readings say so.
- A runtime i2c failure on a pin write is caught at the write, logged once
  per board transition (alive to lost, lost to alive), and raised as a
  Critical glitch; the maintenance loop keeps running for the other board.
- The published relay state for a lost board is not the software state: a
  read-back of the port word, or an explicit "unknown", replaces it.
- Recovery: a lost board that acknowledges again is re-initialized and its
  commanded states re-asserted, as the gw108 auto-repair does.
- Local tests first (the field-bug rule): a fake PCF8575 that refuses the
  probe, and one that raises `OSError` after N writes, each with the test
  failing before the fix.

## Open

- Whether the probe and the write path share one liveness record per
  board with OPS-59's dfr path (one bus, two drivers today).
- Whether the pico-cycler should stop cycling when relay 1's board is lost,
  rather than reporting zombies hourly for four days.
