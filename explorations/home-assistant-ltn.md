# Home Assistant + an LTN wrapper

Status: Draft · Pass 0 · Updated 2026-06-07

> What this is: an open exploration of porting GridWorks SCADA/proactor
> capabilities into a Home Assistant (HA)-native form. Motivated by the
> [Aris collaboration](aris-collaboration.md) (Jonathon Woolley is building
> HA-based SCADA) and by GridWorks wanting a first step into the HA open-source
> ecosystem.

## The question

If a third party runs their SCADA on Home Assistant, what is the smallest,
cleanest set of GridWorks capabilities they need in order to participate in the
GridWorks fabric — and do we **wrap** our existing code behind an HA integration
or **reimplement** it HA-native? This is undecided; the doc scopes the pieces.

## Candidate capabilities to port

These are the durable, reusable parts of the SCADA/proactor stack — the bits
that are valuable independent of our specific actors:

1. **An "LTN wrapper."** A component installed on HA that handles the link to
   the GridWorks fabric: connection, **heartbeating**, and the **crypto
   handshake / identity**. This is the membrane between an HA-based SCADA and
   the rest of the system — the same role the LTN plays today (currently
   `gridworks-scada/gw_spaceheat/actors/ltn/`, being separated into a
   rabbit-native extension of gridworks-base).

2. **Reliable messaging — store-and-resend of un-acked messages.** The proactor
   guarantees delivery across outages by persisting un-acked messages and
   re-sending them (the "reupload" mechanism). HA's native eventing is not built
   for guaranteed cross-outage delivery, so this is a real gap to fill.

3. **Actor-based hierarchical state machines.** The mechanism that makes thorny
   control scenarios tractable — e.g. a race condition where a valve is mid-close
   and a conflicting command arrives. GridWorks models these as hierarchical
   state machines (cf. `gw_spaceheat/actors/local_control/tou_base.py`); HA
   automations are not a natural fit for that rigor.

## Architecture seam

- gridworks-base is **AMQP/pika-native**; gridworks-scada is the **MQTT** side
  (via Rabbit's MQTT plugin). An HA SCADA would need to pick a transport into
  the fabric — likely MQTT to mirror the existing SCADA side, but open.
- Authentication into the fabric goes through **FIS** (mTLS cert issuance +
  authorization). An HA-installed LTN wrapper would need to obtain and present
  a FIS-issued identity. How that provisioning works on an HA box is open.

## Prior art: `gridworks-homeassistant`

There is already a **`gridworks-homeassistant` HACS integration** — a simple
HTTP API pattern (`/api/<actor_name>/<type_name>`) for interacting with
GridWorks pico-based open-source devices (e.g. `Gw101 PicoBtu1`,
`Gw100 TankModule3`). That is a *device-reporting* integration over HTTP, not
the stateful, broker-connected **LTN wrapper** described above — but it is the
natural starting point and learning surface for the HA work, and the place the
BTU sub-thread already lives.

## Sub-thread: BTU meter → HA

The original narrow task (Linear [OPS-47](https://linear.app/gridworks/issue/OPS-47), now cancelled) was getting the
GridWorks BTU meter (`gridworks-pico` — itself due for an overhaul) to report
into Jonathon's HA SCADA, via the `gridworks-homeassistant` integration above.
It was chosen as a way to learn HA. Jonathon may have found another path, but may
still want the BTU meter; keep it as a small, optional on-ramp rather than the
headline.

## Open questions

- **Wrap vs reimplement.** Expose existing proactor capabilities behind a thin
  HA integration, or build HA-native equivalents? A sidecar process (proactor
  running alongside HA, HA as one of its actors) may sidestep the
  reimplementation cost.
- **Minimal LTN-wrapper surface.** What is the smallest contract an HA SCADA
  must honor (heartbeat cadence, identity, message types)?
- **HA ecosystem mechanics.** How HA integrations / add-ons are built and
  distributed (core vs HACS), and what constraints that places on shipping a
  long-running, stateful, broker-connected component.
- **Does HA's runtime support our needs** (guaranteed delivery + hierarchical
  FSM), or must those run in a sidecar the HA integration talks to?
