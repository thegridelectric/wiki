Status: Draft · Pass 0 · Updated 2026-06-10

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