# gridworks-pico — spec (primary)

Status: Draft · Pass 0 · Updated 2026-09-22

> What this is: the MicroPython firmware on the Raspberry Pi Pico W boards
> that read tank thermistors, flow meters and BTU meters in each house and
> post readings to the house scada over the LAN. It holds the platform
> choice, the flash and link rules the firmware keeps, how a pico says
> what it is, and the field facts experiments have verified; the rest is
> Open and the firmware repo (`gridworks-pico`) is the authority.

## Overview

A pico boots from on-flash config (`comms_config.json` names the link,
wifi or WIZnet ethernet, and the scada it posts to), joins the LAN, and
posts readings and a params record to the scada's HTTP endpoint. The
scada's pico-cycler actor owns recovery: a pico that stops posting is a
"zombie", and the cycler power-cycles the shared VDC bus that feeds
every pico in the house. Scada-side policy for that bus lives in the
scada spec; this hub holds what is true of the picos themselves.

## Platform

- New picos are PicoW over WiFi, building to about 20 homes. ESP32 is a
  later evaluation.
- Wiznet ethernet is rejected for new provisioning and supported while
  deployed (beech tank2 and tank3 at least). `connect_to_ethernet` stays
  in the firmware and every change is made on both link types.
- Why Wiznet is out for new boards, from the field:
  - WIZNET5K SPI operations block inside the driver and its MicroPython
    build has no HTTP call with a timeout, so a stalled post freezes the
    interpreter. Any bound on a post is made in our own code, never by a
    `timeout=` argument.
  - mDNS does not work on WIZNET5K; a Wiznet pico reaches the scada by IP
    address only.
  - The Wiznet Pico2 runs a hand-built MicroPython
    (`firmware/W5500-EVB-Pico2/`) and corrupts its filesystem: a NIC reset
    glitches USB during a flash write. PicoW field units stayed stable.

## Filesystem corruption model

A pico that "lost MicroPython" almost never did. The MicroPython firmware
sits in a raw flash region written only in BOOTSEL/UF2 mode and does not
corrupt in the field, which is why a bench reflash revives a dead pico.
What corrupts is the littlefs filesystem holding `main.py`,
`comms_config.json`, `app_config.json` and the modules: a reset or power
loss during a flash write leaves the littlefs metadata tree half-updated
and the mount fails (`OSError 84`). The damage is structural, not per
file.

Two picos were lost this way over five months (OPS-302), most likely from
a rail cycle during an `app_config.json` write at boot. Consecutive rail
cycles are the dangerous case: a second cycle can arrive while the write
started after the first is still in flight. Rail cycles are routine (the
shared 5 V bus and the pico-cycler), so the firmware assumes a write can
be interrupted at any moment.

## Flash-write discipline

1. **Atomic writes only.** Every flash write goes through
   `_atomic_write(path, data)`: write `path.tmp`, `os.sync()`,
   `os.rename`, `os.sync()`. Never `open(path, "w")` on a live file.
2. **Config is written only on an actual change.** A boot with nothing
   changed writes nothing.
3. **No hardware reset around a flash write.** No NIC reset and no
   `machine.reset()` while a write is in flight.
4. **Two write sites:** `save_app_config()` and `update_code()`'s
   `main_update.py`. Nothing writes on a timer, per loop or per boot.

Tank module and BTU meter both keep all four.

## Connectivity

`net.py` is the one networking module for the tank module and the BTU
meter: `connect_to_wifi`, `connect_to_ethernet`, the two connected
checks, and an `HttpClient` whose `post(path, payload, mode)` returns
`(status, body)` and whose `post_fire_and_forget` carries readings.

A pico recovers its own link. The first connect gives up after
`CONNECT_TIMEOUT_S` (10), a failed post sets `needs_reconnect`, and the
main loop re-runs the association no more often than
`RECONNECT_COOLDOWN_S` (30), with no reset and no flash write on that
path. A pico cannot power-cycle itself; the scada's rail cycle is the
last resort.

The params post is the one place the scada checks a pico's identity and
hands it the layout's capture settings, so it is retried until answered.
`start()` posts once after `update_code()` and keeps whether the scada
answered; `main_loop()` posts again every `PARAMS_RETRY_S` (30) while
the link reports up, until it has. A late answer that changes a
parameter is saved and the pico resets onto it, since names, capture
period and timers are set once at boot; a late answer with no change
writes nothing. `CaptureOffsetS` is never saved and never counts as a
change. `update_code()` is not retried: the update listener takes a
pico's second `code-update` request as proof the update installed.

There is no failover address. An IP-to-DNS fallback cannot work on Wiznet
(no mDNS) and would split the two link types into different behaviour,
and the scada already reports a pico that stops delivering readings. The
scada's address on the pico network is fixed instead (its own pico subnet
or a DHCP reservation on the house router), and `BaseUrl` is that address.

## Hardware identity

