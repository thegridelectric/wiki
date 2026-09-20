# pico-overhaul (design)

Status: Draft · Pass 0 · Updated 2026-09-20 · Linear: OPS-402

**EDD: yes** the bench harness is the verification: a PicoW and a Wiznet
pico on a relay-cut rail with a scripted listener in the scada's place.
Firmware passes every harness scenario on both boards before it goes to a
house (`experiments/future/pico-bench-harness/`).

**▶ Active spoke: this file, "Build order".**

> What this is: the one consolidating design for `gridworks-pico`: firmware
> that does not corrupt its flash, recovers its own link, says what it is
> and what code it runs, reaches a house only after passing a bench
> harness, and is provisioned by one clear path. Each section ends in a
> done-when.

## Where the code stands

The work is on `td/pico-easy-fixes`, the open pull request 15 against
`dev`. It forks from `dev` at `d35ca14`; the earlier `jm/pico-overhaul` and
`jm/design-start` work was copied into it by hand, so it is not a
descendant of either and those branches are reference only. Spruce runs
this branch: four tank picos took a build of it on 2026-09-09, and
pipes1 and the four BTU picos took the single-file builds at `0ca8a2f` on
2026-09-15 (OPS-553 holds the evidence, and the floor1 loss of that day).

| Section | State on the branch |
|---|---|
| Flash-write discipline | ✅ in the runtime; the soak is not run |
| Self-healing connectivity | ◐ works; numbers unmeasured; a stuck post is unbounded |
| Shared `net.py` | ◐ in use; failover removed; hand-inlined single-file copies |
| What code a pico runs | not started |
| Code download | ◐ atomic; accepts a short body; false acknowledge |
| Bench harness | started under OPS-553 |
| Field update process | not started |
| Pico hardware identity | ◐ firmware and params words done; layout half waits |
| Provisioning | ◐ generator is live; ethernet prompt and README stale |
| ADC / sensing | ◐ tank integer math done; supply voltage hard-coded |

## Platform decision

- **New picos are PicoW over WiFi**, building to ~20 homes. ESP32 is a
  next-summer evaluation.
- **Wiznet is rejected for new provisioning and supported while
  deployed.** Ethernet picos are still in houses (beech tank2 and tank3 at
  least), so `connect_to_ethernet` stays in the firmware, every change is
  made on both link types, and the bench harness carries a Wiznet pico.
- **Why Wiznet is out for new boards** (field-verified, January field day):
  - WIZNET5K SPI operations block inside the driver, and its MicroPython
    build has no HTTP call with a timeout: a stalled post freezes the
    interpreter. Any bound on a post is therefore made in our own code and
    never by a `timeout=` argument.
  - mDNS does not work on WIZNET5K (IP address only).
  - Pico2 with hand-built MicroPython is fragile and corrupts its
    filesystem: a NIC reset glitches USB during a flash write. PicoW field
    units stayed stable.
- The provisioner offers WiFi only for a new pico.

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

1. **Atomic writes only.** One helper, `_atomic_write(path, data)`, for
   every flash write: write `path.tmp`, `os.sync()`, `os.rename`,
   `os.sync()`. Never `open(path, "w")` on a live file.
2. **Write config only on an actual change.** The steady state is zero
   config writes; a boot with nothing changed writes nothing.
3. **Never reset hardware around a flash write.** No NIC reset and no
   `machine.reset()` while a write is in flight.
4. **Two write sites, no others:** `save_app_config()` and
   `update_code()`'s `main_update.py`. Nothing writes on a timer, per loop
   or per boot.

All four hold in the runtime on the branch, tank and BTU.

**Done-when:** harness scenario "soak": a bench pico power-cycled hard 100×
back-to-back during steady operation never fails to remount its
filesystem, and `app_config.json` is unchanged across reboots when nothing
changed. On both boards.

## Self-healing connectivity

The branch has it: the first connect gives up after `CONNECT_TIMEOUT_S`
(10), a failed post sets `needs_reconnect`, and the main loop re-runs the
association no more often than `RECONNECT_COOLDOWN_S` (30), with no reset
and no flash write on that path. The pico cannot power-cycle itself; the
scada's rail cycle stays the rare last resort, and the point is for it to
stop firing.

