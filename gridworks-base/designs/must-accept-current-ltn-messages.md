Status: Draft · Pass 0 · Updated 2026-06-09

# gwbase MUST accept current LTN/SCADA routing keys

What this is: a bug + fix-direction note. The upgraded gwbase 0.5.x routing-key
parser **silently drops** production messages whose `gw`-wrapped routing key
uses a proactor **short_name** (e.g. `s` = scada, `a` = atn) in the position
gwbase treats as a `to-class`. Surfaced live while live-testing
gridworks-journalkeeper against the production broker.

## The bug

`parse_routing_key` (`src/gwbase/transport_encoding.py`) parses a
`MessageCategory.GridworksWrapped` (`gw`) key as exactly 5 tokens:

```
gw.<from-alias>.to.<to-class>.<type-name>
```

and runs token[3] through `RoutingClass(...)` — the **closed** enum
`{ta, cn, ltn, mm, scada, price, weather, time, super}` (full words).

Production messages instead carry the proactor **MQTT short_name** in that
slot. Observed live from prod:

```
gw.hw1-isone-me-versant-keene-beech.to.s.gridworks-ping
gw.hw1-...-keene-beech.to.s.slow-contract-heartbeat
gw.hw1-...-keene-oak.to.s.gridworks-ack
```

`s` is the **scada short_name**, not a routing class — confirmed in
`gridworks-proactor`: `gwproactor_test/dummies/names.py`
`DUMMY_SCADA1_SHORT_NAME = "s"`, `dummies/tree/atn.py` `short_name="a"`,
`scada2.py` `short_name="s2"`, plus admin. The `to` token is a **per-link
peer short_name** in the proactor's MQTT topic grammar
(`gw/<src-short>/to/<dst-short>/<type>`), translated dot-for-slash onto AMQP.
It is NOT, and was never, a gwbase `RoutingClass`.

`RoutingClass("s")` raises → in `ActorBase.on_message`
(`src/gwbase/actor_base.py:540-549`) the delivery is **acked first
(line 540)** and then, on the parse `ValueError`, the handler **`return`s
without dispatching**. So the message is acknowledged and discarded — silent
data loss, only a `WARNING: Could not parse routing key`.

The same failure hits the **broadcast** path: `MessageCategory.JsonBroadcast`
(`rjb`) keys carry a `from_class` token that `_parse_json_broadcast_envelope`
runs through the same `RoutingClass`. Production uses **`ws` = weather
service**, e.g. `rjb.hw1-isone-ws.ws.weather` (a forecast broadcast ~every
10 min) — so weather forecasts, which JK actively persists, are dropped too.
The defect is *any* class-token slot in `parse_routing_key`, not just the
wrapped `to`.

## Why this matters

Any current LTN/SCADA/weather message whose routing key uses a short-form
class token is dropped by a gwbase consumer. This was first diagnosed on base
0.4.0 during the 2026-05-24 journalkeeper prod-broker test (this design
consolidates that earlier `routingclass-wire-aliases` finding) and still holds
on 0.5.x. Quantified there: **48 messages dropped in a single 5-minute prod
run**, and **weather forecasts (≈every 10 min) were never captured once**
across two runs. Affected traffic includes scada liveness (`gridworks-ping`,
`gridworks-ack`, `slow-contract-heartbeat`, via `to.s`) and weather broadcasts
(via `ws`). **TODO: enumerate the full short-form set** (audit prod routing
keys via the mgmt API or a wide `#` binding) before sizing the fix.

**Discovery note.** Production JournalKeeper binds *narrow* keys
(`#.energy-instruction`, `#.report`, …), so it never observes these drops — the
loss is only visible under a catch-all `#` binding on `ear_tx`. Re-check with a
wide audit binding before the gwbase migration of the LTN, whose wire
vocabulary likely uses more of these short forms.

**Why the bug is narrow today (coincidence, not design).** The `to` token is
the destination ShNode alias (the proactor peer short_name). It parses only
when that alias happens to equal a `RoutingClass` value. That is true for the
`ltn` and `scada` ShNodes, which are **special** — each maps 1:1 to a GNode,
so its alias matches the GNodeClass (`ltn` ↔ LeafTransactiveNode, `scada` ↔
Scada). So scada→ltn traffic parses (alias `ltn` is also a `RoutingClass`),
while anything addressed to `s` (scada short_name), `a` (atn), `s2`, admin,
etc. is dropped. The two namespaces — proactor short_names and gwbase
`RoutingClass` — are independent; the overlap is accidental.

## Constraint

The proactor/scada side **cannot change** — reworking the routing-key grammar
there is a major proactor refactor the team explicitly does not want. So the
fix MUST live in **gwbase**: it must accept the routing-key format current
production actually emits.

## Fix direction (decided)

gwbase's routing-key parser treats **class tokens** — the wrapped `to`-class
*and* the broadcast `from`-class — as **opaque short_names**, not a closed
`RoutingClass`:

- Parse the class token as a free-form short_name; `*_class`/`*_alias` become
  **best-effort/optional** (None when not resolvable). Delivery never depends
  on them. gwbase MAY map known short forms (`s`→scada, `ws`→weather, …) to
  classes as metadata, but MUST NOT raise or drop on an unknown one.
- Routing-key *build* functions can keep emitting long forms; only *parse*
  needs to be tolerant.
- `on_message` MUST NOT silently drop on a routing-key parse issue — the
  current ack-then-`return` order (`actor_base.py:540` acks, `:549` returns)
  is itself the data-loss hazard and must go.

The invariant: **a gwbase consumer MUST NOT drop a message it received just
because the routing key uses the current production short_name grammar.** The
fix lives entirely in gwbase — no proactor/scada change, no ShNode renames, no
historical patch.

## Open questions

- Full inventory of prod routing keys that currently fail to parse (which
  types, which senders).
- Is the `to` short_name ever needed for JK's slice binding, or is the
  type-name suffix (`#.<type>`) sufficient? (JK binds by type suffix, so the
  body still arrives — the only loss is at `on_message` parse.)
- Decide the gwbase API shape for an unparseable/short_name `to` token.
