# Pico firmware next

Status: Accepted · Pass 1 · Updated 2026-10-14 · Linear: OPS-595

**EDD: yes** a real pico against a real scada is the verification; the
windows under "Verification" are run before any section reaches
Verified.

> What this is: the next round of pico firmware work and the scada
> changes that go with it. Three sections: a pico that keeps itself
> connected and announces that it is alive, a pico that says what it is,
> and the btu-meter code running as a flow-only meter. Cross-cutting
> because every change touches both gridworks-pico and the scada actor
> that decodes it. Raised 2026-10-14 out of the pico reboot storm.

## Where this starts

The 09-22 build (gridworks-pico `6a713e1`) is on every tank and btu
pico in the fleet. Its liveness story is: the pico posts data on its
capture period, the scada declares it missing after 2.1 periods of
silence (OPS-592), and the pico cycler power-cycles the rail. The
pico's own part in staying connected is thin:

- A post that raises sets a reconnect flag. The main loop then asks the
  NIC whether the link is up and does nothing while it says yes
  (`btu_meter/async_btu_main_no_net.py:280`). A pico whose posts fail
  while the link looks up keeps failing until the scada cycles the rail.
- No post has a timeout, so a socket that hangs rather than fails
  stalls the main loop with no flag set at all. On the Wiznet build no
  `timeout=` argument can bound a post
  (`gridworks-pico/executor/primary.md` "Platform").
- The two `machine.reset()` calls are for a params answer that arrives
  late at boot and changes a parameter, and for a code update, each
  after its flash write completes (lines 427 and 467).

What the pico says about itself: the params post has `HwUid`,
`PicoBoardVariant` (which names the board and so the link type) and
`MicropythonVersion` (`async_btu_main_no_net.py:363`). It has no
firmware commit and no MAC. Which build a pico runs is reconstructed
from the md5 of the file the box served it
(`experiments/pico-power-cycling/firmware-track-record.md`). The
MicroPython version the Pico W fleet runs is recorded nowhere in a
repo; the next params post from any Pico W says it.

The motivating case is beech's primary-btu, a Pico W on wifi, which
goes silent for two 300 s posts a few times a day while every other
pico in the house keeps posting through the same scada listener. The
rail cycle is the only thing that brings it back, and nothing in the
pico's behaviour tells us whether it was trying.

## 1. Staying connected and being seen

Every number below hangs off one clock, the heartbeat period P = 10 s.
The same rules apply to the tank-module and btu-meter firmware, which
share one networking code. The breadboard flow modules
(`ApiFlowModule`) are left alone: no heartbeat, their capture-period
bound as now.

### The heartbeat

The pico posts a `pico.heartbeat` every 10 s to
`/<actor-node-name>/pico-heartbeat`, served by `ApiBtuMeter` and
`ApiTankModule`: `HwUid`, `UptimeS` (seconds since boot), `ResetCause`,
`TypeName`, `Version`. The scada answers 200 and nothing else. Every
post the actor accepts from the pico, heartbeat or data, feeds the
pico's `heard`; a refused post does not.

`ResetCause` is a new enum with three values: `PowerOn`, `Watchdog`,
`SelfReset`. On rp2 `machine.reset()` is itself a watchdog reboot and
`machine.reset_cause()` returns only power-on or watchdog, so a
self-reset is marked before the call in a watchdog scratch register
(`scratch[0..3]` are free to us; the SDK's reboot uses 4..7; they
survive a watchdog reboot and clear on power-on). All three
`machine.reset()` calls, the connectivity self-reset, the late-params
reset and the code-update reset, set the marker in `scratch[0]`; only
the connectivity self-reset increments the count in `scratch[1]`,
which the backoff below uses. At boot: marker set means `SelfReset`;
watchdog without the marker means `Watchdog`; otherwise `PowerOn`.
The marker is cleared as soon as it is read. No hardware watchdog is
started in this round, so an unmarked `Watchdog` should never arrive
and is worth seeing if it does. Uptime and reset cause let the scada
see a pico that reset itself, count self-resets as glitches, and tell
a self-reset from a rail cycle. The identity facts of section 2
stay on the params post, sent once at boot.