What is left:

- **The boot posts after a late link** are OPS-553.
- **The numbers are a guess.** `experiments/future/pico-rejoin/` times
  every `wlan.status()` transition of the join and is not yet run. It is
  aimed at the spruce pattern where, after a rail cycle, the secondary
  flow pico goes dark for a stereotyped 13 to 14 minutes, a delay set
  below the firmware (the CYW43 join retries, or DHCP under an
  all-picos-at-once rejoin). Set the timeout, the cooldown and whether it
  backs off from what that run finds.
- **A stuck post is unbounded.** `urequests.post` is called with no
  timeout, and none would hold on Wiznet. The bound is made in our own
  code. Open: a `machine.WDT` fed by the main loop (RP2040 maximum about
  8.3 s, cannot be stopped once started, and a code download must finish
  inside it or feed it), against a raw-socket client with `settimeout` on
  PicoW only. The harness scenario "silent server" decides between them on
  evidence.
- `needs_reconnect` is cleared before the attempt and not set again when
  the attempt fails; the next failed post sets it. Set it again on
  failure.

**Done-when:** harness scenarios "AP dropped for 2 minutes" and "silent
server": the pico resumes reporting on its own with no rail cycle and no
flash write, and its readings never stop for longer than the bound. On
both boards.

## Shared `net.py`

`net.py` on the branch is the one networking module, imported by
`tank_module_3_main.py` and `async_btu_main.py`: `connect_to_wifi`,
`connect_to_ethernet`, the two `is_..._connected` checks, and an
`HttpClient` whose `post(path, payload, mode)` returns `(status, body)`
(mode 0 no body, 1 parsed JSON, 2 raw bytes) and whose
`post_fire_and_forget` serves readings. `base_url` is normalised once.

What is left:

- `post` closes the response in a `finally` and collects garbage after
  it; move the `gc.collect()` into the `finally` as
  `post_fire_and_forget` has it.
- **No failover.** The IP-to-DNS failover (`BackupUrl`, its retry
  cooldown, the `baseurl.failure.alert` post) is gone from the branch and
  stays gone: it cannot work on Wiznet (no mDNS), it would split the two
  link types into different behaviour, and the scada already reports a
  pico that stops delivering readings. The scada's address is fixed
  instead, as a provisioning requirement. Remove the dead `BackupUrl` key
  from both sample `comms_config.json` files.
- **One source, one flashable file.** The in-field code download delivers
  one file, so the branch carries hand-inlined copies
  (`tank_module_3_main_no_net.py`, `async_btu_main_no_net.py`) that
  nothing keeps in step with `net.py`. A build script produces the
  single file from `net.py` plus the module source; the hand copies go,
  and the provisioner installs the built file, so a USB-provisioned pico
  and a field-updated pico run the same bytes.

**Done-when:** one implementation of each networking primitive in the
tree; the flashable file of each module is a build output; no `BackupUrl`
in the tree.

## What code a pico runs

Nothing a pico sends says which `gridworks-pico` code it runs. On
2026-09-19 it took a field experiment and a read of the update server's
folder to learn that spruce ran two different unmerged builds.

- The pico computes the SHA-256 of its application code at boot
  (`uhashlib`, 512-byte blocks) and sends it, whole, in its params word,
  beside a release name held as a constant in the file. With the
  single-file build the hash is of `main.py`; the file is the code. The
  hash cannot drift from the code and needs no tooling to be true, so it
  also identifies a hand-edited or unreleased file; the release name
  makes it readable.
- A release is a tag on `main`. The build script writes the tag into the
  release-name constant and prints the file's hash; built from a tree
  that is not at a tag, it names the build `bench`.
- It rides the params words and not `code-update`: in-field update is
  retired before scaling, and the params words are not.
- Sema: new versions of `tank.module.params` (200 is published) and
  `async.btu.params` (100 is published), with the two fields, under the
  sema vocabulary protocol; the flow params word takes them with
  OPS-549. The gwsproto twins follow. The scada carries the fields and
  checks nothing against them; the firmware keeps sending the old
  version to a scada that has no twin yet, chosen by a constant set at
  build.

**Done-when:** a bench pico's params post carries the hash the build
script printed and the release name, in a registered word, on both
boards; a hand-edited `main.py` shows a different hash.

