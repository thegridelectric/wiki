# starter-scripts — changelog

One entry per `starter-scripts` commit (git = the what, this = the why).
Entries before 2026-08-23 live in git history only.

## 2026-09-24 — winter hack: secondary pump ON above 500 W hp-odu (`ff7650c`)

`spruce_winter_hack.py` turns the secondary pump on above 500 W of
hp-odu power instead of 120 W; OFF below 80 W is unchanged. With the
compressor off, the spruce Samsung outdoor unit pulses to 168-318 W for
about 60 s every 5 minutes on cold early mornings. On 2026-09-24 from
02:53 to 07:21 each of 45 pulses ran the pump for a minute at 7.7 gpm
through the heat exchanger and de-stratified the buffer (top 139 F to
117 F, bottom 103 F to 115 F) with no heat call. Over 33 compressor
starts (2026-09-21 to -24) power passed 500 W 4-12 s after its first
reading over 120 W, and lift first showed 15 s or more after the 500 W
crossing, so the pump still runs before there is lift.

## 2026-09-24 — better 5v toggles on all hosues (`57065f4`)

One pair of scripts keyed on the pi's hostname (`five_v_bus.py`): spruce
drives gw108 relay 1 on GPIO 23 as the deleted `spruce_turn_off_5v.py` /
`spruce_turn_on_5v.py` did; every
other house drives Krida relay 1 on board 1, whose address is read from
the production layout's Krida component (board 2 sits at 0x23 at oak,
fir and elm, where a dip switch differs, and is never touched). The
Krida write is a read-modify-write of the live 16-bit port, so only the
named relays change; `adafruit_pcf8575` cannot be used for a single
relay because its write buffer starts all-zero. A House0 off also
energizes relays 5, 6 and 8 (hp-failsafe, hp-scada-ops, aquastat-ctrl)
so the heat pump and the oil boiler stay off while the bus is down, as
the hand procedure does; on de-energizes them again unless
`--keep-hp-off`. Why: confirming which picos are live at a house means
dropping the 5V bus with the scada stopped and watching the bank re-post
into the starter-scripts API; one script per house family kept that a
per-house rewrite.

## 2026-09-22 — debug spruce hack (`e531e18`)

The first deploy read the buffer channels as CelsiusTimes100, the
telemetry name the tlayouts spruce layout gives them; the scada running
at spruce reports them CelsiusTimes1000 (live snapshot: 57100 = 57.1 C),
so the band saw ~1000 F, latched full and could never clear. Decode is
now /1000 with the live reading cited beside it. `spruce_snap.py` keeps
/100: which encoding is right depends on which scada is running (the
field `gwspaceheat` vs the `jm/spruce-unlimbo` window scada).

## 2026-09-22 — winter hack: HP call gated by a buffer band (`0860c97`)

`spruce_winter_hack.py` opens the heat-pump call when buffer-depth3 (the
bottom of the buffer) reaches `BUFFER_FULL_F` and lets it close again, on
the off-peak schedule as before, once buffer-depth1 (the top) drops below
`BUFFER_CHARGE_F`; between the two the latch holds. Defaults 130 F / 90 F
at the top of the script, overridable from `~/starter-scripts/.env` as
`WINTER_HACK_BUFFER_FULL_F` / `WINTER_HACK_BUFFER_CHARGE_F` (pydantic
settings, same file as the MQTT creds) so George can retune without
touching source; the script refuses to start with the band inverted. The
temps come off the scada snapshot the listener already subscribes to for
the flow check (`buffer-depth1-device` / `buffer-depth3-device`). A stale or missing reading holds the latch and logs it
once; with no reading ever seen the call is schedule-only, i.e. the
previous behavior. Every HP-call change logs its reason (peak state +
both temps) and the enforce heartbeat logs the band status. Why: with
the TOU contact closed all night the Samsung would cycle on a full
buffer; the band lets the store fill once and rest until the house has
drawn it down.

## 2026-09-21 — add `spruce_snap.py` field-support watcher (`c3047e4`)

