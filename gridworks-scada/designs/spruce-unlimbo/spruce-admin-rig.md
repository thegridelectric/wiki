# Spruce admin rig (spoke)

Status: Draft · Pass 0 · Updated 2026-09-08 · Linear: OPS-392

> What this is: a standing rig for driving the real spruce house from
> the admin panel against the latest `jm/spruce-unlimbo`, with a person
> on site (George, 2026-09-08). The scada runs in a shared tmux session
> on the box off the dev broker, so spruce stays off rmqbot while
> `layout.lite/013` is staging (`sh-node-actor-partition/
> staging-words-on-prod.md`). The one-off form of this is
> `experiments/2026-09-08-spruce-admin-panel/` "Protocol"; this spoke
> makes it repeatable and open-ended.

## State (2026-09-08 14:29 ET, session closed with the rig live)

- Laptop: `jm/spruce-unlimbo` pushed at `609e4085` (force-with-lease over
  the pre-amend twin `c8555abe`). `gw-dev-rabbit` up; the tunnel
  `ssh -f -N -o ExitOnForwardFailure=yes -R 1885:localhost:1885 spruce`
  is running from this morning's window.
- Box (`spruce`): `~/gridworks-scada-unlimbo` on `jm/spruce-unlimbo` at
  `609e4085`, clean (moved to the pushed tip 2026-09-08 14:24 ET).
  `gwspaceheat`, `gwspaceheat-restart.timer` and `spruce-summer-hack`
  are all active. `~/envs/dev.env` present.
  tmux installed, no session. Artifacts in
  `~/.config/gridworks/scada-experiment/` are the 09-06 spruce pair
  (`gw.nolan.layout/000`, `gw.nolan.operational.params/000`).
- 14:24 ET: the deployed scada, its restart timer and the summer hack
  stopped; the unlimbo scada booted in the background from
  `~/envs/dev.env` (`setsid nohup timeout 14460 … window_boot.py 14400`,
  log `/tmp/spruce-admin-rig/boot.log`), upstream on the tunnel, admin
  link awaiting its peer on the box's mosquitto. Restarted 14:45 ET
  after the picos' 5 V supply was reconnected (earlier logs
  `boot-1424.log`, `boot-1444-failed.log` alongside); self-terminates
  at 18:45 ET; restarted again 14:54 ET at `cdce340b` (hp-boss boots
  HpOff and reports it), bound 18:54 ET; stopped 15:14 for the relay
  stress rerun on the replaced board
  (`experiments/2026-08-23-gw108-relay-stress/2026-09-08-spruce-board2/`), restarted
  15:20, bound 19:20 ET; restore is step 4 below.
- 15:2x ET: Samsung field setting 2091 set to 1 (external thermostat
  control), so the hp-scada-ops dry contact now starts and stops the
  heat pump; before this the unit ran its own schedule and ignored it.
- The window's record lives on the box: snapshots every 30 s captured
  from the box mosquitto into `/tmp/spruce-admin-rig/snapshots.log`
  (`mosquitto_sub -F "%U %t %p"`), and the scada's own upstream events
  (`report.event` every 5 min, problems, comm events) persisted under
  `~/.local/share/gridworks/scada-experiment/event/` because the
  upstream link has no LTN peer on the dev broker and so never acks.
  Nothing reaches the dev broker itself while the link is awaiting its
  peer; a laptop-side recorder on 1885 stays empty. At restore, both go
  into the experiment's `instances/`.
- `gwa` installed editable into the unlimbo venv on the box, and
  `~/.config/gridworks/admin/admin-config.json` registers scada `spruce`
  at `localhost:1883` with the admin link's user from `dev.env`
  (recorded in the box `~/README.md`).

## How the local admin window works

Roles: the Claude session starts and stops the scada side (the deployed
scada, its restart timer, the summer hack, and the unlimbo scada in the
background); the human runs the admin panel in a tmux session on the box
that the person on site can attach to.

