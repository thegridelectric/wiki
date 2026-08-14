# pico-overhaul (design)

Status: Draft · Pass 0 · Updated 2026-08-13 · Linear: OPS-402

**EDD: yes** the verification is a bench pico on the real broker: it survives
repeated power-cycles-during-flash-write (no FS corruption) and re-joins wifi on
its own after the AP is dropped — not code review.

**Sequencing:** hold execution until spruce-unlimbo (OPS-392) and
hardware-layout-pass-one (OPS-407) land — the Pico hardware identity section
below authors `PicoBoardVariant` into the same in-flight tlayouts gen path
those designs are still reshaping.

> What this is: the one consolidating design for `gridworks-pico` — **needed for
> scaling, before September 2026**. The code has fractured enough that
> provisioning one more pico is confusing. This doc is written to be **built from directly**:
> every section ends in concrete do/don't and a done-when, with reference code,
> so there is little room to interpret it loosely.

## Baseline (build from this branch, nothing else)

The starting point is the **`jm/pico-overhaul`** branch (off `origin/dev @
d35ca14`). It already contains everything worth keeping — build forward from it,
do not reconstruct it:

- **reset-vref / `Pin(26, Pin.IN)`** ADC fix — already in the `d35ca14` base.
- **flash atomicity** (`tank-module-3`, cherry-picked) — the atomic config/code
  writes below.
- **BTU partial-channel sync-send** fix (cherry-picked from the deployed `field`
  line) — send the channels you have rather than dropping the whole report.
- **Wiznet removed** — the `*_wiznet` variants and the ethernet path are gone.

Avery's vortex code is deliberately **not** here (preserved on
`origin/as/vortex`). The old `net.py` "part 1" is **not** carried forward as-is —
its intent is rebuilt cleanly here (see *Shared `net.py`*); the partial version on
`origin/jm/cleanup` is reference only. The deployed `field` line is fully
superseded by this branch (push `jm/field-backup`, then `field` can go).

## Platform decision

- **PicoW over wifi for this year**, building to ~20 homes. **Wiznet is
  rejected.** ESP32 is a *next-summer* evaluation, not now.
- **Why Wiznet is out** (field-verified, Jan field day + ChatGPT analysis):
  - WIZNET5K SPI ops **block inside the driver**, and MicroPython `urequests`
    gives **no real network timeout** — a stalled HTTP call **freezes the whole
    interpreter**.
  - mDNS **does not work** on WIZNET5K (IP address only).
  - Pico2 with hand-spun MicroPython is fragile and corrupts its filesystem.
  - The deepest reason ties to *Filesystem corruption* below: a **NIC reset
    glitches USB during a flash write**, corrupting the littlefs metadata. PicoW
    field units stayed stable; Wiznet ones got bricked. ESP32 (external flash +
    robust stack) is the more field-tolerant long-term answer.
- **Consequence:** delete the `*_wiznet` module variants and the
  `connect_to_ethernet` path; wifi is the only transport. Fail fast if a
  `comms_config.json` still says `ethernet`.

## Filesystem corruption — the model everything else follows

A pico that "lost MicroPython" almost never did. The **firmware** lives in a raw
flash region written only in BOOTSEL/UF2 mode — it does not corrupt in the field,
which is why a bench reflash instantly "fixes" a dead pico. What corrupts is the
**littlefs filesystem** (where `main.py`, `comms_config.json`, `app_config.json`,
and modules live): a reset or power loss **during a flash write** leaves
littlefs's metadata tree half-updated, and the mount then fails (`OSError 84`).
`main.py` "surviving" is luck — the corruption is structural, not per-file.

Field evidence (OPS-302): two picos were lost over five months, most likely
from a reboot landing during an `app_config.json` write on boot — the
write-every-boot pattern this design retires below. The dangerous case is
specifically **consecutive** power cycles: the pico-cycler's routine bus
power-cycling means a second cycle can land mid-write again before the first
write ever finished cleanly, compounding the odds of catching littlefs
mid-update — a single isolated cycle is far less likely to hit the window.

Bus power-cycles are **routine by design** (shared 5 V bus, pico-cycler relay),
so the only safe assumption is: **a write can be interrupted at any moment.**
Everything below is in service of never corrupting the FS.

