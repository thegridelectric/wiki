# firmware-patch (design)

Status: Draft · Pass 0 · Updated 2026-09-21 · Linear: OPS-553

**EDD: yes** a power cycle of a real pico rail is the verification: every
live pico posts its params after every boot
(`experiments/2026-09-19-spruce-pico-params/` is the before picture).

> What this is: a small patch to the pico firmware on `td/pico-easy-fixes`
> so a pico always sends its params to the scada, then the analysis from
> the 2026-09-19 spruce experiment that found the problem.

## The problem

The firmware on `td/pico-easy-fixes` often does not send its params to the
scada after a boot.

1. `start()` tries to connect for 10 s (`CONNECT_TIMEOUT_S`). When the
   link is not up by then it gives up, sets `needs_reconnect`, and carries
   on. That timeout is right and stays: it cured a real hang.
2. The next thing `start()` does is call `update_app_config()`, once. With
   no link the post fails, and `update_app_config()` returns without a
   word.
3. `main_loop()` reconnects a few seconds later and readings flow
   normally. Nothing calls `update_app_config()` again.

So on any boot where the link takes longer than 10 s, the scada never
gets that pico's params. The params post is the only place the scada
checks the pico's identity (board variant, MicroPython version) and sends
back the capture settings the layout wants, so the pico runs unchecked on
whatever settings it booted with until its next boot. At spruce this
happens on about half of all boots.

## The change: `update_app_config()` is retried from `main_loop()`

**`update_app_config()` needs to change**, with a few lines in `start()`
and `main_loop()` to call it again until the scada has answered. The same
change goes in four files (line numbers at `0ca8a2f`):

| file | `update_app_config` | `main_loop` | `start` |
|---|---|---|---|
| `tank_module/tank_module_3_main_no_net.py` | 331 | 462 | 484 |
| `tank_module/tank_module_3_main.py` | 200 | 331 | 353 |
| `btu_meter/async_btu_main_no_net.py` | 384 | 844 | 866 |
| `btu_meter/async_btu_main.py` | 253 | 713 | 735 |

**1. `update_app_config()` returns whether the scada answered, and takes a
`late` flag.** Everything not shown stays as it is.

```python
def update_app_config(self, late=False):
    current = self.current_tank_module_params()   # BTU: current_async_btu_params()
    status, updated_config = self.http.post(...)  # unchanged
    if status is None:                            # BTU has this line; add it to tank
        self.needs_reconnect = True
    if status != 200 or not updated_config:
        return False                              # was: return

    changed = any(...)                            # unchanged, PARAM_KEYS only
    if not changed:
        return True                               # was: return

    new_config = {...}                            # unchanged
    self.save_app_config(new_config)              # unchanged
    if late:
        machine.reset()                           # new: boot again on the saved config
    self.load_app_config(new_config)              # unchanged
    ...                                           # unchanged (CaptureOffsetS)
    return True
```

**2. `start()` remembers the result.**

```python
self.update_code()                                # unchanged, once per boot
self.params_answered = self.update_app_config()   # was: self.update_app_config()
self.last_params_try = utime.time()
```

**3. `main_loop()` asks again until answered.** Once per pass, directly
after the existing `needs_reconnect` block. In the BTU loop it goes after
the `pending_async_check` block, so a report that is due goes first.

```python
if (not self.params_answered
        and self.link_is_up()
        and utime.time() - self.last_params_try > PARAMS_RETRY_S):
    self.last_params_try = utime.time()
    self.params_answered = self.update_app_config(late=True)
```

**4. One constant and one helper.**

```python
PARAMS_RETRY_S = 30

def link_is_up(self):
    if self.wifi_or_ethernet == 'wifi':
        return is_wifi_connected()                # net.is_wifi_connected() in the files that import net
    return is_ethernet_connected()
```

Why it is shaped this way:

- **A late answer that changes settings resets the pico.** Names, capture
  period and timers are set once, at boot (`set_names()` and the timer
  starts come after `update_app_config()` in `start()`). Saving the new
  config and resetting sets them the one way they are set today. After the
  reset the saved config matches the scada's answer, so one late answer
  costs at most one reset. A late answer with no changes writes nothing
  and resets nothing.