The unlimbo scada boots from `~/envs/dev.env`: real spruce identity,
dev-broker creds only, upstream over the laptop's `ssh -R 1885` tunnel,
paths root `scada-experiment` so the deployed scada's data is untouched,
and its admin link on the box's own mosquitto at `localhost:1883` as the
local link's user. `window_boot.py` takes a bound in seconds and the env
file, and self-terminates at the bound. Boot cycles the vdc-relay once.

The panel runs on the box from the same venv, against that mosquitto:

    ssh -t spruce tmux new -As unlimbo
    cd ~/gridworks-scada-unlimbo/gw_spaceheat
    venv/bin/gwa watch spruce

`tmux new -As unlimbo` creates the session or attaches to it, so a
second person attaching sees the same panel. Detach with `Ctrl-b d`;
the panel keeps running. The admin config is
`~/.config/gridworks/admin/admin-config.json` on the box. The panel
shows `?` per row until each node's first state report arrives; the
cycler and hp-boss rows follow `machine.states` live. Release admin and
quit the TUI before the scada is stopped.

## Findings, 2026-09-08 afternoon window (George on site)

Record: `experiments/2026-09-08-spruce-admin-panel/` "Afternoon window"
(box logs under `rig-log/afternoon/`, snapshots every 30 s in
`snapshots.log`, the scada's persisted events under
`instances/afternoon-events/`).

- **gw108 board replaced** (Joe could not reproduce the 0x21 reset on
  bench boards). The reset followed the house: B2 17/100 with the iso
  relay switched alone, 0/60 with two or more other coils on
  (`experiments/2026-08-23-gw108-relay-stress/2026-09-08-spruce-board2/`). Two-coil rule
  stands; the electrical question is the iso actuator on the relay
  supply or that relay position's wiring.
- **hp-boss** boots `HpOff` and reports at start (`cdce340b`, on the
  box since 14:54); the row shows a state and offers a button. Verified
  live: TurnOn/TurnOff dispatches reach hp-boss, the ops relay pin
  follows, the RIB LED follows the relay both ways.
