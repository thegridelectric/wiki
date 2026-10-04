# experiments — changelog

One entry per commit in the `experiments` code repo
(github.com/thegridelectric/experiments); git holds the *what*, this file
the *why*.

Newest at the top.

## 2026-09-30 — alerter-to-alertmanager: the tap witnessed; snapshot from the published alert words (OPS-547, `a598162`)

The new folder records the run: the alerter's `gw.alert` through the
tap into a local Alertmanager, Firing paged, Resolved closed, alerter
and tap restarted with the alert open, PASS; evidence, the archived
store, the two alert-word instances and the run record, with the mock
scada reused from the September 15 folder. `src/gwexp/sema` regenerates
from sema `632b58e`: the five alert words leave `indexes/staging.yaml`
as published; no generated class changed. **Why:** the design's handoff
bar for OPS-547, and the snapshot has to say the words are published
before the box run reads instances through it.

## 2026-09-30 — sema snapshot regenerated from jm/operating-status (OPS-392, `65b1fdc`)

`src/gwexp/sema` regenerates: `layout.lite` 013 loses `ActuationAuthority`,
`ServiceMode` and `SeasonalStorageMode`, so `gw1.actuation.authority` and
`gw1.service.mode` leave the closure; the regen also carries the sema
changes since the last one (`gw1.actor.class` 014, the pico component
words). No gwexp code read the retired enum. **Why:** the posture facts
ride `gw.house.operating.status` now, and the experiment tooling decodes
`layout.lite` from this snapshot.

## 2026-09-28 — sieg-keep-ratio-map: the map, run in two windows (`9cca498`)

The 26 stops ran script-driven through the admin path in two maple
windows, 18:23 to 21:07 ET, and the record is written: keep onset 27 to
30 s, half point 38 s, keep complete 54 to 57 s from the send stop; a
stop counted down from the keep end lands 4 s further toward keep than
its count says; the store relay makes no difference; and the flow
meters answer about 1 s behind the water in motion, so the 4 s lag the
morning's traverses implied was that second plus the keep-side offset.
`keep_ratio.py` now reads only StopValve stops with their direction;
`emit_instances.py` writes one run record per window; the protocol's
timing is corrected to five minutes a run from send and seven from
keep. The driver's window-1 log, committed mid-run, is now complete.

## 2026-09-28 — Add sieg-keep-ratio-map experiment for maple (`9e0d91b`)

Two pieces of basic-sieg work in one commit, plus another session's
alerter evidence (`2026-09-15-alerter-no-data/`, recorded by that
session). First, `maple-ecodan-start-in-full-keep` gains finding 6 and
`loop_volume.py`: the nine closed-start chunks of the day's four windows
fit the kept loop at about 0.8 gal of water, with the fitted volume
climbing with temperature, so the model is missing a loss term that the
holds are to calibrate. Second, `2026-09-28-sieg-keep-ratio-map/`, the
experiment that replaces the loop's guessed valve constants with maple's
own: `half_point.py` reads the day's full travels and places keep onset
at about 26 s, keep complete at about 56 s and the keep stop at about
94 s from the send stop, all six half crossings agreeing only with a
4 s answer lag in the flow meters; `drive_keep_ratio.py` sends the
panel's own admin dispatches from a script and times each StopValve
from its MoveTo, so a run's position is set by the log, not by hand;
`keep_ratio.py` reads the settled kept fraction per stop from held
values with an age cap, since a settled flow posts nothing new. The
protocol is 26 stops across the span where the split changes, from
both directions with the store relay alternating, over two windows.

## 2026-09-28 — beta-field-windows keeps every run under `runs/`; a run emits `gw.readings` (`ca6e4ea`)

The basic-sieg change 5 series needs several heat pump starts kept side by
side, so the "only the last run is kept" rule goes: each window is a folder
under `beta-field-windows/runs/` (logs, events, capture, provenance
sidecars, `instances/`), indexed in `runs.md`. `emit_readings.py` folds a
run's `report.event`s into one `gw.readings` instance through the vendored
snapshot, so a run's readings are read from a sema instance and not off
the strip; `emit_instances.py` takes the run folder and the code ref as
arguments instead of scanning the folder top. First run filed: the
2026-09-28 12:41 maple window, one Ecodan start held at full keep and
opened by hand at 120.9 F.

## 2026-09-28 — maple-ecodan-start-in-full-keep: the Ecodan called at full keep (`29369cc`)