The timer callback marks a heartbeat due; the main loop sends it,
because a MicroPython timer callback cannot do network I/O. A
heartbeat due while the main loop was busy is sent as soon as the loop
returns, not at the next tick. After a boot the first heartbeat goes
out as soon as the link is up, before `update_code()` and the params
post, so the scada hears the pico before the two boot posts spend
their timeouts. The tank module's boot-time offset sleep
(`tank_module_3_main_no_net.py:517`, up to a capture period) goes
away: the sync timer's first period is set to the offset instead, so
the main loop, and its heartbeats, start right after the boot posts.

### The bound

Liveness rests on the heartbeat. A heartbeat-fed pico is dead at
2.1 × P + C, where C is the pico's self-recovery budget beyond 2.1
periods: the time the chain below needs to rebuild, reset and post
again. At 2.1 × P, 21 s, the scada sends a Warning glitch so the
silence is on record, rate-capped as the actor's other glitches are; at 2.1 × P + C it sends `PicoMissing` to the
pico cycler and a `ChannelFlatlined` per channel, as
`gridworks-scada/executor/sensor-freshness.md` "Who declares a loss"
says for a dead pico. A 300 s channel on a dead pico is therefore
unknown at 71 s, not 630 s: a reading from a pico known to be dead is
not trusted for the rest of its capture period.

This changes "The bound" in `sensor-freshness.md`, which has one
multiple and no additive term. The spec gains one clause with this
design: a heartbeat-fed pico is dead at 2.1 × P + C. In code
`PicoLiveness` takes a `recovery_budget_s` beside its multiple; the
number is one named constant, `PICO_RECOVERY_BUDGET_S = 50`, in the
same module as the multiple, and zero for a pico with no heartbeat.

### Act on the API answer, not on the NIC

A post that does not get a healthy response is a failure, whatever the
NIC says about the link. Failures count on any post, heartbeat or
data. The reconnect flag and `RECONNECT_COOLDOWN_S` retire; the
failure count replaces them.

| | value | rule |
|---|---|---|
| post bound (Pico W) | 5 s | at most P/2, so a stalled post never overlaps the next heartbeat; Wiznet below |
| failures before rebuild | 2 | 2P of silence; one dropped packet on wifi is routine, two in a row are not |
| rebuild | wifi: deactivate, reassociate, DHCP; ethernet: re-init the chip, DHCP; 10 s timeout | the existing `CONNECT_TIMEOUT_S`, independent of P |
| failures after rebuild before `machine.reset()` | 2 | the same N, one constant |
| reset, boot, link up, first heartbeat | about 10 s | independent of P |
| C on the scada | 50 s | the chain above, 4P + rebuild + boot, minus the 2.1P the bound gives, plus slack |

The chain from the first failed post, each failure detected 5 s after
its send: sends at 0 and 10 s fail at 5 and 15 s; rebuild from 15 to
25 s; the heartbeat due at 20 s is sent at 25 s and fails at 30 s;
the send at 30 s fails at 35 s; reset at 35 s; link up and first
heartbeat by about 45 s. The scada's clock started at the last good
heartbeat, up to 10 s earlier, so the pico is posting again by about
55 s on the scada's clock and the rail cycle at 71 s has 16 s of
slack. The cycler is the backstop for a pico that cannot run its own
recovery, never a race with one that is healing itself. Halve P and C
drops by about 20 s; the rebuild and boot terms stay.

How a post is bounded differs by link type, and the firmware says so:

- **Pico W:** `requests.post(..., timeout=5)`; the lwIP socket honours
  `settimeout`.
- **Wiznet:** the driver blocks inside SPI and the spec says no
  `timeout=` bounds a post. A stalled Wiznet post is caught by the
  rail cycle at 71 s, as today with a margin, unless a bench check
  shows `settimeout` works on that build, in which case the spec
  sentence is corrected in the same wave and the 5 s bound applies.
  A failed Wiznet post, as opposed to a stalled one, counts like any
  other.

Two rules on the reset:

