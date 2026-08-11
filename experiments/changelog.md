# experiments — changelog

One entry per commit in the `experiments` code repo
(github.com/thegridelectric/experiments); git holds the *what*, this file
the *why*.

Newest at the top.

---

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
