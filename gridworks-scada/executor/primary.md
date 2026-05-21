# gridworks-scada — Rebuild Specification (primary)

The faithful-rebuild hub for `gridworks-scada`. Intended to grow into a
language-agnostic account complete enough to rebuild the SCADA from these docs.

> **Status: acceptable-minimum first pass (discovery phase).** This captures the
> load-bearing architecture from the repo's current `CLAUDE.md` and code, and
> marks everything unresolved or unbuilt as **Open**. It is **not yet
> authoritative**. Design questions still converging live in
> [`../research/concerns/`](../research/concerns/); component descriptions and the
> bug/cleanup register live in [`../research/`](../research/). Provenance of
> claims here: mostly `told` (from `CLAUDE.md`) / `inferred` — verify against
> code before relying. See [`../PROCESS.md`](../PROCESS.md).

## What the SCADA is

Runtime for a transactive heat-pump thermal-storage SCADA on a Raspberry Pi in
residential heating installations. It does five things:

1. Tracks the state of a **DispatchContract** it can hold with its
   LeafTransactiveNode (LTN; legacy name `Atn`/`AtomicTNode` — see
   [`../../glossary.md`](../../glossary.md)).
2. While the contract exists and is in `RemoteControl`, sends sensing data
   upstream: compressed state (~temperature) every ~5 min, async power-on-change,
   and diagnostics.
3. While the contract is active, executes actuating commands from the LTN
   (heat pump, boost elements, pumps, valves).
4. When there is no contract, or it is in `LocalControl`, **runs the heating
   system itself**.
5. Retains a pared-down log when out of contact (1d/7d/28d tiers) and backfills
   it upstream on reconnect.

## Architecture

### Actor topology

The SCADA process is one `ScadaApp` (a gwproactor host) running one
**PrimeActor** (`actors/scada.py::Scada`) plus a fleet of communicators
(relays, sensors, hubs, multiplexers, FSM nodes). Actors talk via the
proactor's message bus, **not** direct calls. A second process, `Scada2`
(`scada2_app.py`), runs on the LAN side and hosts hardware actors that don't
fit on the primary box; it links to Scada over `local_mqtt`.

The `Scada` PrimeActor owns:
- A top-level state machine (`Auto` / `Admin`) via the `transitions` library;
  `Admin` is entered when the admin UI grabs control.
- The **DispatchContract** lifecycle with the LTN
  (`actors/contract_handler.py` — described in
  [`../research/components/contract-handler.md`](../research/components/contract-handler.md)).
  Contract status drives whether actuating commands come from the LTN
  (`RemoteControl`) or local logic (`LocalControl`).
- Synchronous compressed reports (`ReportEvent`) + async `PowerWatts` upstream
  when in `RemoteControl`; retention/backfill when out of contact.
- Routing of `FsmEvent` / `AnalogDispatch` to actors via a command tree built
  from the hardware layout.

### Links

Three MQTT links (gwproactor): `gridworks_mqtt` (upstream, to the LTN),
`local_mqtt` (to Scada2 on the LAN), `admin` (the gridworks-admin UI).
**Open:** the proactor link can't model multiple downstream SCADA; the LTN is
moving off the proactor to rabbit-native; the SCADA↔LTN transport may itself
become rabbit-native. See
[`../research/concerns/transport-and-links.md`](../research/concerns/transport-and-links.md).

### Hardware layout

The hardware-layout JSON is the single source of truth for which actors exist,
what they control, and how they connect — it defines the actor graph at
startup (not runtime config). Built programmatically under
`gw_spaceheat/layout_gen/`; in-memory form is
`gwsproto.data_classes.house_0_layout.House0Layout`.

### Boundary protocol vs. runtime (Sema)

All JSON crossing a process boundary (to LTN, Scada2, or admin) uses types in
`packages/gridworks-scada-protocol` (`gwsproto`) — **Sema boundary
infrastructure** (CamelCase, `TypeName`/`Version`, named formats, append-only
enums). Sema does **not** govern runtime architecture or internal object
models; in-process actor-to-actor messages are plain Python objects. The SCADA
is a **legacy** Sema implementation — modernizing it is a tracked concern
([`../research/concerns/sema-style.md`](../research/concerns/sema-style.md)).

### Packages

`packages/gridworks-scada-protocol` (`gwsproto`, boundary types) and
`packages/gridworks-admin` (`gwadmin`, the textual admin UI) are separate
`uv`-managed PyPI distributions, editable-installed into the scada venv.

## Cross-cutting commitments

Normative across the domain — full statements in
[`../research/principles.md`](../research/principles.md):

- The SCADA acts **on behalf of the customer**, not the provider.
- Whoever owns the LTN's financial choices **holds the SLA**.
- The SCADA terminates a contract on **SLA breach**, never for convenience.
- The liveness **heartbeat is SCADA↔LTN** (not cloud↔LTN), because the SCADA is
  the party that actually goes offline.
- **Open / not-yet-in-code:** TerminalAsset **deed** (third-party-validated GPS
  / asset-type / metering) and **TradingRights** certificate (homeowner→
  aggregator, with clawback; required by both MarketMaker and SCADA from the
  LTN). See
  [`../research/concerns/deeds-and-trading-rights.md`](../research/concerns/deeds-and-trading-rights.md).

## Map of the spec

| Covers | Where | Status |
|---|---|---|
| Overview, architecture, commitments, TOC | **primary.md** (this file) | acceptable-minimum |
| Contract / heartbeat lifecycle | sub-spec **Open** — meanwhile [`../research/components/contract-handler.md`](../research/components/contract-handler.md) | Open |
| Actor model & message bus | sub-spec **Open** | Open |
| Hardware layout / actor graph | sub-spec **Open** | Open |
| Boundary types (gwsproto / Sema) | sub-spec **Open** | Open |
| Transport & links | design converging in [`../research/concerns/transport-and-links.md`](../research/concerns/transport-and-links.md) | Open |
| Non-GNode interfaces (provisioning, certs, admin) | [`../research/concerns/non-gnode-interfaces.md`](../research/concerns/non-gnode-interfaces.md) | Open |

## Open (top-level)

- De-stale and verify the architecture claims above against code (currently
  `told`/`inferred` from `CLAUDE.md`).
- Decide LTN/SCADA transport (rabbit-native?) before writing the transport
  sub-spec — it changes the rebuild target materially.
- Promote converged `research/` material into sub-specs as it stabilizes.