Which board a pico is varies independently of its `DeviceType`: a
dist-btu Wiznet Pico2 was swapped for a PicoW with the component's
`DeviceType` unchanged (OPS-240). Board variant is an instance-level
physical fact of the same kind as `PicoHwUid`.

- **`PicoBoardVariant`** (enum `pico.board.variant`):
  `PicoWiznetEth2040`, `PicoWiznetEth2350`, `PicoRaspberryWifi2040`. The
  provisioner derives it from `os.uname().machine` and writes it to
  `comms_config.json`; the stored value wins over a fresh derivation at
  run time.
- **`MicropythonVersion`** is read live (`os.uname().release`) and never
  stored on the pico.
- Both ride the params post (`tank.module.params` 200,
  `async.btu.params` 100, `flow.hall.params` 200) and both are fields on
  the three pico component words.
- Both are layout facts. A fact belongs in the hardware layout when
  changing it is a trip to the house, and a reflash costs what a board
  swap costs. The scada holds what the pico posts against what the layout
  says and reports a mismatch as a stale layout; it never writes the
  layout.

## Provisioning

`provisioner_generator.py` builds `provisioner.py` from `net.py` and the
two module sources on disk, so the provisioner cannot drift from the
modules. The generated provisioner runs on the pico from Thonny: it clears
the old files, writes `boot.py`, joins the link, posts `new.pico` with the
`HwUid`, writes `comms_config.json` and `app_config.json`, then writes
`net.py` and `main.py`.

MicroPython itself (the `.uf2`) is flashed at the bench and never over the
air. The app-code download (`update_code()` to `/code-update`) exists for
the first tens of homes and nothing durable depends on it; at scale,
provisioning is the only way code reaches a pico.

## Verified field facts

Status: Verified · Pass 0 · Updated 2026-09-02 · Reviewed 2026-08-05@5e77cee (`experiments/2026-08-03-pico-gap-analysis/`, `experiments/2026-08-05-pico-link-census/`, `experiments/2026-08-10-hp-snafu-and-pico-blackout-postmortem/`)

- **A permanently dead pico in the layout reboots every sibling.** The
  cycler shakes the shared VDC bus every 30 minutes while any zombie
  exists, so a house carrying one dead pico power-cycles all its picos
  about 48 times a day. Siblings that rejoin inside the 10-minute
  dropout floor make the shakes invisible; one that takes 13–14 minutes
  logs a "dropout" per shake. Spruce's dropout rate collapsed when the
  dead floor2 pico was removed from the layout, and fell again when
  three more wifi picos were removed, so the residual was wifi
  congestion on the herd. A dead pico is de-layouted, not left for the
  cycler to chase.
- **Link type is unobservable on the LAN.** The ethernet path brings up
  `network.WIZNET5K()` with no explicit MAC, and the driver's default
  carries no WIZnet OUI, so wired and wifi picos are indistinguishable by
  MAC prefix. Ground truth is each pico's on-flash `comms_config.json`
  (`WifiOrEthernet`); the picos do not report it and the layouts do not
  carry it. The fix is firmware self-report of link type and MAC in the
  params post, carried into the layout.
- **A VDC power-cycle cannot rescue a pico from an access point that is
  not broadcasting.** When the house router's 2.4 GHz SSID went down
  (2026-08-10) every wifi pico zombied at once and the cycler's shakes
  changed nothing; the wired side stayed up. All-wifi tank picos can
  run gapless for weeks (elm, 56 days), so wifi is not the fault, the
  AP is.

## Open

- The posting protocol: the readings posts are not sema words yet.
- Which `gridworks-pico` code a pico runs: nothing it posts says.
- A stuck post is unbounded, and the connect timeout and reconnect
  cooldown are unmeasured guesses.
- The layout side of hardware identity: no house layout carries
  `PicoBoardVariant` or `MicropythonVersion` yet.
- The open-thermistor voltage reads 3.3 V on the BTU meter and 2.97 V on
  the tank module; the ADC supply voltage is a hard-coded 3.3 V in both.
- Provisioning: one page from a blank board to a posting pico.
- The params retry is unverified in the field: three cycles of the
  spruce rail with the listener in the scada's place, PASS when every
  live pico posts params after every boot and readings keep their
  cadence (`experiments/2026-09-19-spruce-pico-params/` is the before
  picture: three of eight, then five of eight).
- floor1 at spruce has sent nothing since the 2026-09-15 in-field
  update. Leading cause, unconfirmed: a short download written straight
  to `main_update.py` by the old firmware and swapped in by `boot.py`,
  which checks nothing and has no way back (its `main_revert.py` branch
  is dead). The USB serial REPL and `os.listdir()` settle it.

## Glossary

- **zombie** — a pico the scada has not heard from within its dropout
  floor.
- **shake** — the pico-cycler's power-cycle of the house's shared VDC
  bus.
- **dropout** — a gap in a pico's readings longer than the 10-minute
  floor.
