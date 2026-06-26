# proactor-makeover

Status: Draft · Pass 0 · Updated 2026-06-25 · Linear: OPS-428

**EDD: yes** verified by experiments on a real broker — the scada↔LTN link and
its decoupled liveness closing the 15-minute blackhole gap — run on both the old
and the new code, per the link-state findings' standing charge; not code review.

> What this is: replace the `gridworks-proactor` link mechanism and the `gwproto`
> type surface with a **gwbase- and Sema-native** scada transport. **Net outcome:
> neither `gridworks-proactor` nor `gridworks-protocol` (gwproto) survives as a
> package.** Three threads, one program, spanning scada + gwbase. The deep link
> analysis it builds on is
> [`../gridworks-scada/executor/scada-ltn-link-state.md`](../gridworks-scada/executor/scada-ltn-link-state.md);
> the target format + heartbeat model already live in gwbase
> ([`../gridworks-base/executor/codec.md`](../gridworks-base/executor/codec.md),
> [`../gridworks-base/executor/actors.md`](../gridworks-base/executor/actors.md)).

## Why

- The proactor link FSM is **1:1** (one peer per link): it can't express
  one-parent↔many-children — the aggregation future, at VCharge scale — and it
  **conflates broker liveness with peer liveness**, which is how a SCADA sat
  comms-dead ~15 minutes while looking healthy (a half-open socket no layer
  detected).
- `gwproto` is ~90% redundant with `gwsproto`, and the scada has **already**
  largely flipped its imports. A bespoke proactor codegen plus a near-duplicate
  types package is cost without benefit.
- gwbase already specifies the clean target — the `gw` envelope (`Src`/`Dst`/
  `From`), and `heartbeat.a` (the hex ping/pong). The scada should be a
  **citizen of that model**, not a parallel stack.

## Axioms / standing constraints

- **LTN on gwbase**; **scada MQTT-native** (mosquitto on the Pis), riding the
  rabbit MQTT plugin for the critical scada↔LTN link.
- **NO BACK DOOR** — no side channel that bypasses the authenticated transport.
- **Rewrite, not refactor** — flat-in-scada under `uv`; the old gwproactor is
  frozen as the ingester/uploader until cut over.
- **Sim/real trust boundary** — a simulated scada must find it **hard or
  impossible to acquire a real-world TaDeed / validation**; the boundary is
  enforced at the deed, not by good intentions. Not designed here, but a standing
  constraint on identity / provisioning / what a scada may claim about itself.

## Thread 1 — link mechanism → AllyLink

Replace the proactor link state machine with **AllyLink**, two tracks built in
tandem:

- **Scada AllyLink** — flat, scada-side; works **1:1 with a paired gwbase LTN**
  over the rabbit MQTT plugin, and **1-parent-to-many-children on one broker** (a
  home's Pi hierarchy). The one-parent-per-broker constraint keeps it simple.
- **FULL AllyLink in gwbase** — multiple parents ↔ fleets of children on one
  broker (the aggregator↔LTN case), incl. lifting in **persist-until-landed-in-a-
  permanent-store** acks.

**Two decoupled machines:** a **broker-connection** machine ("up or it isn't" —
a first-class active broker-reachability probe + bounded reconnect that
re-resolves DNS/route) and an **ally-presence** machine (the application-level
scada↔LTN liveness). Closes the half-open blackhole gap (the interim keepalive
mitigation rides ahead of it — [OPS-304](https://linear.app/gridworks/issue/OPS-304)).

Mechanism specifics (from the link-state findings):

- **Three-beat hello**, once, on link bring-up.
- **Hex keepalive = application-level proof of full receipt.** The hex pair
  (gwbase's `heartbeat.a` `MyHex` / `YourLastHex` is the precedent) is **not mere
  transport liveness**: echoing the peer's hex is a **strong proof that, at the
  application level, the message was fully received** — strengthened by the
  **three-volley** pattern. Driven at the **parent's cadence** (asymmetry kept for
  the fan shape; cadence an **explicit parameter, never emergent from telemetry**).
  The makeover **may extend `heartbeat.a` or coin a new versioned word** — the
  requirement is the receipt proof, not reuse for its own sake; reconcile with the
  versionless `gridworks.ping` (the keepalive keeps its ack — it IS the liveness).
- **Inverted ack default** — nothing is acked unless it backs a contract; the
  keepalive is the exception (its ack is the liveness).
- **Fire-and-forget `ally.inactive` / `ally.active`** — live peer-up/down,
  unpersisted, on whatever link still works (the third-party-referee signal).
- **Upstream-stream principle** — internal-link telemetry (`local_mqtt`/`admin`)
  stays off the contract-backing stream; only scada↔LTN liveness goes up.
- **Vocabulary** — parent / child / ally.

**Third-party umpire (open, load-bearing).** The scada↔LTN ally health link
specifically needs a party **independent of both** scada and LTN able to
validate the link's state — who went dark, when — because **financial agreements
settle on the SLA**, and a dispute can't be adjudicated by the two interested
parties alone. The fire-and-forget `ally.inactive` (emitted live on whatever
link still works) plus JournalKeeper-as-referee is the seed; the full umpire /
non-repudiation mechanism is an **open design requirement, not a nicety** — see
[`../gridworks-scada/explorations/liveness-and-sla.md`](../gridworks-scada/explorations/liveness-and-sla.md).

**Dispatch authorization (load-bearing).** Establishing the scada↔LTN dispatch
agreement also requires the **LTN to prove to the scada that it owns the
TaTradingRights** for the asset — the scada accepts dispatch only from a
counterparty that can demonstrate the trading authority (the TaTradingRights
assertion minted at provisioning). The agreement is mutual: identity + liveness +
**authorization**, not liveness alone.

## Thread 2 — format → the gwbase `gw` envelope

Align the scada wire format to gwbase's application envelope:

- `From`/`Src` is a **left.right.dot GNodeAlias** (the routing identity in
  `GridworksHeader`).
- Allow **non-wrapped messages** as a first-class option (extend the existing
  wrap/unwrap separation).
- Keep the application `gw` envelope distinct from the transport `RoutingEnvelope`.
- **Sema ride-alongs:** new **versioned wrapper/header words** carrying the
  left.right.dot `From`; sema delivered to the scada as a zipped snapshot file.

## Thread 3 — type surface → standard Sema codegen, retire gwproto

The scada's types come from **gwsproto via the standard Sema snapshot codegen**
(flat types, per the FLAT-sema rule) — not bespoke gwproto codegen. The scada
`gwproto → gwsproto` import flip is largely done already; gwproto's residual
proactor-only surface retires with the proactor.

## Outcome / done-when

- The scada runs on AllyLink + the `gw` envelope + gwsproto, verified against a
  real broker, with decoupled liveness closing the blackhole gap.
- `gridworks-proactor` and `gridworks-protocol` (gwproto) are archived/removed —
  neither survives as a package.

## Process

- **Before discarding the old mechanism:** a **full proactor analysis** to be
  sure everything load-bearing is captured (ack/"pat" semantics, in-flight event
  accounting, reupload pacing, anything else) — capture is explicit, silence is
  not capture.
- Then a **long-running fable session** runs the rewrite under two standing
  charges: use Andy's proactor as inspiration for what it did **well**; run
  experiments on old and new throughout.

(Cross-design sequencing — the interim half-open mitigation, the unlimbo epic —
is tracked in Linear.)