## Flash-write discipline (the spine)

1. **Atomic writes only.** Never `open(path, "w")` the live file. One helper for
   every flash write (text or binary), matching the landed `1a171de` pattern —
   `os.sync()` on both sides of the rename:

   ```python
   def _atomic_write(path, data):           # data: bytes
       tmp = path + ".tmp"
       with open(tmp, "wb") as f:
           f.write(data)
       os.sync()                            # flush littlefs before the swap
       os.rename(tmp, path)                 # atomic on littlefs
       os.sync()                            # and after
   ```

2. **Write config only on an actual change.** Today `update_app_config()` calls
   `save_app_config()` **unconditionally on every boot** — a flash write every
   power-up, which is exactly the corruption exposure. Diff first:

   ```python
   def save_app_config_if_changed(self, new_config):
       try:
           with open(APP_CONFIG_FILE) as f:
               current = ujson.load(f)
       except (OSError, ValueError):
           current = None
       if current == new_config:
           return False            # no write — the common case, protects flash
       _atomic_write(APP_CONFIG_FILE, ujson.dumps(new_config).encode())
       return True
   ```

   Config changes are **rare**; the steady state must be **zero** config writes.

3. **Never reset hardware around a flash write.** No NIC reset, no
   `machine.reset()` while a write is in flight. (The Wiznet bricking was a NIC
   reset glitching USB mid-write.)

4. **Audit every flash write.** The known write sites are `save_app_config()`
   (tank module + btu meter) and `update_code()`'s `main_update.py` write —
   there should be **no others**. Each must go through `_atomic_write` and fire
   only on a real config change or a deliberate code update — never on a timer,
   never per loop, never per boot. Grep the tree to confirm nothing else opens a
   file for writing.

**Done-when:** a bench pico power-cycled hard 100× **back-to-back** (not spaced
out — the field-realistic stressor above) during steady operation never fails
to remount its FS; `app_config.json` mtime does not change across reboots when
nothing changed.

## Self-healing connectivity (stop relying on the pico-cycler)

Today `connect_to_wifi()` does `while not wlan.isconnected(): sleep(500ms)` —
it **blocks forever**, and once up there is **no reconnect** if wifi drops; the
SCADA pico-cycler power-cycles the board to recover. Replace with
**non-blocking detect + bounded reconnect**, run from the main loop:

- On a failed post / detected drop, attempt reconnect with a **timeout and
  backoff** (e.g. 5 s connect timeout, back off to a cap), **without blocking**
  the measurement timers.
- **FS-safety rule:** reconnection MUST NOT trigger a hardware reset or any flash
  write. It only re-runs the wifi association. (This is the whole point — recover
  the link without risking the FS.)
- **Fallback is explicit, and avoids the cycler.** The pico **cannot
  power-cycle itself** — only the external SCADA pico-cycler relay can. So the
  rule is: keep retrying reconnect with a capped backoff **indefinitely**; the
  pico-cycler stays the *rare last resort* and the whole point is for it to stop
  firing. If a self-`machine.reset()` is ever added to clear a wedged network
  stack, it MUST run **only when no flash write is in flight** (per the
  flash-write rule) — a reset mid-write is the corruption we are eliminating.

**The code, not the pico-cycler, owns noticing the link is dead.**
`tank_module`'s `connect_to_wifi()` today has no reconnect at all (confirmed —
it blocks forever, as above); `btu_meter`'s `post_with_fallback()` tracks
per-request failure but has no wifi-level liveness check. Both need the
non-blocking detect + bounded reconnect above; neither should depend on the
pico-cycler to notice.

**The exact timeout/backoff numbers are not a bench guess — they're what
`experiments/future/pico-rejoin/` is built to answer.** Not yet run. It mirrors
the deployed single-connect join path and times every `wlan.status()`
transition, aimed at the field-observed pattern at spruce: after every
half-hourly VDC shake, the secondary flow pico goes dark for a stereotyped
13–14 min before reporting again. The deployed firmware issues one
`wlan.connect()` and waits forever, so that timing is set by layers *below*
the firmware — the CYW43 driver's internal join retries, or DHCP under an
all-picos-at-once rejoin herd — not by anything this design controls directly.
Running the experiment's protocol (baseline power cycles → failure injections
→ a real spruce VDC-shake capture) is this section's actual next EDD step;
set the reconnect timeout/backoff from what it finds, not a bench guess.