A 21-minute admin-driven maple window, its own folder because it tests
one thing: the Ecodan's start with the Siegenthaler loop fully kept and
69 F water at its inlet. The call became power at 3 min 52 s and 1.5 kW
at 6 min, both on the startup-signature medians, so the kept cold loop
does not change the start delay; the kept loop climbed 56 F in 4 min
with 1.5 to 2.6 F of lift; the compressor ran 1 to 2.5 min past relay 6
opening, which is what an HpOff panel beside a 1.9 kW meter means. The
folder carries the window logs, the four persisted reports, the broker
capture, a parsed sieg-view strip and the run record. The 07:15 report
was lost to closing on the laptop clock, 70 s ahead of the box.

## 2026-09-27 — beta-field-windows round five: maple, basic-sieg 4d verified (`29369cc`)

The folder keeps only the last run, so round four's spruce and beech
artifacts go and maple's 11-minute window of 2026-09-27 takes their
place: both window logs, the 16 persisted events, the broker capture,
the subagent's read of them, and a provenance sidecar for each.
`emit_instances.py` learns maple's alias, creates `instances/` when
missing, and names the commits it ran against. The recipe's Houses table
records maple as Active with a window up, and its 110-firmware section
gains the BTU picos' `async.btu.params` refusal, seen at this round
beside the tank picos'.

## 2026-09-25 — house_window: a two-pi window runs on both pis or neither; beech2 joins (`65f0a25`)

The window stopped `gwspaceheat2` on maple2 but not its restart timer, so
on the 16:32 maple window the timer brought production scada2 back at
16:45 beside the branch scada2, and both posted maple2's analog temps to
maple's broker under different encodings. Behind that sat three ways one
pi could run the branch beside the other's production scada: the pis
booted 20 s apart and so ended 20 s apart; a crash on one restored only
that one; and `on` booted the second pi before learning whether the first
had come up. Now the timer is among the second pi's window services, both
pis boot at once, `on` ends the window on both unless both are up, and a
watcher on the laptop ends it on both when it ends on either. It kills
and restores itself, because `pkill` takes the box-side job's wrapper and
its restart with it. Every house but spruce has a second pi, so beech
gets `beech2` in both scripts; beech's window refused until beech2 was
kitted with the branch checkout, `~/experiments`, a window env pointing at
beech's mosquitto (production at beech uses beech2's), and the pair.
`on` waits on the two boots by pid, since a bare `wait` also waits on the
broker capture this shell starts and never returns. `off` counted
`report.event`s with a `grep` whose no-match exit failed the pipeline
under `pipefail`, so a window with no reports ended `off` before it
restored the first pi; the count tolerates none, and `off` restores the
first pi from an EXIT trap whatever fails before it. Witnessed at maple
2026-09-25: a killed scada2 ended both windows within 10 s and both pis
came back on production; a 15-minute window ended both at its bound.

## 2026-09-25 — maple_snap.py: the field-support strip for maple (`aa79501`; the title is the starter-scripts commit's, the diff is house_window on both maple pis)

