# pico-overhaul (design)

Status: Draft · Pass 0 · Updated 2026-09-22 · Linear: OPS-402

**EDD: yes** the bench harness is the verification: a PicoW and a Wiznet
pico on a relay-cut rail with a scripted listener in the scada's place.
Firmware passes its harness scenarios on both boards before it goes to a
house (`experiments/future/pico-bench-harness/`).

**▶ Active spoke: this file, "Build order".**

> What this is: the short list of what `gridworks-pico` still needs before
> the heating season. What is settled and built (platform, flash-write
> discipline, self-reconnect, `net.py`, hardware identity, the provisioner
> generator) is in the executor hub (`../executor/primary.md`).

## Where the code stands

`main` at `6a713e1` is the current firmware: `td/pico-easy-fixes` with
the params retry, merged 2026-09-22. `jm/pico-overhaul` is gone; all of
it was carried onto that branch. Spruce runs earlier builds of the same
line: four tank picos took one on 2026-09-09, and pipes1 and the four
BTU picos took the single-file builds at `0ca8a2f` on 2026-09-15
(`experiments/2026-09-19-spruce-pico-params/`). The `main` build goes
to spruce at the next site visit, with the three-cycle params check in
the executor's Open list.

In-field code download is used this year and retired before scaling, so
nothing here hardens it or builds on it.

## Build order

**Do this next:** step 1.

1. **The harness start**: OPS-554 (the params retry, OPS-553, is on `main`).
2. **Sensor fault reporting**: OPS-556, verified by its pulled-lead
   harness scenario.
3. **A pico says what code it runs** (below).
4. **Small fixes** (below).
5. **Provisioning** (below).

## A pico says what code it runs

Nothing a pico sends says which `gridworks-pico` code it runs. On
2026-09-19 it took a field experiment and a read of the update server's
folder to learn that spruce ran two different unmerged builds.

- Each module source holds `FirmwareCommit = "unstamped"`, and the tracked
  sources never hold anything else. `provisioner_generator.py` substitutes
  the value into the text it embeds in `provisioner.py`, and into the
  single-file builds it writes to a gitignored `build/` folder for this
  year's code download. `provisioner.py` and the `*_no_net.py` copies are
  build outputs and leave the tree.
- The value is the full 40-hex commit, with `-dirty` appended when
  `net.py`, `tank_module/` or `btu_meter/` differ from that commit.
  `unstamped` is the only other value, and it marks a file that did not
  come through the generator.
- The generator refuses to write `build/` from a dirty tree unless passed
  a flag; those files go to houses.
- The pico sends the value in its params post beside
  `MicropythonVersion`, and the scada tracks it the same way.
- Sema: a format for the value, new versions of `tank.module.params` and
  `async.btu.params` (both published) and an in-place edit of
  `flow.hall.params` (staging), under the sema vocabulary protocol. The
  gwsproto twins follow.

**Done-when:** harness scenario "identity": a bench pico's params post
carries the commit the generator stamped, in a registered word, on both
boards; a module file copied by hand posts `unstamped`.

## Small fixes

- `needs_reconnect` is cleared before the reconnect attempt and not set
  again when the attempt fails, so the next try waits for a readings post
  to fail. Set it again on failure, tank and BTU.
- `HttpClient.post` collects garbage outside its `finally`; move it in, as
  `post_fire_and_forget` has it.
- Remove the dead `BackupUrl` key from both sample `comms_config.json`
  files.
- Remove `boot.py`'s `main_revert.py` branch; nothing writes that file.

## Provisioning

Three houses are provisioned in Millinocket this fall.

- The generator's prompt offers WiFi only for a new pico; today its
  ethernet branch still writes `"WifiOrEthernet": "ethernet"`.
- `README.md` gets one "blank pico to reporting module" page in place of
  the Wiznet firmware walk-through. The page says the scada's address on
  the pico network is fixed and `BaseUrl` is that address.

**Done-when:** a person who has never provisioned a pico takes a blank
board to a reporting module by following one page, with one provisioner.

## Field updates this year

Only a build that passed the harness on both boards goes to a house; the
first pico is confirmed by its params post (commit) and its readings
before the rest are cycled; pico, commit and time go in the house's record
the same day.

## Not now

Each becomes its own issue if the field asks for it.

- A bound on a stuck post (`urequests.post` has no timeout and none would
  hold on Wiznet): a `machine.WDT` fed by the main loop, or a raw-socket
  client on PicoW. The scada's rail cycle covers it meanwhile.
- Measuring the connect timeout and reconnect cooldown
  (`experiments/future/pico-rejoin/`), aimed at the spruce secondary flow
  pico's 13 to 14 minute rejoin.
- Harness scenarios beyond OPS-554 and OPS-556: soak (100 hard rail
  cycles), AP dropped, silent server.
- A length check on the downloaded body, the listener acknowledging on
  evidence, a `boot.py` fallback to `main_previous.py`. All serve code
  download.
- ADC supply voltage as measured or configured, and integer ADC math in
  the BTU meter.
- The layout half of hardware identity (waits for OPS-392 and OPS-407).
