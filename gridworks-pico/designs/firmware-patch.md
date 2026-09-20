# firmware-patch (design)

Status: Draft · Pass 0 · Updated 2026-09-20 · Linear: OPS-553

**EDD: yes** a power cycle of a real pico rail with a listener in the
scada's place is the verification: every live pico posts its params on
every boot (`experiments/2026-09-19-spruce-pico-params/` is the harness and
the before picture).

> What this is: the findings from the 2026-09-19 spruce pico params
> experiment, captured as they stand, for a patch to the pico firmware's
> boot sequence, and the plan for that patch.

## The problem

A pico makes two posts at the top of `start()`, before its reading loop:
the `code-update` check and its params word (`tank.module.params`,
`async.btu.params`). It makes each once. When WiFi has not associated by
the connect timeout, both are skipped without a trace and the pico goes on
to post readings normally.

The scada checks a pico's identity (board variant, MicroPython version
against the layout) and answers with the capture settings the layout wants
only inside the params post. A pico that loses the race therefore runs
unchecked, on whatever capture settings it booted with, until its next
boot, and it never sees a pending code update either.

## What was seen

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

## Where the behaviour comes from

Every live spruce pico runs firmware from `td/pico-easy-fixes`, the branch
of the open pull request 15 against `dev` in `gridworks-pico`, put there by
two in-field updates (2026-09-09 and 2026-09-15, table under "To solve" 2).
Two facts show it: `async.btu.params` Version `100` is sent on that branch and on no
other, and the skipped boot posts are possible only from `dc8f1d7` on.

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

The timeout fixes a real hang and stays. The mechanism is read from the
code and fits the timing above; no pico serial output was captured, so it
is not yet observed directly.

Which code a pico runs can be told two ways. A pico that posts params shows
it in the word: tank `110` against `200` (which adds `PicoBoardVariant` and
`MicropythonVersion`), BTU `000` against `100`; every params post in the
experiment was `200` or `100`. A pico that delivers readings and skipped
both boot posts while the listener was answering 200 runs `dc8f1d7` or
later. Across the three boots of 2026-09-19 every pico but buffer skipped
at least once.

## To solve

1. **The boot posts.** A pico makes its params post on every boot, however
   late WiFi comes up, without holding up readings.
2. **Why floor1 went away.** Leading cause, not yet confirmed: floor1
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
     happened to floor1 is not known.
   - What settles it: floor1's USB serial REPL and `os.listdir()`. A short
     or broken `main.py` beside an intact `main_previous.py` confirms it;
     a board that does not answer is hardware.
   - buffer and the two picos updated only on 09-09 (tank1 and fancoil by
     elimination) run the 09-09 build, not `0ca8a2f`.
3. **A pico says what code it runs.** OPS-402. In-field firmware upgrade
   is allowed this year and retired before scaling, so the identifier
   belongs in the params words and not in `code-update`.
4. **When the flash happened.** ✅ 2026-09-15, inside a scada-down window
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

The patch is made on `td/pico-easy-fixes`.

## Do this next

The plan below is in its adversarial cycle at the Design scale
(`adversarial-cycle.md`). Round 1 is done and returned NOT APPROVED on a
wider plan; the plan was then cut to the params retry and the harness
start. The record is `scratch/firmware-patch/`: `plan-r1.md`, `sol-r1.md`
(12 blocking findings), `fable-r1-response.md` (each finding checked, and
the direction of the fold), `start-commit.txt`.

1. Read `adversarial-cycle.md`; check the pin in `~/.codex/config.toml`
   (`gpt-5.6-sol`, high).
2. Copy this file to `scratch/firmware-patch/plan-r2.md` and open round 2
   with Sol through the Codex plugin: a fresh thread, high effort, since
   the plan was rewritten and not just folded. The focus text names the
   code as the contract (`gridworks-pico` on `td/pico-easy-fixes`:
   `tank_module/tank_module_3_main_no_net.py`,
   `btu_meter/async_btu_main_no_net.py`, `net.py`; and
   `starter-scripts/api/common.py` `update_pico_code`), states the
   Design-scale materiality bar, asks for every finding above it, carries
   the secrets clause, and says what round 1 found and what was cut, so
   Sol attacks the new plan: the reset on a late changed answer (reset
   loops, a reset landing in a flash write, the BTU flow count across a
   reset), the retry's place in each loop, `link_is_up()` on ethernet, and
   whether the four harness scenarios can fail for the right reason.
3. Check each finding against the code, fold what holds, record
   `sol-r2.md` and `fable-r2-response.md`; at most four rounds. Report to
   the human, who holds the Pass increment.
4. Once Accepted: build the harness start in
   `experiments/future/pico-bench-harness/` on the bench (one PicoW, one
   Wiznet pico, a relay on their rail, the scripted listener), show
   scenario 1 red on `0ca8a2f`, then make the firmware change and turn the
   four scenarios green.