The maple window's strip showed the analog-temp channels ten times hot:
maple2 posts them by its own layout's encoding (`WaterTempCTimes1000` on
`main`) into a window scada whose layout declares `CelsiusTimes100`, and
the wire carries no unit. The branch cannot run in maple2's normal
checkout between windows (its loader refuses the non-sema production
layout, and `main` cannot load the sema one), so the second pi gets the
first pi's window kit: `~/gridworks-scada-unlimbo`, `~/envs/dev.env` with
only the local link, and the window pair in `scada-experiment/`.
`put_layout.sh maple` puts and byte-checks the pair on both boxes;
`window_boot.py` moves to the repo root (it is what every window boots
through, not the 2026-08-10 rung's own harness) and boots `Scada2App`
under `WINDOW_SCADA2=1` with the same paths-root isolation; `house_window.sh maple on` checks maple2's head,
stops `gwspaceheat2`, boots the branch scada2 there and restores it at
`off` and on exit, with `status` covering it. The field-window recipe's
"Houses" and the spot-check recipe say why both pis move together.

## 2026-09-24 — beta-field-windows: beech's refused params came from pico-cycler reboots

Round four's README and the recipe's "Picos on the 110 firmware" section
said a 110 tank pico posts refused params once a minute. It posts once
per boot (`gridworks-pico` `7a80933` has no retry). The per-minute
refusals at beech came from the pico cycler power-cycling the 5 V bus
about every 65 s over one flatlined pico (`dist2-flow pico_2a7e22`).
Both docs now say so, and the recipe treats a run of cycler reboots as a
finding while a single refusal is not. Why: the wrong cause would have
sent the next round after the firmware rather than the cycler.

---

## 2026-09-24 — house_window: windows save a full-slot report and pull their persisted events

A bounded window is now at least 11 minutes (`on` refuses shorter), so it
crosses two 300 s report boundaries and saves the first full-slot report.
`on` stamps the window's UTC start on the box; `off` pulls every
persisted event stamped since then into `../scratch/<house>-events-<stamp>/`
and prints the `report.event` count, warning when there is none. Round
four's persisted events join the last-run record in
`beta-field-windows/` (`spruce-events/`, `beech-events/`, with
provenance), and its README corrects the boot-to-first-snapshot reading
(9 s, not 80 s: the 80 s compared the box clock with the laptop's). The
recipe says every round reads the reports as well as the snapshots. Why:
with no LTN the upstream link never goes active, so round four's reports
persisted on the boxes and never reached the capture. The 5-minute
windows also closed before the second boundary, so the reporting cadence
the round meant to check went unread.

---

## 2026-09-24 — cleaning up the beta-field-windows

Round four replaces round three in `beta-field-windows/` (two 5-minute
windows on scada `847d9ca9`, spruce and beech, no LTN, no `--debug`);
`emit_instances.py` finds each house's `<house>-window-*.log` in the
folder instead of naming the round's logs by hand. The field-window
recipe's Houses table carries `ServiceMode` and `ActuationAuthority` per
house so beech's Standby is an expected reading, not a finding; the
round reads the gen's ops params against it before `on`. The recipe also
says to check for a capture left running (`on` reuses it), gives the box
pull command and the live log path, notes the UTC ISO event filenames,
and points at the missing-pico method in `starter-scripts`. A section
records that the fleet's picos post `tank.module.params` 110 for several
weeks (spruce excepted), so the per-minute problem events on a House0
window are not a finding. Why: the next session should open the recipe
and run a round without rediscovering any of these.

---

## 2026-09-23 — beta-field-windows: lean non-dated practice folder, last run only; recipe gains On Tap + keep-last-run rule

The dated `2026-09-18-beta-field-windows/` folder becomes the non-dated
`beta-field-windows/`: the field-window test is an ongoing practice, not a
one-shot experiment, and it keeps only the last run — a new window deletes the
prior run's data (git history and the logbook keep what a round taught). The
folder now holds `emit_instances.py`, the last run (round three, 2026-09-19),
and a lean README whose top states the delete rule. `field-window-recipe.md`
gains the keep-only-the-last-run rule and the On Tap list; `README.md` (the
experiments index) records this as the one exception to
one-folder-per-experiment and to the evidence-stays-untouched rule, and the
logbook links repoint to the renamed folder.

## 2026-09-23 — field-window recipe as a top-level doc; spot-check spruce branch exception (`d164646`)

The operational how-to for running a bounded window of the unlimbo scada on a
house — the two window kinds, the two box layouts (production vs the
`scada-experiment` window pair), the `put_layout.sh` byte-identity gate, the
tunnel, and running a round — becomes `field-window-recipe.md` at the repo
root, a sibling to `spot-check-recipe.md`. The two are the live and the
after-the-fact paths for working with the production machines, and a subfolder
README was a poor home for the live one. `spot-check-recipe.md` gains a
"Spruce is special" section: spruce runs production off `actual-spruce` in both
scada and tlayouts — a different branch in both repos than the rest of the
fleet, which the window branches (`jm/spruce-unlimbo`, tlayouts `jm/spruce`)
sit beside.

## 2026-09-23 — refactor beta field windows (`2c185da`)

`spot_check.py` and `spot-check-recipe.md` arrive: a spot-check answers a
quick question about a house straight from the journal DB and leaves
nothing in the repo, which is the line between it and an experiment. The
tool reads `report.event`, because the state machines (sieg control, HP
boss, relays) are not a journaled message type of their own and ride
inside that payload beside the numeric channels; `pull_readings.py` sees
only the numerics. The beta-field-windows README is cut down: "Why" and
"Known" fold into "Systems with beta windows" and "Left to check or figure
out", the round is written as bring up, collect, close, and the resolved
mysteries leave the file for the logbook and git history.

## 2026-09-19 — improving scripts for beta field windows (`c1205b4`)

`house_window.sh` starts `capture_broker.py` at every `on` and refuses to open a
window without one, so a round cannot again end with no broker-side
record; the capture is shared by the open windows and stopped by hand
(`capture off`). `dev` joins spruce and beech as a target: the same
`window_boot.py`, which now takes the scada checkout as an argument, runs
the laptop's checkout on its sim pair, so a round is rehearsed before a
house gives up its plant control. `--debug` sets the scada's log levels
through the process environment (the base level is an integer setting);
`--ltn` runs the LTN on the laptop against the target's own layout pair,
which is where the LTN takes its identity and its peer from, with the ops
params path given explicitly because the LTN's default name for it matches
no generated pair.
The round README's Process steps follow the new usage.

## 2026-09-19 — refactoring the beta-field-windows (`8c6bb10`)

The spruce and beech windows of 2026-09-18 were the first round of
something that recurs: after roughly each spruce-unlimbo spoke the new
scada code runs in a bounded window on one house per layout family. The
folder takes the name of that practice, `2026-09-18-beta-field-windows/`,
so later rounds add to it; the `ExperimentSlug` in its instances and the
logbook line move with it.
Its README becomes a statement of what the rounds have established and
what is still a mystery, rewritten each round, with a temporary Process
section; the per-round narrative stays in git history and the logbook.

Round one of the beta field windows had no broker-side record: a hand-run
`mosquitto_sub` was refused and the window's events were copied off the
boxes afterwards. `capture_broker.py` rides the broker's firehose
(`amq.rabbitmq.trace`, `publish.#`), so one queue sees the scada's MQTT
traffic and every gwbase actor exchange, including exchanges declared after
it started. Before it reports ready it publishes a probe and requires it
back through the firehose, so a capture that says `capturing` is proven to
be recording. Tracing is a per-vhost switch, so a pidfile holds it to one
capture at a time. The broker URL is `GWEXP_RABBIT__URL` in the repo's
`.env`; `pika` joins the dependencies.

## 2026-09-18 — the spruce window names the winter hack alone; correct-house0 windows record (`3013412`)

The winter hack is spruce's one plant-control service beside the scada, so
`house_window.sh` and the `window_boot.py` docstring name it alone. `on`
also opens without the tunnel when the laptop's dev broker is not there:
the tunnel carries the upstream link for observation, commands ride the
box's own mosquitto, and a missing tunnel costs data, not the window.

The same commit holds the record of the first run of the script on both
houses, `2026-09-18-correct-house0-windows/`: the generated layout pairs
booted on spruce and beech, with what each window's log and data showed.

## 2026-09-18 — update scada scripts (`7bf9aa3`)

`spruce_window.sh` stopped the summer hack by name, so with the winter
hack running the plant it would have booted a window scada beside a
controller still enforcing the zone, valve and pump relays, and `off`
would have left the house with no plant controller. Beech had only the
per-rung `beech_window.sh` copies, whose `on` writes that rung's layout
pair over whatever `put_layout.sh` put. `house_window.sh <house>` carries
the window for both houses. `on` refuses unless the box's pair is
byte-identical to the tlayouts gen output and the box's unlimbo checkout
is at the laptop's pushed scada head; it records which of the house's
services were running, stops them, and the box restarts exactly those when
the window scada exits for any reason (the bound, a crash, or `off`), so a
closed laptop does not leave a house without its controller.
`spruce_window.sh` and a top-level `beech_window.sh` call it with their
house.

## 2026-09-18 — put_layout.sh names the previous file only when one was kept (OPS-539, `5c30b84`)

On a box with no window files yet (maple's first put) the script printed
the name of a previous-file copy it had not made. It now reports the copy
the box made, or that there was none.

---

## 2026-09-18 — put_layout.sh: the tlayouts gen output onto a house's experiment-window dir (OPS-539, `216813d`)

The window scada reads its layout and ops params from
`~/.config/gridworks/scada-experiment/` on the box, and those files were
refreshed by hand, so they drifted from `tlayouts/output/<house>/`
without anyone seeing it. `put_layout.sh <house> check` reports whether
the two box files are byte-identical (sha256) to the gen output;
`put_layout.sh <house> <change>` leaves a dated
`<file>.<date>-pre-<change>.json` copy beside each file that differs,
copies the gen output over it and verifies the hash. It refuses while a
window scada is running. Spruce, beech and maple share the one script;
the per-house part is the gen's two output filenames.

---

## 2026-09-10 — pico-state-reported: journalkeeper reads the cycler's per-pico roster on the dev broker (`90336c0`)

New folder. The actual-spruce sim scada (`69d5d6ec`, nolan layout,
simulated) with an LTN peer on the dev broker, and journalkeeper
`3a8bc57` on a fresh local `tsdb_devrung`: `buffer-pico-state` and
`tank1-pico-state` appear from `layout.lite` 012 and carry Alive then
Flatlined in time order, PASS. Harness `mqtt_types.py`, two capture
tallies, and the journal readback with its query. Found on the way:
the journalkeeper makes no `pico-cycler` state channel, so the spoke's
"flatline row before the cycler's own row" has nothing to order
against; the live persistor never prints its dropped counter; the
`jm/spruce-unlimbo` line emits `layout.lite` 013 (staging), which the
journal seed does not carry; the laptop's stale scada event backlog
uploads on link-active and flaps an old-decoder LTN.

**Why:** the spruce pull of the roster line is next, and a report
reaching the journal before it knows the channels only tallies drops.
Seeing the pairing work on the dev broker first is the rung the spoke
asked for.

Also in the folder: the same rows read from the production journal once
spruce ran the line (`spruce-pico-states.txt`, the `psql` one-liner in
the README, and the state changes as a table). They are the roster's
first field use: five tank modules dark together from the router
replacement while the BTU picos stayed alive, read off the journal
alone. The folder was renamed from `pico-state-journal-dev-rung` to
`pico-state-reported` to cover both halves, and the dev rung's laptop
artifacts (captures, harness, decoded instances, readback) were
dropped; the README keeps its findings.

## 2026-09-10 — gw108-ct-testing: cut to run 3 and the explanation; ci.sh green (`b0738bd`)

The folder now holds one run and why it matters. Run 3 at spruce (a
voltage CT on the CT4 connector, nothing on CT1) shows P0 reading 94 %
of the CT's signal with nothing attached; the RevB schematic and copper
say why: the four CT inputs return through one `1V65` node held by
nothing but two 100 kΩ resistors, so the node wobbles at 60 Hz by half
the CT's voltage and any shunted input reads the wobble. The README
walks the circuit step by step, states the fix (10 µF from `1V65` to
ground, shunts on used headers; Joe's CircuitLab reproduction agrees),
and the bench check before spruce is touched. The purpose of the CTs is
on/off detection, so that is the bar. The speed ladder (six
secondary-pump drive levels on one pass through the CT, 2026-09-07)
keeps its own `speed-ladder/` subfolder with a README that embeds the
7.5 V waveform and the ladder figure, both committed PNGs; its
`staircase.py` carries its own level label so `fold.py` can lose the
ladder-level lookup. Removed: the jumper and synth scripts, the other
26 spruce instances and the day's handoff, and `cycle.py` with its tie1
run (that run's one durable fact, that only CT1's header carries a
shunt, is in the README). The pre-prune
folder is kept outside git at `scratch/gw108-ct-testing-before-prune-2026-09-10`.

`ci.sh` is green again: the pyright exclusion list gains the
August–September scripts that import environments this repo lacks
(gwwf, gwbase, gnr, gwadmin, smbus2, paho, sqlalchemy), two real type
errors are fixed (`stub_fis.py`'s log_message signature; `staircase.py`
labelling a missing flow reading instead of dividing None), and the own-version decode of the
ads-noise reader instance is dropped with a note: that file records the
pre-regenesis word, which no snapshot carries any more.

## 2026-09-09 — gw108-ct-testing: folder renamed from adc-waveform-bench; spruce runs 1–7 in a dated subfolder; peek.py --channels (`e5f4f4f`)

The bench folder now carries the question it answers (which gw108 CT
inputs read what) rather than the first tool used. Today's seven
`peek.py` runs at spruce, with the CT arrangement changed between runs,
live in `2026-09-09-spruce-runs/` with a handoff README: three of the
four ADC inputs (P0, P1, P3) carry one signal whichever holds the CT, P2
is independent with a different bias, and the voltage-type CT was the
noise source. `peek.py` takes `--channels` so the own channel per phase
follows the CT placement. The eGauge CT moved to eGauge port 05 for the
secondary pump (tlayouts changelog has that side).

## 2026-09-08 — gw108-relay-stress: one folder per harness, honeysuckle run 3 (bench board clean) (`3942920`)

Third run of the relay-stress harness, on the bench gw108 (honeysuckle,
nothing on the relay contacts): B3 0/100, F3 0/30, A3 0/30 against
35/100 and 17/100 on spruce's two boards. The reset needs what spruce
hangs on the iso relay's contacts, not the board. Honeysuckle got its
first `~/experiments` clone, recorded in its box README.

The three relay-stress runs now share `2026-08-23-gw108-relay-stress/`:
the harness at the top, one dated subfolder per run with its own README,
a hub README with the runs table. The 08-23 and 09-08 spruce folders
moved under it; every path reference (logbook, ci.sh, the pump-speed
sweep and admin-panel READMEs, two wiki files) follows. The 08-23
instances keep their `spruce-relay-stress` ExperimentSlug, as recorded
at emission.

---

## 2026-09-08 — fis-gate-battery: the revocation group (CRL on the rig broker) (`84352c7`)

The replaced-pi case from the mTLS + FIS auth design (OPS-420): a
predecessor pi holds a still-valid cert with the same CN as its
successor, and the gate cannot tell them apart. `certs/gen_certs.sh`
now mints a second same-CN cert for weather and the scada and an empty
CRL; `certs/crl.sh` rewrites the throwaway CA's CRL (revoke by serial,
`--expired` for a one-second `nextUpdate`) into the hash-dir name
Erlang looks up. The rig broker mounts a `crl/` directory and an
`advanced.config`, `rig.py` gains the CRL, effective-`ssl_options`,
`StartedAt` and broker-log levers (local rig only), and `battery.py`
runs five revocation cases after the MQTT leg: the ping-pong on both
transports first, then refusal at the handshake on 5671 and 8883 with
FIS never asked and no restart, the newer cert admitted, the expired
list refusing everyone, a fresh list admitting again. 38/38, storm
100/100. Found on the first run: `advanced.config`'s `ssl_options`
REPLACES the conf file's rather than merging, so the whole TLS block
(material, tightening, `crl_check`, `crl_cache`) lives in
`advanced.config` and `rabbitmq.conf` carries no `ssl_options.*`; the
design's prod set-up sequence is corrected to match.

## 2026-09-07 — adc-waveform-bench: capture harness, fold, and the vendored gw.adc.waveform (`193f126`)

Rung `2026-09-07-adc-waveform-bench/` for the CT measurement chain
(OPS-518). `capture.py` runs on the pi (smbus2, bus 1, ADS1115 at 0x48)
in two modes, single-shot with OS-bit polling and continuous at 860 SPS
with change-detection dedupe, and writes a `gw.adc.waveform` instance
through the vendored class. `fold.py` fits the mains frequency on the
irregular samples by periodogram, folds onto one period and plots the
composite; `synth.py` makes the dry-run instance the fold must recover.
The snapshot seed gains `gw.adc.waveform`; numpy and matplotlib join
the deps for the fold. The regen also caught the snapshot up with sema
since 2026-08-13: the seed still pinned
`i2c.thermistor.reader.component.gt` at 000 and 003, versions the
squash folded into one 000, so the pin becomes the bare latest. That
broke the ads-noise emitter, which decoded its archived reader record
through the pre-squash 000 class: the record is in a wire shape no
current word carries (reference volts and series resistance on the
reader). The emitter now reads it as typed legacy evidence
(`LegacyThermistorReader`, with the note naming what retires it) and
its instances re-emit byte-stable. `fold.py` gains `--show` for the
interactive matplotlib window. Run 1 is honeysuckle with no CT installed, so
the expected picture is bias noise: it validates the sampling path and
the fold before a CT exists on spruce.

## 2026-09-06 — fis staging box: dropped (`2b2d189`)

The staging-box reproducer's timeline records the teardown: server,
primary IP and firewall deleted on Hetzner, the Route 53 record removed,
the cert-inventory rows retired. **Why:** the box existed for the gate
rehearsal, and the battery's green remote run closed that; the recipe
rebuilds it in a quarter hour if prod's cutover needs a twin again.

## 2026-09-06 — fis gate battery: remote run green against hw1-2 (`7b00342`)

`2026-09-05-fis-gate-battery/` grows a second rig. The battery and the
storm take their rig from the environment (`rig.py`): local is the
harness broker on this machine with a FIS process the battery owns, as
before; remote is a broker box with FIS under systemd, reached over ssh.
`remote.env` names the box (`hw1-2.electricity.works`, `hw1__2`, the
`hw1` identities); `setup-remote.sh` mints the identities' principal
rows on the box with the registry's ids and cuts their client certs on
certbot against the real CA (fetched, then removed from certbot);
`run-remote.sh` runs both scripts against the box. On the remote rig
FIS starts and stops through `systemctl` over ssh, the
management-API-down leg runs an ad-hoc `fis api` with a wrong management
password (launched with `setsid -f`: a trailing `&` left a subshell
holding the ssh session open), the broker's connection list comes from
`rabbitmqctl` in the box's container, the FIS database and `/ping` ride
an ssh tunnel, and the run's FIS log is the journal for a window opened
on the box's clock (this laptop runs 69 s ahead of the box). The README
carries the remote rig, its runbook, the findings and the timeline; the
green run's case log and storm summary sit beside it
(`battery-2026-09-06-hw1-2.log`, `storm-2026-09-06-hw1-2.json`); the
staging-box reproducer's timeline records step 9 done.
**Why:** the stand-up-fis design's verification is the battery green
against the staging box, not against a laptop broker: a real CA, real
TLS to a real host, FIS as the box runs it.

## 2026-09-06 — fis gate, and spruce pump speed sweep (`67323d7`)

The fis half (the spruce half is the pump-speed sweep session's): the
battery's second rig landed mid-flight, before the two harness fixes
and the record in `7b00342` above.

## 2026-08-23 — re-run spruce store charge valve experiment (`fb604d8`)

`2026-08-16-spruce-store-charge-valve/` re-dated to
`2026-08-23-spruce-store-charge-valve/` (the 08-16 runs were void — relay
not wired to the valve; artifacts in git history). New
`charge_valve_polarity.py`: legs D/E (iso closed + pump on, charge
de-energized / energized), witnesses independent of meter placement
(secondary temps + store-hot-pipe + tank1), dead-head guard ends a leg at
60 s of fresh zero flow, POR check with re-assert after every write;
results + log + `gw.experiment.run` + `gw.readings` pull.
The commit also carries the soak protocol (George's actuator timing:
slow to open, may not open against dead-head pressure) and the soak run:
charge energized 12 min with iso open and the pump circulating, then iso
closed — flow to 0 in ~90 s, store branch untouched.
**Why:** the day's charge_store runs showed the believed charge posture
fully stagnant; these runs killed the polarity AND timing/pressure
hypotheses — no condition moves water through the store, so the break is
physical (wiring/actuator/return path), on-site next.

## 2026-08-23 — spruce gw108 i2c relay stress tests (`1d5b816`)

New `2026-08-23-spruce-relay-stress/`: `relay_stress.py` (named runs
`--run <label>`, per-run log + typed results in `/home/pi/relay-stress-runs/`,
posture knobs for the non-toggled coils, i2c retries through a brownout),
`emit_instances.py` (`gw.experiment.run` per run), runs A–F with logs +
results, a `gw.readings` pull over the morning window, README with
the result table and a one-command-per-box reproduction. Logbook entry;
08-16 charge-valve folder + logbook marked superseded by the 08-20 on-site
result; `ci.sh` excludes the three pi-only spruce harnesses.
**Why:** the 08-20 observation that rapid iso toggling brings the OPS-452
reset. Found: energizing the iso relay with < 2 other 0x21 coils on resets
the chip (66 % per energize with none; 2/15 with one; 0 with two+); the
pump relay never trips it; spacing is irrelevant; the hack's start order
(clear all, iso first) is why it resets at start. Hardware evidence for
Joe plus a software ordering rule. The morning's exploratory sweep was
not kept (its charge-valve reading was a confound). The commit also
carries the 08-16 charge-valve folder's driver + `gw.readings` pull from
the earlier unsquashed commit.

## 2026-08-11 — README: name .env as the journal-DB access point (`d1f2413`)

**What:** Layout section gains a `.env` bullet (`GJK_DB_URL`, gitignored).

**Why:** journal-DB access for sessions and analysis scripts was
discoverable only in `pull_readings.py`'s docstring. The README now names
it, GridWorks_CLAUDE.md's "Journal DB first" maxim points here, and the
credential is gone from the Claude settings env block (single location).

## 2026-08-11 — ads-declared-rate spruce window: PASS + window harness (`45d50c4`)

**What:** the spruce rung of ads-declared-rate ran and passed: the
unlimbo scada booted on the real spruce thermistors (services stopped
for the window), zero i2c errors, zero readback mismatches, all four
zones publishing real temperatures; noise floors in the 8 SPS band
(zone4/garage modestly above). New in the folder: `window_boot.py`
(bounded real-hardware boot via the base `make_app_for_cli` — the
universe guardrail's designed test-boot exemption), `capture_window.py`
(laptop-side raw broker capture), `emit_window_instances.py` + the
run's instances, the boot log, capture, and archived persister events.

**Why:** the pre-promote EDD gate for the hardware-word closure needed
the declared-rate claim shown on the deployment silicon, not just the
bench. Two window catches recorded in the README: the unlimbo
LocalControl ScadaBlind path crashes on the Nolan layout (hard-coded
House0 store-pump-failsafe node), and the experiment env shared the
deployed scada's event persister (events archived here, removed from
the box before service restart; future windows set their own paths
name).

## 2026-08-10 — hp snafu and pico blackout postmortem (`e52e6eb`)

**What:** one squashed commit for the whole incident investigation:
`2026-08-10-hp-snafu-and-pico-blackout-postmortem/` — evidence and
reproducers for the spruce evening incident (the Samsung ignored a
physically-verified 20:00 cool call; the GridWorks wifi went off the
air at 17:04, stranding all six picos as zombies). Contents: three
`gw.readings` pulls (pico.blackout channels, hp.norun evening,
hp.baseline healthy week), 12 glitch instances decoded through the
vendored `glitch` word, frozen pi-side external evidence (journald
excerpts + wifi state), `archive_glitches.py`, `hp_power_analysis.py`,
`collect_pi_evidence.sh`, and a README that leads with the heat pump —
opening on the note that the two events are probably not related
through gw108 board issues — and closes with NEXT STEPS for the
OPS-492 field visit. The ads-declared-rate README + bench logs ride
along (interleaved in the squashed range).

**Why:** the live diagnosis ran as ad-hoc SQL and ssh probes; the
folder re-collects the evidence sema-first so the verdicts rest on
re-pullable, validated data. Wifi verdict: the router stopped
broadcasting the GridWorks SSID (the pi's own wlan0 lost it at
17:04:29, `ssid-not-found`) — the zombies are network-side, not pico
or 5 VDC. Heat-pump verdict (open, OPS-492): the witnessed 15:02/15:09
contact test proves the whole hack → 0x21 → RIB → B21 chain and 2091=1
authority, yet the unit stood down at ~16:00:00 with the contact still
closed and ignored the 20:00 call — the heat pump in one of two ways
(run-state fault, the 07-29 pattern; or half-applied settings) or the
post-pin wiring; the README's NEXT STEPS discriminate. NEXT STEPS-last
diverges from the README template at Jessica's request.

## 2026-08-10 — Semafy experiments (`6b2cc35`)

**What:** the whole repo becomes sema-typed — vocabulary, tooling, and
every folder — squashed from the day's clusters into one commit. Also
carries the gap-analysis README's "wifi-herd reduction" section: the
fancoil, pipes1, and floor1 picos disconnected (and de-layouted in
the 08-10 13:45 ET deploy) to see whether fewer wifi picos — same
router — changes the secondary-BTU pico's residual gap rate; the
de-layout was verified against the live layout emission, so the
zombie-shake confound Finding 1 documents is absent.

*Vocabulary + snapshot:* experiment data rides instances of the
staging vocabulary (`gw.experiment.run`, `gw.channel.gap.stats`,
`gw.channel.jump.stats`, `gw.channel.noise.stats`, `gw.readings`)
through the vendored `gwexp` snapshot; `gw.channel.gap.stats` coined
at sema `208cf81` (the jump-stats sibling thresholding on silence);
`glitch`/000 + its `log.level` enum vendored so journal glitch
payloads decode through the word (all 471 fleet payloads in the smoke
window validate), and the reader component rides
`i2c.thermistor.reader.component.gt/000`.

*Shared tooling:* `pull_readings.py` (archive → `gw.readings` instance
→ display CSV; `--condition` filename field; stage 1 reads layout.lite
from the journal DB — byte-identical re-pulls verified, boto3 dropped;
store policy: DB first, eventstore by hand), `naming.py` (bijection +
dash-grammar filenames; validators return the format types),
`unit_encodings.py`, `stats_display.py`. `ci.sh` covers new work by
default: pyright over every repo script (find + commented deny-list
for environment-bound and archived scripts), emitters via the
`*/emit_instances.py` glob reproducing committed instances
byte-for-byte, `sema validate` over every instance.

*Folders:* `ads-noise` + `spruce-no-cool-postmortem` fully sema-typed
(the pilot). `pico-gap-analysis`: the semafied floor2-removal
before/after — two condition-tagged pulls, 43 `gw.channel.gap.stats`
instances per window, verdict in README + logbook (spruce 104 →
17 gaps/day; the zombie-shake feedback loop CONFIRMED); all four
scripts under the sema-gravity maxim (NamedTuple records, property
formats on aliases / channel names / mapping keys / timestamps,
LiteralString-clean parameterized SQL). `pico-link-census`: typed
records, ssh failures no longer read as zero neighbors (`mac.address`
vendoring deferred to next regen). `pico-rejoin`: moves to the new
`future/<slug>/` convention — queued experiments sit undated until
first run. `registry-projection-rig`: forest broadcast decoded through
gnr's snapshot. June four: the `sim-time-experiment/` local workspace
ported in — harnesses + run evidence verbatim as archived records
(June-era APIs, deny-listed), paying the reproducer debt the
migration README owed; the workspace is now redundant.

**Why:** the database is storage, not truth — meaning lives in the
words, so units, channel identity, hardware facts, and message
payloads are read from sema instances, never from DB columns,
filename conventions, or hand-kept copies. Committed data is sema
instances + verbatim evidence only; the CI gate covers new work by
default instead of by remembering.