- **`changed` stays on `PARAM_KEYS` only.** `CaptureOffsetS` is never
  saved, so comparing it on the late path would reset the pico on every
  slow boot.
- **`update_code()` is not retried.** The update listener takes a pico's
  second `code-update` request as proof the update installed.
- **The retry is an ordinary post between readings**, through the same
  client a reading uses, only while the link reports up, and never from a
  timer callback. It adds no new way for the loop to stall.

## Test in the field

At spruce, with the patched firmware on the picos: cycle the 5 V pico
rail three times, the starter-scripts API listener in the scada's place
(the 2026-09-19 protocol). PASS: every live pico posts params after every
boot, the slow ones within about `PARAMS_RETRY_S` of their first reading,
and readings keep their cadence throughout.

## Do this next

1. Make the change above on `td/pico-easy-fixes`, in the four files.
2. Regenerate the provisioner: run `python provisioner_generator.py` and
   commit the new `provisioner.py` with the four files. The generator
   stitches `net.py`, `tank_module/tank_module_3_main.py` and
   `btu_meter/async_btu_main.py` into the one `provisioner.py`. Check:
   `grep -c params_answered provisioner.py` is not 0.
3. Merge `td/pico-easy-fixes` to `main`.
4. Get the patched files onto the spruce picos (see Open).
5. Run "Test in the field" with someone at the rail.
6. While on site: floor1's USB serial REPL and `os.listdir()` ("Other
   findings" 1).

## How we figured this out

### What was seen

Spruce, 2026-09-19, two power cycles of the 5 V pico rail with the
starter-scripts API listener on the scada's port. Eight live picos
(floor1 is dead).

| pico | cycle 1 | cycle 2 |
|---|---|---|
| buffer | params | params |
| tank1 | readings only | readings only |
| fancoil | params | readings only |
| pipes1 | readings only | params |
| primary-btu | params | params |
| secondary-btu | readings only | params |
| store-btu | readings only | readings only |
| dist-btu | readings only | params |

- Three of eight posted params in cycle 1, five of eight in cycle 2, a
  different set each time. In a scada window earlier the same day the four
  that posted were store-btu, buffer, tank1 and secondary-btu. Any pico can
  miss; it is not older firmware or a naming problem on particular picos.
- Whenever the post is sent it is right: the expected path
  (`/<name>/tank-module-params`, `/<name>/async-btu-params`), the layout's
  `ActorNodeName` and `HwUid`, a 200 back. No 404 and no unknown path in
  either run.
- A pico that skipped params also skipped `code-update` (three and three
  in cycle 1, five and five in cycle 2), and the picos that skipped were
  the slowest to reappear after power returned (15 to 16 s against 6 to
  13 s).
- Tank picos post `tank.module.params` Version `200`; BTU picos post
  `async.btu.params` Version `100`.

### Where the behaviour comes from