**Done-when:** drop the AP for 2 minutes and restore it; the pico re-joins and
resumes reporting on its own, with no power-cycle and no flash write.

## Shared `net.py` (rebuild the common module cleanly)

All modules (`tank_module`, `btu_meter`, future `flow_module`) duplicate
networking, config load/save, and code-update. Factor it into one `net.py` with
a **precise contract** — and spell out the two bugs the WIP hit so they are not
repeated:

- `post_json(endpoint, payload) -> dict | None` — returns the **parsed dict** on
  200, else `None`. **It is not a response object** — do not call `.json()` on
  it. (Bug to avoid: `updated.json()` on a dict.)
- `post_maybe_file(endpoint, payload) -> (bytes | None, is_json: bool)` — returns
  a **tuple**. `if resp:` is truthy even for `(None, False)`; always unpack:
  `content, is_json = ...; if not content: return`. (Bug to avoid: treating the
  tuple as a response.)
- Both **close the response and `gc.collect()` in a `finally`** (WIZNET-safe
  habits carry over and cost nothing on PicoW).
- **Normalize `base_url`** once at load: `self.base_url =
  comms_config["BaseUrl"].rstrip("/")`, and every endpoint starts with `/`.

**Non-negotiable: preserve what `async_btu_main.py`'s `post_with_fallback()`
already does — the simpler contract above must not silently drop it.** The
deployed btu code has real functionality worth carrying forward into `net.py`,
not reimplementing from scratch or losing:

- IP→DNS failover (`BaseUrl`/`BackupUrl`) with a retry-cooldown
  (`BASE_URL_RETRY_SECONDS`) before re-trying the primary.
- a `baseurl-failure-alert` posted to scada when IP fails over.
- 404 treated as "server reachable, wrong endpoint" (not a connectivity
  failure) vs. other statuses/exceptions treated as real failures.

`net.py` is where this gets deduplicated across `tank_module`/`btu_meter`
(today it exists only in the btu code — `tank_module` has none of it), not
where it gets dropped.

**Also strip a hidden false assumption the current code carries:** `timeout=3`
(or `5`) passed to `urequests.post` is not a real guarantee on MicroPython —
the design's own Wiznet analysis above already established there is no real
network timeout; PicoW just doesn't happen to hang the way Wiznet did. `net.py`
must not lean on `timeout=` as a correctness mechanism — the self-healing
reconnect below is what actually bounds a stuck connection.

**Done-when:** `tank_module` and `btu_meter` both import `net.py`; there is one
implementation of each networking primitive in the tree, and the IP/DNS
failover + failure-alert behavior above still works from both.

## Code download — keep now, remove at scale

Two different things, do not conflate them:

- **Firmware (MicroPython `.uf2`)** — flashed at the bench / provisioning today,
  not OTA. A robust firmware-OTA path may be worth building later; it is **out of
  scope here** and nothing in this design depends on one. For now, bench flashing
  is the baseline (and not leaning on an OTA crutch keeps code quality honest).
- **App-code download** (`update_code()` → `/code-update`) — **kept for this
  year** (≤ ~20 homes, while tailscale/SSH exist). At the hundreds-phase there is
  **no tailscale and no SSH**, and the app-code download is **removed** then too;
  changes ship at provisioning. Until then, `update_code()` must use the correct
  contract:

  ```python
  def update_code(self):
      content, is_json = self.post_maybe_file(endpoint, payload)
      if not content:
          return
      if is_json:                 # server says "no update"
          return
      _atomic_write("main_update.py", content)   # content is bytes
      machine.reset()             # the one sanctioned reset — and not during a config write
  ```

## ADC / sensing correctness

- **Do not hard-code 3.3 V.** The bench finding: open-thermistor reads 3.3 V on
  the BTU but **2.97 V on the tank module** (a low 3V3 rail or a leakage path).
  Name it `ADC_SUPPLY_V` and treat it as **measured/configured**, not assumed —
  and chase the 2.97 V as a real hardware fault (measure the 3V3 pin), don't
  calibrate it away.
