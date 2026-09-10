# experiments — changelog

One entry per commit in the `experiments` code repo
(github.com/thegridelectric/experiments); git holds the *what*, this file
the *why*.

Newest at the top.

---

## 2026-09-10 — pico-state-reported: journalkeeper reads the cycler's per-pico roster on the dev broker <!-- pending commit -->

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

## 2026-09-10 — gw108-ct-testing: cut to run 3 and the explanation; ci.sh green <!-- pending commit -->

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

## 2026-09-09 — gw108-ct-testing: folder renamed from adc-waveform-bench; spruce runs 1–7 in a dated subfolder; peek.py --channels <!-- pending commit -->

The bench folder now carries the question it answers (which gw108 CT
inputs read what) rather than the first tool used. Today's seven
`peek.py` runs at spruce, with the CT arrangement changed between runs,
live in `2026-09-09-spruce-runs/` with a handoff README: three of the
four ADC inputs (P0, P1, P3) carry one signal whichever holds the CT, P2
is independent with a different bias, and the voltage-type CT was the
noise source. `peek.py` takes `--channels` so the own channel per phase
follows the CT placement. The eGauge CT moved to eGauge port 05 for the
secondary pump (tlayouts changelog has that side).

## 2026-09-08 — gw108-relay-stress: one folder per harness, honeysuckle run 3 (bench board clean) <!-- pending commit -->

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

## 2026-09-08 — fis-gate-battery: the revocation group (CRL on the rig broker) <!-- pending commit -->

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

## 2026-09-07 — adc-waveform-bench: capture harness, fold, and the vendored gw.adc.waveform <!-- pending commit -->

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

## 2026-09-06 — fis staging box: dropped <!-- pending commit -->

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

## 2026-08-11 — README: name .env as the journal-DB access point <!-- pending commit -->

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
