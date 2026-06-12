# Integrate gwbase + sema updates into JournalKeeper

Status: Accepted · Pass 1 · Updated 2026-06-12 · Linear: OPS-386

**EDD: no** build-out/integration; verified by the test suite (incl. the Layer-2
liveness test, `tests/test_live_amqp.py`), not gated on a standalone real-world
experiment.

> What this is: the **hub** of the design to finish moving
> `gridworks-journalkeeper` onto upgraded **gwbase 0.5.x** (three-tier
> `ServiceSettings`/`ActorBase`) and the updated **sema** restricted-snapshot
> toolchain (OPS-380). Structure: **what to do next at the top, the ordered spoke
> list, then notes.** Durable facts from completed items are distilled into
> `executor/primary.md`; this hub is deleted when the last item lands.

## ▶ Do this now — item #3: persisted type-set

Add these types to JK's persisted set — the durable **semantic** signals (the
proactor **mechanism** events are deliberately skipped; the rewrite will churn
them):

- **Add:** `gridworks.ack`, `gridworks.ping`, `gridworks.event.startup`,
  `gridworks.event.shutdown`, `gridworks.event.comm.peer.active`, and the new
  `ally.inactive`.
- **Skip:** `gridworks.event.comm.mqtt.connect` / `…fully.subscribed` /
  `…response.timeout`, `send.layout`.

For each: seed it in `src/gjk/sema_seed_request.yaml` → regen the snapshot
(`scripts/regen_sema_snapshot.sh`) → add it to the right table in
`sema_message_persistor.py` → confirm it flows through the liveness harness
(`tests/test_live_amqp.py`). `ally.inactive` is a **new sema word**, coined first
via `/make-sema-word` (branch `jm/proactor-link-vocab`); peer-up (`peer.active`,
an Event) and peer-down (`ally.inactive`, a non-event) stay asymmetric **on
purpose** — real friction for the proactor rewrite to resolve, not to paper over
here. Full detail in spoke **`persisted-type-set.md`**.

Then **item #4 — close session loose ends:** commit/stash the prod-persist
live-test runner.

## Spokes (in order)

1. ✅ **DONE** — sema snapshot regen (item #1; folded in, no separate spoke).
2. ✅ **DONE** — `gwbase-tier-migration.md` (item #2; landed + live-verified).
3. **▶ `persisted-type-set.md` (item #3) — active** (see top).
4. close session loose ends (item #4; no spoke).

---

## Notes

What landed (durable facts distilled into `executor/primary.md` + `changelog.md`):

- **#1 — sema snapshot regen** — clean restricted-snapshot from sema `dev` via
  `scripts/regen_sema_snapshot.sh`; round-trip gate + `samples/` ship, vendored
  `tests/` dropped; market enums arrive structurally via `bid`/`atn.bid`;
  `atn.bid` + `bid` + `latest.price` decode. Seed at
  `src/gjk/sema_seed_request.yaml`.
- **#2 — gwbase tap-tier migration** (`0b7c2e0`) — `Settings(GNodeSettings)` →
  `ServiceSettings`, `service_alias` first-class, `g_node.json` deleted, plain
  XDG. Live-verified by `tests/test_live_amqp.py` (Layer-2: real actor boot →
  broker-consume → persist — the path the unit suite skips).
- **Liveness harness** (`603d8a9`) — ephemeral RabbitMQ + TimescaleDB via
  `testcontainers`; the reusable vehicle #3's types flow through (Layer 2 of the
  `layered-test-harness` design).

Upstream prerequisites that landed:

- Regression fix — `report.event`/`layout.lite` `time_received` seam (PR #162).
- sema snapshot-improvement merged (PR #21, `8293b4e`).
- gwbase 0.5.2 on PyPI + routing-key data-loss fix (OPS-388, distilled into
  `gridworks-base/executor/transport.md`); JK pinned `gridworks-base>=0.5.2`.
- JK `legacy_hack` — `on_routing_key_parse_error` recovers legacy `broadcast.*`
  keys (the scada-side fix stopping *new* ones shipped as OPS-387).