- **Heat pump: the SmartThings mode decides whether B21 is heard.**
  Chain proven to the RIB coil (TurnOn/TurnOff reach hp-boss, the ops
  relay pin and the RIB LED follow). With FSV 2091 = 1 the app screen
  reads "mode: controlled by thermostat" and the contact governs: the
  15:37:08 relay-open stopped a running compressor inside a minute
  (odu 1396 W at 15:37:30, 21 W at 15:38:00, pump overrun to 15:39).
  After a mode change made in the app (~15:41) the screen read
  "mode: cool" and the contact was ignored both ways: relay closed
  15:40:47, no start in five minutes; app start at ~15:45:45 took at
  once (ctrl box 104 W at 15:46:00); relay opened 15:48:06, compressor
  kept climbing to 1584 W and only stopped at 15:51:30 on the cooling
  water law (LWT 8.1 °C, the app said "water law temp"). So the app's
  mode selection overrides 2091, or resets it; which one is unread.
  Rule for the rig: after 2091 = 1, nobody touches mode in the app and
  the screen must read "controlled by thermostat"; verify 2091 on the
  touch panel after any app change. The earlier no-response
  (15:23–15:29, before George's ~15:30 power cycle) is consistent with
  2091 taking effect only on reboot. Entering water is not a cause:
  journal DB Aug 8 to Sep 8 shows 1865 of 1907 compressor starts with
  EWT at or below 55 °F (median 51 °F), and the unit's routine pattern
  is 2–5 min runs every ~10 min, water-law cycling with no load.
  Unchecked still: B21 live to B19 with the RIB red.
- **Charge valve does not open.** OpenValve reaches the relay actor and
  the 0x21 pin (port 1 bit 3) reads high, no chip reset; with the iso
  valve closed and the pump on, store-flow stays 0 and the water takes
  the distribution path (secondary 3.96 gpm at 7.6 V against 7.4 on the
  short loop). Hardware from the relay contact outward, most likely the
  wire not carried to the new board's 1.3 position.
- **store-cold-pipe reads ~154 °C** straight from the store-btu pico
  (raw CelsiusTimes100 15374–15432; hot pipe 17.9 °C), layout units
  consistent for both channels. A shorted thermistor or lead, or the
  wrong input, on that pico.
- **Picos dark = 5 V supply unplugged**, not the router: reconnected at
  ~14:41, all six posted within a minute. `start_api.sh` on the box is
  the pico-path test; it needs port 8000, so the scada must be stopped.
- **DAC verified live**: admin dispatch 5.0 V → code 2000 on channel C
  through the mux, flow 9.56 → 4.00 gpm on the sweep's curve.
- **Direct eGauge read** with the spruce register map:
  `rig-log/afternoon/egauge_live.py` (run from the box's
  `starter-scripts` venv; `egauge.py` there carries the House0 map and
  mislabels spruce's registers).
- Window operations: `pkill -f window_boot.py` in the same ssh command
  as a relaunch line kills the shell itself; a stopped window scada can
  linger holding port 8000 (kill the pid `ss -ltnp` names). The
  upstream link never leaves awaiting-peer (no LTN on the dev broker),
  so nothing reaches the dev broker; the record is the box.

## ▶ Do this next

1. Heat pump call, one clean cycle with the app untouched and the
   screen reading "controlled by thermostat": TurnOn, start within
   ~3 min; TurnOff with LWT still above ~11 °C, stop within a minute.
   If it fails, read 2091 on the touch panel first, then meter
   B21→B19 with the RIB red (breakers off, live-dead-live first).
2. Charge valve: check the wire on the new board's relay 1.3 contact,
   then OpenValve from the panel and watch store-flow.
3. store-btu pico: cold-pipe thermistor and its input.
4. Restore afterwards exactly as the 09-08 README step 11: check the
   deployed event dir holds nothing window-born, `pkill -f
   "[w]indow_boot.py"` if the bound has not passed, stop the snapshot
   `mosquitto_sub`, copy `/tmp/spruce-admin-rig/` and the experiment
   paths root's events into the experiment folder, then
   `sudo systemctl start spruce-summer-hack gwspaceheat gwspaceheat-restart.timer`.

## Open

- hp-boss row shows `?` for the whole window: `HpBoss.__init__` sets
  `state = HpOn` and only `report_state()`s on a transition, so a TurnOn
  into the default state emits nothing and the snapshot's
  `LatestStateList` never carries `hp.boss.state`. Meanwhile the ops
  relay is open, so the default disagrees with the plant. The panel
  then offers the row no button at all (`RelayWidgetConfig.next_command`
  returns nothing for a two-command row with no observed state), so
  under admin the heat pump cannot be commanded from the panel. Fix candidate
  (not during a live window): boot state `HpOff` and a `report_state()`
  at start, with a test; the cycler already reports every cycle, which is
  why its row fills. Also open: whether a two-command row with no
  observed state should offer both commands instead of none.
- 2026-09-08 window: no pico posts reached port 8000 at all (tcpdump
  empty, 16 snapshot channels, all board-local; the deployed scada had
  flatlined all six picos in the minutes before the switch, after a
  house power-off). ARP table on the box held no pico addresses. A
  pico outage after a power cycle is a house-network fact, not a rig
  fact; the rig only surfaces it. Test the pico HTTP path from
  `starter-scripts` before blaming the scada.
- `experiments/2026-09-07-adc-waveform-bench/` bears on this rig: its
  "Speed ladder (spruce, secondary pump)" drove the DAC and the pump relay
  on the real house from the deployed venv with `spruce-summer-hack`
  stopped, exactly the plant the panel drives here (the failsafe drops
  the pump when the hack stops; a driver re-energizes it). Read that
  section and the CT capture command before the first pump move, and
  fold what the rig reuses in here.
- Whether this rig deserves its own flat design and issue once it
  outlives the epic (a standing operator rig is shared-dependency work).
