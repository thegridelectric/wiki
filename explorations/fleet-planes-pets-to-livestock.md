Status: Draft · Pass 0 · Updated 2026-11-11

> What this is: the pets→livestock fleet-management architecture sketch
> — Authority / Control / Observability plane separation, Grid Node
> Registry, Fleet Console, Fleet Index Service. Moved verbatim from
> gridworks-infra (observability/custom-tools/gridworks_webapp.md)
> 2026-06-10: aspirational architecture, not deployed reality.

## GridWorks Web App — Architecture Overview

We are transitioning from a “pets” model (per-home SSH + tmux dashboards + local MQTT admin) to a livestock model with centralized observability and properly separated authority.

Propose we partition UI into three domains

1. **Authority Plane**. GNode identity, PKI & mTLK, broker auth, firmware upgrade auth

2. **Control Plane** Human-authorized actuation and configuration. Flipping relays

3. **Observability Plane**

These are intentionally separate. Will likely need to split current
hardware layout concept between 1 & 2

### Authority Plane
The Authority Plane governs identity, runtime authorization, and secure broker access.

It consists of:
 - Grid Node Registry (Seed DB)
 - Secure Broker Access
    - mTLS
     - Fleet Index Service (FIS)

The Authority Plane sits upstream of RabbitMQ and is not dependent on the analytics/web database.

#### Grid Node Registry (Seed DB)

The Grid Node Registry is the canonical ontology and topology store. To start it includes GNodes, Position points and Connectivity edges. IT will expand to include some of the 
core topology of hardware layouts.

Characteristics: 
  - slow changing
  - highly relational, enforced w foreign keys
  - temporal (append-only versioned tables)
  - governance-grade data
  - not populated from rabbit telemetry

#### Secure Broker Access

Secure Broker Access ensures that only properly identified and authorized runtime instances may publish operational traffic.

It consists of 
  - mTLS identity
    - Each GNode application holds a client certificate
    - Certificate CN = `GNodeId`
    - Broker enforces:
      - TLS required
      - Client cert required
      - Cert validation against trusted CA
  - Fleet Index Service (FIS)
    - Tracks `GNodeInstances`
    - Enforcing single-publisher (at a time) per GNodeId
    - Responds to broker HTTP auth backend

### Control Plane

Updated 2026-11-11. The control plane answers one question for every box
in the fleet: what should run here, at which commit, and is that what is
running? Today the answer lives in two hand-driven halves. The FIS gate
leases each identity (one cert, one process) and the `box-deploy.sh` script
in `gridworks-infra/tools/` pulls, syncs and restarts a platform service
from the laptop over ssh. Routine operation still means a person on a
box.

The shape this plane grows into: a box is a GNode. It has a registered
identity and a cert, it reads the registry's statement of what should run
on it and at which SHA, it pulls that code itself, and it reports what it
is running. The registry is the control plane. Nothing in that loop needs
an inbound path to the box, and nothing in it needs a vendor control plane
(AWS orchestration, Kubernetes), which keeps the fleet free of tooling
that locks it to one provider.

Two pieces of work already implement this shape for one class of box each:

- OPS-401 (code-update) is the Pi side: a pull-based version handshake
  over the broker, a supervisor that applies the release and reports, no
  inbound path on a house.
- `box-deploy.sh` is the VM side with the laptop standing in for the
  registry's statement.

Orchestration generalises these. The registry's statement of what runs
where is the one new element; the handshake, the supervisor and the lease
exist.

The unit a box runs is likely a container. The services on the `hw1`
boxes run native under systemd today. The `hw2` simulation host is the
first box set up for containers, and it is where the registry's
statement of what runs on a box is first tried against compose.

By-hand access remains for support and repair and is a separate concern.
OPS-662 (production security) and OPS-663 (pi-support-tunnel) set that
posture: outbound-only boxes, a tailnet for the VMs, an on-demand tunnel
for a Pi. Orchestration removes the routine reasons to use that path.

**Where the LTN runs.** The LTN stays in the cloud. Three reasons:

- The LTN changes far more often than the scada: the market vocabulary
  (flo.params, price identity, bids and contracts) is where the work is.
  A cloud box redeploys by commit, push and pull in minutes; a Pi deploy
  goes through OPS-401, which is a 100-homes gate.
- Houses go offline far more often than cloud boxes. The LTN is the
  house's representative in the market, and a representative has to
  outlive the house being offline: it keeps the contract state, the last
  readings and the forecast, and can say what is happening with the house
  when the house cannot.
- The code path to a cloud box exists today; the Pi update path does not.

Dispatch latency does not change this. The fastpath is scada to broker to
LTN, and every scada and LTN talks to the production broker in us-east-1,
so the broker's location decides it. Measured 2026-11-11: broker TCP
connect is about 3 ms from the AWS LTN box and about 110 ms from Hetzner
Helsinki, against an hourly offer window, a 60 s contract heartbeat and a
5 s ack timeout. OPS-667 moves the LTN box to Helsinki on that basis. The scada never
sees a price. At the top of the hour the MarketMaker publishes the
price, the LTN runs the FLO and sends the scada the hour's contract, and
the scada executes it locally. At a sub-hour cadence that chain repeats
per slot, and the broker, the MarketMaker, the FLO and the LTNs move to
one US location together. The outage and standby questions are worked
in `ltn-placement-and-comms-loss.md`.

### Observability Plane


The UI Plane is responsible for observability, visualization, operational analytics and, human-controlled actuation. 

We currently have a first draft (backoffice + visualizer) that functions well but is difficult to maintain.

**Fleet Console**
 - Create new  scaffolding designed for clarity and maintainability.
 - Merge backoffice + visualizer 
 - Use the combined journaldb as downstream data store.
 - Port existing functionality incrementally.
 - Improve scalability (targeting 100+ sites).
 - Add first-class presence model
 
Separate into three core areas:
  - Read-only observability
  - Administrative config 
      - creating site, modifying data
  - Control Pane (flipping relays)

Interactions:
  - seed db -> journaldb via some replication mechanism
  - control of relays etc waits until broker is secure


**Installer App**
Important, needs design!