## Code download (kept this year, removed at scale)

Two different things:

- **Firmware (MicroPython `.uf2`)** is flashed at the bench, never over
  the air, and nothing here depends on an over-the-air path.
- **App-code download** (`update_code()` to `/code-update`, served by the
  starter-scripts listener with the scada stopped) is kept for this year
  (≤ ~20 homes, while tailscale and SSH exist) and removed at the
  hundreds phase, when changes ship at provisioning. Nothing durable is
  built on it.

The least that stops a repeat of floor1 (OPS-553):

- **The body is checked before it is written.** The build script ends
  the file with a line carrying the file's byte length; `update_code()`
  writes `main_update.py` only when that line is present and the length
  matches. It needs no `Content-Length`, which the client does not
  expose. A body that fails is dropped and the pico boots on as it was.
- **The listener acknowledges on evidence.** Today it takes a pico's
  second `code-update` request as proof of install, so a failed install
  is acknowledged at the next boot. It acknowledges when that pico's
  params post carries the hash of the staged file.
- **`boot.py`** renames `main_update.py` to `main.py` with no check and
  its `main_revert.py` branch is dead, since nothing writes that file.
  Remove the dead branch. A real fallback (restore `main_previous.py`
  when the new code does not come up) needs a health check across a
  reset and reaches picos only by USB; it is a nice-to-have.
- The update is made with the scada stopped; an update path with the
  scada running is not built.

**Done-when:** harness scenario "short body": a listener that drops the
connection mid-file leaves the pico on its old `main.py`, and the
listener does not acknowledge. On both boards.

## Bench harness

Pico code cannot be tested off the board in a way that means anything:
what matters is the WiFi chip's join timing and the WIZNET5K driver. The
harness is the test suite. It starts under OPS-553 with the late-link
scenarios; this design grows it:

| Scenario | Proves |
|---|---|
| late link, late answer, prompt link, never answered | OPS-553 |
| soak: 100 hard rail cycles back-to-back | flash-write discipline |
| AP dropped for 2 minutes | reconnect |
| silent server (accepts, never answers) | the bound on a stuck post |
| short body on `code-update` | the download check |
| identity | the params word carries board, MicroPython, release, hash |

Each run ends in one line per scenario and board, PASS or FAIL, with the
request log as evidence, and is recorded under the experiments
conventions. A field bug becomes a harness scenario that fails before its
fix goes in.

**Done-when:** every scenario runs unattended from one command on the
bench pi against both boards.

## Field update process

`FIELD_UPDATE.md` in `gridworks-pico`, read before any fielded pico is
touched, and `GridWorks_CLAUDE.md` points at it:

- only a released build that passed the harness on both boards goes to a
  house;
- every file staged first; one rail cycle for the first pico, confirmed
  by its params post (release and hash) and its readings; then one for
  the rest; scada back up;
- no rail cycle while another pico's update is pending;
- pico, release, hash and time recorded the same day in the house's
  record;
- the rail-off time of `spruce_5vdc_toggle.py` is an argument, and no
  script is edited on a box.

**Done-when:** the file exists, the pointer exists, and the next field
update is made by it.

## Pico hardware identity — `PicoBoardVariant` + `MicropythonVersion`

Nothing in sema or on-device tracked which physical board a pico is — Wiznet vs PicoW vs
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
  firmware build — to prefill/verify the pick). Echoed in the params POST
  (`tank.module.params` 200, `async.btu.params` 100) so the scada flags a
  mismatch against what the layout claims and asks for a regenerated
  layout; the scada never writes the layout itself.

**`MicropythonVersion`** — a layout fact, on a wider test than rewiring:
a fact belongs in the hardware layout when changing it is a trip to the
house. Picos take no remote code download (the code-download path goes at
scale, see above), so a reflash costs what a board swap costs. The layout
carries the release the pico was provisioned with, authored in the gen like
`PicoHwUid`; the firmware reads its own live (`os.uname().release`) and
carries it in the params POST; the scada holds the two against each other
and reports a mismatch as "the layout is stale", never writing the layout.
Same field on the three pico component words, optional (a layout may not
have it recorded yet). One wrinkle for whoever fills this in:
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

## ADC / sensing correctness

