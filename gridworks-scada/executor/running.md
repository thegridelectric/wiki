Status: Draft · Pass 0 · Updated 2026-10-26

# Running an LTN + SCADA from a checkout (cold start)

What this is: the go-to recipe for standing up a SCADA process and an LTN
process from a gridworks-scada checkout — the first stop for any Claude
(or human) who needs the things *running*, not just tested. Dry-run path
AND the scada leg of the live-broker path verified 2026-06-10 on
`jm/spruce-unlimbo` (see "Verified live run" below); the LTN leg is
`told` from [`experimentation-rig.md`](experimentation-rig.md) and the
README until a cold live run of the pair confirms it end to end.

## 0 · Environment

Venv + editable packages per [`environment.md`](environment.md):
`./tools/mkenv.sh`, then

```sh
source gw_spaceheat/venv/bin/activate
export PYTHONPATH=$PWD/gw_spaceheat:$PYTHONPATH
```

## 1 · `.env` and the hardware layout

Both processes are configured by `.env` (copy `.env-template` if absent)
and refuse to start without a loadable hardware layout. `.env` names no
layout paths: each process resolves its files by their deployed names in
its config folder, as on a box.

| Process | Folder | Files |
|---|---|---|
| scada | `~/.config/gridworks/scada/` | `hardware-layout.json`, `operational-params.json`, `ta-deed.json` |
| LTN | `~/.config/gridworks/ltn/` | `hardware-layout.json`, `operational-params.json` |

`experiments/put_layout.sh dev <change>` seeds both folders from the Nolan
sim fixtures in `tests/config/` (`gw.nolan.*`), renaming at the copy and
checking the sha256; `put_layout.sh dev check` compares without writing.

- A missing `ta-deed.json` stops the boot unless the params word refuses
  dispatch with reason `NoTaDeed` (or is in Standby); with that word the
  scada sends a `no-ta-deed` Warning glitch at startup, runs UnValidated
  and refuses every LTN contract offer through the leaf-ally gate
  (`local-control.md` "The dispatch refusal").
- `tests/config/` also holds two House0 sim pairs with their deeds
  (`gw.house0.orange.*`, `gw.house0.willow.*`), which `put_layout.sh dev`
  does not place.
- On the spruce branch line use the nolan layout; House0 relay actuation
  is disabled there (see the spruce-unlimbo design).
- Layout named-type `Version` strings must match the checked-out code's
  pydantic literals — a version-bump commit that misses a layout JSON
  shows up as `ValidationError: Input should be '003'` at load.

## 2 · Dry run first (no broker needed)

```sh
gws config          # resolved settings — check hardware_layout path
gws run --dry-run   # SCADA: loads layout, prints settings, exits
gws ltn run --dry-run
```

Both dry-runs passing means layout + settings are coherent; every
problem so far (missing layout file, version mismatch) is caught here.
`gws ltn --help` shows the LTN subcommands (`config`, `run`).

## 3 · Live run — pick a broker

**(a) Local mosquitto — lightest, SCADA-side only:**

```sh
mosquitto -c tests/config/local_mosquitto.conf -v &
gws run
```

(Stop any Homebrew mosquitto service first; ports collide.)

**(b) `gw-dev-rabbit` — for LTN↔SCADA↔JK experiments:** broker facts
(ports 5672/1885/15672, vhost `d1__1`, anonymous → `smqPublic`, MQTT
bridged to `amq.topic`) and the JK-observer recipe live in
[`experimentation-rig.md`](experimentation-rig.md). Point each side at
it with the TLS-off overrides that sit commented in `.env-template`:
`SCADA_GRIDWORKS_MQTT__{HOST=localhost,PORT=1885,…,TLS__USE_TLS=false}`
and `LTN_SCADA_MQTT__{…same…}`.

## 4 · LTN specifics (known friction)

- The LTN reads its own config dir, `~/.config/gridworks/ltn/`, which
  `put_layout.sh dev` seeds (section 1).
- Without `LTN_SCADA_MQTT__TLS__USE_TLS=false` it resolves TLS cert
  paths under `~/.config/gridworks/ltn/certs/…`.

## Verified live run (2026-06-10, scada leg)

`gws run` on `jm/spruce-unlimbo`, nolan layout (sim-ness comes from the
fixture, there is no flag), against `gw-dev-rabbit` (the **preferred dev broker for running** —
mosquitto is for pytest): all three links connect and reach
`awaiting_peer` (see [`scada-ltn-link-state.md`](scada-ltn-link-state.md));
GpioSensor zone actors, DerivedGenerator, LeafAlly all run. Two
current caveats:

- **`LocalControlTouBase.main` crashes at startup** on the nolan layout
  (`'NoneType' object has no attribute 'handle'` — a House0 relay node
  the layout lacks), and ~3.5 min later the **watchdog shuts the whole
  process down** (dead actor → keepalive stops → monitored-communication
  shutdown, as designed for systemd restart). Fix in flight in the
  spruce-unlimbo design (simulated-actors spoke).
- A stale persisted `SlowContractHeartbeat` v000 in the state dir is
  rejected loudly by the now-v001 literal and ignored — harmless; clear
  `~/.local/share/gridworks/scada/event/` remnants if the noise bothers.

## Rolling a house between lines

`scripts/roll.sh <house> check | forward | to <scada-branch> | back`,
run from the laptop, is the one way a deployed house moves between
scada lines; `forward` is `to main`, and the roll-back
path is the same script as the roll-forward.

