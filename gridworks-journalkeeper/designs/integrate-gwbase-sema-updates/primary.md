# Integrate gwbase + sema updates into JournalKeeper

Status: Accepted · Pass 1 · Updated 2026-06-22 · Linear: OPS-386

**EDD: no** build-out/integration; verified by the test suite (incl. the Layer-2
liveness test, `tests/test_live_amqp.py`), not gated on a standalone real-world
experiment.

> What this is: the **hub** of the design to finish moving
> `gridworks-journalkeeper` onto upgraded **gwbase 0.5.x** (three-tier
> `ServiceSettings`/`ActorBase`) and the updated **sema** restricted-snapshot
> toolchain (OPS-380). Structure: **what to do next at the top, the ordered spoke
> list, then notes.** Durable facts from completed items are distilled into
> `executor/primary.md`; this hub is deleted when the last item lands.

## ▶ Do this now — item #4: close session loose ends

Commit/stash the prod-persist live-test runner; tidy active-claims. With the
persisted type-set moved out (below), this is all that remains — the gwbase +
sema integration itself is done.

**Item #3 (persisted type-set) moved to OPS-317 (scada-health-diagnostics),
2026-06-22.** The durable liveness-signal *selection* and the new `ally.inactive`
word are scada-health-diagnostics work, so that design owns the *what + why*. JK's
persist *mechanism* (seed → snapshot-regen → persistor recipe) stays here as
reference in **`persisted-type-set.md`**. Correction carried over: `ally.inactive`
was **never authored** — the `jm/proactor-link-vocab` branch it was parked against
is merged into sema dev and carries no unique commits, so it must still be coined
via `/make-sema-word`.

## Spokes (in order)

1. ✅ **DONE** — sema snapshot regen (item #1; folded in, no separate spoke).
2. ✅ **DONE** — `gwbase-tier-migration.md` (item #2; landed + live-verified).
3. ↪ **MOVED to OPS-317** — `persisted-type-set.md` retained as the JK persist
   *mechanism* reference (the *how*); the signal-set selection + `ally.inactive`
   are owned by the scada-health-diagnostics design.
4. **▶ close session loose ends (item #4) — active** (see top).

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
