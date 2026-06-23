# pico-overhaul (design)

Status: Draft · Pass 0 · Updated 2026-06-23 · Linear: OPS-402

**EDD: yes** the verification is a bench pico on the real broker: it survives
repeated power-cycles-during-flash-write (no FS corruption) and re-joins wifi on
its own after the AP is dropped — not code review.

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

**Done-when:** a bench pico power-cycled hard 100× during steady operation never
fails to remount its FS; `app_config.json` mtime does not change across reboots
when nothing changed.

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

**Done-when:** `tank_module` and `btu_meter` both import `net.py`; there is one
implementation of each networking primitive in the tree.

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

- [ ] **Open (not yet dug into — scope at the start of this work):** audit
  `provisioner*.py`, choose the one true path, delete the rest, and write the
  step-by-step "blank pico → deployed module" runbook.

**Done-when:** a person who has never provisioned a pico can take a blank board to
a reporting module by following one page, with one provisioner script.

## Build order (do them in this order)

1. Baseline is the **`jm/pico-overhaul`** branch (done: reset-vref + atomicity +
   BTU fix + Wiznet removed). Push it; back up `field` as `jm/field-backup`.
2. Build `net.py` to the contract above; convert `tank_module` then `btu_meter`.
3. Flash-write discipline: `_atomic_write` everywhere + config-write-on-change.
4. Self-healing reconnect.
5. ADC fixes (supply voltage, integer math, ISR cleanup).
6. Provisioning cleanup (one true provisioner + the runbook).
7. Soak test (the EDD experiment) before declaring done.

## Open

- A shared `common.py` beyond networking (config load/save, the ISR/loop
  skeleton) — likely yes; scope it once `net.py` lands.
- `flow_module` is empty — does it become its own module or a `btu_meter` mode?
- Exact reconnect timeout/backoff numbers — set them on the bench.
