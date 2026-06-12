# Spoke A — gwbase tier-model migration

Status: Accepted · Pass 1 · Updated 2026-06-12 · Linear: OPS-386

> What this is: spoke of `integrate-gwbase-sema-updates` (hub: `primary.md`,
> OPS-386). The concrete plan for hub item **#2** — moving JournalKeeper's
> settings off the GNode-only tier onto gwbase 0.5.x's `ServiceSettings`, making
> `service_alias` first-class, and adopting the plain-XDG path convention. The
> actor class is already `ActorBase`; this spoke is almost entirely about
> `src/gjk/config.py` and the path/CI plumbing around it.

## Where JK sits today

- `JournalKeeper(ActorBase)` already — `src/gjk/journal_keeper.py:26`. **No
  `GridworksActor`, no orchestrator tier.** The actor side is already correct
  for a tap; only the *settings* class lags.
- `Settings(GNodeSettings)` — `src/gjk/config.py:18`. `GNodeSettings`
  (gwbase `config/g_node_settings.py`) = `ServiceSettings` **plus** a
  GNode-only `g_node_path` (loads `g.node.gt.json`). JK is **not** a GNode and
  never loads that file usefully, so it is carrying GNode identity it doesn't use.
- JK declares GNode-shaped fields it does not need: `g_node_alias`,
  `g_node_id`, `world_instance_alias` (`config.py:27-29`).
- `model_config` keeps JK's own `env_prefix="GJK_"` (`config.py:35-39`).

## Target tier model (verified against gwbase 0.5.x)

The three tiers, from `gridworks-base/src/gwbase/config/`:

- **`ServiceSettings`** (`config/service_settings.py:7`) — minimum to ride
  gwbase rabbit + sema **without** being a GNode. Fields: `rabbit`,
  **`service_alias: LeftRightDot`** (required, the routable address, e.g.
  `d1.journal`), `instance_id` (auto-uuid per boot if `None`), `service_name`
  (default `"gridworks"`, the **XDG path segment**, *not* the alias),
  `log_level`, `log_rotate_*`. `env_prefix="GWBASE_"`.
- **`GNodeSettings(ServiceSettings)`** (`config/g_node_settings.py:9`) — adds
  `g_node_path` (durable GNode identity file). **What JK should stop
  inheriting.**
- **`ActorBase`** (`actor_base.py:58`) — `__init__(*, settings: ServiceSettings)`;
  reads `self.alias = settings.service_alias` (`:100`), per-boot
  `instance_id` (`:101`), builds a logger from `service_name` into the XDG
  state dir. Accepts any `ServiceSettings` (or subclass).

## The migration

**1. Reparent `Settings` to `ServiceSettings`.**

```python
from gwbase.config import ServiceSettings   # was: GNodeSettings

class Settings(ServiceSettings):
    # JK-specific config retained as-is:
    db_url: SecretStr = ...
    gbo_db_url: SecretStr = ...
    aws: AwsClient = AwsClient()
    ops_genie_api_key: SecretStr = ...
    my_fqdn: str = "localhost"
    visualizer_api_password: SecretStr = ...
    email_sender: SecretStr = ...
    email_password: SecretStr = ...

    # gwbase-native identity (was the g_node_alias hack):
    service_alias: LeftRightDot = "d1.journal"
    service_name: str = "journalkeeper"   # XDG segment

    model_config = ConfigDict(
        env_prefix="GJK_", env_nested_delimiter="__", extra="ignore",
    )
```

**2. Drop the GNode-only fields:** `g_node_alias`, `g_node_id`,
`world_instance_alias`. Anything that read `settings.g_node_alias` for routing
now reads `settings.service_alias`.

**3. Make `service_alias` first-class — replace the `.env`/`g_node_alias`
hack.** `ServiceSettings.service_alias` is **required** with no default; JK
gives it a sane default (`"d1.journal"`) and lets `GJK_SERVICE_ALIAS` override.
Because JK keeps `env_prefix="GJK_"`, the inherited `service_alias` field is
read from `GJK_SERVICE_ALIAS` (the most-derived `model_config` prefix wins for
inherited fields). **VERIFIED:** the env half is already wired — JK's `.env`
sets `GJK_SERVICE_ALIAS` (comment there: *"routable address of this tap. Was
previously g_node_alias"*); that is how the recent live-test satisfied it. So
the migration's *code* delta is: add the `service_alias` field (default +
`GJK_SERVICE_ALIAS` override) and delete the now-dead `g_node_alias`
(`config.py:27`, currently ignored via `extra="ignore"`). Also scrub the stale
`GJK_G_NODE_PATH` lines from `.env` and `template.env` (leftover GNodeSettings
plumbing — no g-node file once on `ServiceSettings`, see §4).