- **Do not hard-code 3.3 V.** Open-thermistor reads 3.3 V on the BTU and
  2.97 V on the tank module (a low 3V3 rail or a leakage path). Name it
  `ADC_SUPPLY_V`, treat it as measured or configured, and chase the
  2.97 V as a hardware fault (measure the 3V3 pin). The tank code holds
  `ADC_REF_UV = 3_300_000`; the BTU code holds `ADC_REF_V = 3.3` and a
  second literal in `measure_ct_voltage`.
- **Integer ADC math.** Done in the tank module; the BTU meter still
  averages floats.
- No network call runs in a timer callback, in either module.

## Provisioning (one clear path)

`provisioner_generator.py` is the live tool: it builds `provisioner.py`
from the module sources on disk, so the provisioner cannot drift from the
modules. `old_provisioner.py` is archived. What is left:

- the generator's interactive ethernet branch still writes
  `"WifiOrEthernet": "ethernet"` for a new pico; new picos are WiFi;
- the provisioner installs the built single file (see "Shared `net.py`");
- the scada's address on the pico network is fixed (its own pico subnet,
  or a DHCP reservation on the house router) and `BaseUrl` is that
  address; the page says so;
- `README.md` still walks through the Wiznet firmware and has no "blank
  pico to reporting module" page.

At the hundreds phase there is no tailscale, no SSH and no code download,
so provisioning is the only way code reaches a pico.

**Done-when:** a person who has never provisioned a pico takes a blank
board to a reporting module by following one page, with one provisioner.

## Build order

**Do this next:** step 1, which lives in the OPS-553 design: finish its
adversarial review, get it Accepted, then build the harness start in
`experiments/future/pico-bench-harness/` and turn its late-link scenario
green. This design gets its own Design-scale adversarial cycle
(`adversarial-cycle.md`, review files in `scratch/pico-overhaul/`) once
OPS-553's plan is agreed; Sol's quota is spent on one design at a time.

1. OPS-553: the harness start and the params retry.
2. The build script and the single flashable file; the hand-inlined
   copies go; the provisioner installs the built file.
3. What code a pico runs: the sema versions, the firmware fields, the
   harness "identity" scenario.
4. The download check, the listener's acknowledge, the dead `boot.py`
   branch; harness "short body".
5. `FIELD_UPDATE.md` and the pointer. Pull request 15 is reviewed and
   merged after this step, and spruce is brought to the first release by
   the process.
6. Harness "soak", "AP dropped" and "silent server"; `pico-rejoin`; the
   reconnect numbers and the bound on a stuck post.
7. Provisioning: the ethernet prompt, the README page.

## Nice to have

Moved to their own issue when the build order is done:

- `boot.py` fallback to `main_previous.py` with a health check.
- ADC supply voltage and the BTU integer math.
- The layout half of pico hardware identity (waits for OPS-392 and
  OPS-407).
- A shared `common.py` beyond networking (config load and save, the loop
  skeleton).
- The scada raising a Warning for a pico that delivers readings and has
  posted no params since the scada started.

## Open

- Branches. Everything worth keeping from `jm/cleanup`,
  `jm/cleanup-offset-fix`, `jm/design-start` and `jm/pico-overhaul` is on
  `td/pico-easy-fixes` by hand copy, except `jm/pico-overhaul`'s removal
  of the ethernet path, which the platform decision reverses. Glean and
  delete, or tag and delete. `as/vortex` holds the vortex flow-meter code
  and is on no other branch.
- One long-lived branch or two. `dev` holds nothing `main` lacks; a
  release is a tag on `main`.
- The bound on a stuck post: watchdog or raw socket (see "Self-healing
  connectivity").
- The exact `os.uname().machine` strings for the PicoW and the hand-built
  Wiznet firmware are not recorded; read one of each on the bench before
  relying on the derived `PicoBoardVariant`.
- Whether any RP2040 Wiznet units (against Wiznet Pico2, RP2350) are
  still deployed, for the `PicoBoardVariant` backfill.
- Whether upstream MicroPython now has a working Ethernet stack for the
  Wiznet chip; it affects how `MicropythonVersion` reads for deployed
  units.
- `flow_module`: its own module or a `btu_meter` mode (OPS-549).