- **No network calls in the timer ISR** — the ISR sets flags; the main
  loop does the I/O.
- **Integer ADC math**: replace the float/list averaging with an
  integer accumulation loop.

## Pico hardware identity — `PicoBoardVariant` + `MicropythonVersion`

**The gap (named in OPS-402 but never landed here until now):** nothing in
sema or on-device tracks which physical board a pico is — Wiznet vs PicoW vs
(eventually) ESP32. `HwUid`/`PicoHwUid` is a chip serial, identical in shape
across every variant. `DeviceType` (`GridworksTankModule3`) is deliberately
coarse — per `gw1.device.type`'s own definition, a *category*, "NOT a strict
manufacturer make+model" — and empirically wrong to fork by board anyway:
OPS-240 records a dist-btu Wiznet Pico2 swapped for a Pico W with the
component's `DeviceType` (`GridworksGw101`) unchanged — direct evidence that
board varies independently of `DeviceType`. OPS-265 separately confirms a
third board variant, a Wiznet Pico (RP2040, "not Pico 2"), was deployed at
Fir's tank3 — so all three variants this design tracks have real fleet
history, even though only the dist-btu case is confirmed as an in-place swap.
Board variant is an **instance-level physical fact**, the same shape as
`PicoHwUid` already on the component, not a category split.

