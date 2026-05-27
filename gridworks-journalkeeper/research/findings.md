# gridworks-journalkeeper — findings

Status: Draft · Pass 0 · Updated 2026-05-26

> **Note on convention.** `findings.md` is now flagged as a legacy
> register in `wiki/GridWorks_CLAUDE.md` (preferred: Linear for
> actionable items, `concerns/` for architectural ones). This file
> exists by explicit user request to capture what was learned in the
> 2026-05-26 gwwf→gjk dev-rabbit integration test as input to a real
> test harness. Items here SHOULD migrate to Linear / `concerns/`
> when they get touched.

---

## F-001 (2026-05-26) — End-to-end weather pipeline verified on dev infrastructure

**What ran:** gwwf with `GWWF_HACK_FICTITIOUS=1` publishing canned
`weather` v000 every 5s → dev rabbit (`gw-dev-rabbit`, vhost `d1__1`)
→ gjk via `scripts/point_at_dev_hack.py` (a one-shot companion runner
modelled on `point_at_prod.py`) → `gw_data.messages` table on
`gw-data-pg` (port 5433). 22 weather rows landed within minutes,
payload JSON intact.

**The pipeline structurally:**

```
WeatherActor._publish(weather)                        [gwwf]
    └─ publish to weathermic_tx, routing-key
         rjb.d1-weather-dev.weather.weather           [gwbase canonical: TC → <rc>mic_tx]
            └─ broker e2e binding weathermic_tx → ear_tx
                 (already declared in the dev-rabbit
                 image; not declared by gwbase at startup)
                    └─ JournalKeeper queue bound to
                         ear_tx with "#" (catch-all)   [gjk]
                            └─ dispatch_message →
                                 SemaCodec.from_dict →
                                 SemaMessagePersistor →
                                 gw_data.db.models.MessageSql
                                    └─ INSERT into messages    [postgres]
```

**No code edits needed in gjk for the new type** — Stage 1's port to
`SemaMessagePersistor.all_known_message_types()` means new sema types
flow through with zero handler code in the consumer.

---

## F-002 (2026-05-26) — The hack pattern (env-var module-globals) is fragile

`gwwf/weather_actor.py` exposes `GWWF_HACK_FICTITIOUS` and
`GWWF_HACK_INTERVAL_S` as **module-level** captures:

```python
HACK_FICTITIOUS = bool(os.environ.get("GWWF_HACK_FICTITIOUS"))
HACK_INTERVAL_S = int(os.environ.get("GWWF_HACK_INTERVAL_S", "5"))
```

