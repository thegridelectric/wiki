# Coverage map

Living inventory of `gridworks-scada` and how far each part has been
documented. Status legend: `untouched` → `mapped` → `documented` → `verified`
(see `PROCESS.md`). Pick the next discovery pass to maximize coverage of
load-bearing code.

Last updated: 2026-05-21.

> **Terminology:** `atn` / `AtomicTNode` is **always legacy** — wherever it
> appears in code or in-repo docs, read it as the **LeafTransactiveNode (LTN)**,
> which is the current concept. The LTN is being separated out of this repo into
> a rabbit-native extension of gridworks-base; its presence here (`ltn_app.py`,
> `actors/ltn/`) is temporary, not a permanent actor subpackage.

## Entry points & apps (`gw_spaceheat/`)

| File | Lines | Role (first impression) | Status |
|---|---|---|---|
| `run_scada.py` | 6 | thin launcher | untouched |
| `scada_app.py` | 163 | primary `ScadaApp` (gwproactor host) | untouched |
| `scada2_app.py` | 106 | `Scada2` LAN-side app | untouched |
| `ltn_app.py` | 119 | LeafTransactiveNode app — **temporary home**, migrating to a rabbit-native extension of gridworks-base | untouched |
| `scada_app_interface.py` | 30 | app interface ABC | untouched |
| `cli.py`, `command_line_utils.py` | — | `gws` CLI | untouched |

## Actors (`gw_spaceheat/actors/`)

| File | Role (first impression) | Status |
|---|---|---|
| `scada.py` | the **PrimeActor**: top-level state machine, link routing, reporting | untouched |
| `contract_handler.py` | DispatchContract/heartbeat lifecycle with LTN | **mapped** → see [[../components/contract-handler]] |
| `scada_data.py` | report/snapshot data accumulation | untouched |
| `scada_interface.py` | Scada ABC | untouched |
| `secondary_scada.py` | Scada2 prime actor | untouched |
| `power_meter.py`, `multipurpose_sensor.py`, `api_*_module.py` | sensing actors | untouched |
| `relay.py`, `i2c_*` , `zero_ten_outputer.py` | actuation actors | untouched |
| `hp_boss.py`, `sieg_loop.py`, `pico_cycler.py` | control actors | untouched |
| `hubitat*`, `honeywell_thermostat.py`, `gpio_sensor.py` | device integrations | untouched |
| `leaf_ally/`, `local_control/`, `procedural/` | actor subpackages | untouched |
| `atn/` | **LEGACY** — `atn`/`AtomicTNode` is always old terminology, superseded by LeafTransactiveNode (LTN) | untouched |
| `ltn/` | **NOT an actor subpackage** — temporary location for the LeafTransactiveNode, migrating to a rabbit-native extension of gridworks-base | untouched |
| `sh_node_actor.py`, `pico_actor_base.py`, `subscription_handler.py` | actor base/util | untouched |
| `codec_factories.py`, `config.py` | wiring/settings | untouched |

## Boundary protocol & subpackages

| Path | Role | Status |
|---|---|---|
| `packages/gridworks-scada-protocol` (`gwsproto`) | Sema boundary types exchanged with LTN/Scada2/admin | untouched |
| `packages/gridworks-admin` (`gwadmin`) | textual admin UI (local-MQTT, tailscale-trust) | untouched |
| `gw_spaceheat/layout_gen/` | builds hardware-layout JSON (actor graph source of truth) | untouched |
| `gw_spaceheat/drivers/` | hardware drivers | untouched |

## Existing in-repo docs (evidence, not ground truth — verify)

| File | Freshness | Note |
|---|---|---|
| `CLAUDE.md` | current | accurate architecture summary; good evidence |
| `docs/architecture-overview.md` | **stale** | references "winter 2022-2023", Nolan house — F-001 |
| `docs/*` (hardware-layout, hierarchical-state-machines, representation-contract, …) | unknown | not yet assessed |
| top-level `old_words/` | historical | Algorand-era vocabulary; superseded by mTLS direction — context for [[../concerns/deeds-and-trading-rights]] |

## Open questions parked for later

- Is the LTN (`ltn_app.py`, `actors/ltn/`) in scope for this wiki, or does it get
  its own `wiki/gridworks-ltn/` once split to native rabbit? (User: LTN is being
  separated and moved to native rabbit; see [[../concerns/transport-and-links]].)
- Which `scratch*.py` files at `gw_spaceheat/` root are live vs. dead?