Carried, outside the cycle: floor1's USB console and `os.listdir()` on
site; how the rail was cycled around 16:36 on 2026-09-15, and whether the
listener was restarted then.

## Plan

One change to the firmware on `td/pico-easy-fixes`, tank and BTU, WiFi and
ethernet: the params post is retried until answered. The 10 s connect
timeout and the reconnect loop stay. What a pico reports about the code it
runs, the safety of the in-field code download, and bounding a stuck HTTP
post belong to OPS-402.

### The bench harness comes first

`gridworks-pico` has no tests, and this bug was found in the field, so it
gets a test that fails before the fix goes in. Pico code cannot be tested
off the board in a way that means anything: the behaviour that matters is
the WiFi chip's join timing and the WIZNET5K driver, which a stand-in does
not have. The test is a bench harness, and firmware passes it on one PicoW
and one Wiznet pico before it goes to a house.

The harness starts here with what this fix needs, in
`experiments/future/pico-bench-harness/`, and grows under OPS-402:

- the two bench picos on a rail the bench pi cuts with a relay;
- a listener in the scada's place that follows a script per scenario:
  answer at once, stay silent for t seconds and then answer, answer params
  with changed settings;
- a run is rail off, rail on, watch for a bounded time, then one line per
  scenario and board: PASS or FAIL, with the request log as evidence.

Scenarios for this fix, each on both boards:

1. **Late link.** The listener refuses connections for 15 s after rail on
   (longer than the connect timeout), then answers. PASS: the params post
   arrives. Red on `0ca8a2f`.
2. **Late answer with changes.** As 1, and the params answer changes
   `CapturePeriodS`. PASS: the pico resets once, posts params again, and
   reports on the new period; no second reset.
3. **Prompt link.** The listener answers from the start. PASS: one params
   post, no retry, no reset. Guards the normal boot.
4. **Never answered.** The listener answers readings and never answers
   params. PASS: readings keep their cadence for 10 minutes and a params
   attempt arrives about every 30 s.

### Params retry

Invariants:

- The first reading goes out as it does today; a params retry is made
  between readings, never in a timer callback.
- The retry makes the same kind of post a reading makes, through the same
  client, and only while the link reports connected
  (`is_wifi_connected()` or `is_ethernet_connected()`, by
  `wifi_or_ethernet`). It adds no new way for the loop to stall; bounding a
  stuck post is OPS-402's.
- Params is answered on a 200 with a body. Until then the pico asks again
  no faster than once per `PARAMS_RETRY_S` (30), for as long as it runs.
- `code-update` is asked once per boot, as today, and is never retried:
  the listener takes a pico's second `code-update` request as proof the
  update installed.
- A late answer is never applied in place. When it differs from the saved
  config it is saved (the existing write-on-change path) and the pico
  resets, so names, period, offset and timers are set the one way they are
  set today, at boot. When it does not differ nothing is written and
  nothing resets. After a reset the saved config matches the answer, so
  one late answer costs at most one reset.

```
update_app_config(late=False) -> bool:        # tank and BTU
    status, answer = post params
    if status is None: needs_reconnect = True
    if status != 200 or not answer: return False
    changed = <existing comparison, extended to CaptureOffsetS>
    if changed:
        save_app_config(new_config)           # existing atomic write
        if late: machine.reset()              # after the write has returned
        <existing in-place apply, boot path only>
    return True

start():                                      # tank and BTU
    try connect                               # unchanged
    update_code()                             # unchanged, once
    self.params_answered = self.update_app_config()
    self.last_params_try = utime.time()
    ...                                       # unchanged

main_loop(), once per pass, after the reconnect check:
    if not self.params_answered
       and link_is_up()
       and utime.time() - self.last_params_try > PARAMS_RETRY_S:
        self.last_params_try = utime.time()
        self.params_answered = self.update_app_config(late=True)
```

In the BTU loop the retry sits after the `pending_async_check` block, so a
report that is due goes first. `link_is_up()` is the one new helper. The
change is made in `tank_module_3_main.py` and `async_btu_main.py` and in
their `_no_net` copies until OPS-402 replaces the copies with a build step.

### Verification

Harness scenarios 1 to 4 green on both bench boards. Then spruce: the
2026-09-19 protocol, three rail cycles with the listener in the scada's
place, and every live pico posts params after every boot, the late ones
within `PARAMS_RETRY_S` of their first reading.

## Open

- How the patched firmware reaches the spruce picos: one more in-field
  update, or USB. floor1 needs USB either way.
- Whether the scada accepts the bodies the picos send. The listener in the
  experiment takes any path, so its 200 is not the scada's.
