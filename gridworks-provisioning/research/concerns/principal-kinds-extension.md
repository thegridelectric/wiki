# Concern: extend provisioning to mint service + operator principals

Status: Draft · Pass 0 · Updated 2026-05-30

> **TODO.** Today's provisioning flow (per
> [`../../executor/primary.md`](../../executor/primary.md)) mints
> GNode identity + cert. The FIS Principal model
> ([`../../../gridworks-fleet-index-service/research/concerns/principal-model.md`](../../../gridworks-fleet-index-service/research/concerns/principal-model.md))
> recognizes three principal kinds: `gnode`, `service`,
> `operator`. Provisioning needs to handle all three.

## What's missing

- **`service` principals** (journalkeeper, ear actor-side, future
  analytics consumers) — cert subject `CN=<service-name>`,
  permissions like `read="ear_tx"`, no single-writer constraint.
  Provisioned once per deployment, not per-boot.
- **`operator` principals** (cloud admin operators) — cert subject
  `CN=<operator-id>`, scope-based permissions, shorter cert
  lifetime, MFA gating. Provisioned per-operator at onboarding.

Both currently have no provisioning path.

## When to address

After the FIS principal-model concern itself converges into a
design. Until then this stays a TODO — the provisioning flow can't
firm up without knowing the FIS-side data shape.