**`PicoBoardVariant`** — a new sibling enum (`DeviceType` stays untouched),
values `PicoWiznetEth2040` / `PicoWiznetEth2350` / `PicoRaspberryWifi2040`
(room for an `Esp32...` value next summer — likely its own field name, since
ESP32 isn't a Pico-family board at all). New field on
`pico.tank.module.component.gt`, `pico.flow.module.component.gt`,
`pico.btu.meter.component.gt` — all three are `staging` today, so this lands
without a version bump.

- **Fails the rewiring test the "layout" way.** Physically swapping a pico's
  board is exactly the kind of change the hardware-layout-pass-one design
  (OPS-407, in progress) already carves out for device nameplate facts
  (`hp_model`, `hp_max_kw_el`: "a few config fields go to the LAYOUT... because
  swapping them IS rewiring"). `PicoBoardVariant`
  belongs the same place: on the component's `.gt` instance, in the static
  hardware-layout artifact, authored the same way `PicoHwUid` already is —
  hand-typed into each house's layout-gen at layout-authoring time (the
  sema-native `tlayouts/gen_<house>_sema.py` pass-one is mid-migrating to; the
  legacy `gen_<house>.py` path is the fallback while that lands).
- **Local storage / provisioning:** the provisioner writes it to
  `comms_config.json` at provisioning time (operator picks one of the three,
  or the provisioner reads `os.uname().machine` — which differs by board
  firmware build — to prefill/verify the pick). Optionally echoed in the
  params POST so scada can flag a mismatch against what the layout claims —
  catches an undocumented field swap without waiting for the next layout
  regen.

**`MicropythonVersion`** — the opposite side of the rewiring test: reflashing
a board's firmware needs no rewiring, so per that same discriminator this is
explicitly **not** a layout fact. It doesn't fit
operational-params either (not a tuning knob) — it's runtime telemetry, full
stop. Read live each report (`sys.implementation.version` /
`os.uname().version`) and carried in the params POST; never persisted to
flash, never authored into any of the three artifacts (deployment config /
hardware layout / operational params). One wrinkle for whoever fills this in:
the Wiznet Ethernet build was a **hand-compiled custom firmware**
(`gridworks-pico/firmware/W5500-EVB-Pico2/`, `Wiz-Pico2_2aaf30.uf2`) because
stock MicroPython had no working Ethernet stack for that chip at build time —
`sys.implementation.version` may not be a meaningful string for that variant;
worth checking whether upstream MicroPython now supports it before assuming
the stock value is enough. Moot for new provisioning (Wiznet is rejected
above) but matters for reading historical/still-deployed units.

**Sema scope — register the params payload for real.** `tank.module.params`
(and the btu/flow equivalents) is a hand-built dict today
(`current_tank_module_params()`, bare `TypeName`/`Version` strings, never
through the sema registry) — a real gap at a pico→scada boundary. Since
`PicoBoardVariant` and `MicropythonVersion` both need to ride this payload,
this design registers it as a proper sema word (and its btu/flow siblings)
rather than adding untyped fields to the existing dict.

**Done-when:** a provisioned pico's `PicoBoardVariant` shows up correctly in
its house's generated layout; its params POST carries both `PicoBoardVariant`
(matching the layout) and a live `MicropythonVersion`; both ride a registered
sema type, not a hand-built dict.

## Provisioning — the original pain (make one clear path)

The reason this overhaul exists is that **provisioning one more pico is
confusing**: `provisioner.py`, `old_provisioner.py`, and
`provisioner_generator.py` have drifted, and it is not obvious which one is the
truth. The end state is **one documented, repeatable path** from a blank pico to
a deployed module — flash MicroPython in BOOTSEL mode → drop
`boot.py` / `main.py` / `comms_config.json` / `app_config.json` → it runs — with a
single provisioner and no dead variants.

This matters most **at scale**: with no tailscale and no SSH at the hundreds-phase
(and no app-code download), **provisioning is the only way code reaches a pico**,
so it must be solid before then.

**A first pass on the audit — not a full resolution, but a concrete starting
point:** `provisioner_generator.py` is the one that's actually live — it
derives `provisioner.py` by reading the real `tank_module_3_main.py` /
`async_btu_main.py` source off disk, so `provisioner.py` can't drift from the
deployed modules by construction. `old_provisioner.py` looks dead — hand-drifted
hardcoded ADC calibration constants, never mentioned anywhere in `README.md`'s
actual provisioning instructions. **A live bug, independent of that call:**
`provisioner_generator.py` still has a working interactive ethernet branch
that writes `"WifiOrEthernet": "ethernet"` into a new pico's
`comms_config.json` — directly contradicting the Platform-decision section
above ("wifi is the only transport... fail fast if `comms_config.json` still
says ethernet"). Fix that regardless of how the rest of the audit lands.

- [ ] **Open:** confirm `old_provisioner.py` can be deleted, strip the
  ethernet branch (+ the Wiznet firmware section of `README.md`) from the
  live path, and write the step-by-step "blank pico → deployed module"
  runbook.

**Done-when:** a person who has never provisioned a pico can take a blank board to
a reporting module by following one page, with one provisioner script.

## Build order (do them in this order)

1. ✅ Baseline is the **`jm/pico-overhaul`** branch (reset-vref + atomicity +
   BTU fix + Wiznet removed); pushed to origin. `field` backed up as
   `jm/field-backup` (also pushed).
2. Build `net.py` to the contract above (including the preserved IP/DNS
   failover + failure-alert behavior); convert `tank_module` then `btu_meter`.
3. Flash-write discipline: `_atomic_write` everywhere + config-write-on-change.
4. Self-healing reconnect — run `experiments/future/pico-rejoin/` first to set
   the actual timeout/backoff numbers, then implement against them.
5. ADC fixes (supply voltage, integer math, ISR cleanup).
6. Pico hardware identity: register `tank.module.params` (+ btu/flow
   equivalents) as sema words carrying `PicoBoardVariant` +
   `MicropythonVersion`; wire the provisioner + layout-gen to author
   `PicoBoardVariant` into the layout.
7. Provisioning cleanup (one true provisioner + the runbook).
8. Soak test (the EDD experiment) before declaring done.

## Open

- A shared `common.py` beyond networking (config load/save, the ISR/loop
  skeleton) — likely yes; scope it once `net.py` lands.
- `flow_module` doesn't exist yet (only archived `flow_hall`/`flow_reed` code
  and an `experimental/flow_simulator.py`) — does it become its own module or
  a `btu_meter` mode?
- Whether any RP2040-chip Wiznet units (vs. Wiznet Pico**2**/RP2350) are still
  deployed anywhere in the fleet, for `PicoBoardVariant` backfill — Jessica to
  check field/provisioning records.
- Whether upstream MicroPython now has a working Ethernet stack for the
  Wiznet chip (the custom build `Wiz-Pico2_2aaf30.uf2` existed because it
  didn't at build time) — moot for new provisioning since Wiznet is rejected,
  but affects how `MicropythonVersion` reads for historical units.
