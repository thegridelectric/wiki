# Concern: transport & links (proactor vs. rabbit-native)

Design intent from Jessica + evidence from code. Several things here are
**open for debate**.

## What exists today

- The SCADA uses **gwproactor** for its MQTT-only transport. `actors/scada.py`
  names three MQTT links: `LTN_MQTT = "gridworks_mqtt"` (upstream, to the LTN —
  the code/legacy name for this link's peer is `atn`/AtomicTNode),
  `LOCAL_MQTT = "local_mqtt"` (to Scada2 on the LAN), `ADMIN_MQTT = "admin"`
  (the gridworks-admin UI). (Per `CLAUDE.md`; verify in `scada.py`.)
- The LTN currently **also runs on the proactor** (`ltn_app.py`).

## The contrast: gridworks-base rabbit transport

The primary GridWorks message-passing mechanism is **rabbit-based**, specified
in `wiki/gridworks-base/executor/design.md`. Key properties the proactor link
lacks:

- **Strict transport/codec separation** — transport routes raw bytes
  (`RoutingEnvelope` + `bytes`); the application owns its codec. The proactor
  entangles MQTT plumbing with message handling.
- **A routing fabric that is the authoritative "who may talk to whom"** — the
  two-exchange-per-class pattern (`<rc>_tx` internal + `<rc>mic_tx`) plus a
  declared binding table. The broker enforces reach; actors can't grant
  themselves reach.
- **Multiple peers per class naturally** — topic exchanges + per-actor queues
  bound on `rj.*.*.*.*.<my-alias>`.

## The known problem

> The proactor *link* concept needs to improve — in particular **it does not
> allow for multiple downstream SCADA**. (Jessica)

The proactor models a link as a single upstream / single downstream pairing;
the rabbit model is many-to-many by construction.

## Decisions that are OPEN

1. **LTN off the proactor.** We are **not** planning to keep running the LTN on
   the proactor, even though we do today. The LTN is being separated and moved
   to **native rabbit**.
2. **SCADA rabbit-native?** We *may* decide the SCADA's link to the LTN becomes
   rabbit-native too. Undecided.
3. If the SCADA stays MQTT but the LTN is rabbit-native, the bridge is the
   RabbitMQ MQTT plugin (already used for `gridworks_mqtt`) — but that does not
   by itself fix the multiple-downstream-SCADA limitation.

## Open questions

- What exactly is a proactor "link" in code, and where is the single-downstream
  assumption baked in? (Trace gwproactor + `scada_app.py` / `scada2_app.py`.)
- If SCADA→LTN goes rabbit-native, what is the SCADA's TransportClass and
  RoutingClass in the gridworks-base taxonomy? (`Scada` is listed there.)
- Does the local Scada↔Scada2 link stay Mosquitto MQTT regardless?

## Links

`wiki/gridworks-base/executor/design.md` · [[non-gnode-interfaces]] ·
[[../components/contract-handler]]
