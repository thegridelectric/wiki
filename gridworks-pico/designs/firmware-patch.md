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
3. **A pico says what code it runs.** Every params word carries something
   that identifies the `gridworks-pico` code on the pico. In-field
   firmware upgrade is allowed this year and retired before scaling, so
   the identifier belongs in the params words and not in `code-update`.
   The form of the identifier is open.
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

## Plan

Three changes to the firmware on `td/pico-easy-fixes`, in both the tank
and the BTU code, then the process file. The `CONNECT_TIMEOUT_S = 10`
connect and the reconnect loop stay as they are.

### 0. The local test comes first

`gridworks-pico` has no tests, and both bugs here were found in the field,
so each gets a local test that fails before its fix goes in. The missing
simulation is the first change: stand-ins for `machine`, `network`,
`urequests` and `utime` that let `TankModule3` and the BTU meter be
imported and driven under CPython, with a settable "WiFi up at t seconds"
and a scripted HTTP server side. Two tests, red on `0ca8a2f`:

- WiFi comes up after the connect timeout: the pico still posts params,
  and applies the answer.
- The `code-update` body is cut short: `main_update.py` is not written.

### A. Boot posts are retried until answered

Invariants:

- Readings never wait on a boot post. The first reading goes out as it
  does today.
- The scada serves no `code-update` path; only the starter-scripts
  listener does. So `code-update` counts as answered on any HTTP status,
  and params only on a 200 with a body. Until both are answered the pico
  keeps asking, no faster than once per `BOOT_POST_RETRY_S` (30), for as
  long as it runs.
- A params answer that arrives late is applied exactly as one at boot:
  saved on change, names reset, the report timer re-armed when
  `CapturePeriodS` changed.
- A late `code-update` answer that carries code resets the pico, as at
  boot.

```
start():
    try connect (10 s timeout)          # unchanged
    self.boot_posts_answered = self.try_boot_posts()
    set_names(); first reading; start timer; main_loop()

try_boot_posts() -> bool:
    if not self.code_update_answered:
        self.code_update_answered = self.update_code()      # True on any HTTP status
    if not self.params_answered:
        self.params_answered = self.update_app_config()     # True on 200 + body
    return self.code_update_answered and self.params_answered

main_loop(), once per pass, before the readings:
    reconnect check                                          # unchanged
    if not self.boot_posts_answered
       and not self.needs_reconnect
       and now - self.last_boot_post_try > BOOT_POST_RETRY_S:
        self.last_boot_post_try = now
        period = self.capture_period_s
        self.boot_posts_answered = self.try_boot_posts()
        if self.params_answered:
            set_names()
            if self.capture_period_s != period: start_sync_report_timer()
```

`update_code()` and `update_app_config()` return whether they were
answered; today both return `None` on every path. Each post is bounded by
the HTTP client's own timeout, so an unanswered retry costs one timeout
per 30 s and no reading is skipped for it.

### B. A pico says what code it runs

The pico computes the SHA-256 of its own `main.py` at boot (`uhashlib`,
read in 512-byte blocks) and sends the first 12 hex characters in its
params word, beside a release name held as a constant in the file. The
hash cannot drift from the code and needs no tooling to be true, so it
also identifies a hand-edited or unreleased file; the release name makes
it readable. Rejected: a hand-kept version constant alone (it drifts, as
`Version` fields already have), and reporting it in `code-update`
(in-field update is retired before scaling).

This takes a new version of each pico params word in sema
(`tank.module.params`, `async.btu.params`, and the flow params words when
those picos are next touched), authored under the sema vocabulary
protocol, and the gwsproto twin. The scada carries the two fields and
checks nothing against them in this design.

A build script produces the single flashable file from `net.py` plus the
module source, replacing the hand-inlined `_no_net.py` copies, and prints
the file's hash. A release is a tag on `main`; the script writes the tag
into the release-name constant and refuses to build from a tree that is
not at a tag unless told the build is a bench build, which it names
`bench`.

### C. The update cannot leave a pico without a main

In-field update is retired before scaling, so this is the least that
stops a repeat of floor1:

- `update_code()` writes the body only when its length equals the
  response's `Content-Length`; otherwise it drops it and the boot-post
  retry asks again.
- `boot.py` keeps the swap and gains the way back: when `main.py` fails
  to import, it restores `main_previous.py` and resets. `boot.py` is
  written at provisioning, so this reaches a fielded pico only by USB;
  picos already in the field keep the old `boot.py` and rely on the
  length check.
- The dead `main_revert.py` branch goes.

### D. The process file

The update is made with the scada stopped and the starter-scripts listener
in its place; an update path with the scada running is not built. The
process keeps the window short: every file staged first, one rail cycle
for the first pico, one for the rest, scada back up. The rail-off time of
`spruce_5vdc_toggle.py` becomes an argument, so the script is never edited
on a box.

`FIELD_UPDATE.md` in `gridworks-pico`, written once B is settled: only a
released build goes to a fielded pico; one pico first, confirmed by its
params post (release name and hash) and readings, then the rest; no rail
cycle while another pico's update is pending; pico, release, hash and time
recorded the same day; a change to a boot path is power-cycle tested with
the listener before it is released. `GridWorks_CLAUDE.md` points at it.

### Verification

The harness of `experiments/2026-09-19-spruce-pico-params/`, on a bench
rail first and then spruce: repeated rail cycles with the listener in the
scada's place, and every live pico posts `code-update` and params after
every boot, late ones within `BOOT_POST_RETRY_S` of their first reading.
For C, a listener that closes the connection mid-body: the pico keeps its
old `main.py` and asks again.

## Open

- Whether this belongs inside the consolidating pico design (OPS-402,
  which names self-heal reconnect and a common `net.py`) or ships ahead of
  it as its own patch.
- Whether the scada accepts the bodies the picos send. The listener in the
  experiment takes any path, so its 200 is not the scada's.
- How the patched firmware reaches the spruce picos: by one more in-field
  update under the process in D, or by USB. floor1 needs USB either way.
- Whether the scada-side Warning for a pico that delivers readings and has
  posted no params belongs to this design. It is scada work outside the
  two-sim-houses focus.