A line for someone working the heat pump: hp-ewt / hp-lwt /
store-hot-pipe / store-cold-pipe / buffer-depth1 / buffer-depth3 in F and
secondary-flow in GPM from the scada snapshot (the admin
`snapshot-spaceheat` on the box's local mosquitto, cached from a
background MQTT thread), and secondary-pump / hp-odu / hp-ctrl-box power
in W read straight off the eGauge over Modbus — the same registers and
F32 decode the winter hack uses. Power is read at the meter, not from the
snapshot, because it moves fast and the ~30 s snapshot is too slow for it.
The eGauge is polled every 2 s but a line prints only on a 30 s heartbeat
or the moment a power channel moves >=5 W (idle jitter stays quiet); the
column header reprints every 5 min. The temp/flow channels report
async-on-change, so the line is flagged only when the snapshot feed itself
stalls, never for a steady value that is simply minutes old. Why: field
support to get the Samsung responding to heat calls — the values you watch
while doing it, in one place at meter speed.

## 2026-08-25 — remove `provoke_gw108.py` (`69d1f69`)

Stale on two counts: it targets `dac3`, dead since 2026-07-30 (secondary
pump speed moved to `dac2`), and the hypothesis it bisected — whether
DAC/mux i2c traffic during the enforce burst causes the 0x21 reset — is
answered more directly by the 2026-08-23 relay-stress experiment
(`experiments/2026-08-23-spruce-relay-stress/`), which found the real
trigger (iso relay energized with fewer than two other 0x21 coils on)
without ever touching the DAC. `relay_stress.py` is the current tool for
further sweeps. Why: Joe asked whether this script was still the one to
use for testing.


## 2026-08-23 — store scripts: honest stop reasons, i2c retries, eGauge poller, dead-head guard (`5707494`)

`store_common`: `i2c_retry` on every relay read/write (a 0x21 brownout no
longer kills a run mid-repair — the second charge attempt's lesson from
the stress harness applied here); reset repair waits 0.5 s and re-asserts
through `set`. `EgaugePoller`: direct 5 s modbus poll of the eGauge's
hp-odu register (9014, live-verified against the snapshot; the snapshot
refreshes hp power only every ~30-60 s) — the fast signal for gating the
secondary pump on compressor ramp, not yet consumed. Both scripts: stop
reason distinguishes Ctrl-C from a crash, and a crash logs its traceback
to the log instead of only the screen. `charge_store`: dead-head guard —
fresh `secondary-flow` < 0.5 gpm for 60 s (after a 120 s grace) with the
pump commanded on reopens the iso valve and stops with a CRITICAL note
(assumes the meter witnesses store-path flow; revisit if the polarity
re-run shows otherwise).
Why: the first charge run stopped with reason "interrupted" and no way to
tell Ctrl-C from an exception from the log alone; and the pump-gating
design (wait for HP ramp before circulating a chilled, stratified store —
cold enters at the TOP) needs power at seconds latency.

## 2026-08-23 — store scripts wait for the first snapshot (`f4b6c03`)

`store_common.Snapshots.wait_first` (block up to 60 s until MQTT has
delivered a snapshot), called by both store scripts before acting — the
opening report line printed all `--` on the first charge run because
nothing had arrived yet.

## 2026-08-23 — charge_store / discharge_store; hack energizes iso last, no clear when healthy (`660a944`, `cc3e14f`)

`spruce_summer_hack.py`: at start, clear-then-configure an expander ONLY
if its config regs are nonzero (power-on state); a healthy chip keeps its
coils and the enforce pass corrects drift one coil at a time. The ON state
change and the auto-repair re-assert now go pump → hp-call → iso last (was
iso first). `relay_stress.py` removed (the harness lives in experiments).

New `store_common.py` (0x21 relay map, relay writes with the POR check +
re-assert, snapshot listener judging age by scada read time, shared log =
the summer hack's log file, screen line), `charge_store.py` (charge valve
energized first → iso closed → pump on → hp-call; stops at the heat pump's
natural off = `hp-odu-pwr` < 100 W for 10 min after having run, or freeze /
store-floor / max-run guards; iso reopened first and charge valve
de-energized LAST on exit), `discharge_store.py` (store pump on, integrates
`store-flow` to 120 gal; iso open, charge off, secondary pump off, store
pump on; exits at once if `hp-odu-pwr` rises above 500 W — the Samsung
ignores hp-call today and must not run with the secondary pump off).
Both report store/buffer temps + flows to screen and the hack's log every
10 min, timestamped (`cc3e14f`). Also `4b391cb` (relay_stress first
draft) is superseded within this cluster — the harness lives in the
experiments repo. Why: charge and discharge the store
by hand this week ahead of the scada relay port; and the 2026-08-23
relay-stress finding — energizing the iso relay with fewer than two other
0x21 coils on resets the expander ~2 times in 3, which is exactly what the
old start sequence did (clear all, energize iso first, alone) and why the
service reset at every start. Every restart is now a witnessed test of the
fix.
