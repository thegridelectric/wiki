Status: Draft · Pass 0 · Updated 2026-09-07

# Running an LTN + SCADA from a checkout (cold start)

What this is: the go-to recipe for standing up a SCADA process and an LTN
process from a gridworks-scada checkout — the first stop for any Claude
(or human) who needs the things *running*, not just tested. Dry-run path
AND the scada leg of the live-broker path verified 2026-06-10 on
`jm/spruce-unlimbo` (see "Verified live run" below); the LTN leg is
`told` from [`experimentation-rig.md`](experimentation-rig.md) and the
README until the hello-world verification pass (in the spruce-unlimbo
design) confirms the pair end to end.

## 0 · Environment

Venv + editable packages per [`environment.md`](environment.md):
`./tools/mkenv.sh`, then

```sh
source gw_spaceheat/venv/bin/activate
export PYTHONPATH=$PWD/gw_spaceheat:$PYTHONPATH
```

## 1 · `.env` and the hardware layout

Both processes are configured by `.env` (copy `.env-template` if absent)
and refuse to start without a loadable hardware layout:

```sh
SCADA_PATHS__HARDWARE_LAYOUT="tests/config/nolan-layout.json"
LTN_PATHS__HARDWARE_LAYOUT="tests/config/nolan-layout.json"
```

- Available test layouts: `tests/config/nolan-layout.json` (spruce/Nolan
  scheme) and `tests/config/house0-layout.json` (House0 scheme).
  **`hardware-layout.json` no longer exists** (renamed on the spruce
  branch line) — a `.env` pointing at it fails with `FileNotFoundError`.
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

- The LTN expects its own config dir: copy the hardware layout to
  `~/.config/gridworks/ltn/hardware-layout.json` by hand (the framework
  only auto-isolates XDG dirs under pytest).
- Without `LTN_SCADA_MQTT__TLS__USE_TLS=false` it resolves TLS cert
  paths under `~/.config/gridworks/ltn/certs/…`.

## Verified live run (2026-06-10, scada leg)

`gws run` on `jm/spruce-unlimbo`, nolan layout, `SCADA_IS_SIMULATED=true`,
against `gw-dev-rabbit` (the **preferred dev broker for running** —
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

## Experiment window on a deployed box

A branch scada run on a deployed box (a "window": stop the services, boot
the branch against the real plant, restore) keeps staging vocabulary off
the production broker through three layers, and a window holds all three.

1. **Status tier.** A staging layout cluster means dev brokers only. The
   check is by hand today: every gwsproto schema pin and every word in
   the closure copy (`sema_closure/registry.yaml`) against the registry's
   status; `gwsproto_sema_conformance.py` has no release-gate flag. A
   branch pinning non-published words cannot deploy beyond dev until they
   promote.
2. **Credential-structural.** The window scada keeps the box's real
   identity but boots from `~/envs/dev.env`: dev-broker credentials only,
   upstream host a localhost tunnel (`ssh -f -N -R 1885:localhost:1885
   <box>`), never prod credentials, so staging-typed payloads physically
   cannot reach the prod broker. The universe guardrail would refuse a
   prod identity on localhost at a real boot; the harness runs inside its
   test-boot exemption.
3. **Paths-structural.** Boot through the window harness
   (`WindowScadaApp`, `experiments/2026-08-10-ads-declared-rate/
   window_boot.py`): its `paths_name()` override is the only paths-root
   override that survives app construction, and it refuses to boot if the
   event or log dirs resolve outside `~/.config/gridworks/scada-experiment/`.
   Env-only overrides (`SCADA_PATHS__NAME`) are silently discarded. This
   keeps the window's un-acked events out of the deployed scada's
   persister.

Window protocol on top of the layers: stop everything on the bus
(`gwspaceheat-restart.timer`, `gwspaceheat`, any hack service; the transient
timer restores them). Before restarting the deployed scada, remember its
persister replays every un-acked event in its event dir to whatever broker
it connects to (`start_reupload` on link-up): verify the deployed event dir
(`~/.local/share/gridworks/scada/event/`) holds nothing window-born and
archive-then-delete anything that is. One shutdown event once rode a
deployed scada's startup reupload to prod and S3 through a shared paths
root. Command senders run on the box itself from its `~/experiments` clone
at a pushed SHA against `localhost:1883`; a window must not depend on a
laptop tunnel, which can die silently. Stopping services, placing env
files and restarting are the human's to run; a session preps the commands
and the watch-list.

## Open

- The full live bidirectional LTN↔SCADA run over dev rabbit (with a JK
  consuming) is not yet verified cold — that pass is the hello-world
  step of the spruce-unlimbo design; its findings reconcile here.
- Whether a SCADA on the nolan layout needs Scada2/local_mqtt presence
  to run live, or runs degraded without it.
- `gws run_s2` (Scada2) is undocumented here — add when first needed.
