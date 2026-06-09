# Concern: non-GNode interfaces (provisioning, certs, admin)

Design intent from Jessica + evidence from code. These are the interfaces to the
SCADA that are **not** the GNode-to-GNode (SCADA↔LTN) message path —
provisioning, certificates, and administration. Largely **undetermined**.

## What's undetermined

The non-GNode interfaces have not been designed. They include at least:

- **Provisioning** — how a Pi gets its hardware-layout, identity, and config.
- **Certificates** — how the SCADA obtains its keys/certs (today: `getkeys.py`
  pulls from the central `certbot` host via rclone + ssh key, per `CLAUDE.md`).
- **Admin** — operational control of a running SCADA.

## Admin: where it is today vs. where it's going

- **Today:** the **textual admin panel** (`packages/gridworks-admin`, `gwadmin`)
  lives in the SCADA repo and depends on **tailscale** for security, talking to
  the **LOCAL MQTT broker on each Pi** (`ADMIN_MQTT = "admin"` link).
- **Target:** migrate to a **rabbit-native admin in the cloud**, once **mTLS**
  is in place — see [[../../../gridworks-fleet-index-service/research/design]].
  The trust model shifts from "tailscale network membership" to "mTLS client
  identity + FIS authorization."

## Why this is its own concern

These interfaces touch security boundaries different from the dispatch path:
admin can *grab control* (the SCADA has an `Admin` top-level state entered when
the admin UI takes over — `CLAUDE.md`), so its trust model is as important as
the LTN's. Conflating it with the GNode path is a design risk.

## Open questions

- What is the minimal provisioning story for a new Aris-style installer who is
  not GridWorks? (Ties to the deed in [[deeds-and-trading-rights]].)
- Does the `Admin` state's authority respect the customer-not-provider principle
  ([[../principles]])? Who is allowed to grab control, and can the homeowner
  override?
- Cert lifecycle end-to-end: issue (certbot today / FIS-era tomorrow), rotate,
  revoke (clawback).

## Links

[[deeds-and-trading-rights]] · [[transport-and-links]] ·
[[../../../gridworks-fleet-index-service/research/design]] · [[../principles]]
