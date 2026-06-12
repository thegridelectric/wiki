# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-scada` code repo**. The matching git commit (in
`gridworks-scada`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-06-11 — Green the test suite: House0 AsyncCaptureDelta + local test dotenv wiring (`b3cf2c4b`)

**What:** Two coupled fixes landed together so `pytest` passes both
locally and in CI on `jm/spruce-unlimbo`:

1. **AsyncCaptureDelta restored to House0 layout.** `dab55d20` bumped
   `RelayActorConfig` to `003`, which *enforces* Axiom 1 (if
   `AsyncCapture` is true, `AsyncCaptureDelta` must exist — and the
   check is `not AsyncCaptureDelta`, so both absent and `null` fail),
   but only `nolan-layout.json` got the values. Added
   `AsyncCaptureDelta: 1` to the 14 relay configs in
   `tests/config/house0-layout.json` that lacked the key (relays are
   binary state, so a delta of 1 captures every change, matching
   nolan's relays). This is the bug behind CI's two `value_error`
   failures on `relay18`. `tests/config/layout-lite.json` carries the
   same `null` deltas but is loaded through the lite path, which does
   not exercise the axiom in any test — left untouched on purpose, since
   the goal was a green suite, not a speculative edit.

2. **Local test dotenv actually loads now.** `tests/conftest.py` declared
   `TEST_DOTENV_PATH` / `TEST_DOTENV_PATH_VAR` but never wired them, so
   `gwproactor_test` fell back to its own default name and loaded nothing.
   The LTN broker (`scada_mqtt = MQTTClient()`, `tls.use_tls` defaults
   True) then tried TLS against the plain local mosquitto and hung —
   every scada↔LTN link test timed out after 10 s. conftest now sets
   `GWPROACTOR_TEST_DOTENV_PATH` so the repo's local config loads, and
   `tests/.env-gw-spaceheat-test` is committed (copied from
   `tests/config/.env-local`, TLS off) and removed from `.gitignore` —
   the test rig should travel with the repo, not be hand-created per
   checkout. CI still overwrites it from `.env-ci` (TLS on, with certs),
   so CI keeps exercising the TLS path.

**Why:** the branch's tests were red both locally (link timeouts) and in
CI (the axiom failures). The merge `bb4f6294` was an early suspect but
was a red herring — the regression is the config-version bump that
enforced the axiom without backfilling House0, plus a long-standing dead
dotenv wiring that only bites a fresh checkout with no local rig.

## 2026-06-11 — Sim-time bridge: scada-side sim.timestep listener (OFI) (`aa802567`, PR #571)

**What:** On branch `jm/sim-time-bridge` (off `jm/spruce-unlimbo`): a
minimal listener that subscribes over MQTT to the time coordinator's
`sim.timestep` broadcasts, parses the JSON directly (deliberately
bypassing the gwsproto codec — OFI: interim, dies in the uv/AllyLink
rebuild), tracks latest sim time, and triggers the link keepalive per
the bridge plan (1-minute timesteps feed ping/ack; existing scada/LTN
stay wall-clock).

**Why:** the sim-time spoke of the simulated-test-environment design
(OPS-40, hub + spoke Accepted · Pass 1 2026-06-11) — the simplest
scada-side hook for the bridge, per the decision to keep scada sim-time
machinery minimal until the rebuild.

## 2026-06-11 — Merge branch 'dev' into jm/spruce-unlimbo (`bb4f6294`)

**What:** Merge commit bringing the branch up to current dev (docs
additions, standby/ltn/sieg_loop updates). One conflict,
`tests/config/nolan-layout.json` (both-added): resolved keeping the
branch's version-bumped copy — RelayActorConfig `003` /
I2cThermistorChannelConfig `001` — over dev's stale `002`/`000`; only
those four Version lines differed.

**Why:** keep the spruce-unlimbo working branch current with dev per
its own design ("merge dev forward regularly"), and as the base for
the upcoming sim-time bridge work, which branches off
`jm/spruce-unlimbo`. The branch's bumped config versions are the ones
its post-glean code requires (the poison-message lesson: stale-version
payloads against post-bump code).

## 2026-06-10 — Bump nolan-layout config versions to match RelayActorConfig 003 / I2cThermistorChannelConfig 001 (`77d882ac`)

**What:** In `tests/config/nolan-layout.json`: the
`gw108.vdc.relay.component.gt` ConfigList entry 002→003
(RelayActorConfig) and the `i2c.thermistor.reader.component.gt`
component 000→001 + its two ConfigList entries 000→001
(I2cThermistorChannelConfig). Version strings only; the bumped types
added validators, no new required fields.

**Why:** The `2b603cc0` glean cherry-pick bumped these type versions and
updated `house0-layout.json`, but `nolan-layout.json` didn't exist on
`jm/spruce-new`, so the pick couldn't touch it — leaving every
nolan-layout load (and therefore `gws run` and the whole test suite,
which conftest points at this file) failing pydantic validation. Found
via `gws run --dry-run`; both scada and LTN dry-runs pass after the fix.

## 2026-06-10 — Bump channel config versions for RelayActorConfig and I2cThermistorChannelConfig (`dab55d20`, cherry-pick of `2b603cc0` onto `jm/spruce-unlimbo`)

**What:** Second of two cherry-picks gleaning `jm/spruce-new` onto
`jm/spruce-unlimbo` (the spruce-unlimbo working branch, cut from
`td/orig-pred-set`). Adds `ChannelConfigBase` type helper, bumps
RelayActorConfig / I2cThermistorChannelConfig (+ related channel-config
named types) versions, adds named-type tests, and adds the
`airtable_pat` setting + `.env-template` lines. Conflict resolved in
`.env-template` only (union of both sides; the pick's truncated
real-prefix Airtable PAT replaced with an empty placeholder).

**Why:** Branch-reconciliation step of the spruce-unlimbo design: these
two commits were the only content in `jm/spruce-new` not already in
`td/orig-pred-set` (which contains `jm/spruce` as an ancestor). After
this lands, `jm/spruce` and `jm/spruce-new` are fully gleaned and can be
deleted.

## 2026-06-10 — docstring for actors/scada.py (`a5451f43`, cherry-pick of `62bc7218`)

**What:** Replaces scada.py's one-line module docstring with one
explaining that Scada is the prime actor in a gwproactor app: child
actors load from the hardware layout + actor registry, so layout
`ActorClass` values must resolve through `gw_spaceheat/actors/__init__.py`
exports or the proactor cannot instantiate them.

**Why:** First of the two `jm/spruce-new` glean cherry-picks onto
`jm/spruce-unlimbo` (see entry above). The docstring captures the
layout→registry coupling that bit during spruce bring-up.

## 2026-06-10 — OFI comment (`8a0e1689`)

**What:** Add an OFI comment in `gw_spaceheat/actors/sieg_loop.py`
`moving_to_hp_off_valve_position` pointing at OPS-400
`sieg-semantic-harmonization`. No behavior change.

**Why:** Flags in-code that, after `e6ba4f51`, control state `HpOff` no longer
uniquely determines valve posture (it branches on static `settings.system_mode`
with no disambiguating telemetry), and that default-when-off is per-heat-pump
(Maple Mitsubishi vs Beech LG) and not yet parameterized — so the next reader
sees the seam and the tracking issue without spelunking the changelog.

## 2026-06-10 — Open sieg valve in Standby (`e6ba4f51`, PR #570)

**What:** In `gw_spaceheat/actors/sieg_loop.py`, the transition into
`SiegControlState.HpOff` no longer hard-codes `moving_to_full_keep` (loop
CLOSED). It now routes through a new `moving_to_hp_off_valve_position(event)`
that branches on `self.settings.system_mode`: `Standby` → `moving_to_full_send`
(valve OPEN); anything else → `moving_to_full_keep` (CLOSED — heating-season
behavior unchanged). Authored + merged by Thomas.

**Why:** The simple sieg code keeps the loop closed whenever the heat pump is
off — correct for the heating season, wrong for summer/Standby (especially when
the valve is otherwise not moving). Maple sat in Standby with the loop closed
post-incident; the first action is putting the loop in full send. SiegLoop
learns posture from the **static startup config** `settings.system_mode` (env
`SCADA_SYSTEM_MODE`), so the new posture takes effect on the restart that
switches a SCADA to Standby (which also rebuilds the LocalControl tree). Design
`sieg-summer-posture`, OPS-395. Known OFI (`sieg-semantic-harmonization`,
OPS-400): control state `HpOff` no longer uniquely determines valve posture and
telemetry can't disambiguate (valve-state `SingleMachineState` still TODO); and
default-when-off is per-heat-pump (Maple Mitsubishi vs Beech LG), not yet
parameterized.

## 2026-06-09 — ltn sends correct scada wrapped (`981f0939`)

**What:** Replace the five `Message(..., Dst="broadcast", ...)` publishes in
`gw_spaceheat/actors/ltn/ltn.py` with real proactor-peer addressing: `Bid` → the
MarketMaker (`Dst="mm"`); `FloNextHourPlans`, `Glitch`, and both
`FloParamsHouse0` sends → the scada (`Dst=self.scada.name`, i.e. `"s"`). Each
site carries a HACK comment to revert to a real `rjb` broadcast once the LTN is a
gwbase actor (it leaves the scada lexicon).

**Why:** `Dst="broadcast"` is a magic string the proactor turns into a wire
routing key with no valid GridWorks envelope, so a gwbase consumer
(JournalKeeper) drops it at parse — silent data loss (prod saw `broadcast.glitch`
/ `broadcast.flo-next-hour-plans`). Addressing a real peer makes a valid
`gw.<src>.to.<peer>.<type>` key that gwbase parses (tolerant short-form parse,
gridworks-base design `must-accept-current-ltn-messages`). `"mm"` is deliberately
the gwbase `RoutingClass.MarketMaker` token, so the key already matches the
new/future rabbit structure. Design `ltn-sends-gw-wrapped`, OPS-387; depends on
the gridworks-base parser change publishing.

## 2026-05-14 — Add back a much-pruned docs folder (`c05a7625`, merged `6734aa0f` / PR #562)

**What:** Restores a `docs/` folder to the scada repo with three focused,
hand-pruned documents — `docs/editor-setup.md` (109 lines),
`docs/provisioning.md` (257 lines), and `docs/tls.md` (123 lines). No code
changes; docs only. Authored 2026-05-07, merged to `dev` on 2026-05-14.

**Why:** The repo's earlier `docs/` had been removed; this brings back a
deliberately slimmed-down subset covering the three things a human setting
up scada actually needs — editor setup, device provisioning, and TLS — as
repo-standalone docs (a repo's own docs stand alone for a human and don't
reference the wiki). Curated-minimum rather than the full former tree.
