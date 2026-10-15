# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-pico` code repo**. The matching git commit (in
`gridworks-pico`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-10-14 — update rreadme for pico2 firmware, publication-grade sema snapshot (`50f6efa`)

**What.** Two things in one commit. `scripts/regen_sema_snapshot.sh`
drops `--allow-staged` and the vendored snapshot is rebuilt from sema
`88fac01`, where the eight pico words are published: the staging marker,
the README banner and the staging index go, and the registry copy shows
the eight at `published`. And the W5500-EVB-Pico2 firmware README gains
the `mpremote mip install requests urequests` form of its urequests step
beside the Thonny one.

**Why.** The words the firmware speaks were promoted on 2026-10-14 after
the bench runs on all three boards, so the snapshot the test API
validates against is now publication-grade. The Pico2 bench run stalled
at `ImportError: no module named 'urequests'` on a board provisioned
without Thonny; the install from the host is one line. OPS-595.

## 2026-10-14 — Regenerate the firmware outputs (`048ff2c`)

**What.** `provisioner.py` and the two `_no_net.py` files, built by
`provisioner_generator.py` from `4ff3111`, which they are stamped with.

**Why.** The outputs name the commit they were generated from, so they
follow the sources in a commit of their own. OPS-595.

## 2026-10-14 — Deactivate the Wiznet chip before a rebuild; test API defaults to port 8765 (`4ff3111`)

**What.** An ethernet rebuild calls `active(False)` on the old
`WIZNET5K` object before dropping it and re-initing the chip, as the
wifi rebuild already does. The test API's default port moves from 8000
to 8765, in the module and the README.

**Why.** The NotFound chain on the W5500 RP2040 (MicroPython 1.26.0):
every rebuild printed `wiznet5k_send_ethernet: fatal error -5` from the
driver, a frame still in flight when the chip was re-inited; the link
came back anyway; on the Wiznet Pico2 with this change the rebuild is
silent. The chain itself ran as designed on both Wiznet boards:
self-resets at 60 and 120 s of uptime, the marker and count surviving
each reset at both chips' scratch base, the first 200 clearing them.
On the Wiznet driver `socket.settimeout` raises before and after
connect, so ethernet posts stay unbounded by design. Port 8000 is the scada's pico listener, and a bench API
on it collides with the scada tests on the same laptop. OPS-595.

## 2026-10-14 — Regenerate the firmware outputs (`4771c6e`)

**What.** `provisioner.py` and the two `_no_net.py` files, built by
`provisioner_generator.py` from `3f77beb`, which they are stamped with.

**Why.** The outputs name the commit they were generated from, so they
follow the sources in a commit of their own. OPS-595.

## 2026-10-14 — Bench findings: associate up to three times, hold data after a failure, retry params on rebuild (`3f77beb`)

**What.** A wifi connect tries up to three associations, each from
`active(False)`, before it raises. A data post
that fails holds every further data post until the next heartbeat goes
out. The params retry runs as soon as the link is rebuilt, not only every
30 s. The MicroPython stand-ins refuse a post while no NIC is connected,
as the real stack does.

**Why.** The first bench runs of the heartbeat build on a Pico W
(MicroPython 1.23.0). Starting the connect from `active(False)` was tried
first; with it, three power-on boots and three self-reset boots out of
six still timed out on the boot association, while the rebuild's
association a few seconds later came up at once every time, so a pico
reached the API 22 s after boot instead of 5. The second attempt is what
works, so the connect makes it itself; with it a boot whose first
association times out sends its heartbeat first, at 16 s. The bench pico
runs MicroPython 1.29.0 from this run on, the fleet 1.23.0; the first
association fails on both. A snapshot that failed at boot kept its sentinel and
reposted every second until a 200, which with failures counted on every
post ran the recovery chain at 1 Hz instead of on the heartbeat's 10 s
clock. And a pico that booted without a link posted data under its
default names for up to 30 s before the layout's params answer arrived.
OPS-595.

## 2026-10-14 — Regenerate the firmware outputs (`00a19cf`)

**What.** `provisioner.py` and the two `_no_net.py` files, built by
`provisioner_generator.py` from `4d8f66b`, which they are stamped with.

**Why.** The outputs name the commit they were generated from, so they
follow the sources in a commit of their own. OPS-595.

## 2026-10-14 — The pico keeps itself connected and says it is alive (`4d8f66b`)

