# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-timecoordinator` code repo**. The matching git commit (in
`gridworks-timecoordinator`) holds the WHAT (the diff). Each entry's
date and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's own git history.

Newest at the top.

---

## 2026-07-04 — Track gwbase 0.5.6 (`047b530`)

**What:** `pyproject.toml` `gridworks-base>=0.5.2` → `>=0.5.6`; relocked.

**Why:** stay on the current published gwbase. 0.5.6 adds the `gnrmic_tx → amq.topic`
broadcast bridge (registry `g.node.forest` broadcasts reach MQTT-native actors) and
renames the definitions artifact `prod_definitions.json` → `hybrid_definitions.json`
(vhost = `<universe>__<run>`); nothing in the 0.5.2→0.5.6 span changes this repo's
consumed API. **Verified:** both tests passed on 0.5.6 (incl. the broker-gated one against gw-dev-rabbit).

## 2026-06-11 — From-scratch rebuild: tc-hello broadcasts sim.timestep

**What:** On branch `jm/hello-world` (off `legacy`): delete everything,
fresh uv scaffold (src layout, `gridworks-base>=0.5.2` from PyPI, pytest
+ ruff) and `gwtc.hello` — a `HelloTimeCoordinator(Orchestrator)` (NOT a
GNode: `ServiceSettings`, alias `d1.tc`, `TransportClass.TimeCoordinator`)
broadcasting `sim.timestep`, advancing `TimeUnixS` by `--step-seconds`
per `--beat-seconds` of wall time. Witnessed live test green against
gw-dev-rabbit: an observer queue on `timemic_tx` received consecutive
timesteps with advancing TimeUnixS.

**Why:** the hello-world design ([OPS-405](https://linear.app/gridworks/issue/OPS-405), Accepted · Pass 1) — the sim
stack needs a time authority, and gwbase built the seat for it
(control-plane `sim.timestep` reception + `send_ready()` already in
every Orchestrator-tier actor). Poetry-era first-pass code preserved on
`legacy`, mined for intent per the legacy-first-pass rule.
