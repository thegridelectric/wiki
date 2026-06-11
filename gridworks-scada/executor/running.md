Status: Draft · Pass 0 · Updated 2026-06-10

# Running an LTN + SCADA from a checkout (cold start)

What this is: the go-to recipe for standing up a SCADA process and an LTN
process from a gridworks-scada checkout — the first stop for any Claude
(or human) who needs the things *running*, not just tested. Dry-run path
verified 2026-06-10 on `jm/spruce-unlimbo` (`dab55d20` + the
nolan-layout version fix); live-broker steps are `told` from
[`experimentation-rig.md`](experimentation-rig.md) and the README until
the hello-world verification pass (tracked in the spruce-unlimbo design)
confirms them end to end.

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

## Open

- The full live bidirectional LTN↔SCADA run over dev rabbit (with a JK
  consuming) is not yet verified cold — that pass is the hello-world
  step of the spruce-unlimbo design; its findings reconcile here.
- Whether a SCADA on the nolan layout needs Scada2/local_mqtt presence
  to run live, or runs degraded without it.
- `gws run_s2` (Scada2) is undocumented here — add when first needed.