A house's LTN and scada run on exactly the same branch, at the same
pushed SHA. The LTN is a checkout of this repo on the `ltn` box
(`~/ltn-<house>/gridworks-scada`, run by the systemd unit
`gwltn@<house>` from `service/gwltn@.service`;
`gridworks-infra/ltn/README.md`), and a roll moves it with the pi:
`to` and `back` fast-forward both checkouts and restart the LTN's unit
before the pi's service, and `check` compares both against the line's
record. The unit runs `LtnApp.main` with the dashboard off
(`LTN_DASHBOARD__PRINT_GUI=false`); the tests are
`tests/test_misc/test_roll_ltn.py`, with a stub `ssh` for the boxes.
The lines are `main` (the spruce-unlimbo line), `legacy` (the line the
House0 houses ran before it, with the winter's fixes),
`td/generalized-flo` (oak's LTN work) and `actual-spruce` (spruce's
winter hack). `forward` goes to `main`; `back` goes to the house's
roll-back line. On `main` the LTN
loads the same layout ⊕ operational-params pair as the scada, from
`~/ltn-<house>/.config/gridworks/ltn/`, and the roll verifies and
installs it there as it does on the pi. `check` fails when either box
is behind the pushed tip of its line or the two SHAs differ. A scada
paired with an LTN on another line has every Report go un-acked, and
its link flaps for as long as the pair stands
(`experiments/2026-10-22-spruce-roll-rehearsal/`).

Each scada branch has a tlayouts branch, and that branch's committed
`output/<house>/` JSON is the record of what the house runs
(`wiki/tlayouts/executor/primary.md` "Temporary authority"): `main`,
`legacy` and `actual-spruce` read the tlayouts branch of the same name,
and `td/generalized-flo` (the FLO work, which changes the LTN and not
the layout) reads `legacy`. The script
reads the record from the tlayouts *remote* after a fetch, so only
pushed JSON reaches a box whatever the laptop's checkout is doing, and
moves each pi's `~/gridworks-scada` only by fast-forward to the pushed
SHA of the branch. A dirty or diverged box checkout refuses.

The pair is verified before the service restarts. A layout matches byte
for byte. On `main` the operational-params file matches
outside its `DispatchHold` block, which the scada writes itself (the
cold latch sets `ServiceContractBroken` in
`actors/scada.py` `process_break_service_contract`; an operator hold
sets `OperatorHold`); the other lines do not read the ops word and the
file is left alone. The rules are `scripts/roll_compare.py`, with tests
in `tests/test_misc/test_roll_compare.py`. A pi whose file differs shows
the differing paths and takes the committed file only on a `y`, with
its own kept as `<stem>.<date>-pre-roll.json`. Every house but spruce
has a second pi, `<house>2`, whose `gwspaceheat2` reads
`~/.config/gridworks/scada2/`. A second pi is left alone by a roll: its
checkout does not move and its service is not restarted, and its layout
is compared on the part scada2 senses (the `s2` node and its hierarchy,
their components and cacs, the channels those nodes capture); a
difference there stops the roll, and the fix is made by hand.

Stored events do not cross lines. The scada persists every event it has
not had acked (`~/.local/share/gridworks/scada/event/`) and re-sends
them on each link-up; an event one line's scada wrote is never acked by
the other line's LTN, and the link flaps on it at every ack timeout,
sending a `layout.lite` on each return to active. So the roll stops the
service, sets the event folder's contents aside as
`event.<date>-pre-roll-to-<branch>/`, and starts it. Verified on spruce
2026-10-22 (`experiments/2026-10-22-spruce-roll-rehearsal/`), which is
also where a branch scada paired with the other line's LTN was seen to
flap for as long as it ran.

Two guards stop the roll before the checkout: a difference in
`gw_spaceheat/requirements/` between the SHAs (the venv is rebuilt by
hand on the box with `tools/mkenv.sh`), and a difference in `service/`
unit files (root reinstalls them with `service/install`). Spruce's
winter hack (`spruce-winter-hack.service`) is the plant controller on
`actual-spruce`: the script disables it when spruce leaves that line and
enables it when spruce returns, so a reboot never runs two controllers.

`back` goes to the house's roll-back line: `actual-spruce` for spruce,
`td/generalized-flo` for the houses in the script's `THOMAS_LTN` list
(oak), `legacy` for the rest.

The `legacy` and `actual-spruce` layout gens run from the laptop's
`legacy` worktree of the scada repo, `GridWorks/scada-legacy`
(`environment.md`).

**No roll to beech (2026-10-20).** Beech is unwell in the field. Do NOT
roll it until this line is removed.

A roll puts words on the production broker, so every word that crosses
the wire is published before a box speaks it, with the closure words it
`$ref`s; a word that only lives in the layout file on the box may stay
staging. The check is by hand: every gwsproto schema pin and the scada's
sema snapshot (`packages/gridworks-scada-protocol/sema_snapshot/`, its
`indexes/staging.yaml` lists the staging words) against the registry's
status; `gwsproto_sema_conformance.py` has no release-gate flag.

Reading a house after a roll, learned in the beta field windows of
2026-09 and 2026-10 (record: `experiments/beta-field-windows/`):

- Start the bus capture before the first actuation and run it past the
  last expected one, and prove the subscriber connects before anything
  is switched on; a capture that starts late witnesses nothing.
- Two clocks: the box clocks run about 70 s behind the laptop. Event
  filenames are UTC, log lines are box-local ET, and a timeline written
  on the laptop is laptop time. Say which clock every stamp is on.
- A layout's `DataChannels` and `DerivedChannels` together are the
  names a report can have; count channels against both lists.

## Open

- The wire-word versus layout-file-only split for the spruce branch has
  not been drawn yet.
- The full live bidirectional LTN↔SCADA run over dev rabbit (with a JK
  consuming) is not yet verified cold; its findings reconcile here when it runs.
- Whether a SCADA on the nolan layout needs Scada2/local_mqtt presence
  to run live, or runs degraded without it.
- `gws run_s2` (Scada2) is undocumented here — add when first needed.
