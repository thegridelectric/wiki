# starter-scripts — changelog

One entry per `starter-scripts` commit (git = the what, this = the why).
Entries before 2026-08-23 live in git history only.

<!-- pending commit -->
## 2026-08-25 — remove `provoke_gw108.py`

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