**What.** `net.py` gains the heartbeat, the failure-counted link and the
self-reset. A `pico.heartbeat` goes every 10 s from the main loop, the
first one at boot before the code-update and params posts. Every post's
answer feeds the link: two failures in a row rebuild it, two more after
the rebuild reset the pico, with the marker in watchdog scratch 0 and the
count of self-resets in a row in scratch 1, so the next boot reports
`SelfReset` and waits a doubling uptime budget before the next one. Pico W
posts are bounded at 5 s; Wiznet posts take no timeout. The params posts
move to `async.btu.params` 110 and `tank.module.params` 210 with
`MacAddress`, `FirmwareCommit` and, on the btu meter, `ReadTemps`: a pico
is flow-only until a params answer turns the thermistors on, and the
temperature fields appear iff it does. The tank module's sync timer
starts on the capture offset instead of sleeping through it. Both mains
get a `boot()` and a `loop_once()`. `provisioner_generator.py` builds
all three outputs, `provisioner.py` and the two `_no_net.py` files, from
`net.py` and the mains, stamped with the commit; the `_no_net` files are
no longer pasted by hand. The firmware runs under pytest against the test
API through MicroPython stand-ins in `tests/micropython_stubs/`, and the
chain of section 1 of the design has its tests.

**Why.** A pico whose posts fail while the NIC says the link is up kept
failing until the scada cycled the rail, and nothing it posted said
whether it was trying, or why it had booted. Acting on the API's answer
and announcing uptime and reset cause gives the scada a 21 s silence to
record and a 71 s bound to act on, and lets a self-reset be told from a
rail cycle. The stand-ins exist so the chain fails a local test before
the firmware goes to a bench. OPS-595.

## 2026-10-14 — Every pico post decodes through the sema codec (`df64000`)

**What.** The vendored snapshot seeds the six pico words sema now has
(`multichannel.snapshot` 000, `microvolts` 100, `new.code` 100,
`new.pico` 100, `pico.heartbeat` 000 and the `pico.reset.cause` enum)
alongside the params words; the hand-typed interim models go, and the
test API validates every post through the codec. One check sits beside
the codec: an enum value the vocabulary lacks is refused rather than
decoded to the enum's default.

**Why.** The interim models existed only until the words were authored
(sema `5950c2b`). A sema decoder maps an unknown enum value to the
default on purpose, so a later vocabulary reaches an older consumer; the
bench wants the opposite, because the firmware under test posting a unit
or reset cause the vocabulary lacks is the bug it is there to catch.
OPS-595.

## 2026-10-14 — Type the snapshot's units as spaceheat.telemetry.name (`084aaf3`)

**What.** The vendored sema snapshot seeds `spaceheat.telemetry.name`
instead of `gw1.unit`; the interim `multichannel.snapshot` model types
`UnitList` with it and refuses a value outside the enum.

**Why.** The strings the firmware posts, `GpmTimes100`, `CelsiusTimes100`,
`VoltsTimes100`, are telemetry names, the enum every scada data channel
declares, not `gw1.unit` values. The first cut reached for `gw1.unit`,
which would have needed a new enum version for units sema already has.

## 2026-10-14 — Add the test API the firmware is tested against (`d3a8643`)

**What.** A laptop-side Python package, `pico_testapi`, that serves the
routes a pico posts to (`pico-heartbeat`, the two params posts,
`multichannel-snapshot`, `microvolts`, `code-update`, `new-pico`),
validates each post through a vendored sema snapshot, records what it
received, and misbehaves on command: answer 404, answer slowly, drop the
connection, go away for a set time, answer params with `ReadTemps` either
way. With it come `pyproject.toml` (uv), the seed and regen script for the
snapshot, `ci.sh`, and the first pytest suite in the repo.

**Why.** The next firmware round (heartbeat, failure-counted reconnect,
self-reset with backoff) is a chain that has to be driven end to end on
the bench without a scada or a house. Nothing in the repo ran under
pytest before, so the chain could only be checked in the field. OPS-595.

## 2026-09-22 — Retry the params post until the scada answers

**What.** In the two tank-module and two BTU-meter mains (and the
regenerated `provisioner.py`): `update_app_config()` returns whether the
scada answered and takes a `late` flag; `start()` keeps the result;
`main_loop()` posts again every `PARAMS_RETRY_S` while the link is up
until the scada has answered. A late answer that changes settings saves
the config and resets the pico. The tank module now sets
`needs_reconnect` on a failed params post, as the BTU meter already did.

**Why.** `start()` gives the link 10 s, then posts params once. On any
boot where the link takes longer, the post fails silently and nothing
posts again, so the scada never checks that pico's identity or sends the
layout's capture settings. At spruce this was about half of all boots
(`experiments/2026-09-19-spruce-pico-params/`). Branch `td/pico-easy-fixes`.