Every live spruce pico runs firmware from `td/pico-easy-fixes`, the branch
of the open pull request 15 against `dev` in `gridworks-pico`, put there by
two in-field updates (2026-09-09 and 2026-09-15, table under "Other
findings" 1). Two facts show it: `async.btu.params` Version `100` is sent
on that branch and on no other, and the skipped boot posts are possible
only from `dc8f1d7` on.

- On `main`, `connect_to_wifi()` loops until the link is up, with no
  timeout, so `start()` cannot reach the boot posts without WiFi. A slow
  access point delays the boot and nothing is skipped.
- `dc8f1d7` "Self-healing connectivity" (2026-09-08): `net.connect_to_wifi`
  raises after `CONNECT_TIMEOUT_S`; `start()` catches it, sets
  `needs_reconnect`, and goes on to `update_code()` and
  `update_app_config()` with no link. Both return silently on anything but
  a 200 (`tank_module/tank_module_3_main.py:183`, `:346`). The reconnect
  path later restores the link for readings and never re-runs the boot
  posts.

The mechanism is read from the code and fits the timing above; no pico
serial output was captured, so it is not yet observed directly.

Which code a pico runs can be told two ways. A pico that posts params shows
it in the word: tank `110` against `200` (which adds `PicoBoardVariant` and
`MicropythonVersion`), BTU `000` against `100`; every params post in the
experiment was `200` or `100`. A pico that delivers readings and skipped
both boot posts while the listener was answering 200 runs `dc8f1d7` or
later. Across the three boots of 2026-09-19 every pico but buffer skipped
at least once.

## Other findings from the same experiment

Not part of this patch. What a pico reports about the code it runs, the
safety of the in-field code download, and bounding a stuck HTTP post
belong to OPS-402.

1. **Why floor1 went away.** Leading cause, not yet confirmed: floor1
   fetched the update with the old firmware's `update_code`, a short or
   interrupted body was written to `main_update.py`, and `boot.py` swapped
   it in as a `main.py` that fails at import on every boot. What supports
   it, from the update server's folder on the spruce box
   (`~/starter-scripts/`, `code_uploaded/`):

   | when (ET) | pico | file |
   |---|---|---|
   | 09-09 06:40 to 12:17 | buffer, pipes1, `pico_239531`, `pico_9a7935` | tank, 15857 bytes |
   | 09-15 16:19 | pipes1 | tank `_no_net` at `0ca8a2f`, 15823 bytes (sha256 matches the repo) |
   | 09-15 16:36 staged, never acknowledged | floor1 | the same bytes as pipes1 |
   | 09-15 16:39 to 17:11 | store-btu, dist-btu, secondary-btu, primary-btu | BTU `_no_net` at `0ca8a2f`, 33274 bytes (sha256 matches) |

   - floor1 has no earlier entry, so on 09-15 it was the one pico still on
     the `main` generation of the firmware, and the only one to fetch the
     new file through that generation's `update_code`: `urequests`,
     `response.content` taken as the file whenever it does not parse as
     JSON, written straight to `main_update.py` with no temp file, then
     `machine.reset()`. pipes1 took the same bytes through the 09-09
     build's client and atomic write and came back.
   - Nothing checks the body in either generation (no length, no hash, no
     compile), and `boot.py` renames `main_update.py` to `main.py` with no
     check and no way back: its `main_revert.py` branch is dead, since no
     code writes that file. A bad `main.py` is permanent and fails before
     any network call, which matches floor1 sending nothing to the
     listener on 2026-09-19 and surviving every rail cycle unchanged.
   - Cleared: the new tank file raising on floor1's older config files
     (extra or missing keys are tolerated; a damaged `app_config.json`
     would still post as `/tank/...`), and any rewrite of
     `comms_config.json` (no tank firmware writes it).
   - A picos-rail power cycle is the only way to make a pico check for
     its update, and it cuts every pico at once, so a cycle made for one
     pico can land inside another's download or write. Whether that
     happened to floor1 is not known; nor is how the rail was cycled
     around 16:36 on 2026-09-15, or whether the listener was restarted
     then.
   - What settles it: floor1's USB serial REPL and `os.listdir()`. A short
     or broken `main.py` beside an intact `main_previous.py` confirms it;
     a board that does not answer is hardware.
   - buffer and the two picos updated only on 09-09 (tank1 and fancoil by
     elimination) run the 09-09 build, not `0ca8a2f`.
2. **A pico says what code it runs.** OPS-402. In-field firmware upgrade
   is allowed this year and retired before scaling, so the identifier
   belongs in the params words and not in `code-update`.
3. **When the flash happened.** ✅ 2026-09-15, inside a scada-down window
   from 16:09:30 to 17:21:47 ET (journal DB). floor1's last reading is
   16:09:24 ET on all six of its channels, steady and in family to the
   end. Every other spruce pico stops within seconds of it and returns
   between 17:22:06 and 17:22:12 ET, so the window hides the order in
   which the picos were flashed. The scada reports floor1
   (`pico_71156b`) `pico-just-zombied` at 17:25:06 ET and hourly in
   `pico-zombies` since. The branch head `0ca8a2f` was pushed 37 minutes
   before the window opened and adds the single-file firmware
   (`tank_module/tank_module_3_main_no_net.py`,
   `btu_meter/async_btu_main_no_net.py`); the BTU file posts
   `code-update` before params, as the picos do, so these two files at
   `0ca8a2f` are the flashed code.