- **Reset only from the main loop, never from the timer callback,** so
  a reset can never interrupt a flash write. The two flash writes,
  saved params and new code, are main-loop calls, so the ordering is
  natural (`gridworks-pico/executor/primary.md` "Flash-write
  discipline").
- **Backoff by the self-reset count.** The budget before the next
  self-reset doubles with each self-reset in a row, read from
  `scratch[1]`, capped at eight minutes, and the count clears on the
  first 200. With the scada down a pico then churns once a minute,
  then once per two, four, eight minutes, for as long as the outage
  lasts. That churn is harmless: a reset writes no flash, the pico
  buffers nothing, a flow meter's tick state restarts with no scada
  there to receive it. It also means every scada stop longer than
  about 40 s, a deploy or a layout reload, self-resets every pico in
  the house once; that is expected, not a fault.

### No hardware watchdog this round

A hung main loop is caught by the rail cycle at 71 s. A `machine.WDT`
would catch it at 8 s, the rp2 maximum, but at that length every wait
in the firmware over 8 s needs a feed point, and a missed one is a
spurious hardware reset, possibly during a flash write, which is the
corruption the flash rules exist to prevent. The heartbeat's uptime
and reset cause will show how often a pico hangs rather than loses
its connection; a watchdog is decided on that data, after a season.

### The pico posts that have no word

`tank.module.params`, `async.btu.params`, `ticklist.hall` and
`baseurl.failure.alert` are sema words. `microvolts`,
`multichannel.snapshot`, `new.code` (the fleet firmware's code-update
post) and `new.pico` (the provisioner's) are not. The heartbeat is not
the only pico post with a word while the data it guards has none:
those four are written in the same wave. `pico.comms.params` is posted
only by the legacy ticklist btu code and gets no word.

## 2. What a pico says about itself

The params post already names the board (`PicoBoardVariant`, which is
the link type) and the MicroPython version. It gains the firmware
commit and the MAC. The scada checks what the pico posts against the
layout and reports a mismatch as a stale layout; it never writes the
layout (`gridworks-pico/executor/primary.md` "Hardware identity").

| field | params word, version | component word | the scada |
|---|---|---|---|
| `FirmwareCommit` (`formats/firmware.commit`) | `async.btu.params` 110, `tank.module.params` 210: already there, staging, edited in place | not a layout fact | logs it with the params line; the md5 reconstruction retires |
| `MacAddress` (`formats/mac.address`) | 110 and 210, in place | not a layout fact in this design | logs it with the params line |
| `PicoBoardVariant` | already posted | already on `pico.btu.meter.component.gt` 000 and `pico.tank.module.component.gt` 012 | checked against the layout, as now |

Keeping the MAC off the layout diverges from the pico spec's
"Verified field facts" bullet on link type, whose layout clause is
rewritten in the same wave: `PicoBoardVariant` is the link-type fact
on the layout and the MAC is logged only.

**Rollout.** The firmware posts `"Version": "100"` and `"200"` today
(`async_btu_main_no_net.py:382`, `tank_module_3_main_no_net.py:329`)
and a deployed pico takes new code only at boot, so the move to
110/210 is not one step across a house. The order: the box serves the
new build first; the scada deploys with both versions pinned in
`sema_seed_request.yaml` and the twins and handlers accepting either;
an old-build pico sends no heartbeat, is dead at 71 s, is cycled, and
takes the new code at that boot. That one rail cycle per house is the
rollout mechanism and is expected. A pico that does not heartbeat
after it is de-layouted until it is reflashed at the bench, as the
pico spec says for a dead pico, never left for the cycler to chase.
The 100/200 pins come out once every pico in the fleet is on 110/210.

## 3. The GW101 as a flow-only meter

All of the flow-meter hardware in the field is breadboards: a Pico and
a hall sensor posting tick lists (`pico.flow.module.component.gt`,
`ApiFlowModule`). They are replaced in a couple of weeks by GW101
boards with no thermistors. The old flow-meter code is left alone.

**Decision: one device type with a mode.** The GW101 is one board,
with or without thermistors plugged in. What it senses is a fact about
the installed instance, so it is stated on the component, as the CT
already is. The word, the actor and the firmware keep their names:
the device type is `Gw101`, which is honest either way; "btu meter"
stays the name of the firmware folder, `pico.btu.meter.component.gt`
and `ApiBtuMeter` until the proactor port regenerates the twins, when
a rename costs nothing extra. A layout's `DisplayName` says "flow
meter" where that is what the instance is. A second device type was
rejected: it spreads one board over two words and two actors for the
sake of a name, and reusing the flow-module word means the GW101
speaking tick lists, the branch being left behind.

The CT precedent does not transfer as a mechanism: the firmware
derives `ReadCtVoltage` from `CtChannelName` being present, with a
`None` default, and the params change check ignores keys the answer
omits. The temperature names default to derived strings. So here the
flag is primary:

- **`pico.btu.meter.component.gt` 000** (staging, in place) gains
  `ReadTemps: bool`. `HotChannelName`, `ColdChannelName`,
  `ThermistorBeta`, `TempCalcMethod` and `AsyncCaptureDeltaCelsiusX100`
  become optional, with one axiom each: present iff `ReadTemps` is
  true. A flow-only layout names no temperature channel, so a layout
  cannot name a channel nothing sends on.
- **`async.btu.params` 110** (staging, in place) gains `ReadTemps` with
  the same iff axioms.
- **Firmware:** `ReadTemps` is persisted in `app_config.json` and is in
  `PARAM_KEYS`, so a changed answer is seen and saved; it defaults to
  false and the temperature names default to `None`, so a fresh pico
  is flow-only until the first params answer, which turns the
  thermistors on where the layout has them. An answer with `ReadTemps`
  false clears the saved names. With `ReadTemps` false the pico does
  not read the thermistors and leaves the temperature channels out of
  the snapshot. The btu board already drops an open thermistor at
  3.299 V; the flag makes the intent explicit rather than relying on
  that.
- **`ApiBtuMeter`:** the params answer omits the fields the component
  does not have, never nulls them; the hot and cold channels are
  looked up only when the component has them, as `ct_channel` is
  today (`gw_spaceheat/actors/api_btu_meter.py:76`); a snapshot that
  names a temperature channel on a flow-only component is a post
  error.
- The gwsproto twin and the scada's sema snapshot move in the same
  wave.

## Verification

Field windows run on one pico with the box's log and the journal as
the record. Window 1 is two drops so each tests one outcome.

1. **Posts fail, link up, pico heals itself.** On the box, drop the
   pico's packets to the scada's port with iptables for 45 s. Expect
   two failed heartbeats, a rebuild, two more failures, a self-reset,
   and a heartbeat with `ResetCause` `SelfReset` and `UptimeS` near
   zero within 50 s of the first miss; no rail cycle.
2. **Posts fail past the pico's budget.** The same drop for 150 s.
   Expect the Warning glitch at 21 s, the rail cycle at 71 s and not
   before, and the pico back within one heartbeat of the drop ending.
3. **Scada down.** Stop the scada for ten minutes. Expect self-resets
   at about 0.75, 2.5 and 6 minutes, each within 30 s of that, and a
   heartbeat within P of the scada's return with no rail cycle.
4. **Flow-only GW101.** A GW101 with no thermistors and `ReadTemps`
   false on the bench against a dev scada: a snapshot with only the
   flow channel, no temperature channel in the layout, and the actor
   rejecting a snapshot that names one.

Bench, before the windows: a Pico W reassociates after `active(False)`
then `active(True)` on the fleet's MicroPython build, or the rebuild
uses `deinit()` and a fresh `WLAN` object; and whether `settimeout`
works on the Wiznet build.

**A test API in gridworks-pico.** The firmware is tested against a
small HTTP API that lives in gridworks-pico itself, not against a
scada: it serves the pico's routes (`pico-heartbeat`, the params post,
`multichannel-snapshot`, `microvolts`, the code update), validates
each post against the sema snapshot, and is scripted to misbehave on
command: answer 404, answer slowly, drop the connection, go away for
a set time, answer params with `ReadTemps` either way. Against it the
firmware's chain is driven end to end on the bench, failure count,
rebuild, self-reset with the scratch-register marker and count,
backoff, the heartbeat before the boot posts, without a scada or a
house. The scada side under OPS-532 is then checked against the same
routes. This is how gridworks-pico tests at all, since nothing in the
repo runs under pytest today.

## Scope now

This round is built in gridworks-pico and sema only. The scada side,
the heartbeat route, `recovery_budget_s`, the Warning glitch, the
optional temperature channels and the 110/210 pins, is a TODO under
OPS-532, and the fleet keeps today's capture-period bound until it is
built. The firmware's heartbeat posts are answered 404 by today's scada
and count as failures, so the heartbeat route on the scada is the
first scada item.

## Do this next

Set up the test API in gridworks-pico. Then author the sema words:
`pico.heartbeat` and `pico.reset.cause`, then `microvolts`,
`multichannel.snapshot`, `new.code` and `new.pico` (registry and
authoring spokes first, summary posted, per the sema protocol), and
the `ReadTemps` and `MacAddress` edits to the four staging words. Then
the firmware against the test API, then the bench checks. The scada
side and the field windows wait on OPS-532.