This works only because `__main__.py` calls `dotenv.load_dotenv()`
**before** importing `weather_actor`. Any test or harness that imports
`weather_actor` differently (e.g. via pytest's import-on-collection)
sees `False`. **Implication for a real harness:** carry these as
settings on the `GwwfSettings` object (or a dedicated `WeatherHack`
settings sub-class) — not as module globals. Settings objects are
ordered correctly and overridable per-test.

---

## F-003 (2026-05-26) — Bus topology: canonical mic vs prod-fabric legacy

(See also `wiki/gridworks-base/executor/primary.md` §7 "Dev brokers
vs prod broker.")

- **gwbase declares only `<rc>mic_tx`.** Consume `<rc>_tx` exchanges
  and cross-class bindings are broker-fabric — declared by infra, not
  the framework.
- **The dev-rabbit docker image** (`ghcr.io/thegridelectric/dev-rabbit:latest`)
  carries a baseline fabric including `ear_tx`, `ws_tx`, and the
  `weathermic_tx → ear_tx` binding. The test relied on that baseline.
- **A test harness that builds a broker from scratch MUST declare its
  own fabric** — otherwise the test passes locally and fails on CI's
  clean broker. Add a `pytest` fixture `dev_rabbit_fabric()` that
  declares the minimum exchanges + bindings the test needs.
- The `_consume_exchange = "ws_tx"` override in `WeatherActor` is a
  prod-fabric concession; it has no canonical justification. Revisit
  when the prod fabric is rebuilt.

---

## F-004 (2026-05-26) — Capture-and-replay is the obvious harness shape

The integration test taught us the three test layers naturally split:

1. **Layer A — Fetch.** Hitting NWS. Network-dependent.
   Mockable but the mock IS the contract you care about.
2. **Layer B — Build.** NWS-response dict → `Weather` payload. Pure
   function. Testable offline given a captured NWS response.
3. **Layer C — Publish.** Payload + envelope → bytes on the wire.
   Pure once you have a dev broker.

**Harness recipe (proposal):**

- `tests/fixtures/nws/` — capture real NWS responses as JSON files,
  one per scenario (normal obs, missing temp, stale obs, unexpected
  units, NWS 503, etc.). Add a CLI: `gwwf-capture-nws --out ...` that
  hits the live API once and writes a fixture. Periodically regen +
  commit to track NWS contract drift.
- `tests/test_weather_build_offline.py` — Layer B unit tests:
  load each fixture, call `_build_weather`, assert the resulting
  `Weather` payload. No broker, no DB, no internet.
- `tests/test_weather_publish_dev_rabbit.py` — Layer C integration
  test using `pytest.mark.integration`. Spin up dev rabbit + DB
  fixtures in setUp; publish a known Weather; assert it lands in
  `messages`; tear down by deleting the test's
  `from_alias` rows.
- Live NWS (Layer A) gets at most a smoke test in CI that runs once
  per day on a cron, not on every PR.

---

## F-005 (2026-05-26) — gjk-side: the catch-all hack-runner is a useful template

`scripts/point_at_dev_hack.py` is a "consume + log + capture" runner
that's broker/type-agnostic — it binds catch-all on
`_consume_exchange`, wraps `dispatch_message` to log + write each body
to `captured-dev/<alias>-<type>-<ts>.json`, and try/excepts around
the actual persistence (so receipt remains visible even if persistence
breaks). This is exactly the shape of a **generic dev consumer for
integration tests** that any future producer can wire against. The
script lives in `scripts/` as a working example; promote it into a
library helper (`gjk.testing.catchall_runner` or similar) when the
harness lands.

---

## F-006 (2026-05-26) — LeftRightDot rejects hyphens (session-tag aliases break)

The `Weather.from_g_node_alias` sema validation rejected
`d1.weather.dev.bright-frost` because `LeftRightDot` does not permit
hyphens (lowercase-letter tokens joined by `.`, no `-`, no `_`). Used
`d1.weather.dev` instead. This is **the grid coordinate-system
grammar** and not negotiable — session-friendly tags like
`bright-frost` SHALL NOT appear in any aliasable identifier. See
`wiki/glossary.md` for the canonical surfacing of this gotcha.

---

## F-007 (2026-05-26) — gjk inherits the hardcoded `/etc/gridworks/g_node.json` default; should adopt the proactor `Paths` XDG convention

gjk currently uses `gwbase.GNodeSettings` directly, which defaults
`g_node_path` to `/etc/gridworks/g_node.json` — a system-level path
that requires root to provision and doesn't follow XDG.

This is the same gap the framework-level design
[**`wiki/gridworks-base/designs/support-non-gnode-actors/xdg-paths.md`**](../../gridworks-base/designs/support-non-gnode-actors/xdg-paths.md)
calls out: the proactor `Paths` class
(`gridworks-proactor/gwproactor/config/paths.py`) already implements
the right pattern (`~/.config/gridworks/<service>/…`), and
**`wiki/gridworks-ltn/executor/primary.md`** confirms the LTN already
uses it (`~/.config/gridworks/ltn/`, `LTN_PATHS__HARDWARE_LAYOUT`,
etc.). scada finds its `hardware-layout.json` via the same mechanism.

The integration test sidestepped this with a
`GJK_G_NODE_PATH=/Users/jessica/GridWorks/gridworks-journalkeeper/g_node.json`
override in `.env` pointing at a repo-local file — useful as a hack
but not a convergence.

**Direction (parked, depends on F-005):**

- When F-005 lands `Paths` in `gridworks-base`, journalkeeper picks
  it up automatically by bumping its `gridworks-base` floor.
- If that's far off, journalkeeper could depend on `gridworks-proactor`
  *just for `Paths`* (small surface) and pre-empt — same as LTN.
- Either way, the target shape is:
  - Config dir: `~/.config/gridworks/journalkeeper/`
  - `g_node.json` lives at `~/.config/gridworks/journalkeeper/g_node.json`
  - `GJK_PATHS__BASE` / `GJK_PATHS__NAME` env override roots for
    tests (single XDG root override moves everything together).

---

## Implications for journalkeeper test harness specifically

- **Receive-side smoke** is most of what gjk needs. Given any
  well-formed Weather (or other Sema type) on the bus, can journalkeeper
  decode + persist? That's a single integration test parameterised
  over fixtures from each producer.
- **DB persistence verification** is currently `SELECT … FROM
  messages` directly. A reusable helper —
  `assert_persisted(session, from_alias, type_name, count, since_ms)` —
  would clean up that pattern.
- **Test isolation** needs `from_alias` namespacing for the test run
  (e.g. `d1.test.<test-id>`) + teardown that deletes by `from_alias`,
  not `TRUNCATE`. The dev DB carries useful pre-existing rows from
  other sessions that should not be clobbered.
- The **same broker-fabric concern from F-003** applies here on the
  consume side: declare what bindings the test needs at setUp; do
  not rely on the image's baked-in fabric.

---

## Open items (TODO migrate to Linear or `concerns/`)

1. The 22 captured `messages` rows on dev-pg are real-but-test data
   from this session. We didn't clean them up. Future tests need
   namespacing + teardown discipline (see F-006 inside the test
   isolation paragraph above).
2. Decide where the broker-fabric declaration lives (sema convention?
   gwbase helper? Per-repo test fixture?). Cross-repo concern.
3. The hack-mode env vars in `weather_actor.py` should migrate to
   the settings object (F-002) before the next iteration.
