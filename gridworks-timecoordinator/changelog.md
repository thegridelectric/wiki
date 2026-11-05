# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-timecoordinator` code repo**. The matching git commit (in
`gridworks-timecoordinator`) holds the WHAT (the diff). Each entry's
date and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's own git history.

Newest at the top.

---

## 2026-11-04 — The time coordinator is a GNode; ci.sh is the one gate (`befe546`, on `dev`)

**Why.** The registry holds `hw1.time` as a GNode of class
`TimeCoordinator` and gridworks-base 0.7.1 puts the class on the
`GridworksActor` tier, while the hello actor still called itself not a
GNode, rode `ServiceSettings`, read `GWBASE_*` variables against the
one-env-one-prefix rule, and defaulted to `d1.tc` where the registry
rule says `<universe>.time`. The repo also had no gate: no `ci.sh`, no
workflow, no pyright.

**What.** `GwtcSettings(GNodeSettings)` with the `GWTC_` prefix, alias
`d1.time`, `super_alias`; `HelloTimeCoordinator` is a `GridworksActor`
declaring `GwGNodeClass.TimeCoordinator`; the test writes a dev identity
file; the README says what the coordinator is. `ci.sh` runs the locked
sync, ruff, pyright, the unit tests and the live test when a broker
answers; the workflow is checkout, uv and `./ci.sh` with the dev-rabbit
service. Pin `gridworks-base>=0.7.1`; the lock updates when that release
exists. The Ready barrier stays Open.

## 2026-10-09 — Track gwbase 0.5.15 (`7528e95, on `dev``)

The floor was 0.5.6; the lock resolves to 0.5.15 so the simulation runs on the same gwbase as the fleet (`user_id` on publish, OPS-579).

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
