# gwbase upgrade sweep

Status: Draft · Pass 0 · Updated 2026-11-12 · Linear: OPS-674

**EDD: no** a dependency bump across nine repos; verified by each repo's
`ci.sh` against the dev broker, then each deployed service rolled from a
pushed `main` SHA and seen connecting and handling its first message.

> What this is: every gwbase consumer moves to gridworks-base 0.7.3 with
> a `<0.8` ceiling, so the fleet runs one gwbase era and no pin admits a
> breaking release it was not written against.

## Why

The consumers sit on five gwbase versions, from 0.5.14 to 0.7.3. Two
releases in that range break subclasses: 0.6.0 adds a `header` argument
to every `Orchestrator.process_message`, and 0.7.0/0.7.1 make
`GridworksActor` take a required `g_node_class` and derive its transport
class from it. Three repos pin `>=0.5.15` with no ceiling, so a routine
`uv lock --upgrade` would pull 0.7.3 into code written for 0.5 and fail
at startup. Two of them, the registry and the weather service, are live.

The ear gains the most. It consumes all of `ear_tx` from Helsinki
against the us-east broker with a prefetch of 1, about 9 messages a
second at 110 ms round trip; the gwbase changelog estimates it falls
behind at 300 to 450 homes. 0.5.17 makes prefetch a setting with a
default of 100.

What each consumer picks up, by release (full entries in the gwbase
changelog):

| Release | Change | Matters to |
|---|---|---|
| 0.5.15 | `user_id` stamped on every publish; a GNode re-reads its alias from gnr before reconnect | ear |
| 0.5.16 | `stop()` ends the reconnect loop even when `local_stop` skips the base hook | ear |
| 0.5.17 | `prefetch_count` setting, default 100 | ear |
| 0.6.0 | framework unwraps `gw` bodies; `process_message(*, envelope, body, header)` | every Orchestrator below 0.6 |
| 0.7.0, 0.7.1 | `GridworksActor(g_node_class=...)`; transport class derived | every GridworksActor below 0.7 |
| 0.7.2 | LTN and FLO routing edges | broker definitions only |
| 0.7.3 | `log_tz` setting: log timestamps in the service's zone with offset | all |

## The change, per repo

Each repo gets the pin `"gridworks-base>=0.7.3,<0.8"`, a relock, the
code changes listed, a green `ci.sh` and one pending changelog entry in
its wiki domain. Order runs from no code change to the most.

| # | Repo | Locked now | Base class | Code change | Deployed on | Changelog |
|---|---|---|---|---|---|---|
| 1 | gridworks-ear | 0.5.14 | ActorBase | none expected; rewrite the pin comment | `ear` box, two units (`ear`, `gnr-ear`) | `wiki/ear/` |
| 2 | gridworks-shovel | 0.5.17 | ActorBase | none expected | `rmqtap` | `wiki/shovel/` |
| 3 | gridworks-journalkeeper | 0.6.0 | ActorBase | none expected | `gjk` | `wiki/gridworks-journalkeeper/` |
| 4 | gridworks-alerter | 0.6.0 | Orchestrator | none expected | `alerts` | `wiki/gridworks-alerter/` |
| 5 | gridworks-marketmaker | 0.7.1 | GridworksActor | none | `mm` | `wiki/gridworks-marketmaker/` |
| 6 | gridworks-timecoordinator | 0.7.1 | GridworksActor | none | not deployed | `wiki/gridworks-timecoordinator/` |
| 7 | grid-node-registry | 0.5.15 | Orchestrator ×2 | `process_message` signature | `gnr` | `wiki/grid-node-registry/` |
| 8 | gridworks-weather-forecast | 0.5.15 | GridworksActor + Orchestrator | signature, `g_node_class`, identity file | `forecast` | `wiki/gridworks-weather-forecast/` |
| 9 | gridworks-terminalasset | 0.5.15 | GridworksActor | signature, `g_node_class` | not deployed | `wiki/gridworks-terminalasset/` |

gridworks-flo and gridworks-ltn are already on 0.7.3. gridworks-ps has
no gwbase dependency.

### Notes by repo

- **ActorBase repos (1–3).** ActorBase changed only additively from
  0.5.14 to 0.7.3 (`git -C gridworks-base log 9ba2b96..815fe14 --
  src/gwbase/actor_base.py` lists four commits). The ear overrides
  `bind_queue`; confirm the base bind flow it mirrors is unchanged.
  Prefetch is set by `EAR_PREFETCH_COUNT`, `SHOVEL_PREFETCH_COUNT`,
  `GJK_PREFETCH_COUNT`; the default of 100 needs no `.env` line.
- **gridworks-ear.** The pyproject comment above the pins says upgrades
  are a separate deliberate change. This is that change; the comment is
  rewritten to say what the pins are now. The local checkout is two
  commits behind `origin/main`; pull before branching.
- **gridworks-journalkeeper.** Cut the upgrade branch from `main`. The
  open feature branch picks it up by merging `main`.
- **gridworks-marketmaker.** The local `main` is stale; `origin/main`
  already has the 0.7.1 commit. Pull first.
- **grid-node-registry.** `GnrRabbit.process_message` and the CLI's
  `_OperatorPublisher.process_message` both take the new `header`
  keyword. Commands arrive bare today, so `header` is `None` in practice;
  the framework now drops a wrapped body that fails to unwrap.
- **gridworks-weather-forecast.** `WeatherActor` drops
  `transport_class=` and passes
  `g_node_class=GwGNodeClass.WeatherForecastService`; `_MintPublisher`
  takes the new signature. 0.7.0 checks `g_node_class` against the
  identity file's `GNodeClass` at boot. The dev identity file
  `scripts/dev-g.node.gt.json` has `"GNodeClass": "weather"`, which will
  be refused. Fix the dev file, read the identity file on the forecast
  box before rolling, and check what the registry row for `hw1.weather`
  holds.
- **gridworks-terminalasset.** Default branch is `dev`; no `ci.sh`, so
  the gate is the test suite. `HelloTerminalAsset` passes
  `g_node_class=GwGNodeClass.TerminalAsset` and takes the new signature.

## Rollout

Code-repo work follows the branch rule (`jm/gwbase-0-7-3` per repo) and
the human commits. A deployed service rolls only from a pushed `main`
SHA, with `gridworks-infra/tools/box-deploy.sh <box>` after reading the
box's `instance-README.md`. After each roll, the service's journal shows
the connect line (host, port, vhost) and its first handled message
within one normal message interval.

Roll the ear first, one unit at a time. Roll the registry before the
weather service, since the weather service reads gnr.

## Decisions for the human

- **`log_tz` per service.** 0.7.3 defaults to UTC. Setting
  `<PREFIX>_LOG_TZ=America/New_York` in each box `.env` matches the FLO.
  The `.env` change is box state and goes in the instance-README.
- **Weather identity class.** If the box identity file or the registry
  row says `weather`, changing it to `WeatherForecastService` is a
  registry data change, outside a dependency bump.