**4. Paths — plain XDG, no g_node file, no proactor.** Two consequences of
dropping `GNodeSettings`:

- JK **sheds the `g.node.gt.json` requirement entirely** — a `ServiceSettings`
  actor has no GNode identity file to load. The hub's "g_node.json under the
  XDG config dir" item largely **dissolves**: there is no g-node file for JK.
- What XDG *does* still buy JK: gwbase's logger already writes to
  `state_dir(service_name)` for free once `service_name="journalkeeper"`. The
  only remaining choice is **where JK's `.env` lives** — today `DEFAULT_ENV_FILE
  = ".env"` (cwd; `config.py:6`). Option: relocate to
  `config_dir("journalkeeper")/.env` via gwbase `config/paths.py:config_dir`.
  **Open** — keep cwd `.env` for now vs. adopt XDG config dir; low stakes.

  `Paths` source is **gwbase** (`gwbase/config/paths.py` — plain helper
  functions keyed on `service_name`; tests redirect via the bare
  `XDG_CONFIG_HOME` / `XDG_DATA_HOME` / `XDG_STATE_HOME`). **Not** proactor's
  `Paths` class and **not** the `<PREFIX>_PATHS__BASE/NAME` nested-env idiom.

  > **Why plain XDG (durable rationale).** scada and the LTN use proactor's
  > `Paths` (`gwproactor/config/paths.py:70`) with `SCADA_PATHS__BASE` etc. —
  > but those are **on-device proactor** services, a different world. **All
  > GridWorks *cloud* actors are gwbase** (JK, MarketMaker, Sema services, …),
  > so the cloud-actor fleet is uniformly plain-XDG; the two idioms are a clean
  > **world boundary** (cloud=gwbase=XDG, edge=proactor=`PATHS__`), not an
  > inconsistency. The hub's checkbox phrase "the pattern the LTN and scada
  > already use" is a **mis-anchor** — JK's template is the other gwbase cloud
  > actors, not scada/LTN. Do **not** reflexively pull `gridworks-proactor`
  > into JK for `Paths`; that inverts the layering for one feature.

**5. CI on the published base. VERIFIED — nothing to do.** CI
(`.github/workflows/tests.yml`) and the test fixtures carry **no**
sibling-checkout / `../gridworks-base` editable install; the only reference is
the PyPI pin `gridworks-base>=0.5.2` in `pyproject.toml`. This checkbox closes
with no change. (The live-test repoint lived only in the runner scripts
`scripts/point_at_dev_hack.py` / `point_at_prod_observe.py`, which is hub item
#4's concern, not CI.)

## Acceptance / done-when

- ✅ `Settings(ServiceSettings)`; no `g_node_*` / `world_instance_alias` fields
  (`config.py`). `g_node.json` deleted (tracked file removed).
- ✅ `service_alias` defaulted (`"d1.journal"`) + `GJK_SERVICE_ALIAS`-overridable;
  nothing reads `g_node_alias`. `template.env` / `.env` `GJK_G_NODE_PATH` scrubbed.
- ✅ JK boots and persists end-to-end against published `gridworks-base>=0.5.2`
  with no sibling checkout — **verified by `tests/test_live_amqp.py`**: a real
  `JournalKeeper` actor (executing the migrated `ActorBase.__init__` →
  broker-consume) ingests a `scada.params` message off an ephemeral broker and
  lands it in the DB. This closed the gap the unit suite couldn't (it skips
  `ActorBase.__init__`).
- ✅ JK suite green (21 passed incl. the live test); logs land under
  `state_dir("journalkeeper")`.

**Status:** migration landed (`0b7c2e0`) and **live-verified** by the Layer-2
liveness test. Done.

## Open questions

- `.env` location: cwd vs. XDG config dir (low stakes — decide at impl).

_(Resolved: service_alias mechanism — §3; CI sibling-checkout — §5; GNode
fields are dead — see §2.)_

**§2 note (verified safe to delete):** `g_node_alias` / `g_node_id` /
`world_instance_alias` are read **nowhere** — they appear only at their
`config.py:27-29` definitions. Don't conflate with
`s3_message_importer.py`'s separate hardcoded `world_instance_name = "hw1__1"`
(a different attribute, untouched by this deletion).
